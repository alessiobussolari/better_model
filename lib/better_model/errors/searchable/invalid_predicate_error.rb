# frozen_string_literal: true

require_relative "searchable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Searchable
      # Raised when an invalid predicate is used in a search query.
      #
      # @example
      #   raise InvalidPredicateError.new(
      #     predicate_scope: :title_xxx,
      #     value: "Rails",
      #     available_predicates: [:title_eq, :title_cont, :title_start],
      #     model_class: Article
      #   )
      #
      # @example Accessing error data
      #   rescue InvalidPredicateError => e
      #     e.predicate_scope         # => :title_xxx
      #     e.value                   # => "Rails"
      #     e.available_predicates    # => [:title_eq, :title_cont, :title_start]
      #     e.model_class             # => Article
      #
      #     # Sentry-compatible data
      #     e.tags    # => {error_category: 'invalid_predicate', module: 'searchable', predicate: 'title_xxx'}
      #     e.context # => {model_class: 'Article'}
      #     e.extra   # => {predicate_scope: :title_xxx, value: 'Rails', available_predicates: [...]}
      class InvalidPredicateError < SearchableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :predicate_scope, :value, :available_predicates, :model_class

        # @param predicate_scope [Symbol, String] The invalid predicate that was attempted
        # @param value [Object] The value passed to the predicate
        # @param available_predicates [Array<Symbol>] List of valid predicates
        # @param model_class [Class, nil] The model class where error occurred
        def initialize(predicate_scope:, value: nil, available_predicates: [], model_class: nil)
          @predicate_scope = predicate_scope
          @value = value
          @available_predicates = available_predicates
          @model_class = model_class

          @tags = build_tags(
            error_category: "invalid_predicate",
            predicate: predicate_scope
          )

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            predicate_scope: predicate_scope,
            value: value,
            available_predicates: available_predicates
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Invalid predicate scope: #{predicate_scope.inspect}."
          if available_predicates.any?
            msg += " Available predicable scopes: #{available_predicates.join(', ')}"
          end
          msg
        end
      end
    end
  end
end
