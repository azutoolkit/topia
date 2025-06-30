#!/usr/bin/env crystal

require "../src/topia"

# Developer Experience Demo
# Showcases all the enhanced CLI features for better developer productivity

puts "🎯 Developer Experience Demo".colorize(:cyan)
puts "=" * 50

# 1. Create sample tasks with descriptions and dependencies
puts "\n1. Creating Sample Tasks with Descriptions..."

Topia.task("setup")
  .describe("Initialize project dependencies and configuration")
  .command("echo 'Setting up project...'")
  .command("mkdir -p tmp/build")

Topia.task("lint")
  .describe("Run code quality checks and linting")
  .depends_on("setup")
  .command("echo 'Running linter...'")
  .command("sleep 0.5")

Topia.task("test")
  .describe("Execute test suite with coverage reporting")
  .depends_on(["setup", "lint"])
  .command("echo 'Running tests...'")
  .command("sleep 1")

Topia.task("build")
  .describe("Compile and bundle the application")
  .depends_on("test")
  .command("echo 'Building application...'")
  .command("sleep 0.8")

Topia.task("deploy")
  .describe("Deploy application to production environment")
  .depends_on("build")
  .command("echo 'Deploying to production...'")
  .command("sleep 0.3")

# Create a file processing task
Topia.task("process-files")
  .describe("Process and transform source files")
  .src("./spec/support/*.txt")
  .dist("./tmp/processed/")

# Set default tasks
Topia.default(["lint", "test"])

puts "✓ Created 6 tasks with descriptions and dependencies"

# 2. CLI Feature Examples
puts "\n2. CLI Feature Examples:"
puts "Run these commands to test different CLI features:\n"

examples = [
  "Basic Operations:",
  "  topia -l                      # List all tasks",
  "  topia --list-detailed         # Detailed task information",
  "  topia build                   # Run single task",
  "  topia lint test build         # Run multiple tasks",
  "",
  "Output Control:",
  "  topia -q build                # Quiet mode (errors only)",
  "  topia --verbose build         # Verbose output",
  "  topia -d build                # Debug mode with detailed logs",
  "  topia --no-color build        # Disable colored output",
  "",
  "Execution Modes:",
  "  topia -p lint test build      # Parallel execution",
  "  topia -j 2 -p lint test       # Parallel with 2 jobs",
  "  topia --dry-run deploy        # Show execution plan",
  "  topia -w build                # Watch mode (continuous)",
  "  topia -i                      # Interactive task selection",
  "",
  "Configuration:",
  "  topia --init                  # Create sample config",
  "  topia --validate-config       # Validate configuration",
  "  topia -c custom.yml build     # Use custom config",
  "",
  "Information & Analysis:",
  "  topia --dependencies build    # Show task dependencies",
  "  topia --where setup           # Show task definition location",
  "  topia --stats build           # Show execution statistics",
  "  topia --profile build         # Enable performance profiling",
  "",
  "Advanced Features:",
  "  topia --help                  # Comprehensive help",
  "  topia --version               # Version information",
]

examples.each { |line| puts line }

# 3. Demo configuration validation
puts "\n3. Configuration Management Demo:"

# Create a sample configuration file
config_content = <<-YAML
# Topia Configuration Example
version: "1.0"
debug: false

# Global settings
settings:
  parallel_jobs: 4
  watch_polling_interval: 1000
  cache_enabled: true

# Default tasks to run when no tasks specified
default_tasks:
  - "lint"
  - "test"

# Task definitions and overrides
tasks:
  build:
    description: "Compile application with optimizations"
    dependencies: ["test"]
    commands:
      - "echo 'Building with config...'"
      - "crystal build --release src/main.cr"

  deploy:
    description: "Deploy to production with health checks"
    dependencies: ["build"]
    environment:
      NODE_ENV: "production"
    commands:
      - "echo 'Deploying with health checks...'"

# Environment-specific configurations
environments:
  development:
    debug: true
    parallel_jobs: 2

  production:
    debug: false
    parallel_jobs: 8
    cache_enabled: true

YAML

begin
  File.write("demo-config.yml", config_content)
  puts "✓ Created demo-config.yml"
  puts "  Use: topia -c demo-config.yml --validate-config"
