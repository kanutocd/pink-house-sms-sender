# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    class TestMessage < Minitest::Test
      def test_normalizes_and_freezes_a_message
        message = Message.new(
          to: "  +639171234567  ",
          body: "Your OTP is 123456",
          metadata: { request_id: "abc" },
          requirements: ["unicode", :unicode]
        )

        assert_equal "+639171234567", message.to
        assert_equal "Your OTP is 123456", message.body
        assert_equal({ request_id: "abc" }, message.metadata)
        assert_equal [:unicode], message.requirements
        assert_predicate message, :frozen?
      end

      def test_rejects_invalid_recipient_and_body
        assert_raises(ArgumentError) { Message.new(to: nil, body: "body") }
        assert_raises(ArgumentError) { Message.new(to: " ", body: "body") }
        assert_raises(ArgumentError) { Message.new(to: "+1", body: nil) }
        assert_raises(ArgumentError) { Message.new(to: "+1", body: " ") }
      end

      def test_rejects_invalid_optional_values
        assert_raises(ArgumentError) { Message.new(to: "+1", body: "body", metadata: []) }
        assert_raises(ArgumentError) { Message.new(to: "+1", body: "body", requirements: {}) }
        assert_raises(ArgumentError) { Message.new(to: "+1", body: "body", requirements: [nil]) }
      end
    end
  end
end
