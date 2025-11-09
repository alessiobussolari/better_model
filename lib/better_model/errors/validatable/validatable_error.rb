# frozen_string_literal: true

require_relative "../better_model_error"

module BetterModel
  module Errors
    module Validatable
      # Base error class for all Validatable-related errors.
      class ValidatableError < BetterModelError
      end
    end
  end
end
