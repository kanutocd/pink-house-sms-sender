# frozen_string_literal: true

require "test_helper"
require "sms/sender/providers/semaphore"

module Sms
  module Sender
    class TestSemaphore < Minitest::Test
      def test_maps_accepted_response_and_form_request
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 200, body: '[{"message_id":12345,"status":"Queued"}]')
        end
        provider = build_provider(http)

        delivery = provider.deliver(Message.new(to: "+639171234567", body: "Hello"))

        assert_equal :accepted, delivery.status
        assert_equal :semaphore, delivery.provider
        assert_equal "12345", delivery.provider_message_id
        assert_equal "https://example.test/api/v4/messages", calls.first[:url]
        assert_equal "application/x-www-form-urlencoded", calls.first[:headers]["Content-Type"]
        assert_equal(
          { "apikey" => "secret", "number" => "+639171234567", "message" => "Hello", "sendername" => "MyApp" },
          URI.decode_www_form(calls.first[:body]).to_h
        )
      end

      def test_uses_default_base_url_without_sender
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 200, body: '[{"message_id":12345,"status":"Sent"}]')
        end
        build_provider(http, settings: { api_key: "secret" }).deliver(Message.new(to: "+1", body: "Hello"))

        assert_equal "https://api.semaphore.co/api/v4/messages", calls.first[:url]
        refute URI.decode_www_form(calls.first[:body]).to_h.key?("sendername")
      end

      def test_rejects_invalid_configuration_and_message
        provider = build_provider(->(**) { raise "not called" }, settings: {})

        assert_raises(Errors::ConfigurationError) { provider.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(ArgumentError) { provider.deliver(Object.new) }
      end

      def test_maps_http_failures
        [
          [400, Errors::InvalidRequest],
          [401, Errors::Authentication],
          [429, Errors::RateLimited],
          [503, Errors::ProviderUnavailable],
          [418, Errors::Unknown]
        ].each do |status, error_class|
          body = status == 418 ? "[]" : "{}"
          provider = build_provider(->(**) { HTTP::Response.new(status: status, body: body) })

          assert_raises(error_class) { provider.deliver(Message.new(to: "+1", body: "Hello")) }
        end
      end

      def test_maps_rejected_and_malformed_responses
        failed = build_provider(->(**) { HTTP::Response.new(status: 200, body: '[{"status":"Failed"}]') })
        refunded = build_provider(->(**) { HTTP::Response.new(status: 200, body: '[{"status":"Refunded"}]') })
        malformed = build_provider(->(**) { HTTP::Response.new(status: 200, body: "not-json") })
        invalid = build_provider(->(**) { HTTP::Response.new(status: 200, body: "{}") })

        assert_raises(Errors::ProviderRejected) { failed.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(Errors::ProviderRejected) { refunded.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(Errors::Unknown) { malformed.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(Errors::Unknown) { invalid.deliver(Message.new(to: "+1", body: "Hello")) }
      end

      private

      def build_provider(http, settings: { api_key: "secret", sender: "MyApp", base_url: "https://example.test" })
        configuration = ProviderConfiguration.new(name: :semaphore, settings: settings)
        Providers::Semaphore.new(configuration: configuration, http: HTTP::Client.new(transport: http))
      end
    end
  end
end
