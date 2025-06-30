require "./dependency_manager"
require "./command"
require "./input_file"
require "./watcher"
require "./plugin"
require "./pipe"
require "./spinner"

module Topia
  # Main task orchestrator - now focuses on coordination rather than implementation
  class Task
    getter name : String
    getter pipeline : (Pipe(Array(InputFile)) | Pipe(String) | Pipe(Bool) | Nil)
    getter spi : Spinner
    getter source_file : String?
    getter source_line : Int32?
    property description : String?

    @command_executor : CommandExecutor
    @file_distributor : FileDistributor
    @task_watcher : TaskWatcher
    @plugin_classes : Array(Plugin)
    @dist_path : String
    @use_dist : Bool
    @pipeline : (Pipe(Array(InputFile)) | Pipe(String) | Pipe(Bool) | Nil)
    @source_file : String?
    @source_line : Int32?
    @description : String?
    @debug : Bool
    @spi : Spinner

    def initialize(@name : String, @debug = false)
      @command_executor = CommandExecutor.new
      @file_distributor = FileDistributor.new
      @task_watcher = TaskWatcher.new
      @plugin_classes = [] of Plugin
      @pipeline = nil
      @dist_path = ""
      @use_dist = false
      @source_file = nil
      @source_line = nil
      @description = nil
      @spi = Spinner.new("Waiting...")

      # Try to capture source location
      capture_source_location
    end

    def run(params : Array(String) = [] of String)
      spi.start("Running Task '#{name}'..")

      # Execute commands first
      @command_executor.execute_all

      # Handle watching or direct execution
      if @task_watcher.watching
        spi.message = "Watching for changes in #{@task_watcher.watch_path}.."
        run_with_watching(params)
      else
        run_pipeline(params)
      end

      spi.success("Task '#{name}' finished successfully.")
      self
    end

    private def run_with_watching(params : Array(String))
      @task_watcher.watch_for_changes do
        run_pipeline(params)
        spi.success("Watch pipeline executed successfully.")
      end
    end

    private def run_pipeline(params : Array(String))
      return unless current_pipeline = @pipeline

      builder = PipelineBuilder.new
      builder.start(current_pipeline.value)

      @plugin_classes.each do |plugin|
        result = PluginLifecycle.run_plugin(plugin, builder.value, params) do
          debug(builder.value)
        end

        if result.nil?
          raise Error.new("Plugin '#{plugin.class.name}' returned nil for task '#{@name}'")
        end

        builder.pipe(plugin)
      end

      # Keep the pipeline as the original type by not reassigning from builder
      run_distribution if @use_dist
    end

    # Load files with the given mode, according to the given path
    def src(path : String, mode = "w")
      files = Dir.glob(path).compact_map do |file_path|
        # Skip directories and only process files
        next unless File.file?(file_path)

        begin
          name = File.basename(file_path)
          file_dir = File.dirname(file_path) + "/"
          contents = File.read(file_path)
          InputFile.new(name, file_dir, contents)
        rescue ex
          # Skip files that can't be read (permissions, etc.)
          Topia.warn("Skipping file #{file_path}: #{ex.message}") if Topia.verbose?
          nil
        end
      end

      @pipeline = Pipe(Array(InputFile)).new(files)
      self
    end

    def dist(output_path : String)
      @use_dist = true
      @dist_path = output_path
      self
    end

    private def run_distribution
      return unless current_pipeline = @pipeline

      if current_pipeline.type_name != "Array(Topia::InputFile)"
        raise Error.new("dist may only be used on Array(Topia::InputFile), got #{current_pipeline.type_name}")
      end

      files = current_pipeline.value.as(Array(InputFile))
      @file_distributor.distribute(files, @dist_path)

      # Block watching temporarily to prevent recursive triggers
      @task_watcher.block_changes
      @task_watcher.delay(1.5) { @task_watcher.unblock_changes }
    end

    def watch(dir : String, read_sources : Bool = false)
      @task_watcher.configure(dir)
      src(dir) if read_sources
      self
    end

    def pipe(plugin : Plugin)
      @plugin_classes.push(plugin)
      self
    end

    def command(command : String)
      @command_executor.add_command(command)
      self
    end

    def depends_on(dependencies : Array(String))
      DependencyManager.add_dependency(@name, dependencies)
      self
    end

    def depends_on(dependency : String)
      depends_on([dependency])
    end

    # Set task description for better CLI output
    def describe(description : String)
      @description = description
      self
    end

    # Get pipeline information for CLI display
    def pipeline_info : String?
      components = [] of String

      unless @command_executor.commands.empty?
        components << "#{@command_executor.commands.size} command(s)"
      end

      unless @plugin_classes.empty?
        plugin_names = @plugin_classes.map(&.class.name.split("::").last)
        components << "plugins: #{plugin_names.join(" → ")}"
      end

      if @use_dist
        components << "dist: #{@dist_path}"
      end

      if @task_watcher.watching
        components << "watching: #{@task_watcher.watch_path}"
      end

      return nil if components.empty?
      components.join(", ")
    end

    # Capture source location where task was defined
    private def capture_source_location
      # This is a simplified version - in a real implementation,
      # you might use caller information or stack traces
      # For now, we'll just mark it as "defined in code"
      @source_file = "defined in code"
      @source_line = 0
    end

    private def debug(value)
      spi.message = "Pipeline value: #{value}" if @debug
    end
  end
end
