# frozen_string_literal: true

# Statusable - Sistema di stati dichiarativi per modelli Rails
#
# Questo concern permette di definire stati sui modelli utilizzando un DSL
# semplice e dichiarativo, simile al pattern Enrichable ma per gli stati.
#
# Esempio di utilizzo:
#   class Communications::Consult < ApplicationRecord
#     include BetterModel::Statusable
#
#     is :pending, -> { status == 'initialized' }
#     is :active_session, -> { status == 'active' && !expired? }
#     is :expired, -> { expires_at.present? && expires_at <= Time.current }
#     is :scheduled, -> { scheduled_at.present? }
#     is :immediate, -> { scheduled_at.blank? }
#     is :ready_to_start, -> { scheduled? && scheduled_at <= Time.current }
#   end
#
# Utilizzo:
#   consult.is?(:pending)           # => true/false
#   consult.is_pending?             # => true/false
#   consult.is_active_session?      # => true/false
#   consult.is_expired?             # => true/false
#   consult.is_scheduled?           # => true/false
#
module BetterModel
  module Statusable
    extend ActiveSupport::Concern

    included do
      # Registry degli stati definiti per questa classe
      class_attribute :is_definitions
      self.is_definitions = {}
    end

    class_methods do
      # DSL per definire stati
      #
      # Parametri:
      # - status_name: simbolo che rappresenta lo stato (es. :pending, :active)
      # - condition_proc: lambda o proc che definisce la condizione
      # - block: blocco alternativo alla condition_proc
      #
      # Esempi:
      #   is :pending, -> { status == 'initialized' }
      #   is :expired, -> { expires_at.present? && expires_at <= Time.current }
      #   is :ready do
      #     scheduled_at.present? && scheduled_at <= Time.current
      #   end
      def is(status_name, condition_proc = nil, &block)
        # Valida i parametri prima di convertire
        raise ArgumentError, "Status name cannot be blank" if status_name.blank?

        status_name = status_name.to_sym
        condition = condition_proc || block
        raise ArgumentError, "Condition proc or block is required" unless condition
        raise ArgumentError, "Condition must respond to call" unless condition.respond_to?(:call)

        # Registra lo stato nel registry
        self.is_definitions = is_definitions.merge(status_name => condition.freeze).freeze

        # Genera il metodo dinamico is_#{status_name}?
        define_is_method(status_name)
      end

      # Lista di tutti gli stati definiti per questa classe
      def defined_statuses
        is_definitions.keys
      end

      # Verifica se uno stato è definito
      def status_defined?(status_name)
        is_definitions.key?(status_name.to_sym)
      end

      private

      # Genera dinamicamente il metodo is_#{status_name}? per ogni stato definito
      def define_is_method(status_name)
        method_name = "is_#{status_name}?"

        # Evita di ridefinire metodi se già esistono
        return if method_defined?(method_name)

        define_method(method_name) do
          is?(status_name)
        end
      end
    end

    # Metodo generico per verificare se uno stato è attivo
    #
    # Parametri:
    # - status_name: simbolo dello stato da verificare
    #
    # Ritorna:
    # - true se lo stato è attivo
    # - false se lo stato non è attivo o non è definito
    #
    # Esempio:
    #   consult.is?(:pending)
    def is?(status_name)
      status_name = status_name.to_sym
      condition = self.class.is_definitions[status_name]

      # Se lo stato non è definito, ritorna false (secure by default)
      return false unless condition

      # Valuta la condizione nel contesto dell'istanza del modello
      # Gli errori si propagano naturalmente - fail fast
      instance_exec(&condition)
    end

    # Ritorna tutti gli stati disponibili per questa istanza con i loro valori
    #
    # Ritorna:
    # - Hash con chiavi simbolo (stati) e valori booleani (attivi/inattivi)
    #
    # Esempio:
    #   consult.statuses
    #   # => { pending: true, active: false, expired: false, scheduled: true }
    def statuses
      self.class.is_definitions.each_with_object({}) do |(status_name, _condition), result|
        result[status_name] = is?(status_name)
      end
    end

    # Verifica se l'istanza ha almeno uno stato attivo
    def has_any_status?
      statuses.values.any?
    end

    # Verifica se l'istanza ha tutti gli stati specificati attivi
    def has_all_statuses?(status_names)
      Array(status_names).all? { |status_name| is?(status_name) }
    end

    # Filtra una lista di stati restituendo solo quelli attivi
    def active_statuses(status_names)
      Array(status_names).select { |status_name| is?(status_name) }
    end

    # Override di as_json per includere automaticamente gli stati se richiesto
    def as_json(options = {})
      result = super

      # Include gli stati se esplicitamente richiesto, converting symbol keys to strings
      result["statuses"] = statuses.transform_keys(&:to_s) if options[:include_statuses]

      result
    end
  end
end
