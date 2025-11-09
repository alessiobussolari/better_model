# frozen_string_literal: true

module BetterModel
  module Validatable
    # Configurator for Validatable DSL.
    #
    # This configurator enables defining validations declaratively
    # within the `validatable do...end` block.
    #
    # @example
    #   validatable do
    #     # Basic validations
    #     check :title, :content, presence: true
    #     check :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    #
    #     # Complex validations
    #     check_complex :valid_pricing
    #     check_complex :stock_check
    #
    #     # Validation groups
    #     validation_group :step1, [:email, :password]
    #     validation_group :step2, [:first_name, :last_name]
    #   end
    #
    # @api private
    class Configurator
      attr_reader :groups

      # Initialize a new Configurator.
      #
      # @param model_class [Class] Model class being configured
      def initialize(model_class)
        @model_class = model_class
        @complex_validations = []
        @groups = {}
      end

      # Define standard validations on fields.
      #
      # Delegates to ActiveRecord's validates method.
      #
      # @param fields [Array<Symbol>] Field names
      # @param options [Hash] Validation options (presence, format, etc.)
      #
      # @example
      #   check :title, :content, presence: true
      #   check :email, format: { with: URI::MailTo::EMAIL_REGEXP }
      #   check :age, numericality: { greater_than: 0 }
      #
      def check(*fields, **options)
        @model_class.validates(*fields, **options)
      end

      # Use a registered complex validation.
      #
      # Complex validations must be registered first using
      # register_complex_validation in the model.
      #
      # @param name [Symbol] Name of registered complex validation
      # @raise [ArgumentError] If validation is not registered
      #
      # @example
      #   # In model (registration):
      #   register_complex_validation :valid_pricing do
      #     if sale_price.present? && sale_price >= price
      #       errors.add(:sale_price, "must be less than regular price")
      #     end
      #   end
      #
      #   # In configurator (usage):
      #   validatable do
      #     check_complex :valid_pricing
      #   end
      #
      def check_complex(name)
        unless @model_class.complex_validation?(name)
          raise ArgumentError, "Unknown complex validation: #{name}. Use register_complex_validation to define it first."
        end

        @complex_validations << name.to_sym
      end

      # Define a validation group.
      #
      # Groups allow validating only a subset of fields,
      # useful for multi-step forms or partial validations.
      #
      # @param group_name [Symbol] Group name
      # @param fields [Array<Symbol>] Fields included in group
      # @raise [ArgumentError] If group name is invalid, fields not array, or group already defined
      #
      # @example
      #   validation_group :step1, [:email, :password]
      #   validation_group :step2, [:first_name, :last_name]
      #   validation_group :step3, [:address, :city, :zip_code]
      #
      # @example Usage
      #   user.valid?(:step1)  # Validate only email and password
      #   user.errors_for_group(:step1)
      #
      def validation_group(group_name, fields)
        raise ArgumentError, "Group name must be a symbol" unless group_name.is_a?(Symbol)
        raise ArgumentError, "Fields must be an array" unless fields.is_a?(Array)
        raise ArgumentError, "Group already defined: #{group_name}" if @groups.key?(group_name)

        @groups[group_name] = {
          name: group_name,
          fields: fields
        }
      end

      # Return complete configuration.
      #
      # @return [Hash] Configuration with all validations
      def to_h
        {
          complex_validations: @complex_validations
        }
      end
    end
  end
end
