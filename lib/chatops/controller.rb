module ChatOps
  module Controller
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
        methods: chatops }
    end

    def process(*args)
      scrubbed_params = jsonrpc_params.except(
        :user, :method, :controller, :action, :params, :room_id)

      scrubbed_params.each { |k, v| params[k] = v }

      super
    rescue AbstractController::ActionNotFound
      return jsonrpc_method_not_found
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
      return true unless (chatop_names + [:list]).include?(params[:action].to_sym)
      authenticated = authenticate_with_http_basic do |u, p|
        if ENV["CHATOPS_AUTH_TOKEN"].nil?
          raise StandardError, "Attempting to authenticate chatops with nil token"
        end
        if ENV["CHATOPS_ALT_AUTH_TOKEN"].nil?
          raise StandardError, "Attempting to authenticate chatops with nil alternate token"
        end

        Rack::Utils.secure_compare(ENV["CHATOPS_AUTH_TOKEN"], p) ||
        Rack::Utils.secure_compare(ENV["CHATOPS_ALT_AUTH_TOKEN"], p)
      end
      unless authenticated
        render :status => :forbidden, :text => "Not authorized"
      end
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
