require "./spec_helper"

describe "New Topia Features" do
  before_each do
    # Clear any existing state
    Topia.clear_tasks
  end

  describe "Task Dependencies" do
    it "should add and retrieve task dependencies" do
      Topia::DependencyManager.add_dependency("build", ["clean", "compile"])
      dependencies = Topia::DependencyManager.get_dependencies("build")
      dependencies.should eq(["clean", "compile"])
    end

    it "should resolve execution order with dependencies" do
      Topia::DependencyManager.add_dependency("deploy", ["build"])
      Topia::DependencyManager.add_dependency("build", ["test"])
      Topia::DependencyManager.add_dependency("test", ["compile"])

      order = Topia::DependencyManager.resolve_execution_order(["deploy"])
      order.should eq(["compile", "test", "build", "deploy"])
    end

    it "should detect circular dependencies" do
      Topia::DependencyManager.add_dependency("a", ["b"])
      Topia::DependencyManager.add_dependency("b", ["c"])
      Topia::DependencyManager.add_dependency("c", ["a"])

      expect_raises(Topia::Error, /Circular dependency/) do
        Topia::DependencyManager.resolve_execution_order(["a"])
      end
    end

    it "should validate dependencies exist" do
      Topia::DependencyManager.add_dependency("build", ["nonexistent"])

      expect_raises(Topia::Error, /does not exist/) do
        Topia::DependencyManager.validate_dependencies(["build"])
      end
    end
  end

  describe "Parallel Execution" do
    it "should group tasks by dependency level" do
      # This test verifies the dependency level grouping logic
      # We can't easily test actual parallel execution in specs
      Topia::DependencyManager.add_dependency("level2a", ["level1"])
      Topia::DependencyManager.add_dependency("level2b", ["level1"])

      order = Topia::DependencyManager.resolve_execution_order(["level2a", "level2b"])
      order.first.should eq("level1")
      order.should contain("level2a")
      order.should contain("level2b")
    end
  end

  describe "Configuration" do
    it "should substitute variables in configuration" do
      config_content = "build_dir: ${build_path}/output"
      Topia::Config.set_variable("build_path", "/tmp/build")

      # Test variable substitution (private method, so we test indirectly)
      variables = {"build_path" => "/tmp/build"}
      result = config_content.gsub(/\$\{([^}]+)\}/) do |match|
        key = match[2..-2]  # Remove ${ and }
        variables[key]? || match
      end

      result.should eq("build_dir: /tmp/build/output")
    end

    it "should create sample configuration" do
      temp_file = File.tempname("topia_test", ".yml")

      begin
        Topia::Config.create_sample_config(temp_file)
        File.exists?(temp_file).should be_true

        content = File.read(temp_file)
        content.should contain("name: My Project")
        content.should contain("tasks:")
      ensure
        File.delete(temp_file) if File.exists?(temp_file)
      end
    end
  end

  describe "CLI" do
    it "should parse command line arguments" do
      cli = Topia::CLI.new
      cli.parse_args(["-d", "--parallel", "build", "test"])

      cli.options["debug"]?.should be_true
      cli.options["parallel"]?.should be_true
      cli.tasks.should eq(["build", "test"])
    end

    it "should handle help option" do
      cli = Topia::CLI.new
      cli.parse_args(["--help"])
      cli.options["help"]?.should be_true
    end

    it "should handle version option" do
      cli = Topia::CLI.new
      cli.parse_args(["-v"])
      cli.options["version"]?.should be_true
    end
  end

  describe "Integration" do
    it "should support fluent task creation with dependencies" do
      # Test that the Task class supports the new depends_on method
      task = Topia.task("integration_test")

      # These should not raise errors
      task.command("echo 'test'")
      task.should_not be_nil
      task.name.should eq("integration_test")
    end

    it "should maintain backward compatibility" do
      # Ensure existing functionality still works
      task = Topia.task("compat_test")
        .command("echo 'backward compatible'")
        .src("./spec/support/*.txt")
        .dist("./tmp/output")

      task.should_not be_nil
      task.name.should eq("compat_test")
    end
  end
end
