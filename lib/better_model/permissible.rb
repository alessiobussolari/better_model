# frozen_string_literal: true

require_relative "errors/permissible/permissible_error"
require_relative "errors/permissible/configuration_error"

# Permissible - Declarative permissions system for Rails models.
#
# This concern enables defining permissions/capabilities on models using a simple,
# declarative DSL, similar to the Statusable pattern but for operations.
#
# @example Basic Usage
#   class Article < ApplicationRecord
#     include BetterModel::Permissible
#
#     permit :delete, -> { status != "published" }
#     permit :edit, -> { is?(:draft) || is?(:scheduled) }
#     permit :publish, -> { is?(:draft) && valid?(:publication) }
#     permit :archive, -> { is?(:published) && created_at < 1.year.ago }
#   end
#
# @example Checking Permissions
#   article.permit?(:delete)           # => true/false
#   article.permit_delete?             # => true/false
#   article.permit_edit?               # => true/false
#   article.permit_publish?            # => true/false
#
module BetterModel
  module Permissible
    extend ActiveSupport::Concern

    included do
      # Registry of permissions defined for this class
      class_attribute :permit_definitions
      self.permit_definitions = {}
    end

    class_methods do
      # DSL to define permissions.
      #
      # Defines a permission check that can be evaluated against model instances.
      # Automatically creates a convenience method permit_<permission_name>? for each permission.
      #
      # @param permission_name [Symbol, String] Permission identifier (e.g., :delete, :edit)
      # @param condition_proc [Proc, nil] Lambda or proc that defines the condition
      # @yield Alternative to condition_proc parameter
      # @raise [BetterModel::Errors::Permissible::ConfigurationError] If parameters are invalid
      #
      # @example With lambda parameter
      #   permit :delete, -> { status != "published" }
      #
      # @example With block
      #   permit :edit do
      #     is?(:draft)
      #   end
      #
      # @example Complex condition
      #   permit :publish do
      #     is?(:draft) && valid?(:publication)
      #   end
      def permit(permission_name, condition_proc = nil, &block)
        # Validate parameters before converting
        if permission_name.blank?
          raise BetterModel::Errors::Permissible::ConfigurationError, "Permission name cannot be blank"
        end

        permission_name = permission_name.to_sym
        condition = condition_proc || block

        unless condition
          raise BetterModel::Errors::Permissible::ConfigurationError, "Condition proc or block is required"
        end

        unless condition.respond_to?(:call)
          raise BetterModel::Errors::Permissible::ConfigurationError, "Condition must respond to call"
        end

        # Register permission in registry
        self.permit_definitions = permit_definitions.merge(permission_name => condition.freeze).freeze

        # Generate dynamic method permit_#{permission_name}?
        define_permit_method(permission_name)
      end

      # List all permissions defined for this class.
      #
      # @return [Array<Symbol>] Array of defined permission names
      #
      # @example
      #   Article.defined_permissions  # => [:delete, :edit, :publish]
      def defined_permissions = permit_definitions.keys

      # Check if a permission is defined.
      #
      # @param permission_name [Symbol, String] Permission name to check
      # @return [Boolean] true if permission is defined
      #
      # @example
      #   Article.permission_defined?(:delete)  # => true
      def permission_defined?(permission_name) = permit_definitions.key?(permission_name.to_sym)

      private

      # Generate dynamic method permit_#{permission_name}? for each defined permission.
      #
      # @param permission_name [Symbol] Permission name
      # @api private
      def define_permit_method(permission_name)
        method_name = "permit_#{permission_name}?"

        # Avoid redefining methods if they already exist
        return if method_defined?(method_name)

        define_method(method_name) do
          permit?(permission_name)
        end
      end
    end

    # Generic method to check if a permission is granted.
    #
    # Evaluates the permission condition in the context of the model instance.
    # Returns false if permission is not defined (secure by default).
    #
    # @param permission_name [Symbol, String] Permission name to check
    # @return [Boolean] true if permission is granted, false otherwise
    #
    # @example
    #   article.permit?(:delete)  # => true
    def permit?(permission_name)
      permission_name = permission_name.to_sym
      condition = self.class.permit_definitions[permission_name]

      # If permission is not defined, return false (secure by default)
      return false unless condition

      # Evaluate condition in context of model instance
      # Errors propagate naturally - fail fast
      instance_exec(&condition)
    end

    # Returns all available permissions for this instance with their values.
    #
    # @return [Hash{Symbol => Boolean}] Hash with permission names and their granted status
    #
    # @example
    #   article.permissions
    #   # => { delete: true, edit: false, publish: false, archive: false }
    def permissions
      self.class.permit_definitions.each_with_object({}) do |(permission_name, _condition), result|
        result[permission_name] = permit?(permission_name)
      end
    end

    # Check if instance has at least one granted permission.
    #
    # @return [Boolean] true if any permission is granted
    #
    # @example
    #   article.has_any_permission?  # => true
    def has_any_permission? = permissions.values.any?

    # Check if instance has all specified permissions granted.
    #
    # @param permission_names [Array<Symbol>] Permission names to check
    # @return [Boolean] true if all permissions are granted
    #
    # @example
    #   article.has_all_permissions?([:edit, :publish])  # => false
    def has_all_permissions?(permission_names)
      Array(permission_names).all? { |permission_name| permit?(permission_name) }
    end

    # Filter a list of permissions returning only granted ones.
    #
    # @param permission_names [Array<Symbol>] Permission names to filter
    # @return [Array<Symbol>] Granted permissions
    #
    # @example
    #   article.granted_permissions([:edit, :delete, :publish])  # => [:edit]
    def granted_permissions(permission_names)
      Array(permission_names).select { |permission_name| permit?(permission_name) }
    end

    # Override as_json to automatically include permissions if requested.
    #
    # @param options [Hash] Options for as_json
    # @option options [Boolean] :include_permissions Include permissions in JSON output
    # @return [Hash] JSON representation
    #
    # @example
    #   article.as_json(include_permissions: true)
    #   # => { ..., "permissions" => { "delete" => true, "edit" => false } }
    def as_json(options = {})
      result = super

      # Include permissions if explicitly requested, converting symbol keys to strings
      result["permissions"] = permissions.transform_keys(&:to_s) if options[:include_permissions]

      result
    end
  end
end
