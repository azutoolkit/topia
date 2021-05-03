require "../src/topia"
require "./tasks/*"

support_dir = "../spec/support"

Topia.task("azu.endpoint")
  .pipe(Generator.new)
  .command("mkdir -p ./playground/endpoints")

Topia::CLI.run
