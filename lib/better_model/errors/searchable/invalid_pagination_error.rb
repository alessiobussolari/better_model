# frozen_string_literal: true

require_relative "searchable_error"

module BetterModel
  module Errors
    module Searchable
      # Raised when invalid pagination parameters are provided.
      class InvalidPaginationError < SearchableError
      end
    end
  end
end
