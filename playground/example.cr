require "../src/topia"

support_dir = "../spec/support"

class Generator
  include Topia::Plugin

  def run(input, params)
    @spi.message = "Generating Endpoint!"
    name, route, request, response = params

    method, path = route.split(":/")
    
    File.open("./playground/endpoints/#{name.downcase}.cr", "w") do |file|
      file.puts <<-CONTENT
      class #{name.camelcase}Endpoint
        include Azu::Endpoint(#{request.camelcase}, #{response.camelcase})
        
        #{method.downcase} "/#{path.downcase}"

        def call : #{response.camelcase}
        end
      end
      CONTENT
    end
    @spi.message = "Done Generating Endpoint!"
    true
  end

  def on(event : String)
    sleep 2
    @spi.message = " Hello from event: #{event}"
    sleep 2
  end
end

Topia.task("azu.endpoint")
  .pipe(Generator.new)
  .command("mkdir -p ./playground/endpoints")

if ARGV.size > 0
  task, command = ARGV.first, ARGV[1..-1]
  Topia.run(task, command)
else
  Topia.run_default
end
# Topia.run("azu.endpoint", "dashboard_home", "get:/dashboard/:name", "request", "response")

