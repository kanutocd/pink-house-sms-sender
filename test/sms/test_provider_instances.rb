# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestProviderInstances < Minitest::Test
      def test_configures_multiple_instances_of_one_provider_from_environment
        with_fresh_registry do
          Sender.configure_from_env(env: textbee_instance_environment)

          assert_equal %i[textbee_primary textbee_backup], Sender.registry.configured
          assert_equal :textbee, Sender.registry.provider_metadata(:textbee_backup).fetch(:adapter)
          assert_equal "backup", Sender.registry.provider(:textbee_backup).configuration[:device_id]
        end
      end

      def test_rejects_unknown_provider_instance_prefix
        with_fresh_registry do
          assert_raises(ArgumentError) do
            Sender.configure_from_env(
              env: {
                "SMS_SENDER_PROVIDERS" => "unknown_primary",
                "SMS_SENDER_DEFAULT_PROVIDER" => "unknown_primary"
              }
            )
          end
        end
      end

      private

      def textbee_instance_environment
        {
          "SMS_SENDER_PROVIDERS" => "textbee_primary,textbee_backup",
          "SMS_SENDER_DEFAULT_PROVIDER" => "textbee_primary",
          "SMS_SENDER_TEXTBEE_PRIMARY_SETTINGS" => '{"device_id":"primary"}',
          "SMS_SENDER_TEXTBEE_BACKUP_SETTINGS" => '{"device_id":"backup"}'
        }
      end

      def with_fresh_registry
        previous = Sender.instance_variable_get(:@registry)
        Sender.instance_variable_set(:@registry, ProviderRegistry.new)
        yield
      ensure
        Sender.instance_variable_set(:@registry, previous)
      end
    end
  end
end
