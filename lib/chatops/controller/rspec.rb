module ChatOpsSpecHelpers
  def chatops_auth!(user = "_", pass = ENV["CHATOPS_AUTH_TOKEN"])
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user, pass)
  end

  def chatop(method, params = {})
    args = params.dup.symbolize_keys
    user = args.delete :user

    post(:execute, {:method => method, :user => user, :params => args})
  end

  def chatop_response
    json_response = JSON.load(response.body)
    if json_response["error"].present?
      raise "There was an error instead of an expected successful response: #{json_response["error"]}"
    end
    json_response["result"]
  end

  def chatop_error
    json_response = JSON.load(response.body)
    json_response["error"]["message"]
  end

  RSpec.configure do |config|
    config.include self
  end
end
