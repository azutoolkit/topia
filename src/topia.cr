require "colorize"
require "log"

require "./topia/spinner"
require "./topia/watcher"
require "./topia/command"
require "./topia/error"
require "./topia/input_file"
require "./topia/pipe"
require "./topia/plugin"
require "./topia/task"
require "./topia/cli"
require "./topia/dependency_manager"
require "./topia/config"
require "./topia/async_spinner"
require "./topia/async_watcher"
require "./topia/task_cache"
require "./topia/concurrent_executor"

module Topia
  VERSION = "0.1.0"
  SPINNER = Spinner.new("Waiting...")

  class_property? debug = false
  class_getter logger = Log.for("Topia")

  @@tasks = [] of Task
  @@default_tasks : Array(String) = [] of String
  @@output_mode : Symbol = :normal
  @@task_statistics = {} of String => Hash(String, String | Int32 | Float64)

  # Output mode management
  def self.set_output_mode(mode : Symbol)
    @@output_mode = mode
    case mode
    when :quiet
      Log.setup(:error)
    when :verbose
      Log.setup(:debug)
    when :debug
      Log.setup(:debug)
    else
      Log.setup(:info)
    end
  end

  def self.output_mode
    @@output_mode
  end

  def self.quiet?
    @@output_mode == :quiet
  end

  def self.verbose?
    @@output_mode == :verbose || @@output_mode == :debug
  end

  # Creates a new task
  def self.task(name : String)
    task = Task.new(name, debug?)
    @@tasks.push(task.as(Topia::Task))
    self.debug("Task '#{name}' created.")
    task
  end

  # Overload for creating a task with a callback function that gets executed first
  def self.task(name : String, cb)
    task = self.task(name)
    fn = cb.call
    task.pipe = Pipe(typeof(fn)).new(fn)
    task
  end

  # Run a task
  def self.run(name : String, params : Array(String) = [] of String)
    start_time = Time.monotonic

    @@tasks.each do |task|
      if name == task.name
        begin
          task.run(params)
          record_task_success(name, start_time)
        rescue ex
          record_task_failure(name, start_time, ex)
          raise ex
        end
        return
      end
    end

    raise Topia::Error.new("Task '#{name}' not found")
  end

  # Override to run multiple tasks
  # To be used for default tasks.
  def self.run(tasks : Array)
    tasks.each do |task|
      begin
        run_task, command = task.split(/\s/)
        self.run run_task, command.split(/\s/)
      rescue
        run_task = task
        self.run(task)
      end
    end
  end

  # Adds a default task
  def self.default(subtask : String)
    @@default_tasks.push(subtask)
  end

  # Add multiple default tasks
  def self.default(subtasks : Array(String))
    @@default_tasks = subtasks
  end

  # Runs the default task(s)
  def self.run_default
    self.run(@@default_tasks)
  end

  # CLI entry point
  def self.cli(args = ARGV)
    CLI.run(args)
  end

  # Configuration file support
  def self.configure(file_path : String)
    Config.load_from_file(file_path)
  end

  # Create sample configuration
  def self.create_sample_config(file_path : String = "topia.yml")
    Config.create_sample_config(file_path)
  end

  # Parallel task execution with job control
  def self.run_parallel(task_names : Array(String), max_jobs : Int32 = System.cpu_count)
    # Find the tasks to execute
    tasks_to_run = [] of Task
    task_names.each do |task_name|
      if task = find_task(task_name)
        tasks_to_run << task
      else
        raise Error.new("Task '#{task_name}' not found")
      end
    end

    # Execute using the concurrent executor
    stats = execute_concurrent(tasks_to_run, max_jobs, use_cache: true, show_progress: verbose?)

    # Report results if verbose
    if verbose?
      puts "\n📊 Parallel Execution Results:".colorize(:cyan)
      puts "  Total tasks: #{stats.total_tasks}"
      puts "  Completed: #{stats.completed_tasks}"
      puts "  Failed: #{stats.failed_tasks}"
      puts "  Success rate: #{stats.success_rate.round(1)}%"
      puts "  Total time: #{format_duration_ms(stats.total_duration.total_milliseconds)}"
    end
  end

  # Watch and run tasks when files change
  def self.watch_and_run(task_names : Array(String), &block : Array(String) -> Nil)
    watcher = AsyncWatcher.new

    # Watch current directory and common file patterns
    patterns = ["./**/*.cr", "./**/*.yml", "./**/*.yaml", "./**/*.json", "./**/*.md"]

    # Store the block as a proc to use in the callback
    callback = block

    watcher.watch(patterns) do |changed_files|
      callback.call(changed_files)
    end

    # Keep the program running
    Signal::INT.trap do
      info "Stopping file watcher..."
      watcher.stop
      exit(0)
    end
  end

  # Task management helpers
  def self.available_tasks : Array(Task)
    @@tasks
  end

  def self.default_tasks : Array(String)
    @@default_tasks
  end

  def self.find_task(name : String) : Task?
    @@tasks.find { |task| task.name == name }
  end

  def self.task_dependencies(task_name : String) : Array(String)
    DependencyManager.get_dependencies(task_name)
  end

  # Dependency validation
  def self.validate_all_dependencies
    available_task_names = @@tasks.map(&.name)
    DependencyManager.validate_dependencies(available_task_names)
  end

  # Task statistics
  def self.record_task_success(task_name : String, start_time : Time::Span)
    end_time = Time.monotonic
    duration = end_time - start_time

    @@task_statistics[task_name] = {
      "status"      => "success",
      "duration_ms" => duration.total_milliseconds,
      "last_run"    => Time.local.to_s("%Y-%m-%d %H:%M:%S"),
      "runs"        => (@@task_statistics[task_name]?.try(&.["runs"]?.as?(Int32)) || 0) + 1,
    }

    success "✓ Task '#{task_name}' completed in #{format_duration(duration)}"
  end

  def self.record_task_failure(task_name : String, start_time : Time::Span, error : Exception)
    end_time = Time.monotonic
    duration = end_time - start_time

    @@task_statistics[task_name] = {
      "status"      => "failed",
      "duration_ms" => duration.total_milliseconds,
      "last_run"    => Time.local.to_s("%Y-%m-%d %H:%M:%S"),
      "error"       => error.message || "Unknown error",
      "runs"        => (@@task_statistics[task_name]?.try(&.["runs"]?.as?(Int32)) || 0) + 1,
    }

    error "✗ Task '#{task_name}' failed after #{format_duration(duration)}: #{error.message}"
  end

  def self.task_statistics(task_name : String) : String?
    stats = @@task_statistics[task_name]?
    return nil unless stats

    status = stats["status"]
    runs = stats["runs"]
    duration = stats["duration_ms"].as?(Float64) || 0.0
    last_run = stats["last_run"]

    "#{runs} runs, last: #{status} in #{format_duration_ms(duration)} (#{last_run})"
  end

  def self.show_detailed_statistics
    return if @@task_statistics.empty?

    puts ""
    puts "Detailed Task Statistics:".colorize(:cyan)
    puts "━" * 60

    @@task_statistics.each do |task_name, stats|
      status_color = stats["status"] == "success" ? :green : :red
      puts "#{task_name}:".colorize(:white)
      puts "  Status: #{stats["status"]}".colorize(status_color)
      puts "  Runs: #{stats["runs"]}"
      puts "  Duration: #{format_duration_ms(stats["duration_ms"].as?(Float64) || 0.0)}"
      puts "  Last run: #{stats["last_run"]}"

      if error = stats["error"]?
        puts "  Error: #{error}".colorize(:red)
      end

      puts ""
    end
  end

  # Clear all tasks (useful for testing)
  def self.clear_tasks
    @@tasks.clear
    @@default_tasks.clear
    @@task_statistics.clear
    DependencyManager.clear_dependencies
  end

  # Output helpers
  def self.info(message : String)
    return if quiet?
    puts message.colorize(:cyan)
  end

  def self.success(message : String)
    return if quiet?
    puts message.colorize(:green)
  end

  def self.warn(message : String)
    puts message.colorize(:yellow) unless quiet?
  end

  def self.error(message : String)
    puts "ERROR: #{message}".colorize(:red)
  end

  def self.debug(message : String)
    return unless debug?
    puts "DEBUG: #{message}".colorize(:dark_gray)
  end

  # Duration formatting helpers
  private def self.format_duration(duration : Time::Span) : String
    format_duration_ms(duration.total_milliseconds)
  end

  private def self.format_duration_ms(ms : Float64) : String
    if ms < 1000
      "#{ms.round(2)}ms"
    elsif ms < 60000
      "#{(ms / 1000).round(2)}s"
    else
      minutes = (ms / 60000).to_i
      seconds = ((ms % 60000) / 1000).round(2)
      "#{minutes}m #{seconds}s"
    end
  end

  # Debugging utility
  private def self.debug(message)
    @@logger.debug { message } if debug?
  end
end
