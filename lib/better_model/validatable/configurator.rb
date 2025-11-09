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
    #     check :title, :content, presence: true
    #     check :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    #
    #     # Validazioni complesse
    #     check_complex :valid_pricing
    #     check_complex :stock_check
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
        @complex_validations = []
        @groups = {}
      end

      # Definisce validazioni standard sui campi
      #
      # @param fields [Array<Symbol>] Nomi dei campi
      # @param options [Hash] Opzioni di validazione (presence, format, etc.)
      #
      # @example
      #   check :title, :content, presence: true
      #   check :email, format: { with: URI::MailTo::EMAIL_REGEXP }
      #   check :age, numericality: { greater_than: 0 }
      #
      def check(*fields, **options)
        @model_class.validates(*fields, **options)
      end

      # Usa una validazione complessa registrata
      #
      # Le validazioni complesse devono essere registrate prima usando
      # register_complex_validation nel modello.
      #
      # @param name [Symbol] Nome della validazione complessa registrata
      #
      # @example
      #   # Nel modello (registrazione):
      #   register_complex_validation :valid_pricing do
      #     if sale_price.present? && sale_price >= price
      #       errors.add(:sale_price, "must be less than regular price")
      #     end
      #   end
      #
      #   # Nel configurator (uso):
      #   validatable do
      #     check_complex :valid_pricing
      #   end
      #
      def check_complex(name)
        unless @model_class.complex_validation?(name)
          raise ArgumentError, "Unknown complex validation: #{name}. Use register_complex_validation to define it first."
        end

        @complex_validations << name.to_sym
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
          complex_validations: @complex_validations
        }
      end
    end
  end
end
