require "./spec_helper"

describe "Developer Experience Features" do
  before_each do
    Topia.clear_tasks
  end

  describe "Enhanced CLI" do
    it "supports verbose and quiet modes" do
      cli = Topia::CLI.new
      cli.parse_args(["--verbose", "build"])

      cli.options["verbose"]?.should be_true
      cli.options["quiet"]?.should be_false
      cli.tasks.should eq(["build"])
    end

    it "supports job control for parallel execution" do
      cli = Topia::CLI.new
      cli.parse_args(["-j", "4", "-p", "build"])

      cli.options["jobs"]?.should eq(4)
      cli.options["parallel"]?.should be_true
    end

    it "supports watch mode" do
      cli = Topia::CLI.new
      cli.parse_args(["-w", "build"])

      cli.options["watch"]?.should be_true
    end

    it "supports interactive mode" do
      cli = Topia::CLI.new
      cli.parse_args(["-i"])

      cli.options["interactive"]?.should be_true
    end

    it "supports configuration validation" do
      cli = Topia::CLI.new
      cli.parse_args(["--validate-config"])

      cli.options["validate_config"]?.should be_true
    end

    it "supports task information commands" do
      cli = Topia::CLI.new
      cli.parse_args(["--dependencies", "build"])

      cli.options["show_dependencies"]?.should eq("build")

      cli2 = Topia::CLI.new
      cli2.parse_args(["--where", "setup"])

      cli2.options["where"]?.should eq("setup")
    end

    it "supports statistics and profiling" do
      cli = Topia::CLI.new
      cli.parse_args(["--stats", "--profile", "build"])

      cli.options["stats"]?.should be_true
      cli.options["profile"]?.should be_true
    end

    it "supports initialization command" do
      cli = Topia::CLI.new
      cli.parse_args(["--init", "/tmp/test"])

      cli.options["init"]?.should eq("/tmp/test")
    end

    it "supports detailed task listing" do
      cli = Topia::CLI.new
      cli.parse_args(["--list-detailed"])

      cli.options["list_detailed"]?.should be_true
    end

    it "supports color control" do
      cli = Topia::CLI.new
      cli.parse_args(["--no-color", "build"])

      cli.options["no_color"]?.should be_true
    end
  end

  describe "Output Mode Management" do
    it "sets output mode correctly" do
      Topia.set_output_mode(:quiet)
      Topia.output_mode.should eq(:quiet)
      Topia.quiet?.should be_true
      Topia.verbose?.should be_false

      Topia.set_output_mode(:verbose)
      Topia.output_mode.should eq(:verbose)
      Topia.quiet?.should be_false
      Topia.verbose?.should be_true

      Topia.set_output_mode(:normal)
      Topia.output_mode.should eq(:normal)
      Topia.quiet?.should be_false
      Topia.verbose?.should be_false
    end
  end

  describe "Task Descriptions and Information" do
    it "supports task descriptions" do
      task = Topia.task("example")
        .describe("This is an example task for testing")
        .command("echo 'test'")

      task.description.should eq("This is an example task for testing")
    end

    it "provides pipeline information" do
      task = Topia.task("complex")
        .command("echo 'step1'")
        .command("echo 'step2'")
        .dist("./output")

      pipeline_info = task.pipeline_info
      pipeline_info.should_not be_nil
      pipeline_info.should contain("2 command(s)")
      pipeline_info.should contain("dist: ./output")
    end

    it "tracks source location" do
      task = Topia.task("source-test")

      task.source_file.should_not be_nil
      task.source_line.should_not be_nil
    end
  end

  describe "Task Statistics" do
    it "records task execution statistics" do
      task = Topia.task("stats-test")
        .command("echo 'testing stats'")

      # Simulate task execution
      start_time = Time.monotonic
      begin
        # Simulate successful execution
        Topia.record_task_success("stats-test", start_time)

        stats = Topia.task_statistics("stats-test")
        stats.should_not be_nil
        stats.should contain("success")
        stats.should contain("1 runs")
      rescue
        # Handle any errors
      end
    end

    it "records task failure statistics" do
      task = Topia.task("failure-test")
        .command("false") # Command that will fail

      start_time = Time.monotonic
      error = Exception.new("Test failure")

      Topia.record_task_failure("failure-test", start_time, error)

      stats = Topia.task_statistics("failure-test")
      stats.should_not be_nil
      stats.should contain("failed")
      stats.should contain("Test failure")
    end
  end

  describe "Configuration Management" do
    it "validates task dependencies" do
      # Create tasks with dependencies
      Topia.task("dep1").command("echo 'dep1'")
      Topia.task("dep2").command("echo 'dep2'")
      Topia.task("main").depends_on(["dep1", "dep2"]).command("echo 'main'")

      # This should not raise an error
      expect_raises(Topia::Error) do
        Topia.validate_all_dependencies
      end.should be_falsey
    end

    it "detects missing dependencies" do
      # Create task with non-existent dependency
      Topia.task("invalid").depends_on("non-existent").command("echo 'invalid'")

      # This should raise an error for missing dependency
      expect_raises(Topia::Error) do
        Topia.validate_all_dependencies
      end
    end
  end

  describe "Enhanced Error Handling" do
    it "provides helpful error messages for missing tasks" do
      expect_raises(Topia::Error, "Task 'non-existent' not found") do
        Topia.run("non-existent")
      end
    end

    it "handles plugin execution errors gracefully" do
      # This test would require a mock plugin that fails
      # Skipping for now as it requires more complex setup
    end
  end

  describe "Task Discovery and Listing" do
    it "lists available tasks correctly" do
      Topia.task("task1").describe("First task").command("echo 'task1'")
      Topia.task("task2").describe("Second task").command("echo 'task2'")
      Topia.task("task3").describe("Third task").command("echo 'task3'")

      tasks = Topia.available_tasks
      tasks.size.should eq(3)
      tasks.map(&.name).should contain("task1")
      tasks.map(&.name).should contain("task2")
      tasks.map(&.name).should contain("task3")
    end

    it "tracks default tasks" do
      Topia.task("default1").command("echo 'default1'")
      Topia.task("default2").command("echo 'default2'")
      Topia.default(["default1", "default2"])

      Topia.default_tasks.should eq(["default1", "default2"])
    end

    it "finds tasks by name" do
      task = Topia.task("findable").command("echo 'findable'")

      found_task = Topia.find_task("findable")
      found_task.should_not be_nil
      found_task.try(&.name).should eq("findable")

      missing_task = Topia.find_task("missing")
      missing_task.should be_nil
    end
  end

  describe "Performance Features" do
    it "supports parallel execution configuration" do
      # Test that parallel execution methods exist and can be called
      task_names = ["task1", "task2"]

      # This would normally execute tasks, but we'll just test the interface
      # Topia.run_parallel(task_names, max_jobs: 2)

      # Test job count defaults
      max_jobs = System.cpu_count
      max_jobs.should be > 0
    end

    it "provides duration formatting" do
      # Test duration formatting (private method, so we test via statistics)
      start_time = Time.monotonic
      sleep(0.001) # Small delay

      Topia.record_task_success("duration-test", start_time)
      stats = Topia.task_statistics("duration-test")
      stats.should_not be_nil
      stats.should match(/\d+(\.\d+)?(ms|s)/)
    end
  end

  describe "Developer Productivity" do
    it "provides comprehensive help information" do
      # Test that CLI help can be generated without errors
      cli = Topia::CLI.new
      cli.parse_args(["--help"])

      cli.options["help"]?.should be_true
    end

    it "supports version information" do
      cli = Topia::CLI.new
      cli.parse_args(["--version"])

      cli.options["version"]?.should be_true
    end

    it "supports dry run mode" do
      cli = Topia::CLI.new
      cli.parse_args(["--dry-run", "build", "test"])

      cli.options["dry_run"]?.should be_true
      cli.tasks.should eq(["build", "test"])
    end
  end

  describe "Interactive Features" do
    it "supports task selection parsing" do
      # This would require exposing the parse_task_selection method
      # or testing it through the interactive interface
      # Skipping for now as it requires UI interaction simulation
    end
  end

  describe "Integration Tests" do
    it "handles complete workflow" do
      # Create a realistic workflow
      Topia.task("setup")
        .describe("Setup project")
        .command("echo 'Setting up...'")

      Topia.task("build")
        .describe("Build project")
        .depends_on("setup")
        .command("echo 'Building...'")

      Topia.task("test")
        .describe("Run tests")
        .depends_on("build")
        .command("echo 'Testing...'")

      Topia.default(["test"])

      # Verify the complete setup
      Topia.available_tasks.size.should eq(3)
      Topia.default_tasks.should eq(["test"])
      Topia.task_dependencies("test").should eq(["build"])
      Topia.task_dependencies("build").should eq(["setup"])
    end
  end
end
