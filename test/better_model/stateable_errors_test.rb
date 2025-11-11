# frozen_string_literal: true

require "test_helper"

module BetterModel
  class StateableErrorsTest < ActiveSupport::TestCase
    # ========================================
    # ERROR CLASS EXISTENCE TESTS
    # ========================================

    test "StateableError class exists" do
      assert defined?(BetterModel::Errors::Stateable::StateableError)
    end

    test "NotEnabledError class exists" do
      assert defined?(BetterModel::Errors::Stateable::NotEnabledError)
    end

    test "InvalidStateError class exists" do
      assert defined?(BetterModel::Errors::Stateable::InvalidStateError)
    end

    test "InvalidTransitionError class exists" do
      assert defined?(BetterModel::Errors::Stateable::InvalidTransitionError)
    end

    test "CheckFailedError class exists" do
      assert defined?(BetterModel::Errors::Stateable::CheckFailedError)
    end

    test "GuardFailedError class exists (alias)" do
      assert defined?(BetterModel::Errors::Stateable::GuardFailedError)
    end

    test "ValidationFailedError class exists" do
      assert defined?(BetterModel::Errors::Stateable::ValidationFailedError)
    end

    # ========================================
    # INHERITANCE TESTS
    # ========================================

    test "StateableError inherits from StandardError" do
      assert BetterModel::Errors::Stateable::StateableError < StandardError
    end

    test "NotEnabledError inherits from StateableError" do
      assert BetterModel::Errors::Stateable::NotEnabledError < BetterModel::Errors::Stateable::StateableError
    end

    test "InvalidStateError inherits from StateableError" do
      assert BetterModel::Errors::Stateable::InvalidStateError < BetterModel::Errors::Stateable::StateableError
    end

    test "InvalidTransitionError inherits from StateableError" do
      assert BetterModel::Errors::Stateable::InvalidTransitionError < BetterModel::Errors::Stateable::StateableError
    end

    test "CheckFailedError inherits from StateableError" do
      assert BetterModel::Errors::Stateable::CheckFailedError < BetterModel::Errors::Stateable::StateableError
    end

    test "ValidationFailedError inherits from StateableError" do
      assert BetterModel::Errors::Stateable::ValidationFailedError < BetterModel::Errors::Stateable::StateableError
    end

    # ========================================
    # ALIAS TEST
    # ========================================

    test "GuardFailedError is an alias for CheckFailedError" do
      assert_equal BetterModel::Errors::Stateable::CheckFailedError, BetterModel::Errors::Stateable::GuardFailedError
    end

    # ========================================
    # ERROR INSTANTIATION TESTS
    # ========================================

    test "StateableError can be instantiated" do
      error = BetterModel::Errors::Stateable::StateableError.new("test message")
      assert_equal "test message", error.message
    end

    test "NotEnabledError has default message" do
      error = BetterModel::Errors::Stateable::NotEnabledError.new("Module is not enabled")
      assert_includes error.message, "Module is not enabled"
    end

    test "InvalidStateError has descriptive message" do
      error = BetterModel::Errors::Stateable::InvalidStateError.new("Invalid state: invalid_state")
      assert_includes error.message, "Invalid state"
      assert_includes error.message, "invalid_state"
    end

    test "InvalidTransitionError has descriptive message" do
      error = BetterModel::Errors::Stateable::InvalidTransitionError.new("Cannot transition from draft to published via publish")
      assert_includes error.message, "Cannot transition from"
      assert_includes error.message, "draft"
      assert_includes error.message, "published"
      assert_includes error.message, "publish"
    end

    test "CheckFailedError has descriptive message" do
      error = BetterModel::Errors::Stateable::CheckFailedError.new("Check failed for transition publish")
      assert_includes error.message, "Check failed for transition"
      assert_includes error.message, "publish"
    end

    test "ValidationFailedError has descriptive message" do
      error = BetterModel::Errors::Stateable::ValidationFailedError.new("Validation failed for transition publish: Title can't be blank")
      assert_includes error.message, "Validation failed for transition"
      assert_includes error.message, "publish"
      assert_includes error.message, "Title can't be blank"
    end

    # ========================================
    # ERROR CATCHING TESTS
    # ========================================

    test "StateableError can be caught as StandardError" do
      begin
        raise BetterModel::Errors::Stateable::StateableError.new("test")
      rescue StandardError => e
        assert_instance_of BetterModel::Errors::Stateable::StateableError, e
      end
    end

    test "NotEnabledError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::NotEnabledError.new("test message")
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::NotEnabledError, e
      end
    end

    test "InvalidStateError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::InvalidStateError.new("test message")
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::InvalidStateError, e
      end
    end

    test "InvalidTransitionError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::InvalidTransitionError.new("test message")
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::InvalidTransitionError, e
      end
    end

    test "CheckFailedError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::CheckFailedError.new("test message")
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::CheckFailedError, e
      end
    end

    test "GuardFailedError (alias) can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::GuardFailedError.new("test message")
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::CheckFailedError, e
      end
    end

    test "ValidationFailedError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::ValidationFailedError.new("test message")
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::ValidationFailedError, e
      end
    end

    # ========================================
    # NAMESPACE TESTS
    # ========================================

    test "all errors are in BetterModel::Stateable namespace" do
      assert_equal "BetterModel::Errors::Stateable::StateableError", BetterModel::Errors::Stateable::StateableError.name
      assert_equal "BetterModel::Errors::Stateable::NotEnabledError", BetterModel::Errors::Stateable::NotEnabledError.name
      assert_equal "BetterModel::Errors::Stateable::InvalidStateError", BetterModel::Errors::Stateable::InvalidStateError.name
      assert_equal "BetterModel::Errors::Stateable::InvalidTransitionError", BetterModel::Errors::Stateable::InvalidTransitionError.name
      assert_equal "BetterModel::Errors::Stateable::CheckFailedError", BetterModel::Errors::Stateable::CheckFailedError.name
      assert_equal "BetterModel::Errors::Stateable::ValidationFailedError", BetterModel::Errors::Stateable::ValidationFailedError.name
    end

    # ========================================
    # SIMPLIFIED ERROR SYSTEM TESTS (v3.0+)
    # ========================================
    # Note: v3.0 simplified error system removed Sentry-specific attributes
    # Errors now use standard Ruby exception messages only

    test "errors use standard exception message format" do
      error = BetterModel::Errors::Stateable::InvalidTransitionError.new("Cannot transition from draft to published via publish")
      assert_equal "Cannot transition from draft to published via publish", error.message
    end

    test "errors can be raised with simple string messages" do
      assert_raises(BetterModel::Errors::Stateable::NotEnabledError) do
        raise BetterModel::Errors::Stateable::NotEnabledError, "Module is not enabled"
      end
    end

    test "errors inherit standard Ruby exception behavior" do
      error = BetterModel::Errors::Stateable::CheckFailedError.new("Check failed")
      assert_respond_to error, :message
      assert_respond_to error, :backtrace
      assert_respond_to error, :cause
    end
  end
end
