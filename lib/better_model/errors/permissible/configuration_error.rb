# frozen_string_literal: true

module BetterModel
  module Errors
    module Permissible
      # Configuration error for Permissible module.
      # Inherits from ArgumentError for backward compatibility with existing rescue clauses.
      class ConfigurationError < ArgumentError
      end
    end
  end
end
