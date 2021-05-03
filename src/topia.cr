require "colorize"
require "log"

require "./topia/spinner"
require "./topia/watcher"
require "./topia/command"
require "./topia/error"
require "./topia/input_file"
require "./topia/pipe"
require "./topia/plugin"
require "./topia/task"
require "./topia/cli"

module Topia
  VERSION = "0.1.0"

  class_property? debug = false
  class_getter logger = Log.for("Topia")
  class_getter spi = Spinner.new("Waiting...")

  @@tasks = [] of Task
  @@default_tasks : Array(String) = [] of String

  # Creates a new task
  def self.task(name : String)
    task = Task.new(name, debug?)
    @@tasks.push(task.as(Topia::Task))
    self.debug("Task '#{name}' created.")
    task
  end

  # Overload for creating a task with a callback function that gets executed first
  def self.task(name : String, cb)
    task = self.task(name)
    fn = cb.call
    task.pipe = Pipe(typeof(fn)).new(fn)
    task
  end

  # Run a task
  def self.run(name : String, params : Array(String) = [] of String)
    @@tasks.each do |task|
      if name == task.name
        task.run(params)
      end
    end
  end

  # Override to run multiple tasks
  # To be used for default tasks.
  def self.run(tasks : Array)
    tasks.each do |task|
      begin
        run_task, command = task.split(/\s/)
        self.run run_task, command.split(/\s/)
      rescue
        run_task = task
        self.run(task)
      end
    end
  end

  # Adds a default task
  def self.default(subtask : String)
    @@default_tasks.push(subtask)
  end

  # Add multiple default tasks
  def self.default(subtasks : Array(String))
    @@default_tasks = subtasks
  end

  # Runs the default task(s)
  def self.run_default
    self.run(@@default_tasks)
  end

  # Debugging utility
  private def self.debug(message)
    @@logger.debug { message } if debug?
  end
end
