# frozen_string_literal: true

module BetterModel
  module Stateable
    # Configurator for Stateable DSL.
    #
    # This configurator enables defining state machines declaratively
    # within the `stateable do...end` block.
    #
    # @example
    #   stateable do
    #     # Define states
    #     state :pending, initial: true
    #     state :confirmed
    #     state :paid
    #
    #     # Define transitions
    #     transition :confirm, from: :pending, to: :confirmed do
    #       check { items.any? }
    #       check :customer_valid?
    #       check if: :is_ready?
    #
    #       validate { errors.add(:base, "Invalid") unless valid_for_confirmation? }
    #
    #       before_transition { prepare }
    #       after_transition { notify }
    #     end
    #   end
    #
    # @api private
    class Configurator
      attr_reader :states, :transitions, :initial_state, :table_name

      # Initialize a new Configurator.
      #
      # @param model_class [Class] Model class being configured
      def initialize(model_class)
        @model_class = model_class
        @states = []
        @transitions = {}
        @initial_state = nil
        @table_name = nil
        @current_transition = nil
      end

      # Define a state.
      #
      # @param name [Symbol] State name
      # @param initial [Boolean] Whether this is the initial state
      # @raise [ArgumentError] If state name is invalid or already defined
      #
      # @example
      #   state :draft, initial: true
      #   state :published
      #   state :archived
      #
      # @example With initial state
      #   state :pending, initial: true
      def state(name, initial: false)
        raise ArgumentError, "State name must be a symbol" unless name.is_a?(Symbol)
        raise ArgumentError, "State #{name} already defined" if @states.include?(name)

        @states << name

        if initial
          raise ArgumentError, "Initial state already defined as #{@initial_state}" if @initial_state
          @initial_state = name
        end
      end

      # Define a transition.
      #
      # @param event [Symbol] Event/transition name
      # @param from [Symbol, Array<Symbol>] Source state(s)
      # @param to [Symbol] Destination state
      # @yield Block to configure guards, validations, callbacks
      # @raise [ArgumentError] If event is invalid, already defined, or states don't exist
      #
      # @example Simple transition
      #   transition :publish, from: :draft, to: :published
      #
      # @example With checks and callbacks
      #   transition :confirm, from: :pending, to: :confirmed do
      #     check { valid? }
      #     check :ready_to_confirm?
      #     before_transition { prepare_confirmation }
      #     after_transition { send_email }
      #   end
      #
      # @example From multiple states
      #   transition :cancel, from: [:pending, :confirmed, :paid], to: :cancelled
      #
      def transition(event, from:, to:, &block)
        raise ArgumentError, "Event name must be a symbol" unless event.is_a?(Symbol)
        raise ArgumentError, "Transition #{event} already defined" if @transitions.key?(event)

        # Normalize from to array
        from_states = Array(from)

        # Verify states exist
        from_states.each do |state_name|
          unless @states.include?(state_name)
            raise ArgumentError, "Unknown state in from: #{state_name}. Define it with 'state :#{state_name}' first."
          end
        end

        unless @states.include?(to)
          raise ArgumentError, "Unknown state in to: #{to}. Define it with 'state :#{to}' first."
        end

        # Initialize transition configuration
        @transitions[event] = {
          from: from_states,
          to: to,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }

        # If block provided, configure it
        if block_given?
          @current_transition = @transitions[event]
          instance_eval(&block)
          @current_transition = nil
        end
      end

      # Define a check for the current transition.
      #
      # Checks are preconditions that must be true to allow the transition.
      #
      # @overload check(&block)
      #   Check with lambda/proc
      #   @yield Block to evaluate in instance context
      #   @example
      #     check { items.any? && customer.present? }
      #
      # @overload check(method_name)
      #   Check with method
      #   @param method_name [Symbol] Method name to call
      #   @example
      #     check :customer_valid?
      #
      # @overload check(if: predicate)
      #   Check with Statusable predicate
      #   @param if [Symbol] Predicate name (Statusable integration)
      #   @example
      #     check if: :is_ready_for_publishing?
      #
      # @raise [StateableError] If called outside transition block
      # @raise [ArgumentError] If no check provided
      def check(method_name = nil, if: nil, &block)
        raise StateableError, "check can only be called inside a transition block" unless @current_transition

        if block_given?
          @current_transition[:guards] << { type: :block, block: block }
        elsif method_name
          @current_transition[:guards] << { type: :method, method: method_name }
        elsif binding.local_variable_get(:if)
          @current_transition[:guards] << { type: :predicate, predicate: binding.local_variable_get(:if) }
        else
          raise ArgumentError, "check requires either a block, method name, or if: option"
        end
      end

      # Define a validation for the current transition.
      #
      # Validations are executed after guards and before callbacks.
      # They must add errors to the errors object if validation fails.
      #
      # @yield Block to evaluate in instance context
      # @raise [StateableError] If called outside transition block
      # @raise [ArgumentError] If no block provided
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

      # Define a before_transition callback for the current transition.
      #
      # Before_transition callbacks are executed before the state transition.
      #
      # @overload before_transition(&block)
      #   Before_transition callback with lambda/proc
      #   @yield Block to execute
      #   @example
      #     before_transition { calculate_total }
      #
      # @overload before_transition(method_name)
      #   Before_transition callback with method
      #   @param method_name [Symbol] Method name to call
      #   @example
      #     before_transition :calculate_total
      #
      # @raise [StateableError] If called outside transition block
      # @raise [ArgumentError] If no callback provided
      def before_transition(method_name = nil, &block)
        raise StateableError, "before_transition can only be called inside a transition block" unless @current_transition

        if block_given?
          @current_transition[:before_callbacks] << { type: :block, block: block }
        elsif method_name
          @current_transition[:before_callbacks] << { type: :method, method: method_name }
        else
          raise ArgumentError, "before_transition requires either a block or method name"
        end
      end

      # Define an after_transition callback for the current transition.
      #
      # After_transition callbacks are executed after the state transition.
      #
      # @overload after_transition(&block)
      #   After_transition callback with lambda/proc
      #   @yield Block to execute
      #   @example
      #     after_transition { send_notification }
      #
      # @overload after_transition(method_name)
      #   After_transition callback with method
      #   @param method_name [Symbol] Method name to call
      #   @example
      #     after_transition :send_notification
      #
      # @raise [StateableError] If called outside transition block
      # @raise [ArgumentError] If no callback provided
      def after_transition(method_name = nil, &block)
        raise StateableError, "after_transition can only be called inside a transition block" unless @current_transition

        if block_given?
          @current_transition[:after_callbacks] << { type: :block, block: block }
        elsif method_name
          @current_transition[:after_callbacks] << { type: :method, method: method_name }
        else
          raise ArgumentError, "after_transition requires either a block or method name"
        end
      end

      # Define an around callback for the current transition.
      #
      # Around callbacks wrap the state transition.
      # The block receives another block that must be called to execute the transition.
      #
      # @yield Block to execute, receives a block to call
      # @raise [StateableError] If called outside transition block
      # @raise [ArgumentError] If no block provided
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

      # Specify the table name for state transitions.
      #
      # @param name [String, Symbol] Table name
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

      # Return complete configuration.
      #
      # @return [Hash] Configuration with states and transitions
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
