# frozen_string_literal: true

require_relative "archivable_error"

module BetterModel
  module Errors
    module Archivable
      # Raised when Archivable methods are called but the module is not enabled on the model.
      class NotEnabledError < ArchivableError
        def initialize(msg = nil)
          super(msg || "Archivable is not enabled. Add 'archivable do...end' to your model.")
        end
      end
    end
  end
end
