# frozen_string_literal: true

require_relative "stateable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Stateable
      # Raised when validation fails during a state transition.
      #
      # @example
      #   raise ValidationFailedError.new(
      #     event: :publish,
      #     errors_object: article.errors,
      #     current_state: :draft,
      #     target_state: :published,
      #     model_class: Article
      #   )
      class ValidationFailedError < StateableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :event, :errors_object, :current_state, :target_state, :model_class

        # Initialize a new ValidationFailedError.
        #
        # @param event [Symbol] The transition event that failed validation
        # @param errors_object [ActiveModel::Errors] ActiveModel errors object with validation errors
        # @param current_state [Symbol, nil] Current state before transition (optional)
        # @param target_state [Symbol, nil] Target state for the transition (optional)
        # @param model_class [Class, nil] Model class (optional)
        def initialize(event:, errors_object:, current_state: nil, target_state: nil, model_class: nil)
          @event = event
          @errors_object = errors_object
          @current_state = current_state
          @target_state = target_state
          @model_class = model_class

          @tags = build_tags(
            error_category: "validation",
            event: event
          )

          @context = build_context(
            model_class: model_class,
            current_state: current_state,
            target_state: target_state
          )

          @extra = build_extra(
            event: event,
            error_fields: errors_object.attribute_names,
            errors_object: errors_object
          )

          super(build_message)
        end

        private

        def build_message
          "Validation failed for transition #{event.inspect}: #{errors_object.full_messages.join(', ')}"
        end
      end
    end
  end
end
