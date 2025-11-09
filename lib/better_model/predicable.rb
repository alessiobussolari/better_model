# frozen_string_literal: true

require_relative "errors/predicable/predicable_error"
require_relative "errors/predicable/configuration_error"

# Predicable - Declarative filters/predicates system for Rails models.
#
# This concern enables defining search predicates on models using a simple, declarative DSL
# that automatically generates scopes based on column type.
#
# @example Basic Usage
#   class Article < ApplicationRecord
#     include BetterModel::Predicable
#
#     predicates :title, :status, :view_count, :published_at, :featured
#   end
#
# @example Generated Scopes
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
      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Predicable::ConfigurationError.new(
          reason: "BetterModel::Predicable can only be included in ActiveRecord models"
        )
      end

      # Registry of predicable fields defined for this class
      class_attribute :predicable_fields, default: Set.new
      # Registry of generated predicable scopes
      class_attribute :predicable_scopes, default: Set.new
      # Registry of custom complex predicates
      class_attribute :complex_predicates_registry, default: {}.freeze
    end

    class_methods do
      # DSL to define predicable fields.
      #
      # Automatically generates filter scopes based on column type:
      # - String: _eq, _not_eq, _matches, _start, _end, _cont, _not_cont, _i_cont, _not_i_cont, _in, _not_in, _present(bool), _blank(bool), _null(bool)
      # - Numeric: _eq, _not_eq, _lt, _lteq, _gt, _gteq, _between, _not_between, _in, _not_in, _present(bool)
      # - Boolean: _eq, _not_eq, _present(bool)
      # - Date: _eq, _not_eq, _lt, _lteq, _gt, _gteq, _between, _not_between, _in, _not_in, _within(duration), _blank(bool), _null(bool)
      #
      # @param field_names [Array<Symbol>] Field names to make predicable
      #
      # @note All predicates require explicit parameters. Use _eq(true)/_eq(false) for booleans.
      #
      # @example
      #   predicates :title, :view_count, :published_at, :featured
      def predicates(*field_names)
        field_names.each do |field_name|
          validate_predicable_field!(field_name)
          register_predicable_field(field_name)

          # Auto-detect type and generate appropriate scopes
          column = columns_hash[field_name.to_s]
          next unless column

          # Base predicates available for all column types
          define_base_predicates(field_name, column.type)

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
            # JSONB/JSON: PostgreSQL-specific predicates
            define_postgresql_jsonb_predicates(field_name)
          else
            # Check for array columns (PostgreSQL)
            if column.respond_to?(:array?) && column.array?
              define_postgresql_array_predicates(field_name)
            end
            # Unknown types only get base predicates
          end
        end
      end

      # Register a custom complex predicate.
      #
      # Allows defining complex filters that combine multiple conditions
      # or use custom logic not covered by standard predicates.
      #
      # @param name [Symbol] Predicate name
      # @yield Predicate implementation block
      # @raise [BetterModel::Errors::Predicable::ConfigurationError] If block is not provided
      #
      # @example
      #   register_complex_predicate :recent_popular do |days = 7, min_views = 100|
      #     where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
      #   end
      #
      #   Article.recent_popular(7, 100)
      def register_complex_predicate(name, &block)
        unless block_given?
          raise BetterModel::Errors::Predicable::ConfigurationError.new(
            reason: "Block required for complex predicate",
            model_class: self
          )
        end

        # Register in registry
        self.complex_predicates_registry = complex_predicates_registry.merge(name.to_sym => block).freeze

        # Define scope
        scope name, block

        # Register scope
        register_predicable_scopes(name)
      end

      # Check if a field has been registered as predicable.
      #
      # @param field_name [Symbol] Field name to check
      # @return [Boolean] true if field is predicable
      def predicable_field?(field_name) = predicable_fields.include?(field_name.to_sym)

      # Check if a predicable scope has been generated.
      #
      # @param scope_name [Symbol] Scope name to check
      # @return [Boolean] true if scope exists
      def predicable_scope?(scope_name) = predicable_scopes.include?(scope_name.to_sym)

      # Check if a complex predicate has been registered.
      #
      # @param name [Symbol] Predicate name to check
      # @return [Boolean] true if complex predicate exists
      def complex_predicate?(name) = complex_predicates_registry.key?(name.to_sym)

      private

      # Validate that field exists in table.
      #
      # @param field_name [Symbol] Field name to validate
      # @raise [BetterModel::Errors::Predicable::ConfigurationError] If field doesn't exist
      # @api private
      def validate_predicable_field!(field_name)
        unless column_names.include?(field_name.to_s)
          raise BetterModel::Errors::Predicable::ConfigurationError.new(
            reason: "Invalid field name: #{field_name}. Field does not exist in #{table_name}",
            model_class: self,
            expected: "valid column name from #{table_name}",
            provided: field_name
          )
        end
      end

      # Register a field in predicable_fields registry.
      #
      # @param field_name [Symbol] Field name to register
      # @api private
      def register_predicable_field(field_name)
        self.predicable_fields = (predicable_fields + [ field_name.to_sym ]).to_set.freeze
      end

      # Register scopes in predicable_scopes registry.
      #
      # @param scope_names [Array<Symbol>] Scope names to register
      # @api private
      def register_predicable_scopes(*scope_names)
        self.predicable_scopes = (predicable_scopes + scope_names.map(&:to_sym)).to_set.freeze
      end

      # Generate base predicates: _eq, _not_eq, _present.
      #
      # @param field_name [Symbol] Field name
      # @param column_type [Symbol, nil] Column type
      # @api private
      def define_base_predicates(field_name, column_type = nil)
        table = arel_table
        field = table[field_name]

        # Equality
        scope :"#{field_name}_eq", ->(value) { where(field.eq(value)) }
        scope :"#{field_name}_not_eq", ->(value) { where(field.not_eq(value)) }

        # Presence - skip for string/text types as they get specialized version
        # String types need to check for both nil and empty string
        # Requires boolean parameter: true for present, false for absent
        unless [ :string, :text ].include?(column_type)
          scope :"#{field_name}_present", ->(value) {
            value ? where(field.not_eq(nil)) : where(field.eq(nil))
          }
        end

        scopes_to_register = [ :"#{field_name}_eq", :"#{field_name}_not_eq" ]
        scopes_to_register << :"#{field_name}_present" unless [ :string, :text ].include?(column_type)

        register_predicable_scopes(*scopes_to_register)
      end

      # Generate predicates for string fields (14 scopes).
      #
      # Base predicates (_eq, _not_eq) are defined separately.
      # _present(bool), _blank(bool), _null(bool) handle presence with parameters.
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_string_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # String-specific presence check (checks both nil and empty string)
        # Requires boolean parameter: true for present, false for blank
        scope :"#{field_name}_present", ->(value) {
          value ? where(field.not_eq(nil).and(field.not_eq(""))) : where(field.eq(nil).or(field.eq("")))
        }

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

        # Presence predicates (3) - _present is overridden above for string-specific behavior
        # All require boolean parameter: true for condition, false for negation
        scope :"#{field_name}_blank", ->(value) {
          value ? where(field.eq(nil).or(field.eq(""))) : where(field.not_eq(nil).and(field.not_eq("")))
        }
        scope :"#{field_name}_null", ->(value) {
          value ? where(field.eq(nil)) : where(field.not_eq(nil))
        }

        register_predicable_scopes(
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

      # Generate predicates for numeric fields (11 scopes).
      #
      # Base predicates (_eq, _not_eq, _present(bool)) are defined separately.
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_numeric_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # Comparison (4)
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

        register_predicable_scopes(
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

      # Generate predicates for boolean fields (0 scopes).
      #
      # Base predicates (_eq, _not_eq, _present) are defined separately.
      # Use _eq(true) or _eq(false) for boolean filtering.
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_boolean_predicates(field_name)
        # No additional scopes needed for boolean fields
        # Use field_eq(true) or field_eq(false) instead
      end

      # Generate predicates for PostgreSQL array fields (3 scopes).
      #
      # @param field_name [Symbol] Field name
      # @api private
      #
      # @note This method is not covered by automated tests because it requires
      #   PostgreSQL. Tests run on SQLite for performance.
      #   Test manually on PostgreSQL with: rails console RAILS_ENV=test
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

      # Generate predicates for PostgreSQL JSONB fields (4 scopes).
      #
      # @param field_name [Symbol] Field name
      # @api private
      #
      # @note This method is not covered by automated tests because it requires
      #   PostgreSQL with JSONB support. Tests run on SQLite for performance.
      #   Test manually on PostgreSQL with: rails console RAILS_ENV=test
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

      # Generate predicates for date/datetime fields (11 scopes).
      #
      # Base predicates (_eq, _not_eq, _present(bool)) are defined separately.
      # Date convenience shortcuts removed except _within(duration).
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_date_predicates(field_name)
        table = arel_table
        field = table[field_name]

        # Comparison (4)
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

        # Date convenience - only _within with explicit parameter
        scope :"#{field_name}_within", ->(duration) {
          # Auto-detect: ActiveSupport::Duration or numeric (days)
          time_ago = duration.respond_to?(:ago) ? duration.ago : duration.to_i.days.ago
          where(field.gteq(time_ago))
        }

        # Presence predicates (2) - _present(bool) is defined in base predicates
        # _blank and _null require boolean parameter: true for condition, false for negation
        scope :"#{field_name}_blank", ->(value) {
          value ? where(field.eq(nil)) : where(field.not_eq(nil))
        }
        scope :"#{field_name}_null", ->(value) {
          value ? where(field.eq(nil)) : where(field.not_eq(nil))
        }

        register_predicable_scopes(
          :"#{field_name}_lt",
          :"#{field_name}_lteq",
          :"#{field_name}_gt",
          :"#{field_name}_gteq",
          :"#{field_name}_between",
          :"#{field_name}_not_between",
          :"#{field_name}_in",
          :"#{field_name}_not_in",
          :"#{field_name}_within",
          :"#{field_name}_blank",
          :"#{field_name}_null"
        )
      end

      # Check if database adapter is PostgreSQL.
      #
      # @return [Boolean] true if PostgreSQL adapter
      # @api private
      def postgresql_adapter? = connection.adapter_name.match?(/PostgreSQL/i)
    end
  end
end
