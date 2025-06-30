require "../src/topia"
require "../src/topia/async_spinner"
require "../src/topia/async_watcher"
require "../src/topia/task_cache"
require "../src/topia/concurrent_executor"

puts "=== Topia Performance Improvements Demo ===".colorize(:cyan)
puts ""

# 1. Async Spinner Demo
puts "1. 🔄 High-Performance Non-Blocking Spinner".colorize(:yellow)
puts "   • Uses Crystal's select for non-blocking operations"
puts "   • Eliminates CPU-intensive loops"
puts "   • Supports concurrent spinner management"
puts ""

spinner = Topia::AsyncSpinner.new("Demonstrating async spinner...")
spinner.start

sleep(1.second)
spinner.message = "Updated message during execution"
sleep(0.5.seconds)

spinner.success("Async spinner demonstration complete!")

# Spinner Pool Demo
puts ""
puts "2. 🎛 Spinner Pool for Multiple Operations".colorize(:yellow)

pool = Topia::SpinnerPool.new
pool.create("demo1", "Operation 1")
pool.create("demo2", "Operation 2")
pool.create("demo3", "Operation 3")

pool.start("demo1")
pool.start("demo2")
pool.start("demo3")

puts "   Active spinners: #{pool.active_count}"

sleep(0.5.seconds)
pool.success("demo1", "Operation 1 completed")
sleep(0.3.seconds)
pool.success("demo2", "Operation 2 completed")
sleep(0.2.seconds)
pool.success("demo3", "Operation 3 completed")

puts "   All operations completed!"
puts ""

# 2. Async File Watcher Demo
puts "3. 📁 High-Performance File System Watcher".colorize(:yellow)
puts "   • Platform-specific file system events (when available)"
puts "   • Intelligent debouncing to prevent excessive callbacks"
puts "   • Optimized polling fallback with smart caching"
puts "   • Efficient change detection algorithms"

# Create a test file to watch
test_file = File.tempname("topia_watch_demo", ".txt")
File.write(test_file, "Initial content")

watcher = Topia::AsyncWatcher.new([test_file], 100.milliseconds)

puts "   Watching file: #{test_file}"
puts "   Debounce time: 100ms for optimal performance"

# Start watching in a separate fiber
watch_fiber = spawn do
  watcher.watch([test_file]) do |changed_files|
    puts "   ✓ File change detected: #{changed_files.join(", ")}".colorize(:green)
  end
end

sleep(0.1.seconds)

# Modify the file to trigger watcher
File.write(test_file, "Modified content")
sleep(0.2.seconds)

watcher.stop
sleep(50.milliseconds)  # Let watcher fiber finish
File.delete(test_file)

puts "   File watcher demonstration complete!"
puts ""

# 3. Task Caching Demo
puts "4. 🗂 Advanced Task Result Caching".colorize(:yellow)
puts "   • SHA256-based cache keys for consistency"
puts "   • Intelligent dependency invalidation"
puts "   • File modification time tracking"
puts "   • Persistent cache with JSON serialization"

cache = Topia::TaskCache.new(".demo_cache")

# Simulate caching a task result
puts "   Caching task result..."
cache.put(
  task_name: "demo_build",
  input_data: "source files",
  output_data: "compiled binary",
  dependencies: ["clean", "compile"],
  file_dependencies: ["src/main.cr", "src/lib.cr"],
  success: true,
  result_data: "Build completed "
)

# Retrieve from cache
puts "   Retrieving from cache..."
if cached_result = cache.get("demo_build", "source files", ["clean", "compile"])
  puts "   ✓ Cache hit! Task: #{cached_result.task_name}".colorize(:green)
  puts "     Success: #{cached_result.success}"
  puts "     Result: #{cached_result.result_data}"
else
  puts "   ✗ Cache miss".colorize(:red)
end

# Show cache statistics
stats = cache.stats
puts "   📊 Cache Stats:"
puts "     Entries: #{stats[:entries]}"
puts "     Size: #{stats[:size_mb].round(3)} MB"
puts ""

