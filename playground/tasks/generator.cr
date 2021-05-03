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
    @spi.message = " Hello from event: #{event}"
  end
end