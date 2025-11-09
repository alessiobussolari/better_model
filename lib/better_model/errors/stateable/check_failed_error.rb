# frozen_string_literal: true

require_relative "stateable_error"

module BetterModel
  module Errors
    module Stateable
      # Raised when a check condition fails.
      class CheckFailedError < StateableError
        def initialize(event, check_description = nil)
          msg = "Check failed for transition #{event.inspect}"
          msg += ": #{check_description}" if check_description
          super(msg)
        end
      end

      # Alias for backwards compatibility
      GuardFailedError = CheckFailedError
    end
  end
end
