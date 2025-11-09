# frozen_string_literal: true

require_relative "errors/taggable/taggable_error"
require_relative "errors/taggable/configuration_error"

# Taggable - Declarative tag management system for Rails models.
#
# This concern enables managing multiple tags on models using PostgreSQL arrays
# with normalization, validation, and statistics. Search is delegated to Predicable.
#
# @example Basic Usage
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
# @example Managing Tags
#   article.tag_with("ruby", "rails")           # Add tags
#   article.untag("rails")                      # Remove tags
#   article.tag_list = "ruby, rails, tutorial"  # From CSV string
#   article.tagged_with?("ruby")                # => true
#
# @example Searching (Delegated to Predicable)
#   Article.tags_contains("ruby")               # Predicable
#   Article.tags_overlaps(["ruby", "python"])   # Predicable
#   Article.search(tags_contains: "ruby")       # Searchable + Predicable
#
# @example Statistics
#   Article.tag_counts                          # => {"ruby" => 45, "rails" => 38}
#   Article.popular_tags(limit: 10)             # => [["ruby", 45], ["rails", 38], ...]
#
module BetterModel
  module Taggable
    extend ActiveSupport::Concern

    # Taggable Configuration.
    #
    # Internal configuration class for the Taggable DSL.
    #
    # @api private
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
      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Taggable::ConfigurationError.new(
          reason: "BetterModel::Taggable can only be included in ActiveRecord models"
        )
      end

      # Taggable configuration for this class
      class_attribute :taggable_config, default: nil
    end

    class_methods do
      # DSL to configure Taggable.
      #
      # @yield [config] Configuration block
      # @raise [BetterModel::Errors::Taggable::ConfigurationError] If already configured or field doesn't exist
      #
      # @example
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
        # Prevent multiple configuration
        if taggable_config.present?
          raise BetterModel::Errors::Taggable::ConfigurationError.new(
            reason: "Taggable already configured for #{name}",
            model_class: self
          )
        end

        # Create configuration
        config = Configuration.new
        config.instance_eval(&block) if block_given?

        # Validate that field exists
        tag_field_name = config.tag_field.to_s
        unless column_names.include?(tag_field_name)
          raise BetterModel::Errors::Taggable::ConfigurationError.new(
            reason: "Tag field #{config.tag_field} does not exist in #{table_name}",
            model_class: self,
            expected: "valid column name from #{table_name}",
            provided: config.tag_field
          )
        end

        # Save configuration (frozen for thread-safety)
        self.taggable_config = config.freeze

        # Auto-register predicates for search (delegated to Predicable)
        predicates config.tag_field if respond_to?(:predicates)

        # Register validations if configured
        setup_validations(config) if config.validates_minimum || config.validates_maximum ||
                                     config.allowed_tags || config.forbidden_tags
      end

      # ============================================================================
      # CLASS METHODS - Statistics
      # ============================================================================

      # Returns a hash with the count of each tag.
      #
      # @return [Hash{String => Integer}] Tag counts
      #
      # @example
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

      # Returns the most popular tags with their counts.
      #
      # @param limit [Integer] Maximum number of tags to return
      # @return [Array<Array(String, Integer)>] Tag-count pairs sorted by count
      #
      # @example
      #   Article.popular_tags(limit: 10)
      #   # => [["ruby", 45], ["rails", 38], ["tutorial", 12]]
      def popular_tags(limit: 10)
        return [] unless taggable_config

        tag_counts
          .sort_by { |_tag, count| -count }
          .first(limit)
      end

      # Returns tags that appear together with the specified tag.
      #
      # @param tag [String] Tag to find related tags for
      # @param limit [Integer] Maximum number of related tags to return
      # @return [Array<String>] Related tags sorted by frequency
      #
      # @example
      #   Article.related_tags("ruby", limit: 10)
      #   # => ["rails", "gem", "activerecord"]
      def related_tags(tag, limit: 10)
        return [] unless taggable_config

        field = taggable_config.tag_field
        related_counts = Hash.new(0)

        # Normalize query tag
        config = taggable_config
        normalized_tag = tag.to_s
        normalized_tag = normalized_tag.strip if config.strip
        normalized_tag = normalized_tag.downcase if config.normalize

        # Find records containing the tag
        find_each do |record|
          tags = record.public_send(field) || []
          next unless tags.include?(normalized_tag)

          # Count other tags that appear together
          tags.each do |other_tag|
            next if other_tag == normalized_tag
            related_counts[other_tag] += 1
          end
        end

        # Return sorted by frequency
        related_counts
          .sort_by { |_tag, count| -count }
          .first(limit)
          .map(&:first)
      end

      private

      # Setup ActiveRecord validations.
      #
      # @param config [Configuration] Taggable configuration
      # @api private
      def setup_validations(config)
        field = config.tag_field

        # Minimum validation
        if config.validates_minimum
          min = config.validates_minimum
          validate do
            tags = public_send(field) || []
            if tags.size < min
              errors.add(field, "must have at least #{min} tags")
            end
          end
        end

        # Maximum validation
        if config.validates_maximum
          max = config.validates_maximum
          validate do
            tags = public_send(field) || []
            if tags.size > max
              errors.add(field, "must have at most #{max} tags")
            end
          end
        end

        # Whitelist validation
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

        # Blacklist validation
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
    # INSTANCE METHODS - Tag Management
    # ============================================================================

    # Add one or more tags to the record.
    #
    # @param new_tags [Array<String>] Tags to add
    # @return [void]
    #
    # @example
    #   article.tag_with("ruby")
    #   article.tag_with("ruby", "rails", "tutorial")
    def tag_with(*new_tags)
      return unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field

      # Initialize array if nil
      current_tags = public_send(field) || []

      # Normalize and add tags (avoid duplicates with |)
      normalized_tags = new_tags.flatten.map { |tag| normalize_tag(tag) }.compact
      updated_tags = (current_tags | normalized_tags)

      # Update field
      public_send("#{field}=", updated_tags)
      save if persisted?
    end

    # Remove one or more tags from the record.
    #
    # @param tags_to_remove [Array<String>] Tags to remove
    # @return [void]
    #
    # @example
    #   article.untag("tutorial")
    #   article.untag("ruby", "rails")
    def untag(*tags_to_remove)
      return unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field

      # Get current tags
      current_tags = public_send(field) || []

      # Normalize tags to remove
      normalized_tags = tags_to_remove.flatten.map { |tag| normalize_tag(tag) }.compact

      # Remove tags
      updated_tags = current_tags - normalized_tags

      # Update field
      public_send("#{field}=", updated_tags)
      save if persisted?
    end

    # Replace all existing tags with new tags.
    #
    # @param new_tags [Array<String>] New tags to set
    # @return [void]
    #
    # @example
    #   article.retag("python", "django")
    def retag(*new_tags)
      return unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field

      # Normalize new tags
      normalized_tags = new_tags.flatten.map { |tag| normalize_tag(tag) }.compact.uniq

      # Replace all tags
      public_send("#{field}=", normalized_tags)
      save if persisted?
    end

    # Check if record has a specific tag.
    #
    # @param tag [String] Tag to check
    # @return [Boolean] true if record has the tag
    #
    # @example
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

    # Returns tags as a delimited string.
    #
    # @return [String] Tags joined by delimiter
    #
    # @example
    #   article.tag_list  # => "ruby, rails, tutorial"
    def tag_list
      return "" unless taggable_enabled?

      config = self.class.taggable_config
      field = config.tag_field
      delimiter = config.delimiter

      current_tags = public_send(field) || []

      # Add space after comma for readability (only if delimiter is comma)
      separator = delimiter == "," ? "#{delimiter} " : delimiter
      current_tags.join(separator)
    end

    # Set tags from a delimited string.
    #
    # @param tag_string [String] Delimited tag string
    # @return [void]
    #
    # @example
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

    # Override as_json to include tag information.
    #
    # @param options [Hash] Options for as_json
    # @option options [Boolean] :include_tag_list Include tag_list as string
    # @option options [Boolean] :include_tag_stats Include tag statistics
    # @return [Hash] JSON representation
    #
    # @example
    #   article.as_json(include_tag_list: true, include_tag_stats: true)
    def as_json(options = {})
      json = super(options)

      return json unless taggable_enabled?

      # Add tag_list if requested
      if options[:include_tag_list]
        json["tag_list"] = tag_list
      end

      # Add tag statistics if requested
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

    # Check if Taggable is enabled for this class.
    #
    # @return [Boolean] true if enabled
    # @api private
    def taggable_enabled? = self.class.taggable_config.present?

    # Normalize a tag according to configuration.
    #
    # @param tag [String] Tag to normalize
    # @return [String, nil] Normalized tag or nil if invalid
    # @api private
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
