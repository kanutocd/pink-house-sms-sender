# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestErrors < Minitest::Test
      def test_provider_errors_are_retryable_and_failover_eligible
        error = Errors::Timeout.new(provider: :twilio)

        assert_kind_of Error, error
        assert_equal :unknown, error.category
        assert_equal :twilio, error.provider
        assert_predicate error, :retryable?
        assert_predicate error, :failover?
      end

      def test_terminal_errors_are_not_retryable
        error = Errors::InvalidRecipient.new("bad number", category: :invalid_recipient)

        assert_equal :invalid_recipient, error.category
        refute_predicate error, :retryable?
        refute_predicate error, :failover?
      end

      def test_all_normalized_error_categories_are_available
        classes = %i[
          Network Timeout RateLimited Authentication Authorization InvalidRequest
          InvalidRecipient ProviderUnavailable ProviderRejected Unknown
        ]

        classes.each do |name|
          error = Errors.const_get(name).new

          assert_kind_of Error, error
        end
      end
    end
  end
end
