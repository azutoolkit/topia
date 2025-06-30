require "./spec_helper"

describe "Refactored Topia Components" do
  describe "Pipeline System" do
    it "should create type-safe pipelines" do
      pipeline = Topia::Pipe(String).new("test")
      pipeline.value.should eq("test")
      pipeline.type_name.should eq("String")
    end

    it "should build pipelines with PipelineBuilder" do
      builder = Topia::PipelineBuilder.new
      pipeline = builder.start("hello").build
      pipeline.should_not be_nil
      pipeline.try(&.value).should eq("hello")
    end
  end

  describe "CommandExecutor" do
    it "should store and execute commands" do
      executor = Topia::CommandExecutor.new
      executor.add_command("echo 'hello world'")
      executor.commands.size.should eq(1)
      executor.commands.first.name.should eq("echo")
      executor.commands.first.args.should eq(["'hello", "world'"])
    end
  end

  describe "FileDistributor" do
    it "should validate input before distribution" do
      distributor = Topia::FileDistributor.new
      empty_files = [] of Topia::InputFile

      expect_raises(Topia::Error, "Files array cannot be empty") do
        distributor.distribute(empty_files, "/tmp/test")
      end

      test_file = Topia::InputFile.new("test.txt", "/tmp/", "content")
      expect_raises(Topia::Error, "Output path cannot be empty") do
        distributor.distribute([test_file], "")
      end
    end
  end

  describe "TaskWatcher" do
    it "should configure watching properly" do
      watcher = Topia::TaskWatcher.new
      watcher.watching.should be_false

      watcher.configure("/tmp/watch")
      watcher.watching.should be_true
      watcher.watch_path.should eq("/tmp/watch")
    end

    it "should handle change blocking" do
      watcher = Topia::TaskWatcher.new
      watcher.block_changes
      watcher.unblock_changes
    end
  end

  describe "Plugin Architecture" do
    it "should provide clean plugin utilities" do
      # Test the utility functions exist and are accessible
      typeof(Topia::PluginUtils.announce("test")).should eq(Nil)
      typeof(Topia::PluginUtils.error("test")).should eq(Nil)
      typeof(Topia::PluginUtils.success("test")).should eq(Nil)
    end

    it "should support plugin lifecycle management" do
      # Mock plugin for testing
      mock_plugin = MockPlugin.new

      result = Topia::PluginLifecycle.run_plugin(mock_plugin, "input", [] of String) do
        # Block called with result, but we'll test the return value separately
      end

      result.should eq("processed: input")
      mock_plugin.pre_run_called.should be_true
      mock_plugin.after_run_called.should be_true
    end
  end
end

# Mock plugin for testing
class MockPlugin < Topia::Plugin
  property pre_run_called = false
  property after_run_called = false

  def run(input, args = [] of String)
    "processed: #{input}"
  end

  def on(event : String)
    case event
    when "pre_run"
      @pre_run_called = true
    when "after_run"
      @after_run_called = true
    end
  end
end
