# frozen_string_literal: true

require_relative "archivable_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module Archivable
      # Raised when attempting to archive a record that is already archived.
      #
      # @example
      #   raise AlreadyArchivedError.new(
      #     archived_at: Time.current,
      #     model_class: Article,
      #     model_id: 123
      #   )
      class AlreadyArchivedError < ArchivableError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :archived_at, :model_class, :model_id

        # Initialize a new AlreadyArchivedError.
        #
        # @param archived_at [Time] Timestamp when the record was archived
        # @param model_class [Class, nil] Model class (optional)
        # @param model_id [Integer, nil] Model ID (optional)
        def initialize(archived_at:, model_class: nil, model_id: nil)
          @archived_at = archived_at
          @model_class = model_class
          @model_id = model_id

          @tags = build_tags(error_category: "already_archived")

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            archived_at: archived_at,
            model_id: model_id
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Record is already archived"
          msg += " (archived at: #{archived_at})" if archived_at
          msg
        end
      end
    end
  end
end
