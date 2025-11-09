# frozen_string_literal: true

module BetterModel
  module Stateable
    # Check evaluator per Stateable (internal class name remains Guard for compatibility)
    #
    # Valuta le check conditions per determinare se una transizione è permessa.
    # Supporta tre tipi di checks:
    # - Block: lambda/proc valutato nel contesto dell'istanza
    # - Method: metodo chiamato sull'istanza
    # - Predicate: integrazione con Statusable (is_ready?, etc.)
    #
    class Guard
      def initialize(instance, guard_config)
        @instance = instance
        @guard_config = guard_config
      end

      # Valuta il check
      #
      # @return [Boolean] true se il check passa
      # @raise [BetterModel::Errors::Stateable::CheckFailedError] Se il check fallisce (opzionale, dipende dal contesto)
      #
      def evaluate
        case @guard_config[:type]
        when :block
          evaluate_block
        when :method
          evaluate_method
        when :predicate
          evaluate_predicate
        else
          raise BetterModel::Errors::Stateable::StateableError, "Unknown check type: #{@guard_config[:type]}"
        end
      end

      # Descrizione del check per messaggi di errore
      #
      # @return [String] Descrizione human-readable
      #
      def description
        case @guard_config[:type]
        when :block
          "block check"
        when :method
          "method check: #{@guard_config[:method]}"
        when :predicate
          "predicate check: #{@guard_config[:predicate]}"
        else
          "unknown check"
        end
      end

      private

      # Valuta un check block
      def evaluate_block
        block = @guard_config[:block]
        @instance.instance_exec(&block)
      end

      # Valuta un check method
      def evaluate_method
        method_name = @guard_config[:method]

        unless @instance.respond_to?(method_name, true)
          raise NoMethodError, "Check method '#{method_name}' not found in #{@instance.class.name}. " \
                               "Define it in your model: def #{method_name}; ...; end"
        end

        @instance.send(method_name)
      end

      # Valuta un check predicate (integrazione Statusable)
      def evaluate_predicate
        predicate_name = @guard_config[:predicate]

        unless @instance.respond_to?(predicate_name)
          raise NoMethodError, "Check predicate '#{predicate_name}' not found in #{@instance.class.name}. " \
                               "Make sure Statusable is enabled and the predicate is defined: is :ready, -> { ... }"
        end

        @instance.send(predicate_name)
      end
    end
  end
end
