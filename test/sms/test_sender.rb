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
  end
end
