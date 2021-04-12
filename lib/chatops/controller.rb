require "chatops"

module Chatops
  module Controller
    class ConfigurationError < StandardError ; end
    extend ActiveSupport::Concern

    included do
      before_action :ensure_valid_chatops_url,       if: :should_authenticate_chatops?
      before_action :ensure_valid_chatops_timestamp, if: :should_authenticate_chatops?
      before_action :ensure_valid_chatops_signature, if: :should_authenticate_chatops?
      before_action :ensure_valid_chatops_nonce,     if: :should_authenticate_chatops?
      before_action :ensure_chatops_authenticated,   if: :should_authenticate_chatops?
      before_action :ensure_user_given
      before_action :ensure_method_exists
    end

    def list
      chatops = self.class.chatops
      chatops.each { |name, hash| hash[:path] = name }
      render :json => {
        namespace: self.class.chatops_namespace,
        help: self.class.chatops_help,
        error_response: self.class.chatops_error_response,
        methods: chatops,
        version: "3" }
    end

    def process(*args)
      setup_params!

      if params[:chatop].present?
        params[:action] = params[:chatop]
        args[0] = params[:action]
        unless self.respond_to?(params[:chatop].to_sym)
          raise AbstractController::ActionNotFound
        end
      end

      super(*args)
    rescue AbstractController::ActionNotFound
      return jsonrpc_method_not_found
    end

    def execute_chatop
      # This needs to exist for route declarations, but we'll be overriding
      # things in #process to make a method the action.
    end

    protected

    def setup_params!
      json_body.each do |key, value|
        next if params.has_key? key
        params[key] = value
      end

      @jsonrpc_params = params.delete(:params) if params.has_key? :params

      self.params = params.permit(:action, :chatop, :controller, :id, :mention_slug, :message_id, :method, :room_id, :user)
    end

    def jsonrpc_params
      @jsonrpc_params ||= ActionController::Parameters.new
    end

    def json_body
      hash = {}
      if request.content_mime_type == Mime[:json]
        hash = ActiveSupport::JSON.decode(request.raw_post) || {}
      end
      hash.with_indifferent_access
    end

    # `options` supports any of the optional fields documented
    # in the [protocol](../../docs/protocol-description.md).
    def jsonrpc_success(message, options: {})
      response = { :result => message.to_s }
      # do not allow options to override message
      options.delete(:result)
      jsonrpc_response response.merge(options)
    end
    alias_method :chatop_send, :jsonrpc_success

    def jsonrpc_parse_error
      jsonrpc_error(-32700, 500, "Parse error")
    end

    def jsonrpc_invalid_request
      jsonrpc_error(-32600, 400, "Invalid request")
    end

    def jsonrpc_method_not_found
      jsonrpc_error(-32601, 404, "Method not found")
    end

    def jsonrpc_invalid_params(message)
      message ||= "Invalid parameters"
      jsonrpc_error(-32602, 400, message.to_s)
    end
    alias_method :jsonrpc_failure, :jsonrpc_invalid_params

    def jsonrpc_error(number, http_status, message)
      jsonrpc_response({ :error => { :code => number, :message => message.to_s } }, http_status)
    end

    def jsonrpc_response(hash, http_status = nil)
      http_status ||= 200
      render :status => http_status,
             :json => { :jsonrpc => "2.0",
                        :id      => params[:id] }.merge(hash)
    end

    def ensure_user_given
      return true unless chatop_names.include?(params[:action].to_sym)
      return true if params[:user].present?
      jsonrpc_invalid_params("A username must be supplied as 'user'")
    end

    def ensure_chatops_authenticated
      body = request.raw_post || ""
      signature_string = [@chatops_url, @chatops_nonce, @chatops_timestamp, body].join("\n")
      # We return this just to aid client debugging.
      response.headers["Chatops-Signature-String"] = Base64.strict_encode64(signature_string)
      raise ConfigurationError.new("You need to add a client's public key in .pem format via #{Chatops.public_key_env_var_name}") unless Chatops.public_key.present?
      if signature_valid?(Chatops.public_key, @chatops_signature, signature_string) ||
          signature_valid?(Chatops.alt_public_key, @chatops_signature, signature_string)
          return true
      end
      return jsonrpc_error(-32800, 403, "Not authorized")
    end

    def ensure_valid_chatops_url
      unless Chatops.auth_base_url.present?
        raise ConfigurationError.new("You need to set the server's base URL to authenticate chatops RPC via #{Chatops.auth_base_url_env_var_name}")
      end
      if Chatops.auth_base_url[-1] == "/"
        raise ConfigurationError.new("Don't include a trailing slash in #{Chatops.auth_base_url_env_var_name}; the rails path will be appended and it must match exactly.")
      end
      @chatops_url = Chatops.auth_base_url + request.path
    end

    def ensure_valid_chatops_nonce
      @chatops_nonce = request.headers["Chatops-Nonce"]
      return jsonrpc_error(-32801, 403, "A Chatops-Nonce header is required") unless @chatops_nonce.present?
    end

    def ensure_valid_chatops_signature
      signature_header = request.headers["Chatops-Signature"]

      begin
        # "Chatops-Signature: Signature keyid=foo,signature=abc123" => { "keyid"" => "foo", "signature" => "abc123" }
        signature_items = signature_header.split(" ", 2)[1].split(",").map { |item| item.split("=", 2) }.to_h
        @chatops_signature = signature_items["signature"]
      rescue NoMethodError
        # The signature header munging, if something's amiss, can produce a `nil` that raises a
        # no method error. We'll just carry on; the nil signature will raise below
      end

      unless @chatops_signature.present?
        return jsonrpc_error(-32802, 403, "Failed to parse signature header")
      end
    end

    def ensure_valid_chatops_timestamp
      @chatops_timestamp = request.headers["Chatops-Timestamp"]
      time = Time.iso8601(@chatops_timestamp)
      if !(time > 1.minute.ago && time < 1.minute.from_now)
        return jsonrpc_error(-32803, 403, "Chatops timestamp not within 1 minute of server time: #{@chatops_timestamp} vs #{Time.now.utc.iso8601}")
      end
    rescue ArgumentError, TypeError
      # time parsing or missing can raise these
      return jsonrpc_error(-32804, 403, "Invalid Chatops-Timestamp: #{@chatops_timestamp}")
    end

    def request_is_chatop?
      (chatop_names + [:list]).include?(params[:action].to_sym)
    end

    def chatops_test_auth?
      Rails.env.test? && request.env["CHATOPS_TESTING_AUTH"]
    end

    def should_authenticate_chatops?
      request_is_chatop? && !chatops_test_auth?
    end

    def signature_valid?(key_string, signature, signature_string)
      return false unless key_string.present?
      digest = OpenSSL::Digest::SHA256.new
      decoded_signature = Base64.decode64(signature)
      public_key = OpenSSL::PKey::RSA.new(key_string)
      public_key.verify(digest, decoded_signature, signature_string)
    end

    def ensure_method_exists
      return jsonrpc_method_not_found unless (chatop_names + [:list]).include?(params[:action].to_sym)
    end

    def chatop_names
      self.class.chatops.keys
    end

    module ClassMethods
      def chatop(method_name, regex, help, &block)
        chatops[method_name] = { help: help,
                                 regex: regex.source,
                                 params: regex.names }
        define_method method_name, &block
      end

      %w{namespace help error_response}.each do |setting|
        method_name = "chatops_#{setting}".to_sym
        variable_name = "@#{method_name}".to_sym
        define_method method_name do |*args|
          assignment = args.first
          if assignment.present?
            instance_variable_set variable_name, assignment
          end
          instance_variable_get variable_name.to_sym
        end
      end

      def chatops
        @chatops ||= {}
        @chatops
      end
    end
  end
end
