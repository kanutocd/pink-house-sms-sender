# frozen_string_literal: true

module Sms
  module Sender
    # Provider-neutral delivery status update, suitable for webhook adapters.
    class DeliveryEvent
      attr_reader :provider, :provider_message_id, :status, :metadata, :error, :occurred_at

      # @param provider [Symbol, String] source provider
      # @param provider_message_id [String] provider-side message identifier
      # @param status [Symbol] normalized delivery status
      # @param metadata [Hash] provider event metadata
      # @param error [Errors::Base, nil] normalized delivery error
      # @param occurred_at [Time] provider event timestamp
      def initialize(provider:, provider_message_id:, status:, metadata: {}, error: nil, occurred_at: Time.now)
        @provider = provider.to_sym
        @provider_message_id = provider_message_id.to_s
        @status = normalize_status(status)
        @metadata = validate_metadata(metadata)
        @error = validate_error(error)
        @occurred_at = validate_time(occurred_at)
        freeze
      end

      private

      def normalize_status(value)
        return value.to_sym if Delivery::STATUSES.include?(value.to_sym)

        raise ArgumentError, "unknown delivery event status: #{value.inspect}"
      rescue NoMethodError
        raise ArgumentError, "status must be symbolizable"
      end

      def validate_metadata(value)
        raise ArgumentError, "metadata must be a Hash" unless value.is_a?(Hash)

        value.dup.freeze
      end

      def validate_error(value)
        return unless value
        return value if value.is_a?(Errors::Base)

        raise ArgumentError, "error must be a normalized sender error"
      end

      def validate_time(value)
        return value if value.is_a?(Time)

        raise ArgumentError, "occurred_at must be a Time"
      end
    end
  end
end
