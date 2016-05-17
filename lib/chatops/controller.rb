module ChatOps
  module Controller
    extend ActiveSupport::Concern

    included do
      before_filter :ensure_chatops_authenticated, :only => [:execute, :list]
      before_filter :ensure_user_given, :only => [:execute, :list]
    end

    def execute
      method = params[:method].to_sym
      return jsonrpc_method_not_found unless self.class.chatops[method].present?

      send method
    end

    def list
      render :json => {
        namespace: self.class.chatops_namespace,
        help: self.class.chatops_help,
        methods: self.class.chatops }
    end

    def jsonrpc_params
      params["params"] || {}
    end

    def jsonrpc_success(message)
      jsonrpc_response :result => message
    end

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
      jsonrpc_error(-32602, 400, message)
    end

    def jsonrpc_error(number, http_status, message)
      jsonrpc_response({ :error => { :code => number, :message => message } }, http_status)
    end

    def jsonrpc_response(hash, http_status = nil)
      http_status ||= 200
      render :status => http_status,
             :json => { :jsonrpc => "2.0",
                        :id      => params[:id] }.merge(hash)
    end

    def ensure_user_given
      return true unless params[:action] == "execute"
      return true if params[:user].present?
      jsonrpc_invalid_params("A username must be supplied as 'user'")
    end

    def ensure_chatops_authenticated
      return true unless %w{execute list}.include?(params[:action])
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

    module ClassMethods
      def chatop(method_name, regex, help, &block)
        chatops[method_name] = { help: help,
                                 regex: regex.source,
                                 params: regex.names }
        define_method method_name, &block
      end

      def chatops_namespace(namespace = nil)
        if namespace.present?
          @chatops_namespace = namespace
        end
        @chatops_namespace
      end

      def chatops_help(help = nil)
        if help.present?
          @chatops_help = help
        end
        @chatops_help
      end

      def chatops
        @chatops ||= {}
        @chatops
      end
    end
  end
end
