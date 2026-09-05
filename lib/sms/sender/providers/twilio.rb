# frozen_string_literal: true

require "base64"
require "json"
require "uri"

module Sms
  module Sender
    module Providers
      # Twilio HTTP adapter for SMS message submission.
      class Twilio < Provider
        # Default Twilio REST API base URL.
        BASE_URL = "https://api.twilio.com/2010-04-01/Accounts"
        # Twilio message resource suffix.
        SEND_PATH = "/Messages.json"

        # @param configuration [ProviderConfiguration] Twilio settings
        # @param http [HTTP::Client] injectable HTTP client
        def initialize(configuration:, http: HTTP::Client.new)
          super(configuration: configuration)
          @http = http
        end

        # Submit an SMS through Twilio.
        # @param message [Message] normalized outbound message
        # @return [Delivery] accepted provider response
        def deliver(message)
          validate_message(message)
          response = @http.request(:post, endpoint, headers: headers, body: request_body(message))
          map_response(response)
        end

        private

        def endpoint
          "#{configuration[:base_url] || BASE_URL}/#{account_sid}#{SEND_PATH}"
        end

        def headers
          {
            "Authorization" => "Basic #{Base64.strict_encode64("#{account_sid}:#{auth_token}")}",
            "Content-Type" => "application/x-www-form-urlencoded"
          }
        end

        def account_sid
          required_setting(:account_sid, "Twilio account_sid is required")
        end

        def auth_token
          required_setting(:auth_token, "Twilio auth_token is required")
        end

        def required_setting(key, message)
          value = configuration[key]
          return value.to_s unless value.nil? || value.to_s.empty?

          raise Errors::ConfigurationError.new(message, category: :configuration, provider: :twilio)
        end

        def request_body(message)
          fields = { "To" => message.to, "Body" => message.body }
          sender_key = configuration[:from] ? "From" : "MessagingServiceSid"
          sender = configuration[:from] || configuration[:messaging_service_sid]
          if sender.nil? || sender.to_s.empty?
            raise Errors::ConfigurationError.new("Twilio from or messaging_service_sid is required",
                                                 category: :configuration, provider: :twilio)
          end

          fields[sender_key] = sender
          URI.encode_www_form(fields)
        end

        def map_response(response)
          payload = JSON.parse(response.body.to_s)
          return map_failure(response.status, payload) unless response.successful?
          raise TypeError unless payload.is_a?(Hash) && payload["sid"]

          Delivery.new(status: :accepted, provider: :twilio, provider_message_id: payload["sid"], metadata: payload)
        rescue JSON::ParserError, TypeError, NoMethodError
          raise Errors::Unknown.new(
            "Twilio returned an invalid response",
            category: :malformed_response,
            provider: :twilio
          )
        end

        def map_failure(status, payload)
          message = payload.is_a?(Hash) ? payload["message"] : nil
          message ||= "Twilio request failed with HTTP #{status}"
          error_class = failure_class(status, payload)
          raise error_class.new(message, category: error_class.name.split("::").last.downcase.to_sym,
                                         provider: :twilio)
        end

        def failure_class(status, payload)
          return Errors::InvalidRecipient if invalid_recipient?(status, payload)

          {
            400 => Errors::InvalidRequest,
            401 => Errors::Authentication,
            403 => Errors::Authorization,
            429 => Errors::RateLimited
          }.fetch(status) { status.between?(500, 599) ? Errors::ProviderUnavailable : Errors::Unknown }
        end

        def invalid_recipient?(status, payload)
          status == 400 && payload.is_a?(Hash) && payload["code"].to_i == 21_211
        end

        def validate_message(message)
          return if message.is_a?(Message)

          raise ArgumentError, "message must be a Sms::Sender::Message"
        end
      end
    end
  end
end
