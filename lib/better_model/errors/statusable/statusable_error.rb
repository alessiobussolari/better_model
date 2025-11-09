# frozen_string_literal: true

require_relative "../better_model_error"

module BetterModel
  module Errors
    module Statusable
      # Base error class for all Statusable-related errors.
      class StatusableError < BetterModelError
      end
    end
  end
end
