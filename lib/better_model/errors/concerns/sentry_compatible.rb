# frozen_string_literal: true

module BetterModel
  module Errors
    module Concerns
      # Shared module for building Sentry-compatible error data structures.
      #
      # This concern provides helper methods for constructing tags, context, and extra
      # data that follow Sentry's conventions for error enrichment.
      #
      # @example Usage in error classes
      #   class InvalidPredicateError < SearchableError
      #     include BetterModel::Errors::Concerns::SentryCompatible
      #
      #     def initialize(predicate_scope:, **options)
      #       @predicate_scope = predicate_scope
      #       @tags = build_tags(error_category: 'invalid_predicate', predicate: predicate_scope)
      #       @context = build_context(options)
      #       @extra = build_extra(options)
      #       super(build_message)
      #     end
      #   end
      module SentryCompatible
        private

        # Build tags hash with base module tag
        #
        # @param error_category [String, Symbol] The error category for grouping
        # @param custom_tags [Hash] Additional tags to include
        # @return [Hash] Tags hash with error_category, module, and custom tags
        def build_tags(error_category:, **custom_tags)
          {
            error_category: error_category.to_s,
            module: extract_module_name
          }.merge(normalize_tag_values(custom_tags))
        end

        # Build context hash with model_class if present
        #
        # @param model_class [Class, nil] The ActiveRecord model class
        # @param custom_context [Hash] Additional context data
        # @return [Hash] Context hash with model_class and custom context
        def build_context(model_class: nil, **custom_context)
          ctx = {}
          ctx[:model_class] = model_class.name if model_class
          ctx.merge(custom_context.compact)
        end

        # Build extra hash with all provided data
        #
        # @param data [Hash] All extra debug data
        # @return [Hash] Extra hash with all data
        def build_extra(**data)
          data.compact
        end

        # Extract module name from error class namespace
        #
        # @return [String] The module name (e.g., 'searchable', 'stateable')
        def extract_module_name
          # self.class.name => "BetterModel::Errors::Searchable::InvalidPredicateError"
          # Extract "Searchable" and downcase it
          parts = self.class.name.split("::")
          module_name = parts[-2] # Second to last part is the module name
          module_name&.downcase || "unknown"
        end

        # Normalize tag values to strings (Sentry requirement)
        #
        # @param tags [Hash] Hash of tag key-value pairs
        # @return [Hash] Hash with all values converted to strings
        def normalize_tag_values(tags)
          tags.transform_values { |v| v.nil? ? nil : v.to_s }.compact
        end
      end
    end
  end
end
