require "../src/topia"

support_dir = "../spec/support"

class ExamplePlugin
  include Topia::Plugin

  def run(input)
    sleep 2
    puts " Hello From Plugin"
    sleep 2
    1
  end

  def on(event : String)
    sleep 2
    puts " Hello from event: #{event}"
    sleep 2
  end
end

Topia.task("test")
     .pipe(ExamplePlugin.new)
     .src("#{support_dir}/*.txt")

Topia.default("test")

Topia.run_default
