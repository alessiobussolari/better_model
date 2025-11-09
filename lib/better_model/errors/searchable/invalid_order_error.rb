# frozen_string_literal: true

require_relative "searchable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Searchable
      # Raised when an invalid order/sort is used in a search query.
      #
      # @example
      #   raise InvalidOrderError.new(
      #     order_scope: :created_at_xxx,
      #     available_sorts: [:created_at_asc, :created_at_desc, :title_asc],
      #     model_class: Article
      #   )
      class InvalidOrderError < SearchableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :order_scope, :available_sorts, :model_class

        # Initialize a new InvalidOrderError.
        #
        # @param order_scope [Symbol, String] The invalid order scope that was requested
        # @param available_sorts [Array<Symbol>] List of available/valid sort scopes
        # @param model_class [Class, nil] Model class (optional)
        def initialize(order_scope:, available_sorts: [], model_class: nil)
          @order_scope = order_scope
          @available_sorts = available_sorts
          @model_class = model_class

          @tags = build_tags(
            error_category: "invalid_order",
            order: order_scope
          )

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            order_scope: order_scope,
            available_sorts: available_sorts
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Invalid order scope: #{order_scope.inspect}."
          if available_sorts.any?
            msg += " Available sortable scopes: #{available_sorts.join(', ')}"
          end
          msg
        end
      end
    end
  end
end
