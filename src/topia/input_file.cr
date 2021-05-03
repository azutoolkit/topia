module Topia
  class InputFile
    property name : String, path : String, contents : String

    def initialize(@name, @path, @contents)
    end

    def write
      File.write("#{path}#{name}", contents)
    end
  end
end
