# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    module Observability
      class TestMemory < Minitest::Test
        def test_records_events_and_notifies_subscribers
          observer = Memory.new
          received = []
          observer.subscribe(->(event) { received << event })

          event = observer.emit(type: :attempt, provider: :twilio)

          assert_equal [event], observer.events
          assert_equal [event], received
          assert_predicate event, :frozen?
          assert_predicate observer.events, :frozen?
        end

        def test_supports_block_subscriber_and_clear
          observer = Memory.new
          received = []
          observer.subscribe { |event| received << event[:type] }
          observer.emit(type: :election)

          assert_equal [:election], received
          assert_empty observer.clear
          assert_empty observer.events
        end

        def test_rejects_invalid_subscriber
          assert_raises(ArgumentError) { Memory.new.subscribe(Object.new) }
        end
      end
    end
  end
end
