# frozen_string_literal: true

require "test_helper"
require "sms/sender/providers/infobip"

module Sms
  module Sender
    class TestInfobip < Minitest::Test
      def test_maps_request_and_accepted_response
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 200,
                             body: '{"messages":[{"messageId":"abc-123","status":{"groupName":"PENDING"}}]}')
        end
        delivery = build_provider(http).deliver(Message.new(to: "+639171234567", body: "Hello"))

        assert_equal :accepted, delivery.status
        assert_equal :infobip, delivery.provider
        assert_equal "abc-123", delivery.provider_message_id
        assert_equal "https://example.test/sms/3/messages", calls.first[:url]
        assert_equal "App secret", calls.first[:headers]["Authorization"]
        assert_equal(
          { "messages" => [{ "sender" => "MyApp", "destinations" => [{ "to" => "+639171234567" }],
                             "content" => { "text" => "Hello" } }] },
          JSON.parse(calls.first[:body])
        )
      end

      def test_supports_default_base_url_and_from
        calls = []
        http = lambda do |**options|
          calls << options
          HTTP::Response.new(status: 200, body: '{"messages":[{"messageId":"abc-123"}]}')
        end
        build_provider(http,
                       settings: { api_key: "secret", from: "InfoSMS" }).deliver(Message.new(to: "+1", body: "Hi"))

        assert_equal "https://api.infobip.com/sms/3/messages", calls.first[:url]
        assert_equal "InfoSMS", JSON.parse(calls.first[:body]).dig("messages", 0, "sender")
      end

      def test_rejects_invalid_configuration_and_message
        provider = build_provider(->(**) { raise "not called" }, settings: {})

        assert_raises(Errors::ConfigurationError) { provider.deliver(Message.new(to: "+1", body: "Hi")) }
        provider = build_provider(->(**) { raise "not called" }, settings: { api_key: "secret" })
        assert_raises(Errors::ConfigurationError) { provider.deliver(Message.new(to: "+1", body: "Hi")) }
        assert_raises(ArgumentError) { provider.deliver(Object.new) }
      end

      def test_maps_http_failures
        [
          [400, Errors::InvalidRequest, "{}"], [401, Errors::Authentication, "{}"],
          [403, Errors::Authorization, "{}"], [429, Errors::RateLimited, "{}"],
          [503, Errors::ProviderUnavailable, "{}"], [418, Errors::Unknown, "[]"]
        ].each do |status, error_class, body|
          provider = build_provider(->(**) { HTTP::Response.new(status: status, body: body) })
          assert_raises(error_class) { provider.deliver(Message.new(to: "+1", body: "Hi")) }
        end
      end

      def test_maps_nested_error_and_malformed_responses
        error = '{"requestError":{"serviceException":{"text":"bad request"}}}'
        malformed = build_provider(->(**) { HTTP::Response.new(status: 400, body: error) })
        invalid = build_provider(->(**) { HTTP::Response.new(status: 200, body: "{}") })
        broken = build_provider(->(**) { HTTP::Response.new(status: 200, body: "not-json") })

        assert_raises(Errors::InvalidRequest) { malformed.deliver(Message.new(to: "+1", body: "Hi")) }
        assert_raises(Errors::Unknown) { invalid.deliver(Message.new(to: "+1", body: "Hi")) }
        assert_raises(Errors::Unknown) { broken.deliver(Message.new(to: "+1", body: "Hi")) }
      end

      private

      def build_provider(http, settings: default_settings)
        configuration = ProviderConfiguration.new(name: :infobip, settings: settings)
        Providers::Infobip.new(configuration: configuration, http: HTTP::Client.new(transport: http))
      end

      def default_settings
        { api_key: "secret", sender: "MyApp", base_url: "https://example.test" }
      end
    end
  end
end
