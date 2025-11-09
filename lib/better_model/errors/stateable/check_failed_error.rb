# frozen_string_literal: true

require_relative "stateable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Stateable
      # Raised when a transition check fails.
      #
      # @example
      #   raise CheckFailedError.new(
      #     event: :publish,
      #     check_description: "Article must be complete",
      #     check_type: "predicate",
      #     current_state: :draft,
      #     model_class: Article
      #   )
      class CheckFailedError < StateableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :event, :check_description, :check_type, :current_state, :model_class

        # Initialize a new CheckFailedError.
        #
        # @param event [Symbol] The transition event that failed
        # @param check_description [String, nil] Human-readable description of the failed check (optional)
        # @param check_type [String, nil] Type of check that failed (e.g., "predicate", "method", "block") (optional)
        # @param current_state [Symbol, nil] Current state of the model (optional)
        # @param model_class [Class, nil] Model class (optional)
        def initialize(event:, check_description: nil, check_type: nil, current_state: nil, model_class: nil)
          @event = event
          @check_description = check_description
          @check_type = check_type
          @current_state = current_state
          @model_class = model_class

          @tags = build_tags(
            error_category: "check_failed",
            event: event,
            check_type: check_type
          )

          @context = build_context(
            model_class: model_class,
            current_state: current_state
          )

          @extra = build_extra(
            event: event,
            check_description: check_description,
            check_type: check_type,
            current_state: current_state
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Check failed for transition #{event.inspect}"
          msg += ": #{check_description}" if check_description
          msg
        end
      end

      # Alias for backwards compatibility
      GuardFailedError = CheckFailedError
    end
  end
end
