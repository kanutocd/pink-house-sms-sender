# frozen_string_literal: true

module Sms
  module Sender
    # Namespace for dependency-free runtime event sinks.
    module Observability
      # Thread-safe in-memory event sink with optional subscribers.
      class Memory
        def initialize
          @events = []
          @subscribers = []
          @lock = Mutex.new
        end

        # Record an event and notify subscribers.
        # @param event [Hash] structured sender event
        # @return [Hash] frozen event
        def emit(event)
          normalized = event.dup.freeze
          @lock.synchronize do
            @events << normalized
            @subscribers.each { |subscriber| subscriber.call(normalized) }
          end
          normalized
        end

        # Subscribe a callable to future events.
        # @param subscriber [#call] event subscriber
        def subscribe(subscriber = nil, &block)
          callback = subscriber || block
          raise ArgumentError, "subscriber must respond to call" unless callback.respond_to?(:call)

          @lock.synchronize { @subscribers << callback }
          callback
        end

        # @return [Array<Hash>] immutable event history
        def events
          @lock.synchronize { @events.dup.freeze }
        end

        # Clear recorded events.
        def clear
          @lock.synchronize { @events.clear }
        end
      end
    end
  end
end
