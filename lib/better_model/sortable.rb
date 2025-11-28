# frozen_string_literal: true

require_relative "errors/sortable/sortable_error"
require_relative "errors/sortable/configuration_error"

# Sortable - Declarative sorting system for Rails models.
#
# This concern enables defining sorts on models using a simple, declarative DSL
# that automatically generates scopes based on column type.
#
# @example Basic Usage
#   class Article < ApplicationRecord
#     include BetterModel::Sortable
#
#     sort :title, :view_count, :published_at
#   end
#
# @example Generated Scopes
#   Article.sort_title_asc                    # ORDER BY title ASC
#   Article.sort_title_desc_i                 # ORDER BY LOWER(title) DESC
#   Article.sort_view_count_desc_nulls_last   # ORDER BY view_count DESC NULLS LAST
#   Article.sort_published_at_newest          # ORDER BY published_at DESC
#
module BetterModel
  module Sortable
    extend ActiveSupport::Concern

    included do
      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Sortable::ConfigurationError, "BetterModel::Sortable can only be included in ActiveRecord models"
      end

      # Registry of sortable fields defined for this class
      class_attribute :sortable_fields, default: Set.new
      # Registry of generated sortable scopes
      class_attribute :sortable_scopes, default: Set.new
      # Registry of custom complex sorts
      class_attribute :complex_sorts_registry, default: {}.freeze
    end

    class_methods do
      # DSL to define sortable fields.
      #
      # Automatically generates sorting scopes based on column type:
      # - String: _asc, _desc, _asc_i, _desc_i (case-insensitive)
      # - Numeric: _asc, _desc, _asc_nulls_last, _desc_nulls_last, etc.
      # - Date: _asc, _desc, _newest, _oldest
      #
      # @param field_names [Array<Symbol>] Field names to make sortable
      #
      # @example
      #   sort :title, :view_count, :published_at
      def sort(*field_names)
        field_names.each do |field_name|
          validate_sortable_field!(field_name)
          register_sortable_field(field_name)

          # Skip scope generation if table doesn't exist (allows eager loading before migrations)
          next unless table_exists?

          # Auto-detect type and generate appropriate scopes
          column = columns_hash[field_name.to_s]
          next unless column

          case column.type
          when :string, :text
            define_string_sorting(field_name)
          when :integer, :decimal, :float, :bigint
            define_numeric_sorting(field_name)
          when :date, :datetime, :time, :timestamp
            define_date_sorting(field_name)
          else
            # Default: genera solo scope base
            define_base_sorting(field_name)
          end
        end
      end

      # Register a custom complex sort.
      #
      # Allows defining complex sorts that combine multiple fields
      # or use custom logic not covered by standard sorts.
      #
      # @param name [Symbol] Sort name (will be prefixed with sort_)
      # @yield Sort implementation block
      # @raise [BetterModel::Errors::Sortable::ConfigurationError] If block is not provided
      #
      # @example Multi-field sort
      #   register_complex_sort :by_popularity do
      #     order(view_count: :desc, published_at: :desc)
      #   end
      #
      #   Article.sort_by_popularity
      #
      # @example Parametrized sort
      #   register_complex_sort :by_relevance do |keyword|
      #     order(Arel.sql("CASE WHEN title ILIKE '%#{sanitize_sql_like(keyword)}%' THEN 1 ELSE 2 END"))
      #   end
      #
      #   Article.sort_by_relevance('rails')
      def register_complex_sort(name, &block)
        unless block_given?
          raise BetterModel::Errors::Sortable::ConfigurationError, "Block required for complex sort"
        end

        # Register in registry
        self.complex_sorts_registry = complex_sorts_registry.merge(name.to_sym => block).freeze

        # Define scope
        scope :"sort_#{name}", block

        # Register scope
        register_sortable_scopes(:"sort_#{name}")
      end

      # Check if a field has been registered as sortable.
      #
      # @param field_name [Symbol] Field name to check
      # @return [Boolean] true if field is sortable
      #
      # @example
      #   Article.sortable_field?(:title)  # => true
      def sortable_field?(field_name) = sortable_fields.include?(field_name.to_sym)

      # Check if a sortable scope has been generated.
      #
      # @param scope_name [Symbol] Scope name to check
      # @return [Boolean] true if scope exists
      #
      # @example
      #   Article.sortable_scope?(:sort_title_asc)  # => true
      def sortable_scope?(scope_name) = sortable_scopes.include?(scope_name.to_sym)

      # Check if a complex sort has been registered.
      #
      # @param name [Symbol] Sort name to check
      # @return [Boolean] true if complex sort exists
      #
      # @example
      #   Article.complex_sort?(:by_popularity)  # => true
      def complex_sort?(name) = complex_sorts_registry.key?(name.to_sym)

      private

      # Validate that field exists in table.
      #
      # @param field_name [Symbol] Field name to validate
      # @raise [BetterModel::Errors::Sortable::ConfigurationError] If field doesn't exist
      # @api private
      def validate_sortable_field!(field_name)
        # Skip validation if table doesn't exist (allows eager loading before migrations)
        return unless table_exists?

        unless column_names.include?(field_name.to_s)
          raise BetterModel::Errors::Sortable::ConfigurationError, "Invalid field name: #{field_name}. Field does not exist in #{table_name}"
        end
      end

      # Register a field in sortable_fields registry.
      #
      # @param field_name [Symbol] Field name to register
      # @api private
      def register_sortable_field(field_name)
        self.sortable_fields = (sortable_fields + [ field_name.to_sym ]).to_set.freeze
      end

      # Register scopes in sortable_scopes registry.
      #
      # @param scope_names [Array<Symbol>] Scope names to register
      # @api private
      def register_sortable_scopes(*scope_names)
        self.sortable_scopes = (sortable_scopes + scope_names.map(&:to_sym)).to_set.freeze
      end

      # Generate base sorting scopes: sort_field_asc and sort_field_desc.
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_base_sorting(field_name)
        quoted_field = connection.quote_column_name(field_name)

        scope :"sort_#{field_name}_asc", -> { order(Arel.sql("#{quoted_field} ASC")) }
        scope :"sort_#{field_name}_desc", -> { order(Arel.sql("#{quoted_field} DESC")) }

        register_sortable_scopes(
          :"sort_#{field_name}_asc",
          :"sort_#{field_name}_desc"
        )
      end

      # Generate sorting scopes for string fields (includes case-insensitive).
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_string_sorting(field_name)
        quoted_field = connection.quote_column_name(field_name)

        # Scope base
        scope :"sort_#{field_name}_asc", -> { order(Arel.sql("#{quoted_field} ASC")) }
        scope :"sort_#{field_name}_desc", -> { order(Arel.sql("#{quoted_field} DESC")) }

        # Scope case-insensitive
        scope :"sort_#{field_name}_asc_i", -> { order(Arel.sql("LOWER(#{quoted_field}) ASC")) }
        scope :"sort_#{field_name}_desc_i", -> { order(Arel.sql("LOWER(#{quoted_field}) DESC")) }

        register_sortable_scopes(
          :"sort_#{field_name}_asc",
          :"sort_#{field_name}_desc",
          :"sort_#{field_name}_asc_i",
          :"sort_#{field_name}_desc_i"
        )
      end

      # Generate sorting scopes for numeric fields (includes NULL handling).
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_numeric_sorting(field_name)
        quoted_field = connection.quote_column_name(field_name)

        # Base scopes
        scope :"sort_#{field_name}_asc", -> { order(Arel.sql("#{quoted_field} ASC")) }
        scope :"sort_#{field_name}_desc", -> { order(Arel.sql("#{quoted_field} DESC")) }

        # Pre-calculate SQL for NULL handling (necessary because scope doesn't have access to private methods)
        sql_asc_nulls_last = nulls_order_sql(field_name, "ASC", "LAST")
        sql_desc_nulls_last = nulls_order_sql(field_name, "DESC", "LAST")
        sql_asc_nulls_first = nulls_order_sql(field_name, "ASC", "FIRST")
        sql_desc_nulls_first = nulls_order_sql(field_name, "DESC", "FIRST")

        # Scopes with NULL handling
        scope :"sort_#{field_name}_asc_nulls_last", -> {
          order(Arel.sql(sql_asc_nulls_last))
        }
        scope :"sort_#{field_name}_desc_nulls_last", -> {
          order(Arel.sql(sql_desc_nulls_last))
        }
        scope :"sort_#{field_name}_asc_nulls_first", -> {
          order(Arel.sql(sql_asc_nulls_first))
        }
        scope :"sort_#{field_name}_desc_nulls_first", -> {
          order(Arel.sql(sql_desc_nulls_first))
        }

        register_sortable_scopes(
          :"sort_#{field_name}_asc",
          :"sort_#{field_name}_desc",
          :"sort_#{field_name}_asc_nulls_last",
          :"sort_#{field_name}_desc_nulls_last",
          :"sort_#{field_name}_asc_nulls_first",
          :"sort_#{field_name}_desc_nulls_first"
        )
      end

      # Generate sorting scopes for date/datetime fields (includes semantic shortcuts).
      #
      # @param field_name [Symbol] Field name
      # @api private
      def define_date_sorting(field_name)
        quoted_field = connection.quote_column_name(field_name)

        # Base scopes
        scope :"sort_#{field_name}_asc", -> { order(Arel.sql("#{quoted_field} ASC")) }
        scope :"sort_#{field_name}_desc", -> { order(Arel.sql("#{quoted_field} DESC")) }

        # Semantic shortcuts
        scope :"sort_#{field_name}_newest", -> { order(Arel.sql("#{quoted_field} DESC")) }
        scope :"sort_#{field_name}_oldest", -> { order(Arel.sql("#{quoted_field} ASC")) }

        register_sortable_scopes(
          :"sort_#{field_name}_asc",
          :"sort_#{field_name}_desc",
          :"sort_#{field_name}_newest",
          :"sort_#{field_name}_oldest"
        )
      end

      # Generate SQL for NULL handling across different databases.
      #
      # @param field_name [Symbol] Field name
      # @param direction [String] Sort direction ('ASC' or 'DESC')
      # @param nulls_position [String] NULL position ('FIRST' or 'LAST')
      # @return [String] SQL ORDER BY clause
      # @api private
      #
      # @note The MySQL/MariaDB else block is not covered by automated tests
      #   because tests run on SQLite. Test manually on MySQL with: rails console RAILS_ENV=test
      def nulls_order_sql(field_name, direction, nulls_position)
        quoted_field = connection.quote_column_name(field_name)

        # PostgreSQL and SQLite 3.30+ support NULLS LAST/FIRST natively
        if connection.adapter_name.match?(/PostgreSQL|SQLite/)
          "#{quoted_field} #{direction} NULLS #{nulls_position}"
        else
          # MySQL/MariaDB: emulate with CASE
          if nulls_position == "LAST"
            "CASE WHEN #{quoted_field} IS NULL THEN 1 ELSE 0 END, #{quoted_field} #{direction}"
          else # FIRST
            "CASE WHEN #{quoted_field} IS NULL THEN 0 ELSE 1 END, #{quoted_field} #{direction}"
          end
        end
      end
    end

    # Instance Methods

    # Returns list of sortable attributes (excludes sensitive fields).
    #
    # Automatically filters out password and encrypted fields for security.
    #
    # @return [Array<String>] Sortable attribute names
    #
    # @example
    #   article.sortable_attributes
    #   # => ["id", "title", "view_count", "published_at", "created_at", "updated_at"]
    def sortable_attributes
      self.class.column_names.reject do |attr|
        attr.start_with?("password", "encrypted_")
      end
    end
  end
end
