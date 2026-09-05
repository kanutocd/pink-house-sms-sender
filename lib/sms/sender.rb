# frozen_string_literal: true

require_relative "sender/version"

# Top-level namespace for SMS-related libraries.
module Sms
  # Namespace for the sms-sender gem.
  module Sender
    # Base class for errors raised by the sender runtime.
    class Error < StandardError; end

    class << self
      # @return [ProviderRegistry] process-local provider registry
      def registry
        @registry ||= ProviderRegistry.new
      end

      # @return [Array<Symbol>] providers supported by the gem
      def providers
        registry.supported
      end

      # Configure one provider for direct delivery.
      # @return [ProviderConfiguration] stored provider configuration
      def configure_provider(name, settings: {}, enabled: true, priority: 0, capabilities: nil)
        registry.configure(
          name,
          settings: settings,
          enabled: enabled,
          priority: priority,
          capabilities: capabilities
        )
      end

      # Deliver through a configured provider.
      #
      # This direct provider path is intentionally small. Automatic election
      # and failover are introduced by the routing phases.
      # @param to [String] recipient address
      # @param message [String] SMS body
      # @param provider [Symbol, String, nil] configured provider override
      # @return [Delivery] provider-neutral delivery result
      def deliver(to:, message:, provider: nil, metadata: {}, requirements: [])
        provider_name = provider || registry.configured.first
        raise Errors::ConfigurationError, "no provider is configured" unless provider_name

        normalized_message = Message.new(
          to: to,
          body: message,
          metadata: metadata,
          requirements: requirements
        )
        registry.provider(provider_name).deliver(normalized_message)
      end
    end
  end
end

require_relative "sender/errors"
require_relative "sender/message"
require_relative "sender/delivery"
require_relative "sender/provider_configuration"
require_relative "sender/provider"
require_relative "sender/provider_registry"
require_relative "sender/http"
require_relative "sender/router"
require_relative "sender/circuit_breaker"
require_relative "sender/health"
require_relative "sender/election"
