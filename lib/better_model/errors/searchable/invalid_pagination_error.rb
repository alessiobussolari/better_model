# frozen_string_literal: true

require_relative "searchable_error"

module BetterModel
  module Errors
    module Searchable
      class InvalidPaginationError < SearchableError; end
    end
  end
end
