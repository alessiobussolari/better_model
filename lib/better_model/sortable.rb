# frozen_string_literal: true

# Sortable - Sistema di ordinamento dichiarativo per modelli Rails
#
# Questo concern permette di definire ordinamenti sui modelli utilizzando un DSL
# semplice e dichiarativo che genera automaticamente scope basati sul tipo di colonna.
#
# Esempio di utilizzo:
#   class Article < ApplicationRecord
#     include BetterModel::Sortable
#
#     sort :title, :view_count, :published_at
#   end
#
# Utilizzo:
#   Article.sort_title_asc                    # ORDER BY title ASC
#   Article.sort_title_desc_i                 # ORDER BY LOWER(title) DESC
#   Article.sort_view_count_desc_nulls_last   # ORDER BY view_count DESC NULLS LAST
#   Article.sort_published_at_newest          # ORDER BY published_at DESC
#
module BetterModel
  module Sortable
    extend ActiveSupport::Concern

    included do
      # Valida che sia incluso solo in modelli ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Sortable can only be included in ActiveRecord models"
      end

      # Registry dei campi sortable definiti per questa classe
      class_attribute :sortable_fields, default: Set.new
      # Registry degli scope sortable generati
      class_attribute :sortable_scopes, default: Set.new
    end

    class_methods do
      # DSL per definire campi sortable
      #
      # Genera automaticamente scope di ordinamento basati sul tipo di colonna:
      # - String: _asc, _desc, _asc_i, _desc_i (case-insensitive)
      # - Numeric: _asc, _desc, _asc_nulls_last, _desc_nulls_last, etc.
      # - Date: _asc, _desc, _newest, _oldest
      #
      # Esempio:
      #   sort :title, :view_count, :published_at
      def sort(*field_names)
        field_names.each do |field_name|
          validate_sortable_field!(field_name)
          register_sortable_field(field_name)

          # Auto-rileva tipo e genera scope appropriati
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

      # Verifica se un campo è stato registrato come sortable
      def sortable_field?(field_name)
        sortable_fields.include?(field_name.to_sym)
      end

      # Verifica se uno scope sortable è stato generato
      def sortable_scope?(scope_name)
        sortable_scopes.include?(scope_name.to_sym)
      end

      private

      # Valida che il campo esista nella tabella
      def validate_sortable_field!(field_name)
        unless column_names.include?(field_name.to_s)
          raise ArgumentError, "Invalid field name: #{field_name}. Field does not exist in #{table_name}"
        end
      end

      # Registra un campo nel registry sortable_fields
      def register_sortable_field(field_name)
        self.sortable_fields = (sortable_fields + [field_name.to_sym]).to_set.freeze
      end

      # Registra scope nel registry sortable_scopes
      def register_sortable_scopes(*scope_names)
        self.sortable_scopes = (sortable_scopes + scope_names.map(&:to_sym)).to_set.freeze
      end

      # Genera scope base: sort_field_asc e sort_field_desc
      def define_base_sorting(field_name)
        quoted_field = connection.quote_column_name(field_name)

        scope :"sort_#{field_name}_asc", -> { order(Arel.sql("#{quoted_field} ASC")) }
        scope :"sort_#{field_name}_desc", -> { order(Arel.sql("#{quoted_field} DESC")) }

        register_sortable_scopes(
          :"sort_#{field_name}_asc",
          :"sort_#{field_name}_desc"
        )
      end

      # Genera scope per campi stringa (include case-insensitive)
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

      # Genera scope per campi numerici (include gestione NULL)
      def define_numeric_sorting(field_name)
        quoted_field = connection.quote_column_name(field_name)

        # Scope base
        scope :"sort_#{field_name}_asc", -> { order(Arel.sql("#{quoted_field} ASC")) }
        scope :"sort_#{field_name}_desc", -> { order(Arel.sql("#{quoted_field} DESC")) }

        # Pre-calcola SQL per gestione NULL (necessario perché lo scope non ha accesso ai metodi privati)
        sql_asc_nulls_last = nulls_order_sql(field_name, "ASC", "LAST")
        sql_desc_nulls_last = nulls_order_sql(field_name, "DESC", "LAST")
        sql_asc_nulls_first = nulls_order_sql(field_name, "ASC", "FIRST")
        sql_desc_nulls_first = nulls_order_sql(field_name, "DESC", "FIRST")

        # Scope con gestione NULL
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

      # Genera scope per campi data/datetime (include shortcuts semantici)
      def define_date_sorting(field_name)
        quoted_field = connection.quote_column_name(field_name)

        # Scope base
        scope :"sort_#{field_name}_asc", -> { order(Arel.sql("#{quoted_field} ASC")) }
        scope :"sort_#{field_name}_desc", -> { order(Arel.sql("#{quoted_field} DESC")) }

        # Shortcuts semantici
        scope :"sort_#{field_name}_newest", -> { order(Arel.sql("#{quoted_field} DESC")) }
        scope :"sort_#{field_name}_oldest", -> { order(Arel.sql("#{quoted_field} ASC")) }

        register_sortable_scopes(
          :"sort_#{field_name}_asc",
          :"sort_#{field_name}_desc",
          :"sort_#{field_name}_newest",
          :"sort_#{field_name}_oldest"
        )
      end

      # Genera SQL per gestione NULL multi-database
      def nulls_order_sql(field_name, direction, nulls_position)
        quoted_field = connection.quote_column_name(field_name)

        # PostgreSQL e SQLite 3.30+ supportano NULLS LAST/FIRST nativamente
        if connection.adapter_name.match?(/PostgreSQL|SQLite/)
          "#{quoted_field} #{direction} NULLS #{nulls_position}"
        else
          # MySQL/MariaDB: emulazione con CASE
          if nulls_position == "LAST"
            "CASE WHEN #{quoted_field} IS NULL THEN 1 ELSE 0 END, #{quoted_field} #{direction}"
          else # FIRST
            "CASE WHEN #{quoted_field} IS NULL THEN 0 ELSE 1 END, #{quoted_field} #{direction}"
          end
        end
      end
    end

    # Metodi di istanza

    # Ritorna lista di attributi sortable (esclude campi sensibili)
    def sortable_attributes
      self.class.column_names.reject do |attr|
        attr.start_with?("password", "encrypted_")
      end
    end
  end
end
