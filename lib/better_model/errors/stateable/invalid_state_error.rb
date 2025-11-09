# frozen_string_literal: true

require_relative "stateable_error"

module BetterModel
  module Errors
    module Stateable
      # Raised when an invalid state is referenced.
      class InvalidStateError < StateableError
        def initialize(state)
          super("Invalid state: #{state.inspect}")
        end
      end
    end
  end
end
