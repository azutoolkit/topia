# Generated by Topia Endpoint Generator
# Endpoint: Userprofile
# Route: GET /api/users/

class UserprofileEndpoint
  include Azu::Endpoint(Getuserrequest, Userresponse)

  get "/api/users/"

  def call : Userresponse
    # TODO: Implement endpoint logic
    Userresponse.new
  end
end
