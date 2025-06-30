module Topia
  class Command
    getter name, args, full

    def initialize(@name : String, @args : Array(String), @full : String)
    end
  end

  # Handles command execution separately from Task orchestration
  class CommandExecutor
    getter commands : Array(Command)

    def initialize
      @commands = [] of Command
    end

    def add_command(command : String)
      split_commands = command.split("&&")

      split_commands.each do |text_command|
        text_command = text_command.strip
        command_args = text_command.split(" ")
        command_name = command_args.delete_at(0)
        @commands.push(Command.new(command_name, command_args, text_command))
      end
    end

    def execute_all
      @commands.each do |command|
        begin
          run_command(command.name, command.args)
        rescue
          raise Error.new("Command '#{command.full}' failed during execution.")
        end
      end
    end

    private def run_command(name, args)
      status = Process.run(name, args: args)
      status.exit_code
    end
  end
end
