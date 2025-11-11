# frozen_string_literal: true

require_relative "archivable_error"

module BetterModel
  module Errors
    module Archivable
      class AlreadyArchivedError < ArchivableError; end
    end
  end
end
