# frozen_string_literal: true

require_relative "searchable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Searchable
      # Raised when invalid pagination parameters are provided.
      #
      # @example
      #   raise InvalidPaginationError.new(
      #     parameter_name: "page",
      #     value: -1,
      #     valid_range: {min: 1, max: 1000},
      #     reason: "page must be >= 1"
      #   )
      class InvalidPaginationError < SearchableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :parameter_name, :value, :valid_range, :reason

        # Initialize a new InvalidPaginationError.
        #
        # @param parameter_name [String] Name of the invalid pagination parameter (e.g., "page", "per_page")
        # @param value [Object, nil] The invalid value that was provided (optional)
        # @param valid_range [Hash, nil] Hash with :min and :max keys defining valid range (optional)
        # @param reason [String, nil] Custom error reason (optional)
        def initialize(parameter_name:, value: nil, valid_range: nil, reason: nil)
          @parameter_name = parameter_name
          @value = value
          @valid_range = valid_range
          @reason = reason

          @tags = build_tags(
            error_category: "pagination",
            parameter: parameter_name
          )

          @context = {}

          @extra = build_extra(
            parameter_name: parameter_name,
            value: value,
            valid_range: valid_range,
            reason: reason
          )

          super(build_message)
        end

        private

        def build_message
          return reason if reason

          msg = "Invalid pagination parameter '#{parameter_name}'"
          msg += ": #{value}" if value
          if valid_range
            msg += " (valid range: #{valid_range[:min]}..#{valid_range[:max]})"
          end
          msg
        end
      end
    end
  end
end
