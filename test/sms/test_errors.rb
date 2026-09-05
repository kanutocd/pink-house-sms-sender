# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestErrors < Minitest::Test
      def test_retryable_categories_are_failover_eligible
        %i[network timeout rate_limited provider_unavailable].each do |category|
          error = Errors.const_get(category_class_name(category)).new(category: category, provider: :twilio)

          assert_predicate error, :retryable?
          assert_predicate error, :failover?
        end
      end

      def test_authentication_and_authorization_are_retryable_but_not_failover_eligible
        %i[authentication authorization].each do |category|
          error = Errors.const_get(category_class_name(category)).new(category: category)

          assert_predicate error, :retryable?
          refute_predicate error, :failover?
        end
      end

      def test_terminal_categories_are_not_retryable
        %i[invalid_request invalid_recipient provider_rejected unknown].each do |category|
          error = Errors.const_get(category_class_name(category)).new(category: category)

          refute_predicate error, :retryable?
          refute_predicate error, :failover?
        end
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

      def test_error_preserves_provider_and_defaults_category
        error = Errors::Timeout.new(provider: :twilio)
        anonymous_error = Class.new(Errors::Base).new

        assert_kind_of Error, error
        assert_equal :timeout, error.category
        assert_equal :twilio, error.provider
        assert_equal :unknown, anonymous_error.category
      end

      private

      def category_class_name(category)
        category.to_s.split("_").map(&:capitalize).join
      end
    end
  end
end
