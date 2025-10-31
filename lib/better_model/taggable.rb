# frozen_string_literal: true

# Taggable - Sistema di gestione tag dichiarativo per modelli Rails
#
# Questo concern permette di gestire tag multipli sui modelli utilizzando array PostgreSQL
# con normalizzazione, validazione e statistiche. La ricerca è delegata a Predicable.
#
# Esempio di utilizzo:
#   class Article < ApplicationRecord
#     include BetterModel
#
#     taggable do
#       tag_field :tags
#       normalize true
#       validates_tags minimum: 1, maximum: 10
#     end
#   end
#
# Utilizzo:
#   article.tag_with("ruby", "rails")           # Aggiungi tag
#   article.untag("rails")                      # Rimuovi tag
#   article.tag_list = "ruby, rails, tutorial"  # Da stringa CSV
#   article.tagged_with?("ruby")                # => true
#
# Ricerca (delegata a Predicable):
#   Article.tags_contains("ruby")               # Predicable
#   Article.tags_overlaps(["ruby", "python"])   # Predicable
#   Article.search(tags_contains: "ruby")       # Searchable + Predicable
#
# Statistiche:
#   Article.tag_counts                          # => {"ruby" => 45, "rails" => 38}
#   Article.popular_tags(limit: 10)             # => [["ruby", 45], ["rails", 38], ...]
#
module BetterModel
  module Taggable
    extend ActiveSupport::Concern

    # Configurazione Taggable
    class Configuration
      attr_reader :validates_minimum, :validates_maximum, :allowed_tags, :forbidden_tags

      def initialize
        @tag_field = :tags
        @normalize = false
        @strip = true
        @min_length = nil
        @max_length = nil
        @delimiter = ","
        @validates_minimum = nil
        @validates_maximum = nil
        @allowed_tags = nil
        @forbidden_tags = nil
      end

      def tag_field(field_name = nil)
        return @tag_field if field_name.nil?
        @tag_field = field_name.to_sym
      end

      def normalize(value = nil)
        return @normalize if value.nil?
        @normalize = value
      end

      def strip(value = nil)
        return @strip if value.nil?
        @strip = value
      end

      def min_length(value = nil)
        return @min_length if value.nil?
        @min_length = value
      end

      def max_length(value = nil)
        return @max_length if value.nil?
        @max_length = value
      end

      def delimiter(value = nil)
        return @delimiter if value.nil?
        @delimiter = value
      end

      def validates_tags(options = {})
        @validates_minimum = options[:minimum]
        @validates_maximum = options[:maximum]
        @allowed_tags = Array(options[:allowed_tags]) if options[:allowed_tags]
        @forbidden_tags = Array(options[:forbidden_tags]) if options[:forbidden_tags]
      end
    end

    included do
      # Valida che sia incluso solo in modelli ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Taggable can only be included in ActiveRecord models"
      end

      # Configurazione Taggable per questa classe
      class_attribute :taggable_config, default: nil
    end

    class_methods do
      # DSL per configurare Taggable
      #
      # Esempio:
      #   taggable do
      #     tag_field :tags
      #     normalize true
      #     strip true
      #     min_length 2
      #     max_length 50
      #     delimiter ','
      #     validates_tags minimum: 1, maximum: 10, allowed_tags: ["ruby", "rails"]
      #   end
      def taggable(&block)
        # Previeni configurazione multipla
        if taggable_config.present?
          raise ArgumentError, "Taggable already configured for #{name}"
        end

        # Crea configurazione
        config = Configuration.new
        config.instance_eval(&block) if block_given?

        # Valida che il campo esista
        tag_field_name = config.tag_field.to_s
        unless column_names.include?(tag_field_name)
          raise ArgumentError, "Tag field #{config.tag_field} does not exist in #{table_name}"
        end

        # Salva configurazione (frozen per thread-safety)
        self.taggable_config = config.freeze

        # Auto-registra predicates per ricerca (delegato a Predicable)
        predicates config.tag_field if respond_to?(:predicates)

        # Registra validazioni se configurate
        setup_validations(config) if config.validates_minimum || config.validates_maximum ||
                                     config.allowed_tags || config.forbidden_tags
      end

      # ============================================================================
      # CLASS METHODS - Statistiche
      # ============================================================================

      # Restituisce un hash con il conteggio di ciascun tag
      #
      # Esempio:
      #   Article.tag_counts  # => {"ruby" => 45, "rails" => 38, "tutorial" => 12}
      def tag_counts
        return {} unless taggable_config

        field = taggable_config.tag_field
        counts = Hash.new(0)

        # Itera tutti i record e conta i tag
        find_each do |record|
          tags = record.public_send(field) || []
          tags.each { |tag| counts[tag] += 1 }
        end

        counts
      end

      # Restituisce i tag più popolari con il loro conteggio
      #
      # Esempio:
      #   Article.popular_tags(limit: 10)
      #   # => [["ruby", 45], ["rails", 38], ["tutorial", 12]]
      def popular_tags(limit: 10)
        return [] unless taggable_config

        tag_counts
          .sort_by { |_tag, count| -count }
          .first(limit)
      end

      # Restituisce i tag che appaiono insieme al tag specificato
      #
      # Esempio:
      #   Article.related_tags("ruby", limit: 10)
      #   # => ["rails", "gem", "activerecord"]
      def related_tags(tag, limit: 10)
        return [] unless taggable_config

        field = taggable_config.tag_field
        related_counts = Hash.new(0)

        # Normalizza il tag query
        config = taggable_config
        normalized_tag = tag.to_s
        normalized_tag = normalized_tag.strip if config.strip
        normalized_tag = normalized_tag.downcase if config.normalize

        # Trova record che contengono il tag
        find_each do |record|
          tags = record.public_send(field) || []
          next unless tags.include?(normalized_tag)

          # Conta gli altri tag che appaiono insieme
          tags.each do |other_tag|
            next if other_tag == normalized_tag
            related_counts[other_tag] += 1
          end
        end

        # Restituisci ordinati per frequenza
        related_counts
          .sort_by { |_tag, count| -count }
          .first(limit)
          .map(&:first)
      end

      private

      # Setup delle validazioni ActiveRecord
      def setup_validations(config)
        field = config.tag_field

        # Validazione minimum
        if config.validates_minimum
          min = config.validates_minimum
          validate do
            tags = public_send(field) || []
            if tags.size < min
              errors.add(field, "must have at least #{min} tags")
            end
          end
        end

        # Validazione maximum
        if config.validates_maximum
          max = config.validates_maximum
          validate do
            tags = public_send(field) || []
            if tags.size > max
              errors.add(field, "must have at most #{max} tags")
            end
          end
        end

        # Validazione whitelist
        if config.allowed_tags
          allowed = config.allowed_tags
          validate do
            tags = public_send(field) || []
            invalid_tags = tags - allowed
            if invalid_tags.any?
              errors.add(field, "contains invalid tags: #{invalid_tags.join(', ')}")
            end
          end
        end

        # Validazione blacklist
        if config.forbidden_tags
          forbidden = config.forbidden_tags
          validate do
            tags = public_send(field) || []
            forbidden_found = tags & forbidden
            if forbidden_found.any?
              errors.add(field, "contains forbidden tags: #{forbidden_found.join(', ')}")
            end
          end
        end
      end
    end

    # ============================================================================
    # INSTANCE METHODS - Gestione Tag
    # ============================================================================

    # Aggiunge uno o più tag al record
    #
    # Esempio:
    #   article.tag_with("ruby")
    #   article.tag_with("ruby", "rails", "tutorial")
    def tag_with(*new_tags)
      return unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field

      # Inizializza array se nil
      current_tags = public_send(field) || []

      # Normalizza e aggiungi tag (evita duplicati con |)
      normalized_tags = new_tags.flatten.map { |tag| normalize_tag(tag) }.compact
      updated_tags = (current_tags | normalized_tags)

      # Aggiorna il campo
      public_send("#{field}=", updated_tags)
      save if persisted?
    end

    # Rimuove uno o più tag dal record
    #
    # Esempio:
    #   article.untag("tutorial")
    #   article.untag("ruby", "rails")
    def untag(*tags_to_remove)
      return unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field

      # Ottieni tag attuali
      current_tags = public_send(field) || []

      # Normalizza tag da rimuovere
      normalized_tags = tags_to_remove.flatten.map { |tag| normalize_tag(tag) }.compact

      # Rimuovi tag
      updated_tags = current_tags - normalized_tags

      # Aggiorna il campo
      public_send("#{field}=", updated_tags)
      save if persisted?
    end

    # Sostituisce tutti i tag esistenti con nuovi tag
    #
    # Esempio:
    #   article.retag("python", "django")
    def retag(*new_tags)
      return unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field

      # Normalizza nuovi tag
      normalized_tags = new_tags.flatten.map { |tag| normalize_tag(tag) }.compact.uniq

      # Sostituisci tutti i tag
      public_send("#{field}=", normalized_tags)
      save if persisted?
    end

    # Verifica se il record ha un determinato tag
    #
    # Esempio:
    #   article.tagged_with?("ruby")  # => true/false
    def tagged_with?(tag)
      return false unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field

      current_tags = public_send(field) || []
      normalized_tag = normalize_tag(tag)

      current_tags.include?(normalized_tag)
    end

    # ============================================================================
    # TAG LIST (CSV Interface)
    # ============================================================================

    # Restituisce i tag come stringa separata da delimitatore
    #
    # Esempio:
    #   article.tag_list  # => "ruby, rails, tutorial"
    def tag_list
      return "" unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field
      delimiter = config.delimiter

      current_tags = public_send(field) || []

      # Aggiungi spazio dopo virgola per leggibilità (solo se delimiter è virgola)
      separator = delimiter == "," ? "#{delimiter} " : delimiter
      current_tags.join(separator)
    end

    # Imposta i tag da una stringa separata da delimitatore
    #
    # Esempio:
    #   article.tag_list = "ruby, rails, tutorial"
    def tag_list=(tag_string)
      return unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field
      delimiter = config.delimiter

      # Parse string
      if tag_string.blank?
        tags = []
      else
        tags = tag_string.split(delimiter).map { |tag| normalize_tag(tag) }.compact.uniq
      end

      # Imposta tags
      public_send("#{field}=", tags)
      save if persisted?
    end

    # ============================================================================
    # JSON SERIALIZATION
    # ============================================================================

    # Override as_json per includere informazioni tag
    #
    # Opzioni:
    #   include_tag_list: true    # Includi tag_list come string
    #   include_tag_stats: true   # Includi statistiche tag
    #
    # Esempio:
    #   article.as_json(include_tag_list: true, include_tag_stats: true)
    def as_json(options = {})
      json = super(options)

      return json unless taggable_enabled?

      # Aggiungi tag_list se richiesto
      if options[:include_tag_list]
        json["tag_list"] = tag_list
      end

      # Aggiungi statistiche tag se richiesto
      if options[:include_tag_stats]
        config = self.class.taggable_config
        field = config.tag_field
        tags = public_send(field) || []

        json["tag_stats"] = {
          "count" => tags.size,
          "tags" => tags
        }
      end

      json
    end

    private

    # Verifica se Taggable è abilitato per questa classe
    def taggable_enabled?
      self.class.taggable_config.present?
    end

    # Normalizza un tag secondo la configurazione
    def normalize_tag(tag)
      return nil if tag.blank?

      config = self.class.taggable_config
      normalized = tag.to_s

      # Strip whitespace
      normalized = normalized.strip if config.strip

      # Lowercase
      normalized = normalized.downcase if config.normalize

      # Min length
      return nil if config.min_length && normalized.length < config.min_length

      # Max length
      normalized = normalized[0...config.max_length] if config.max_length && normalized.length > config.max_length

      normalized
    end
  end
end
