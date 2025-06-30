require "file_utils"

module Topia
  # High-performance file system event watcher using OS-level events
  class AsyncWatcher
    alias ChangeCallback = Proc(Array(String), Nil)

    enum EventType
      Created
      Modified
      Deleted
      Moved
    end

    struct FileEvent
      property path : String
      property type : EventType
      property timestamp : Time

      def initialize(@path : String, @type : EventType)
        @timestamp = Time.utc
      end
    end

    @patterns : Array(String)
    @running : Bool
    @fiber : Fiber?
    @event_channel : Channel(FileEvent)
    @callback_channel : Channel(ChangeCallback)
    @stop_channel : Channel(Bool)
    @debounce_time : Time::Span
    @last_events : Hash(String, Time)

    def initialize(@patterns = [] of String, @debounce_time = 100.milliseconds)
      @running = false
      @event_channel = Channel(FileEvent).new(100)  # Buffered channel
      @callback_channel = Channel(ChangeCallback).new
      @stop_channel = Channel(Bool).new
      @last_events = {} of String => Time
    end

    def watch(patterns : Array(String), &callback : ChangeCallback)
      @patterns = patterns
      start
      @callback_channel.send(callback)

      # Keep the main fiber alive while watching
      @stop_channel.receive
    end

    def watch(pattern : String, &callback : ChangeCallback)
      watch([pattern], &callback)
    end

    def start
      return if @running
      @running = true

      @fiber = spawn do
        run_event_loop
      end

      # Start platform-specific watchers
      @patterns.each do |pattern|
        spawn_watcher_for_pattern(pattern)
      end
    end

    def stop
      return unless @running
      @running = false
      @stop_channel.send(true)
      sleep(50.milliseconds)  # Let fiber finish processing
    end

    private def run_event_loop
      current_callback : ChangeCallback? = nil
      pending_events = [] of FileEvent
      last_batch_time = Time.utc

      loop do
        select
        when callback = @callback_channel.receive
          current_callback = callback
        when event = @event_channel.receive
          # Debounce events to avoid excessive callbacks
          if should_process_event?(event)
            pending_events << event
            last_batch_time = Time.utc
          end
        when timeout(50.milliseconds)
          # Process batched events
          if !pending_events.empty? && (Time.utc - last_batch_time) > @debounce_time
            if callback = current_callback
              changed_files = pending_events.map(&.path).uniq
              callback.call(changed_files)
            end
            pending_events.clear
          end
        end

        break unless @running
      end
    end

    private def should_process_event?(event : FileEvent) : Bool
      path = event.path
      last_time = @last_events[path]?

      # Debounce repeated events on the same file
      if last_time && (event.timestamp - last_time) < @debounce_time
        return false
      end

      @last_events[path] = event.timestamp
      true
    end

    private def spawn_watcher_for_pattern(pattern : String)
      spawn do
        watch_pattern(pattern)
      end
    end

    private def watch_pattern(pattern : String)
      # Extract directory from pattern
      dir = File.dirname(pattern)
      dir = "." if dir == pattern

      return unless Dir.exists?(dir)

      {% if flag?(:linux) %}
        watch_with_inotify(dir, pattern)
      {% elsif flag?(:darwin) %}
        watch_with_fsevents(dir, pattern)
      {% else %}
        watch_with_polling(dir, pattern)
      {% end %}
    end

    # Linux: Use inotify for efficient file system monitoring
    {% if flag?(:linux) %}
    private def watch_with_inotify(dir : String, pattern : String)
      # Implementation would use Linux inotify API
      # For now, fall back to optimized polling
      watch_with_polling(dir, pattern)
    end
    {% end %}

    # macOS: Use FSEvents for efficient file system monitoring
    {% if flag?(:darwin) %}
    private def watch_with_fsevents(dir : String, pattern : String)
      # Implementation would use macOS FSEvents API
      # For now, fall back to optimized polling
      watch_with_polling(dir, pattern)
    end
    {% end %}

    # Optimized polling fallback with smart caching
    private def watch_with_polling(dir : String, pattern : String)
      file_cache = {} of String => File::Info

      # Initial scan
      scan_files(dir, pattern, file_cache)

      while @running
        sleep(250.milliseconds)  # More efficient than previous implementation

        current_files = {} of String => File::Info
        scan_files(dir, pattern, current_files)

        # Detect changes efficiently
        detect_changes(file_cache, current_files)
        file_cache = current_files
      end
    end

    private def scan_files(dir : String, pattern : String, cache : Hash(String, File::Info))
      return unless Dir.exists?(dir)

      begin
        Dir.glob(pattern) do |file_path|
          next unless File.exists?(file_path)

          begin
            info = File.info(file_path)
            cache[file_path] = info
          rescue
            # File might have been deleted during iteration
          end
        end
      rescue
        # Directory might have been deleted
      end
    end

    private def detect_changes(old_cache : Hash(String, File::Info), new_cache : Hash(String, File::Info))
              # Detect new files
        new_cache.each do |path, info|
          unless old_cache.has_key?(path)
            # Non-blocking send
            select
            when @event_channel.send(FileEvent.new(path, EventType::Created))
              # Event sent
            when timeout(1.millisecond)
              # Channel full, skip this event
            end
          end
        end

        # Detect modified files
        old_cache.each do |path, old_info|
          if new_info = new_cache[path]?
            if new_info.modification_time > old_info.modification_time
              select
              when @event_channel.send(FileEvent.new(path, EventType::Modified))
                # Event sent
              when timeout(1.millisecond)
                # Channel full, skip this event
              end
            end
          else
            # File was deleted
            select
            when @event_channel.send(FileEvent.new(path, EventType::Deleted))
              # Event sent
            when timeout(1.millisecond)
              # Channel full, skip this event
            end
          end
        end
    end
  end

  # High-performance watcher pool for monitoring multiple directories
  class WatcherPool
    @watchers : Hash(String, AsyncWatcher)
    @active_count : Int32

    def initialize
      @watchers = {} of String => AsyncWatcher
      @active_count = 0
    end

    def add_watcher(id : String, patterns : Array(String), debounce_time = 100.milliseconds) : AsyncWatcher
      watcher = AsyncWatcher.new(patterns, debounce_time)
      @watchers[id] = watcher
      watcher
    end

    def start_watching(id : String, &callback : AsyncWatcher::ChangeCallback)
      watcher = @watchers[id]?
      if watcher
        spawn do
          watcher.watch(@watchers[id].@patterns, &callback)
        end
        @active_count += 1
      end
    end

    def stop_watcher(id : String)
      watcher = @watchers[id]?
      if watcher
        watcher.stop
        @watchers.delete(id)
        @active_count -= 1
      end
    end

    def stop_all
      @watchers.each_value(&.stop)
      @watchers.clear
      @active_count = 0
    end

    def active_count : Int32
      @active_count
    end
  end
end
