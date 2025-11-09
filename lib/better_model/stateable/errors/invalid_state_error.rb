# frozen_string_literal: true

module BetterModel
  module Stateable
    # Raised when an invalid state is referenced
    class InvalidStateError < StateableError
      def initialize(state)
        super("Invalid state: #{state.inspect}")
      end
    end
  end
end
