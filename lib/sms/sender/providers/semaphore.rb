# frozen_string_literal: true

require "json"
require "uri"

module Sms
  module Sender
    module Providers
      # Semaphore HTTP adapter for Philippine SMS delivery.
      class Semaphore < Provider
        # Default hosted Semaphore API base URL.
        BASE_URL = "https://api.semaphore.co"
        # Semaphore SMS submission endpoint path.
        SEND_PATH = "/api/v4/messages"

        # @param configuration [ProviderConfiguration] Semaphore settings
        # @param http [HTTP::Client] injectable HTTP client
        def initialize(configuration:, http: HTTP::Client.new)
          super(configuration: configuration)
          @http = http
        end

        # Submit an SMS through Semaphore.
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
          { "Content-Type" => "application/x-www-form-urlencoded" }
        end

        def api_key
          key = configuration[:api_key]
          return key.to_s unless key.nil? || key.to_s.empty?

          raise Errors::ConfigurationError.new("Semaphore api_key is required", category: :configuration,
                                                                                provider: :semaphore)
        end

        def request_body(message)
          fields = { "apikey" => api_key, "number" => message.to, "message" => message.body }
          fields["sendername"] = configuration[:sender] if configuration[:sender]
          URI.encode_www_form(fields)
        end

        def map_response(response)
          payload = JSON.parse(response.body.to_s)
          return map_failure(response.status, payload) unless response.successful?

          result = payload.first
          raise TypeError unless result.is_a?(Hash)
          if result["status"].to_s.casecmp("failed").zero? || result["status"].to_s.casecmp("refunded").zero?
            return map_rejection(result)
          end

          Delivery.new(
            status: :accepted,
            provider: :semaphore,
            provider_message_id: result["message_id"].to_s,
            metadata: result
          )
        rescue JSON::ParserError, TypeError, NoMethodError
          raise Errors::Unknown.new("Semaphore returned an invalid response", category: :malformed_response,
                                                                              provider: :semaphore)
        end

        def map_failure(status, payload)
          message = payload.is_a?(Hash) ? payload["message"] : nil
          message ||= "Semaphore request failed with HTTP #{status}"
          error_class = case status
                        when 401 then Errors::Authentication
                        when 429 then Errors::RateLimited
                        when 400 then Errors::InvalidRequest
                        when 500..599 then Errors::ProviderUnavailable
                        else Errors::Unknown
                        end
          raise error_class.new(message, category: error_class.name.split("::").last.downcase.to_sym,
                                         provider: :semaphore)
        end

        def map_rejection(_result)
          raise Errors::ProviderRejected.new("Semaphore rejected the message", category: :provider_rejected,
                                                                               provider: :semaphore)
        end

        def validate_message(message)
          return if message.is_a?(Message)

          raise ArgumentError, "message must be a Sms::Sender::Message"
        end
      end
    end
  end
end
