# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestRouter < Minitest::Test
      FakeProvider = Struct.new(:configuration, :calls) do
        def name
          configuration.name
        end

        def deliver(message)
          calls << message
          Delivery.new(status: :accepted, provider: name, provider_message_id: "id")
        end
      end

      def test_routes_to_the_only_enabled_provider
        provider = fake_provider(:textbee, priority: 1)
        router = Router.new(registry: registry_with(provider))

        delivery = router.deliver(Message.new(to: "+1", body: "Hello"))

        assert_equal :textbee, delivery.provider
        assert_equal 1, provider.calls.length
      end

      def test_selects_highest_priority_provider
        low = fake_provider(:textbee, priority: 1)
        high = fake_provider(:semaphore, priority: 10)
        router = Router.new(registry: registry_with(low, high))

        delivery = router.deliver(Message.new(to: "+1", body: "Hello"))

        assert_equal :semaphore, delivery.provider
        assert_empty low.calls
      end

      def test_ignores_disabled_provider
        disabled = fake_provider(:textbee, priority: 100, enabled: false)
        enabled = fake_provider(:semaphore, priority: 1)
        router = Router.new(registry: registry_with(disabled, enabled))

        assert_equal :semaphore, router.deliver(Message.new(to: "+1", body: "Hello")).provider
      end

      def test_breaks_priority_ties_deterministically
        semaphore = fake_provider(:semaphore, priority: 1)
        textbee = fake_provider(:textbee, priority: 1)
        router = Router.new(registry: registry_with(semaphore, textbee))

        assert_equal :textbee, router.deliver(Message.new(to: "+1", body: "Hello")).provider
      end

      def test_reports_no_eligible_provider_and_invalid_message
        disabled = fake_provider(:textbee, enabled: false)
        router = Router.new(registry: registry_with(disabled))

        assert_raises(Errors::ConfigurationError) { router.deliver(Message.new(to: "+1", body: "Hello")) }
        assert_raises(ArgumentError) { router.deliver(Object.new) }
      end

      def test_explicit_provider_must_be_enabled
        disabled = fake_provider(:textbee, enabled: false)
        router = Router.new(registry: registry_with(disabled))

        assert_raises(Errors::ConfigurationError) do
          router.deliver(Message.new(to: "+1", body: "Hello"), provider: :textbee)
        end
      end

      private

      def fake_provider(name, priority: 0, enabled: true)
        configuration = ProviderConfiguration.new(name: name, priority: priority, enabled: enabled)
        FakeProvider.new(configuration, [])
      end

      def registry_with(*providers)
        registry = ProviderRegistry.new(catalog: {})
        providers.each do |provider|
          registry.register(provider.name, loader: -> { provider.class })
          registry.configure(
            provider.name,
            priority: provider.configuration.priority,
            enabled: provider.configuration.enabled?
          )
        end
        registry.define_singleton_method(:provider) do |name|
          providers.find { |item| item.name == name.to_sym }
        end
        registry.define_singleton_method(:providers) { providers }
        registry
      end
    end
  end
end
