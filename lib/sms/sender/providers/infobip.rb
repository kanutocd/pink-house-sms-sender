# frozen_string_literal: true

require "json"

module Sms
  module Sender
    module Providers
      # Infobip HTTP adapter for advanced SMS message submission.
      class Infobip < Provider
        # Default Infobip SMS API base URL.
        BASE_URL = "https://api.infobip.com"
        # Infobip advanced SMS endpoint path.
        SEND_PATH = "/sms/3/messages"

        # @param configuration [ProviderConfiguration] Infobip settings
        # @param http [HTTP::Client] injectable HTTP client
        def initialize(configuration:, http: HTTP::Client.new)
          super(configuration: configuration)
          @http = http
        end

        # Submit an SMS through Infobip.
        # @param message [Message] normalized outbound message
        # @return [Delivery] accepted provider response
        def deliver(message)
          validate_message(message)
          response = @http.request(:post, endpoint, headers: headers, body: request_body(message))
          map_response(response)
        end

        private

        def endpoint
          "#{configuration[:base_url] || BASE_URL}#{SEND_PATH}"
        end

        def headers
          { "Authorization" => "App #{api_key}", "Content-Type" => "application/json", "Accept" => "application/json" }
        end

        def api_key
          key = configuration[:api_key]
          return key.to_s unless key.nil? || key.to_s.empty?

          raise Errors::ConfigurationError.new("Infobip api_key is required", category: :configuration,
                                                                              provider: :infobip)
        end

        def sender
          value = configuration[:from] || configuration[:sender]
          return value.to_s unless value.nil? || value.to_s.empty?

          raise Errors::ConfigurationError.new("Infobip from or sender is required", category: :configuration,
                                                                                     provider: :infobip)
        end

        def request_body(message)
          {
            "messages" => [
              {
                "sender" => sender,
                "destinations" => [{ "to" => message.to }],
                "content" => { "text" => message.body }
              }
            ]
          }
        end

        def map_response(response)
          payload = JSON.parse(response.body.to_s)
          return map_failure(response.status, payload) unless response.successful?

          result = payload.is_a?(Hash) && payload["messages"]&.first
          raise TypeError unless result.is_a?(Hash) && result["messageId"]

          Delivery.new(status: :accepted, provider: :infobip, provider_message_id: result["messageId"],
                       metadata: payload)
        rescue JSON::ParserError, TypeError, NoMethodError
          raise Errors::Unknown.new("Infobip returned an invalid response", category: :malformed_response,
                                                                            provider: :infobip)
        end

        def map_failure(status, payload)
          message = payload.is_a?(Hash) ? payload["requestError"] : nil
          if message.is_a?(Hash) && message["serviceException"].is_a?(Hash)
            message = message["serviceException"]["text"]
          end
          message ||= "Infobip request failed with HTTP #{status}"
          error_class = case status
                        when 400 then Errors::InvalidRequest
                        when 401 then Errors::Authentication
                        when 403 then Errors::Authorization
                        when 429 then Errors::RateLimited
                        when 500..599 then Errors::ProviderUnavailable
                        else Errors::Unknown
                        end
          raise error_class.new(message, category: error_class.name.split("::").last.downcase.to_sym,
                                         provider: :infobip)
        end

        def validate_message(message)
          return if message.is_a?(Message)

          raise ArgumentError, "message must be a Sms::Sender::Message"
        end
      end
    end
  end
end
