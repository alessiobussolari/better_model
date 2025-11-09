# frozen_string_literal: true

module BetterModel
  module Stateable
    # Raised when trying to transition to an invalid state from current state
    class InvalidTransitionError < StateableError
      def initialize(event, from_state, to_state)
        super("Cannot transition from #{from_state.inspect} to #{to_state.inspect} via #{event.inspect}")
      end
    end
  end
end
