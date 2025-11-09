# frozen_string_literal: true

module BetterModel
  module Errors
    # Root error class for all BetterModel errors.
    # All module-specific errors inherit from this class.
    #
    # All errors include Sentry-compatible data structures:
    # - context: High-level structured metadata (model_class, etc.)
    # - tags: Filterable metadata for grouping/searching (error_category, module, etc.)
    # - extra: Detailed debug data with all error-specific parameters
    #
    # @example Accessing error data
    #   rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
    #     e.predicate_scope  # => :title_xxx
    #     e.tags             # => {error_category: 'invalid_predicate', module: 'searchable', ...}
    #     e.context          # => {model_class: 'Article'}
    #     e.extra            # => {predicate_scope: :title_xxx, value: 'Rails', ...}
    #   end
    #
    # @example Sentry integration
    #   Sentry.capture_exception(error) do |scope|
    #     scope.set_context("error_details", error.context)
    #     scope.set_tags(error.tags)
    #     scope.set_extras(error.extra)
    #   end
    class BetterModelError < StandardError
      attr_reader :context, :tags, :extra

      # Initialize a new BetterModelError.
      #
      # @param message [String, nil] Optional error message
      def initialize(message = nil)
        # Initialize sentry attributes only if not already set by subclass
        @context ||= {}
        @tags ||= {}
        @extra ||= {}
        super(message)
      end
    end
  end
end
