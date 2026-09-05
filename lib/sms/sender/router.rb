# frozen_string_literal: true

module Sms
  module Sender
    # Selects one eligible configured provider for a delivery.
    class Router
      # @param registry [ProviderRegistry] provider registry to route through
      def initialize(registry: Sms::Sender.registry, circuit_options: {})
        @registry = registry
        @circuit_options = circuit_options
        @circuits = {}
      end

      # Deliver a normalized message through the best eligible provider.
      #
      # Providers are ordered by descending priority, then by name for stable
      # tie-breaking. Failover is bounded by the eligible provider count.
      # @param message [Message] normalized outbound message
      # @param provider [Symbol, String, nil] optional explicit provider
      # @param max_attempts [Integer, nil] optional upper bound on attempts
      # @return [Delivery] provider-neutral delivery result
      def deliver(message, provider: nil, max_attempts: nil)
        validate_message(message)
        candidates = eligible_providers(provider)
        attempt_limit = validate_max_attempts(max_attempts || candidates.length)
        attempts = []
        last_error = nil

        candidates.first(attempt_limit).each do |candidate|
          delivery = candidate.deliver(message)
          circuit_for(candidate).record_success
          return with_attempt(delivery, attempts, candidate.name, :accepted)
        rescue Errors::Base => e
          circuit_for(candidate).record_failure(e)
          attempts << attempt_record(candidate.name, :failed, e)
          last_error = e
          raise unless e.failover?
        end

        Delivery.new(status: :failed, provider: last_error.provider, attempts: attempts, error: last_error)
      end

      private

      def eligible_providers(name = nil)
        candidates = name ? [@registry.provider(name)] : @registry.providers
        selected = candidates.select { |item| item.configuration.enabled? && circuit_for(item).allow? }
                             .sort { |left, right| provider_order(right) <=> provider_order(left) }
        return selected unless selected.empty?

        raise Errors::ConfigurationError.new("no eligible provider is configured", category: :configuration)
      end

      def validate_max_attempts(value)
        return value if value.is_a?(Integer) && value.positive?

        raise ArgumentError, "max_attempts must be a positive Integer"
      end

      def provider_order(provider)
        [provider.configuration.priority, provider.name.to_s]
      end

      def circuit_for(provider)
        @circuits[provider.name] ||= CircuitBreaker.new(**@circuit_options)
      end

      def attempt_record(provider, status, error = nil)
        { provider: provider, status: status, error: error&.category }.compact
      end

      def with_attempt(delivery, attempts, provider, status)
        Delivery.new(
          status: delivery.status,
          provider: delivery.provider,
          provider_message_id: delivery.provider_message_id,
          attempts: attempts + [attempt_record(provider, status)],
          error: delivery.error,
          metadata: delivery.metadata
        )
      end

      def validate_message(message)
        return if message.is_a?(Message)

        raise ArgumentError, "message must be a Sms::Sender::Message"
      end
    end
  end
end
