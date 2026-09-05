# frozen_string_literal: true

module Sms
  module Sender
    # Immutable configuration shared by provider adapters.
    class ProviderConfiguration
      attr_reader :name, :settings, :enabled, :priority, :capabilities

      # @param name [Symbol, String] provider name
      # @param settings [Hash] provider-specific settings
      # @param enabled [Boolean] whether the provider may be used
      # @param priority [Integer] static provider preference
      # @param capabilities [Array<Symbol>] advertised capabilities
      def initialize(name:, settings: {}, enabled: true, priority: 0, capabilities: [])
        @name = normalize_name(name)
        @settings = normalize_settings(settings)
        @enabled = validate_enabled(enabled)
        @priority = validate_priority(priority)
        @capabilities = normalize_capabilities(capabilities)
        freeze
      end

      # @param key [Symbol, String] setting name
      # @return [Object, nil] configured setting
      def [](key)
        settings[key] || settings[key.to_sym]
      end

      # @return [Boolean] whether this configuration has been enabled
      def enabled?
        enabled
      end

      private

      def normalize_name(value)
        name = value.to_sym
        raise ArgumentError, "name must not be empty" if name.empty?

        name
      rescue NoMethodError
        raise ArgumentError, "name must be symbolizable"
      end

      def normalize_settings(value)
        raise ArgumentError, "settings must be a Hash" unless value.is_a?(Hash)

        value.dup.freeze
      end

      def validate_enabled(value)
        return value if [true, false].include?(value)

        raise ArgumentError, "enabled must be true or false"
      end

      def validate_priority(value)
        return value if value.is_a?(Integer)

        raise ArgumentError, "priority must be an Integer"
      end

      def normalize_capabilities(value)
        raise ArgumentError, "capabilities must be an Array" unless value.is_a?(Array)

        value.map(&:to_sym).uniq.freeze
      rescue NoMethodError
        raise ArgumentError, "capabilities must contain symbolizable values"
      end
    end
  end
end
