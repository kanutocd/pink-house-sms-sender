# frozen_string_literal: true

require "test_helper"

module Sms
  class TestSender < Minitest::Test
    def test_that_it_has_a_version_number
      refute_nil Sender::VERSION
    end

    def test_that_it_exposes_a_public_error_class
      assert_operator Sender::Error, :<, StandardError
    end

    def test_that_shared_contracts_are_backed_by_sender_core
      assert_same ::Sender::Core::Message, Sender::Message
      assert_same ::Sender::Core::Delivery, Sender::Delivery
      assert_same ::Sender::Core::Provider, Sender::Provider
    end
  end
end
