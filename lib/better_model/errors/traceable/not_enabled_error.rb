# frozen_string_literal: true

require_relative "traceable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Traceable
      # Raised when Traceable methods are called but the module is not enabled on the model.
      #
      # @example
      #   raise NotEnabledError.new(
      #     module_name: "Traceable",
      #     method_called: "some_method",
      #     model_class: Article
      #   )
      #
      # @example Accessing error data
      #   rescue NotEnabledError => e
      #     e.module_name    # => "Traceable"
      #     e.method_called  # => "some_method"
      #     e.model_class    # => Article
      #
      #     # Sentry-compatible data
      #     e.tags    # => {error_category: 'not_enabled', module: 'traceable'}
      #     e.context # => {model_class: 'Article', module_name: 'Traceable'}
      #     e.extra   # => {method_called: 'some_method'}
      class NotEnabledError < TraceableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :module_name, :method_called, :model_class

        # @param module_name [String] The module that is not enabled
        # @param method_called [String, Symbol, nil] The method that was called
        # @param model_class [Class, nil] The model class where error occurred
        def initialize(module_name:, method_called: nil, model_class: nil)
          @module_name = module_name
          @method_called = method_called
          @model_class = model_class

          @tags = build_tags(error_category: "not_enabled")

          @context = build_context(
            model_class: model_class,
            module_name: module_name
          )

          @extra = build_extra(method_called: method_called)

          super(build_message)
        end

        private

        def build_message
          msg = "#{module_name} is not enabled. Add '#{module_name.downcase} do...end' to your model."
          msg += " (called from: #{method_called})" if method_called
          msg
        end
      end
    end
  end
end
