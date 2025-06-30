require "yaml"

module Topia
  # Configuration management for Topia projects
  class Config
    # Configuration structure
    struct TaskConfig
      include YAML::Serializable

      property description : String? = nil
      property commands : Array(String)? = nil
      property sources : Array(String)? = nil
      property output : String? = nil
      property watch : String? = nil
      property watch_sources : Bool? = nil
      property dependencies : Array(String)? = nil
      property plugins : Array(String)? = nil
    end

    struct ProjectConfig
      include YAML::Serializable

      property name : String? = nil
      property version : String? = nil
      property description : String? = nil
      property tasks : Hash(String, TaskConfig)? = nil
      property default_tasks : Array(String)? = nil
      property plugins : Array(String)? = nil
      property variables : Hash(String, String)? = nil
    end

    @@config : ProjectConfig?
    @@variables = {} of String => String

    def self.load_from_file(file_path : String)
      unless File.exists?(file_path)
        raise Error.new("Configuration file '#{file_path}' not found")
      end

      begin
        content = File.read(file_path)

        # Replace variables in content
        content = substitute_variables(content)

        @@config = ProjectConfig.from_yaml(content)

        # Process the loaded configuration
        process_configuration
      rescue ex : YAML::ParseException
        raise Error.new("Invalid YAML in configuration file '#{file_path}': #{ex.message}")
      rescue ex
        raise Error.new("Failed to load configuration from '#{file_path}': #{ex.message}")
      end
    end

    def self.current_config : ProjectConfig?
      @@config
    end

    def self.set_variable(key : String, value : String)
      @@variables[key] = value
    end

    def self.get_variable(key : String) : String?
      @@variables[key]?
    end

    def self.create_sample_config(file_path : String = "topia.yml")
      sample_config = {
        "name"        => "My Project",
        "version"     => "1.0.0",
        "description" => "A sample Topia project configuration",
        "variables"   => {
          "build_dir" => "./build",
          "src_dir"   => "./src",
        },
        "default_tasks" => ["build"],
        "tasks"         => {
          "clean" => {
            "description" => "Clean build directory",
            "commands"    => ["rm -rf ${build_dir}"],
          },
          "build" => {
            "description"  => "Build the project",
            "dependencies" => ["clean"],
            "sources"      => ["${src_dir}/**/*.cr"],
            "commands"     => ["crystal build src/main.cr -o ${build_dir}/app"],
          },
          "test" => {
            "description" => "Run tests",
            "commands"    => ["crystal spec"],
          },
          "dev" => {
            "description"   => "Development mode with file watching",
            "watch"         => "${src_dir}",
            "watch_sources" => true,
            "commands"      => ["crystal run src/main.cr"],
          },
        },
      }

      File.write(file_path, sample_config.to_yaml)
      puts "✓ Created sample configuration file: #{file_path}".colorize(:green)
    end

    private def self.substitute_variables(content : String) : String
      # Load variables from config first
      if config_data = YAML.parse(content).as_h?
        if variables = config_data["variables"]?.try(&.as_h?)
          variables.each do |key, value|
            @@variables[key.to_s] = value.to_s
          end
        end
      end

      # Add environment variables
      ENV.each do |key, value|
        @@variables["ENV_#{key}"] = value
      end

      # Substitute variables in format ${variable_name}
      result = content
      @@variables.each do |key, value|
        result = result.gsub("${#{key}}", value)
      end

      result
    end

    private def self.process_configuration
      config = @@config
      return unless config

      # Set default tasks
      if default_tasks = config.default_tasks
        Topia.default(default_tasks)
      end

      # Create tasks from configuration
      if tasks = config.tasks
        tasks.each do |task_name, task_config|
          create_task_from_config(task_name, task_config)
        end
      end

      # Validate dependencies
      validate_task_dependencies
    end

    private def self.create_task_from_config(name : String, config : TaskConfig)
      task = Topia.task(name)

      # Add dependencies
      if dependencies = config.dependencies
        # We'll set this up but the task class needs to support it
        DependencyManager.add_dependency(name, dependencies)
      end

      # Add sources
      if sources = config.sources
        sources.each do |source|
          task.src(source)
        end
      end

      # Add commands
      if commands = config.commands
        commands.each do |command|
          task.command(command)
        end
      end

      # Set output directory
      if output = config.output
        task.dist(output)
      end

      # Configure watching
      if watch_path = config.watch
        watch_sources = config.watch_sources || false
        task.watch(watch_path, watch_sources)
      end

      # Add plugins (if specified)
      if plugins = config.plugins
        plugins.each do |plugin_name|
          # This would need to be implemented based on plugin loading strategy
          # For now, we'll just store the plugin names
        end
      end
    end

    private def self.validate_task_dependencies
      config = @@config
      return unless config
      return unless tasks = config.tasks

      available_tasks = tasks.keys
      DependencyManager.validate_dependencies(available_tasks)
    end
  end

  # Configuration DSL helpers
  module ConfigDSL
    def self.configure_from_hash(config : Hash)
      # Helper method to configure from hash (useful for testing)
      yaml_content = config.to_yaml
      temp_file = File.tempname("topia_config", ".yml")
      File.write(temp_file, yaml_content)

      begin
        Config.load_from_file(temp_file)
      ensure
        File.delete(temp_file) if File.exists?(temp_file)
      end
    end
  end
end
