# frozen_string_literal: true

require_relative "errors/validatable/validatable_error"
require_relative "errors/validatable/not_enabled_error"
require_relative "errors/validatable/configuration_error"

# Validatable - Declarative validation system for Rails models.
#
# This concern enables defining validations declaratively and readably,
# with support for conditional validations, groups, cross-field, and business rules.
#
# @note OPT-IN APPROACH
#   Declarative validations are not enabled automatically.
#   You must explicitly call `validatable do...end` in your model.
#
# @example Basic Usage
#   class Article < ApplicationRecord
#     include BetterModel
#
#     # Status (from Statusable)
#     is :draft, -> { status == "draft" }
#     is :published, -> { status == "published" }
#
#     # Register complex validations
#     register_complex_validation :valid_date_range do
#       return if starts_at.blank? || ends_at.blank?
#       errors.add(:starts_at, "must be before end date") if starts_at >= ends_at
#     end
#
#     # Enable validatable (opt-in)
#     validatable do
#       # Basic validations
#       check :title, :content, presence: true
#
#       # Conditional validations (using Rails options)
#       check :published_at, presence: true, if: -> { status == "published" }
#       check :author_id, presence: true, if: :is_published?
#
#       # Complex validations for cross-field and business logic
#       check_complex :valid_date_range
#
#       # Validation groups
#       validation_group :step1, [:email, :password]
#       validation_group :step2, [:first_name, :last_name]
#     end
#   end
#
# @example Validation Usage
#   article.valid?           # All validations
#   article.valid?(:step1)   # Only step1 group
#
module BetterModel
  module Validatable
    extend ActiveSupport::Concern

    included do
      # Include shared enabled check concern
      include BetterModel::Concerns::EnabledCheck

      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Validatable::ConfigurationError, "Invalid configuration"
      end

      # Validatable configuration (opt-in)
      class_attribute :validatable_enabled, default: false
      class_attribute :validatable_config, default: {}.freeze
      class_attribute :validatable_groups, default: {}.freeze
      class_attribute :_validatable_setup_done, default: false
      # Registry for custom complex validations
      class_attribute :complex_validations_registry, default: {}.freeze
    end

    class_methods do
      # DSL to enable and configure validatable (OPT-IN)
      #
      # @example Basic activation
      #   validatable do
      #     check :title, presence: true
      #   end
      #
      # @example With conditional validations
      #   validatable do
      #     check :published_at, presence: true, if: :is_published?
      #   end
      #
      def validatable(&block)
        # Enable validatable
        self.validatable_enabled = true

        # Configure if block provided
        if block_given?
          configurator = Configurator.new(self)
          configurator.instance_eval(&block)
          self.validatable_config = configurator.to_h.freeze
          self.validatable_groups = configurator.groups.freeze
        end

        # Setup validators only once
        return if self._validatable_setup_done

        self._validatable_setup_done = true

        # Apply validators from configuration
        apply_validatable_config
      end

      # Check if validatable is enabled
      #
      # @return [Boolean]
      def validatable_enabled? = validatable_enabled == true

      # Register a custom complex validation
      #
      # Allows defining reusable complex validations that can combine
      # multiple fields or use custom logic not covered by standard validations.
      #
      # @param name [Symbol] the validation name
      # @param block [Proc] the validation block to be executed in the instance context
      #
      # @example Basic complex validation
      #   register_complex_validation :valid_pricing do
      #     if sale_price.present? && sale_price >= price
      #       errors.add(:sale_price, "must be less than regular price")
      #     end
      #   end
      #
      # @example Multi-field logic
      #   register_complex_validation :valid_dates do
      #     if starts_at.present? && ends_at.present? && starts_at >= ends_at
      #       errors.add(:ends_at, "must be after start date")
      #     end
      #   end
      #
      def register_complex_validation(name, &block)
        unless block_given?
          raise BetterModel::Errors::Validatable::ConfigurationError, "Invalid configuration"
        end

        # Register in the registry
        self.complex_validations_registry = complex_validations_registry.merge(name.to_sym => block).freeze
      end

      # Check if a complex validation has been registered
      #
      # @param name [Symbol] the validation name
      # @return [Boolean]
      def complex_validation?(name) = complex_validations_registry.key?(name.to_sym)

      private

      # Apply validation configurations to the model
      def apply_validatable_config
        return unless validatable_config.present?

        # Apply complex validations
        validatable_config[:complex_validations]&.each do |name|
          apply_complex_validation(name)
        end
      end

      # Apply a complex validation
      def apply_complex_validation(name)
        block = complex_validations_registry[name]
        return unless block

        # Create a custom validator for this complex validation
        validate do
          instance_eval(&block)
        end
      end
    end

    # Instance methods

    # Override valid? to support validation groups
    #
    # @param context [Symbol, nil] Context or validation group
    # @return [Boolean]
    def valid?(context = nil)
      if context && self.class.validatable_groups.key?(context)
        # Validate only the specified group
        validate_group(context)
      else
        # Standard Rails validation
        super(context)
      end
    end

    # Validate only a specific group
    #
    # @param group_name [Symbol] Group name
    # @return [Boolean]
    def validate_group(group_name)
      ensure_module_enabled!(:validatable, BetterModel::Errors::Validatable::NotEnabledError)

      group = self.class.validatable_groups[group_name]
      return false unless group

      # Clear existing errors
      errors.clear

      # Run validations only for fields in this group
      group[:fields].each do |field|
        run_validations_for_field(field)
      end

      errors.empty?
    end

    # Get errors for a specific group
    #
    # @param group_name [Symbol] Group name
    # @return [ActiveModel::Errors]
    def errors_for_group(group_name)
      ensure_module_enabled!(:validatable, BetterModel::Errors::Validatable::NotEnabledError)

      group = self.class.validatable_groups[group_name]
      return errors unless group

      # Filter errors to only include fields in this group
      filtered_errors = ActiveModel::Errors.new(self)
      group[:fields].each do |field|
        errors[field].each do |error|
          filtered_errors.add(field, error)
        end
      end

      filtered_errors
    end

    private

    # Run validations for a specific field
    def run_validations_for_field(field)
      # This is a simplified version - Rails validations are complex
      # We'll leverage Rails' built-in validation framework
      self.class.validators_on(field).each do |validator|
        validator.validate(self)
      end
    end
  end
end
