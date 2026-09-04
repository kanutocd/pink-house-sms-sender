# frozen_string_literal: true

require_relative "sender/version"

# Top-level namespace for SMS-related libraries.
module Sms
  # Namespace for the sms-sender gem.
  module Sender
    # Base class for errors raised by sms-sender.
    class Error < StandardError; end
  end
end
