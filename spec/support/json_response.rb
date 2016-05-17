module RSpec
  module JSONResponse
    def json_response(response = @response)
      @json_responses ||= {}
      @json_responses[response] ||= JSON.load(response.body)
    end

    RSpec::Matchers.define :be_valid_json do
      match do |response|
        begin
          json_response(response)
          true
        rescue StandardError => ex
          @exception = ex
          false
        end
      end

      failure_message do |response|
        %{Expected response body to be valid json, but there was an error parsing it:\n  #{@exception.inspect}}
      end
    end

    ::RSpec.configure do |config|
      config.include self
    end
  end
end
