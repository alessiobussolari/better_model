# frozen_string_literal: true

module BetterModel
  module Errors
    module Stateable
      # Configuration error for Stateable module.
      # Inherits from ArgumentError for backward compatibility with existing rescue clauses.
      class ConfigurationError < ArgumentError
      end
    end
  end
end
