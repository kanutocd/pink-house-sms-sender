# frozen_string_literal: true

require_relative "sender/version"
require "sender/core"
require "json"

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
    # SMS facade over the shared delivery router.
    class Router < ::Sender::Core::Router
      # @param registry [ProviderRegistry, nil] SMS provider registry
      # @param circuit_options [Hash] circuit-breaker options
      # @param state_store [StateStore::Memory, nil] runtime state store
      # @param observer [Observability::Memory, nil] event observer
      def initialize(registry: nil, circuit_options: {}, state_store: nil, observer: nil)
        super(
          registry: registry || Sender.registry,
          circuit_options: circuit_options,
          state_store: state_store || StateStore::Memory.new,
          observer: observer || Observability::Memory.new
        )
      end
    end
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
        textbee: { path: "sms/sender/providers/text_bee", support_level: :supported },
        semaphore: { path: "sms/sender/providers/semaphore", support_level: :experimental },
        twilio: { path: "sms/sender/providers/twilio", support_level: :experimental },
        infobip: { path: "sms/sender/providers/infobip", support_level: :supported }
      }.freeze

      # @param catalog [Hash] SMS provider names mapped to adapter paths
      def initialize(catalog: DEFAULT_PROVIDERS)
        super(catalog: catalog, default_capabilities: [:sms])
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

      # @return [Hash] advisory metadata for a registered SMS provider
      def provider_metadata(name)
        registry.provider_metadata(name)
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

      # Configure selected providers and their preferred default from an env-like object.
      # @param env [#fetch, #[]] environment values
      # @return [ProviderRegistry] configured SMS registry
      def configure_from_env(env: ENV)
        names = env.fetch("SMS_SENDER_PROVIDERS").split(",").map(&:strip).reject(&:empty?)
        default = env.fetch("SMS_SENDER_DEFAULT_PROVIDER").strip
        raise ArgumentError, "default provider must be selected" unless names.include?(default)

        names.each_with_index do |name, index|
          priority = name == default ? names.length + 1 : names.length - index
          configure_provider(name, settings: environment_settings(env, name), priority: priority)
        end
        registry
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

      def environment_settings(env, name)
        raw = env["SMS_SENDER_#{name.upcase}_SETTINGS"]
        return {} if raw.nil? || raw.strip.empty?

        settings = JSON.parse(raw)
        raise ArgumentError, "provider settings must be a JSON object" unless settings.is_a?(Hash)

        settings.transform_keys(&:to_sym)
      rescue JSON::ParserError => e
        raise ArgumentError, "provider settings must contain valid JSON: #{e.message}"
      end

      def build_registry
        ProviderRegistry.new
      end
    end
  end
end

# The compatibility facade owns loading channel adapters; the shared runtime
# remains responsible for contracts, routing, and resilience.
