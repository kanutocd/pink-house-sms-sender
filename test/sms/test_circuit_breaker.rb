# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestCircuitBreaker < Minitest::Test
      def setup
        @time = 0.0
        @breaker = CircuitBreaker.new(
          failure_threshold: 2,
          observation_window: 10,
          open_cooldown: 5,
          half_open_probe_limit: 1,
          clock: -> { @time }
        )
      end

      def test_opens_after_threshold_and_blocks_requests
        error = Errors::Network.new

        assert_predicate @breaker, :allow?
        @breaker.record_failure(error)

        assert_equal :closed, @breaker.state
        @breaker.record_failure(error)

        assert_equal :open, @breaker.state

        refute_predicate @breaker, :allow?
      end

      def test_observation_window_expires_old_failures
        error = Errors::Timeout.new

        @breaker.record_failure(error)
        @time = 11
        @breaker.record_failure(error)

        assert_equal :closed, @breaker.state
      end

      def test_cooldown_allows_one_probe
        error = Errors::ProviderUnavailable.new
        2.times { @breaker.record_failure(error) }
        @time = 5

        assert_equal :half_open, @breaker.state
        assert_predicate @breaker, :allow?

        refute_predicate @breaker, :allow?
      end

      def test_successful_probe_closes_circuit
        open_circuit
        @time = 5

        assert_predicate @breaker, :allow?

        @breaker.record_success

        assert_equal :closed, @breaker.state
        assert_predicate @breaker, :allow?
      end

      def test_failed_probe_reopens_circuit
        open_circuit
        @time = 5

        assert_predicate @breaker, :allow?
        @breaker.record_failure(Errors::Timeout.new)

        assert_equal :open, @breaker.state

        refute_predicate @breaker, :allow?
      end

      def test_terminal_failure_does_not_open_circuit
        @breaker.record_failure(Errors::InvalidRecipient.new)

        assert_equal :closed, @breaker.state
        assert_predicate @breaker, :allow?
      end

      def test_validates_configuration
        assert_raises(ArgumentError) { CircuitBreaker.new(failure_threshold: 0) }
        assert_raises(ArgumentError) { CircuitBreaker.new(observation_window: 0) }
        assert_raises(ArgumentError) { CircuitBreaker.new(open_cooldown: 0) }
        assert_raises(ArgumentError) { CircuitBreaker.new(half_open_probe_limit: 0) }
      end

      private

      def open_circuit
        error = Errors::Network.new
        2.times { @breaker.record_failure(error) }
      end
    end
  end
end
