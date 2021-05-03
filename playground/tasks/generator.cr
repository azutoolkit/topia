class Generator
  include Topia::Plugin

  def run(input, params)
    announce "Generating Endpoint!"
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
    announce "Done Generating Endpoint!"
    true
  end

  def on(event : String)
    announce " Hello from event: #{event}"
  end
end