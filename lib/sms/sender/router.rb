# frozen_string_literal: true

module Sms
  module Sender
    # Selects one eligible configured provider for a delivery.
    class Router
      # @param registry [ProviderRegistry] provider registry to route through
      def initialize(registry: Sms::Sender.registry)
        @registry = registry
      end

      # Deliver a normalized message through the best eligible provider.
      #
      # Providers are ordered by descending priority, then by name for stable
      # tie-breaking. Automatic failover is intentionally deferred.
      # @param message [Message] normalized outbound message
      # @param provider [Symbol, String, nil] optional explicit provider
      # @return [Delivery] provider-neutral delivery result
      def deliver(message, provider: nil)
        validate_message(message)
        selected_provider(provider).deliver(message)
      end

      private

      def selected_provider(name)
        candidates = name ? [@registry.provider(name)] : eligible_providers
        selected = candidates.select { |item| item.configuration.enabled? }
                             .max_by { |item| [item.configuration.priority, item.name.to_s] }
        return selected if selected

        raise Errors::ConfigurationError.new("no eligible provider is configured", category: :configuration)
      end

      def eligible_providers
        @registry.providers
      end

      def validate_message(message)
        return if message.is_a?(Message)

        raise ArgumentError, "message must be a Sms::Sender::Message"
      end
    end
  end
end
