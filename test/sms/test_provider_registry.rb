# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    module Providers
      class Provider < Sms::Sender::Provider
      end
    end

    class TestProviderRegistry < Minitest::Test
      class FakeProvider < Provider; end

      def test_exposes_default_catalog_without_loading_adapters
        registry = ProviderRegistry.new

        assert_equal %i[textbee semaphore twilio infobip], registry.supported
        assert_empty registry.configured
        assert_includes Sender.providers, :textbee
      end

      def test_registers_configures_and_lazily_instantiates_provider
        loaded = false
        registry = ProviderRegistry.new(catalog: {})
        loader = lambda do
          loaded = true
          FakeProvider
        end
        registry.register(:fake, loader: loader, capabilities: [:sms])

        refute loaded
        configuration = registry.configure("fake", settings: { token: "secret" })

        refute loaded
        provider = registry.provider(:fake)

        assert loaded
        assert_equal({ token: "secret" }, configuration.settings)
        assert_equal [:fake], registry.configured
        assert_instance_of FakeProvider, provider
      end

      def test_lazy_path_loader_resolves_provider_constant_when_loaded
        registry = ProviderRegistry.new(catalog: { fake: "sms/sender/provider" })
        registry.configure(:fake)

        assert_kind_of Provider, registry.provider(:fake)
      end

      def test_returns_all_configured_provider_instances
        registry = ProviderRegistry.new(catalog: {})
        registry.register(:first, loader: -> { FakeProvider })
        registry.register(:second, loader: -> { FakeProvider })
        registry.configure(:first)
        registry.configure(:second)

        assert_equal %i[first second], registry.providers.map(&:name)
      end

      def test_rejects_unknown_duplicate_and_invalid_registrations
        registry = ProviderRegistry.new(catalog: {})

        assert_raises(ArgumentError) { registry.register(:fake, loader: Object.new) }
        registry.register(:fake, loader: -> { FakeProvider })
        assert_raises(ArgumentError) { registry.register(:fake, loader: -> { FakeProvider }) }
        assert_raises(Errors::ConfigurationError) { registry.configure(:missing) }
        assert_raises(ArgumentError) { registry.register(nil, loader: -> { FakeProvider }) }
        assert_raises(ArgumentError) { registry.register("", loader: -> { FakeProvider }) }
        assert_raises(ArgumentError) { registry.register(:not_an_array, loader: -> { FakeProvider }, capabilities: {}) }
        assert_raises(ArgumentError) { registry.register(:bad, loader: -> { FakeProvider }, capabilities: [nil]) }
      end

      def test_requires_configuration_and_loads_textbee_adapter
        registry = ProviderRegistry.new
        assert_raises(Errors::ConfigurationError) { registry.provider(:textbee) }

        registry.configure(:textbee, settings: { api_key: "secret" })
        provider = registry.provider(:textbee)

        assert_instance_of Providers::TextBee, provider
      end

      def test_rejects_loader_that_does_not_return_a_class
        registry = ProviderRegistry.new(catalog: {})
        registry.register(:invalid, loader: -> { Object.new })
        registry.configure(:invalid)

        assert_raises(Errors::ConfigurationError) { registry.provider(:invalid) }
      end

      def test_wraps_missing_adapter_load_errors
        registry = ProviderRegistry.new(catalog: {})
        registry.register(:missing, loader: -> { raise LoadError, "missing dependency" })
        registry.configure(:missing)

        error = assert_raises(Errors::ConfigurationError) { registry.provider(:missing) }

        assert_match(/could not load provider missing/, error.message)
      end
    end
  end
end
