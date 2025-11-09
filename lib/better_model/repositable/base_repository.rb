# frozen_string_literal: true

module BetterModel
  module Repositable
    # Base repository class for implementing the Repository Pattern with BetterModel.
    #
    # Repositories encapsulate data access logic and provide a clean interface for querying models.
    # This base class integrates seamlessly with BetterModel's Searchable, Predicable, and Sortable concerns.
    #
    # @example Basic usage
    #   class ArticleRepository < BetterModel::Repositable::BaseRepository
    #     def model_class = Article
    #
    #     def published
    #       search({ status_eq: "published" })
    #     end
    #
    #     def recent(days: 7)
    #       search({ created_at_gteq: days.days.ago })
    #     end
    #   end
    #
    #   repo = ArticleRepository.new
    #   articles = repo.search({ status_eq: "published" }, page: 1, per_page: 20)
    #   article = repo.search({ id_eq: 1 }, limit: 1)
    #
    # @example With BetterModel Searchable
    #   # If your model uses BetterModel::Searchable:
    #   class Article < ApplicationRecord
    #     include BetterModel
    #
    #     predicates :title, :status, :view_count, :published_at
    #     sort :title, :view_count, :published_at
    #   end
    #
    #   # The repository automatically uses the model's search() method
    #   repo = ArticleRepository.new
    #   repo.search({ title_cont: "Rails", view_count_gt: 100 })
    #
    class BaseRepository
      attr_reader :model

      # Initialize a new repository instance.
      #
      # @param model_class [Class] The ActiveRecord model class (optional if model_class method is defined)
      def initialize(model_class = nil)
        @model = model_class || self.class.instance_method(:model_class).bind(self).call
      end

      # Main search method with support for predicates, pagination, ordering, and limits.
      #
      # This method integrates with BetterModel's Searchable concern if available,
      # otherwise falls back to standard ActiveRecord queries.
      #
      # @param predicates [Hash] Filter conditions using BetterModel predicates
      # @param page [Integer] Page number for pagination (default: 1)
      # @param per_page [Integer] Records per page (default: 20)
      # @param includes [Array] Associations to eager load
      # @param joins [Array] Associations to join
      # @param order [String, Hash] SQL order clause
      # @param order_scope [Hash] BetterModel sort scope (e.g., { field: :published_at, direction: :desc })
      # @param limit [Integer, Symbol, nil] Result limit:
      #   - Integer (1): Returns single record (first)
      #   - Integer (2+): Returns limited relation
      #   - nil: Returns all results (no limit)
      #   - :default: Uses pagination (default behavior)
      #
      # @return [ActiveRecord::Relation, ActiveRecord::Base, nil] Query results
      #
      # @example Basic search with predicates
      #   search({ status_eq: "published", view_count_gt: 100 })
      #
      # @example With pagination
      #   search({ status_eq: "published" }, page: 2, per_page: 50)
      #
      # @example Single result
      #   search({ id_eq: 1 }, limit: 1)
      #
      # @example All results (no pagination)
      #   search({ status_eq: "published" }, limit: nil)
      #
      # @example With eager loading
      #   search({ status_eq: "published" }, includes: [:author, :comments])
      #
      # @example With ordering
      #   search({ status_eq: "published" }, order_scope: { field: :published_at, direction: :desc })
      #
      def search(predicates = {}, page: 1, per_page: 20, includes: [], joins: [], order: nil, order_scope: nil,
                 limit: :default)
        # Remove nil values (keep false for boolean predicates)
        cleaned_predicates = (predicates || {}).compact

        # Validate predicates if model supports it
        validate_predicates!(cleaned_predicates) if cleaned_predicates.present?

        # Use BetterModel's search() method if available, otherwise use all
        result = if @model.respond_to?(:search) && cleaned_predicates.present?
                   @model.search(cleaned_predicates)
                 else
                   @model.all
                 end

        # Apply joins BEFORE includes (necessary for ORDER BY on joined tables)
        result = result.joins(*joins) if joins.present?

        # Apply includes if specified
        result = result.includes(*includes) if includes.present?

        # Apply ordering: order_scope has priority over order
        if order_scope.present?
          scope_name = build_scope_name(order_scope)
          result = result.send(scope_name) if result.respond_to?(scope_name)
        elsif order.present?
          result = result.order(order)
        end

        # Apply limit if specified (has priority over pagination)
        case limit
        when 1
          result.first
        when (2..)
          result.limit(limit)
        when nil
          # limit: nil explicitly means unlimited - return all results
          result
        when :default
          # :default means use pagination (this is the default when no limit is specified)
          paginate(result, page: page, per_page: per_page)
        else
          # Fallback to pagination for any other case
          paginate(result, page: page, per_page: per_page)
        end
      end

      # Standard CRUD methods delegated to the model
      delegate :find, to: :@model
      delegate :find_by, to: :@model
      delegate :create, to: :@model
      delegate :create!, to: :@model

      # Build a new model instance with the given attributes.
      #
      # @param attributes [Hash] Model attributes
      # @return [ActiveRecord::Base] New model instance (not persisted)
      def build(attributes = {})
        @model.new(attributes)
      end

      # Update a record by ID.
      #
      # @param id [Integer] Record ID
      # @param attributes [Hash] Attributes to update
      # @return [ActiveRecord::Base] Updated record
      # @raise [ActiveRecord::RecordNotFound] If record not found
      # @raise [ActiveRecord::RecordInvalid] If validation fails
      def update(id, attributes)
        record = find(id)
        record.update!(attributes)
        record
      end

      # Delete a record by ID.
      #
      # @param id [Integer] Record ID
      # @return [ActiveRecord::Base] Deleted record
      # @raise [ActiveRecord::RecordNotFound] If record not found
      def delete(id)
        @model.destroy(id)
      end

      # Base ActiveRecord methods delegated to the model
      delegate :where, to: :@model
      delegate :all, to: :@model
      delegate :count, to: :@model
      delegate :exists?, to: :@model

      private

      # Validate that predicates are supported by the model.
      #
      # If the model includes BetterModel::Predicable, validates against predicable_scope?.
      # Otherwise, checks if the model responds to the predicate method.
      #
      # @param predicates [Hash] Predicates to validate
      def validate_predicates!(predicates)
        predicates.each_key do |predicate|
          # Check if model supports predicable_scope? validation
          if @model.respond_to?(:predicable_scope?)
            next if @model.predicable_scope?(predicate)

            available_list = @model.predicable_scopes.to_a.sort.join(", ")
            Rails.logger.error "Invalid predicate '#{predicate}' for model #{@model.name}. " \
                               "Available: #{available_list}"
          else
            # Fallback to checking if method exists
            next if @model.respond_to?(predicate)

            available_list = available_predicates.join(", ")
            Rails.logger.error "Invalid predicate '#{predicate}' for model #{@model.name}. " \
                               "Available: #{available_list}"
          end
        end
      end

      # Get available predicates for models without BetterModel::Predicable.
      #
      # @return [Array<Symbol>] List of available predicate methods
      def available_predicates
        @model.methods.grep(/_eq$|_cont$|_gteq$|_lteq$|_in$|_not_null$|_null$/).sort
      end

      # Centralized pagination using ActiveRecord offset/limit.
      #
      # @param relation [ActiveRecord::Relation] Relation to paginate
      # @param page [Integer] Page number (1-indexed)
      # @param per_page [Integer] Records per page
      # @return [ActiveRecord::Relation] Paginated relation
      def paginate(relation, page:, per_page:)
        offset_value = (page.to_i - 1) * per_page.to_i
        relation.offset(offset_value).limit(per_page)
      end

      # Build scope name for ordering (e.g., "sort_published_at_desc").
      #
      # @param order_scope [Hash] Hash with :field and :direction keys
      # @return [String] Scope name
      def build_scope_name(order_scope)
        "sort_#{order_scope[:field]}_#{order_scope[:direction]}"
      end
    end
  end
end
