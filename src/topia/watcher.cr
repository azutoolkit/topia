module Watcher
  # Class to save file changes
  private class WatchEvent
    property changed = false, files = {} of String => Tuple(Bool, String)
    getter interval

    def initialize(@interval : Int32 | Float64)
    end

    # Allow to yield a block when a file changes
    def on_change(&)
      yield files if changed
    end
  end

  # Get file timestamp using File.stat
  def self.timestamp_for(file : String)
    File.info(file).modification_time.to_s("%Y%m%d%H%M%S.%L")
  end

  private def self.scanner(files, event)
    event.changed = false
    Dir.glob(files) do |file|
      timestamp = timestamp_for(file)
      if (event.files[file]? && event.files[file].last != timestamp)
        event.files[file] = {false, timestamp}
        event.changed = true
      elsif event.files[file]?.nil?
        event.files[file] = {true, timestamp}
        event.changed = true
      end
    end
    event
  end

  # Allow to watch file changes using Watcher.watch
  def self.watch(files, interval : Int32 | Float64, &)
    event = WatchEvent.new(interval)
    loop do
      event = scanner(files, event)
      yield event
      sleep event.interval.seconds
    end
  end

  def self.watch(files, &)
    self.watch(files, 1) do |event|
      yield event
    end
  end
end

# Allow to watch file changes
def watch(files, interval, &)
  Watcher.watch(files, interval) do |event|
    yield event
  end
end

# :ditto:
def watch(files, &)
  watch(files, 1) do |event|
    yield event
  end
end

module Topia
  # Handles file watching for tasks separately from Task orchestration
  class TaskWatcher
    include Watcher

    getter watch_path : String
    getter watching : Bool

    def initialize
      @watch_path = ""
      @watching = false
      @watch_block = false
    end

    def configure(path : String)
      @watch_path = path
      @watching = true
    end

    def watch_for_changes(&block : -> Void)
      return unless @watching

      watch @watch_path do |event|
        event.on_change do |files|
          unless @watch_block
            block.call
          end
        end
      end
    end

    def block_changes
      @watch_block = true
    end

    def unblock_changes
      @watch_block = false
    end

    def delay(duration : Float64, &)
      sleep duration.seconds
      yield
    end
  end
end
