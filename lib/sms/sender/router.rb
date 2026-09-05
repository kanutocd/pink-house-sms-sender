# frozen_string_literal: true

module Sms
  module Sender
    # Selects one eligible configured provider for a delivery.
    class Router
      # @param registry [ProviderRegistry] provider registry to route through
      def initialize(registry: Sms::Sender.registry, circuit_options: {}, state_store: StateStore::Memory.new,
                     observer: Observability::Memory.new)
        @registry = registry
        @circuit_options = circuit_options
        @state_store = state_store
        @observer = observer
        @election = Election.new(state_store: @state_store)
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
        candidates = eligible_providers(provider, requirements: message.requirements)
        attempt_limit = validate_max_attempts(max_attempts || candidates.length)
        attempts = []
        last_error = nil

        candidates.first(attempt_limit).each do |candidate|
          started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          delivery = candidate.deliver(message)
          previous_state = circuit_for(candidate).state
          circuit_for(candidate).record_success
          if previous_state != circuit_for(candidate).state
            emit(type: :circuit_transition, provider: candidate.name, from: previous_state,
                 to: circuit_for(candidate).state)
          end
          health_for(candidate).record_success(
            latency: elapsed_since(started_at), circuit_state: circuit_for(candidate).state
          )
          emit(type: :attempt, provider: candidate.name, status: :accepted, latency: elapsed_since(started_at))
          return with_attempt(delivery, attempts, candidate.name, :accepted)
        rescue Errors::Base => e
          previous_state = circuit_for(candidate).state
          circuit_for(candidate).record_failure(e)
          if previous_state != circuit_for(candidate).state
            emit(type: :circuit_transition, provider: candidate.name, from: previous_state,
                 to: circuit_for(candidate).state)
          end
          health_for(candidate).record_failure(
            latency: elapsed_since(started_at), error: e, circuit_state: circuit_for(candidate).state
          )
          emit(type: :attempt, provider: candidate.name, status: :failed, error: e.category,
               latency: elapsed_since(started_at))
          attempts << attempt_record(candidate.name, :failed, e)
          last_error = e
          if e.failover? && attempts.length < attempt_limit
            emit(type: :failover, from: candidate.name, to: candidates[attempts.length]&.name)
          end
          raise unless e.failover?
        end

        Delivery.new(status: :failed, provider: last_error.provider, attempts: attempts, error: last_error)
      end

      # @param name [Symbol, String] configured provider name
      # @return [Hash] current provider health snapshot
      def health(name)
        health_for(@registry.provider(name)).snapshot
      end

      # @return [Array<Hash>] structured events emitted by this router
      def events
        @observer.events
      end

      private

      def eligible_providers(name = nil, requirements: [])
        candidates = name ? [@registry.provider(name)] : @registry.providers
        selected = @election.rank(
          candidates, requirements: requirements, circuits: circuit_map(candidates), health: health_map(candidates)
        )
        emit(type: :election, candidates: selected.map(&:name), selected: selected.first&.name)
        return selected unless selected.empty?

        raise Errors::ConfigurationError.new("no eligible provider is configured", category: :configuration)
      end

      def validate_max_attempts(value)
        return value if value.is_a?(Integer) && value.positive?

        raise ArgumentError, "max_attempts must be a positive Integer"
      end

      def circuit_map(providers)
        providers.to_h { |provider| [provider.name, circuit_for(provider)] }
      end

      def health_map(providers)
        providers.to_h { |provider| [provider.name, health_for(provider)] }
      end

      def circuit_for(provider)
        @state_store.fetch([:circuit, provider.name]) { CircuitBreaker.new(**@circuit_options) }
      end

      def health_for(provider)
        @state_store.fetch([:health, provider.name]) do
          Health.new(
            observation_window: @circuit_options.fetch(:observation_window, CircuitBreaker::DEFAULT_OBSERVATION_WINDOW)
          )
        end
      end

      def elapsed_since(started_at)
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      end

      def emit(event)
        @observer.emit(event)
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
