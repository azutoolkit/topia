class DashboadHomeEndpoint
  include Azu::Endpoint(Request, Response)

  get "/dashboard/:name"

  def call : Response
  end
end
