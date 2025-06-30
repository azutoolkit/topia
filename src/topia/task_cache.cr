require "digest/sha256"
require "json"
require "file_utils"

module Topia
  # High-performance task result caching with intelligent invalidation
  class TaskCache
    struct CacheEntry
      include JSON::Serializable

      property task_name : String
      property input_hash : String
      property output_hash : String
      property timestamp : Int64
      property dependencies : Array(String)
      property file_dependencies : Array(String)
      property success : Bool
      property result_data : String?

      def initialize(@task_name : String, @input_hash : String, @output_hash : String,
                     @dependencies : Array(String), @file_dependencies : Array(String),
                     @success : Bool, @result_data : String? = nil)
        @timestamp = Time.utc.to_unix
      end

      def expired?(max_age : Time::Span) : Bool
        Time.utc.to_unix - @timestamp > max_age.total_seconds
      end
    end

    @cache_dir : String
    @cache_entries : Hash(String, CacheEntry)
    @max_age : Time::Span
    @max_entries : Int32

    def initialize(@cache_dir = ".topia/cache", @max_age = 24.hours, @max_entries = 1000)
      @cache_entries = {} of String => CacheEntry
      setup_cache_directory
      load_cache_entries
    end

    def cache_key(task_name : String, input_data : String, dependencies : Array(String)) : String
      content = "#{task_name}:#{input_data}:#{dependencies.sort.join(",")}"
      Digest::SHA256.hexdigest(content)
    end

    def get(task_name : String, input_data : String, dependencies : Array(String)) : CacheEntry?
      key = cache_key(task_name, input_data, dependencies)
      entry = @cache_entries[key]?

      return nil unless entry
      return nil if entry.expired?(@max_age)
      return nil unless valid_dependencies?(entry)

      entry
    end

    def put(task_name : String, input_data : String, output_data : String,
            dependencies : Array(String), file_dependencies : Array(String),
            success : Bool, result_data : String? = nil)

      key = cache_key(task_name, input_data, dependencies)
      input_hash = Digest::SHA256.hexdigest(input_data)
      output_hash = Digest::SHA256.hexdigest(output_data)

      entry = CacheEntry.new(
        task_name: task_name,
        input_hash: input_hash,
        output_hash: output_hash,
        dependencies: dependencies,
        file_dependencies: file_dependencies,
        success: success,
        result_data: result_data
      )

      @cache_entries[key] = entry

      # Maintain cache size
      cleanup_old_entries if @cache_entries.size > @max_entries

      # Persist to disk
      save_cache_entry(key, entry)
    end

    def invalidate(task_name : String)
      keys_to_remove = [] of String

      @cache_entries.each do |key, entry|
        if entry.task_name == task_name || entry.dependencies.includes?(task_name)
          keys_to_remove << key
        end
      end

      keys_to_remove.each do |key|
        @cache_entries.delete(key)
        remove_cache_file(key)
      end
    end

    def invalidate_by_files(changed_files : Array(String))
      keys_to_remove = [] of String

      @cache_entries.each do |key, entry|
        if files_overlap?(entry.file_dependencies, changed_files)
          keys_to_remove << key
        end
      end

      keys_to_remove.each do |key|
        @cache_entries.delete(key)
        remove_cache_file(key)
      end
    end

    def clear
      FileUtils.rm_rf(@cache_dir)
      setup_cache_directory
      @cache_entries.clear
    end

    def stats : NamedTuple(entries: Int32, size_mb: Float64, hit_rate: Float64)
      size_bytes = 0_i64

      Dir.glob(File.join(@cache_dir, "*.json")) do |file|
        size_bytes += File.size(file)
      end

      {
        entries: @cache_entries.size,
        size_mb: size_bytes / (1024.0 * 1024.0),
        hit_rate: calculate_hit_rate
      }
    end

    private def setup_cache_directory
      FileUtils.mkdir_p(@cache_dir)
    end

    private def load_cache_entries
      @cache_entries = {} of String => CacheEntry

      return unless Dir.exists?(@cache_dir)

      Dir.glob(File.join(@cache_dir, "*.json")) do |file|
        begin
          content = File.read(file)
          entry = CacheEntry.from_json(content)
          key = File.basename(file, ".json")
          @cache_entries[key] = entry
        rescue
          # Remove corrupted cache files
          File.delete(file)
        end
      end
    end

    private def save_cache_entry(key : String, entry : CacheEntry)
      file_path = File.join(@cache_dir, "#{key}.json")
      File.write(file_path, entry.to_json)
    end

    private def remove_cache_file(key : String)
      file_path = File.join(@cache_dir, "#{key}.json")
      File.delete(file_path) if File.exists?(file_path)
    end

    private def valid_dependencies?(entry : CacheEntry) : Bool
      # Check if any dependency tasks have been modified
      entry.dependencies.each do |dep_task|
        # This would need to be integrated with the task system
        # to check if dependency tasks have been modified
      end

      # Check file dependencies
      entry.file_dependencies.each do |file_path|
        return false unless File.exists?(file_path)

        begin
          current_mtime = File.info(file_path).modification_time.to_unix
          if current_mtime > entry.timestamp
            return false
          end
        rescue
          return false
        end
      end

      true
    end

    private def files_overlap?(file_deps : Array(String), changed_files : Array(String)) : Bool
      file_deps.any? do |dep_file|
        changed_files.any? { |changed| File.same?(dep_file, changed) rescue false }
      end
    end

    private def cleanup_old_entries
      # Remove oldest entries first
      sorted_entries = @cache_entries.to_a.sort_by { |_, entry| entry.timestamp }

      entries_to_remove = sorted_entries.first(@cache_entries.size - @max_entries + 100)
      entries_to_remove.each do |key, _|
        @cache_entries.delete(key)
        remove_cache_file(key)
      end
    end

    private def calculate_hit_rate : Float64
      # This would need to be tracked during actual usage
      # For now, return a placeholder
      0.0
    end
  end

  # Cache-aware task executor with performance optimizations
  class CachedTaskExecutor
    @cache : TaskCache
    @hit_count : Int32
    @miss_count : Int32

    def initialize(cache_dir = ".topia/cache")
      @cache = TaskCache.new(cache_dir)
      @hit_count = 0
      @miss_count = 0
    end

    def execute_with_cache(task : Task, input_data : String = "", file_dependencies : Array(String) = [] of String)
      task_name = task.name
      dependencies = DependencyManager.get_dependencies(task_name)

      # Check cache first
      if cached_result = @cache.get(task_name, input_data, dependencies)
        @hit_count += 1
        puts "✓ Cache hit for task '#{task_name}'".colorize(:green)
        return cached_result.result_data
      end

      @miss_count += 1
      puts "⚡ Executing task '#{task_name}' (cache miss)".colorize(:yellow)

      # Execute task
      start_time = Time.utc
      success = false
      result_data : String? = nil

      begin
        # This would integrate with the actual task execution
        task.run
        success = true
        result_data = "Task completed successfully"
      rescue ex
        success = false
        result_data = ex.message
        raise ex
      ensure
        end_time = Time.utc
        execution_time = end_time - start_time

        # Cache the result
        output_data = result_data || ""
        @cache.put(
          task_name: task_name,
          input_data: input_data,
          output_data: output_data,
          dependencies: dependencies,
          file_dependencies: file_dependencies,
          success: success,
          result_data: result_data
        )

        puts "⏱ Task '#{task_name}' executed in #{execution_time.total_milliseconds.round(2)}ms".colorize(:cyan)
      end

      result_data
    end

    def invalidate_cache(task_name : String)
      @cache.invalidate(task_name)
    end

    def invalidate_by_files(changed_files : Array(String))
      @cache.invalidate_by_files(changed_files)
    end

    def cache_stats
      stats = @cache.stats
      hit_rate = @hit_count.to_f / (@hit_count + @miss_count) * 100

      {
        cache_entries: stats[:entries],
        cache_size_mb: stats[:size_mb],
        cache_hit_rate: hit_rate,
        total_hits: @hit_count,
        total_misses: @miss_count
      }
    end

    def clear_cache
      @cache.clear
      @hit_count = 0
      @miss_count = 0
    end
  end

  # Global cache instance for easy access
  @@cached_executor : CachedTaskExecutor?

  def self.cached_executor
    @@cached_executor ||= CachedTaskExecutor.new
  end

  def self.cache_stats
    cached_executor.cache_stats
  end

  def self.clear_cache
    cached_executor.clear_cache
  end
end
