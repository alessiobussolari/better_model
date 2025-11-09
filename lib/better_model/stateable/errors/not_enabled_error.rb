# frozen_string_literal: true

module BetterModel
  module Stateable
    # Raised when Stateable is not enabled but methods are called
    class NotEnabledError < StateableError
      def initialize(msg = nil)
        super(msg || "Stateable is not enabled. Add 'stateable do...end' to your model.")
      end
    end
  end
end
