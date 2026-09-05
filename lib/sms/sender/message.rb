# frozen_string_literal: true

module Sms
  module Sender
    # Immutable provider-neutral outbound SMS message.
    class Message
      # @return [String] normalized recipient address
      attr_reader :to

      # @return [String] message body
      attr_reader :body

      # @return [Hash] application metadata
      attr_reader :metadata

      # @return [Array<Symbol>] required provider capabilities
      attr_reader :requirements

      # @param to [String] recipient phone number or address
      # @param body [String] SMS body
      # @param metadata [Hash] optional application metadata
      # @param requirements [Array<Symbol>] required provider capabilities
      def initialize(to:, body:, metadata: {}, requirements: [])
        @to = normalize_recipient(to)
        @body = validate_body(body)
        @metadata = normalize_metadata(metadata)
        @requirements = normalize_requirements(requirements)
        freeze
      end

      private

      def normalize_recipient(value)
        raise ArgumentError, "to must be a String" unless value.is_a?(String)

        recipient = value.strip
        raise ArgumentError, "to must not be empty" if recipient.empty?

        recipient
      end

      def validate_body(value)
        raise ArgumentError, "body must be a String" unless value.is_a?(String)
        raise ArgumentError, "body must not be empty" if value.strip.empty?

        value.dup.freeze
      end

      def normalize_metadata(value)
        raise ArgumentError, "metadata must be a Hash" unless value.is_a?(Hash)

        value.dup.freeze
      end

      def normalize_requirements(value)
        raise ArgumentError, "requirements must be an Array" unless value.is_a?(Array)

        value.map(&:to_sym).uniq.freeze
      rescue NoMethodError
        raise ArgumentError, "requirements must contain symbolizable values"
      end
    end
  end
end
