# frozen_string_literal: true

require_relative "stateable_error"

module BetterModel
  module Errors
    module Stateable
      # Raised when a transition validation fails.
      class ValidationFailedError < StateableError
        def initialize(event, errors)
          super("Validation failed for transition #{event.inspect}: #{errors.full_messages.join(', ')}")
        end
      end
    end
  end
end
