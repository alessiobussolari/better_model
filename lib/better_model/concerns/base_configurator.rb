# frozen_string_literal: true

module BetterModel
  module Concerns
    # Base class for BetterModel module configurators
    #
    # This class provides common functionality for all BetterModel configurators,
    # including input validation, default configuration, and configuration freezing.
    #
    # @example Creating a custom configurator
    #   module BetterModel
    #     module CustomModule
    #       class Configurator < BetterModel::Concerns::BaseConfigurator
    #         def initialize(model_class)
    #           super
    #           @custom_options = {}
    #         end
    #
    #         def option(name, value)
    #           validate_symbol!(name, "option name")
    #           @custom_options[name] = value
    #         end
    #
    #         def to_h
    #           { custom_options: @custom_options }
    #         end
    #       end
    #     end
    #   end
    #
    class BaseConfigurator
      # The model class being configured
      # @return [Class]
      attr_reader :model_class

      # Initialize the configurator
      #
      # @param model_class [Class] The model class being configured
      # @raise [ArgumentError] If model_class is nil
      def initialize(model_class)
        raise ArgumentError, "model_class cannot be nil" if model_class.nil?

        @model_class = model_class
      end

      # Return the configuration as a frozen hash
      #
      # Subclasses should override this method to return their specific configuration.
      # The hash will be frozen automatically when the configuration is applied.
      #
      # @return [Hash] The configuration hash
      def to_h
        {}
      end

      protected

      # Validate that a value is a symbol
      #
      # @param value [Object] The value to validate
      # @param name [String] The name of the parameter for error messages
      # @raise [ArgumentError] If the value is not a symbol
      # @return [void]
      def validate_symbol!(value, name)
        raise ArgumentError, "#{name} must be a symbol, got #{value.class}" unless value.is_a?(Symbol)
      end

      # Validate that a value is an array
      #
      # @param value [Object] The value to validate
      # @param name [String] The name of the parameter for error messages
      # @raise [ArgumentError] If the value is not an array
      # @return [void]
      def validate_array!(value, name)
        raise ArgumentError, "#{name} must be an array, got #{value.class}" unless value.is_a?(Array)
      end

      # Validate that a value is a positive integer
      #
      # @param value [Object] The value to validate
      # @param name [String] The name of the parameter for error messages
      # @raise [ArgumentError] If the value is not a positive integer
      # @return [void]
      def validate_positive_integer!(value, name)
        unless value.is_a?(Integer) && value > 0
          raise ArgumentError, "#{name} must be a positive integer, got #{value.inspect}"
        end
      end

      # Validate that a value is a non-negative integer
      #
      # @param value [Object] The value to validate
      # @param name [String] The name of the parameter for error messages
      # @raise [ArgumentError] If the value is not a non-negative integer
      # @return [void]
      def validate_non_negative_integer!(value, name)
        unless value.is_a?(Integer) && value >= 0
          raise ArgumentError, "#{name} must be a non-negative integer, got #{value.inspect}"
        end
      end

      # Validate that a value is a boolean
      #
      # @param value [Object] The value to validate
      # @param name [String] The name of the parameter for error messages
      # @raise [ArgumentError] If the value is not a boolean
      # @return [void]
      def validate_boolean!(value, name)
        unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
          raise ArgumentError, "#{name} must be a boolean, got #{value.class}"
        end
      end

      # Validate that a value is one of the allowed values
      #
      # @param value [Object] The value to validate
      # @param allowed [Array] The allowed values
      # @param name [String] The name of the parameter for error messages
      # @raise [ArgumentError] If the value is not in the allowed list
      # @return [void]
      def validate_inclusion!(value, allowed, name)
        unless allowed.include?(value)
          raise ArgumentError, "#{name} must be one of #{allowed.inspect}, got #{value.inspect}"
        end
      end

      # Check if a column exists on the model
      #
      # @param column_name [Symbol, String] The column name to check
      # @return [Boolean] True if the column exists
      def column_exists?(column_name)
        return false unless model_class.respond_to?(:column_names)
        # Skip check if table doesn't exist (allows eager loading before migrations)
        return false unless model_class.respond_to?(:table_exists?) && model_class.table_exists?

        model_class.column_names.include?(column_name.to_s)
      end

      # Check if a method exists on the model
      #
      # @param method_name [Symbol, String] The method name to check
      # @return [Boolean] True if the method exists
      def method_exists?(method_name)
        model_class.method_defined?(method_name) ||
          model_class.private_method_defined?(method_name)
      end
    end
  end
end
