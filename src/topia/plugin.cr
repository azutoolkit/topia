module Topia
  module Plugin
    abstract def run(input, args)
    abstract def on(event : String)

    def announce(message)
      SPINNER.message = message
    end

    def error(message)
      SPINNER.error message
    end

    def success(message)
      SPINNER.success message
    end
  end
end
