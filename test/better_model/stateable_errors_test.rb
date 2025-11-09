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
      error = BetterModel::Errors::Stateable::NotEnabledError.new
      assert_includes error.message, "Stateable is not enabled"
      assert_includes error.message, "stateable do...end"
    end

    test "NotEnabledError accepts custom message" do
      error = BetterModel::Errors::Stateable::NotEnabledError.new("Custom message")
      assert_equal "Custom message", error.message
    end

    test "InvalidStateError formats state in message" do
      error = BetterModel::Errors::Stateable::InvalidStateError.new(:invalid_state)
      assert_includes error.message, "Invalid state"
      assert_includes error.message, "invalid_state"
    end

    test "InvalidTransitionError formats transition in message" do
      error = BetterModel::Errors::Stateable::InvalidTransitionError.new(:publish, :draft, :published)
      assert_includes error.message, "Cannot transition from"
      assert_includes error.message, "draft"
      assert_includes error.message, "published"
      assert_includes error.message, "publish"
    end

    test "CheckFailedError formats event in message" do
      error = BetterModel::Errors::Stateable::CheckFailedError.new(:publish)
      assert_includes error.message, "Check failed for transition"
      assert_includes error.message, "publish"
    end

    test "CheckFailedError accepts optional description" do
      error = BetterModel::Errors::Stateable::CheckFailedError.new(:publish, "custom check description")
      assert_includes error.message, "Check failed for transition"
      assert_includes error.message, "publish"
      assert_includes error.message, "custom check description"
    end

    test "ValidationFailedError formats errors in message" do
      # Create a mock errors object
      errors = ActiveModel::Errors.new(Article.new)
      errors.add(:base, "First error")
      errors.add(:base, "Second error")

      error = BetterModel::Errors::Stateable::ValidationFailedError.new(:publish, errors)
      assert_includes error.message, "Validation failed for transition"
      assert_includes error.message, "publish"
      assert_includes error.message, "First error"
      assert_includes error.message, "Second error"
    end

    # ========================================
    # ERROR CATCHING TESTS
    # ========================================

    test "StateableError can be caught as StandardError" do
      begin
        raise BetterModel::Errors::Stateable::StateableError, "test"
      rescue StandardError => e
        assert_instance_of BetterModel::Errors::Stateable::StateableError, e
      end
    end

    test "NotEnabledError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::NotEnabledError
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::NotEnabledError, e
      end
    end

    test "InvalidStateError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::InvalidStateError.new(:test)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::InvalidStateError, e
      end
    end

    test "InvalidTransitionError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::InvalidTransitionError.new(:test, :a, :b)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::InvalidTransitionError, e
      end
    end

    test "CheckFailedError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::CheckFailedError.new(:test)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::CheckFailedError, e
      end
    end

    test "GuardFailedError (alias) can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::GuardFailedError.new(:test)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::CheckFailedError, e
      end
    end

    test "ValidationFailedError can be caught as StateableError" do
      errors = ActiveModel::Errors.new(Article.new)
      errors.add(:base, "test")

      begin
        raise BetterModel::Errors::Stateable::ValidationFailedError.new(:test, errors)
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
  end
end
