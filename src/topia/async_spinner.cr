require "colorize"

module Topia
  # High-performance, non-blocking spinner using Crystal's select and channels
  class AsyncSpinner
    SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    getter message : String
    getter running : Bool

    @fiber : Fiber?
    @control_channel : Channel(Symbol)
    @message_channel : Channel(String)
    @update_interval : Time::Span

    def initialize(@message = "Working...", @update_interval = 100.milliseconds)
      @running = false
      @control_channel = Channel(Symbol).new
      @message_channel = Channel(String).new
    end

    def start(new_message : String? = nil)
      return if @running

      @message = new_message if new_message
      @running = true

      @fiber = spawn do
        run_spinner_loop
      end
    end

        def stop
      return unless @running

      @control_channel.send(:stop)
      # Wait a brief moment for the fiber to process the stop signal
      sleep(10.milliseconds)
      @running = false

      # Clear the spinner line
      print "\r\033[K"
    end

    def message=(new_message : String)
      @message = new_message

      # Non-blocking send with select and timeout
      select
      when @message_channel.send(new_message)
        # Message sent successfully
      when timeout(1.millisecond)
        # Channel is full, ignore and continue
      end
    end

    def success(message : String)
      stop
      puts "✓ #{message}".colorize(:green)
    end

    def error(message : String)
      stop
      puts "✗ #{message}".colorize(:red)
    end

    def warning(message : String)
      stop
      puts "⚠ #{message}".colorize(:yellow)
    end

    def info(message : String)
      stop
      puts "ℹ #{message}".colorize(:cyan)
    end

    private def run_spinner_loop
      frame_index = 0
      current_message = @message

      loop do
        # Non-blocking check for control messages
        select
        when control = @control_channel.receive
          case control
          when :stop
            break
          end
        when new_message = @message_channel.receive
          current_message = new_message
        when timeout(@update_interval)
          # Update spinner frame
          frame = SPINNER_FRAMES[frame_index % SPINNER_FRAMES.size]
          print "\r#{frame.colorize(:cyan)} #{current_message}"
          STDOUT.flush
          frame_index += 1
        end
      end
    end
  end

  # Performance-optimized spinner pool for multiple concurrent operations
  class SpinnerPool
    @spinners : Hash(String, AsyncSpinner)
    @active_count : Int32

    def initialize
      @spinners = {} of String => AsyncSpinner
      @active_count = 0
    end

    def create(id : String, message : String) : AsyncSpinner
      spinner = AsyncSpinner.new(message)
      @spinners[id] = spinner
      spinner
    end

    def start(id : String, message : String? = nil)
      spinner = @spinners[id]?
      if spinner
        spinner.start(message)
        @active_count += 1
      end
    end

    def stop(id : String)
      spinner = @spinners[id]?
      if spinner && spinner.running
        spinner.stop
        @active_count -= 1
      end
    end

    def success(id : String, message : String)
      spinner = @spinners[id]?
      if spinner
        spinner.success(message)
        @active_count -= 1 if spinner.running
        @spinners.delete(id)
      end
    end

    def error(id : String, message : String)
      spinner = @spinners[id]?
      if spinner
        spinner.error(message)
        @active_count -= 1 if spinner.running
        @spinners.delete(id)
      end
    end

    def active_count : Int32
      @active_count
    end

    def stop_all
      @spinners.each_value(&.stop)
      @spinners.clear
      @active_count = 0
    end
  end
end
