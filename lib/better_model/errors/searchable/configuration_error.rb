# frozen_string_literal: true

module BetterModel
  module Errors
    module Searchable
      # Configuration error for Searchable module.
      # Inherits from ArgumentError for backward compatibility with existing rescue clauses.
      class ConfigurationError < ArgumentError
      end
    end
  end
end
