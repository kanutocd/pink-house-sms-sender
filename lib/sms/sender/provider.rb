# frozen_string_literal: true

module Sms
  module Sender
    # Base contract implemented by provider adapters.
    class Provider
      # @return [ProviderConfiguration] provider configuration
      attr_reader :configuration

      # @param configuration [ProviderConfiguration] provider configuration
      def initialize(configuration:)
        unless configuration.is_a?(ProviderConfiguration)
          raise ArgumentError, "configuration must be a ProviderConfiguration"
        end

        @configuration = configuration
      end

      # @return [Symbol] provider name
      def name
        configuration.name
      end

      # @return [Array<Symbol>] provider capabilities
      def capabilities
        configuration.capabilities
      end

      # Deliver a normalized message through the provider.
      #
      # @raise [NotImplementedError] when called on the base contract
      def deliver(_message)
        raise NotImplementedError, "provider adapters must implement #deliver"
      end
    end
  end
end
