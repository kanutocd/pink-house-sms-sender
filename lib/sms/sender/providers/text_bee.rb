# frozen_string_literal: true

require "json"

module Sms
  module Sender
    # Namespace for provider adapter implementations.
    module Providers
      # TextBee HTTP adapter.
      class TextBee < Provider
        # Default hosted TextBee API base URL.
        BASE_URL = "https://api.textbee.dev"
        # TextBee SMS submission endpoint path.
        SEND_PATH = "/api/v1/gateway/send-sms"

        # @param configuration [ProviderConfiguration] TextBee settings
        # @param http [HTTP::Client] injectable HTTP client
        def initialize(configuration:, http: HTTP::Client.new)
          super(configuration: configuration)
          @http = http
        end

        # Submit an SMS through TextBee.
        # @param message [Message] normalized outbound message
        # @return [Delivery] accepted provider response
        def deliver(message)
          validate_message(message)
          response = @http.request(:post, endpoint, headers: headers, body: request_body(message))
          map_response(response)
        end

        private

        def endpoint
          "#{base_url}#{SEND_PATH}"
        end

        def base_url
          value = configuration[:base_url] || BASE_URL
          value.to_s.sub(%r{/+$}, "")
        end

        def headers
          { "x-api-key" => api_key, "Content-Type" => "application/json" }
        end

        def api_key
          key = configuration[:api_key]
          return key.to_s unless key.nil? || key.to_s.empty?

          raise Errors::ConfigurationError.new("TextBee api_key is required", category: :configuration,
                                                                              provider: :textbee)
        end

        def request_body(message)
          body = { "recipients" => [message.to], "message" => message.body }
          device_id = configuration[:device_id]
          body["deviceId"] = device_id if device_id
          body
        end

        def map_response(response)
          payload = parse_payload(response.body)
          return map_failure(response.status, payload) unless response.successful?
          return map_rejection(payload) if payload.dig("data", "success") == false

          data = payload.fetch("data")
          Delivery.new(
            status: :accepted,
            provider: :textbee,
            provider_message_id: data["smsBatchId"],
            metadata: payload
          )
        rescue KeyError, TypeError
          raise Errors::Unknown.new("TextBee returned an invalid response", category: :malformed_response,
                                                                            provider: :textbee)
        end

        def parse_payload(body)
          JSON.parse(body.to_s)
        rescue JSON::ParserError
          raise Errors::Unknown.new("TextBee returned malformed JSON", category: :malformed_response,
                                                                       provider: :textbee)
        end

        def map_failure(status, payload)
          message = payload["message"] || "TextBee request failed with HTTP #{status}"
          error_class = case status
                        when 401 then Errors::Authentication
                        when 429 then Errors::RateLimited
                        when 400 then Errors::InvalidRequest
                        when 500..599 then Errors::ProviderUnavailable
                        else Errors::Unknown
                        end
          raise error_class.new(message, category: error_class.name.split("::").last.downcase.to_sym,
                                         provider: :textbee)
        end

        def map_rejection(payload)
          message = payload.dig("data", "message") || "TextBee rejected the message"
          raise Errors::ProviderRejected.new(message, category: :provider_rejected, provider: :textbee)
        end

        def validate_message(message)
          return if message.is_a?(Message)

          raise ArgumentError, "message must be a Sms::Sender::Message"
        end
      end
    end
  end
end
