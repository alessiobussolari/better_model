# frozen_string_literal: true

require_relative "archivable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Archivable
      # Raised when attempting to perform an operation that requires an archived record on a non-archived record.
      #
      # @example
      #   raise NotArchivedError.new(
      #     method_called: "unarchive!",
      #     model_class: Article,
      #     model_id: 123
      #   )
      class NotArchivedError < ArchivableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :method_called, :model_class, :model_id

        # Initialize a new NotArchivedError.
        #
        # @param method_called [String, Symbol] Method that was called
        # @param model_class [Class, nil] Model class (optional)
        # @param model_id [Integer, nil] Model ID (optional)
        def initialize(method_called:, model_class: nil, model_id: nil)
          @method_called = method_called
          @model_class = model_class
          @model_id = model_id

          @tags = build_tags(error_category: "not_archived")

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            method_called: method_called,
            model_id: model_id
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Record is not archived"
          msg += " (called from: #{method_called})" if method_called
          msg
        end
      end
    end
  end
end
