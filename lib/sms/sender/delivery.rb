# frozen_string_literal: true

module Sms
  module Sender
    # Immutable provider-neutral delivery result.
    class Delivery
      # Statuses exposed by the provider-neutral delivery result.
      STATUSES = %i[pending submitted accepted delivered failed unknown].freeze

      attr_reader :status, :provider, :provider_message_id, :attempts, :error, :metadata

      # @param status [Symbol] normalized delivery status
      # @param provider [Symbol, nil] provider that handled the delivery
      # @param provider_message_id [String, nil] provider-side identifier
      # @param attempts [Array<Hash>] delivery attempt records
      # @param error [Errors::Base, nil] normalized failure
      # @param metadata [Hash] provider-neutral metadata
      def initialize(status: :unknown, provider: nil, provider_message_id: nil, attempts: [], error: nil, metadata: {})
        @status = normalize_status(status)
        @provider = provider&.to_sym
        @provider_message_id = provider_message_id&.to_s&.freeze
        @attempts = normalize_attempts(attempts)
        @error = validate_error(error)
        @metadata = normalize_metadata(metadata)
        freeze
      end

      # @return [Boolean] whether the provider accepted the message
      def accepted?
        %i[submitted accepted].include?(status)
      end

      # @return [Boolean] whether the handset delivery was confirmed
      def delivered?
        status == :delivered
      end

      # @return [Boolean] whether delivery failed terminally
      def failed?
        status == :failed
      end

      # Apply a provider webhook event to this immutable delivery state.
      # @param event [DeliveryEvent] normalized provider status update
      # @return [Delivery] updated delivery state
      def with_event(event)
        raise ArgumentError, "event must be a Sms::Sender::DeliveryEvent" unless event.is_a?(DeliveryEvent)
        if provider && (event.provider != provider || event.provider_message_id != provider_message_id)
          raise ArgumentError, "delivery event does not match this delivery"
        end

        Delivery.new(
          status: event.status,
          provider: event.provider,
          provider_message_id: event.provider_message_id,
          attempts: attempts,
          error: event.error,
          metadata: metadata.merge(event.metadata)
        )
      end

      private

      def normalize_status(value)
        status = value.to_sym
        return status if STATUSES.include?(status)

        raise ArgumentError, "unknown delivery status: #{value.inspect}"
      rescue NoMethodError
        raise ArgumentError, "status must be symbolizable"
      end

      def normalize_attempts(value)
        raise ArgumentError, "attempts must be an Array" unless value.is_a?(Array)

        value.map do |attempt|
          raise ArgumentError, "each attempt must be a Hash" unless attempt.is_a?(Hash)

          attempt.dup.freeze
        end.freeze
      end

      def validate_error(value)
        return unless value
        return value if value.is_a?(Errors::Base)

        raise ArgumentError, "error must be a normalized sender error"
      end

      def normalize_metadata(value)
        raise ArgumentError, "metadata must be a Hash" unless value.is_a?(Hash)

        value.dup.freeze
      end
    end
  end
end
