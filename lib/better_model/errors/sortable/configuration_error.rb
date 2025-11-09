# frozen_string_literal: true

module BetterModel
  module Errors
    module Sortable
      # Configuration error for Sortable module.
      # Inherits from ArgumentError for backward compatibility with existing rescue clauses.
      class ConfigurationError < ArgumentError
      end
    end
  end
end
