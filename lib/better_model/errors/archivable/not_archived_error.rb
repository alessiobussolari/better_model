# frozen_string_literal: true

require_relative "archivable_error"

module BetterModel
  module Errors
    module Archivable
      # Raised when attempting to restore a record that is not archived.
      class NotArchivedError < ArchivableError
      end
    end
  end
end
