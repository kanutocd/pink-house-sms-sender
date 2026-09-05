# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestHealth < Minitest::Test
      def setup
        @time = 0.0
        @health = Health.new(observation_window: 10, clock: -> { @time })
      end

      def test_tracks_successes_latency_and_circuit_state
        @health.record_success(latency: 0.2)
        @health.record_success(latency: 0.4, circuit_state: :half_open)

        snapshot = @health.snapshot

        assert_equal 2, snapshot[:recent_successes]
        assert_equal 0, snapshot[:recent_failures]
        assert_equal 0, snapshot[:consecutive_failures]
        assert_in_delta 0.3, snapshot[:average_latency]
        assert_equal :half_open, snapshot[:circuit_state]
        assert_predicate snapshot, :frozen?
      end

      def test_tracks_failures_and_resets_consecutive_count_on_success
        @health.record_failure(latency: 0.5, error: Errors::Timeout.new, circuit_state: :open)
        @health.record_failure(latency: 0.7, error: Errors::Network.new, circuit_state: :open)

        assert_equal 2, @health.snapshot[:consecutive_failures]
        @health.record_success(latency: 0.1)

        snapshot = @health.snapshot

        assert_equal 0, snapshot[:consecutive_failures]
        assert_equal 1, snapshot[:recent_successes]
        assert_equal :closed, snapshot[:circuit_state]
      end

      def test_expires_observations
        @health.record_success(latency: 0.2)
        @health.record_failure(latency: 0.4, error: Errors::Network.new)
        @time = 11

        snapshot = @health.snapshot

        assert_equal 0, snapshot[:consecutive_failures]
        assert_equal 0, snapshot[:recent_successes]
        assert_equal 0, snapshot[:recent_failures]
        assert_nil snapshot[:average_latency]
      end

      def test_rejects_invalid_configuration_and_latency
        assert_raises(ArgumentError) { Health.new(observation_window: 0) }
        assert_raises(ArgumentError) { @health.record_success(latency: -1) }
        assert_raises(ArgumentError) { @health.record_failure(latency: "slow", error: Errors::Network.new) }
      end
    end
  end
end
