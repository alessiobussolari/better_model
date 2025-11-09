# frozen_string_literal: true

require_relative "searchable_error"

module BetterModel
  module Errors
    module Searchable
      # Raised when security validation fails for a search query.
      class InvalidSecurityError < SearchableError
      end
    end
  end
end
