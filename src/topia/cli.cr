require "option_parser"
require "colorize"
require "file_utils"

module Topia
  # Command Line Interface for Topia task runner
  class CLI
    VERSION_TEXT = "Topia v#{Topia::VERSION} - Crystal Task Automation Framework"

    getter options : Hash(String, String | Bool | Int32)
    getter tasks : Array(String)

    def initialize
      @options = {} of String => String | Bool | Int32
      @tasks = [] of String
    end

    def self.run(args = ARGV)
      cli = new
      cli.parse_args(args)
      cli.execute
    end

    def parse_args(args : Array(String))
      parser = OptionParser.new do |parser|
        parser.banner = VERSION_TEXT
        parser.separator ""
        parser.separator "Usage: topia [options] [task_names...]"
        parser.separator ""
        parser.separator "Main Options:"

        parser.on("-h", "--help", "Show this help message") do
          @options["help"] = true
        end

        parser.on("-v", "--version", "Show version information") do
          @options["version"] = true
        end

        parser.on("-l", "--list", "List all available tasks") do
          @options["list"] = true
        end

        parser.on("--list-detailed", "List tasks with detailed information") do
          @options["list_detailed"] = true
        end

        parser.separator ""
        parser.separator "Execution Options:"

        parser.on("-p", "--parallel", "Run tasks in parallel") do
          @options["parallel"] = true
        end

        parser.on("-j JOBS", "--jobs=JOBS", "Number of parallel jobs (default: CPU cores)") do |jobs|
          @options["jobs"] = jobs.to_i
        end

        parser.on("--dry-run", "Show what would be executed without running") do
          @options["dry_run"] = true
        end

        parser.on("-w", "--watch", "Watch for file changes and re-run tasks") do
          @options["watch"] = true
        end

        parser.on("-i", "--interactive", "Interactive task selection") do
          @options["interactive"] = true
        end

        parser.separator ""
        parser.separator "Output Control:"

        parser.on("-q", "--quiet", "Suppress all output except errors") do
          @options["quiet"] = true
          @options["verbose"] = false
        end

        parser.on("--verbose", "Enable verbose output") do
          @options["verbose"] = true
          @options["quiet"] = false
        end

        parser.on("-d", "--debug", "Enable debug mode with detailed logging") do
          @options["debug"] = true
          @options["verbose"] = true
          Topia.debug = true
        end

        parser.on("--no-color", "Disable colored output") do
          @options["no_color"] = true
          Colorize.enabled = false
        end

        parser.on("--stats", "Show execution statistics") do
          @options["stats"] = true
        end

        parser.separator ""
        parser.separator "Configuration:"

        parser.on("-c CONFIG", "--config=CONFIG", "Specify configuration file") do |config|
          @options["config"] = config
        end

        parser.on("--validate-config", "Validate configuration file and exit") do
          @options["validate_config"] = true
        end

        parser.on("--init [DIR]", "Initialize topia.yml in directory") do |dir|
          @options["init"] = dir || "."
        end

        parser.separator ""
        parser.separator "Information:"

        parser.on("--dependencies TASK", "Show task dependencies") do |task|
          @options["show_dependencies"] = task
        end

        parser.on("--where TASK", "Show where task is defined") do |task|
          @options["where"] = task
        end

        parser.on("--profile", "Enable performance profiling") do
          @options["profile"] = true
        end

        parser.separator ""
        parser.separator "Examples:"
        parser.separator "  topia build                    # Run 'build' task"
        parser.separator "  topia build test deploy        # Run multiple tasks"
        parser.separator "  topia -p build test            # Run tasks in parallel"
        parser.separator "  topia -j 4 build               # Use 4 parallel jobs"
        parser.separator "  topia -c topia.yml build       # Use custom config"
        parser.separator "  topia -l                       # List available tasks"
        parser.separator "  topia --list-detailed          # Detailed task information"
        parser.separator "  topia -w build                 # Watch and rebuild"
        parser.separator "  topia --init                   # Create sample config"
        parser.separator "  topia --validate-config        # Check config syntax"
        parser.separator "  topia --dependencies build     # Show task dependencies"
        parser.separator "  topia -q build                 # Quiet mode"
        parser.separator "  topia --verbose build          # Verbose output"
        parser.separator "  topia --stats build            # Show execution stats"
        parser.separator ""

        parser.unknown_args do |args|
          @tasks = args
        end

        parser.invalid_option do |flag|
          error "Invalid option: #{flag}"
          puts parser
          exit(1)
        end
      end

      begin
        parser.parse(args)
      rescue ex : OptionParser::Exception
        error "#{ex.message}"
        puts parser
        exit(1)
      end
    end

    def execute
      setup_output_mode

      # Handle help and version first
      if @options["help"]?
        show_help
        return
      end

      if @options["version"]?
        show_version
        return
      end

      # Handle initialization
      if init_dir = @options["init"]?.as?(String)
        initialize_project(init_dir)
        return
      end

      # Load configuration
      load_configuration_with_validation

      # Handle configuration validation
      if @options["validate_config"]?
        validate_configuration_only
        return
      end

      # Handle information commands
      if @options["list"]?
        list_tasks
        return
      end

      if @options["list_detailed"]?
        list_tasks_detailed
        return
      end

      if task_name = @options["show_dependencies"]?.as?(String)
        show_task_dependencies(task_name)
        return
      end

      if task_name = @options["where"]?.as?(String)
        show_task_location(task_name)
        return
      end

      # Handle interactive mode
      if @options["interactive"]?
        run_interactive_mode
        return
      end

      # Execute tasks
      if @tasks.empty?
        run_default_tasks
      else
        run_specified_tasks
      end
    end

    private def setup_output_mode
      if @options["quiet"]?
        Topia.set_output_mode(:quiet)
      elsif @options["verbose"]?
        Topia.set_output_mode(:verbose)
      else
        Topia.set_output_mode(:normal)
      end
    end

    private def show_help
      puts create_help_text
    end

    private def create_help_text : String
      String.build do |str|
        str << VERSION_TEXT.colorize(:cyan)
        str << "\n\n"
        str << "Usage: topia [options] [task_names...]\n\n"

        str << "Main Options:\n"
        str << "  -h, --help                     Show this help message\n"
        str << "  -v, --version                  Show version information\n"
        str << "  -l, --list                     List all available tasks\n"
        str << "      --list-detailed            List tasks with detailed information\n\n"

        str << "Execution Options:\n"
        str << "  -p, --parallel                 Run tasks in parallel\n"
        str << "  -j JOBS, --jobs=JOBS           Number of parallel jobs (default: CPU cores)\n"
        str << "      --dry-run                  Show what would be executed without running\n"
        str << "  -w, --watch                    Watch for file changes and re-run tasks\n"
        str << "  -i, --interactive              Interactive task selection\n\n"

        str << "Output Control:\n"
        str << "  -q, --quiet                    Suppress all output except errors\n"
        str << "      --verbose                  Enable verbose output\n"
        str << "  -d, --debug                    Enable debug mode with detailed logging\n"
        str << "      --no-color                 Disable colored output\n"
        str << "      --stats                    Show execution statistics\n\n"

        str << "Configuration:\n"
        str << "  -c CONFIG, --config=CONFIG     Specify configuration file\n"
        str << "      --validate-config          Validate configuration file and exit\n"
        str << "      --init [DIR]               Initialize topia.yml in directory\n\n"

        str << "Information:\n"
        str << "      --dependencies TASK        Show task dependencies\n"
        str << "      --where TASK               Show where task is defined\n"
        str << "      --profile                  Enable performance profiling\n\n"

        str << "Examples:\n"
        str << "  topia build                    # Run 'build' task\n"
        str << "  topia build test deploy        # Run multiple tasks\n"
        str << "  topia -p build test            # Run tasks in parallel\n"
        str << "  topia -j 4 build               # Use 4 parallel jobs\n"
        str << "  topia -c topia.yml build       # Use custom config\n"
        str << "  topia -l                       # List available tasks\n"
        str << "  topia --list-detailed          # Detailed task information\n"
        str << "  topia -w build                 # Watch and rebuild\n"
        str << "  topia --init                   # Create sample config\n"
        str << "  topia --validate-config        # Check config syntax\n"
        str << "  topia --dependencies build     # Show task dependencies\n"
        str << "  topia -q build                 # Quiet mode\n"
        str << "  topia --verbose build          # Verbose output\n"
        str << "  topia --stats build            # Show execution stats\n"
      end
    end

    private def show_version
      info VERSION_TEXT
      puts "Crystal: #{Crystal::VERSION}"
      puts "Platform: #{{% if flag?(:darwin) %}"macOS"{% elsif flag?(:linux) %}"Linux"{% elsif flag?(:windows) %}"Windows"{% else %}"Unknown"{% end %}}"
      puts "Build: #{{% if flag?(:release) %}"Release"{% else %}"Debug"{% end %}}"
    end

    private def initialize_project(dir : String)
      config_path = Path[dir] / "topia.yml"

      if File.exists?(config_path)
        unless confirm("Configuration file already exists. Overwrite?")
          warn "Initialization cancelled."
          return
        end
      end

      begin
        Topia.create_sample_config(config_path.to_s)
        success "✓ Created #{config_path}"
        info "Edit #{config_path} to customize your tasks and configuration."
      rescue ex
        error "Failed to create configuration: #{ex.message}"
        exit(1)
      end
    end

    private def load_configuration_with_validation
      config_file = @options["config"]?.as?(String)

      if config_file
        load_and_validate_config(config_file)
      else
        # Try to load default config files
        load_default_configuration_with_validation
      end
    end

    private def load_and_validate_config(file : String)
      unless File.exists?(file)
        error "Configuration file '#{file}' not found"
        exit(1)
      end

      begin
        debug "Loading configuration from #{file}"
        Topia.configure(file)
        debug "✓ Configuration loaded successfully"

        # Validate the loaded configuration
        validate_loaded_configuration
      rescue ex : YAML::ParseException
        error "Configuration syntax error in #{file}:"
        error "  Line #{ex.line_number}: #{ex.message}"
        exit(1)
      rescue ex
        error "Failed to load configuration: #{ex.message}"
        exit(1)
      end
    end

    private def load_default_configuration_with_validation
      default_files = ["topia.yml", "topia.yaml", ".topia.yml"]

      default_files.each do |file|
        if File.exists?(file)
          debug "Found default configuration: #{file}"
          load_and_validate_config(file)
          return
        end
      end

      debug "No configuration file found, using defaults"
    end

    private def validate_configuration_only
      info "Validating configuration..."

      config_file = @options["config"]?.as?(String) || find_default_config

      unless config_file
        error "No configuration file found to validate"
        exit(1)
      end

      begin
        Topia.configure(config_file)
        validate_loaded_configuration
        success "✓ Configuration is valid"
      rescue ex : YAML::ParseException
        error "Configuration syntax error:"
        error "  Line #{ex.line_number}: #{ex.message}"
        exit(1)
      rescue ex
        error "Configuration validation failed: #{ex.message}"
        exit(1)
      end
    end

    private def validate_loaded_configuration
      # Validate that referenced tasks exist
      available_task_names = Topia.available_tasks.map(&.name)
      default_tasks = Topia.default_tasks

      default_tasks.each do |task_name|
        unless available_task_names.includes?(task_name)
          warn "Default task '#{task_name}' is not defined"
        end
      end

      # Validate dependencies
      Topia.validate_all_dependencies

      debug "✓ Configuration validation passed"
    end

    private def find_default_config : String?
      ["topia.yml", "topia.yaml", ".topia.yml"].find { |f| File.exists?(f) }
    end

    private def list_tasks
      available_tasks = Topia.available_tasks

      if available_tasks.empty?
        warn "No tasks defined."
        return
      end

      info "Available tasks:"
      puts ""

      available_tasks.each do |task|
        dependencies = Topia.task_dependencies(task.name)
        status = if dependencies.empty?
                   "○".colorize(:blue)
                 else
                   "●".colorize(:green)
                 end

        puts "  #{status} #{task.name.colorize(:white)}"

        unless dependencies.empty?
          puts "    Dependencies: #{dependencies.join(", ").colorize(:dark_gray)}"
        end
      end

      puts ""
      unless Topia.default_tasks.empty?
        puts "Default tasks: #{Topia.default_tasks.join(", ")}".colorize(:dark_gray)
      end
    end

    private def list_tasks_detailed
      available_tasks = Topia.available_tasks

      if available_tasks.empty?
        warn "No tasks defined."
        return
      end

      info "Detailed task information:"
      puts ""

      available_tasks.each do |task|
        puts "━" * 60
        puts "Task: #{task.name.colorize(:cyan)}"

        dependencies = Topia.task_dependencies(task.name)
        unless dependencies.empty?
          puts "Dependencies: #{dependencies.join(" → ").colorize(:yellow)}"
        end

        # Show task source information
        puts "Source: #{task.source_file || "defined in code"}".colorize(:dark_gray)

        if description = task.description
          if !description.empty?
            puts "Description: #{description}"
          end
        end

        # Show pipeline information
        if task.pipeline_info
          puts "Pipeline: #{task.pipeline_info.colorize(:blue)}"
        end

        # Show statistics if available
        if stats = Topia.task_statistics(task.name)
          puts "Statistics: #{stats.colorize(:green)}"
        end

        puts ""
      end

      unless Topia.default_tasks.empty?
        puts "Default tasks: #{Topia.default_tasks.join(", ")}".colorize(:dark_gray)
      end
    end

    private def show_task_dependencies(task_name : String)
      unless Topia.find_task(task_name)
        error "Task '#{task_name}' not found"
        exit(1)
      end

      dependencies = Topia.task_dependencies(task_name)

      if dependencies.empty?
        info "Task '#{task_name}' has no dependencies."
      else
        info "Dependencies for '#{task_name}':"
        dependencies.each_with_index do |dep, index|
          puts "  #{index + 1}. #{dep}"
        end
      end
    end

    private def show_task_location(task_name : String)
      task = Topia.find_task(task_name)

      unless task
        error "Task '#{task_name}' not found"
        exit(1)
      end

      info "Task '#{task_name}' location:"
      puts "  File: #{task.source_file || "defined in code"}"
      puts "  Line: #{task.source_line || "unknown"}"
    end

    private def run_interactive_mode
      available_tasks = Topia.available_tasks

      if available_tasks.empty?
        warn "No tasks available for interactive selection."
        return
      end

      info "Interactive Task Selection"
      puts "Available tasks:"

      available_tasks.each_with_index do |task, index|
        puts "  #{index + 1}. #{task.name}"
      end

      print "\nSelect task numbers (e.g., 1,3,5 or 1-3): "

      input = gets
      return unless input

      selected_tasks = parse_task_selection(input.strip, available_tasks)

      if selected_tasks.empty?
        warn "No valid tasks selected."
        return
      end

      @tasks = selected_tasks
      run_specified_tasks
    end

    private def parse_task_selection(input : String, available_tasks : Array(Topia::Task)) : Array(String)
      selected = [] of String

      input.split(',').each do |part|
        part = part.strip

        if part.includes?('-')
          # Range selection (e.g., "1-3")
          range_parts = part.split('-')
          next unless range_parts.size == 2

          start_idx = range_parts[0].to_i? || 0
          end_idx = range_parts[1].to_i? || 0

          (start_idx..end_idx).each do |idx|
            if task = available_tasks[idx - 1]?
              selected << task.name
            end
          end
        else
          # Single selection
          idx = part.to_i? || 0
          if task = available_tasks[idx - 1]?
            selected << task.name
          end
        end
      end

      selected.uniq
    end

    private def run_default_tasks
      default_tasks = Topia.default_tasks

      if default_tasks.empty?
        warn "No default tasks defined and no tasks specified."
        info "Use 'topia -l' to list available tasks."
        return
      end

      info "Running default tasks: #{default_tasks.join(", ")}"

      execute_tasks(default_tasks)
    end

    private def run_specified_tasks
      if @options["dry_run"]?
        show_dry_run
        return
      end

      info "Running tasks: #{@tasks.join(", ")}"
      execute_tasks(@tasks)
    end

    private def execute_tasks(task_names : Array(String))
      start_time = Time.monotonic

      begin
        if @options["watch"]?
          run_with_watch_mode(task_names)
        elsif @options["parallel"]?
          run_parallel_with_stats(task_names)
        else
          run_sequential_with_stats(task_names)
        end
      rescue ex : Topia::Error
        error "Task execution failed: #{ex.message}"
        exit(1)
      ensure
        if @options["stats"]?
          show_execution_statistics(start_time)
        end
      end
    end

    private def run_parallel_with_stats(task_names : Array(String))
      jobs = @options["jobs"]?.as?(Int32) || System.cpu_count
      info "Running #{task_names.size} tasks in parallel (#{jobs} jobs)"

      Topia.run_parallel(task_names, max_jobs: jobs.to_i32)
    end

    private def run_sequential_with_stats(task_names : Array(String))
      task_names.each_with_index do |task_name, index|
        if @options["verbose"]?
          info "Running task #{index + 1}/#{task_names.size}: #{task_name}"
        end

        Topia.run(task_name)
      end
    end

    private def run_with_watch_mode(task_names : Array(String))
      info "Starting watch mode for tasks: #{task_names.join(", ")}"
      info "Press Ctrl+C to stop watching"

      Topia.watch_and_run(task_names) do |changed_files|
        debug "Files changed: #{changed_files.join(", ")}"
        info "Re-running tasks due to file changes..."

        task_names.each do |task_name|
          Topia.run(task_name)
        end
      end
    end

    private def show_dry_run
      warn "DRY RUN - Would execute:"

      @tasks.each do |task_name|
        puts "  → Task: #{task_name}"

        if task = Topia.find_task(task_name)
          dependencies = Topia.task_dependencies(task_name)
          unless dependencies.empty?
            puts "    Dependencies: #{dependencies.join(" → ")}"
          end

          if task.pipeline_info
            puts "    Pipeline: #{task.pipeline_info}"
          end
        else
          puts "    ⚠ Task not found".colorize(:red)
        end
      end
    end

    private def show_execution_statistics(start_time : Time::Span)
      end_time = Time.monotonic
      total_time = end_time - start_time

      puts ""
      puts "Execution Statistics:".colorize(:cyan)
      puts "  Total time: #{format_duration(total_time)}"
      puts "  Tasks executed: #{@tasks.size}"

      if @options["parallel"]?
        puts "  Execution mode: Parallel"
        puts "  Jobs: #{@options["jobs"]? || System.cpu_count}"
      else
        puts "  Execution mode: Sequential"
      end

      # Show detailed task statistics if available
      Topia.show_detailed_statistics if @options["verbose"]?
    end

    private def format_duration(duration : Time::Span) : String
      total_ms = duration.total_milliseconds

      if total_ms < 1000
        "#{total_ms.round(2)}ms"
      elsif total_ms < 60000
        "#{(total_ms / 1000).round(2)}s"
      else
        minutes = (total_ms / 60000).to_i
        seconds = ((total_ms % 60000) / 1000).round(2)
        "#{minutes}m #{seconds}s"
      end
    end

    private def confirm(message : String) : Bool
      return true if @options["quiet"]? # Auto-confirm in quiet mode

      print "#{message} [y/N]: "
      response = gets
      return false unless response

      response.strip.downcase.starts_with?("y")
    end

    # Output helpers
    private def info(message : String)
      return if @options["quiet"]?
      puts message.colorize(:cyan)
    end

    private def success(message : String)
      return if @options["quiet"]?
      puts message.colorize(:green)
    end

    private def warn(message : String)
      puts message.colorize(:yellow) unless @options["quiet"]?
    end

    private def error(message : String)
      puts "ERROR: #{message}".colorize(:red)
    end

    private def debug(message : String)
      return unless @options["debug"]?
      puts "DEBUG: #{message}".colorize(:dark_gray)
    end
  end
end
