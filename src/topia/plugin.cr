module Topia
  module Plugin
    @spi : Spinner::Spinner = Topia.spi

    abstract def run(input, args)
    abstract def on(event : String)
  end
end
