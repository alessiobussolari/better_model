# frozen_string_literal: true

module BetterModel
  module Stateable
    # Base error for all Stateable errors
    class StateableError < StandardError; end

    # Raised when Stateable is not enabled but methods are called
    class NotEnabledError < StateableError
      def initialize(msg = nil)
        super(msg || "Stateable is not enabled. Add 'stateable do...end' to your model.")
      end
    end

    # Raised when an invalid state is referenced
    class InvalidStateError < StateableError
      def initialize(state)
        super("Invalid state: #{state.inspect}")
      end
    end

    # Raised when trying to transition to an invalid state from current state
    class InvalidTransitionError < StateableError
      def initialize(event, from_state, to_state)
        super("Cannot transition from #{from_state.inspect} to #{to_state.inspect} via #{event.inspect}")
      end
    end

    # Raised when a guard condition fails
    class GuardFailedError < StateableError
      def initialize(event, guard_description = nil)
        msg = "Guard failed for transition #{event.inspect}"
        msg += ": #{guard_description}" if guard_description
        super(msg)
      end
    end

    # Raised when a transition validation fails
    class ValidationFailedError < StateableError
      def initialize(event, errors)
        super("Validation failed for transition #{event.inspect}: #{errors.full_messages.join(', ')}")
      end
    end
  end
end
