# frozen_string_literal: true

require_relative "validatable_error"

module BetterModel
  module Errors
    module Validatable
      # Raised when Validatable methods are called but the module is not enabled on the model.
      class NotEnabledError < ValidatableError
        def initialize(msg = nil)
          super(msg || "Validatable is not enabled. Add 'validatable do...end' to your model.")
        end
      end
    end
  end
end
