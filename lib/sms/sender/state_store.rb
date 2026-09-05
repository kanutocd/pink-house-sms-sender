# frozen_string_literal: true

module Sms
  module Sender
    # Namespace for replaceable runtime state persistence implementations.
    module StateStore
      # Thread-safe process-local state store.
      class Memory
        def initialize
          @values = {}
          @lock = Mutex.new
        end

        # @param key [Object] state key
        # @return [Object, nil] stored value
        def read(key)
          @lock.synchronize { @values[key] }
        end

        # Store a value and return it.
        # @param key [Object] state key
        # @param value [Object] state value
        # @return [Object] stored value
        def write(key, value)
          @lock.synchronize { @values[key] = value }
        end

        # Read a value or initialize it atomically.
        # @param key [Object] state key
        # @return [Object] existing or initialized value
        def fetch(key)
          @lock.synchronize { @values.fetch(key) { @values[key] = yield } }
        end

        # Remove a value.
        # @param key [Object] state key
        # @return [Object, nil] removed value
        def delete(key)
          @lock.synchronize { @values.delete(key) }
        end

        # Remove all state values.
        def clear
          @lock.synchronize { @values.clear }
        end
      end
    end
  end
end