# 4. Concurrent Execution Demo
puts "5. ⚡ Enhanced Concurrent Task Execution".colorize(:yellow)
puts "   • Dependency-aware parallelization using Crystal Fibers"
puts "   • Advanced job scheduling with priority support"
puts "   • Real-time progress monitoring"
puts "   • Intelligent retry logic with exponential backoff"

# Clear previous tasks
Topia.clear_tasks

# Create a complex task dependency graph
task1 = Topia.task("setup").command("echo 'Setting up environment'")
task2 = Topia.task("compile").depends_on("setup").command("echo 'Compiling source code'")
task3 = Topia.task("test").depends_on("compile").command("echo 'Running tests'")
task4 = Topia.task("lint").depends_on("setup").command("echo 'Running linter'")
task5 = Topia.task("package").depends_on(["test", "lint"]).command("echo 'Creating package'")

tasks = [task1, task2, task3, task4, task5]

puts "   Task dependency graph:"
puts "     setup → compile → test ↘"
puts "     setup → lint --------→ package"
puts ""

# Execute with concurrent executor
executor = Topia::ConcurrentExecutor.new(max_concurrent: 3)

puts "   Starting concurrent execution with 3 workers..."
stats = executor.execute_concurrent(tasks, use_cache: true, show_progress: false)

puts ""
puts "   📊 Execution Statistics:"
puts "     Total tasks: #{stats.total_tasks}"
puts "     Completed: #{stats.completed_tasks}"
puts "     Failed: #{stats.failed_tasks}"
puts "     Success rate: #{stats.success_rate.round(1)}%"
puts "     Total duration: #{stats.total_duration.total_milliseconds.round(2)}ms"
puts "     Average duration: #{stats.average_duration.total_milliseconds.round(2)}ms"
puts "     Max concurrent: #{stats.max_concurrent}"

# Cache statistics
cache_stats = executor.cache_stats
puts ""
puts "   📈 Cache Performance:"
puts "     Cache entries: #{cache_stats[:cache_entries]}"
puts "     Cache size: #{cache_stats[:cache_size_mb].round(3)} MB"
puts "     Hit rate: #{cache_stats[:cache_hit_rate].round(1)}%"
puts "     Total hits: #{cache_stats[:total_hits]}"
puts "     Total misses: #{cache_stats[:total_misses]}"

puts ""
puts "=== Performance Improvements Summary ===".colorize(:cyan)
puts ""

puts "✅ Async Spinner System:"
puts "   • Non-blocking operations using Crystal's select"
puts "   • Eliminated CPU-intensive polling loops"
puts "   • Support for multiple concurrent spinners"
puts "   • Real-time message updates without blocking"
puts ""

puts "✅ High-Performance File Watcher:"
puts "   • Platform-specific file system events (macOS FSEvents, Linux inotify)"
puts "   • Intelligent debouncing prevents excessive callbacks"
puts "   • Optimized polling fallback with smart file caching"
puts "   • Efficient change detection algorithms"
puts ""

puts "✅ Advanced Task Result Caching:"
puts "   • SHA256-based cache keys ensure consistency"
puts "   • Intelligent dependency invalidation"
puts "   • File modification time tracking"
puts "   • Persistent cache with JSON serialization"
puts "   • Automatic cache size management"
puts ""

puts "✅ Enhanced Concurrent Execution:"
puts "   • Dependency-aware parallelization using Crystal Fibers"
puts "   • Worker pool with configurable concurrency limits"
puts "   • Advanced job scheduling with priority support"
puts "   • Real-time progress monitoring and statistics"
puts "   • Intelligent retry logic with exponential backoff"
puts "   • Integration with caching system for optimal performance"

puts ""
puts "🚀 Performance Gains Achieved:".colorize(:green)
puts "   • Eliminated CPU-intensive polling in spinner and watcher"
puts "   • Reduced file system overhead with smart caching"
puts "   • Improved task execution speed with intelligent caching"
puts "   • Maximized CPU utilization with concurrent execution"
puts "   • Enhanced user experience with real-time progress updates"

# Cleanup
cache.clear
FileUtils.rm_rf(".demo_cache") if Dir.exists?(".demo_cache")

puts ""
puts "Demo completed successfully! 🎉".colorize(:green)
