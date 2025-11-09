# frozen_string_literal: true

require_relative "searchable_error"

module BetterModel
  module Errors
    module Searchable
      # Raised when an invalid order is used in a search query.
      class InvalidOrderError < SearchableError
      end
    end
  end
end
