# frozen_string_literal: true

module Sms
  module Sender
    # Selects eligible providers using priority and lightweight health signals.
    class Election
      # Return providers in deterministic descending preference order.
      # @param providers [Array<Provider>] configured providers
      # @param requirements [Array<Symbol>] required message capabilities
      # @param circuits [Hash<Symbol, CircuitBreaker>] provider circuits
      # @param health [Hash<Symbol, Health>] provider health records
      # @return [Array<Provider>] eligible providers
      def rank(providers, requirements: [], circuits: {}, health: {})
        providers.select { |provider| eligible?(provider, requirements, circuits) }
                 .sort_by { |provider| election_key(provider, snapshot_for(health[provider.name])) }
                 .reverse
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
