# frozen_string_literal: true

require_relative "stateable_error"

module BetterModel
  module Errors
    module Stateable
      # Raised when Stateable is not enabled but methods are called.
      class NotEnabledError < StateableError
        def initialize(msg = nil)
          super(msg || "Stateable is not enabled. Add 'stateable do...end' to your model.")
        end
      end
    end
  end
end
