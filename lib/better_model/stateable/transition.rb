# frozen_string_literal: true

module BetterModel
  module Stateable
    # Transition executor per Stateable
    #
    # Gestisce l'esecuzione di una transizione di stato, includendo:
    # - Valutazione guards
    # - Esecuzione validazioni
    # - Esecuzione callbacks (before/after/around)
    # - Aggiornamento stato nel database
    # - Creazione record StateTransition per storico
    #
    class Transition
      def initialize(instance, event, config, metadata = {})
        @instance = instance
        @event = event
        @config = config
        @metadata = metadata
        @from_state = instance.state.to_sym
        @to_state = config[:to]
      end

      # Esegue la transizione
      #
      # @raise [GuardFailedError] Se un guard fallisce
      # @raise [ValidationFailedError] Se una validazione fallisce
      # @raise [ActiveRecord::RecordInvalid] Se il save! fallisce
      # @return [Boolean] true se la transizione ha successo
      #
      def execute!
        # 1. Valuta guards
        evaluate_guards!

        # 2. Esegui validazioni
        execute_validations!

        # 3. Wrap in transaction
        @instance.class.transaction do
          # 4. Esegui callbacks around (se presenti)
          if @config[:around_callbacks].any?
            execute_around_callbacks do
              perform_transition!
            end
          else
            perform_transition!
          end
        end

        true
      end

      private

      # Valuta tutti i guards
      def evaluate_guards!
        guards = @config[:guards] || []

        guards.each do |guard_config|
          guard = Guard.new(@instance, guard_config)

          unless guard.evaluate
            raise GuardFailedError.new(@event, guard.description)
          end
        end
      end

      # Esegue tutte le validazioni
      def execute_validations!
        validations = @config[:validations] || []
        return if validations.empty?

        # Clear existing errors per questa transizione
        @instance.errors.clear

        validations.each do |validation_block|
          @instance.instance_exec(&validation_block)
        end

        if @instance.errors.any?
          raise ValidationFailedError.new(@event, @instance.errors)
        end
      end

      # Esegue i callback around
      def execute_around_callbacks(&block)
        around_callbacks = @config[:around_callbacks] || []

        if around_callbacks.empty?
          block.call
          return
        end

        # Nested around callbacks
        chain = around_callbacks.reverse.reduce(block) do |inner, around_callback|
          proc { @instance.instance_exec(inner, &around_callback) }
        end

        chain.call
      end

      # Esegue la transizione effettiva
      def perform_transition!
        # 1. Esegui before callbacks
        execute_callbacks(@config[:before_callbacks] || [])

        # 2. Aggiorna stato
        @instance.state = @to_state.to_s

        # 3. Salva il record (valida il modello)
        @instance.save!

        # 4. Crea record StateTransition
        create_state_transition_record

        # 5. Esegui after callbacks
        execute_callbacks(@config[:after_callbacks] || [])
      end

      # Esegue una lista di callbacks
      def execute_callbacks(callbacks)
        callbacks.each do |callback_config|
          case callback_config[:type]
          when :block
            @instance.instance_exec(&callback_config[:block])
          when :method
            @instance.send(callback_config[:method])
          end
        end
      end

      # Crea il record StateTransition per lo storico
      def create_state_transition_record
        @instance.state_transitions.create!(
          event: @event.to_s,
          from_state: @from_state.to_s,
          to_state: @to_state.to_s,
          metadata: @metadata
        )
      end
    end
  end
end
