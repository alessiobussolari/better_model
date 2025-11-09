# frozen_string_literal: true

require_relative "stateable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Stateable
      # Raised when an invalid state transition is attempted.
      #
      # @example
      #   raise InvalidTransitionError.new(
      #     event: :publish,
      #     from_state: :draft,
      #     to_state: :published,
      #     model_class: Article
      #   )
      class InvalidTransitionError < StateableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :event, :from_state, :to_state, :model_class

        # Initialize a new InvalidTransitionError.
        #
        # @param event [Symbol] The transition event that was attempted
        # @param from_state [Symbol] The current/source state
        # @param to_state [Symbol] The target/destination state
        # @param model_class [Class, nil] Model class (optional)
        def initialize(event:, from_state:, to_state:, model_class: nil)
          @event = event
          @from_state = from_state
          @to_state = to_state
          @model_class = model_class

          @tags = build_tags(
            error_category: "transition",
            event: event,
            from_state: from_state,
            to_state: to_state
          )

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            event: event,
            from_state: from_state,
            to_state: to_state
          )

          super(build_message)
        end

        private

        def build_message
          "Cannot transition from #{from_state.inspect} to #{to_state.inspect} via #{event.inspect}"
        end
      end
    end
  end
end
