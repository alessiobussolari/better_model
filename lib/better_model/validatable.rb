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
      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Validatable::ConfigurationError, "Invalid configuration"
      end

      # Configurazione validatable (opt-in)
      class_attribute :validatable_enabled, default: false
      class_attribute :validatable_config, default: {}.freeze
      class_attribute :validatable_groups, default: {}.freeze
      class_attribute :_validatable_setup_done, default: false
      # Registry dei complex validations custom
      class_attribute :complex_validations_registry, default: {}.freeze
    end

    class_methods do
      # DSL per attivare e configurare validatable (OPT-IN)
      #
      # @example Attivazione base
      #   validatable do
      #     check :title, presence: true
      #   end
      #
      # @example Con validazioni condizionali
      #   validatable do
      #     check :published_at, presence: true, if: :is_published?
      #   end
      #
      def validatable(&block)
        # Attiva validatable
        self.validatable_enabled = true

        # Configura se passato un blocco
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

      # Verifica se validatable è attivo
      #
      # @return [Boolean]
      def validatable_enabled? = validatable_enabled == true

      # Registra una validazione complessa custom
      #
      # Permette di definire validazioni complesse riutilizzabili che possono combinare
      # più campi o utilizzare logica custom non coperta dalle validazioni standard.
      #
      # @param name [Symbol] il nome della validazione
      # @param block [Proc] il blocco di validazione che verrà eseguito nel contesto dell'istanza
      #
      # @example Validazione complessa base
      #   register_complex_validation :valid_pricing do
      #     if sale_price.present? && sale_price >= price
      #       errors.add(:sale_price, "must be less than regular price")
      #     end
      #   end
      #
      # @example Con logica multi-campo
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

        # Registra nel registry
        self.complex_validations_registry = complex_validations_registry.merge(name.to_sym => block).freeze
      end

      # Verifica se una validazione complessa è stata registrata
      #
      # @param name [Symbol] il nome della validazione
      # @return [Boolean]
      def complex_validation?(name) = complex_validations_registry.key?(name.to_sym)

      private

      # Applica le configurazioni di validazione al modello
      def apply_validatable_config
        return unless validatable_config.present?

        # Apply complex validations
        validatable_config[:complex_validations]&.each do |name|
          apply_complex_validation(name)
        end
      end

      # Applica una validazione complessa
      def apply_complex_validation(name)
        block = complex_validations_registry[name]
        return unless block

        # Crea un validator custom per questa validazione complessa
        validate do
          instance_eval(&block)
        end
      end
    end

    # Metodi di istanza

    # Override valid? per supportare validation groups
    #
    # @param context [Symbol, nil] Context o gruppo di validazione
    # @return [Boolean]
    def valid?(context = nil)
      if context && self.class.validatable_groups.key?(context)
        # Valida solo il gruppo specificato
        validate_group(context)
      else
        # Validazione standard Rails
        super(context)
      end
    end

    # Valida solo un gruppo specifico
    #
    # @param group_name [Symbol] Nome del gruppo
    # @return [Boolean]
    def validate_group(group_name)
      unless self.class.validatable_enabled?
        raise BetterModel::Errors::Validatable::NotEnabledError, "Module is not enabled"
      end

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

    # Ottieni gli errori per un gruppo specifico
    #
    # @param group_name [Symbol] Nome del gruppo
    # @return [ActiveModel::Errors]
    def errors_for_group(group_name)
      unless self.class.validatable_enabled?
        raise BetterModel::Errors::Validatable::NotEnabledError, "Module is not enabled"
      end

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
