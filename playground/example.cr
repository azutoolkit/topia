require "../src/topia"
require "./tasks/*"

puts "=== Topia Task Creation Guide ===".colorize(:cyan)
puts ""

# Create output directory for examples
Dir.mkdir_p("./playground/endpoints") unless Dir.exists?("./playground/endpoints")
Dir.mkdir_p("./playground/output") unless Dir.exists?("./playground/output")

puts "📚 Methods for Creating Tasks Programmatically:".colorize(:yellow)
puts ""

# ============================================================================
# 1. BASIC TASK CREATION
# ============================================================================
puts "1️⃣  Basic Task Creation".colorize(:green)
puts ""

# Simple task with just a name
basic_task = Topia.task("hello")
puts "   Created basic task: #{basic_task.name}".colorize(:white)

# Task with a command
command_task = Topia.task("build")
  .command("echo 'Building project...'")
puts "   Created command task: #{command_task.name}".colorize(:white)

# Task with multiple commands (chained)
multi_command_task = Topia.task("deploy")
  .command("echo 'Running tests...'")
  .command("echo 'Building application...'")
  .command("echo 'Deploying to server...'")
puts "   Created multi-command task: #{multi_command_task.name}".colorize(:white)

puts ""

# ============================================================================
# 2. PLUGIN PIPELINE TASKS
# ============================================================================
puts "2️⃣  Plugin Pipeline Tasks".colorize(:green)
puts ""

# Task with a plugin
plugin_task = Topia.task("generate")
  .pipe(Generator.new)
  .command("echo 'Generation complete'")
puts "   Created plugin task: #{plugin_task.name}".colorize(:white)

# Task with multiple plugins (pipeline)
# Note: In a real scenario, you'd have multiple compatible plugins
multi_plugin_task = Topia.task("process")
  .pipe(Generator.new)
  .command("echo 'Processing complete'")
puts "   Created multi-plugin task: #{multi_plugin_task.name}".colorize(:white)

puts ""

# ============================================================================
# 3. FILE PROCESSING TASKS
# ============================================================================
puts "3️⃣  File Processing Tasks".colorize(:green)
puts ""

# Create some test files first
test_files = ["test1.txt", "test2.txt", "test3.txt"]
test_files.each do |file|
  File.write("./playground/#{file}", "Sample content for #{file}")
end

# Task that processes files from source to destination
file_task = Topia.task("copy_files")
  .src("./playground/*.txt")
  .dist("./playground/output/")
puts "   Created file processing task: #{file_task.name}".colorize(:white)

# Task that processes files with a plugin
file_plugin_task = Topia.task("process_files")
  .src("./playground/*.txt")
  .pipe(Generator.new)
  .dist("./playground/output/")
puts "   Created file+plugin task: #{file_plugin_task.name}".colorize(:white)

puts ""

# ============================================================================
# 4. DEPENDENCY TASKS
# ============================================================================
puts "4️⃣  Task Dependencies".colorize(:green)
puts ""

# Tasks with dependencies
setup_task = Topia.task("setup")
  .command("echo 'Setting up environment...'")
puts "   Created setup task: #{setup_task.name}".colorize(:white)

test_task = Topia.task("test")
  .depends_on("setup")
  .command("echo 'Running tests...'")
puts "   Created test task (depends on setup): #{test_task.name}".colorize(:white)

integration_task = Topia.task("integration")
  .depends_on(["setup", "test"])
  .command("echo 'Running integration tests...'")
puts "   Created integration task (depends on setup, test): #{integration_task.name}".colorize(:white)

puts ""

# ============================================================================
# 5. WATCHING TASKS
# ============================================================================
puts "5️⃣  File Watching Tasks".colorize(:green)
puts ""

# Task that watches for file changes
watch_task = Topia.task("watch_changes")
  .watch("./playground/*.txt")
  .command("echo 'Files changed, rebuilding...'")
puts "   Created watch task: #{watch_task.name}".colorize(:white)

# Task that watches and reads sources
watch_build_task = Topia.task("watch_build")
  .watch("./playground/*.txt", read_sources: true)
  .pipe(Generator.new)
  .dist("./playground/output/")
