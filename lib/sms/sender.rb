# frozen_string_literal: true

require_relative "sender/version"
require "sender/core"

# Top-level namespace for SMS-related libraries.
module Sms
  # Namespace for the sms-sender gem.
  module Sender
    # Shared normalized runtime error base.
    Error = ::Sender::Core::Error
    # Shared capability vocabulary.
    Capabilities = ::Sender::Core::Capabilities
    # Shared normalized message value.
    Message = ::Sender::Core::Message
    # Shared normalized delivery result.
    Delivery = ::Sender::Core::Delivery
    # Shared normalized delivery event.
    DeliveryEvent = ::Sender::Core::DeliveryEvent
    # Shared provider election policy.
    Election = ::Sender::Core::Election
    # Shared provider health tracking.
    Health = ::Sender::Core::Health
    # Shared provider adapter contract.
    Provider = ::Sender::Core::Provider
    # Shared provider configuration value.
    ProviderConfiguration = ::Sender::Core::ProviderConfiguration
    # Shared delivery router.
    Router = ::Sender::Core::Router
    # Shared provider circuit breaker.
    CircuitBreaker = ::Sender::Core::CircuitBreaker
    # Shared runtime state store namespace.
    StateStore = ::Sender::Core::StateStore
    # Shared observability namespace.
    Observability = ::Sender::Core::Observability
    # Shared HTTP transport namespace.
    HTTP = ::Sender::Core::HTTP
    # Shared normalized error namespace.
    Errors = ::Sender::Core::Errors

    # Namespace for SMS provider adapter implementations.
    module Providers
    end

    # SMS-specific registry facade backed by sender-core's registry.
    class ProviderRegistry < ::Sender::Core::ProviderRegistry
      # SMS provider adapter paths included in the gem.
      DEFAULT_PROVIDERS = {
        textbee: "sms/sender/providers/text_bee",
        semaphore: "sms/sender/providers/semaphore",
        twilio: "sms/sender/providers/twilio",
        infobip: "sms/sender/providers/infobip"
      }.freeze

      # @param catalog [Hash] SMS provider names mapped to adapter paths
      def initialize(catalog: DEFAULT_PROVIDERS)
        super
      end

      private

      def lazy_loader(path)
        lambda do
          require path
          constant_name = path.split("/").last.split("_").map(&:capitalize).join
          Providers.const_get(constant_name)
        end
      end
    end

    class << self
      # @return [ProviderRegistry] process-local provider registry
      def registry
        @registry ||= build_registry
      end

      # @return [Array<Symbol>] providers supported by the gem
      def providers
        registry.supported
      end

      # Configure one provider for delivery.
      # @return [ProviderConfiguration] stored provider configuration
      def configure_provider(name, settings: {}, enabled: true, priority: 0, capabilities: nil)
        registry.configure(
          name,
          settings: settings,
          enabled: enabled,
          priority: priority,
          capabilities: capabilities
        )
      end

      # Deliver an SMS through the configured router.
      # @param to [String] recipient address
      # @param message [String] SMS body
      # @param provider [Symbol, String, nil] optional provider override
      # @return [Delivery] provider-neutral delivery result
      def deliver(to:, message:, provider: nil, metadata: {}, requirements: [])
        normalized_message = ::Sender::Core::Message.new(
          to: to,
          body: message,
          metadata: metadata,
          requirements: requirements
        )
        Router.new(registry: registry).deliver(normalized_message, provider: provider)
      end

      private

      def build_registry
        ProviderRegistry.new
      end
    end
  end
end

# The compatibility facade owns loading channel adapters; the shared runtime
# remains responsible for contracts, routing, and resilience.
