# frozen_string_literal: true

# Permissible - Sistema di permessi dichiarativi per modelli Rails
#
# Questo concern permette di definire permessi/capacità sui modelli utilizzando un DSL
# semplice e dichiarativo, simile al pattern Statusable ma per le operazioni.
#
# Esempio di utilizzo:
#   class Article < ApplicationRecord
#     include BetterModel::Permissible
#
#     permit :delete, -> { status != "published" }
#     permit :edit, -> { is?(:draft) || is?(:scheduled) }
#     permit :publish, -> { is?(:draft) && valid?(:publication) }
#     permit :archive, -> { is?(:published) && created_at < 1.year.ago }
#   end
#
# Utilizzo:
#   article.permit?(:delete)           # => true/false
#   article.permit_delete?             # => true/false
#   article.permit_edit?               # => true/false
#   article.permit_publish?            # => true/false
#
module BetterModel
  module Permissible
    extend ActiveSupport::Concern

    included do
      # Registry dei permessi definiti per questa classe
      class_attribute :permit_definitions
      self.permit_definitions = {}
    end

    class_methods do
      # DSL per definire permessi
      #
      # Parametri:
      # - permission_name: simbolo che rappresenta il permesso (es. :delete, :edit)
      # - condition_proc: lambda o proc che definisce la condizione
      # - block: blocco alternativo alla condition_proc
      #
      # Esempi:
      #   permit :delete, -> { status != "published" }
      #   permit :edit, -> { is?(:draft) }
      #   permit :publish do
      #     is?(:draft) && valid?(:publication)
      #   end
      def permit(permission_name, condition_proc = nil, &block)
        # Valida i parametri prima di convertire
        raise ArgumentError, "Permission name cannot be blank" if permission_name.blank?

        permission_name = permission_name.to_sym
        condition = condition_proc || block
        raise ArgumentError, "Condition proc or block is required" unless condition
        raise ArgumentError, "Condition must respond to call" unless condition.respond_to?(:call)

        # Registra il permesso nel registry
        self.permit_definitions = permit_definitions.merge(permission_name => condition.freeze).freeze

        # Genera il metodo dinamico permit_#{permission_name}?
        define_permit_method(permission_name)
      end

      # Lista di tutti i permessi definiti per questa classe
      def defined_permissions
        permit_definitions.keys
      end

      # Verifica se un permesso è definito
      def permission_defined?(permission_name)
        permit_definitions.key?(permission_name.to_sym)
      end

      private

      # Genera dinamicamente il metodo permit_#{permission_name}? per ogni permesso definito
      def define_permit_method(permission_name)
        method_name = "permit_#{permission_name}?"

        # Evita di ridefinire metodi se già esistono
        return if method_defined?(method_name)

        define_method(method_name) do
          permit?(permission_name)
        end
      end
    end

    # Metodo generico per verificare se un permesso è garantito
    #
    # Parametri:
    # - permission_name: simbolo del permesso da verificare
    #
    # Ritorna:
    # - true se il permesso è garantito
    # - false se il permesso non è garantito o non è definito
    #
    # Esempio:
    #   article.permit?(:delete)
    def permit?(permission_name)
      permission_name = permission_name.to_sym
      condition = self.class.permit_definitions[permission_name]

      # Se il permesso non è definito, ritorna false (secure by default)
      return false unless condition

      # Valuta la condizione nel contesto dell'istanza del modello
      # Gli errori si propagano naturalmente - fail fast
      instance_exec(&condition)
    end

    # Ritorna tutti i permessi disponibili per questa istanza con i loro valori
    #
    # Ritorna:
    # - Hash con chiavi simbolo (permessi) e valori booleani (garantiti/negati)
    #
    # Esempio:
    #   article.permissions
    #   # => { delete: true, edit: false, publish: false, archive: false }
    def permissions
      self.class.permit_definitions.each_with_object({}) do |(permission_name, _condition), result|
        result[permission_name] = permit?(permission_name)
      end
    end

    # Verifica se l'istanza ha almeno un permesso garantito
    def has_any_permission?
      permissions.values.any?
    end

    # Verifica se l'istanza ha tutti i permessi specificati garantiti
    def has_all_permissions?(permission_names)
      Array(permission_names).all? { |permission_name| permit?(permission_name) }
    end

    # Filtra una lista di permessi restituendo solo quelli garantiti
    def granted_permissions(permission_names)
      Array(permission_names).select { |permission_name| permit?(permission_name) }
    end

    # Override di as_json per includere automaticamente i permessi se richiesto
    def as_json(options = {})
      result = super

      # Include i permessi se esplicitamente richiesto, converting symbol keys to strings
      result["permissions"] = permissions.transform_keys(&:to_s) if options[:include_permissions]

      result
    end
  end
end