puts "   Created watch+build task: #{watch_build_task.name}".colorize(:white)

puts ""

# ============================================================================
# 6. COMPLEX WORKFLOW TASKS
# ============================================================================
puts "6️⃣  Complex Workflow Tasks".colorize(:green)
puts ""

# Complete workflow task
workflow_task = Topia.task("full_workflow")
  .depends_on(["setup"])
  .src("./playground/*.txt")
  .pipe(Generator.new)
  .command("echo 'Post-processing...'")
  .dist("./playground/output/")
puts "   Created full workflow task: #{workflow_task.name}".colorize(:white)

# Development task with watching
dev_task = Topia.task("dev")
  .depends_on(["setup"])
  .watch("./playground/*.txt", read_sources: true)
  .pipe(Generator.new)
  .command("echo 'Development build complete'")
  .dist("./playground/output/")
puts "   Created development task: #{dev_task.name}".colorize(:white)

puts ""

# ============================================================================
# 7. DYNAMIC TASK CREATION
# ============================================================================
puts "7️⃣  Dynamic Task Creation".colorize(:green)
puts ""

# Create tasks programmatically from data
environments = ["dev", "staging", "prod"]
environments.each do |env|
  env_task = Topia.task("deploy_#{env}")
    .depends_on("test")
    .command("echo 'Deploying to #{env} environment...'")
    .command("echo 'Deployment to #{env} complete'")
  puts "   Created dynamic task: #{env_task.name}".colorize(:white)
end

# Create tasks from configuration-like data
task_configs = [
  { name: "lint", command: "echo 'Linting code...'" },
  { name: "format", command: "echo 'Formatting code...'" },
  { name: "audit", command: "echo 'Security audit...'" }
]

task_configs.each do |config|
  dynamic_task = Topia.task(config[:name])
    .command(config[:command])
  puts "   Created configured task: #{dynamic_task.name}".colorize(:white)
end

puts ""

# ============================================================================
# 8. TASK WITH CALLBACK (Advanced)
# ============================================================================
puts "8️⃣  Advanced Task Creation".colorize(:green)
puts ""

# Task with complex workflow
complex_task = Topia.task("complex_workflow")
  .depends_on(["setup", "test"])
  .src("./playground/*.txt")
  .pipe(Generator.new)
  .command("echo 'Complex processing step 1'")
  .command("echo 'Complex processing step 2'")
  .dist("./playground/output/")
puts "   Created complex workflow task: #{complex_task.name}".colorize(:white)

puts ""

# ============================================================================
# SUMMARY AND USAGE
# ============================================================================
puts "📋 Available Tasks Summary:".colorize(:cyan)
puts ""

Topia.available_tasks.each do |task|
  dependencies = Topia.task_dependencies(task.name)
  if dependencies.empty?
    puts "   • #{task.name}".colorize(:white)
  else
    puts "   • #{task.name} (depends on: #{dependencies.join(", ")})".colorize(:white)
  end
end

puts ""
puts "🚀 How to Run Tasks:".colorize(:yellow)
puts ""
puts "   # Run a single task"
puts "   Topia.run(\"task_name\")".colorize(:green)
puts ""
puts "   # Run multiple tasks with dependencies"
puts "   Topia.run_parallel([\"task1\", \"task2\"])".colorize(:green)
puts ""
puts "   # Run with CLI"
puts "   Topia.cli(ARGV)".colorize(:green)
puts ""

puts "💡 Task Creation Patterns:".colorize(:yellow)
puts ""
puts "   ✅ Method Chaining: task.command().pipe().dist()".colorize(:green)
puts "   ✅ Dependencies: task.depends_on([\"dep1\", \"dep2\"])".colorize(:green)
puts "   ✅ File Processing: task.src().pipe().dist()".colorize(:green)
puts "   ✅ Watching: task.watch().pipe().command()".colorize(:green)
puts "   ✅ Dynamic Creation: Loop + Topia.task()".colorize(:green)
puts ""

puts "=== Task Creation Guide Complete ===".colorize(:cyan)

# Clean up test files
test_files.each do |file|
  File.delete("./playground/#{file}") if File.exists?("./playground/#{file}")
end
