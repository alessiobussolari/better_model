# frozen_string_literal: true

require_relative "../better_model_error"

module BetterModel
  module Errors
    module Stateable
      # Base error class for all Stateable-related errors.
      class StateableError < BetterModelError
      end
    end
  end
end
