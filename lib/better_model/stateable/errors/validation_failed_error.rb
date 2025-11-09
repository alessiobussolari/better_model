# frozen_string_literal: true

module BetterModel
  module Stateable
    # Raised when a transition validation fails
    class ValidationFailedError < StateableError
      def initialize(event, errors)
        super("Validation failed for transition #{event.inspect}: #{errors.full_messages.join(', ')}")
      end
    end
  end
end
