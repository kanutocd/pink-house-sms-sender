# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestRouter < Minitest::Test
      FakeProvider = Struct.new(:configuration, :calls, :failure) do
        def name
          configuration.name
        end

        def deliver(message)
          calls << message
          raise failure if failure

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

      def test_fails_over_on_retryable_error_and_records_attempts
        first = fake_provider(:textbee, priority: 10, failure: Errors::Network.new(provider: :textbee))
        second = fake_provider(:semaphore, priority: 1)

        delivery = Router.new(registry: registry_with(first, second)).deliver(Message.new(to: "+1", body: "Hello"))

        assert_equal :semaphore, delivery.provider
        providers = delivery.attempts.map { |attempt| attempt[:provider] }
        statuses = delivery.attempts.map { |attempt| attempt[:status] }

        assert_equal %i[textbee semaphore], providers
        assert_equal %i[failed accepted], statuses
        assert_equal :network, delivery.attempts.first[:error]
      end

      def test_does_not_fail_over_terminal_errors
        first = fake_provider(:textbee, priority: 10, failure: Errors::InvalidRecipient.new(provider: :textbee))
        second = fake_provider(:semaphore, priority: 1)

        assert_raises(Errors::InvalidRecipient) do
          Router.new(registry: registry_with(first, second)).deliver(Message.new(to: "+1", body: "Hello"))
        end
        assert_empty second.calls
      end

      def test_stops_at_max_attempts_and_returns_failed_delivery
        first = fake_provider(:textbee, priority: 10, failure: Errors::Timeout.new(provider: :textbee))
        second = fake_provider(:semaphore, priority: 1, failure: Errors::ProviderUnavailable.new(provider: :semaphore))

        delivery = Router.new(registry: registry_with(first, second)).deliver(
          Message.new(to: "+1", body: "Hello"), max_attempts: 2
        )

        assert_equal :failed, delivery.status
        assert_equal :semaphore, delivery.provider
        assert_equal :provider_unavailable, delivery.error.category
        assert_equal 2, delivery.attempts.length
      end

      def test_rejects_invalid_max_attempts
        provider = fake_provider(:textbee)
        router = Router.new(registry: registry_with(provider))

        assert_raises(ArgumentError) { router.deliver(Message.new(to: "+1", body: "Hello"), max_attempts: 0) }
      end

      def test_excludes_open_provider_and_uses_recovery_probe
        first = fake_provider(:textbee, priority: 10, failure: Errors::Network.new(provider: :textbee))
        second = fake_provider(:semaphore, priority: 1)
        router = Router.new(
          registry: registry_with(first, second),
          circuit_options: { failure_threshold: 1, open_cooldown: 5 }
        )
        message = Message.new(to: "+1", body: "Hello")

        router.deliver(message)
        delivery = router.deliver(message)

        assert_equal :semaphore, delivery.provider
        assert_equal 1, first.calls.length
      end

      private

      def fake_provider(name, priority: 0, enabled: true, failure: nil)
        configuration = ProviderConfiguration.new(name: name, priority: priority, enabled: enabled)
        FakeProvider.new(configuration, [], failure)
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
