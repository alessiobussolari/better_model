# frozen_string_literal: true

require_relative "errors/stateable/stateable_error"
require_relative "errors/stateable/not_enabled_error"
require_relative "errors/stateable/invalid_state_error"
require_relative "errors/stateable/invalid_transition_error"
require_relative "errors/stateable/check_failed_error"
require_relative "errors/stateable/validation_failed_error"
require_relative "errors/stateable/configuration_error"

# Stateable - Declarative State Machine for Rails models
#
# This concern allows defining declarative state machines with:
# - Explicit states with initial state
# - Transitions with guards, validations, and callbacks
# - Transition history tracking
# - Integration with Statusable for guards
#
# OPT-IN APPROACH: The state machine is not enabled automatically.
# You must explicitly call `stateable do...end` in your model.
#
# DATABASE REQUIREMENTS:
#   - `state` column (string) in the model
#   - Table for transition history (default: `state_transitions`, configurable)
#
# Usage example:
#   class Order < ApplicationRecord
#     include BetterModel
#
#     # Optional: Statusable for derived statuses
#     is :payable, -> { confirmed? && !paid? }
#
#     # Enable stateable (opt-in)
#     stateable do
#       # States
#       state :pending, initial: true
#       state :confirmed
#       state :paid
#       state :cancelled
#
#       # Transitions
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
# Usage:
#   order.state              # => "pending"
#   order.pending?           # => true
#   order.can_confirm?       # => true (checks guards)
#   order.confirm!           # Execute transition
#   order.state              # => "confirmed"
#
#   order.state_transitions  # => Array of StateTransition records
#   order.transition_history # => Formatted array of transitions
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
      # Include shared enabled check concern
      include BetterModel::Concerns::EnabledCheck

      # Validate ActiveRecord inheritance
      unless ancestors.include?(ActiveRecord::Base)
        raise BetterModel::Errors::Stateable::ConfigurationError, "Invalid configuration"
      end

      # Stateable configuration (opt-in)
      class_attribute :stateable_enabled, default: false
      class_attribute :stateable_config, default: {}.freeze
      class_attribute :stateable_states, default: [].freeze
      class_attribute :stateable_transitions, default: {}.freeze
      class_attribute :stateable_initial_state, default: nil
      class_attribute :stateable_table_name, default: nil
      class_attribute :_stateable_setup_done, default: false
    end

    class_methods do
      # DSL to enable and configure stateable (OPT-IN)
      #
      # @example Basic activation
      #   stateable do
      #     state :draft, initial: true
      #     state :published
      #     transition :publish, from: :draft, to: :published
      #   end
      #
      # @example With checks and callbacks
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
        # Enable stateable
        self.stateable_enabled = true

        # Configure if block provided
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

        # Setup association with StateTransition
        setup_state_transitions_association

        # Setup dynamic methods
        setup_dynamic_methods

        # Setup validations
        setup_state_validation

        # Setup callbacks
        setup_initial_state_callback
      end

      # Check if stateable is enabled
      #
      # @return [Boolean]
      def stateable_enabled? = stateable_enabled == true

      private

      # Setup association with StateTransition model
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
          transition_class = Class.new(BetterModel::Models::StateTransition) do
            self.table_name = table_name
          end

          # Register the class in BetterModel namespace
          BetterModel.const_set(class_name, transition_class)
          transition_class
        end
      end

      # Setup dynamic methods for states and transitions
      def setup_dynamic_methods
        # Methods for each state: pending?, confirmed?, etc.
        stateable_states.each do |state_name|
          define_method "#{state_name}?" do
            state.to_s == state_name.to_s
          end
        end

        # Methods for each transition: confirm!, can_confirm?, etc.
        stateable_transitions.each do |event_name, transition_config|
          # event! - execute transition (raises if it fails)
          # Accepts both positional hash and keyword arguments for flexibility
          define_method "#{event_name}!" do |metadata = {}, **kwargs|
            # Convert positional hash to keyword args if provided
            combined_metadata = metadata.merge(kwargs)
            transition_to!(event_name, **combined_metadata)
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

    # Instance methods

    # Execute a state transition
    #
    # @param event [Symbol] Transition name
    # @param metadata [Hash] Optional metadata to save in StateTransition
    # @raise [BetterModel::Errors::Stateable::InvalidTransitionError] If transition is not valid
    # @raise [BetterModel::Errors::Stateable::CheckFailedError] If a check fails
    # @raise [BetterModel::Errors::Stateable::ValidationFailedError] If a validation fails
    # @return [Boolean] true if transition succeeds
    #
    def transition_to!(event, **metadata)
      ensure_module_enabled!(:stateable, BetterModel::Errors::Stateable::NotEnabledError)

      transition_config = self.class.stateable_transitions[event.to_sym]
      unless transition_config
        raise BetterModel::Errors::Stateable::ConfigurationError, "Unknown transition: #{event}"
      end

      current_state = state.to_sym

      # Verify that from_state is valid
      from_states = Array(transition_config[:from])
      unless from_states.include?(current_state)
        raise BetterModel::Errors::Stateable::InvalidTransitionError, "Cannot transition from #{current_state} to #{transition_config[:to]} via #{event}"
      end

      # Execute the transition using Transition executor
      transition = Transition.new(self, event, transition_config, metadata)
      transition.execute!
    end

    # Check if a transition is possible
    #
    # @param event [Symbol] Transition name
    # @return [Boolean] true if transition is possible
    #
    def can_transition_to?(event)
      return false unless self.class.stateable_enabled?

      transition_config = self.class.stateable_transitions[event.to_sym]
      return false unless transition_config

      current_state = state.to_sym
      from_states = Array(transition_config[:from])
      return false unless from_states.include?(current_state)

      # Check guards
      guards = transition_config[:guards] || []
      guards.all? do |guard|
        Guard.new(self, guard).evaluate
      end
    rescue StandardError
      false
    end

    # Get formatted transition history
    #
    # @return [Array<Hash>] Array of transitions with :event, :from, :to, :at, :metadata
    #
    def transition_history
      ensure_module_enabled!(:stateable, BetterModel::Errors::Stateable::NotEnabledError)

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
        # Convert symbol keys to string keys for JSON compatibility
        result["transition_history"] = transition_history.map do |item|
          item.transform_keys(&:to_s)
        end
      end

      result
    end
  end
end
