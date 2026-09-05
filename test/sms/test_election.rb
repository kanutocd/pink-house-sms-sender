# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestElection < Minitest::Test
      Candidate = Struct.new(:configuration, :capabilities) do
        def name
          configuration.name
        end
      end

      Circuit = Struct.new(:permitted) do
        def allow?
          permitted
        end
      end

      def test_filters_disabled_incompatible_and_open_providers
        eligible = candidate(:semaphore, capabilities: %i[sms unicode])
        disabled = candidate(:textbee, enabled: false, capabilities: %i[sms unicode])
        incompatible = candidate(:twilio, capabilities: [:sms])
        open = candidate(:infobip, capabilities: %i[sms unicode])

        result = Election.new.rank(
          [eligible, disabled, incompatible, open],
          requirements: [:unicode],
          circuits: { infobip: Circuit.new(false) }
        )

        assert_equal [eligible], result
      end

      def test_scores_health_but_preserves_priority_as_primary_signal
        healthy_low = candidate(:semaphore, priority: 1)
        unhealthy_high = candidate(:twilio, priority: 5)
        health = {
          semaphore: { recent_successes: 10, recent_failures: 0, consecutive_failures: 0 },
          twilio: { recent_successes: 0, recent_failures: 2, consecutive_failures: 2 }
        }

        result = Election.new.rank([healthy_low, unhealthy_high], health: health)

        assert_equal :semaphore, result.first.name
      end

      def test_breaks_equal_scores_by_priority_then_name
        first = candidate(:textbee, priority: 1)
        second = candidate(:semaphore, priority: 1)

        assert_equal %i[textbee semaphore], Election.new.rank([second, first]).map(&:name)
        assert_equal [:textbee], Election.new.rank([first]).map(&:name)
      end

      def test_handles_health_with_no_observations
        provider = candidate(:textbee)
        health = { textbee: { recent_successes: 0, recent_failures: 0, consecutive_failures: 0 } }

        assert_equal [provider], Election.new.rank([provider], health: health)
      end

      private

      def candidate(name, enabled: true, priority: 0, capabilities: [:sms])
        configuration = ProviderConfiguration.new(name: name, enabled: enabled, priority: priority)
        Candidate.new(configuration, capabilities)
      end
    end
  end
end
