require 'rails_helper'
require 'openssl'
require 'base64'

describe ActionController::Base, type: :controller do
 controller do
    include ChatOps::Controller
    chatops_namespace :test
    chatops_help "ChatOps of and relating to testing"
    chatops_error_response "Try checking haystack?"

    before_filter :ensure_app_given, :only => [:wcid]

    chatop :wcid,
    /(?:where can i deploy|wcid)(?: (?<app>\S+))?/,
    "where can i deploy?" do
      return jsonrpc_invalid_params("I need nope, sorry") if params[:app] == "nope"
      jsonrpc_success "You can deploy #{params["app"]} just fine."
    end

    chatop :foobar,
    /(?:how can i foo and bar all at once)?/,
    "how to foo and bar" do
      raise "there's always params" unless jsonrpc_params.respond_to?(:[])
      jsonrpc_success "You just foo and bar like it just don't matter"
    end

    skip_before_filter :ensure_method_exists, only: :non_chatop_method
    def non_chatop_method
      render :text => "Why would you have something thats not a chatop?"
    end

    def unexcluded_chatop_method
      render :text => "Sadly, I'll never be reached"
    end

    def ensure_app_given
      return jsonrpc_invalid_params("I need an app, every time") unless params[:app].present?
    end
  end

  before :each do
    routes.draw do
      get  "/_chatops" => "anonymous#list"
      post  "/_chatops/:action", controller: "anonymous"
      get  "/other" => "anonymous#non_chatop_method"
      get  "/other_will_fail" => "anonymous#unexcluded_chatop_method"
    end

    @private_key = OpenSSL::PKey::RSA.new(2048)
    ENV["CHATOPS_AUTH_PUBLIC_KEY"] = @private_key.public_key.to_pem
    ENV["CHATOPS_AUTH_BASE_URL"] = "http://test.host"
  end

  it "requires authentication" do
    request.headers['X-Chatops-Timestamp'] = Time.now.utc.iso8601
    get :list
    expect(response.status).to eq 403
    expect(response.body).to eq "Not authorized"
  end

  it "allows public key authentication for a GET request" do
    nonce = SecureRandom.hex(20)
    timestamp = Time.now.utc.iso8601
    request.headers['X-Chatops-Nonce'] = nonce
    request.headers['X-Chatops-Timestamp'] = timestamp
    digest = OpenSSL::Digest::SHA256.new
    signature_string = "http://test.host/_chatops\n#{timestamp}\n#{nonce}\n"
    signature = Base64.encode64(@private_key.sign(digest, signature_string))
    request.headers['X-Chatops-Signature'] = signature
    get :list
    expect(response.status).to eq 200
    expect(response).to be_valid_json
  end

  it "allows public key authentication for a POST request" do
    nonce = SecureRandom.hex(20)
    timestamp = Time.now.utc.iso8601
    request.headers['X-Chatops-Nonce'] = nonce
    request.headers['X-Chatops-Timestamp'] = timestamp
    digest = OpenSSL::Digest::SHA256.new
    params = { :method => "foobar", :room_id => "123", :user => "bhuga", :params => {}}

    body = params.to_json
    @request.headers["Content-Type"] = 'application/json'
    @request.env["RAW_POST_DATA"] = body
    signature_string = "http://test.host/_chatops/foobar\n#{timestamp}\n#{nonce}\n#{body}"
    signature = Base64.encode64(@private_key.sign(digest, signature_string))
    request.headers['X-Chatops-Signature'] = signature

    post :foobar, params
    expect(response.status).to eq 200
    expect(response).to be_valid_json
  end

  it "allows using a second public key to authenticate" do
    ENV["CHATOPS_AUTH_ALT_PUBLIC_KEY"] = ENV["CHATOPS_AUTH_PUBLIC_KEY"]
    other_key = OpenSSL::PKey::RSA.new(2048)
    ENV["CHATOPS_AUTH_PUBLIC_KEY"] = other_key.public_key.to_pem
    nonce = SecureRandom.hex(20)
    timestamp = Time.now.utc.iso8601
    request.headers['X-Chatops-Nonce'] = nonce
    request.headers['X-Chatops-Timestamp'] = timestamp
    digest = OpenSSL::Digest::SHA256.new
    signature_string = "http://test.host/_chatops\n#{timestamp}\n#{nonce}\n"
    signature = Base64.encode64(@private_key.sign(digest, signature_string))
    request.headers['X-Chatops-Signature'] = signature
    get :list
    expect(response.status).to eq 200
    expect(response).to be_valid_json
  end

  it "raises an error trying to auth without a base url" do
    nonce = SecureRandom.hex(20)
    timestamp = Time.now.utc.iso8601
    request.headers['X-Chatops-Nonce'] = nonce
    request.headers['X-Chatops-Timestamp'] = timestamp
    digest = OpenSSL::Digest::SHA256.new
    signature_string = "http://test.host/_chatops\n#{timestamp}\n#{nonce}\n"
    signature = Base64.encode64(@private_key.sign(digest, signature_string))
    request.headers['X-Chatops-Signature'] = signature
    ENV.delete "CHATOPS_AUTH_BASE_URL"
    expect {
      get :list
    }.to raise_error(ChatOps::Controller::ConfigurationError)
  end

  it "raises an error trying to auth without a public key" do
    nonce = SecureRandom.hex(20)
    timestamp = Time.now.utc.iso8601
    request.headers['X-Chatops-Nonce'] = nonce
    request.headers['X-Chatops-Timestamp'] = timestamp
    digest = OpenSSL::Digest::SHA256.new
    signature_string = "http://test.host/_chatops\n#{timestamp}\n#{nonce}\n"
    signature = Base64.encode64(@private_key.sign(digest, signature_string))
    request.headers['X-Chatops-Signature'] = signature
    ENV.delete "CHATOPS_AUTH_PUBLIC_KEY"
    expect {
      get :list
    }.to raise_error(ChatOps::Controller::ConfigurationError)
  end

  it "doesn't authenticate with the wrong public key'" do
    other_key = OpenSSL::PKey::RSA.new(2048)
    ENV["CHATOPS_AUTH_PUBLIC_KEY"] = other_key.public_key.to_pem
    nonce = SecureRandom.hex(20)
    timestamp = Time.now.utc.iso8601
    request.headers['X-Chatops-Nonce'] = nonce
    request.headers['X-Chatops-Timestamp'] = timestamp
    digest = OpenSSL::Digest::SHA256.new
    signature_string = "http://test.host/_chatops\n#{timestamp}\n#{nonce}\n"
    signature = Base64.encode64(@private_key.sign(digest, signature_string))
    request.headers['X-Chatops-Signature'] = signature
    get :list
    expect(response.status).to eq 403
  end

  it "doesn't allow requests more than 1 minute old" do
    nonce = SecureRandom.hex(20)
    timestamp = 2.minutes.ago.utc.iso8601
    request.headers['X-Chatops-Nonce'] = nonce
    request.headers['X-Chatops-Timestamp'] = timestamp
    digest = OpenSSL::Digest::SHA256.new
    signature_string = "http://test.host/_chatops\n#{timestamp}\n#{nonce}\n"
    signature = Base64.encode64(@private_key.sign(digest, signature_string))
    request.headers['X-Chatops-Signature'] = signature
    get :list
    expect(response.status).to eq 403
  end

  it "does not add authentication to non-chatops routes" do
    get :non_chatop_method
    expect(response.status).to eq 200
    expect(response.body).to eq "Why would you have something thats not a chatop?"
  end

  context "when authenticated" do
    before do
      chatops_auth!
    end

    it "provides a list method" do
      get :list
      expect(response.status).to eq 200
      expect(json_response).to eq({
        "namespace" => "test",
        "help" => "ChatOps of and relating to testing",
        "error_response" => "Try checking haystack?",
        "methods" => {
          "wcid" => {
            "help" => "where can i deploy?",
            "regex" => /(?:where can i deploy|wcid)(?: (?<app>\S+))?/.source,
            "params" => ["app"],
            "path" => "wcid"
          },
          "foobar" => {
            "help" => "how to foo and bar",
            "regex" => /(?:how can i foo and bar all at once)?/.source,
            "params" => [],
            "path" => "foobar"
          }
        }
      })
    end

    it "requires a user be sent to chatops" do
      post :foobar
      expect(response.status).to eq 400
      expect(json_response).to eq({
        "jsonrpc" => "2.0",
        "id" => nil,
        "error" => {
          "code" => -32602,
          "message" => "A username must be supplied as 'user'"
        }
      })
    end

    it "returns method not found for a not found method" do
      post :barfoo, :user => "foo"
      expect(json_response).to eq({
        "jsonrpc" => "2.0",
        "id" => nil,
        "error" => {
          "code" => -32601,
          "message" => "Method not found"
        }
      })
      expect(response.status).to eq 404
    end

    it "requires skipping a before_filter to find non-chatop methods, sorry about that" do
      get :unexcluded_chatop_method
      expect(json_response).to eq({
        "jsonrpc" => "2.0",
        "id" => nil,
        "error" => {
          "code" => -32601,
          "message" => "Method not found"
        }
      })
      expect(response.status).to eq 404
    end

    it "runs a known method" do
      post :foobar, :user => "foo"
      expect(json_response).to eq({
        "jsonrpc" => "2.0",
        "id" => nil,
        "result" => "You just foo and bar like it just don't matter"
      })
      expect(response.status).to eq 200
    end

    it "passes parameters to methods" do
      post :wcid, :user => "foo", :params => { "app" => "foo" }
      expect(json_response).to eq({
        "jsonrpc" => "2.0",
        "id" => nil,
        "result" => "You can deploy foo just fine."
      })
      expect(response.status).to eq 200
    end

    it "uses typical controller fun like before_filter" do
      post :wcid, :user => "foo", :params => {}
      expect(json_response).to eq({
        "jsonrpc" => "2.0",
        "id" => nil,
        "error" => {
          "code" => -32602,
          "message" => "I need an app, every time"
        }
      })
      expect(response.status).to eq 400
    end

    it "allows methods to return invalid params with a message" do
      post :wcid, :user => "foo", :params => { "app" => "nope" }
      expect(response.status).to eq 400
      expect(json_response).to eq({
        "jsonrpc" => "2.0",
        "id" => nil,
        "error" => {
          "code" => -32602,
          "message" => "I need nope, sorry"
        }
      })
    end

    context "rspec helpers" do
      it "makes it easy to test a response" do
        chatop "wcid", :user => "foo", :app => "foo"
        expect(chatop_response).to eq "You can deploy foo just fine."
      end

      it "makes it easy to test an error message" do
        chatop "wcid", :user => "foo", :app => "nope"
        expect(chatop_error).to eq "I need nope, sorry"
      end
    end

    context "regex-based test helpers" do
      it "routes based on regexes from test helpers" do
        chat "where can i deploy foobar", "bhuga"
        expect(request.params["action"]).to eq "wcid"
        expect(request.params["user"]).to eq "bhuga"
        expect(request.params["params"]["app"]).to eq "foobar"
        expect(chatop_response).to eq "You can deploy foobar just fine."
      end

      it "works with generic arguments" do
        chat "where can i deploy foobar --fruit apple --vegetable green celery", "bhuga"
        expect(request.params["action"]).to eq "wcid"
        expect(request.params["user"]).to eq "bhuga"
        expect(request.params["params"]["app"]).to eq "foobar"
        expect(request.params["params"]["fruit"]).to eq "apple"
        expect(request.params["params"]["vegetable"]).to eq "green celery"
        expect(chatop_response).to eq "You can deploy foobar just fine."
      end

      it "works with boolean arguments" do
        chat "where can i deploy foobar --this-is-sparta", "bhuga"
        expect(request.params["action"]).to eq "wcid"
        expect(request.params["user"]).to eq "bhuga"
        expect(request.params["params"]["this-is-sparta"]).to eq "true"
      end

      it "anchors regexes" do
        expect {
          chat "too bad that this message doesn't start with where can i deploy foobar", "bhuga"
        }.to raise_error(ChatOps::Controller::TestCaseHelpers::NoMatchingCommandRegex)
      end
    end
  end
end
