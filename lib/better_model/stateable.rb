# frozen_string_literal: true

# Stateable - Declarative State Machine per modelli Rails
#
# Questo concern permette di definire state machines dichiarative con:
# - Stati espliciti con initial state
# - Transizioni con guards, validazioni e callbacks
# - Tracking storico transizioni
# - Integrazione con Statusable per guards
#
# APPROCCIO OPT-IN: La state machine non è attiva automaticamente.
# Devi chiamare esplicitamente `stateable do...end` nel tuo modello.
#
# REQUISITI DATABASE:
#   - Colonna `state` (string) nel modello
#   - Tabella per storico transizioni (default: `state_transitions`, configurabile)
#
# Esempio di utilizzo:
#   class Order < ApplicationRecord
#     include BetterModel
#
#     # Optional: Statusable per status derivati
#     is :payable, -> { confirmed? && !paid? }
#
#     # Attiva stateable (opt-in)
#     stateable do
#       # Stati
#       state :pending, initial: true
#       state :confirmed
#       state :paid
#       state :cancelled
#
#       # Transizioni
#       transition :confirm, from: :pending, to: :confirmed do
#         check { items.any? }
#         check :customer_valid?
#         check if: :is_payable?  # Statusable integration
#
#         validate { errors.add(:base, "Stock unavailable") unless stock_available? }
#
#         before_transition { calculate_total }
#         after_transition { send_confirmation_email }
#       end
#
#       transition :pay, from: :confirmed, to: :paid do
#         before_transition { charge_payment }
#       end
#
#       transition :cancel, from: [:pending, :confirmed], to: :cancelled
#     end
#
#     # Optional: Custom table name for transitions
#     transitions_table 'order_transitions'
#   end
#
# Utilizzo:
#   order.state              # => "pending"
#   order.pending?           # => true
#   order.can_confirm?       # => true (controlla guards)
#   order.confirm!           # Esegue transizione
#   order.state              # => "confirmed"
#
#   order.state_transitions  # => Array di StateTransition records
#   order.transition_history # => Array formattato di transizioni
#
# Table Naming Options:
#   # Option 1: Default shared table (state_transitions)
#   stateable do
#     # Uses 'state_transitions' table by default
#   end
#
#   # Option 2: Custom table name
#   stateable do
#     transitions_table 'order_transitions'
#   end
#
#   # Option 3: Shared custom table
#   class Order < ApplicationRecord
#     stateable do
#       transitions_table 'transitions'
#     end
#   end
#   class Article < ApplicationRecord
#     stateable do
#       transitions_table 'transitions'  # Same table
#     end
#   end
#
module BetterModel
  module Stateable
    extend ActiveSupport::Concern

    # Thread-safe mutex for dynamic class creation
    CLASS_CREATION_MUTEX = Mutex.new

    included do
      # Validazione ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Stateable can only be included in ActiveRecord models"
      end

      # Configurazione stateable (opt-in)
      class_attribute :stateable_enabled, default: false
      class_attribute :stateable_config, default: {}.freeze
      class_attribute :stateable_states, default: [].freeze
      class_attribute :stateable_transitions, default: {}.freeze
      class_attribute :stateable_initial_state, default: nil
      class_attribute :stateable_table_name, default: nil
      class_attribute :_stateable_setup_done, default: false
    end

    class_methods do
      # DSL per attivare e configurare stateable (OPT-IN)
      #
      # @example Attivazione base
      #   stateable do
      #     state :draft, initial: true
      #     state :published
      #     transition :publish, from: :draft, to: :published
      #   end
      #
      # @example Con checks e callbacks
      #   stateable do
      #     state :pending, initial: true
      #     state :confirmed
      #
      #     transition :confirm, from: :pending, to: :confirmed do
      #       check { valid? }
      #       before_transition { prepare_confirmation }
      #       after_transition { send_notification }
      #     end
      #   end
      #
      def stateable(&block)
        # Attiva stateable
        self.stateable_enabled = true

        # Configura se passato un blocco
        if block_given?
          configurator = Configurator.new(self)
          configurator.instance_eval(&block)

          self.stateable_config = configurator.to_h.freeze
          self.stateable_states = configurator.states.freeze
          self.stateable_transitions = configurator.transitions.freeze
          self.stateable_initial_state = configurator.initial_state
          self.stateable_table_name = configurator.table_name
        end

        # Set default table name if not configured
        self.stateable_table_name ||= "state_transitions"

        # Setup methods only once
        return if self._stateable_setup_done

        self._stateable_setup_done = true

        # Setup association con StateTransition
        setup_state_transitions_association

        # Setup dynamic methods
        setup_dynamic_methods

        # Setup validations
        setup_state_validation

        # Setup callbacks
        setup_initial_state_callback
      end

      # Verifica se stateable è attivo
      #
      # @return [Boolean]
      def stateable_enabled?
        stateable_enabled == true
      end

      private

      # Setup association con StateTransition model
      def setup_state_transitions_association
        # Create or retrieve a StateTransition class for the given table name
        transition_class = create_state_transition_class_for_table(stateable_table_name)

        has_many :state_transitions,
                 -> { order(created_at: :desc) },
                 as: :transitionable,
                 class_name: transition_class.name,
                 dependent: :destroy
      end

      # Create or retrieve a StateTransition class for the given table name
      #
      # Thread-safe implementation using mutex to prevent race conditions
      # when multiple threads try to create the same class simultaneously.
      #
      # @param table_name [String] Table name for state transitions
      # @return [Class] StateTransition class
      #
      def create_state_transition_class_for_table(table_name)
        # Create a unique class name based on table name
        class_name = "#{table_name.camelize.singularize}"

        # Fast path: check if class already exists (no lock needed)
        if BetterModel.const_defined?(class_name, false)
          return BetterModel.const_get(class_name)
        end

        # Slow path: acquire lock and create class
        CLASS_CREATION_MUTEX.synchronize do
          # Double-check after acquiring lock (another thread may have created it)
          if BetterModel.const_defined?(class_name, false)
            return BetterModel.const_get(class_name)
          end

          # Create new StateTransition class dynamically
          transition_class = Class.new(BetterModel::StateTransition) do
            self.table_name = table_name
          end

          # Register the class in BetterModel namespace
          BetterModel.const_set(class_name, transition_class)
          transition_class
        end
      end

      # Setup dynamic methods per stati e transizioni
      def setup_dynamic_methods
        # Metodi per ogni stato: pending?, confirmed?, etc.
        stateable_states.each do |state_name|
          define_method "#{state_name}?" do
            state.to_s == state_name.to_s
          end
        end

        # Metodi per ogni transizione: confirm!, can_confirm?, etc.
        stateable_transitions.each do |event_name, transition_config|
          # event! - esegue transizione (raise se fallisce)
          define_method "#{event_name}!" do |**metadata|
            transition_to!(event_name, **metadata)
          end

          # can_event? - controlla se transizione è possibile
          define_method "can_#{event_name}?" do
            can_transition_to?(event_name)
          end
        end
      end

      # Setup validazione dello stato
      def setup_state_validation
        validates :state, presence: true, inclusion: { in: ->(_) { stateable_states.map(&:to_s) } }
      end

      # Setup callback per impostare initial state
      def setup_initial_state_callback
        before_validation :set_initial_state, on: :create

        define_method :set_initial_state do
          return if state.present?
          self.state = self.class.stateable_initial_state.to_s if self.class.stateable_initial_state
        end
      end
    end

    # Metodi di istanza

    # Esegue una transizione di stato
    #
    # @param event [Symbol] Nome della transizione
    # @param metadata [Hash] Metadata opzionale da salvare nella StateTransition
    # @raise [InvalidTransitionError] Se la transizione non è valida
    # @raise [CheckFailedError] Se un check fallisce
    # @raise [ValidationFailedError] Se una validazione fallisce
    # @return [Boolean] true se la transizione ha successo
    #
    def transition_to!(event, **metadata)
      raise NotEnabledError unless self.class.stateable_enabled?

      transition_config = self.class.stateable_transitions[event.to_sym]
      raise ArgumentError, "Unknown transition: #{event}" unless transition_config

      current_state = state.to_sym

      # Verifica che from_state sia valido
      from_states = Array(transition_config[:from])
      unless from_states.include?(current_state)
        raise InvalidTransitionError.new(event, current_state, transition_config[:to])
      end

      # Esegui la transizione usando Transition executor
      transition = Transition.new(self, event, transition_config, metadata)
      transition.execute!
    end

    # Verifica se una transizione è possibile
    #
    # @param event [Symbol] Nome della transizione
    # @return [Boolean] true se la transizione è possibile
    #
    def can_transition_to?(event)
      return false unless self.class.stateable_enabled?

      transition_config = self.class.stateable_transitions[event.to_sym]
      return false unless transition_config

      current_state = state.to_sym
      from_states = Array(transition_config[:from])
      return false unless from_states.include?(current_state)

      # Verifica guards
      guards = transition_config[:guards] || []
      guards.all? do |guard|
        Guard.new(self, guard).evaluate
      end
    rescue StandardError
      false
    end

    # Ottieni lo storico delle transizioni formattato
    #
    # @return [Array<Hash>] Array di transizioni con :event, :from, :to, :at, :metadata
    #
    def transition_history
      raise NotEnabledError unless self.class.stateable_enabled?

      state_transitions.map do |transition|
        {
          event: transition.event,
          from: transition.from_state,
          to: transition.to_state,
          at: transition.created_at,
          metadata: transition.metadata
        }
      end
    end

    # Override as_json per includere transition history
    #
    # @param options [Hash] Options
    # @option options [Boolean] :include_transition_history Include full history
    # @return [Hash]
    #
    def as_json(options = {})
      result = super

      if options[:include_transition_history] && self.class.stateable_enabled?
        result["transition_history"] = transition_history
      end

      result
    end
  end
end
