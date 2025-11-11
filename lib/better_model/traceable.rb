# frozen_string_literal: true

require_relative "errors/traceable/traceable_error"
require_relative "errors/traceable/not_enabled_error"
require_relative "errors/traceable/configuration_error"

# Traceable - Change tracking with audit trail for Rails models.
#
# This concern enables automatic tracking of record changes,
# maintaining a complete history with timestamps, author, and reasoning.
#
# @example Quick Setup - Option 1: Automatic Generator (Recommended)
#   rails g better_model:traceable Article --with-reason
#   rails db:migrate
#
# @example Quick Setup - Option 2: Using Included Migration
#   # The better_model_versions migration is already in the gem
#   rails db:migrate
#
# @note OPT-IN APPROACH
#   Tracking is not enabled automatically. You must explicitly call
#   `traceable do...end` in your model to activate it.
#
# @note DATABASE REQUIREMENTS
#   - better_model_versions table (included in gem)
#
# @example Basic Model Setup
#   class Article < ApplicationRecord
#     include BetterModel
#
#     # Enable traceable (opt-in)
#     traceable do
#       track :status, :title, :published_at  # Fields to track
#     end
#   end
#
# @example Automatic Tracking
#   article.update!(status: "published", updated_by_id: user.id, updated_reason: "Approved")
#
# @example Querying Versions
#   article.versions                           # All versions
#   article.changes_for(:status)               # Changes for a field
#   article.audit_trail                        # Formatted history
#
# @example Time-Travel
#   article.as_of(3.days.ago)                  # State at specific date
#
# @example Rollback
#   article.rollback_to(version)               # Restore to previous version
#
# @example Query Scopes for Changes
#   Article.changed_by(user.id)                # Changes by user
#   Article.changed_between(start, end)        # Changes in period
#   Article.status_changed_from("draft").to("published")  # Specific transitions
#
module BetterModel
  module Traceable
    extend ActiveSupport::Concern

    # Thread-safe mutex for dynamic class creation
    CLASS_CREATION_MUTEX = Mutex.new

    included do
      # Validazione ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Traceable::ConfigurationError, "Invalid configuration"
      end

      # Configurazione traceable (opt-in)
      class_attribute :traceable_enabled, default: false
      class_attribute :traceable_config, default: {}.freeze
      class_attribute :traceable_fields, default: [].freeze
      class_attribute :traceable_sensitive_fields, default: {}.freeze
      class_attribute :traceable_table_name, default: nil
      class_attribute :_traceable_setup_done, default: false
    end

    class_methods do
      # DSL per attivare e configurare traceable (OPT-IN)
      #
      # @example Attivazione base
      #   traceable do
      #     track :status, :title
      #   end
      #
      def traceable(&block)
        # Attiva traceable
        self.traceable_enabled = true

        # Configura se passato un blocco
        if block_given?
          configurator = TraceableConfigurator.new(self)
          configurator.instance_eval(&block)
          self.traceable_config = configurator.to_h.freeze
          self.traceable_fields = configurator.fields.freeze
          self.traceable_sensitive_fields = configurator.sensitive_fields.freeze
          self.traceable_table_name = configurator.table_name
        end

        # Set default table name if not configured
        self.traceable_table_name ||= "#{model_name.singular.underscore}_versions"

        # Setup association and callbacks only once
        return if self._traceable_setup_done

        self._traceable_setup_done = true

        # Create a dynamic Version class for this table if needed
        version_class = create_version_class_for_table(traceable_table_name)

        # Setup association
        # NOTE: We DON'T use dependent: :destroy because we want to preserve
        # version history even after the record is destroyed (audit trail)
        has_many :versions,
                 -> { order(created_at: :desc) },
                 as: :item,
                 class_name: version_class.name,
                 foreign_key: :item_id

        # Setup callbacks per tracking automatico
        after_create :create_version_on_create
        after_update :create_version_on_update
        before_destroy :create_version_on_destroy
      end

      # Verifica se traceable è attivo
      #
      # @return [Boolean]
      def traceable_enabled? = traceable_enabled == true

      # Find records changed by a specific user
      #
      # @param user_id [Integer] User ID
      # @return [ActiveRecord::Relation]
      def changed_by(user_id)
        unless traceable_enabled?
          raise BetterModel::Errors::Traceable::NotEnabledError, "Module is not enabled"
        end

        joins(:versions).where(traceable_table_name => { updated_by_id: user_id }).distinct
      end

      # Find records changed between two timestamps
      #
      # @param start_time [Time, Date] Start time
      # @param end_time [Time, Date] End time
      # @return [ActiveRecord::Relation]
      def changed_between(start_time, end_time)
        unless traceable_enabled?
          raise BetterModel::Errors::Traceable::NotEnabledError, "Module is not enabled"
        end

        joins(:versions).where(traceable_table_name => { created_at: start_time..end_time }).distinct
      end

      # Query builder for field-specific changes
      #
      # @param field [Symbol] Field name
      # @return [ChangeQuery]
      def field_changed(field)
        unless traceable_enabled?
          raise BetterModel::Errors::Traceable::NotEnabledError, "Module is not enabled"
        end

        ChangeQuery.new(self, field)
      end

      # Syntactic sugar: Article.status_changed_from(...)
      def method_missing(method_name, *args, &block)
        if method_name.to_s =~ /^(.+)_changed_from$/
          field = Regexp.last_match(1).to_sym
          return field_changed(field).from(args.first) if traceable_fields.include?(field)
        end

        super
      end

      def respond_to_missing?(method_name, include_private = false)
        if method_name.to_s =~ /^(.+)_changed_from$/
          field = Regexp.last_match(1).to_sym
          return true if traceable_fields.include?(field)
        end

        super
      end

      private

      # Create or retrieve a Version class for the given table name
      #
      # Thread-safe implementation using mutex to prevent race conditions
      # when multiple threads try to create the same class simultaneously.
      #
      # @param table_name [String] Table name for versions
      # @return [Class] Version class
      def create_version_class_for_table(table_name)
        # Create a unique class name based on table name
        class_name = "#{table_name.camelize.singularize}"

        # Fast path: check if class already exists (no lock needed)
        if BetterModel.const_defined?(class_name, false)
          return BetterModel.const_get(class_name)
        end

        # Slow path: acquire lock and create class
        CLASS_CREATION_MUTEX.synchronize do
          # Double-check after acquiring lock (another thread may have created it)
          if BetterModel.const_defined?(class_name, false)
            return BetterModel.const_get(class_name)
          end

          # Create new Version class dynamically
          version_class = Class.new(BetterModel::Models::Version) do
            self.table_name = table_name
          end

          # Register the class in BetterModel namespace
          BetterModel.const_set(class_name, version_class)
          version_class
        end
      end
    end

    # Metodi di istanza

    # Get changes for a specific field across all versions
    #
    # @param field [Symbol] Field name
    # @return [Array<Hash>] Array of changes with :before, :after, :at, :by
    def changes_for(field)
      unless self.class.traceable_enabled?
        raise BetterModel::Errors::Traceable::NotEnabledError, "Module is not enabled"
      end

      versions.select { |v| v.changed?(field) }.map do |version|
        change = version.change_for(field)
        {
          before: change[:before],
          after: change[:after],
          at: version.created_at,
          by: version.updated_by_id,
          reason: version.updated_reason
        }
      end
    end

    # Get formatted audit trail
    #
    # @return [Array<Hash>] Full audit trail
    def audit_trail
      unless self.class.traceable_enabled?
        raise BetterModel::Errors::Traceable::NotEnabledError, "Module is not enabled"
      end

      versions.map do |version|
        {
          event: version.event,
          changes: version.object_changes || {},
          at: version.created_at,
          by: version.updated_by_id,
          reason: version.updated_reason
        }
      end
    end

    # Reconstruct object state at a specific point in time
    #
    # @param timestamp [Time, Date] Point in time
    # @return [self] Reconstructed object (not saved)
    def as_of(timestamp)
      unless self.class.traceable_enabled?
        raise BetterModel::Errors::Traceable::NotEnabledError, "Module is not enabled"
      end

      # Get all versions up to timestamp, ordered from oldest to newest
      relevant_versions = versions.where("created_at <= ?", timestamp).order(created_at: :asc)

      # Start with a blank object
      reconstructed = self.class.new

      # Apply each version's "after" value in chronological order
      relevant_versions.each do |version|
        next unless version.object_changes

        version.object_changes.each do |field, (_before_value, after_value)|
          reconstructed.send("#{field}=", after_value) if reconstructed.respond_to?("#{field}=")
        end
      end

      reconstructed.id = id
      reconstructed.readonly!
      reconstructed
    end

    # Rollback to a specific version
    #
    # @param version [BetterModel::Models::Version, Integer] Version or version ID
    # @param updated_by_id [Integer] User ID performing rollback
    # @param updated_reason [String] Reason for rollback
    # @return [self]
    def rollback_to(version, updated_by_id: nil, updated_reason: nil, allow_sensitive: false)
      unless self.class.traceable_enabled?
        raise BetterModel::Errors::Traceable::NotEnabledError, "Module is not enabled"
      end

      version = versions.find(version) if version.is_a?(Integer)

      raise ActiveRecord::RecordNotFound, "Version not found" unless version
      raise ActiveRecord::RecordNotFound, "Version does not belong to this record" unless version.item == self

      # Apply changes from version
      if version.object_changes
        version.object_changes.each do |field, (before_value, after_value)|
          field_sym = field.to_sym

          # Check if field is sensitive
          if self.class.traceable_sensitive_fields.key?(field_sym)
            unless allow_sensitive
              Rails.logger.warn "[BetterModel::Traceable] Skipping sensitive field '#{field}' in rollback. Use allow_sensitive: true to rollback sensitive fields."
              next
            end

            Rails.logger.warn "[BetterModel::Traceable] Rolling back sensitive field '#{field}' - allowed by allow_sensitive flag"
          end

          # For 'created' events, use after_value (the value at creation)
          # For 'updated' events, use before_value (the value before the update)
          rollback_value = version.event == "created" ? after_value : before_value
          send("#{field}=", rollback_value) if respond_to?("#{field}=")
        end
      end

      # Save with tracking
      self.updated_by_id = updated_by_id if respond_to?(:updated_by_id=)
      self.updated_reason = updated_reason || "Rolled back to version #{version.id}" if respond_to?(:updated_reason=)

      save!(validate: false)
      self
    end

    # Override as_json to include audit trail
    #
    # @param options [Hash] Options
    # @option options [Boolean] :include_audit_trail Include full audit trail
    # @return [Hash]
    def as_json(options = {})
      result = super

      if options[:include_audit_trail] && self.class.traceable_enabled?
        result["audit_trail"] = audit_trail
      end

      result
    end

    private

    # Create version on record creation
    def create_version_on_create
      return unless self.class.traceable_enabled?

      create_version("created", tracked_changes)
    end

    # Create version on record update
    def create_version_on_update
      return unless self.class.traceable_enabled?

      changes = tracked_changes
      return if changes.empty?

      create_version("updated", changes)
    end

    # Create version on record destruction
    def create_version_on_destroy
      return unless self.class.traceable_enabled?

      create_version("destroyed", tracked_final_state)
    end

    # Get tracked changes (only for configured fields)
    def tracked_changes
      return {} if self.class.traceable_fields.empty?

      raw_changes = if saved_changes.any?
        # After save: use saved_changes
        saved_changes.slice(*self.class.traceable_fields.map(&:to_s))
      else
        # Before save: use changes
        changes.slice(*self.class.traceable_fields.map(&:to_s))
      end

      # Apply redaction to sensitive fields
      apply_redaction_to_changes(raw_changes)
    end

    # Get final state for destroyed records
    def tracked_final_state
      raw_state = self.class.traceable_fields.each_with_object({}) do |field, hash|
        hash[field.to_s] = [ send(field), nil ]
      end

      # Apply redaction to sensitive fields
      apply_redaction_to_changes(raw_state)
    end

    # Apply redaction to changes hash based on sensitive field configuration
    #
    # @param changes_hash [Hash] Hash of field changes {field => [old, new]}
    # @return [Hash] Redacted changes hash
    def apply_redaction_to_changes(changes_hash)
      return changes_hash if self.class.traceable_sensitive_fields.empty?

      changes_hash.each_with_object({}) do |(field, values), result|
        field_sym = field.to_sym

        if self.class.traceable_sensitive_fields.key?(field_sym)
          level = self.class.traceable_sensitive_fields[field_sym]
          result[field] = [
            redact_value(field_sym, values[0], level),
            redact_value(field_sym, values[1], level)
          ]
        else
          result[field] = values
        end
      end
    end

    # Redact a single value based on sensitivity level
    #
    # @param field [Symbol] Field name
    # @param value [Object] Value to redact
    # @param level [Symbol] Sensitivity level (:full, :partial, :hash)
    # @return [String] Redacted value
    def redact_value(field, value, level)
      return "[REDACTED]" if value.nil? && level == :full

      case level
      when :full
        "[REDACTED]"
      when :partial
        redact_partial(field, value)
      when :hash
        require "digest"
        "sha256:#{Digest::SHA256.hexdigest(value.to_s)}"
      else
        value  # Fallback to original value
      end
    end

    # Partially redact a value based on field patterns
    #
    # @param field [Symbol] Field name
    # @param value [Object] Value to partially redact
    # @return [String] Partially redacted value
    def redact_partial(field, value)
      return "[REDACTED]" if value.blank?

      str = value.to_s

      # Credit card pattern (13-19 digits)
      if str.gsub(/\D/, "").match?(/^\d{13,19}$/)
        digits = str.gsub(/\D/, "")
        "****#{digits[-4..-1]}"
      # Email pattern
      elsif str.include?("@")
        parts = str.split("@")
        username_length = parts.first.length
        masked_username = username_length <= 3 ? "***" : "#{parts.first[0]}***"
        "#{masked_username}@#{parts.last}"
      # SSN pattern (US: XXX-XX-XXXX or XXXXXXXXX)
      elsif str.gsub(/\D/, "").match?(/^\d{9}$/)
        digits = str.gsub(/\D/, "")
        "***-**-#{digits[-4..-1]}"
      # Phone pattern (10+ digits)
      elsif str.gsub(/\D/, "").match?(/^\d{10,}$/)
        digits = str.gsub(/\D/, "")
        "***-***-#{digits[-4..-1]}"
      # Default: show only length
      else
        "[REDACTED:#{str.length}chars]"
      end
    end

    # Create a version record
    def create_version(event_type, changes_hash)
      versions.create!(
        event: event_type,
        object_changes: changes_hash,
        updated_by_id: try(:updated_by_id),
        updated_reason: try(:updated_reason)
      )
    end
  end


  # Configurator per traceable DSL
  class TraceableConfigurator
    attr_reader :fields, :table_name, :sensitive_fields

    def initialize(model_class)
      @model_class = model_class
      @fields = []
      @sensitive_fields = {}
      @table_name = nil
    end

    # Specify which fields to track
    #
    # @param field_names [Array<Symbol>] Field names to track
    # @param sensitive [Symbol, nil] Sensitivity level (:full, :partial, :hash)
    #
    # @example Normal tracking
    #   track :title, :status
    #
    # @example Sensitive tracking
    #   track :password, sensitive: :full
    #   track :email, sensitive: :partial
    #   track :ssn, sensitive: :hash
    def track(*field_names, sensitive: nil)
      field_names.each do |field|
        @fields << field
        @sensitive_fields[field] = sensitive if sensitive
      end
    end

    # Specify custom table name for versions
    #
    # @param name [String, Symbol] Table name
    def versions_table(name)
      @table_name = name.to_s
    end

    def to_h
      { fields: @fields, sensitive_fields: @sensitive_fields, table_name: @table_name }
    end
  end

  # Query builder for change-specific queries
  class ChangeQuery
    def initialize(model_class, field)
      @model_class = model_class
      @field = field.to_s
      @from_value = nil
      @to_value = nil
      @table_name = model_class.traceable_table_name
    end

    def from(value)
      @from_value = value
      self
    end

    def to(value)
      @to_value = value
      execute_query
    end

    private

    # Check if database supports JSON/JSONB queries
    def postgres?
      ActiveRecord::Base.connection.adapter_name.downcase == "postgresql"
    end

    def mysql?
      adapter = ActiveRecord::Base.connection.adapter_name.downcase
      adapter.include?("mysql") || adapter == "trilogy"
    end

    def execute_query
      # Base query
      query = @model_class.joins(:versions)

      # NOTA: I blocchi PostgreSQL e MySQL qui sotto non sono coperti da test
      # automatici perché i test vengono eseguiti su SQLite per performance.
      # Testare manualmente su PostgreSQL/MySQL con: rails console RAILS_ENV=test

      # PostgreSQL: Use JSONB operators for better performance
      if postgres?
        query = query.where("#{@table_name}.object_changes ? :field", field: @field)

        if @from_value
          query = query.where("#{@table_name}.object_changes->>'#{@field}' LIKE ?", "%#{@from_value}%")
        end

        if @to_value
          query = query.where("#{@table_name}.object_changes->>'#{@field}' LIKE ?", "%#{@to_value}%")
        end
      # MySQL 5.7+: Use JSON_EXTRACT
      elsif mysql?
        query = query.where("JSON_EXTRACT(#{@table_name}.object_changes, '$.#{@field}') IS NOT NULL")

        if @from_value
          query = query.where("JSON_EXTRACT(#{@table_name}.object_changes, '$.#{@field}') LIKE ?", "%#{@from_value}%")
        end

        if @to_value
          query = query.where("JSON_EXTRACT(#{@table_name}.object_changes, '$.#{@field}') LIKE ?", "%#{@to_value}%")
        end
      # SQLite or fallback: Use text-based search (limited functionality)
      else
        Rails.logger.warn "Traceable field-specific queries may have limited functionality on #{ActiveRecord::Base.connection.adapter_name}"

        query = query.where("#{@table_name}.object_changes LIKE ?", "%\"#{@field}\"%")

        if @from_value
          query = query.where("#{@table_name}.object_changes LIKE ?", "%#{@from_value}%")
        end

        if @to_value
          query = query.where("#{@table_name}.object_changes LIKE ?", "%#{@to_value}%")
        end
      end

      query.distinct
    end
  end
end
