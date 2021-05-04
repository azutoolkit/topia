module Topia
  module CLI
    macro included
    def self.run
      if ARGV.size > 0
        task, command = ARGV.first, ARGV[1..-1]
        Topia.run(task, command)
      else
        Topia.run_default
      end
    end
    en
  end
end
