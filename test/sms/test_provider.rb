# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestProvider < Minitest::Test
      def setup
        @configuration = ProviderConfiguration.new(
          name: :semaphore,
          capabilities: [:sms]
        )
        @provider = Provider.new(configuration: @configuration)
      end

      def test_exposes_provider_contract_metadata
        assert_same @configuration, @provider.configuration
        assert_equal :semaphore, @provider.name
        assert_equal [:sms], @provider.capabilities
      end

      def test_requires_adapters_to_implement_delivery
        assert_raises(NotImplementedError) do
          @provider.deliver(Message.new(to: "+1", body: "hello"))
        end
      end

      def test_rejects_invalid_configuration
        assert_raises(ArgumentError) { Provider.new(configuration: {}) }
      end
    end
  end
end
