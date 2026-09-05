# frozen_string_literal: true

require "test_helper"

module Sms
  module Sender
    module StateStore
      class TestMemory < Minitest::Test
        def test_reads_writes_fetches_and_deletes_values
          store = Memory.new

          assert_nil store.read(:missing)
          assert_equal "value", store.write(:key, "value")
          assert_equal "value", store.read(:key)
          assert_equal "value", store.fetch(:key) { raise "not called" }
          created = Object.new

          assert_same created, store.fetch(:created) { created }
          assert_equal "value", store.delete(:key)
          assert_nil store.read(:key)
        end

        def test_clear_removes_all_values
          store = Memory.new
          store.write(:one, 1)
          store.write(:two, 2)

          assert_empty store.clear
          assert_nil store.read(:one)
          assert_nil store.read(:two)
        end
      end
    end
  end
end
