# frozen_string_literal: true

require_relative "../better_model_error"

module BetterModel
  module Errors
    module Traceable
      # Base error class for all Traceable-related errors.
      class TraceableError < BetterModelError
      end
    end
  end
end
