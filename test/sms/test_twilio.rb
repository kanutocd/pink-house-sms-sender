# frozen_string_literal: true

require "base64"
require "test_helper"
require "sms/sender/providers/twilio"

module Sms
  module Sender
    class TestTwilio < Minitest::Test
      def test_maps_from_request_and_accepted_response
        calls, delivery = accepted_delivery

        assert_accepted_delivery(calls, delivery)
      end

      def assert_accepted_delivery(calls, delivery)
        assert_equal :accepted, delivery.status
        assert_equal :twilio, delivery.provider
        assert_equal "SM123", delivery.provider_message_id
        assert_request(calls)
      end

      def assert_request(calls)
        assert_equal "https://example.test/AC123/Messages.json", calls.first[:url]
        assert_equal "Basic #{Base64.strict_encode64("AC123:token")}", calls.first[:headers]["Authorization"]
        assert_equal(
          { "To" => "+639171234567", "Body" => "Hello", "From" => "+15551234567" },
          URI.decode_www_form(calls.first[:body]).to_h
        )
      end

      def test_supports_messaging_service_and_default_base_url
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 200, body: '{"sid":"SM456"}')
        end
        build_provider(http, settings: { account_sid: "AC123", auth_token: "token", messaging_service_sid: "MG123" })
          .deliver(Message.new(to: "+1", body: "Hello"))

        assert_equal "https://api.twilio.com/2010-04-01/Accounts/AC123/Messages.json", calls.first[:url]
        assert_equal "MG123", URI.decode_www_form(calls.first[:body]).to_h.fetch("MessagingServiceSid")
      end

      def test_rejects_invalid_configuration_and_message
        provider = build_provider(->(**) { raise "not called" }, settings: {})

        assert_raises(Errors::ConfigurationError) { provider.deliver(Message.new(to: "+1", body: "Hello")) }
        provider = build_provider(->(**) { raise "not called" }, settings: { account_sid: "AC", auth_token: "token" })
        assert_raises(Errors::ConfigurationError) { provider.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(ArgumentError) { provider.deliver(Object.new) }
      end

      def test_maps_http_failures
        [
          [400, Errors::InvalidRequest, '{"message":"bad"}'],
          [400, Errors::InvalidRecipient, '{"code":21211,"message":"bad number"}'],
          [401, Errors::Authentication, "{}"],
          [403, Errors::Authorization, "{}"],
          [429, Errors::RateLimited, "{}"],
          [503, Errors::ProviderUnavailable, "{}"],
          [418, Errors::Unknown, "[]"]
        ].each { |status, error_class, body| assert_failure(status, error_class, body) }
      end

      def test_maps_malformed_responses
        malformed = build_provider(->(**) { HTTP::Response.new(status: 200, body: "not-json") })
        missing_sid = build_provider(->(**) { HTTP::Response.new(status: 200, body: "{}") })

        assert_raises(Errors::Unknown) { malformed.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(Errors::Unknown) { missing_sid.deliver(Message.new(to: "+1", body: "Hello")) }
      end

      private

      def accepted_delivery
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 201, body: '{"sid":"SM123","status":"queued"}')
        end
        [calls, build_provider(http).deliver(Message.new(to: "+639171234567", body: "Hello"))]
      end

      def assert_failure(status, error_class, body)
        provider = build_provider(->(**) { HTTP::Response.new(status: status, body: body) })
        assert_raises(error_class) { provider.deliver(Message.new(to: "+1", body: "Hello")) }
      end

      def build_provider(http, settings: default_settings)
        configuration = ProviderConfiguration.new(name: :twilio, settings: settings)
        Providers::Twilio.new(configuration: configuration, http: HTTP::Client.new(transport: http))
      end

      def default_settings
        { account_sid: "AC123", auth_token: "token", from: "+15551234567", base_url: "https://example.test" }
      end
    end
  end
end
