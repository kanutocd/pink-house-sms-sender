# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestDeliveryEvent < Minitest::Test
      def test_normalizes_event_and_updates_delivery
        event = DeliveryEvent.new(
          provider: "twilio", provider_message_id: 123, status: :delivered,
          metadata: { "source" => "webhook" }, occurred_at: Time.utc(2026, 1, 1)
        )
        delivery = Delivery.new(status: :accepted, provider: :twilio, provider_message_id: "123",
                                metadata: { request_id: "req-1" })

        updated = delivery.with_event(event)

        assert_equal :delivered, updated.status
        assert_predicate updated, :delivered?
        assert_equal({ request_id: "req-1", "source" => "webhook" }, updated.metadata)
        assert_equal :delivered, event.status
        assert_predicate event, :frozen?
      end

      def test_supports_failed_event_and_rejects_mismatches
        error = Errors::ProviderRejected.new(provider: :textbee)
        event = DeliveryEvent.new(provider: :textbee, provider_message_id: "id", status: :failed, error: error)
        delivery = Delivery.new(status: :accepted, provider: :textbee, provider_message_id: "id")

        assert_equal error, delivery.with_event(event).error
        assert_raises(ArgumentError) do
          delivery.with_event(DeliveryEvent.new(provider: :twilio, provider_message_id: "id", status: :delivered))
        end
      end

      def test_applies_event_to_delivery_without_existing_provider
        event = DeliveryEvent.new(provider: :twilio, provider_message_id: "id", status: :accepted)

        updated = Delivery.new.with_event(event)

        assert_equal :twilio, updated.provider
        assert_equal "id", updated.provider_message_id
        assert_predicate updated, :accepted?
      end

      def test_validates_event_values
        assert_raises(ArgumentError) do
          DeliveryEvent.new(provider: :twilio, provider_message_id: "id", status: :bogus)
        end
        assert_raises(ArgumentError) do
          DeliveryEvent.new(provider: :twilio, provider_message_id: "id", status: :delivered, metadata: [])
        end
        assert_raises(ArgumentError) do
          DeliveryEvent.new(provider: :twilio, provider_message_id: "id", status: :delivered, occurred_at: "now")
        end
        assert_raises(ArgumentError) do
          DeliveryEvent.new(provider: :twilio, provider_message_id: "id", status: :delivered, error: StandardError.new)
        end
      end
    end
  end
end
