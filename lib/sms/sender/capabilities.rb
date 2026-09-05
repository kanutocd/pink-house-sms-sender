# frozen_string_literal: true

module Sms
  module Sender
    # Shared capability vocabulary and normalization rules.
    module Capabilities
      # Initial capability names understood by routing policies.
      KNOWN = %i[sms unicode sender_id alphanumeric_sender delivery_receipts].freeze

      # Normalize capability values without preventing provider extensions.
      # @param values [Array<Symbol, String>] capability names
      # @return [Array<Symbol>] unique normalized names
      def self.normalize(values)
        raise ArgumentError, "capabilities must be an Array" unless values.is_a?(Array)

        values.map(&:to_sym).uniq.freeze
      rescue NoMethodError
        raise ArgumentError, "capabilities must contain symbolizable values"
      end
    end
  end
end
