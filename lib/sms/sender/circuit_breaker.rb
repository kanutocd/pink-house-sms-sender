# frozen_string_literal: true

module Sms
  module Sender
    # In-memory circuit breaker for one provider.
    class CircuitBreaker
      # Circuit states exposed for observability and routing.
      STATES = %i[closed open half_open].freeze
      # Conservative default consecutive-failure threshold.
      DEFAULT_FAILURE_THRESHOLD = 3
      # Default period for retaining failure observations, in seconds.
      DEFAULT_OBSERVATION_WINDOW = 60
      # Default period before an open circuit can be probed, in seconds.
      DEFAULT_OPEN_COOLDOWN = 30
      # Default number of concurrent half-open probes.
      DEFAULT_HALF_OPEN_PROBE_LIMIT = 1

      # @param failure_threshold [Integer] failures required to open
      # @param observation_window [Numeric] failure retention period
      # @param open_cooldown [Numeric] open period before probing
      # @param half_open_probe_limit [Integer] concurrent probe limit
      # @param clock [#call] monotonic clock returning seconds
      def initialize(failure_threshold: DEFAULT_FAILURE_THRESHOLD, observation_window: DEFAULT_OBSERVATION_WINDOW,
                     open_cooldown: DEFAULT_OPEN_COOLDOWN, half_open_probe_limit: DEFAULT_HALF_OPEN_PROBE_LIMIT,
                     clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @failure_threshold = positive_integer(failure_threshold, "failure_threshold")
        @observation_window = positive_number(observation_window, "observation_window")
        @open_cooldown = positive_number(open_cooldown, "open_cooldown")
        @half_open_probe_limit = positive_integer(half_open_probe_limit, "half_open_probe_limit")
        @clock = clock
        @state = :closed
        @failures = []
        @opened_at = nil
        @probes = 0
        @lock = Mutex.new
      end

      # @return [Symbol] current circuit state
      def state
        @lock.synchronize do
          transition_if_ready
          @state
        end
      end

      # Reserve permission for one request.
      # @return [Boolean] whether the request may proceed
      def allow?
        @lock.synchronize do
          transition_if_ready
          return true if @state == :closed
          return false if @state == :open
          return false if @probes >= @half_open_probe_limit

          @probes += 1
          true
        end
      end

      # Record a successful request and close the circuit.
      def record_success
        @lock.synchronize do
          @state = :closed
          @failures.clear
          @opened_at = nil
          @probes = 0
        end
      end

      # Record a retryable provider failure.
      # @param error [Errors::Base] normalized provider error
      def record_failure(error)
        return unless error.retryable?

        @lock.synchronize do
          if @state == :half_open
            open_circuit
          else
            prune_failures
            @failures << @clock.call
            open_circuit if @failures.length >= @failure_threshold
          end
        end
      end

      private

      def transition_if_ready
        return unless @state == :open && @clock.call - @opened_at >= @open_cooldown

        @state = :half_open
        @probes = 0
      end

      def open_circuit
        @state = :open
        @opened_at = @clock.call
        @probes = 0
      end

      def prune_failures
        cutoff = @clock.call - @observation_window
        @failures.reject! { |timestamp| timestamp < cutoff }
      end

      def positive_integer(value, name)
        return value if value.is_a?(Integer) && value.positive?

        raise ArgumentError, "#{name} must be a positive Integer"
      end

      def positive_number(value, name)
        return value if value.is_a?(Numeric) && value.positive?

        raise ArgumentError, "#{name} must be a positive number"
      end
    end
  end
end
