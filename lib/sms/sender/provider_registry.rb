# frozen_string_literal: true

module Sms
  module Sender
    # Catalogs, configures, and lazily loads provider adapters.
    class ProviderRegistry
      # Internal metadata for a registered provider.
      Entry = Struct.new(:name, :loader, :capabilities, keyword_init: true) do
        def load
          adapter = loader.call
          raise Errors::ConfigurationError, "provider #{name} loader did not return a class" unless adapter.is_a?(Class)

          adapter
        end
      end

      # Provider adapter paths included in the initial release.
      DEFAULT_PROVIDERS = {
        textbee: "sms/sender/providers/textbee",
        semaphore: "sms/sender/providers/semaphore",
        twilio: "sms/sender/providers/twilio",
        infobip: "sms/sender/providers/infobip"
      }.freeze

      # @param catalog [Hash] provider names mapped to adapter paths
      def initialize(catalog: DEFAULT_PROVIDERS)
        @entries = {}
        @configurations = {}
        catalog.each do |name, path|
          register(name, loader: lazy_loader(path), capabilities: [:sms])
        end
      end

      # @return [Array<Symbol>] providers known to the registry
      def supported
        @entries.keys.freeze
      end

      # @return [Array<Symbol>] configured providers
      def configured
        @configurations.keys.freeze
      end

      # Register a provider without loading its adapter.
      # @param name [Symbol, String] provider name
      # @param loader [#call] callable returning the adapter class
      # @param capabilities [Array<Symbol>] advertised capabilities
      def register(name, loader:, capabilities: [:sms])
        provider_name = normalize_name(name)
        raise ArgumentError, "loader must respond to call" unless loader.respond_to?(:call)
        raise ArgumentError, "provider already registered: #{provider_name}" if @entries.key?(provider_name)

        @entries[provider_name] = Entry.new(
          name: provider_name,
          loader: loader,
          capabilities: normalize_capabilities(capabilities)
        ).freeze
        provider_name
      end

      # Configure a registered provider without loading its adapter.
      # @return [ProviderConfiguration] the stored configuration
      def configure(name, settings: {}, enabled: true, priority: 0, capabilities: nil)
        entry = fetch_entry(name)
        configuration = ProviderConfiguration.new(
          name: entry.name,
          settings: settings,
          enabled: enabled,
          priority: priority,
          capabilities: capabilities || entry.capabilities
        )
        @configurations[entry.name] = configuration
      end

      # Instantiate a configured provider, loading its adapter on demand.
      # @return [Provider] configured provider adapter
      def provider(name)
        entry = fetch_entry(name)
        configuration = @configurations.fetch(entry.name) do
          raise Errors::ConfigurationError, "provider is not configured: #{entry.name}"
        end
        entry.load.new(configuration: configuration)
      rescue LoadError => e
        raise Errors::ConfigurationError, "could not load provider #{entry.name}: #{e.message}"
      end

      # @return [Array<Provider>] instantiated configured providers
      def providers
        configured.map { |name| provider(name) }
      end

      private

      def fetch_entry(name)
        @entries.fetch(normalize_name(name)) do
          raise Errors::ConfigurationError, "unknown provider: #{name.inspect}"
        end
      end

      def lazy_loader(path)
        lambda do
          require path
          constant_name = path.split("/").last.split("_").map(&:capitalize).join
          Sms::Sender.const_get(:Providers).const_get(constant_name)
        end
      end

      def normalize_name(value)
        name = value.to_sym
        raise ArgumentError, "provider name must not be empty" if name.empty?

        name
      rescue NoMethodError
        raise ArgumentError, "provider name must be symbolizable"
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
