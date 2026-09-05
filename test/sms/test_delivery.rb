# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestDelivery < Minitest::Test
      def test_exposes_provider_neutral_result_fields
        error = Errors::ProviderUnavailable.new("gateway unavailable", provider: :textbee)
        delivery = Delivery.new(
          status: "failed",
          provider: "textbee",
          provider_message_id: 123,
          attempts: [{ provider: :textbee, status: :failed }],
          error: error,
          metadata: { request_id: "abc" }
        )

        assert_equal :failed, delivery.status
        assert_equal :textbee, delivery.provider
        assert_equal "123", delivery.provider_message_id
        assert_equal [{ provider: :textbee, status: :failed }], delivery.attempts
        assert_same error, delivery.error
        assert_equal({ request_id: "abc" }, delivery.metadata)
        assert_predicate delivery, :failed?
        refute_predicate delivery, :accepted?
        refute_predicate delivery, :delivered?
      end

      def test_distinguishes_acceptance_from_delivery
        assert_predicate Delivery.new(status: :submitted), :accepted?
        assert_predicate Delivery.new(status: :accepted), :accepted?
        assert_predicate Delivery.new(status: :delivered), :delivered?
        refute_predicate Delivery.new(status: :pending), :failed?
      end

      def test_rejects_invalid_values
        assert_raises(ArgumentError) { Delivery.new(status: :unknown_status) }
        assert_raises(ArgumentError) { Delivery.new(status: nil) }
        assert_raises(ArgumentError) { Delivery.new(attempts: {}) }
        assert_raises(ArgumentError) { Delivery.new(attempts: [[]]) }
        assert_raises(ArgumentError) { Delivery.new(error: StandardError.new) }
        assert_raises(ArgumentError) { Delivery.new(metadata: []) }
      end
    end
  end
end
