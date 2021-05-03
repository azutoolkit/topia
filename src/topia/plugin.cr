module Topia
  module Plugin
    abstract def run(input)
    abstract def on(event : String)
  end
end
