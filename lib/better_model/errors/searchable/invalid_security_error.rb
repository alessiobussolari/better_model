# frozen_string_literal: true

require_relative "searchable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Searchable
      # Raised when a security policy is violated in a search query.
      #
      # @example
      #   raise InvalidSecurityError.new(
      #     policy_name: "max_page",
      #     violations: ["page exceeds maximum allowed"],
      #     requested_value: 10000,
      #     model_class: Article
      #   )
      class InvalidSecurityError < SearchableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :policy_name, :violations, :requested_value, :model_class

        # Initialize a new InvalidSecurityError.
        #
        # @param policy_name [String] Name of the security policy that was violated
        # @param violations [Array<String>] List of violation descriptions
        # @param requested_value [Object, nil] The value that caused the violation (optional)
        # @param model_class [Class, nil] Model class (optional)
        def initialize(policy_name:, violations: [], requested_value: nil, model_class: nil)
          @policy_name = policy_name
          @violations = violations
          @requested_value = requested_value
          @model_class = model_class

          @tags = build_tags(
            error_category: "security",
            policy: policy_name
          )

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            policy_name: policy_name,
            violations: violations,
            requested_value: requested_value
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Security policy violation: #{policy_name}"
          if violations.any?
            msg += ". #{violations.join('; ')}"
          end
          msg
        end
      end
    end
  end
end
