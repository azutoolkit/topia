require "./dependency_manager"

module Topia
  # Main task orchestrator - now focuses on coordination rather than implementation
  class Task
    getter name : String
    getter pipeline
    getter spi = Topia::SPINNER

    @command_executor : CommandExecutor
    @file_distributor : FileDistributor
    @task_watcher : TaskWatcher
    @plugin_classes : Array(Plugin)
    @dist_path : String
    @use_dist : Bool

    def initialize(@name : String, @debug = false)
      @command_executor = CommandExecutor.new
      @file_distributor = FileDistributor.new
      @task_watcher = TaskWatcher.new
      @plugin_classes = [] of Plugin
      @pipeline = nil
      @dist_path = ""
      @use_dist = false
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
      files = Dir.glob(path).map do |file_path|
        name = File.basename(file_path)
        file_dir = File.dirname(file_path) + "/"
        contents = File.read(file_path)
        InputFile.new(name, file_dir, contents)
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

    private def debug(value)
      spi.message = "Pipeline value: #{value}" if @debug
    end
  end
end
