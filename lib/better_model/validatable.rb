# frozen_string_literal: true

# Validatable - Sistema di validazioni dichiarativo per modelli Rails
#
# Questo concern permette di definire validazioni in modo dichiarativo e leggibile,
# con supporto per validazioni condizionali, gruppi, cross-field e business rules.
#
# APPROCCIO OPT-IN: Le validazioni dichiarative non sono attive automaticamente.
# Devi chiamare esplicitamente `validatable do...end` nel tuo modello.
#
# Esempio di utilizzo:
#   class Article < ApplicationRecord
#     include BetterModel
#
#     # Status (già esistente in Statusable)
#     is :draft, -> { status == "draft" }
#     is :published, -> { status == "published" }
#
#     # Attiva validatable (opt-in)
#     validatable do
#       # Validazioni base
#       validate :title, :content, presence: true
#
#       # Validazioni condizionali
#       validate_if :is_published? do
#         validate :published_at, presence: true
#         validate :author_id, presence: true
#       end
#
#       # Cross-field validations
#       validate_order :starts_at, :before, :ends_at
#
#       # Business rules
#       validate_business_rule :valid_category
#
#       # Gruppi di validazioni
#       validation_group :step1, [:email, :password]
#       validation_group :step2, [:first_name, :last_name]
#     end
#   end
#
# Utilizzo:
#   article.valid?           # Tutte le validazioni
#   article.valid?(:step1)   # Solo gruppo step1
#
module BetterModel
  module Validatable
    extend ActiveSupport::Concern

    included do
      # Validazione ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Validatable can only be included in ActiveRecord models"
      end

      # Configurazione validatable (opt-in)
      class_attribute :validatable_enabled, default: false
      class_attribute :validatable_config, default: {}.freeze
      class_attribute :validatable_groups, default: {}.freeze
      class_attribute :_validatable_setup_done, default: false
    end

    class_methods do
      # DSL per attivare e configurare validatable (OPT-IN)
      #
      # @example Attivazione base
      #   validatable do
      #     validate :title, presence: true
      #   end
      #
      # @example Con validazioni condizionali
      #   validatable do
      #     validate_if :is_published? do
      #       validate :published_at, presence: true
      #     end
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
      def validatable_enabled?
        validatable_enabled == true
      end

      private

      # Applica le configurazioni di validazione al modello
      def apply_validatable_config
        return unless validatable_config.present?

        # Apply conditional validations
        validatable_config[:conditional_validations]&.each do |conditional|
          apply_conditional_validation(conditional)
        end

        # Apply order validations
        validatable_config[:order_validations]&.each do |order_val|
          apply_order_validation(order_val)
        end

        # Apply business rules
        validatable_config[:business_rules]&.each do |rule|
          apply_business_rule(rule)
        end
      end

      # Applica una validazione condizionale
      def apply_conditional_validation(conditional)
        condition = conditional[:condition]
        negate = conditional[:negate]
        validations = conditional[:validations]

        # Create a custom validator for this conditional block
        validate do
          condition_met = if condition.is_a?(Symbol)
                            send(condition)
          elsif condition.is_a?(Proc)
                            instance_exec(&condition)
          else
                            raise ArgumentError, "Condition must be a Symbol or Proc"
          end

          condition_met = !condition_met if negate

          if condition_met
            validations.each do |validation|
              apply_validation_in_context(validation)
            end
          end
        end
      end

      # Applica una validazione order (cross-field)
      def apply_order_validation(order_val)
        validates_with BetterModel::Validatable::OrderValidator,
                       attributes: [ order_val[:first_field] ],
                       second_field: order_val[:second_field],
                       comparator: order_val[:comparator],
                       **order_val[:options]
      end

      # Applica una business rule
      def apply_business_rule(rule)
        validates_with BetterModel::Validatable::BusinessRuleValidator,
                       rule_name: rule[:name],
                       **rule[:options]
      end
    end

    # Metodi di istanza

    # Apply a validation in the context of the current instance
    def apply_validation_in_context(validation)
      fields = validation[:fields]
      options = validation[:options]

      fields.each do |field|
        options.each do |validator_type, validator_options|
          # Prepare validator options
          # If validator_options is true, convert to empty hash
          # If it's a hash, use as-is
          opts = validator_options.is_a?(Hash) ? validator_options : {}

          validator = ActiveModel::Validations.const_get("#{validator_type.to_s.camelize}Validator").new(
            attributes: [ field ],
            **opts
          )
          validator.validate(self)
        end
      end
    end

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
      raise ValidatableNotEnabledError unless self.class.validatable_enabled?

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
      raise ValidatableNotEnabledError unless self.class.validatable_enabled?

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

  # Errori custom
  class ValidatableError < StandardError; end

  class ValidatableNotEnabledError < ValidatableError
    def initialize(msg = nil)
      super(msg || "Validatable is not enabled. Add 'validatable do...end' to your model.")
    end
  end
end
