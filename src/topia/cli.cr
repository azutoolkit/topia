require "option_parser"
require "colorize"

module Topia
  # Command Line Interface for Topia task runner
  class CLI
    VERSION_TEXT = "Topia v#{Topia::VERSION} - Crystal Task Automation Framework"

    getter options : Hash(String, String | Bool)
    getter tasks : Array(String)

    def initialize
      @options = {} of String => String | Bool
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
        parser.separator "Options:"

        parser.on("-h", "--help", "Show this help message") do
          @options["help"] = true
        end

        parser.on("-v", "--version", "Show version information") do
          @options["version"] = true
        end

        parser.on("-d", "--debug", "Enable debug mode") do
          @options["debug"] = true
          Topia.debug = true
        end

        parser.on("-l", "--list", "List all available tasks") do
          @options["list"] = true
        end

        parser.on("-c CONFIG", "--config=CONFIG", "Specify configuration file") do |config|
          @options["config"] = config
        end

        parser.on("-p", "--parallel", "Run tasks in parallel") do
          @options["parallel"] = true
        end

        parser.on("--dry-run", "Show what would be executed without running") do
          @options["dry_run"] = true
        end

        parser.separator ""
        parser.separator "Examples:"
        parser.separator "  topia build                    # Run 'build' task"
        parser.separator "  topia build test deploy        # Run multiple tasks"
        parser.separator "  topia -p build test            # Run tasks in parallel"
        parser.separator "  topia -c topia.yml build       # Use custom config"
        parser.separator "  topia -l                       # List available tasks"
        parser.separator ""

        parser.unknown_args do |args|
          @tasks = args
        end

        parser.invalid_option do |flag|
          puts "ERROR: Invalid option: #{flag}".colorize(:red)
          puts parser
          exit(1)
        end
      end

      begin
        parser.parse(args)
      rescue ex : OptionParser::Exception
        puts "ERROR: #{ex.message}".colorize(:red)
        puts parser
        exit(1)
      end
    end

    def execute
      # Handle help and version first
      if @options["help"]?
        show_help
        return
      end

      if @options["version"]?
        show_version
        return
      end

      # Load configuration if specified
      if config_file = @options["config"]?.as?(String)
        load_configuration(config_file)
      else
        # Try to load default config files
        load_default_configuration
      end

      # Handle list tasks
      if @options["list"]?
        list_tasks
        return
      end

      # Execute tasks
      if @tasks.empty?
        run_default_tasks
      else
        run_specified_tasks
      end
    end

    private def show_help
      puts VERSION_TEXT.colorize(:cyan)
      puts ""
      puts "Topia is a Crystal-based task automation and build pipeline tool."
      puts "It provides a flexible, composable system for automating development workflows."
      puts ""
      puts "Run 'topia -h' for detailed usage information."
    end

    private def show_version
      puts VERSION_TEXT
      puts "Crystal: #{Crystal::VERSION}"
      puts "Platform: #{{% if flag?(:darwin) %}"macOS"{% elsif flag?(:linux) %}"Linux"{% elsif flag?(:windows) %}"Windows"{% else %}"Unknown"{% end %}}"
    end

    private def load_configuration(file : String)
      unless File.exists?(file)
        puts "ERROR: Configuration file '#{file}' not found".colorize(:red)
        exit(1)
      end

      begin
        Topia.configure(file)
        puts "✓ Loaded configuration from #{file}".colorize(:green) if @options["debug"]?
      rescue ex
        puts "ERROR: Failed to load configuration: #{ex.message}".colorize(:red)
        exit(1)
      end
    end

    private def load_default_configuration
      default_files = ["topia.yml", "topia.yaml", ".topia.yml"]

      default_files.each do |file|
        if File.exists?(file)
          load_configuration(file)
          break
        end
      end
    end

    private def list_tasks
      available_tasks = Topia.available_tasks

      if available_tasks.empty?
        puts "No tasks defined.".colorize(:yellow)
        return
      end

      puts "Available tasks:".colorize(:cyan)
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
      puts "Default tasks: #{Topia.default_tasks.join(", ")}".colorize(:dark_gray) unless Topia.default_tasks.empty?
    end

    private def run_default_tasks
      default_tasks = Topia.default_tasks

      if default_tasks.empty?
        puts "No default tasks defined and no tasks specified.".colorize(:yellow)
        puts "Use 'topia -l' to list available tasks."
        return
      end

      puts "Running default tasks: #{default_tasks.join(", ")}".colorize(:cyan)

      if @options["parallel"]?
        Topia.run_parallel(default_tasks)
      else
        Topia.run_default
      end
    end

    private def run_specified_tasks
      if @options["dry_run"]?
        show_dry_run
        return
      end

      puts "Running tasks: #{@tasks.join(", ")}".colorize(:cyan)

      if @options["parallel"]?
        Topia.run_parallel(@tasks)
      else
        @tasks.each do |task_name|
          Topia.run(task_name)
        end
      end
    end

    private def show_dry_run
      puts "DRY RUN - Would execute:".colorize(:yellow)

      @tasks.each do |task_name|
        puts "  → Task: #{task_name}"

        if task = Topia.find_task(task_name)
          dependencies = Topia.task_dependencies(task_name)
          unless dependencies.empty?
            puts "    Dependencies: #{dependencies.join(" → ")}"
          end
        else
          puts "    ⚠ Task not found".colorize(:red)
        end
      end
    end
  end
end
