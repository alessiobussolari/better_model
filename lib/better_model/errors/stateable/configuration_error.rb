# frozen_string_literal: true

require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Stateable
      # Configuration error for Stateable module.
      # Inherits from ArgumentError to ensure consistency with standard Ruby error handling.
      #
      # @example
      #   raise ConfigurationError.new(
      #     reason: "Stateable can only be included in ActiveRecord models",
      #     model_class: MyClass
      #   )
      #
      # @example Accessing error data
      #   rescue ConfigurationError => e
      #     e.reason        # => "Stateable can only be included..."
      #     e.model_class   # => MyClass
      #
      #     # Sentry-compatible data
      #     e.tags    # => {error_category: 'configuration', module: 'stateable'}
      #     e.context # => {model_class: 'MyClass'}
      #     e.extra   # => {reason: '...', expected: '...', provided: '...'}
      class ConfigurationError < ArgumentError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :reason, :model_class, :expected, :provided
        attr_reader :context, :tags, :extra

        # @param reason [String] Description of the configuration problem
        # @param model_class [Class, nil] The class where configuration failed
        # @param expected [Object, nil] What was expected in the configuration
        # @param provided [Object, nil] What was actually provided
        def initialize(reason:, model_class: nil, expected: nil, provided: nil)
          @reason = reason
          @model_class = model_class
          @expected = expected
          @provided = provided

          @tags = build_tags(error_category: "configuration")

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            reason: reason,
            expected: expected,
            provided: provided
          )

          super(build_message)
        end

        private

        def build_message
          msg = reason
          msg += " (expected: #{expected.inspect})" if expected
          msg += " (provided: #{provided.inspect})" if provided
          msg
        end
      end
    end
  end
end
