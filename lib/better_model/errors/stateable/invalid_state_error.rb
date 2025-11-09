# frozen_string_literal: true

require_relative "stateable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Stateable
      # Raised when an invalid state is referenced.
      #
      # @example
      #   raise InvalidStateError.new(
      #     state: :unknown,
      #     available_states: [:draft, :published, :archived],
      #     model_class: Article
      #   )
      class InvalidStateError < StateableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :state, :available_states, :model_class

        # Initialize a new InvalidStateError.
        #
        # @param state [Symbol] The invalid state that was referenced
        # @param available_states [Array<Symbol>] List of valid/available states
        # @param model_class [Class, nil] Model class (optional)
        def initialize(state:, available_states: [], model_class: nil)
          @state = state
          @available_states = available_states
          @model_class = model_class

          @tags = build_tags(error_category: "invalid_state")

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            state: state,
            available_states: available_states
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Invalid state: #{state.inspect}"
          if available_states.any?
            msg += ". Available states: #{available_states.join(', ')}"
          end
          msg
        end
      end
    end
  end
end
