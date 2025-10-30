# frozen_string_literal: true

module BetterModel
  module Stateable
    # Configurator per il DSL di Stateable
    #
    # Questo configurator permette di definire state machines in modo dichiarativo
    # all'interno del blocco `stateable do...end`.
    #
    # Esempio:
    #   stateable do
    #     # Definisci stati
    #     state :pending, initial: true
    #     state :confirmed
    #     state :paid
    #
    #     # Definisci transizioni
    #     transition :confirm, from: :pending, to: :confirmed do
    #       guard { items.any? }
    #       guard :customer_valid?
    #       guard if: :is_ready?
    #
    #       validate { errors.add(:base, "Invalid") unless valid_for_confirmation? }
    #
    #       before { prepare }
    #       after { notify }
    #     end
    #   end
    #
    class Configurator
      attr_reader :states, :transitions, :initial_state, :table_name

      def initialize(model_class)
        @model_class = model_class
        @states = []
        @transitions = {}
        @initial_state = nil
        @table_name = nil
        @current_transition = nil
      end

      # Definisce uno stato
      #
      # @param name [Symbol] Nome dello stato
      # @param initial [Boolean] Se questo è lo stato iniziale
      #
      # @example
      #   state :draft, initial: true
      #   state :published
      #   state :archived
      #
      def state(name, initial: false)
        raise ArgumentError, "State name must be a symbol" unless name.is_a?(Symbol)
        raise ArgumentError, "State #{name} already defined" if @states.include?(name)

        @states << name

        if initial
          raise ArgumentError, "Initial state already defined as #{@initial_state}" if @initial_state
          @initial_state = name
        end
      end

      # Definisce una transizione
      #
      # @param event [Symbol] Nome dell'evento/transizione
      # @param from [Symbol, Array<Symbol>] Stato/i di partenza
      # @param to [Symbol] Stato di arrivo
      # @yield Blocco per configurare guards, validations, callbacks
      #
      # @example Transizione semplice
      #   transition :publish, from: :draft, to: :published
      #
      # @example Con guards e callbacks
      #   transition :confirm, from: :pending, to: :confirmed do
      #     guard { valid? }
      #     guard :ready_to_confirm?
      #     before { prepare_confirmation }
      #     after { send_email }
      #   end
      #
      # @example Da multipli stati
      #   transition :cancel, from: [:pending, :confirmed, :paid], to: :cancelled
      #
      def transition(event, from:, to:, &block)
        raise ArgumentError, "Event name must be a symbol" unless event.is_a?(Symbol)
        raise ArgumentError, "Transition #{event} already defined" if @transitions.key?(event)

        # Normalizza from in array
        from_states = Array(from)

        # Verifica che gli stati esistano
        from_states.each do |state_name|
          unless @states.include?(state_name)
            raise ArgumentError, "Unknown state in from: #{state_name}. Define it with 'state :#{state_name}' first."
          end
        end

        unless @states.include?(to)
          raise ArgumentError, "Unknown state in to: #{to}. Define it with 'state :#{to}' first."
        end

        # Inizializza configurazione transizione
        @transitions[event] = {
          from: from_states,
          to: to,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }

        # Se c'è un blocco, configuralo
        if block_given?
          @current_transition = @transitions[event]
          instance_eval(&block)
          @current_transition = nil
        end
      end

      # Definisce un guard per la transizione corrente
      #
      # I guards sono precondizioni che devono essere vere per permettere la transizione.
      #
      # @overload guard(&block)
      #   Guard con lambda/proc
      #   @yield Blocco da valutare nel contesto dell'istanza
      #   @example
      #     guard { items.any? && customer.present? }
      #
      # @overload guard(method_name)
      #   Guard con metodo
      #   @param method_name [Symbol] Nome del metodo da chiamare
      #   @example
      #     guard :customer_valid?
      #
      # @overload guard(if: predicate)
      #   Guard con Statusable predicate
      #   @param if [Symbol] Nome del predicate (integrazione Statusable)
      #   @example
      #     guard if: :is_ready_for_publishing?
      #
      def guard(method_name = nil, if: nil, &block)
        raise StateableError, "guard can only be called inside a transition block" unless @current_transition

        if block_given?
          @current_transition[:guards] << { type: :block, block: block }
        elsif method_name
          @current_transition[:guards] << { type: :method, method: method_name }
        elsif binding.local_variable_get(:if)
          @current_transition[:guards] << { type: :predicate, predicate: binding.local_variable_get(:if) }
        else
          raise ArgumentError, "guard requires either a block, method name, or if: option"
        end
      end

      # Definisce una validazione per la transizione corrente
      #
      # Le validazioni sono eseguite dopo i guards e prima dei callbacks.
      # Devono aggiungere errori all'oggetto errors se la validazione fallisce.
      #
      # @yield Blocco da valutare nel contesto dell'istanza
      #
      # @example
      #   validate do
      #     errors.add(:base, "Stock unavailable") unless stock_available?
      #     errors.add(:payment, "required") if payment_method.blank?
      #   end
      #
      def validate(&block)
        raise StateableError, "validate can only be called inside a transition block" unless @current_transition
        raise ArgumentError, "validate requires a block" unless block_given?

        @current_transition[:validations] << block
      end

      # Definisce un callback before per la transizione corrente
      #
      # I before callbacks sono eseguiti prima della transizione di stato.
      #
      # @overload before(&block)
      #   Before callback con lambda/proc
      #   @yield Blocco da eseguire
      #   @example
      #     before { calculate_total }
      #
      # @overload before(method_name)
      #   Before callback con metodo
      #   @param method_name [Symbol] Nome del metodo da chiamare
      #   @example
      #     before :calculate_total
      #
      def before(method_name = nil, &block)
        raise StateableError, "before can only be called inside a transition block" unless @current_transition

        if block_given?
          @current_transition[:before_callbacks] << { type: :block, block: block }
        elsif method_name
          @current_transition[:before_callbacks] << { type: :method, method: method_name }
        else
          raise ArgumentError, "before requires either a block or method name"
        end
      end

      # Definisce un callback after per la transizione corrente
      #
      # Gli after callbacks sono eseguiti dopo la transizione di stato.
      #
      # @overload after(&block)
      #   After callback con lambda/proc
      #   @yield Blocco da eseguire
      #   @example
      #     after { send_notification }
      #
      # @overload after(method_name)
      #   After callback con metodo
      #   @param method_name [Symbol] Nome del metodo da chiamare
      #   @example
      #     after :send_notification
      #
      def after(method_name = nil, &block)
        raise StateableError, "after can only be called inside a transition block" unless @current_transition

        if block_given?
          @current_transition[:after_callbacks] << { type: :block, block: block }
        elsif method_name
          @current_transition[:after_callbacks] << { type: :method, method: method_name }
        else
          raise ArgumentError, "after requires either a block or method name"
        end
      end

      # Definisce un callback around per la transizione corrente
      #
      # Gli around callbacks wrappano la transizione di stato.
      # Il blocco riceve un altro blocco che deve chiamare per eseguire la transizione.
      #
      # @yield Blocco da eseguire, riceve un blocco da chiamare
      #
      # @example
      #   around do |transition|
      #     log_start
      #     transition.call
      #     log_end
      #   end
      #
      def around(&block)
        raise StateableError, "around can only be called inside a transition block" unless @current_transition
        raise ArgumentError, "around requires a block" unless block_given?

        @current_transition[:around_callbacks] << block
      end

      # Specifica il nome della tabella per state transitions
      #
      # @param name [String, Symbol] Nome della tabella
      #
      # @example Default (state_transitions)
      #   stateable do
      #     # Uses 'state_transitions' table by default
      #   end
      #
      # @example Custom table name
      #   stateable do
      #     transitions_table 'order_transitions'
      #   end
      #
      # @example Shared table across models
      #   class Order < ApplicationRecord
      #     stateable do
      #       transitions_table 'transitions'
      #     end
      #   end
      #
      #   class Article < ApplicationRecord
      #     stateable do
      #       transitions_table 'transitions'  # Same table
      #     end
      #   end
      #
      def transitions_table(name)
        @table_name = name.to_s
      end

      # Restituisce la configurazione completa
      #
      # @return [Hash] Configurazione con stati e transizioni
      #
      def to_h
        {
          states: @states,
          transitions: @transitions,
          initial_state: @initial_state,
          table_name: @table_name
        }
      end
    end
  end
end
