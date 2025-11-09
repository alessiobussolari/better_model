# frozen_string_literal: true

require_relative "errors/searchable/searchable_error"
require_relative "errors/searchable/invalid_predicate_error"
require_relative "errors/searchable/invalid_order_error"
require_relative "errors/searchable/invalid_pagination_error"
require_relative "errors/searchable/invalid_security_error"
require_relative "errors/searchable/configuration_error"

# Searchable - Unified search system for Rails models.
#
# This concern orchestrates Predicable and Sortable to provide a complete
# search interface with filters, sorting, and pagination.
#
# @example Basic Usage
#   class Article < ApplicationRecord
#     include BetterModel
#
#     predicates :title, :status, :view_count, :published_at
#     sort :title, :view_count, :published_at
#
#     searchable do
#       per_page 25
#       max_per_page 100
#     end
#   end
#
# @example Search with Filters, Pagination, and Sorting
#   Article.search(
#     { title_cont: "Rails", status_eq: "published" },
#     pagination: { page: 1, per_page: 25 },
#     orders: [:sort_published_at_desc, :sort_title_asc]
#   )
#
module BetterModel
  module Searchable
    extend ActiveSupport::Concern


    included do
      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Searchable::ConfigurationError.new(
          reason: "BetterModel::Searchable can only be included in ActiveRecord models",
          model_class: self,
          expected: "ActiveRecord::Base descendant",
          provided: ancestors.first.to_s
        )
      end

      # Configuration registry
      class_attribute :searchable_config, default: {
        default_order: nil,
        per_page: nil,
        max_per_page: nil,
        securities: {}
      }.freeze
    end

    class_methods do
      # Main search interface.
      #
      # Provides a unified search interface combining predicates (filters),
      # sorting, and pagination with support for OR conditions and security policies.
      #
      # @param predicates [Hash] Filter conditions (uses Predicable scopes)
      # @option predicates [Array<Hash>] :or OR conditions
      # @param pagination [Hash] Pagination parameters (optional)
      # @option pagination [Integer] :page Page number
      # @option pagination [Integer] :per_page Results per page
      # @param orders [Array<Symbol>] Array of sortable scope symbols (optional)
      # @param security [Symbol] Security policy name (optional)
      # @param includes [Array, Symbol] Associations to eager load with LEFT OUTER JOIN
      # @param preload [Array, Symbol] Associations to preload with separate queries
      # @param eager_load [Array, Symbol] Associations to eager load (forces LEFT OUTER JOIN)
      #
      # @return [ActiveRecord::Relation] Chainable relation
      #
      # @example Basic search
      #   Article.search({ title_cont: "Rails" })
      #
      # @example With pagination and sorting
      #   Article.search(
      #     { title_cont: "Rails", status_eq: "published" },
      #     pagination: { page: 1, per_page: 25 },
      #     orders: [:sort_published_at_desc]
      #   )
      #
      # @example With OR conditions
      #   Article.search(
      #     {
      #       or: [
      #         { title_cont: "Rails" },
      #         { title_cont: "Ruby" }
      #       ],
      #       status_eq: "published"
      #     },
      #     orders: [:sort_view_count_desc]
      #   )
      #
      def search(predicates = {}, **options)
        # Extract and validate keyword arguments
        pagination = options.delete(:pagination)
        orders = options.delete(:orders)
        security = options.delete(:security)
        includes_param = options.delete(:includes)
        preload_param = options.delete(:preload)
        eager_load_param = options.delete(:eager_load)

        # If there are remaining unknown options, they might be misplaced predicates
        if options.any?
          raise BetterModel::Errors::Searchable::ConfigurationError.new(
            reason: "Unknown keyword arguments: #{options.keys.join(', ')}. Did you mean to pass predicates as a hash? Use: search({#{options.keys.first}: ...})",
            model_class: self,
            provided: options.keys.to_s
          )
        end

        # Sanitize predicates
        predicates = sanitize_predicates(predicates)

        # Extract OR conditions from predicates hash
        or_conditions = predicates.delete(:or)

        # Validate query complexity limits to prevent DoS attacks
        validate_query_complexity(predicates, or_conditions)

        # Validate security if specified
        # Valida sia i predicati AND che quelli dentro le condizioni OR
        if security.present?
          validate_security(security, predicates)
          validate_security_in_or_conditions(security, or_conditions) if or_conditions.present?
        end

        # Start with base scope
        scope = all

        # Apply AND predicates
        scope = apply_predicates(scope, predicates) if predicates.any?

        # Apply OR conditions
        scope = apply_or_conditions(scope, or_conditions) if or_conditions.present?

        # Apply orders: use provided orders, or fall back to default_order
        if orders.present?
          scope = apply_orders(scope, orders)
        elsif searchable_config[:default_order].present?
          scope = apply_orders(scope, searchable_config[:default_order])
        end

        # Apply pagination
        scope = apply_pagination(scope, pagination) if pagination.present?

        # Apply eager loading associations
        scope = apply_includes(scope, includes_param) if includes_param.present?
        scope = apply_preload(scope, preload_param) if preload_param.present?
        scope = apply_eager_load(scope, eager_load_param) if eager_load_param.present?

        scope
      end

      # DSL to configure searchable.
      #
      # @yield [configurator] Configuration block
      #
      # @example
      #   searchable do
      #     per_page 25
      #     max_per_page 100
      #   end
      def searchable(&block)
        configurator = SearchableConfigurator.new(self)
        configurator.instance_eval(&block)
        self.searchable_config = configurator.to_h.freeze
      end

      # Check if a field is searchable (predicable).
      #
      # @param field_name [Symbol] Field name to check
      # @return [Boolean] true if field is searchable
      def searchable_field?(field_name) = respond_to?(:predicable_field?) && predicable_field?(field_name)

      # Returns all searchable (predicable) fields.
      #
      # @return [Set<Symbol>] Set of searchable field names
      def searchable_fields = respond_to?(:predicable_fields) ? predicable_fields : Set.new

      # Returns available predicates for a field.
      #
      # @param field_name [Symbol] Field name
      # @return [Array<Symbol>] Array of available predicates
      #
      # @example
      #   Article.searchable_predicates_for(:title)
      #   # => [:eq, :not_eq, :cont, :i_cont, :start, :end, ...]
      def searchable_predicates_for(field_name)
        return [] unless searchable_field?(field_name)
        return [] unless respond_to?(:predicable_scopes)

        predicable_scopes
          .select { |scope| scope.to_s.start_with?("#{field_name}_") }
          .map { |scope| scope.to_s.delete_prefix("#{field_name}_").to_sym }
      end

      # Returns available sorts for a field.
      #
      # @param field_name [Symbol] Field name
      # @return [Array<Symbol>] Array of available sortable scopes
      #
      # @example
      #   Article.searchable_sorts_for(:title)
      #   # => [:sort_title_asc, :sort_title_desc, :sort_title_asc_i, :sort_title_desc_i]
      def searchable_sorts_for(field_name)
        return [] unless respond_to?(:sortable_field?) && sortable_field?(field_name)
        return [] unless respond_to?(:sortable_scopes)

        sortable_scopes
          .select { |scope| scope.to_s.start_with?("sort_#{field_name}_") }
      end

      private

      # Sanitize and normalize predicate parameters.
      #
      # @param predicates [Hash, ActionController::Parameters] Predicates to sanitize
      # @return [Hash] Sanitized predicates hash
      # @api private
      #
      # @note Does not use to_unsafe_h for security. If passing ActionController::Parameters,
      #   you must call .permit! or .to_h explicitly in your controller before passing here.
      def sanitize_predicates(predicates)
        return {} if predicates.nil?

        # Se è un ActionController::Parameters, converti a hash
        # Ma richiedi che sia già stato permesso (non bypassa strong parameters)
        if defined?(ActionController::Parameters) && predicates.is_a?(ActionController::Parameters)
          unless predicates.permitted?
            raise BetterModel::Errors::Searchable::ConfigurationError.new(
              reason: "ActionController::Parameters must be explicitly permitted before passing to search. Use .permit! or .to_h in your controller.",
              model_class: self,
              expected: "permitted ActionController::Parameters",
              provided: "unpermitted ActionController::Parameters"
            )
          end
          predicates = predicates.to_h
        end

        predicates.deep_symbolize_keys
      end

      # Applica predicati AND
      def apply_predicates(scope, predicates)
        predicates.each do |predicate_scope, value|
          # Validate scope exists
          unless respond_to?(:predicable_scope?) && predicable_scope?(predicate_scope)
            raise BetterModel::Errors::Searchable::InvalidPredicateError.new(
              predicate_scope: predicate_scope,
              value: value,
              available_predicates: predicable_scopes.to_a,
              model_class: self
            )
          end

          # Skip nil/blank values (but not false)
          next if value.nil?
          next if value.respond_to?(:empty?) && value.empty?

          # Apply scope
          scope = if value == true || value == "true"
            # All predicates require parameters, pass true
            scope.public_send(predicate_scope, true)
          elsif value.is_a?(Array)
            # Splat array values for predicates like _between that expect multiple args
            scope.public_send(predicate_scope, *value)
          else
            scope.public_send(predicate_scope, value)
          end
        end

        scope
      end

      # Applica condizioni OR
      def apply_or_conditions(scope, or_conditions_array)
        # Build OR query usando Arel
        or_relation = or_conditions_array.map do |condition_hash|
          temp_scope = all
          condition_hash.symbolize_keys.each do |predicate_scope, value|
            unless respond_to?(:predicable_scope?) && predicable_scope?(predicate_scope)
              raise BetterModel::Errors::Searchable::InvalidPredicateError.new(
                predicate_scope: predicate_scope,
                value: value,
                available_predicates: predicable_scopes.to_a,
                model_class: self
              )
            end

            temp_scope = if value == true || value == "true"
              temp_scope.public_send(predicate_scope, true)
            elsif value.is_a?(Array)
              # Splat array values for predicates like _between that expect multiple args
              temp_scope.public_send(predicate_scope, *value)
            else
              temp_scope.public_send(predicate_scope, value)
            end
          end
          temp_scope
        end.reduce { |union, condition| union.or(condition) }

        scope.merge(or_relation)
      end

      # Applica ordinamenti
      def apply_orders(scope, orders_array)
        Array(orders_array).each do |order_scope|
          order_scope = order_scope.to_sym

          # Validate scope exists
          unless respond_to?(:sortable_scope?) && sortable_scope?(order_scope)
            raise BetterModel::Errors::Searchable::InvalidOrderError.new(
              order_scope: order_scope,
              available_sorts: sortable_scopes.to_a,
              model_class: self
            )
          end

          # Apply scope
          scope = scope.public_send(order_scope)
        end

        scope
      end

      # Applica paginazione
      def apply_pagination(scope, pagination_params)
        page = pagination_params[:page]&.to_i || 1
        per_page = pagination_params[:per_page]&.to_i

        # Validate page >= 1 (always, even without per_page)
        if page < 1
          raise BetterModel::Errors::Searchable::InvalidPaginationError.new(
            parameter_name: "page",
            value: page,
            valid_range: { min: 1 },
            reason: "page must be >= 1"
          )
        end

        # DoS protection: limita il numero massimo di pagina per evitare offset enormi
        # Default 10000, configurabile tramite searchable config
        max_page = searchable_config[:max_page] || 10_000
        if page > max_page
          raise BetterModel::Errors::Searchable::InvalidPaginationError.new(
            parameter_name: "page",
            value: page,
            valid_range: { max: max_page },
            reason: "page must be <= #{max_page} (DoS protection). Configure max_page in searchable block to change this limit."
          )
        end

        # If per_page is not provided, return scope without LIMIT
        return scope if per_page.nil?

        # Validate per_page >= 1
        if per_page < 1
          raise BetterModel::Errors::Searchable::InvalidPaginationError.new(
            parameter_name: "per_page",
            value: per_page,
            valid_range: { min: 1 },
            reason: "per_page must be >= 1"
          )
        end

        # Respect max_per_page limit if configured
        if searchable_config[:max_per_page].present?
          per_page = [ per_page, searchable_config[:max_per_page] ].min
        end

        offset = (page - 1) * per_page
        scope.limit(per_page).offset(offset)
      end

      # Applica includes per eager loading delle associazioni (usa LEFT OUTER JOIN)
      def apply_includes(scope, includes_param)
        return scope if includes_param.blank?
        scope.includes(includes_param)
      end

      # Applica preload per eager loading delle associazioni (carica con query separate)
      def apply_preload(scope, preload_param)
        return scope if preload_param.blank?
        scope.preload(preload_param)
      end

      # Applica eager_load per eager loading delle associazioni (forza LEFT OUTER JOIN)
      def apply_eager_load(scope, eager_load_param)
        return scope if eager_load_param.blank?
        scope.eager_load(eager_load_param)
      end

      # Valida che i predicati obbligatori della security siano presenti con valori validi
      def validate_security(security_name, predicates)
        # Converti security_name a symbol
        security_name = security_name.to_sym

        # Verifica che la security esista nella configurazione
        securities_config = searchable_config[:securities] || {}

        unless securities_config.key?(security_name)
          raise BetterModel::Errors::Searchable::InvalidSecurityError.new(
            policy_name: security_name.to_s,
            requested_value: security_name.to_s,
            violations: ["Unknown security policy: #{security_name}. Available securities: #{securities_config.keys.join(', ')}"],
            model_class: self
          )
        end

        # Ottieni i predicati obbligatori per questa security
        required_predicates = securities_config[security_name]

        # Verifica che tutti i predicati obbligatori siano presenti CON valori validi
        missing_or_blank = required_predicates.reject do |pred|
          value = predicates[pred]
          # Il predicato deve esistere, non essere nil, e non essere empty
          predicates.key?(pred) &&
          !value.nil? &&
          !(value.respond_to?(:empty?) && value.empty?)
        end

        if missing_or_blank.any?
          raise BetterModel::Errors::Searchable::InvalidSecurityError.new(
            policy_name: security_name.to_s,
            violations: missing_or_blank.map(&:to_s),
            requested_value: predicates.to_s,
            model_class: self
          )
        end
      end

      # Valida che le condizioni OR rispettino i requisiti di security
      # Le condizioni OR non devono permettere di bypassare le regole di security
      def validate_security_in_or_conditions(security_name, or_conditions_array)
        return if or_conditions_array.blank?

        # Verifica che la security esista nella configurazione
        securities_config = searchable_config[:securities] || {}

        unless securities_config.key?(security_name)
          raise BetterModel::Errors::Searchable::InvalidSecurityError.new(
            policy_name: security_name.to_s,
            requested_value: security_name.to_s,
            violations: ["Unknown security policy: #{security_name}. Available securities: #{securities_config.keys.join(', ')}"],
            model_class: self
          )
        end

        # Ottieni i predicati obbligatori per questa security
        required_predicates = securities_config[security_name]

        # Valida ogni condizione OR
        or_conditions_array.each_with_index do |condition_hash, index|
          condition_hash = condition_hash.deep_symbolize_keys

          # Verifica che tutti i predicati obbligatori siano presenti in questa condizione OR
          missing_or_blank = required_predicates.reject do |pred|
            value = condition_hash[pred]
            # Il predicato deve esistere, non essere nil, e non essere empty
            condition_hash.key?(pred) &&
            !value.nil? &&
            !(value.respond_to?(:empty?) && value.empty?)
          end

          if missing_or_blank.any?
            raise BetterModel::Errors::Searchable::InvalidSecurityError.new(
              policy_name: "#{security_name} (OR condition ##{index + 1})",
              violations: missing_or_blank.map(&:to_s),
              requested_value: condition_hash.to_s,
              model_class: self
            )
          end
        end
      end

      # Valida la complessità della query per prevenire attacchi DoS
      def validate_query_complexity(predicates, or_conditions)
        # Limita il numero totale di predicati (default 100, configurabile)
        max_predicates = searchable_config[:max_predicates] || 100
        total_predicates = predicates.size

        if total_predicates > max_predicates
          raise BetterModel::Errors::Searchable::ConfigurationError.new(
            reason: "Query too complex: #{total_predicates} predicates exceeds maximum of #{max_predicates}. Configure max_predicates in searchable block to change this limit.",
            model_class: self,
            expected: "max #{max_predicates} predicates",
            provided: "#{total_predicates} predicates"
          )
        end

        # Limita il numero di condizioni OR (default 50, configurabile)
        return unless or_conditions.present?

        max_or_conditions = searchable_config[:max_or_conditions] || 50
        or_count = Array(or_conditions).size

        if or_count > max_or_conditions
          raise BetterModel::Errors::Searchable::ConfigurationError.new(
            reason: "Query too complex: #{or_count} OR conditions exceeds maximum of #{max_or_conditions}. Configure max_or_conditions in searchable block to change this limit.",
            model_class: self,
            expected: "max #{max_or_conditions} OR conditions",
            provided: "#{or_count} OR conditions"
          )
        end

        # Conta anche i predicati dentro ogni condizione OR
        or_predicates_count = Array(or_conditions).sum { |cond| cond.size }
        total_with_or = total_predicates + or_predicates_count

        if total_with_or > max_predicates
          raise BetterModel::Errors::Searchable::ConfigurationError.new(
            reason: "Query too complex: #{total_with_or} total predicates (including OR conditions) exceeds maximum of #{max_predicates}. Configure max_predicates in searchable block to change this limit.",
            model_class: self,
            expected: "max #{max_predicates} total predicates",
            provided: "#{total_with_or} total predicates"
          )
        end
      end
    end

    # Instance Methods

    # Returns search metadata for this record.
    #
    # @return [Hash] Hash with information about searchable and sortable fields
    #
    # @example
    #   article.search_metadata
    #   # => {
    #   #   searchable_fields: [:title, :status, ...],
    #   #   sortable_fields: [:title, :view_count, ...],
    #   #   available_predicates: { title: [:eq, :cont, ...], ... },
    #   #   available_sorts: { title: [:sort_title_asc, ...], ... },
    #   #   pagination: { per_page: 25, max_per_page: 100 }
    #   # }
    def search_metadata
      {
        searchable_fields: self.class.searchable_fields.to_a,
        sortable_fields: self.class.respond_to?(:sortable_fields) ? self.class.sortable_fields.to_a : [],
        available_predicates: self.class.searchable_fields.each_with_object({}) do |field, hash|
          hash[field] = self.class.searchable_predicates_for(field)
        end,
        available_sorts: (self.class.respond_to?(:sortable_fields) ? self.class.sortable_fields : []).each_with_object({}) do |field, hash|
          hash[field] = self.class.searchable_sorts_for(field)
        end,
        pagination: {
          per_page: self.class.searchable_config[:per_page],
          max_per_page: self.class.searchable_config[:max_per_page]
        }
      }
    end
  end

  # Internal configurator for searchable DSL
  class SearchableConfigurator
    attr_reader :config

    def initialize(model_class)
      @model_class = model_class
      @config = {
        default_order: nil,
        per_page: nil,
        max_per_page: nil,
        max_page: nil,
        max_predicates: nil,
        max_or_conditions: nil,
        securities: {}
      }
    end

    def default_order(order_scopes)
      order_scopes = Array(order_scopes)
      @config[:default_order] = order_scopes.map(&:to_sym)
    end

    def per_page(count)
      @config[:per_page] = count.to_i
    end

    def max_per_page(count)
      @config[:max_per_page] = count.to_i
    end

    # DoS protection: limite massimo numero di pagina (default 10000)
    def max_page(count)
      @config[:max_page] = count.to_i
    end

    # DoS protection: limite massimo numero di predicati totali (default 100)
    def max_predicates(count)
      @config[:max_predicates] = count.to_i
    end

    # DoS protection: limite massimo numero di condizioni OR (default 50)
    def max_or_conditions(count)
      @config[:max_or_conditions] = count.to_i
    end

    def security(name, predicates_array = nil)
      name = name.to_sym

      # Check if predicates_array is provided
      if predicates_array.nil?
        raise BetterModel::Errors::Searchable::ConfigurationError.new(
          reason: "Security :#{name} requires predicates to be specified",
          model_class: @model_class,
          expected: "predicates_array argument",
          provided: "nil"
        )
      end

      predicates_array = Array(predicates_array).map(&:to_sym)

      # Valida che i predicati richiesti siano simboli validi
      if predicates_array.empty?
        raise BetterModel::Errors::Searchable::ConfigurationError.new(
          reason: "Security :#{name} must have at least one required predicate",
          model_class: @model_class,
          expected: "at least one predicate",
          provided: "empty array"
        )
      end

      @config[:securities][name] = predicates_array
    end

    def to_h
      @config
    end
  end
end
