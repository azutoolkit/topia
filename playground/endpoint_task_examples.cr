require "../src/topia"
require "./tasks/generator"

puts "=== Endpoint Generation Task Examples ===".colorize(:cyan)
puts ""

# Clean up endpoints directory
if Dir.exists?("./playground/endpoints")
  Dir.glob("./playground/endpoints/*.cr").each { |f| File.delete(f) }
else
  Dir.mkdir_p("./playground/endpoints")
end

# ============================================================================
# YOUR ORIGINAL TASK PATTERN
# ============================================================================
puts "🔄 Your Original Task Pattern:".colorize(:green)
puts ""

# This is your original task
original_task = Topia.task("azu.endpoint")
  .pipe(Generator.new)
  .command("mkdir -p ./playground/endpoints")

puts "   ✓ Original task created: #{original_task.name}".colorize(:white)
puts ""

# ============================================================================
# ENHANCED ENDPOINT GENERATION PATTERNS
# ============================================================================
puts "🚀 Enhanced Endpoint Generation Patterns:".colorize(:green)
puts ""

# 1. Endpoint generation with setup dependencies
setup_endpoints_task = Topia.task("setup_endpoints")
  .command("mkdir -p ./playground/endpoints")
  .command("echo 'Endpoints directory ready'")

endpoint_with_setup = Topia.task("generate_with_setup")
  .depends_on("setup_endpoints")
  .pipe(Generator.new)
  .command("echo 'Endpoint generation complete'")

puts "   ✓ Setup + Generate pattern: #{endpoint_with_setup.name}".colorize(:white)

# 2. Multiple endpoint types
api_endpoints = [
  {name: "user", route: "GET:/api/users/:id", req: "GetUserRequest", res: "UserResponse"},
  {name: "post", route: "POST:/api/posts", req: "CreatePostRequest", res: "PostResponse"},
  {name: "comment", route: "PUT:/api/comments/:id", req: "UpdateCommentRequest", res: "CommentResponse"},
]

api_endpoints.each do |endpoint|
  task_name = "generate_#{endpoint[:name]}_endpoint"
  endpoint_task = Topia.task(task_name)
    .depends_on("setup_endpoints")
    .pipe(Generator.new)
    .command("echo 'Generated #{endpoint[:name]} endpoint'")

  puts "   ✓ Dynamic endpoint task: #{task_name}".colorize(:white)
end

# 3. Batch endpoint generation
batch_generate = Topia.task("generate_all_endpoints")
  .depends_on("setup_endpoints")
  .pipe(Generator.new)
  .command("echo 'All endpoints generated'")

puts "   ✓ Batch generation task: #{batch_generate.name}".colorize(:white)

# 4. Development workflow with watching
dev_endpoints = Topia.task("dev_endpoints")
  .depends_on("setup_endpoints")
  .watch("./spec/support/*.txt", read_sources: true) # Watch for spec changes
  .pipe(Generator.new)
  .command("echo 'Development endpoints updated'")

puts "   ✓ Development watch task: #{dev_endpoints.name}".colorize(:white)

# 5. Endpoint generation with validation
validated_endpoints = Topia.task("generate_validated_endpoints")
  .depends_on("setup_endpoints")
  .pipe(Generator.new)
  .command("echo 'Validating generated endpoints...'")
  .command("echo 'All endpoints validated successfully'")

puts "   ✓ Validated generation task: #{validated_endpoints.name}".colorize(:white)

puts ""

# ============================================================================
# PRACTICAL USAGE EXAMPLES
# ============================================================================
puts "📝 Practical Usage Examples:".colorize(:yellow)
puts ""

# Example 1: Generate a specific endpoint
puts "1. Generate a single endpoint:".colorize(:cyan)
generator = Generator.new
result = generator.run("sample", ["UserProfile", "GET:/api/users/:id", "GetUserRequest", "UserResponse"])
if result
  puts "   ✓ UserProfile endpoint generated".colorize(:green)
else
  puts "   ✗ Generation failed".colorize(:red)
end

# Example 2: Generate multiple endpoints programmatically
puts ""
puts "2. Generate multiple endpoints:".colorize(:cyan)
endpoints_config = [
  ["Dashboard", "GET:/dashboard", "DashboardRequest", "DashboardResponse"],
  ["Settings", "PUT:/settings", "UpdateSettingsRequest", "SettingsResponse"],
  ["Profile", "GET:/profile", "GetProfileRequest", "ProfileResponse"],
]

endpoints_config.each do |config|
  name, route, req, res = config
  result = generator.run("endpoint", [name, route, req, res])
  if result
    puts "   ✓ #{name} endpoint generated".colorize(:green)
  else
    puts "   ✗ #{name} generation failed".colorize(:red)
  end
end

puts ""

# ============================================================================
# SHOW GENERATED FILES
# ============================================================================
puts "📁 Generated Endpoint Files:".colorize(:cyan)
puts ""

Dir.glob("./playground/endpoints/*.cr").each do |file|
  puts "   📄 #{File.basename(file)}".colorize(:white)
end

if Dir.glob("./playground/endpoints/*.cr").any?
  puts ""
  puts "📖 Sample Generated Content:".colorize(:cyan)
  sample_file = Dir.glob("./playground/endpoints/*.cr").first
  puts "File: #{File.basename(sample_file)}".colorize(:dark_gray)
  puts "-" * 50
  puts File.read(sample_file)
  puts "-" * 50
end

puts ""

# ============================================================================
# TASK EXECUTION EXAMPLES
# ============================================================================
puts "⚙️  Task Execution Examples:".colorize(:yellow)
puts ""

puts "Execute individual tasks:"
puts "   Topia.run(\"setup_endpoints\")".colorize(:green)
puts "   Topia.run(\"generate_with_setup\")".colorize(:green)
puts "   Topia.run(\"generate_all_endpoints\")".colorize(:green)
puts ""

puts "Execute with dependencies (automatic resolution):"
puts "   Topia.run(\"generate_validated_endpoints\")  # Runs setup_endpoints first".colorize(:green)
puts ""

puts "Execute multiple tasks in parallel:"
puts "   Topia.run_parallel([\"generate_user_endpoint\", \"generate_post_endpoint\"])".colorize(:green)
puts ""

puts "Start development mode with watching:"
puts "   Topia.run(\"dev_endpoints\")  # Watches for changes and regenerates".colorize(:green)
puts ""

# ============================================================================
# TASK LIST WITH DEPENDENCIES
# ============================================================================
puts "📋 All Available Endpoint Tasks:".colorize(:cyan)
puts ""

Topia.available_tasks.each do |task|
  next unless task.name.includes?("endpoint") || task.name.includes?("azu") || task.name.includes?("setup")

  dependencies = Topia.task_dependencies(task.name)
  if dependencies.empty?
    puts "   • #{task.name}".colorize(:white)
  else
    puts "   • #{task.name} (depends on: #{dependencies.join(", ")})".colorize(:white)
  end
end

puts ""
puts "=== Endpoint Generation Examples Complete ===".colorize(:cyan)
puts ""
puts "💡 Key Takeaways:".colorize(:yellow)
puts "   ✅ Use .pipe(Generator.new) for endpoint generation".colorize(:green)
puts "   ✅ Add .depends_on() for setup tasks".colorize(:green)
puts "   ✅ Chain .command() for additional operations".colorize(:green)
puts "   ✅ Use .watch() for development workflows".colorize(:green)
puts "   ✅ Create dynamic tasks in loops for bulk operations".colorize(:green)