rescue ex
  puts "✗ Failed to create config: #{ex.message}"
end

# 4. Interactive CLI Simulation
puts "\n4. CLI Output Examples:"

# Simulate different output modes
puts "\nQuiet Mode Example (-q):"
puts "  (Only errors would be shown)"

puts "\nVerbose Mode Example (--verbose):"
puts "  ℹ Running task 1/3: lint".colorize(:cyan)
puts "  ✓ Task 'lint' completed in 245ms".colorize(:green)
puts "  ℹ Running task 2/3: test".colorize(:cyan)
puts "  ✓ Task 'test' completed in 1.2s".colorize(:green)

puts "\nDebug Mode Example (-d):"
puts "  DEBUG: Loading configuration from topia.yml".colorize(:dark_gray)
puts "  DEBUG: Task 'build' dependencies: [test]".colorize(:dark_gray)
puts "  DEBUG: Starting parallel execution with 4 jobs".colorize(:dark_gray)

puts "\nStatistics Example (--stats):"
puts "  Execution Statistics:".colorize(:cyan)
puts "    Total time: 2.1s"
puts "    Tasks executed: 3"
puts "    Execution mode: Parallel"
puts "    Jobs: 4"

# 5. Developer Productivity Features
puts "\n5. Developer Productivity Features:"

productivity_features = [
  "✓ Comprehensive help system with examples",
  "✓ Interactive task selection for exploration",
  "✓ Configuration validation with helpful errors",
  "✓ Detailed task information and dependencies",
  "✓ Performance monitoring and statistics",
  "✓ Multiple output modes (quiet/verbose/debug)",
  "✓ Watch mode for continuous development",
  "✓ Parallel execution with job control",
  "✓ Task source location tracking",
  "✓ Error handling with actionable messages",
]

productivity_features.each { |feature| puts "  #{feature}" }

# 6. Best Practices
puts "\n6. Development Best Practices:"

best_practices = [
  "📝 Always add descriptions to tasks using .describe()",
  "🔗 Use dependencies to ensure proper execution order",
  "⚡ Leverage parallel execution for independent tasks",
  "👀 Use watch mode during active development",
  "🔍 Enable debug mode when troubleshooting",
  "📊 Review statistics to optimize build times",
  "⚙️ Validate configuration before deployment",
  "🎯 Use interactive mode to explore available tasks",
]

best_practices.each { |practice| puts "  #{practice}" }

# 7. Advanced Usage Patterns
puts "\n7. Advanced Usage Patterns:"

puts "  Complex Workflow:"
puts "    topia -p -j 8 --stats --verbose lint test build deploy"
puts ""
puts "  Development Workflow:"
puts "    topia -w --verbose build  # Continuous building"
puts ""
puts "  CI/CD Pipeline:"
puts "    topia -q --validate-config && topia -p --stats lint test build"
puts ""
puts "  Debugging Workflow:"
puts "    topia -d --where failing-task  # Debug specific task"

puts "\n8. Performance & Monitoring:"

# Show task execution statistics if any exist
if Topia.available_tasks.any?
  puts "  Available tasks: #{Topia.available_tasks.size}"
  puts "  Default tasks: #{Topia.default_tasks.join(", ")}" unless Topia.default_tasks.empty?

  puts "\n  Task Dependencies:"
  Topia.available_tasks.each do |task|
    deps = Topia.task_dependencies(task.name)
    if deps.any?
      puts "    #{task.name}: #{deps.join(" → ")}"
    end
  end
end

puts "\n" + "=" * 50
puts "🎉 Developer Experience Demo Complete!".colorize(:green)
puts "\nNext Steps:"
puts "1. Try the CLI commands shown above"
puts "2. Create your own tasks with descriptions"
puts "3. Use configuration files for complex setups"
puts "4. Leverage parallel execution for faster builds"
puts "5. Monitor performance with --stats"

# Cleanup
at_exit do
  begin
    File.delete("demo-config.yml") if File.exists?("demo-config.yml")
    Dir.delete("tmp/build") if Dir.exists?("tmp/build")
    Dir.delete("tmp/processed") if Dir.exists?("tmp/processed")
    Dir.delete("tmp") if Dir.exists?("tmp")
  rescue
    # Ignore cleanup errors
  end
end
