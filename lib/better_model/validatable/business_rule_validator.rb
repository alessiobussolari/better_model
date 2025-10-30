# frozen_string_literal: true

module BetterModel
  module Validatable
    # Validator per business rules custom
    #
    # Permette di eseguire metodi custom come validatori, delegando la logica
    # di validazione complessa a metodi del modello.
    #
    # Il metodo della business rule deve aggiungere errori tramite `errors.add`
    # se la validazione fallisce.
    #
    # Esempio:
    #   validates_with BusinessRuleValidator, rule_name: :valid_category
    #
    #   # Nel modello:
    #   def valid_category
    #     unless Category.exists?(id: category_id)
    #       errors.add(:category_id, "must be a valid category")
    #     end
    #   end
    #
    class BusinessRuleValidator < ActiveModel::Validator
      def initialize(options)
        super

        @rule_name = options[:rule_name]

        unless @rule_name
          raise ArgumentError, "BusinessRuleValidator requires :rule_name option"
        end
      end

      def validate(record)
        # Verifica che il metodo esista
        unless record.respond_to?(@rule_name, true)
          raise NoMethodError, "Business rule method '#{@rule_name}' not found in #{record.class.name}. " \
                               "Define it in your model: def #{@rule_name}; ...; end"
        end

        # Esegui il metodo della business rule
        # Il metodo stesso è responsabile di aggiungere errori tramite errors.add
        record.send(@rule_name)
      end
    end
  end
end
