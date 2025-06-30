require "../src/topia"

# Example of a modern plugin using the new architecture
class TextProcessor < Topia::BasePlugin
  def run(input, args = [] of String)
    announce "Processing text input..."

    result = case input
             when String
               input.upcase
             when Array(Topia::InputFile)
               input.map do |file|
                 file.contents = file.contents.upcase
                 file
               end
             else
               success "No processing needed for #{input.class}"
               input
             end

    success "Text processing complete!"
    result
  end
end

# Example of using the refactored components directly
puts "=== Refactored Topia Components Demo ==="

# 1. Type-safe Pipeline Demo
puts "\n1. Type-safe Pipeline:"
pipeline = Topia::Pipe(String).new("hello world")
puts "Pipeline value: #{pipeline.value}"
puts "Pipeline type: #{pipeline.type_name}"

# 2. Pipeline Builder Demo
puts "\n2. Pipeline Builder:"
builder = Topia::PipelineBuilder.new
result_pipeline = builder.start("hello").build
puts "Builder result: #{result_pipeline.try(&.value)}"

# 3. Command Executor Demo
puts "\n3. Command Executor:"
executor = Topia::CommandExecutor.new
executor.add_command("echo 'Hello from CommandExecutor'")
puts "Commands added: #{executor.commands.size}"
puts "First command: #{executor.commands.first.name} #{executor.commands.first.args.join(" ")}"

# 4. File Distributor Demo (dry run)
puts "\n4. File Distributor:"
distributor = Topia::FileDistributor.new
test_files = [
  Topia::InputFile.new("test1.txt", "/tmp/", "content1"),
  Topia::InputFile.new("test2.txt", "/tmp/", "content2"),
]
puts "FileDistributor ready to distribute #{test_files.size} files"

# 5. Task Watcher Demo
puts "\n5. Task Watcher:"
watcher = Topia::TaskWatcher.new
watcher.configure("/tmp/watch_test")
puts "Watcher configured for: #{watcher.watch_path}"
puts "Watching enabled: #{watcher.watching}"

# 6. Plugin Architecture Demo
puts "\n6. Plugin Architecture:"
plugin = TextProcessor.new
result = Topia::PluginLifecycle.run_plugin(plugin, "hello world", [] of String) do
  # Plugin execution callback
end
puts "Plugin result: #{result}"

# 7. Plugin Utilities Demo
puts "\n7. Plugin Utilities:"
Topia::PluginUtils.announce("This is an announcement")
Topia::PluginUtils.success("This is a success message")

puts "\n=== Demo Complete ==="
puts "\nKey improvements in the refactored architecture:"
puts "✓ Type-safe pipelines with proper error handling"
puts "✓ Separated concerns (CommandExecutor, FileDistributor, TaskWatcher)"
puts "✓ Clean plugin architecture with lifecycle management"
puts "✓ Better error handling and validation"
puts "✓ Dependency injection for utilities"
puts "✓ Single Responsibility Principle adherence"
