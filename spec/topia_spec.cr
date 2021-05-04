require "./spec_helper"

module Hello
  include Topia
end

describe Topia do
  support_dir = "./spec/support"

  it "works with a simple named task" do
    task = Hello.task("test")
    task.name.should eq "test"
  end

  it "works with debug mode" do
    Hello.debug = true
    Hello.debug?.should eq true
  end

  it "works with src" do
    task = Hello.task("test").src("#{support_dir}/*.txt")
    task.pipe.value.as(Array).size.should eq 3
  end

  it "works with src and dist" do
    task = Hello.task("test")
      .src("#{support_dir}/*.txt")
      .dist("#{support_dir}_out")

    task.dist.should eq true
    task.dist_path.should eq "#{support_dir}_out"
  end

  it "works with a single default task" do
    Hello.task("default_task").command("touch default1.txt")
    Hello.task("default_task_cleanup").command("rm default1.txt")

    Hello.default("default_task")
    Hello.run_default

    File.exists?("default1.txt").should eq true
    Hello.run("default_task_cleanup")
  end

  it "works with multiple default tasks" do
    Hello.task("default_task").command("touch default1.txt")
    Hello.task("default_task2").command("touch default2.txt")
    Hello.task("default_task_cleanup").command("rm default1.txt && rm default2.txt")

    Hello.default(["default_task", "default_task2"])

    Hello.run_default

    exists = File.exists?("default1.txt")
    exists2 = File.exists?("default2.txt")

    Hello.run("default_task_cleanup")
    exists.should eq true
    exists2.should eq true
  end

  it "works with a shell command" do
    Hello.task("command_task")
      .command("touch ./spec/test.txt")
    Hello.task("command_task_cleanup")
      .command("rm ./spec/test.txt")

    Hello.run("command_task")

    exists = File.exists?("./spec/test.txt")

    Hello.run("command_task_cleanup")
    exists.should eq true
  end
end
