# frozen_string_literal: true

require "test_helper"

module BetterModel
  module Concerns
    class BaseConfiguratorTest < ActiveSupport::TestCase
      def setup
        # Create a test model class for testing
        @model_class = Class.new(ActiveRecord::Base) do
          self.table_name = "articles"

          def self.name
            "TestModel"
          end

          def custom_method
            true
          end
        end
      end

      # ========================================
      # Initialization Tests
      # ========================================

      test "initializes with model class" do
        configurator = BaseConfigurator.new(@model_class)
        assert_equal @model_class, configurator.model_class
      end

      test "raises ArgumentError when model_class is nil" do
        error = assert_raises(ArgumentError) do
          BaseConfigurator.new(nil)
        end

        assert_equal "model_class cannot be nil", error.message
      end

      test "to_h returns empty hash by default" do
        configurator = BaseConfigurator.new(@model_class)
        assert_equal({}, configurator.to_h)
      end

      # ========================================
      # Symbol Validation Tests
      # ========================================

      test "validate_symbol! passes for valid symbol" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_symbol!, :test, "field name")
        end
      end

      test "validate_symbol! raises for string" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_symbol!, "test", "field name")
        end

        assert_match(/field name must be a symbol/, error.message)
      end

      test "validate_symbol! raises for integer" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_symbol!, 123, "field name")
        end

        assert_match(/field name must be a symbol/, error.message)
      end

      # ========================================
      # Array Validation Tests
      # ========================================

      test "validate_array! passes for valid array" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_array!, [ :a, :b ], "fields")
        end
      end

      test "validate_array! passes for empty array" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_array!, [], "fields")
        end
      end

      test "validate_array! raises for hash" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_array!, { a: 1 }, "fields")
        end

        assert_match(/fields must be an array/, error.message)
      end

      # ========================================
      # Positive Integer Validation Tests
      # ========================================

      test "validate_positive_integer! passes for positive integer" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_positive_integer!, 1, "count")
          configurator.send(:validate_positive_integer!, 100, "count")
        end
      end

      test "validate_positive_integer! raises for zero" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_positive_integer!, 0, "count")
        end

        assert_match(/count must be a positive integer/, error.message)
      end

      test "validate_positive_integer! raises for negative" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_positive_integer!, -1, "count")
        end

        assert_match(/count must be a positive integer/, error.message)
      end

      test "validate_positive_integer! raises for float" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_positive_integer!, 1.5, "count")
        end

        assert_match(/count must be a positive integer/, error.message)
      end

      # ========================================
      # Non-Negative Integer Validation Tests
      # ========================================

      test "validate_non_negative_integer! passes for zero" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_non_negative_integer!, 0, "offset")
        end
      end

      test "validate_non_negative_integer! passes for positive" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_non_negative_integer!, 100, "offset")
        end
      end

      test "validate_non_negative_integer! raises for negative" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_non_negative_integer!, -1, "offset")
        end

        assert_match(/offset must be a non-negative integer/, error.message)
      end

      # ========================================
      # Boolean Validation Tests
      # ========================================

      test "validate_boolean! passes for true" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_boolean!, true, "flag")
        end
      end

      test "validate_boolean! passes for false" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_boolean!, false, "flag")
        end
      end

      test "validate_boolean! raises for truthy value" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_boolean!, 1, "flag")
        end

        assert_match(/flag must be a boolean/, error.message)
      end

      test "validate_boolean! raises for nil" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_boolean!, nil, "flag")
        end

        assert_match(/flag must be a boolean/, error.message)
      end

      # ========================================
      # Inclusion Validation Tests
      # ========================================

      test "validate_inclusion! passes for valid value" do
        configurator = BaseConfigurator.new(@model_class)

        assert_nothing_raised do
          configurator.send(:validate_inclusion!, :asc, [ :asc, :desc ], "direction")
        end
      end

      test "validate_inclusion! raises for invalid value" do
        configurator = BaseConfigurator.new(@model_class)

        error = assert_raises(ArgumentError) do
          configurator.send(:validate_inclusion!, :invalid, [ :asc, :desc ], "direction")
        end

        assert_match(/direction must be one of/, error.message)
        assert_match(/:asc/, error.message)
        assert_match(/:desc/, error.message)
      end

      # ========================================
      # Column Exists Tests
      # ========================================

      test "column_exists? returns true for existing column" do
        configurator = BaseConfigurator.new(@model_class)
        assert configurator.send(:column_exists?, :title)
      end

      test "column_exists? returns false for non-existing column" do
        configurator = BaseConfigurator.new(@model_class)
        refute configurator.send(:column_exists?, :nonexistent_column)
      end

      test "column_exists? works with string column name" do
        configurator = BaseConfigurator.new(@model_class)
        assert configurator.send(:column_exists?, "title")
      end

      # ========================================
      # Method Exists Tests
      # ========================================

      test "method_exists? returns true for existing method" do
        configurator = BaseConfigurator.new(@model_class)
        assert configurator.send(:method_exists?, :custom_method)
      end

      test "method_exists? returns false for non-existing method" do
        configurator = BaseConfigurator.new(@model_class)
        refute configurator.send(:method_exists?, :nonexistent_method)
      end

      # ========================================
      # Subclass Inheritance Tests
      # ========================================

      test "subclass can override to_h" do
        custom_configurator = Class.new(BaseConfigurator) do
          def initialize(model_class)
            super
            @custom_value = "test"
          end

          def to_h
            { custom_value: @custom_value }
          end
        end

        configurator = custom_configurator.new(@model_class)
        assert_equal({ custom_value: "test" }, configurator.to_h)
      end

      test "subclass can use validation methods" do
        custom_configurator = Class.new(BaseConfigurator) do
          def configure_option(name)
            validate_symbol!(name, "option name")
            @options ||= []
            @options << name
          end

          def to_h
            { options: @options || [] }
          end
        end

        configurator = custom_configurator.new(@model_class)
        configurator.configure_option(:option1)
        configurator.configure_option(:option2)

        assert_equal({ options: [ :option1, :option2 ] }, configurator.to_h)
      end
    end
  end
end
