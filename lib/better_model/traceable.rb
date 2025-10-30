# frozen_string_literal: true

# Traceable - Change tracking con audit trail per modelli Rails
#
# Questo concern permette di tracciare automaticamente i cambiamenti ai record,
# mantenendo uno storico completo con timestamp, autore e motivazione.
#
# SETUP RAPIDO:
#   # Opzione 1: Generator automatico (raccomandato)
#   rails g better_model:traceable Article --with-reason
#   rails db:migrate
#
#   # Opzione 2: La migration better_model_versions è già nel gem
#   rails db:migrate
#
# APPROCCIO OPT-IN: Il tracking non è attivo automaticamente. Devi chiamare
# esplicitamente `traceable do...end` nel tuo modello per attivarlo.
#
# REQUISITI DATABASE:
#   - better_model_versions table (inclusa nel gem)
#
# Esempio di utilizzo:
#   class Article < ApplicationRecord
#     include BetterModel
#
#     # Attiva traceable (opt-in)
#     traceable do
#       track :status, :title, :published_at  # Campi da tracciare
#     end
#   end
#
# Utilizzo:
#   # Tracking automatico
#   article.update!(status: "published", updated_by_id: user.id, updated_reason: "Approved")
#
#   # Query versioni
#   article.versions                           # Tutte le versioni
#   article.changes_for(:status)               # Cambiamenti per un campo
#   article.audit_trail                        # Storico formattato
#
#   # Time-travel
#   article.as_of(3.days.ago)                  # Stato a una data specifica
#
#   # Rollback
#   article.rollback_to(version)               # Ripristina a versione precedente
#
#   # Scopes per query su cambiamenti
#   Article.changed_by(user.id)                # Modifiche di un utente
#   Article.changed_between(start, end)        # Modifiche in un periodo
#   Article.status_changed_from("draft").to("published")  # Transizioni specifiche
#
module BetterModel
  module Traceable
    extend ActiveSupport::Concern

    # Thread-safe mutex for dynamic class creation
    CLASS_CREATION_MUTEX = Mutex.new

    included do
      # Validazione ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Traceable can only be included in ActiveRecord models"
      end

      # Configurazione traceable (opt-in)
      class_attribute :traceable_enabled, default: false
      class_attribute :traceable_config, default: {}.freeze
      class_attribute :traceable_fields, default: [].freeze
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
      def traceable_enabled?
        traceable_enabled == true
      end

      # Find records changed by a specific user
      #
      # @param user_id [Integer] User ID
      # @return [ActiveRecord::Relation]
      def changed_by(user_id)
        raise NotEnabledError unless traceable_enabled?

        joins(:versions).where(traceable_table_name => { updated_by_id: user_id }).distinct
      end

      # Find records changed between two timestamps
      #
      # @param start_time [Time, Date] Start time
      # @param end_time [Time, Date] End time
      # @return [ActiveRecord::Relation]
      def changed_between(start_time, end_time)
        raise NotEnabledError unless traceable_enabled?

        joins(:versions).where(traceable_table_name => { created_at: start_time..end_time }).distinct
      end

      # Query builder for field-specific changes
      #
      # @param field [Symbol] Field name
      # @return [ChangeQuery]
      def field_changed(field)
        raise NotEnabledError unless traceable_enabled?

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
          version_class = Class.new(BetterModel::Version) do
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
      raise NotEnabledError unless self.class.traceable_enabled?

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
      raise NotEnabledError unless self.class.traceable_enabled?

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
      raise NotEnabledError unless self.class.traceable_enabled?

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
    # @param version [BetterModel::Version, Integer] Version or version ID
    # @param updated_by_id [Integer] User ID performing rollback
    # @param updated_reason [String] Reason for rollback
    # @return [self]
    def rollback_to(version, updated_by_id: nil, updated_reason: nil)
      raise NotEnabledError unless self.class.traceable_enabled?

      version = versions.find(version) if version.is_a?(Integer)

      raise ActiveRecord::RecordNotFound, "Version not found" unless version
      raise ActiveRecord::RecordNotFound, "Version does not belong to this record" unless version.item == self

      # Apply changes from version
      if version.object_changes
        version.object_changes.each do |field, (before_value, _after_value)|
          send("#{field}=", before_value) if respond_to?("#{field}=")
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

      if saved_changes.any?
        # After save: use saved_changes
        saved_changes.slice(*self.class.traceable_fields.map(&:to_s))
      else
        # Before save: use changes
        changes.slice(*self.class.traceable_fields.map(&:to_s))
      end
    end

    # Get final state for destroyed records
    def tracked_final_state
      self.class.traceable_fields.each_with_object({}) do |field, hash|
        hash[field.to_s] = [ send(field), nil ]
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

  # Errori custom
  class TraceableError < StandardError; end

  class NotEnabledError < TraceableError
    def initialize(msg = nil)
      super(msg || "Traceable is not enabled. Add 'traceable do...end' to your model.")
    end
  end

  # Configurator per traceable DSL
  class TraceableConfigurator
    attr_reader :fields, :table_name

    def initialize(model_class)
      @model_class = model_class
      @fields = []
      @table_name = nil
    end

    # Specify which fields to track
    #
    # @param field_names [Array<Symbol>] Field names to track
    def track(*field_names)
      @fields.concat(field_names)
    end

    # Specify custom table name for versions
    #
    # @param name [String, Symbol] Table name
    def versions_table(name)
      @table_name = name.to_s
    end

    def to_h
      { fields: @fields, table_name: @table_name }
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
