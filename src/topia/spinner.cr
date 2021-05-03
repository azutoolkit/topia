module Topia
  class Spinner
    @@frames = ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"]
    @@ok = "✓"
    @@fail = "✗"
    @index = 0
    @timer = Timer.new

    # Initialize a spinner with a message
    def initialize(@message : String = "")
    end

    # Show the spinner
    def start(msg : String = "")
      @message = msg if msg.size > 0
      self.hideCursor
      @timer.start(50.milliseconds) do
        print("\r")
        print("#{@@frames[@index]} #{@message}")
        @index = (@index + 1) % @@frames.size
      end
    end

    def message=(msg : String)
      @message = msg
      self.clear if msg.size < @message.size
    end

    # Stop the spinner and show msg in red with ✗ prepended
    def error(msg : String)
      self.stop("#{@@fail} #{msg}".colorize(:light_red).to_s)
    end

    # Stop the spinner and show msg in green with ✓ prepended
    def success(msg : String)
      self.stop("#{@@ok} #{msg}".colorize(:light_green).to_s)
    end

    # Stop the spinner ans show msg as provided
    def stop(msg : String)
      @timer.stop
      self.showCursor
      self.clear
      puts(msg)
    end

    private def clear
      print("\r\033[0K")
    end

    private def showCursor
      print("\033[?25h")
    end

    private def hideCursor
      print("\033[?25l")
    end
  end

  private class Timer
    @ticking = true

    def start(ts : Time::Span, &block)
      @ticking = true
      spawn do
        loop do
          block.call
          sleep(ts)
          break if !@ticking
        end
      end
    end

    def stop
      @ticking = false
    end
  end
end
