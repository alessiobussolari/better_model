# frozen_string_literal: true

# Predicable - Sistema di filtri/predicati dichiarativo per modelli Rails
#
# Questo concern permette di definire predicati di ricerca sui modelli utilizzando un DSL
# semplice e dichiarativo che genera automaticamente scope basati sul tipo di colonna.
#
# Esempio di utilizzo:
#   class Article < ApplicationRecord
#     include BetterModel::Predicable
#
#     predicates :title, :status, :view_count, :published_at, :featured
#   end
#
# Utilizzo:
#   Article.title_eq("Ruby on Rails")           # WHERE title = 'Ruby on Rails'
#   Article.title_i_cont("rails")               # WHERE LOWER(title) LIKE '%rails%'
#   Article.view_count_gt(100)                  # WHERE view_count > 100
#   Article.published_at_lteq(Date.today)       # WHERE published_at <= '2025-10-29'
#   Article.featured_true                       # WHERE featured = TRUE
#   Article.status_in(["draft", "published"])   # WHERE status IN ('draft', 'published')
#
module BetterModel
  module Predicable
    extend ActiveSupport::Concern

    included do
      # Valida che sia incluso solo in modelli ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Predicable can only be included in ActiveRecord models"
      end

      # Registry dei campi predicable definiti per questa classe
      class_attribute :predicable_fields, default: Set.new
      # Registry degli scope predicable generati
      class_attribute :predicable_scopes, default: Set.new
      # Registry dei predicati complessi custom
      class_attribute :complex_predicates_registry, default: {}.freeze
    end

    class_methods do
      # DSL per definire campi predicable
      #
      # Genera automaticamente scope di filtro basati sul tipo di colonna:
      # - String: _eq, _not_eq, _matches, _start, _end, _cont, _not_cont, _i_cont, _not_i_cont, _in, _not_in, _present, _blank, _null
      # - Numeric: _eq, _not_eq, _lt, _lteq, _gt, _gteq, _in, _not_in, _present
      # - Boolean: _eq, _not_eq, _true, _false, _present
      # - Date: _eq, _not_eq, _lt, _lteq, _gt, _gteq, _in, _not_in, _present, _blank, _null, _not_null
      #
      # Esempio:
      #   predicates :title, :view_count, :published_at, :featured
      def predicates(*field_names)
        field_names.each do |field_name|
          validate_predicable_field!(field_name)
          register_predicable_field(field_name)

          # Auto-rileva tipo e genera scope appropriati
          column = columns_hash[field_name.to_s]
          next unless column

          case column.type
          when :string, :text
            define_string_predicates(field_name)
          when :integer, :decimal, :float, :bigint
            define_numeric_predicates(field_name)
          when :boolean
            define_boolean_predicates(field_name)
          when :date, :datetime, :time, :timestamp
            define_date_predicates(field_name)
          when :jsonb, :json
            # JSONB/JSON: base predicates + PostgreSQL-specific
            define_base_predicates(field_name)
            define_postgresql_jsonb_predicates(field_name)
          else
            # Check for array columns (PostgreSQL)
            if column.respond_to?(:array?) && column.array?
              define_base_predicates(field_name)
              define_postgresql_array_predicates(field_name)
            else
              # Default: genera solo predicati base
              define_base_predicates(field_name)
            end
          end
        end
      end

      # Registra un predicato complesso custom
      #
      # Permette di definire filtri complessi che combinano più condizioni
      # o utilizzano logica custom non coperta dai predicati standard.
      #
      # Esempio:
      #   register_complex_predicate :recent_popular do |days = 7, min_views = 100|
      #     where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
      #   end
      #
      #   Article.recent_popular(7, 100)
      def register_complex_predicate(name, &block)
        raise ArgumentError, "Block required for complex predicate" unless block_given?

        # Registra nel registry
        self.complex_predicates_registry = complex_predicates_registry.merge(name.to_sym => block).freeze

        # Definisce lo scope
        scope name, block

        # Registra lo scope
        register_predicable_scopes(name)
      end

      # Verifica se un campo è stato registrato come predicable
      def predicable_field?(field_name)
        predicable_fields.include?(field_name.to_sym)
      end

      # Verifica se uno scope predicable è stato generato
      def predicable_scope?(scope_name)
        predicable_scopes.include?(scope_name.to_sym)
      end

      # Verifica se un predicato complesso è stato registrato
      def complex_predicate?(name)
        complex_predicates_registry.key?(name.to_sym)
      end

      private

      # Valida che il campo esista nella tabella
      def validate_predicable_field!(field_name)
        unless column_names.include?(field_name.to_s)
          raise ArgumentError, "Invalid field name: #{field_name}. Field does not exist in #{table_name}"
        end
      end

      # Registra un campo nel registry predicable_fields
      def register_predicable_field(field_name)
        self.predicable_fields = (predicable_fields + [ field_name.to_sym ]).to_set.freeze
      end

      # Registra scope nel registry predicable_scopes
      def register_predicable_scopes(*scope_names)
        self.predicable_scopes = (predicable_scopes + scope_names.map(&:to_sym)).to_set.freeze
      end

      # Genera predicati base: _eq, _not_eq, _present
      def define_base_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # Equality
        scope :"#{field_name}_eq", ->(value) { where(field.eq(value)) }
        scope :"#{field_name}_not_eq", ->(value) { where(field.not_eq(value)) }

        # Presence
        scope :"#{field_name}_present", -> { where(field.not_eq(nil)) }

        register_predicable_scopes(
          :"#{field_name}_eq",
          :"#{field_name}_not_eq",
          :"#{field_name}_present"
        )
      end

      # Genera predicati per campi stringa (14 scope)
      def define_string_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # Comparison (2)
        scope :"#{field_name}_eq", ->(value) { where(field.eq(value)) }
        scope :"#{field_name}_not_eq", ->(value) { where(field.not_eq(value)) }

        # Pattern matching (4)
        scope :"#{field_name}_matches", ->(pattern) { where(field.matches(pattern)) }
        scope :"#{field_name}_start", ->(prefix) {
          sanitized = ActiveRecord::Base.sanitize_sql_like(prefix.to_s)
          where(field.matches("#{sanitized}%"))
        }
        scope :"#{field_name}_end", ->(suffix) {
          sanitized = ActiveRecord::Base.sanitize_sql_like(suffix.to_s)
          where(field.matches("%#{sanitized}"))
        }
        scope :"#{field_name}_cont", ->(substring) {
          sanitized = ActiveRecord::Base.sanitize_sql_like(substring.to_s)
          where(field.matches("%#{sanitized}%"))
        }

        # Case-insensitive pattern matching (2)
        scope :"#{field_name}_i_cont", ->(substring) {
          sanitized = ActiveRecord::Base.sanitize_sql_like(substring.to_s.downcase)
          where(Arel::Nodes::NamedFunction.new("LOWER", [ field ]).matches("%#{sanitized}%"))
        }
        scope :"#{field_name}_not_cont", ->(substring) {
          sanitized = ActiveRecord::Base.sanitize_sql_like(substring.to_s)
          where.not(field.matches("%#{sanitized}%"))
        }
        scope :"#{field_name}_not_i_cont", ->(substring) {
          sanitized = ActiveRecord::Base.sanitize_sql_like(substring.to_s.downcase)
          where.not(Arel::Nodes::NamedFunction.new("LOWER", [ field ]).matches("%#{sanitized}%"))
        }

        # Array operations (2)
        scope :"#{field_name}_in", ->(values) { where(field.in(Array(values))) }
        scope :"#{field_name}_not_in", ->(values) { where.not(field.in(Array(values))) }

        # Presence (3)
        scope :"#{field_name}_present", -> { where(field.not_eq(nil).and(field.not_eq(""))) }
        scope :"#{field_name}_blank", -> { where(field.eq(nil).or(field.eq(""))) }
        scope :"#{field_name}_null", -> { where(field.eq(nil)) }

        register_predicable_scopes(
          :"#{field_name}_eq",
          :"#{field_name}_not_eq",
          :"#{field_name}_matches",
          :"#{field_name}_start",
          :"#{field_name}_end",
          :"#{field_name}_cont",
          :"#{field_name}_i_cont",
          :"#{field_name}_not_cont",
          :"#{field_name}_not_i_cont",
          :"#{field_name}_in",
          :"#{field_name}_not_in",
          :"#{field_name}_present",
          :"#{field_name}_blank",
          :"#{field_name}_null"
        )
      end

      # Genera predicati per campi numerici (11 scope)
      def define_numeric_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # Comparison (6)
        scope :"#{field_name}_eq", ->(value) { where(field.eq(value)) }
        scope :"#{field_name}_not_eq", ->(value) { where(field.not_eq(value)) }
        scope :"#{field_name}_lt", ->(value) { where(field.lt(value)) }
        scope :"#{field_name}_lteq", ->(value) { where(field.lteq(value)) }
        scope :"#{field_name}_gt", ->(value) { where(field.gt(value)) }
        scope :"#{field_name}_gteq", ->(value) { where(field.gteq(value)) }

        # Range queries (2)
        scope :"#{field_name}_between", ->(min, max) { where(field.between(min..max)) }
        scope :"#{field_name}_not_between", ->(min, max) { where.not(field.between(min..max)) }

        # Array operations (2)
        scope :"#{field_name}_in", ->(values) { where(field.in(Array(values))) }
        scope :"#{field_name}_not_in", ->(values) { where.not(field.in(Array(values))) }

        # Presence (1)
        scope :"#{field_name}_present", -> { where(field.not_eq(nil)) }

        register_predicable_scopes(
          :"#{field_name}_eq",
          :"#{field_name}_not_eq",
          :"#{field_name}_lt",
          :"#{field_name}_lteq",
          :"#{field_name}_gt",
          :"#{field_name}_gteq",
          :"#{field_name}_between",
          :"#{field_name}_not_between",
          :"#{field_name}_in",
          :"#{field_name}_not_in",
          :"#{field_name}_present"
        )
      end

      # Genera predicati per campi booleani (5 scope)
      def define_boolean_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # Comparison (2)
        scope :"#{field_name}_eq", ->(value) { where(field.eq(value)) }
        scope :"#{field_name}_not_eq", ->(value) { where(field.not_eq(value)) }

        # Boolean shortcuts (2)
        scope :"#{field_name}_true", -> { where(field.eq(true)) }
        scope :"#{field_name}_false", -> { where(field.eq(false)) }

        # Presence (1)
        scope :"#{field_name}_present", -> { where(field.not_eq(nil)) }

        register_predicable_scopes(
          :"#{field_name}_eq",
          :"#{field_name}_not_eq",
          :"#{field_name}_true",
          :"#{field_name}_false",
          :"#{field_name}_present"
        )
      end

      # Genera predicati per campi array PostgreSQL (3 scope)
      def define_postgresql_array_predicates(field_name)
        return unless postgresql_adapter?

        table = arel_table
        field = table[field_name]
        column = columns_hash[field_name.to_s]

        # Array overlap (&&)
        # Usa Arel per generare SQL sicuro con parameter binding
        scope :"#{field_name}_overlaps", ->(array) {
          sanitized_array = Array(array).map { |v| connection.quote(v) }.join(",")
          where(
            Arel::Nodes::InfixOperation.new(
              "&&",
              field,
              Arel::Nodes::SqlLiteral.new("ARRAY[#{sanitized_array}]::#{column.sql_type}")
            )
          )
        }

        # Array contains (@>)
        scope :"#{field_name}_contains", ->(value) {
          sanitized_array = Array(value).map { |v| connection.quote(v) }.join(",")
          where(
            Arel::Nodes::InfixOperation.new(
              "@>",
              field,
              Arel::Nodes::SqlLiteral.new("ARRAY[#{sanitized_array}]::#{column.sql_type}")
            )
          )
        }

        # Array contained by (<@)
        scope :"#{field_name}_contained_by", ->(array) {
          sanitized_array = Array(array).map { |v| connection.quote(v) }.join(",")
          where(
            Arel::Nodes::InfixOperation.new(
              "<@",
              field,
              Arel::Nodes::SqlLiteral.new("ARRAY[#{sanitized_array}]::#{column.sql_type}")
            )
          )
        }

        register_predicable_scopes(
          :"#{field_name}_overlaps",
          :"#{field_name}_contains",
          :"#{field_name}_contained_by"
        )
      end

      # Genera predicati per campi JSONB PostgreSQL (4 scope)
      def define_postgresql_jsonb_predicates(field_name)
        return unless postgresql_adapter?

        table = arel_table
        field = table[field_name]
        quoted_table = connection.quote_table_name(table_name)
        quoted_field = connection.quote_column_name(field_name)

        # JSONB has key (?)
        # Usa named bind per evitare SQL injection
        scope :"#{field_name}_has_key", ->(key) {
          where("#{quoted_table}.#{quoted_field} ? :key", key: connection.quote(key.to_s))
        }

        # JSONB has any key (?|)
        # Sanifica ogni chiave nell'array prima di passare alla query
        scope :"#{field_name}_has_any_key", ->(keys) {
          sanitized_keys = Array(keys).map { |k| connection.quote(k.to_s) }.join(",")
          where("#{quoted_table}.#{quoted_field} ?| ARRAY[#{sanitized_keys}]")
        }

        # JSONB has all keys (?&)
        scope :"#{field_name}_has_all_keys", ->(keys) {
          sanitized_keys = Array(keys).map { |k| connection.quote(k.to_s) }.join(",")
          where("#{quoted_table}.#{quoted_field} ?& ARRAY[#{sanitized_keys}]")
        }

        # JSONB contains (@>)
        # Usa Arel per operazione @> con proper escaping
        scope :"#{field_name}_jsonb_contains", ->(hash_or_value) {
          json_value = hash_or_value.is_a?(String) ? hash_or_value : hash_or_value.to_json
          where(
            Arel::Nodes::InfixOperation.new(
              "@>",
              field,
              Arel::Nodes::Quoted.new(json_value)
            )
          )
        }

        register_predicable_scopes(
          :"#{field_name}_has_key",
          :"#{field_name}_has_any_key",
          :"#{field_name}_has_all_keys",
          :"#{field_name}_jsonb_contains"
        )
      end

      # Genera predicati per campi data/datetime (22 scope)
      def define_date_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # Comparison (6)
        scope :"#{field_name}_eq", ->(value) { where(field.eq(value)) }
        scope :"#{field_name}_not_eq", ->(value) { where(field.not_eq(value)) }
        scope :"#{field_name}_lt", ->(value) { where(field.lt(value)) }
        scope :"#{field_name}_lteq", ->(value) { where(field.lteq(value)) }
        scope :"#{field_name}_gt", ->(value) { where(field.gt(value)) }
        scope :"#{field_name}_gteq", ->(value) { where(field.gteq(value)) }

        # Range queries (2)
        scope :"#{field_name}_between", ->(min, max) { where(field.between(min..max)) }
        scope :"#{field_name}_not_between", ->(min, max) { where.not(field.between(min..max)) }

        # Array operations (2)
        scope :"#{field_name}_in", ->(values) { where(field.in(Array(values))) }
        scope :"#{field_name}_not_in", ->(values) { where.not(field.in(Array(values))) }

        # Date convenience shortcuts (8)
        scope :"#{field_name}_today", -> {
          where(field.between(Date.current.beginning_of_day..Date.current.end_of_day))
        }
        scope :"#{field_name}_yesterday", -> {
          where(field.between(1.day.ago.beginning_of_day..1.day.ago.end_of_day))
        }
        scope :"#{field_name}_this_week", -> {
          where(field.gteq(Date.current.beginning_of_week))
        }
        scope :"#{field_name}_this_month", -> {
          where(field.gteq(Date.current.beginning_of_month))
        }
        scope :"#{field_name}_this_year", -> {
          where(field.gteq(Date.current.beginning_of_year))
        }
        scope :"#{field_name}_past", -> {
          where(field.lt(Time.current))
        }
        scope :"#{field_name}_future", -> {
          where(field.gt(Time.current))
        }
        scope :"#{field_name}_within", ->(duration) {
          # Auto-detect: ActiveSupport::Duration or numeric (days)
          time_ago = duration.respond_to?(:ago) ? duration.ago : duration.to_i.days.ago
          where(field.gteq(time_ago))
        }

        # Presence (4)
        scope :"#{field_name}_present", -> { where(field.not_eq(nil)) }
        scope :"#{field_name}_blank", -> { where(field.eq(nil)) }
        scope :"#{field_name}_null", -> { where(field.eq(nil)) }
        scope :"#{field_name}_not_null", -> { where(field.not_eq(nil)) }

        register_predicable_scopes(
          :"#{field_name}_eq",
          :"#{field_name}_not_eq",
          :"#{field_name}_lt",
          :"#{field_name}_lteq",
          :"#{field_name}_gt",
          :"#{field_name}_gteq",
          :"#{field_name}_between",
          :"#{field_name}_not_between",
          :"#{field_name}_in",
          :"#{field_name}_not_in",
          :"#{field_name}_today",
          :"#{field_name}_yesterday",
          :"#{field_name}_this_week",
          :"#{field_name}_this_month",
          :"#{field_name}_this_year",
          :"#{field_name}_past",
          :"#{field_name}_future",
          :"#{field_name}_within",
          :"#{field_name}_present",
          :"#{field_name}_blank",
          :"#{field_name}_null",
          :"#{field_name}_not_null"
        )
      end

      # Verifica se il database adapter è PostgreSQL
      def postgresql_adapter?
        connection.adapter_name.match?(/PostgreSQL/i)
      end
    end
  end
end
