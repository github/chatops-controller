module ChatOps
  module Controller
    class ConfigurationError < StandardError ; end
    extend ActiveSupport::Concern

    included do
      before_action :ensure_chatops_authenticated
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
      scrubbed_params = jsonrpc_params.except(
        :user, :method, :controller, :action, :params, :room_id)

      scrubbed_params.each { |k, v| params[k] = v }

      if params[:chatop].present?
        params[:action] = params[:chatop]
        args[0] = params[:action]
        unless self.respond_to?(params[:chatop].to_sym)
          raise AbstractController::ActionNotFound
        end
      end

      super *args
    rescue AbstractController::ActionNotFound
      return jsonrpc_method_not_found
    end

    def execute_chatop
      # This needs to exist for route declarations, but we'll be overriding
      # things in #process to make a method the action.
    end

    protected

    def jsonrpc_params
      params["params"] || {}
    end

    def jsonrpc_success(message)
      jsonrpc_response :result => message.to_s
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
      return true if Rails.env.test? && request.env["CHATOPS_TESTING_AUTH"]
      return true unless (chatop_names + [:list]).include?(params[:action].to_sym)
      authenticated = false

      raise ConfigurationError.new("You need to set the server's base URL to authenticate chatops RPC via CHATOPS_AUTH_BASE_URL") unless ENV["CHATOPS_AUTH_BASE_URL"].present?
      url = ENV["CHATOPS_AUTH_BASE_URL"] + request.path
      nonce = request.headers['X-Chatops-Nonce'] 
      timestamp = request.headers['X-Chatops-Timestamp']
      begin
        time = Time.parse(timestamp)
        if !(time > 1.minute.ago && time < 1.minute.from_now)
          return invalid_time
        end
      rescue ArgumentError, TypeError
        return invalid_time
      end
      signature_header = request.headers['X-Chatops-Signature']

      begin
        signature_items = signature_header.split(" ", 2)[1].split(",").map { |item| item.split("=", 2) }.to_h
        signature = signature_items["signature"]
      rescue NoMethodError
      end

      unless signature.present?
        return render :status => :forbidden, :plain => "Failed to parse signature header"
      end

      if url.present? && nonce.present? && timestamp.present? && signature.present?
        body = request.raw_post || ""
        signature_string = [url, nonce, timestamp, body].join("\n")
        response.headers['X-Chatops-SignatureString'] = signature_string
        decoded_signature = Base64.decode64(signature)
        digest = OpenSSL::Digest::SHA256.new
        raise ConfigurationError.new("You need to add a client's public key in .pem format via CHATOPS_AUTH_PUBLIC_KEY") unless ENV["CHATOPS_AUTH_PUBLIC_KEY"].present?
        if ENV["CHATOPS_AUTH_PUBLIC_KEY"].present?
          public_key = OpenSSL::PKey::RSA.new(ENV["CHATOPS_AUTH_PUBLIC_KEY"])
          authenticated = public_key.verify(digest, decoded_signature, signature_string)
        end
        if !authenticated && ENV["CHATOPS_AUTH_ALT_PUBLIC_KEY"].present?
          public_key = OpenSSL::PKey::RSA.new(ENV["CHATOPS_AUTH_ALT_PUBLIC_KEY"])
          authenticated = public_key.verify(digest, decoded_signature, signature_string)
        end
      end
      unless authenticated
        render :status => :forbidden, :plain => "Not authorized"
      end
    end

    def invalid_time
      render :status => :forbidden, :plain => "Invalid X-Chatops-Timestamp: #{request.headers['X-Chatops-Timestamp']}"
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
