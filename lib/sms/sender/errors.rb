# frozen_string_literal: true

module Sms
  module Sender
    # Namespace for normalized delivery errors.
    module Errors
      # Base error raised by the sender runtime.
      class Base < Sender::Error
        # @return [Symbol] normalized error category
        attr_reader :category

        # @param message [String] safe error message
        # @param category [Symbol] normalized error category
        # @param provider [Symbol, nil] provider associated with the error
        def initialize(message = nil, category: :unknown, provider: nil)
          @category = category.to_sym
          @provider = provider&.to_sym
          super(message || category.to_s)
        end

        # @return [Symbol, nil] associated provider
        attr_reader :provider

        # @return [Boolean] whether this error can be retried
        def retryable?
          false
        end

        # @return [Boolean] whether this error permits provider failover
        def failover?
          retryable?
        end
      end

      # Base class for errors originating from a provider or its transport.
      class ProviderError < Base
        def retryable?
          true
        end
      end

      # A network-level failure occurred before a response was received.
      class Network < ProviderError; end

      # The provider request exceeded its timeout.
      class Timeout < ProviderError; end

      # The provider rate-limited the request.
      class RateLimited < ProviderError; end

      # Provider authentication failed.
      class Authentication < ProviderError; end

      # Provider authorization failed.
      class Authorization < ProviderError; end

      # The outbound request was invalid.
      class InvalidRequest < Base; end

      # The recipient address was invalid.
      class InvalidRecipient < Base; end

      # The provider is unavailable and the request may be retried elsewhere.
      class ProviderUnavailable < ProviderError; end

      # The provider rejected the message for a request-specific reason.
      class ProviderRejected < Base; end

      # An error that could not be mapped to a more specific category.
      class Unknown < Base; end

      # A provider or provider configuration cannot be loaded or validated.
      class ConfigurationError < Base; end
    end
  end
end
