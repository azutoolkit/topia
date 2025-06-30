require "./spec_helper"

describe Topia do
  support_dir = "./spec/support"

  it "works with a simple named task" do
    task = Topia.task("test")
    task.name.should eq "test"
  end

  it "works with debug mode" do
    Topia.debug = true
    Topia.debug?.should eq true
  end

  it "works with src" do
    task = Topia.task("test").src("#{support_dir}/*.txt")
    task.pipeline.should_not be_nil
    if pipeline = task.pipeline
      pipeline.value.as(Array).size.should eq 3
    end
  end

  it "works with src and dist" do
    task = Topia.task("test")
      .src("#{support_dir}/*.txt")
      .dist("#{support_dir}_out")

    # Test that the task was configured correctly
    task.should_not be_nil
    task.pipeline.should_not be_nil
  end

  it "works with a single default task" do
    Topia.task("default_task").command("touch default1.txt")
    Topia.task("default_task_cleanup").command("rm default1.txt")

    Topia.default("default_task")
    Topia.run_default

    File.exists?("default1.txt").should eq true
    Topia.run("default_task_cleanup")
  end

  it "works with multiple default tasks" do
    Topia.task("default_task").command("touch default1.txt")
    Topia.task("default_task2").command("touch default2.txt")
    Topia.task("default_task_cleanup").command("rm default1.txt && rm default2.txt")

    Topia.default(["default_task", "default_task2"])

    Topia.run_default

    exists = File.exists?("default1.txt")
    exists2 = File.exists?("default2.txt")

    Topia.run("default_task_cleanup")
    exists.should eq true
    exists2.should eq true
  end

  it "works with a shell command" do
    Topia.task("command_task")
      .command("touch ./spec/test.txt")
    Topia.task("command_task_cleanup")
      .command("rm ./spec/test.txt")

    Topia.run("command_task")

    exists = File.exists?("./spec/test.txt")

    Topia.run("command_task_cleanup")
    exists.should eq true
  end
end
