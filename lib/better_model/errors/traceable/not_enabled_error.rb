# frozen_string_literal: true

require_relative "traceable_error"

module BetterModel
  module Errors
    module Traceable
      # Raised when Traceable methods are called but the module is not enabled on the model.
      class NotEnabledError < TraceableError
        def initialize(msg = nil)
          super(msg || "Traceable is not enabled. Add 'traceable do...end' to your model.")
        end
      end
    end
  end
end
