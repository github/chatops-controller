module ChatOps::Controller::TestCaseHelpers

  class NoMatchingCommandRegex < StandardError ; end

  def chatops_auth!(user = "_", pass = ENV["CHATOPS_AUTH_TOKEN"])
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user, pass)
  end

  def chatop(method, params = {})
    args = params.dup.symbolize_keys
    user = args.delete :user
    room_id = args.delete :room_id

    post method, params: {
      :method => method,
      :params => args,
      :room_id => room_id,
      :user => user,
    }
  end

  def chat(message, user, room_id = "123")
    get :list
    json_response = JSON.load(response.body)
    matchers = json_response["methods"].map { |name, metadata|
      metadata = metadata.dup
      metadata["name"] = name
      metadata["regex"] = Regexp.new("^#{metadata["regex"]}$", "i")
      metadata
    }
    matcher = matchers.find { |matcher| matcher["regex"].match(message) }

    raise NoMatchingCommandRegex.new("No command matches '#{message}'") unless matcher

    match_data = matcher["regex"].match(message)
    jsonrpc_params = {}
    matcher["params"].each do |param|
      jsonrpc_params[param] = match_data[param.to_sym]
    end
    jsonrpc_params.merge!(user: user, room_id: room_id)
    chatop matcher["name"].to_sym, jsonrpc_params
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
end
