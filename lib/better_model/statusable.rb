# frozen_string_literal: true

require_relative "errors/statusable/statusable_error"
require_relative "errors/statusable/configuration_error"

# Statusable - Declarative status system for Rails models.
#
# This concern enables defining statuses on models using a simple, declarative DSL
# similar to the Enrichable pattern but for statuses.
#
# @example Basic Usage
#   class Communications::Consult < ApplicationRecord
#     include BetterModel::Statusable
#
#     is :pending, -> { status == 'initialized' }
#     is :active_session, -> { status == 'active' && !expired? }
#     is :expired, -> { expires_at.present? && expires_at <= Time.current }
#     is :scheduled, -> { scheduled_at.present? }
#     is :immediate, -> { scheduled_at.blank? }
#     is :ready_to_start, -> { scheduled? && scheduled_at <= Time.current }
#   end
#
# @example Checking Statuses
#   consult.is?(:pending)           # => true/false
#   consult.is_pending?             # => true/false
#   consult.is_active_session?      # => true/false
#   consult.is_expired?             # => true/false
#   consult.is_scheduled?           # => true/false
#
module BetterModel
  module Statusable
    extend ActiveSupport::Concern

    included do
      # Registry of statuses defined for this class
      class_attribute :is_definitions
      self.is_definitions = {}
    end

    class_methods do
      # DSL to define statuses.
      #
      # Defines a status check that can be evaluated against model instances.
      # Automatically creates a convenience method is_<status_name>? for each status.
      #
      # @param status_name [Symbol, String] Status identifier (e.g., :pending, :active)
      # @param condition_proc [Proc, nil] Lambda or proc that defines the condition
      # @yield Alternative to condition_proc parameter
      # @raise [BetterModel::Errors::Statusable::ConfigurationError] If parameters are invalid
      #
      # @example With lambda parameter
      #   is :pending, -> { status == 'initialized' }
      #
      # @example With block
      #   is :expired do
      #     expires_at.present? && expires_at <= Time.current
      #   end
      #
      # @example Complex condition
      #   is :ready do
      #     scheduled_at.present? && scheduled_at <= Time.current
      #   end
      def is(status_name, condition_proc = nil, &block)
        # Validate parameters before converting
        if status_name.blank?
          raise BetterModel::Errors::Statusable::ConfigurationError.new(
            reason: "Status name cannot be blank",
            model_class: self
          )
        end

        status_name = status_name.to_sym
        condition = condition_proc || block

        unless condition
          raise BetterModel::Errors::Statusable::ConfigurationError.new(
            reason: "Condition proc or block is required",
            model_class: self
          )
        end

        unless condition.respond_to?(:call)
          raise BetterModel::Errors::Statusable::ConfigurationError.new(
            reason: "Condition must respond to call",
            model_class: self,
            provided: condition.class
          )
        end

        # Register status in registry
        self.is_definitions = is_definitions.merge(status_name => condition.freeze).freeze

        # Generate dynamic method is_#{status_name}?
        define_is_method(status_name)
      end

      # List all statuses defined for this class.
      #
      # @return [Array<Symbol>] Array of defined status names
      def defined_statuses = is_definitions.keys

      # Check if a status is defined.
      #
      # @param status_name [Symbol, String] Status name to check
      # @return [Boolean] true if status is defined
      def status_defined?(status_name) = is_definitions.key?(status_name.to_sym)

      private

      # Generate dynamic method is_#{status_name}? for each defined status.
      #
      # @param status_name [Symbol] Status name
      # @api private
      def define_is_method(status_name)
        method_name = "is_#{status_name}?"

        # Avoid redefining methods if they already exist
        return if method_defined?(method_name)

        define_method(method_name) do
          is?(status_name)
        end
      end
    end

    # Generic method to check if a status is active.
    #
    # Evaluates the status condition in the context of the model instance.
    # Returns false if status is not defined (secure by default).
    #
    # @param status_name [Symbol, String] Status name to check
    # @return [Boolean] true if status is active, false otherwise
    #
    # @example
    #   consult.is?(:pending)  # => true
    def is?(status_name)
      status_name = status_name.to_sym
      condition = self.class.is_definitions[status_name]

      # If status is not defined, return false (secure by default)
      return false unless condition

      # Evaluate condition in context of model instance
      # Errors propagate naturally - fail fast
      instance_exec(&condition)
    end

    # Returns all available statuses for this instance with their values.
    #
    # @return [Hash{Symbol => Boolean}] Hash with status names and their active state
    #
    # @example
    #   consult.statuses
    #   # => { pending: true, active: false, expired: false, scheduled: true }
    def statuses
      self.class.is_definitions.each_with_object({}) do |(status_name, _condition), result|
        result[status_name] = is?(status_name)
      end
    end

    # Check if instance has at least one active status.
    #
    # @return [Boolean] true if any status is active
    def has_any_status? = statuses.values.any?

    # Check if instance has all specified statuses active.
    #
    # @param status_names [Array<Symbol>] Status names to check
    # @return [Boolean] true if all statuses are active
    def has_all_statuses?(status_names)
      Array(status_names).all? { |status_name| is?(status_name) }
    end

    # Filter a list of statuses returning only active ones.
    #
    # @param status_names [Array<Symbol>] Status names to filter
    # @return [Array<Symbol>] Active statuses
    def active_statuses(status_names)
      Array(status_names).select { |status_name| is?(status_name) }
    end

    # Override as_json to automatically include statuses if requested.
    #
    # @param options [Hash] Options for as_json
    # @option options [Boolean] :include_statuses Include statuses in JSON output
    # @return [Hash] JSON representation
    def as_json(options = {})
      result = super

      # Include statuses if explicitly requested, converting symbol keys to strings
      result["statuses"] = statuses.transform_keys(&:to_s) if options[:include_statuses]

      result
    end
  end
end
