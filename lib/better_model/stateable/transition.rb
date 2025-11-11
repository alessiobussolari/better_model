# frozen_string_literal: true

require_relative "../errors/stateable/check_failed_error"
require_relative "../errors/stateable/validation_failed_error"

module BetterModel
  module Stateable
    # Transition executor for Stateable.
    #
    # Handles the execution of a state transition, including:
    # - Check evaluation
    # - Validation execution
    # - Callback execution (before_transition/after_transition/around)
    # - State update in database
    # - StateTransition record creation for history
    #
    # @api private
    class Transition
      # Initialize a new Transition.
      #
      # @param instance [Object] Model instance
      # @param event [Symbol] Transition event name
      # @param config [Hash] Transition configuration
      # @param metadata [Hash] Additional metadata for transition
      def initialize(instance, event, config, metadata = {})
        @instance = instance
        @event = event
        @config = config
        @metadata = metadata
        @from_state = instance.state.to_sym
        @to_state = config[:to]
      end

      # Execute the transition.
      #
      # @raise [BetterModel::Errors::Stateable::CheckFailedError] If a check fails
      # @raise [BetterModel::Errors::Stateable::ValidationFailedError] If a validation fails
      # @raise [ActiveRecord::RecordInvalid] If save! fails
      # @return [Boolean] true if transition succeeds
      #
      # @example
      #   transition.execute!  # => true
      def execute!
        # 1. Evaluate checks
        evaluate_checks!

        # 2. Execute validations
        execute_validations!

        # 3. Wrap in transaction
        @instance.class.transaction do
          # 4. Execute around callbacks (if present)
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

      # Evaluate all checks.
      #
      # @raise [BetterModel::Errors::Stateable::CheckFailedError] If any check fails
      # @api private
      def evaluate_checks!
        checks = @config[:guards] || []  # Keep :guards for internal compatibility

        checks.each do |check_config|
          check = Guard.new(@instance, check_config)  # Guard class handles the logic

          unless check.evaluate
            raise BetterModel::Errors::Stateable::CheckFailedError, "Check failed for transition #{@event}"
          end
        end
      end

      # Execute all validations.
      #
      # @raise [BetterModel::Errors::Stateable::ValidationFailedError] If validations fail
      # @api private
      def execute_validations!
        validations = @config[:validations] || []
        return if validations.empty?

        # Clear existing errors for this transition
        @instance.errors.clear

        validations.each do |validation_block|
          @instance.instance_exec(&validation_block)
        end

        if @instance.errors.any?
          error_messages = @instance.errors.full_messages.join(", ")
          raise BetterModel::Errors::Stateable::ValidationFailedError, "Validation failed for transition #{@event}: #{error_messages}"
        end
      end

      # Execute around callbacks.
      #
      # @yield Block to wrap with around callbacks
      # @api private
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

      # Perform the actual transition.
      #
      # @api private
      def perform_transition!
        # 1. Execute before_transition callbacks
        execute_callbacks(@config[:before_callbacks] || [])

        # 2. Update state
        @instance.state = @to_state.to_s

        # 3. Save record (validates model)
        @instance.save!

        # 4. Create StateTransition record
        create_state_transition_record

        # 5. Execute after_transition callbacks
        execute_callbacks(@config[:after_callbacks] || [])
      end

      # Execute a list of callbacks.
      #
      # @param callbacks [Array<Hash>] Callback configurations
      # @api private
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

      # Create StateTransition record for history.
      #
      # @api private
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
