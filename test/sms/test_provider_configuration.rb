# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestProviderConfiguration < Minitest::Test
      def test_normalizes_provider_configuration
        configuration = ProviderConfiguration.new(
          name: "textbee",
          settings: { api_key: "secret" },
          enabled: false,
          priority: 10,
          capabilities: ["sms", :sms, :unicode]
        )

        assert_equal :textbee, configuration.name
        assert_equal "secret", configuration[:api_key]
        assert_equal "secret", configuration["api_key"]
        refute_predicate configuration, :enabled?
        assert_equal 10, configuration.priority
        assert_equal %i[sms unicode], configuration.capabilities
        assert_predicate configuration, :frozen?
      end

      def test_rejects_invalid_configuration_values
        assert_raises(ArgumentError) { ProviderConfiguration.new(name: nil) }
        assert_raises(ArgumentError) { ProviderConfiguration.new(name: "") }
        assert_raises(ArgumentError) { ProviderConfiguration.new(name: :textbee, settings: []) }
        assert_raises(ArgumentError) { ProviderConfiguration.new(name: :textbee, enabled: nil) }
        assert_raises(ArgumentError) { ProviderConfiguration.new(name: :textbee, priority: 1.5) }
        assert_raises(ArgumentError) { ProviderConfiguration.new(name: :textbee, capabilities: {}) }
        assert_raises(ArgumentError) { ProviderConfiguration.new(name: :textbee, capabilities: [nil]) }
      end
    end
  end
end
