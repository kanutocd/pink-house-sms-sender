# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestSenderApi < Minitest::Test
      class FacadeProvider < Provider
        def deliver(message)
          Delivery.new(status: :accepted, provider: name, metadata: { to: message.to, body: message.body })
        end
      end

      def test_requires_a_configured_provider
        with_fresh_registry do
          assert_raises(Errors::ConfigurationError) do
            Sender.deliver(to: "+1", message: "hello", provider: :not_configured)
          end
        end
      end

      def test_configures_and_delivers_a_normalized_message
        with_fresh_registry do
          assert_raises(Errors::ConfigurationError) do
            Sender.deliver(to: "+1", message: "hello")
          end

          registry = Sender.registry
          registry.register(:facade, loader: -> { FacadeProvider })
          configuration = Sender.configure_provider(:facade, settings: { token: "secret" })

          delivery = Sender.deliver(to: " +1 ", message: "hello", metadata: { id: 1 }, requirements: [:sms])

          assert_equal :facade, configuration.name
          assert_equal :accepted, delivery.status
          assert_equal({ to: "+1", body: "hello" }, delivery.metadata)
        end
      end

      def test_router_uses_the_sms_registry_by_default
        with_fresh_registry do
          Sender.registry.register(:facade, loader: -> { FacadeProvider })
          Sender.configure_provider(:facade)

          delivery = Router.new.deliver(Message.new(to: "+1", body: "hello"))

          assert_equal :accepted, delivery.status
          assert_equal :facade, delivery.provider
        end
      end

      private

      def with_fresh_registry
        previous = Sender.instance_variable_get(:@registry)
        Sender.instance_variable_set(:@registry, ProviderRegistry.new)
        yield
      ensure
        Sender.instance_variable_set(:@registry, previous)
      end
    end
  end
end
