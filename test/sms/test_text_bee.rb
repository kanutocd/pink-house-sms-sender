# frozen_string_literal: true

require "test_helper"
require "sms/sender/providers/text_bee"

module Sms
  module Sender
    class TestTextBee < Minitest::Test
      def test_maps_accepted_response_to_delivery
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 200, body: { "data" => { "smsBatchId" => "batch-123" } }.to_json)
        end
        provider = build_provider(http)

        delivery = provider.deliver(Message.new(to: "+639171234567", body: "Hello"))

        assert_equal :accepted, delivery.status
        assert_equal :textbee, delivery.provider
        assert_equal "batch-123", delivery.provider_message_id
        assert_equal :post, calls.first[:method]
        assert_equal "https://example.test/api/v1/gateway/send-sms", calls.first[:url]
        assert_equal "secret", calls.first[:headers]["x-api-key"]
        assert_equal(
          { "recipients" => ["+639171234567"], "message" => "Hello", "deviceId" => "device-1" },
          JSON.parse(calls.first[:body])
        )
      end

      def test_uses_default_device_and_base_url_when_not_configured
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 200, body: '{"data":{}}')
        end
        provider = build_provider(http, settings: { api_key: "secret" })

        provider.deliver(Message.new(to: "+1", body: "Hello"))

        assert_equal "https://api.textbee.dev/api/v1/gateway/send-sms", calls.first[:url]
        refute JSON.parse(calls.first[:body]).key?("deviceId")
      end

      def test_rejects_missing_api_key_and_invalid_message
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
          provider = build_provider(->(**) { HTTP::Response.new(status: status, body: '{"message":"failed"}') })

          assert_raises(error_class) { provider.deliver(Message.new(to: "+1", body: "Hello")) }
        end
      end

      def test_maps_rejections_and_malformed_responses
        rejected = build_provider(lambda { |**|
          HTTP::Response.new(status: 200, body: '{"data":{"success":false,"message":"rejected"}}')
        })
        malformed = build_provider(->(**) { HTTP::Response.new(status: 200, body: "not-json") })
        invalid = build_provider(->(**) { HTTP::Response.new(status: 200, body: "{}") })

        assert_raises(Errors::ProviderRejected) { rejected.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(Errors::Unknown) { malformed.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(Errors::Unknown) { invalid.deliver(Message.new(to: "+1", body: "Hello")) }
      end

      private

      def build_provider(http,
                         settings: { api_key: "secret", device_id: "device-1", base_url: "https://example.test/" })
        configuration = ProviderConfiguration.new(name: :textbee, settings: settings)
        Providers::TextBee.new(configuration: configuration, http: HTTP::Client.new(transport: http))
      end
    end
  end
end
