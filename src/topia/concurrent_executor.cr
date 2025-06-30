require "./async_spinner"
require "./task_cache"
require "./task"

module Topia
  # Enhanced concurrent task execution with advanced scheduling and resource management
  class ConcurrentExecutor
    struct TaskJob
      property task : Task
      property priority : Int32
      property estimated_duration : Time::Span
      property max_retries : Int32
      property retry_count : Int32
      property dependencies_resolved : Bool
      property started_at : Time?
      property completed_at : Time?

      def initialize(@task : Task, @priority = 0, @estimated_duration = 1.second, @max_retries = 0)
        @retry_count = 0
        @dependencies_resolved = false
        @started_at = nil
        @completed_at = nil
      end

      def duration : Time::Span?
        if (start = @started_at) && (finish = @completed_at)
          finish - start
        end
      end
    end

    struct ExecutionStats
      property total_tasks : Int32
      property completed_tasks : Int32
      property failed_tasks : Int32
      property cached_tasks : Int32
      property total_duration : Time::Span
      property average_duration : Time::Span
      property max_concurrent : Int32

      def initialize
        @total_tasks = 0
        @completed_tasks = 0
        @failed_tasks = 0
        @cached_tasks = 0
        @total_duration = 0.seconds
        @average_duration = 0.seconds
        @max_concurrent = 0
      end

      def success_rate : Float64
        return 0.0 if @total_tasks == 0
        @completed_tasks.to_f / @total_tasks * 100
      end
    end

    @max_concurrent : Int32
    @job_queue : Channel(TaskJob)
    @result_channel : Channel(NamedTuple(job: TaskJob, success: Bool, error: Exception?))
    @workers : Array(Fiber)
    @running : Bool
    @spinner_pool : SpinnerPool
    @cached_executor : CachedTaskExecutor
    @stats : ExecutionStats
    @active_jobs : Hash(String, TaskJob)

    def initialize(@max_concurrent = 4)
      @job_queue = Channel(TaskJob).new(100)
      @result_channel = Channel(NamedTuple(job: TaskJob, success: Bool, error: Exception?)).new
      @workers = [] of Fiber
      @running = false
      @spinner_pool = SpinnerPool.new
      @cached_executor = CachedTaskExecutor.new
      @stats = ExecutionStats.new
      @active_jobs = {} of String => TaskJob
    end

    def execute_concurrent(tasks : Array(Task), use_cache = true, show_progress = true) : ExecutionStats
      @stats = ExecutionStats.new
      @stats.total_tasks = tasks.size

      # Create jobs from tasks
      jobs = tasks.map { |task| TaskJob.new(task) }

      # Resolve dependencies and create execution plan
      execution_plan = create_execution_plan(jobs)

      # Start workers
      start_workers

      # Start progress monitoring if requested
      progress_fiber = start_progress_monitor if show_progress

      begin
        # Execute tasks according to plan
        execute_plan(execution_plan, use_cache)

        # Wait for completion
        wait_for_completion(jobs.size)
      ensure
        stop_workers
        sleep(50.milliseconds) if progress_fiber  # Let progress fiber finish
        @spinner_pool.stop_all
      end

      @stats
    end

    def execute_single_cached(task : Task, use_cache = true) : Bool
      return execute_with_cache(task) if use_cache

      begin
        task.run
        true
      rescue
        false
      end
    end

    private def create_execution_plan(jobs : Array(TaskJob)) : Array(Array(TaskJob))
      # Group jobs by dependency level
      levels = [] of Array(TaskJob)
      completed = Set(String).new

      while completed.size < jobs.size
        current_level = [] of TaskJob

        jobs.each do |job|
          next if completed.includes?(job.task.name)

          dependencies = DependencyManager.get_dependencies(job.task.name)
          if dependencies.all? { |dep| completed.includes?(dep) }
            job.dependencies_resolved = true
            current_level << job
          end
        end

        if current_level.empty?
          remaining = jobs.reject { |job| completed.includes?(job.task.name) }
          raise Error.new("Cannot resolve dependencies for tasks: #{remaining.map(&.task.name).join(", ")}")
        end

        # Sort by priority within each level
        current_level.sort_by! { |job| -job.priority }
        levels << current_level
        current_level.each { |job| completed.add(job.task.name) }
      end

      levels
    end

    private def execute_plan(execution_plan : Array(Array(TaskJob)), use_cache : Bool)
      execution_plan.each do |level_jobs|
        # Submit all jobs in this level
        level_jobs.each do |job|
          submit_job(job, use_cache)
        end

        # Wait for this level to complete before proceeding
        wait_for_level_completion(level_jobs.size)
      end
    end

    private def submit_job(job : TaskJob, use_cache : Bool)
      @active_jobs[job.task.name] = job

      # Create spinner for this job
      @spinner_pool.create(job.task.name, "Executing #{job.task.name}")
      @spinner_pool.start(job.task.name)

      @job_queue.send(job)
    end

    private def start_workers
      @running = true

      @max_concurrent.times do |i|
        worker = spawn do
          worker_loop(i)
        end
        @workers << worker
      end
    end

    private def stop_workers
      @running = false

      # Send stop signals
      @max_concurrent.times do
        @job_queue.close
      end

      # Wait briefly for workers to finish
      sleep(100.milliseconds)
      @workers.clear
    end

    private def worker_loop(worker_id : Int32)
      while @running
        select
        when job = @job_queue.receive?
          break unless job
          execute_job(job, worker_id)
        when timeout(100.milliseconds)
          # Check if we should continue
          next
        end
      end
    end

    private def execute_job(job : TaskJob, worker_id : Int32)
      job.started_at = Time.utc
      success = false
      error : Exception? = nil

      begin
        # Update spinner
        @spinner_pool.start(job.task.name, "Worker #{worker_id}: #{job.task.name}")

        # Execute with caching if enabled
        @cached_executor.execute_with_cache(job.task)
        success = true

      rescue ex
        error = ex
        success = false

        # Retry logic
        if job.retry_count < job.max_retries
          job.retry_count += 1
          @spinner_pool.start(job.task.name, "Retrying #{job.task.name} (#{job.retry_count}/#{job.max_retries})")

          # Exponential backoff
          sleep((2 ** job.retry_count).seconds)

          # Retry the job
          return execute_job(job, worker_id)
        end
      ensure
        job.completed_at = Time.utc

        # Update spinner based on result
        if success
          @spinner_pool.success(job.task.name, "✓ #{job.task.name} completed")
        else
          @spinner_pool.error(job.task.name, "✗ #{job.task.name} failed")
        end

        # Send result
        @result_channel.send({job: job, success: success, error: error})
      end
    end

    private def execute_with_cache(task : Task) : Bool
      begin
        @cached_executor.execute_with_cache(task)
        true
      rescue
        false
      end
    end

    private def wait_for_completion(expected_results : Int32)
      completed = 0

      while completed < expected_results
        result = @result_channel.receive
        completed += 1

        # Update statistics
        update_stats(result)

        # Clean up
        @active_jobs.delete(result[:job].task.name)
      end
    end

    private def wait_for_level_completion(expected_results : Int32)
      completed = 0

      while completed < expected_results
        result = @result_channel.receive
        completed += 1

        # Update statistics
        update_stats(result)

        # Clean up
        @active_jobs.delete(result[:job].task.name)
      end
    end

    private def update_stats(result : NamedTuple(job: TaskJob, success: Bool, error: Exception?))
      job = result[:job]

      if result[:success]
        @stats.completed_tasks += 1
      else
        @stats.failed_tasks += 1
      end

      if duration = job.duration
        @stats.total_duration += duration
        @stats.average_duration = @stats.total_duration / @stats.completed_tasks
      end

      # Track max concurrent
      current_active = @active_jobs.size
      @stats.max_concurrent = Math.max(@stats.max_concurrent, current_active)
    end

    private def start_progress_monitor : Fiber?
      return nil unless @stats.total_tasks > 1

      spawn do
        last_completed = 0

        while @running || @active_jobs.size > 0
          current_completed = @stats.completed_tasks + @stats.failed_tasks

          if current_completed != last_completed
            progress = (current_completed.to_f / @stats.total_tasks * 100).round(1)
            active_count = @active_jobs.size

            puts "\n📊 Progress: #{current_completed}/#{@stats.total_tasks} (#{progress}%) | Active: #{active_count} | Success Rate: #{@stats.success_rate.round(1)}%".colorize(:cyan)

            if @active_jobs.size > 0
              puts "🔄 Active tasks: #{@active_jobs.keys.join(", ")}".colorize(:dark_gray)
            end

            last_completed = current_completed
          end

          sleep(2.seconds)
        end
      end
    end

    def cache_stats
      @cached_executor.cache_stats
    end

    def clear_cache
      @cached_executor.clear_cache
    end
  end

  # Global concurrent executor for easy access
  @@concurrent_executor : ConcurrentExecutor?

  def self.concurrent_executor(max_concurrent = 4)
    @@concurrent_executor ||= ConcurrentExecutor.new(max_concurrent)
  end

  def self.execute_concurrent(tasks : Array(Task), max_concurrent = 4, use_cache = true, show_progress = true)
    executor = ConcurrentExecutor.new(max_concurrent)
    executor.execute_concurrent(tasks, use_cache, show_progress)
  end

  def self.concurrent_stats
    concurrent_executor.cache_stats
  end
end
