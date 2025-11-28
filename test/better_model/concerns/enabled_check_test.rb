# frozen_string_literal: true

require "test_helper"

module BetterModel
  module Concerns
    class EnabledCheckTest < ActiveSupport::TestCase
      # Test error class
      class TestNotEnabledError < StandardError; end

      def setup
        # Create a test class that includes the EnabledCheck concern
        @test_class = Class.new do
          include BetterModel::Concerns::EnabledCheck

          class_attribute :test_module_enabled, default: false

          def self.test_module_enabled?
            test_module_enabled
          end
        end
      end

      # ========================================
      # Instance Method Tests
      # ========================================

      test "ensure_module_enabled! raises error when module is not enabled" do
        instance = @test_class.new

        error = assert_raises(TestNotEnabledError) do
          instance.ensure_module_enabled!(:test_module, TestNotEnabledError)
        end

        assert_equal "Module is not enabled", error.message
      end

      test "ensure_module_enabled! does not raise when module is enabled" do
        @test_class.test_module_enabled = true
        instance = @test_class.new

        assert_nothing_raised do
          instance.ensure_module_enabled!(:test_module, TestNotEnabledError)
        end
      end

      test "ensure_module_enabled! uses custom message when provided" do
        instance = @test_class.new

        error = assert_raises(TestNotEnabledError) do
          instance.ensure_module_enabled!(:test_module, TestNotEnabledError, message: "Custom error message")
        end

        assert_equal "Custom error message", error.message
      end

      test "if_module_enabled returns default when module is not enabled" do
        instance = @test_class.new

        result = instance.if_module_enabled(:test_module, default: "default_value") do
          "block_value"
        end

        assert_equal "default_value", result
      end

      test "if_module_enabled returns nil by default when module is not enabled" do
        instance = @test_class.new

        result = instance.if_module_enabled(:test_module) do
          "block_value"
        end

        assert_nil result
      end

      test "if_module_enabled executes block when module is enabled" do
        @test_class.test_module_enabled = true
        instance = @test_class.new

        result = instance.if_module_enabled(:test_module, default: "default_value") do
          "block_value"
        end

        assert_equal "block_value", result
      end

      test "if_module_enabled returns nil when enabled but no block given" do
        @test_class.test_module_enabled = true
        instance = @test_class.new

        result = instance.if_module_enabled(:test_module, default: "default_value")

        assert_nil result
      end

      # ========================================
      # Class Method Tests
      # ========================================

      test "class ensure_module_enabled! raises error when module is not enabled" do
        error = assert_raises(TestNotEnabledError) do
          @test_class.ensure_module_enabled!(:test_module, TestNotEnabledError)
        end

        assert_equal "Module is not enabled", error.message
      end

      test "class ensure_module_enabled! does not raise when module is enabled" do
        @test_class.test_module_enabled = true

        assert_nothing_raised do
          @test_class.ensure_module_enabled!(:test_module, TestNotEnabledError)
        end
      end

      test "class ensure_module_enabled! uses custom message when provided" do
        error = assert_raises(TestNotEnabledError) do
          @test_class.ensure_module_enabled!(:test_module, TestNotEnabledError, message: "Custom class error")
        end

        assert_equal "Custom class error", error.message
      end

      test "class if_module_enabled returns default when module is not enabled" do
        result = @test_class.if_module_enabled(:test_module, default: []) do
          ["item1", "item2"]
        end

        assert_equal [], result
      end

      test "class if_module_enabled executes block when module is enabled" do
        @test_class.test_module_enabled = true

        result = @test_class.if_module_enabled(:test_module, default: []) do
          ["item1", "item2"]
        end

        assert_equal ["item1", "item2"], result
      end

      # ========================================
      # Edge Cases
      # ========================================

      test "handles missing enabled method gracefully by raising error" do
        # Create a class without the enabled method
        test_class_without_method = Class.new do
          include BetterModel::Concerns::EnabledCheck
        end
        instance = test_class_without_method.new

        error = assert_raises(TestNotEnabledError) do
          instance.ensure_module_enabled!(:nonexistent_module, TestNotEnabledError)
        end

        assert_equal "Module is not enabled", error.message
      end

      test "if_module_enabled handles missing enabled method by returning default" do
        test_class_without_method = Class.new do
          include BetterModel::Concerns::EnabledCheck
        end
        instance = test_class_without_method.new

        result = instance.if_module_enabled(:nonexistent_module, default: "fallback") do
          "block_value"
        end

        assert_equal "fallback", result
      end

      test "works with different default types" do
        instance = @test_class.new

        # Test with array default
        result = instance.if_module_enabled(:test_module, default: [])
        assert_equal [], result

        # Test with hash default
        result = instance.if_module_enabled(:test_module, default: {})
        assert_equal({}, result)

        # Test with false default
        result = instance.if_module_enabled(:test_module, default: false)
        assert_equal false, result

        # Test with empty string default
        result = instance.if_module_enabled(:test_module, default: "")
        assert_equal "", result
      end
    end
  end
end
