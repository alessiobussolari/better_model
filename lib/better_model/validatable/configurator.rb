# frozen_string_literal: true

module BetterModel
  module Validatable
    # Configurator per il DSL di Validatable
    #
    # Questo configurator permette di definire validazioni in modo dichiarativo
    # all'interno del blocco `validatable do...end`.
    #
    # Esempio:
    #   validatable do
    #     # Validazioni base
    #     validate :title, :content, presence: true
    #     validate :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    #
    #     # Validazioni condizionali
    #     validate_if :is_published? do
    #       validate :published_at, presence: true
    #       validate :author_id, presence: true
    #     end
    #
    #     # Validazioni condizionali negate
    #     validate_unless :is_draft? do
    #       validate :reviewer_id, presence: true
    #     end
    #
    #     # Cross-field validations
    #     validate_order :starts_at, :before, :ends_at
    #     validate_order :min_price, :lteq, :max_price
    #
    #     # Business rules
    #     validate_business_rule :valid_category
    #     validate_business_rule :author_has_permission, on: :create
    #
    #     # Gruppi di validazioni
    #     validation_group :step1, [:email, :password]
    #     validation_group :step2, [:first_name, :last_name]
    #   end
    #
    class Configurator
      attr_reader :groups

      def initialize(model_class)
        @model_class = model_class
        @conditional_validations = []
        @order_validations = []
        @business_rules = []
        @groups = {}
      end

      # Definisce validazioni standard sui campi
      #
      # @param fields [Array<Symbol>] Nomi dei campi
      # @param options [Hash] Opzioni di validazione (presence, format, etc.)
      #
      # @example
      #   validate :title, :content, presence: true
      #   validate :email, format: { with: URI::MailTo::EMAIL_REGEXP }
      #   validate :age, numericality: { greater_than: 0 }
      #
      def validate(*fields, **options)
        # Se siamo dentro un blocco condizionale, aggiungi alla condizione corrente
        if @current_conditional
          @current_conditional[:validations] << {
            fields: fields,
            options: options
          }
        else
          # Altrimenti applica direttamente alla classe
          # Questo viene fatto subito, non in apply_validatable_config
          @model_class.validates(*fields, **options)
        end
      end

      # Validazioni condizionali (se condizione è vera)
      #
      # @param condition [Symbol, Proc] Condizione da verificare
      # @yield Blocco con validazioni da applicare se condizione è vera
      #
      # @example Con simbolo (metodo)
      #   validate_if :is_published? do
      #     validate :published_at, presence: true
      #   end
      #
      # @example Con lambda
      #   validate_if -> { status == "published" } do
      #     validate :published_at, presence: true
      #   end
      #
      def validate_if(condition, &block)
        raise ArgumentError, "validate_if requires a block" unless block_given?

        conditional = {
          condition: condition,
          negate: false,
          validations: []
        }

        # Set current conditional per catturare le validate dentro il blocco
        @current_conditional = conditional
        instance_eval(&block)
        @current_conditional = nil

        @conditional_validations << conditional
      end

      # Validazioni condizionali negate (se condizione è falsa)
      #
      # @param condition [Symbol, Proc] Condizione da verificare
      # @yield Blocco con validazioni da applicare se condizione è falsa
      #
      # @example
      #   validate_unless :is_draft? do
      #     validate :reviewer_id, presence: true
      #   end
      #
      def validate_unless(condition, &block)
        raise ArgumentError, "validate_unless requires a block" unless block_given?

        conditional = {
          condition: condition,
          negate: true,
          validations: []
        }

        @current_conditional = conditional
        instance_eval(&block)
        @current_conditional = nil

        @conditional_validations << conditional
      end

      # Validazione di ordine tra campi (cross-field)
      #
      # Verifica che un campo sia in una relazione d'ordine rispetto ad un altro.
      #
      # @param first_field [Symbol] Primo campo
      # @param comparator [Symbol] Comparatore (:before, :after, :lteq, :gteq)
      # @param second_field [Symbol] Secondo campo
      # @param options [Hash] Opzioni aggiuntive (on, if, unless, message)
      #
      # @example Date validation
      #   validate_order :starts_at, :before, :ends_at
      #   validate_order :starts_at, :before, :ends_at, message: "must be before end date"
      #
      # @example Numeric validation
      #   validate_order :min_price, :lteq, :max_price
      #   validate_order :discount, :lteq, :price, on: :create
      #
      # Comparatori supportati:
      # - :before - first < second (date/time)
      # - :after - first > second (date/time)
      # - :lteq - first <= second (numeric)
      # - :gteq - first >= second (numeric)
      # - :lt - first < second (numeric)
      # - :gt - first > second (numeric)
      #
      def validate_order(first_field, comparator, second_field, **options)
        valid_comparators = %i[before after lteq gteq lt gt]
        unless valid_comparators.include?(comparator)
          raise ArgumentError, "Invalid comparator: #{comparator}. Valid: #{valid_comparators.join(', ')}"
        end

        @order_validations << {
          first_field: first_field,
          comparator: comparator,
          second_field: second_field,
          options: options
        }
      end

      # Definisce una business rule custom
      #
      # Le business rules sono metodi custom che implementano logica di validazione
      # complessa che non può essere espressa con validatori standard.
      #
      # @param rule_name [Symbol] Nome del metodo che implementa la rule
      # @param options [Hash] Opzioni (on, if, unless)
      #
      # @example
      #   # Nel configurator:
      #   validate_business_rule :valid_category
      #   validate_business_rule :author_has_permission, on: :create
      #
      #   # Nel modello (implementazione):
      #   def valid_category
      #     unless Category.exists?(id: category_id)
      #       errors.add(:category_id, "must be a valid category")
      #     end
      #   end
      #
      #   def author_has_permission
      #     unless author&.can_create_articles?
      #       errors.add(:author_id, "does not have permission")
      #     end
      #   end
      #
      def validate_business_rule(rule_name, **options)
        @business_rules << {
          name: rule_name,
          options: options
        }
      end

      # Definisce un gruppo di validazioni
      #
      # I gruppi permettono di validare solo un sottoinsieme di campi,
      # utile per form multi-step o validazioni parziali.
      #
      # @param group_name [Symbol] Nome del gruppo
      # @param fields [Array<Symbol>] Campi inclusi nel gruppo
      #
      # @example
      #   validation_group :step1, [:email, :password]
      #   validation_group :step2, [:first_name, :last_name]
      #   validation_group :step3, [:address, :city, :zip_code]
      #
      #   # Utilizzo:
      #   user.valid?(:step1)  # Valida solo email e password
      #   user.errors_for_group(:step1)
      #
      def validation_group(group_name, fields)
        raise ArgumentError, "Group name must be a symbol" unless group_name.is_a?(Symbol)
        raise ArgumentError, "Fields must be an array" unless fields.is_a?(Array)
        raise ArgumentError, "Group already defined: #{group_name}" if @groups.key?(group_name)

        @groups[group_name] = {
          name: group_name,
          fields: fields
        }
      end

      # Restituisce la configurazione completa
      #
      # @return [Hash] Configurazione con tutte le validazioni
      def to_h
        {
          conditional_validations: @conditional_validations,
          order_validations: @order_validations,
          business_rules: @business_rules
        }
      end
    end
  end
end
