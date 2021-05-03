module Topia
  module Plugin
    abstract def run(input, args)
    abstract def on(event : String)

    def announce(message)
      Topia.spi.message = message
    end
  end
end
