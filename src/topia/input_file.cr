module Topia
  class InputFile
    property name : String, path : String, contents : String

    def initialize(@name, @path, @contents)
    end

    def write
      File.write("#{path}#{name}", contents)
    end
  end

  # Handles file distribution separately from Task orchestration
  class FileDistributor
    def initialize
    end

    def distribute(files : Array(InputFile), output_path : String)
      validate_input(files, output_path)

      files.each do |file|
        file.path = output_path
        Dir.mkdir_p(output_path) unless Dir.exists?(output_path)
        file.write
      end
    end

    private def validate_input(files : Array(InputFile), output_path : String)
      raise Error.new("Output path cannot be empty") if output_path.empty?
      raise Error.new("Files array cannot be empty") if files.empty?
    end
  end
end
