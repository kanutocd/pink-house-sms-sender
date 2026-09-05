# frozen_string_literal: true

module Sms
  module Sender
    # Thread-safe in-memory health history for one provider.
    class Health
      # @param observation_window [Numeric] period for retaining observations
      # @param clock [#call] monotonic clock returning seconds
      def initialize(observation_window: CircuitBreaker::DEFAULT_OBSERVATION_WINDOW,
                     clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        unless observation_window.is_a?(Numeric) && observation_window.positive?
          raise ArgumentError, "observation_window must be a positive number"
        end

        @observation_window = observation_window
        @clock = clock
        @successes = []
        @failures = []
        @consecutive_failures = 0
        @circuit_state = :closed
        @lock = Mutex.new
      end

      # Record a successful provider attempt.
      # @param latency [Numeric] elapsed request time in seconds
      # @param circuit_state [Symbol] circuit state after the attempt
      def record_success(latency:, circuit_state: :closed)
        @lock.synchronize do
          prune
          @successes << [@clock.call, validate_latency(latency)]
          @consecutive_failures = 0
          @circuit_state = circuit_state.to_sym
        end
      end

      # Record a failed provider attempt.
      # @param latency [Numeric] elapsed request time in seconds
      # @param error [Errors::Base] normalized error
      # @param circuit_state [Symbol] circuit state after the attempt
      def record_failure(latency:, error:, circuit_state: :closed)
        @lock.synchronize do
          prune
          @failures << [@clock.call, validate_latency(latency), error.category]
          @consecutive_failures += 1
          @circuit_state = circuit_state.to_sym
        end
      end

      # @return [Hash] immutable health snapshot
      def snapshot
        @lock.synchronize do
          prune
          latencies = (@successes + @failures).map { |event| event[1] }
          snapshot_values(latencies).freeze
        end
      end

      private

      def prune
        cutoff = @clock.call - @observation_window
        @successes.reject! { |event| event[0] < cutoff }
        @failures.reject! { |event| event[0] < cutoff }
        @consecutive_failures = 0 if @failures.empty?
      end

      def snapshot_values(latencies)
        {
          recent_successes: @successes.length,
          recent_failures: @failures.length,
          consecutive_failures: @consecutive_failures,
          average_latency: latencies.empty? ? nil : latencies.sum / latencies.length.to_f,
          circuit_state: @circuit_state
        }
      end

      def validate_latency(value)
        return value if value.is_a?(Numeric) && value >= 0

        raise ArgumentError, "latency must be a non-negative number"
      end
    end
  end
end
