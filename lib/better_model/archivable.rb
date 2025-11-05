# frozen_string_literal: true

# Archivable - Sistema di archiviazione dichiarativa per modelli Rails
#
# Questo concern permette di archiviare e ripristinare record utilizzando un DSL
# semplice e dichiarativo, con supporto per predicati e scopes.
#
# SETUP RAPIDO:
#   # Opzione 1: Generator automatico (raccomandato)
#   rails g better_model:archivable Article --with-tracking
#   rails db:migrate
#
#   # Opzione 2: Migration manuale
#   rails g migration AddArchivableToArticles archived_at:datetime archived_by_id:integer archive_reason:string
#   rails db:migrate
#
# APPROCCIO OPT-IN: L'archiviazione non è attiva automaticamente. Devi chiamare
# esplicitamente `archivable do...end` nel tuo modello per attivarla.
#
# APPROCCIO IBRIDO: Usa i predicati esistenti (archived_at_present, archived_at_null, etc.)
# e fornisce alias semantici (archived, not_archived) per una migliore leggibilità.
#
# REQUISITI DATABASE:
#   - archived_at (datetime)    - REQUIRED (obbligatorio)
#   - archived_by_id (integer)  - OPTIONAL (per tracking utente)
#   - archive_reason (string)   - OPTIONAL (per motivazione)
#
# Esempio di utilizzo:
#   class Article < ApplicationRecord
#     include BetterModel
#
#     # Attiva archivable (opt-in)
#     archivable do
#       skip_archived_by_default true  # Opzionale: nascondi archiviati di default
#     end
#   end
#
# Utilizzo:
#   article.archive!                        # Archive the record
#   article.archive!(by: user)              # Archive with user tracking
#   article.archive!(reason: "Outdated")    # Archive with reason
#   article.restore!                        # Restore archived record
#   article.archived?                       # Check if archived
#   article.active?                         # Check if not archived
#
#   # Scopes semantici
#   Article.archived                        # Find archived records
#   Article.not_archived                    # Find active records
#   Article.archived_only                   # Bypass default scope
#
#   # Predicati potenti (generati automaticamente)
#   Article.archived_at_within(7.days)      # Archived in last 7 days
#   Article.archived_at_today               # Archived today
#   Article.archived_at_between(start, end) # Archived in range
#
#   # Helper methods
#   Article.archived_today                  # Alias for archived_at_today
#   Article.archived_this_week              # Alias for archived_at_this_week
#   Article.archived_recently(7.days)       # Alias for archived_at_within
#
#   # Con Searchable
#   Article.search({ archived_at_null: true, status_eq: "published" })
#
module BetterModel
  module Archivable
    extend ActiveSupport::Concern

    included do
      # Validazione ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Archivable can only be included in ActiveRecord models"
      end

      # Configurazione archivable (opt-in)
      class_attribute :archivable_enabled, default: false
      class_attribute :archivable_config, default: {}.freeze
    end

    class_methods do
      # DSL per attivare e configurare archivable (OPT-IN)
      #
      # @example Attivazione base
      #   archivable
      #
      # @example Con configurazione
      #   archivable do
      #     skip_archived_by_default true
      #   end
      def archivable(&block)
        # Valida che archived_at esista
        unless column_names.include?("archived_at")
          raise ArgumentError,
            "Archivable requires an 'archived_at' datetime column. " \
            "Add it with: rails g migration AddArchivedAtTo#{table_name.classify.pluralize} archived_at:datetime"
        end

        # Attiva archivable
        self.archivable_enabled = true

        # Definisci predicati su archived_at (opt-in!)
        predicates :archived_at unless predicable_field?(:archived_at)

        # Definisci anche sort su archived_at (opt-in!)
        sort :archived_at unless sortable_field?(:archived_at)

        # Definisci gli scope alias (approccio ibrido)
        scope :archived, -> { archived_at_present(true) }
        scope :not_archived, -> { archived_at_null(true) }

        # Configura se passato un blocco
        if block_given?
          configurator = ArchivableConfigurator.new(self)
          configurator.instance_eval(&block)
          self.archivable_config = configurator.to_h.freeze

          # Applica default scope SOLO se configurato
          if archivable_config[:skip_archived_by_default]
            default_scope -> { where(archived_at: nil) }
          end
        end
      end

      # Trova SOLO record archiviati, bypassando default scope
      #
      # @return [ActiveRecord::Relation]
      def archived_only
        raise ArchivableNotEnabledError unless archivable_enabled?
        unscoped.archived
      end

      # Helper: alias per archived_at_today
      def archived_today
        raise ArchivableNotEnabledError unless archivable_enabled?
        archived_at_today
      end

      # Helper: alias per archived_at_this_week
      def archived_this_week
        raise ArchivableNotEnabledError unless archivable_enabled?
        archived_at_this_week
      end

      # Helper: alias per archived_at_within
      #
      # @param duration [ActiveSupport::Duration] Durata (es: 7.days)
      # @return [ActiveRecord::Relation]
      def archived_recently(duration = 7.days)
        raise ArchivableNotEnabledError unless archivable_enabled?
        archived_at_within(duration)
      end

      # Verifica se archivable è attivo
      #
      # @return [Boolean]
      def archivable_enabled?
        archivable_enabled == true
      end
    end

    # Metodi di istanza

    # Archivia il record
    #
    # @param by [Integer, Object] ID utente o oggetto user (opzionale)
    # @param reason [String] Motivo dell'archiviazione (opzionale)
    # @return [self]
    # @raise [ArchivableNotEnabledError] se archivable non è attivo
    # @raise [AlreadyArchivedError] se già archiviato
    def archive!(by: nil, reason: nil)
      raise ArchivableNotEnabledError unless self.class.archivable_enabled?
      raise AlreadyArchivedError, "Record is already archived" if archived?

      self.archived_at = Time.current

      # Set archived_by_id: accetta sia ID che oggetti con .id
      if respond_to?(:archived_by_id=) && by.present?
        self.archived_by_id = by.respond_to?(:id) ? by.id : by
      end

      self.archive_reason = reason if respond_to?(:archive_reason=)

      save!(validate: false)
      self
    end

    # Ripristina record archiviato
    #
    # @return [self]
    # @raise [ArchivableNotEnabledError] se archivable non è attivo
    # @raise [NotArchivedError] se non archiviato
    def restore!
      raise ArchivableNotEnabledError unless self.class.archivable_enabled?
      raise NotArchivedError, "Record is not archived" unless archived?

      self.archived_at = nil
      self.archived_by_id = nil if respond_to?(:archived_by_id=)
      self.archive_reason = nil if respond_to?(:archive_reason=)

      save!(validate: false)
      self
    end

    # Verifica se il record è archiviato
    #
    # @return [Boolean]
    def archived?
      return false unless self.class.archivable_enabled?
      archived_at.present?
    end

    # Verifica se il record è attivo (non archiviato)
    #
    # @return [Boolean]
    def active?
      !archived?
    end

    # Override as_json per includere info archivio
    #
    # @param options [Hash] Opzioni as_json
    # @option options [Boolean] :include_archive_info Include archive metadata
    # @return [Hash]
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

  # Errori custom
  class ArchivableError < StandardError; end
  class AlreadyArchivedError < ArchivableError; end
  class NotArchivedError < ArchivableError; end

  class ArchivableNotEnabledError < ArchivableError
    def initialize(msg = nil)
      super(msg || "Archivable is not enabled. Add 'archivable do...end' to your model.")
    end
  end

  # Configurator per archivable DSL
  class ArchivableConfigurator
    attr_reader :config

    def initialize(model_class)
      @model_class = model_class
      @config = {
        skip_archived_by_default: false
      }
    end

    # Configura default scope per nascondere archiviati
    #
    # @param value [Boolean] true per nascondere archiviati di default
    def skip_archived_by_default(value)
      @config[:skip_archived_by_default] = !!value
    end

    def to_h
      @config
    end
  end
end
