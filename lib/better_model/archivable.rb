# frozen_string_literal: true

require_relative "errors/archivable/archivable_error"
require_relative "errors/archivable/already_archived_error"
require_relative "errors/archivable/not_archived_error"
require_relative "errors/archivable/not_enabled_error"
require_relative "errors/archivable/configuration_error"

# Archivable - Declarative archiving system for Rails models.
#
# This concern enables archiving and restoring records using a simple, declarative DSL
# with support for predicates and scopes.
#
# @example Quick Setup - Option 1: Automatic Generator (Recommended)
#   rails g better_model:archivable Article --with-tracking
#   rails db:migrate
#
# @example Quick Setup - Option 2: Manual Migration
#   rails g migration AddArchivableToArticles archived_at:datetime archived_by_id:integer archive_reason:string
#   rails db:migrate
#
# @note OPT-IN APPROACH
#   Archiving is not enabled automatically. You must explicitly call
#   `archivable do...end` in your model to activate it.
#
# @note HYBRID APPROACH
#   Uses existing predicates (archived_at_present, archived_at_null, etc.)
#   and provides semantic aliases (archived, not_archived) for better readability.
#
# @note DATABASE REQUIREMENTS
#   - archived_at (datetime)    - REQUIRED
#   - archived_by_id (integer)  - OPTIONAL (for user tracking)
#   - archive_reason (string)   - OPTIONAL (for reasoning)
#
# @example Basic Model Setup
#   class Article < ApplicationRecord
#     include BetterModel
#
#     # Enable archivable (opt-in)
#     archivable do
#       skip_archived_by_default true  # Optional: hide archived records by default
#     end
#   end
#
# @example Instance Methods Usage
#   article.archive!                        # Archive the record
#   article.archive!(by: user)              # Archive with user tracking
#   article.archive!(reason: "Outdated")    # Archive with reason
#   article.restore!                        # Restore archived record
#   article.archived?                       # Check if archived
#   article.active?                         # Check if not archived
#
# @example Semantic Scopes
#   Article.archived                        # Find archived records
#   Article.not_archived                    # Find active records
#   Article.archived_only                   # Bypass default scope
#
# @example Powerful Predicates (Auto-generated)
#   Article.archived_at_within(7.days)      # Archived in last 7 days
#   Article.archived_at_today               # Archived today
#   Article.archived_at_between(start, end) # Archived in range
#
# @example Helper Methods
#   Article.archived_today                  # Alias for archived_at_today
#   Article.archived_this_week              # Alias for archived_at_this_week
#   Article.archived_recently(7.days)       # Alias for archived_at_within
#
# @example Integration with Searchable
#   Article.search({ archived_at_null: true, status_eq: "published" })
#
module BetterModel
  module Archivable
    extend ActiveSupport::Concern

    included do
      # Include shared enabled check concern
      include BetterModel::Concerns::EnabledCheck

      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Archivable::ConfigurationError, "Invalid configuration"
      end

      # Archivable configuration (opt-in)
      class_attribute :archivable_enabled, default: false
      class_attribute :archivable_config, default: {}.freeze
    end

    class_methods do
      # DSL to enable and configure archivable (OPT-IN).
      #
      # This method activates archivable functionality on your model. It automatically
      # defines predicates and sorts on archived_at, creates semantic scope aliases,
      # and optionally configures default scoping behavior.
      #
      # @yield [configurator] Optional configuration block
      # @raise [BetterModel::Errors::Archivable::ConfigurationError] If archived_at column doesn't exist
      #
      # @example Basic activation
      #   archivable
      #
      # @example With configuration
      #   archivable do
      #     skip_archived_by_default true
      #   end
      def archivable(&block)
        # Validate that archived_at exists (only if table exists - allows eager loading before migrations)
        if table_exists? && !column_names.include?("archived_at")
          raise BetterModel::Errors::Archivable::ConfigurationError, "Invalid configuration"
        end

        # Enable archivable
        self.archivable_enabled = true

        # Define predicates on archived_at (opt-in!)
        predicates :archived_at unless predicable_field?(:archived_at)

        # Define sorting on archived_at (opt-in!)
        sort :archived_at unless sortable_field?(:archived_at)

        # Define semantic scope aliases (hybrid approach)
        scope :archived, -> { archived_at_present(true) }
        scope :not_archived, -> { archived_at_null(true) }

        # Configure if block provided
        if block_given?
          configurator = ArchivableConfigurator.new(self)
          configurator.instance_eval(&block)
          self.archivable_config = configurator.to_h.freeze

          # Apply default scope ONLY if configured
          if archivable_config[:skip_archived_by_default]
            default_scope -> { where(archived_at: nil) }
          end
        end
      end

      # Find ONLY archived records, bypassing default scope.
      #
      # @return [ActiveRecord::Relation]
      # @raise [BetterModel::Errors::Archivable::NotEnabledError] If archivable is not enabled
      #
      # @example
      #   Article.archived_only
      def archived_only
        ensure_module_enabled!(:archivable, BetterModel::Errors::Archivable::NotEnabledError)
        unscoped.archived
      end

      # Find records archived today.
      #
      # Helper alias for archived_at_today predicate.
      #
      # @return [ActiveRecord::Relation]
      # @raise [BetterModel::Errors::Archivable::NotEnabledError] If archivable is not enabled
      #
      # @example
      #   Article.archived_today
      def archived_today
        ensure_module_enabled!(:archivable, BetterModel::Errors::Archivable::NotEnabledError)
        archived_at_today
      end

      # Find records archived this week.
      #
      # Helper alias for archived_at_this_week predicate.
      #
      # @return [ActiveRecord::Relation]
      # @raise [BetterModel::Errors::Archivable::NotEnabledError] If archivable is not enabled
      #
      # @example
      #   Article.archived_this_week
      def archived_this_week
        ensure_module_enabled!(:archivable, BetterModel::Errors::Archivable::NotEnabledError)
        archived_at_this_week
      end

      # Find records archived within the specified duration.
      #
      # Helper alias for archived_at_within predicate.
      #
      # @param duration [ActiveSupport::Duration] Time duration (e.g., 7.days)
      # @return [ActiveRecord::Relation]
      # @raise [BetterModel::Errors::Archivable::NotEnabledError] If archivable is not enabled
      #
      # @example Find records archived in the last 7 days
      #   Article.archived_recently(7.days)
      #
      # @example Find records archived in the last month
      #   Article.archived_recently(1.month)
      def archived_recently(duration = 7.days)
        ensure_module_enabled!(:archivable, BetterModel::Errors::Archivable::NotEnabledError)
        archived_at_within(duration)
      end

      # Check if archivable is enabled on this model.
      #
      # @return [Boolean] true if archivable is enabled, false otherwise
      #
      # @example
      #   Article.archivable_enabled?  # => true
      def archivable_enabled? = archivable_enabled == true
    end

    # Instance Methods

    # Archive this record.
    #
    # Sets archived_at to current time and optionally tracks the user and reason.
    # Bypasses validations when saving.
    #
    # @param by [Integer, Object, nil] User ID or user object (optional)
    # @param reason [String, nil] Reason for archiving (optional)
    # @return [self] Returns self for method chaining
    # @raise [BetterModel::Errors::Archivable::NotEnabledError] If archivable is not enabled
    # @raise [BetterModel::Errors::Archivable::AlreadyArchivedError] If already archived
    #
    # @example Basic archiving
    #   article.archive!
    #
    # @example Archive with user tracking
    #   article.archive!(by: current_user)
    #   article.archive!(by: user.id)
    #
    # @example Archive with reason
    #   article.archive!(reason: "Outdated content")
    #
    # @example Archive with both user and reason
    #   article.archive!(by: current_user, reason: "Compliance violation")
    def archive!(by: nil, reason: nil)
      ensure_module_enabled!(:archivable, BetterModel::Errors::Archivable::NotEnabledError)

      if archived?
        raise BetterModel::Errors::Archivable::AlreadyArchivedError, "Record is already archived"
      end

      self.archived_at = Time.current

      # Set archived_by_id: accepts both ID and objects with .id
      if respond_to?(:archived_by_id=) && by.present?
        self.archived_by_id = by.respond_to?(:id) ? by.id : by
      end

      self.archive_reason = reason if respond_to?(:archive_reason=)

      save!(validate: false)
      self
    end

    # Restore archived record.
    #
    # Clears archived_at, archived_by_id, and archive_reason.
    # Bypasses validations when saving.
    #
    # @return [self] Returns self for method chaining
    # @raise [BetterModel::Errors::Archivable::NotEnabledError] If archivable is not enabled
    # @raise [BetterModel::Errors::Archivable::NotArchivedError] If not archived
    #
    # @example
    #   article.restore!
    def restore!
      ensure_module_enabled!(:archivable, BetterModel::Errors::Archivable::NotEnabledError)

      unless archived?
        raise BetterModel::Errors::Archivable::NotArchivedError, "Record is not archived"
      end

      self.archived_at = nil
      self.archived_by_id = nil if respond_to?(:archived_by_id=)
      self.archive_reason = nil if respond_to?(:archive_reason=)

      save!(validate: false)
      self
    end

    # Check if record is archived.
    #
    # @return [Boolean] true if archived, false otherwise
    #
    # @example
    #   article.archived?  # => true
    def archived?
      return false unless self.class.archivable_enabled?
      archived_at.present?
    end

    # Check if record is active (not archived).
    #
    # @return [Boolean] true if active, false otherwise
    #
    # @example
    #   article.active?  # => true
    def active? = !archived?

    # Override as_json to include archive information.
    #
    # Optionally includes detailed archive metadata when requested.
    #
    # @param options [Hash] Options for as_json
    # @option options [Boolean] :include_archive_info Include archive metadata
    # @return [Hash] JSON representation
    #
    # @example Basic JSON
    #   article.as_json
    #
    # @example With archive info
    #   article.as_json(include_archive_info: true)
    #   # => {
    #   #   ...,
    #   #   "archive_info" => {
    #   #     "archived" => true,
    #   #     "archived_at" => "2025-01-15T10:30:00Z",
    #   #     "archived_by_id" => 42,
    #   #     "archive_reason" => "Outdated"
    #   #   }
    #   # }
    def as_json(options = {})
      result = super

      if options[:include_archive_info] && self.class.archivable_enabled?
        result["archive_info"] = {
          "archived" => archived?,
          "archived_at" => archived_at,
          "archived_by_id" => (respond_to?(:archived_by_id) ? archived_by_id : nil),
          "archive_reason" => (respond_to?(:archive_reason) ? archive_reason : nil)
        }
      end

      result
    end
  end


  # Configurator for archivable DSL.
  #
  # Internal class used to configure archivable behavior through the DSL block.
  #
  # @api private
  class ArchivableConfigurator
    attr_reader :config

    # Initialize a new configurator.
    #
    # @param model_class [Class] The model class being configured
    def initialize(model_class)
      @model_class = model_class
      @config = {
        skip_archived_by_default: false
      }
    end

    # Configure default scope to hide archived records.
    #
    # When enabled, adds a default scope that filters out archived records.
    # Use Model.unscoped or Model.archived_only to access archived records.
    #
    # @param value [Boolean] true to hide archived records by default
    #
    # @example
    #   archivable do
    #     skip_archived_by_default true
    #   end
    def skip_archived_by_default(value)
      @config[:skip_archived_by_default] = !!value
    end

    # Convert configuration to hash.
    #
    # @return [Hash] Configuration hash
    # @api private
    def to_h
      @config
    end
  end
end
