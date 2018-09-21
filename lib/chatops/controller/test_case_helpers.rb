module Chatops::Controller::TestCaseHelpers

  class NoMatchingCommandRegex < StandardError ; end

  def chatops_auth!
    request.env["CHATOPS_TESTING_AUTH"] = true
  end

  def chatops_prefix(prefix = nil)
    # We abuse request.env here so that rails will cycle this with each test.
    # If we used an instance variable, one would always need to be resetting
    # it.
    if prefix
      request.env["CHATOPS_TESTING_PREFIX"] = prefix
    end
    request.env["CHATOPS_TESTING_PREFIX"]
  end

  def chatop(method, params = {})
    args = params.dup.symbolize_keys
    user = args.delete :user
    room_id = args.delete :room_id
    mention_slug = args.delete :mention_slug

    params = {
      :params => args,
      :room_id => room_id,
      :user => user,
      :mention_slug => mention_slug,
    }

    major_version = Rails.version.split('.')[0].to_i
    if major_version >= 5
      post :execute_chatop, params: params.merge(chatop: method)
    else
      post :execute_chatop, params.merge(chatop: method)
    end
  end

  def chat(message, user, room_id = "123")
    get :list
    json_response = JSON.load(response.body)
    matchers = json_response["methods"].map { |name, metadata|
      metadata = metadata.dup
      metadata["name"] = name
      prefix = chatops_prefix ? "#{chatops_prefix} " : ""
      metadata["regex"] = Regexp.new("^#{prefix}#{metadata["regex"]}$", "i")
      metadata
    }

    named_params, command = extract_named_params(message)

    matcher = matchers.find { |m| m["regex"].match(command) }

    raise NoMatchingCommandRegex.new("No command matches '#{command}'") unless matcher

    match_data = matcher["regex"].match(command)
    jsonrpc_params = named_params.dup
    matcher["params"].each do |param|
      jsonrpc_params[param] ||= match_data[param.to_sym]
    end
    jsonrpc_params.merge!(user: user, room_id: room_id, mention_slug: user)
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

  def extract_named_params(command_string)
    params = {}

    while last_index = command_string.rindex(" --")
      arg = command_string[last_index..-1]
      matches = arg.match(/ --(\S+)(.*)/)
      params[matches[1]] = matches[2].strip
      params[matches[1]] = "true" unless params[matches[1]].present?
      command_string = command_string.slice(0, last_index)
    end

    command_string = command_string.strip
    [params, command_string]
  end
end
