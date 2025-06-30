module Topia
  # Manages task dependencies and execution order
  class DependencyManager
    # Task dependency graph
    @@dependencies = {} of String => Array(String)

    def self.add_dependency(task_name : String, dependencies : Array(String))
      @@dependencies[task_name] = dependencies
    end

    def self.get_dependencies(task_name : String) : Array(String)
      @@dependencies[task_name]? || [] of String
    end

    def self.all_dependencies : Hash(String, Array(String))
      @@dependencies
    end

    def self.clear_dependencies
      @@dependencies.clear
    end

    # Resolves task execution order using topological sort
    def self.resolve_execution_order(task_names : Array(String)) : Array(String)
      visited = Set(String).new
      visiting = Set(String).new
      result = [] of String

      task_names.each do |task_name|
        visit(task_name, visited, visiting, result)
      end

      result
    end

    private def self.visit(task_name : String, visited : Set(String), visiting : Set(String), result : Array(String))
      return if visited.includes?(task_name)

      if visiting.includes?(task_name)
        raise Error.new("Circular dependency detected involving task '#{task_name}'")
      end

      visiting.add(task_name)

      # Visit all dependencies first
      dependencies = get_dependencies(task_name)
      dependencies.each do |dep|
        visit(dep, visited, visiting, result)
      end

      visiting.delete(task_name)
      visited.add(task_name)
      result << task_name
    end

    # Validates that all dependencies exist
    def self.validate_dependencies(available_tasks : Array(String))
      errors = [] of String

      @@dependencies.each do |task_name, deps|
        deps.each do |dep|
          unless available_tasks.includes?(dep)
            errors << "Task '#{task_name}' depends on '#{dep}' which does not exist"
          end
        end
      end

      unless errors.empty?
        raise Error.new("Dependency validation failed:\n#{errors.join("\n")}")
      end
    end
  end

  # Handles parallel task execution using Fibers
  class ParallelExecutor
    def self.run_parallel(task_names : Array(String))
      # Resolve dependencies first
      execution_order = DependencyManager.resolve_execution_order(task_names)

      # Group tasks by dependency level for parallel execution
      dependency_levels = group_by_dependency_level(execution_order)

      dependency_levels.each do |level_tasks|
        if level_tasks.size == 1
          # Single task, run directly
          Topia.run(level_tasks.first)
        else
          # Multiple tasks, run in parallel
          run_tasks_in_parallel(level_tasks)
        end
      end
    end

    private def self.group_by_dependency_level(execution_order : Array(String)) : Array(Array(String))
      levels = [] of Array(String)
      completed = Set(String).new

      while completed.size < execution_order.size
        current_level = [] of String

        execution_order.each do |task_name|
          next if completed.includes?(task_name)

          dependencies = DependencyManager.get_dependencies(task_name)
          if dependencies.all? { |dep| completed.includes?(dep) }
            current_level << task_name
          end
        end

        if current_level.empty?
          remaining = execution_order.reject { |t| completed.includes?(t) }
          raise Error.new("Cannot resolve dependencies for tasks: #{remaining.join(", ")}")
        end

        levels << current_level
        current_level.each { |task| completed.add(task) }
      end

      levels
    end

    private def self.run_tasks_in_parallel(task_names : Array(String))
      channels = [] of Channel(Exception?)

      task_names.each do |task_name|
        channel = Channel(Exception?).new
        channels << channel

        spawn do
          begin
            Topia.run(task_name)
            channel.send(nil)
          rescue ex
            channel.send(ex)
          end
        end
      end

      # Wait for all tasks to complete and collect any errors
      errors = [] of Exception
      channels.each do |channel|
        if error = channel.receive
          errors << error
        end
      end

      # Report any errors
      unless errors.empty?
        error_messages = errors.map(&.message).join("\n")
        raise Error.new("Parallel execution failed:\n#{error_messages}")
      end
    end
  end
end
