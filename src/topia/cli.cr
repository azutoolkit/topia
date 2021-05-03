module Topia
  module CLI
    def self.run
      if ARGV.size > 0
        task, command = ARGV.first, ARGV[1..-1]
        Topia.run(task, command)
      else
        Topia.run_default
      end
    end
  end
end
