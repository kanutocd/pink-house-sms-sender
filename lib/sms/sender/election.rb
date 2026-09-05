# frozen_string_literal: true

module Sms
  module Sender
    # Selects eligible providers using priority and lightweight health signals.
    class Election
      # @param state_store [StateStore::Memory] election state persistence
      def initialize(state_store: StateStore::Memory.new)
        @state_store = state_store
      end

      # Return providers in deterministic descending preference order.
      # @param providers [Array<Provider>] configured providers
      # @param requirements [Array<Symbol>] required message capabilities
      # @param circuits [Hash<Symbol, CircuitBreaker>] provider circuits
      # @param health [Hash<Symbol, Health>] provider health records
      # @return [Array<Provider>] eligible providers
      def rank(providers, requirements: [], circuits: {}, health: {})
        result = providers
                 .select { |provider| eligible?(provider, requirements, circuits) }
                 .sort_by { |provider| election_key(provider, snapshot_for(health[provider.name])) }
                 .reverse
        @state_store.write(:last_election, result.first&.name)
        result
      end

      # @return [Symbol, nil] most recently preferred provider
      def last_selection
        @state_store.read(:last_election)
      end

      private

      def eligible?(provider, requirements, circuits)
        provider.configuration.enabled? &&
          requirements.all? { |requirement| provider.capabilities.include?(requirement.to_sym) } &&
          (circuits[provider.name]&.allow? != false)
      end

      def election_key(provider, snapshot)
        priority = provider.configuration.priority
        success_rate = success_rate(snapshot)
        failure_penalty = snapshot ? snapshot[:recent_failures] + snapshot[:consecutive_failures] : 0
        [priority + success_rate - failure_penalty, priority, provider.name.to_s]
      end

      def success_rate(snapshot)
        return 0 unless snapshot

        successes = snapshot[:recent_successes]
        failures = snapshot[:recent_failures]
        total = successes + failures
        total.zero? ? 0 : successes.to_f / total
      end

      def snapshot_for(value)
        return unless value

        value.respond_to?(:snapshot) ? value.snapshot : value
      end
    end
  end
end
