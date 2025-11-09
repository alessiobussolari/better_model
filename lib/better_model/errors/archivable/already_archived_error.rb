# frozen_string_literal: true

require_relative "archivable_error"

module BetterModel
  module Errors
    module Archivable
      # Raised when attempting to archive a record that is already archived.
      class AlreadyArchivedError < ArchivableError
      end
    end
  end
end
