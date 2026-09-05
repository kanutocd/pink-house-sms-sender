# frozen_string_literal: true

require_relative "sender/version"

# Top-level namespace for SMS-related libraries.
module Sms
  # Namespace for the sms-sender gem.
  module Sender
    # Base class for errors raised by the sender runtime.
    class Error < StandardError; end
  end
end

require_relative "sender/errors"
require_relative "sender/message"
require_relative "sender/delivery"
require_relative "sender/provider_configuration"
require_relative "sender/provider"
