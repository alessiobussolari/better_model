# frozen_string_literal: true

module BetterModel
  module Stateable
    # Check evaluator for Stateable transitions.
    #
    # Evaluates check conditions to determine if a transition is allowed.
    # Supports three types of checks:
    # - Block: lambda/proc evaluated in instance context
    # - Method: method called on instance
    # - Predicate: integration with Statusable (is_ready?, etc.)
    #
    # @api private
    class Guard
      # Initialize a new Guard.
      #
      # @param instance [Object] Model instance
      # @param guard_config [Hash] Guard configuration hash
      def initialize(instance, guard_config)
        @instance = instance
        @guard_config = guard_config
      end

      # Evaluate the check.
      #
      # @return [Boolean] true if check passes
      # @raise [BetterModel::Errors::Stateable::CheckFailedError] If check fails (optional, context-dependent)
      #
      # @example
      #   guard.evaluate  # => true
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

      # Description of check for error messages.
      #
      # @return [String] Human-readable description
      #
      # @example
      #   guard.description  # => "method check: customer_valid?"
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

      # Evaluate a block check.
      #
      # @return [Boolean] Result of block evaluation
      # @api private
      def evaluate_block
        block = @guard_config[:block]
        @instance.instance_exec(&block)
      end

      # Evaluate a method check.
      #
      # @return [Boolean] Result of method call
      # @raise [NoMethodError] If method not found
      # @api private
      def evaluate_method
        method_name = @guard_config[:method]

        unless @instance.respond_to?(method_name, true)
          raise NoMethodError, "Check method '#{method_name}' not found in #{@instance.class.name}. " \
                               "Define it in your model: def #{method_name}; ...; end"
        end

        @instance.send(method_name)
      end

      # Evaluate a predicate check (Statusable integration).
      #
      # @return [Boolean] Result of predicate call
      # @raise [NoMethodError] If predicate not found
      # @api private
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
