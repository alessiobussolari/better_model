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
      error = BetterModel::Errors::Stateable::NotEnabledError.new(module_name: "Stateable", method_called: "transition_to!")
      assert_includes error.message, "Stateable is not enabled"
      assert_includes error.message, "stateable do...end"
    end

    test "NotEnabledError formats method in message" do
      error = BetterModel::Errors::Stateable::NotEnabledError.new(module_name: "Stateable", method_called: "transition_to!")
      assert_includes error.message, "transition_to!"
    end

    test "InvalidStateError formats state in message" do
      error = BetterModel::Errors::Stateable::InvalidStateError.new(state: :invalid_state)
      assert_includes error.message, "Invalid state"
      assert_includes error.message, "invalid_state"
    end

    test "InvalidTransitionError formats transition in message" do
      error = BetterModel::Errors::Stateable::InvalidTransitionError.new(event: :publish, from_state: :draft, to_state: :published)
      assert_includes error.message, "Cannot transition from"
      assert_includes error.message, "draft"
      assert_includes error.message, "published"
      assert_includes error.message, "publish"
    end

    test "CheckFailedError formats event in message" do
      error = BetterModel::Errors::Stateable::CheckFailedError.new(event: :publish)
      assert_includes error.message, "Check failed for transition"
      assert_includes error.message, "publish"
    end

    test "CheckFailedError accepts optional description" do
      error = BetterModel::Errors::Stateable::CheckFailedError.new(event: :publish, check_description: "custom check description")
      assert_includes error.message, "Check failed for transition"
      assert_includes error.message, "publish"
      assert_includes error.message, "custom check description"
    end

    test "ValidationFailedError formats errors in message" do
      # Create a mock errors object
      errors = ActiveModel::Errors.new(Article.new)
      errors.add(:base, "First error")
      errors.add(:base, "Second error")

      error = BetterModel::Errors::Stateable::ValidationFailedError.new(event: :publish, errors_object: errors)
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
        raise BetterModel::Errors::Stateable::StateableError.new("test")
      rescue StandardError => e
        assert_instance_of BetterModel::Errors::Stateable::StateableError, e
      end
    end

    test "NotEnabledError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::NotEnabledError.new(module_name: "Stateable", method_called: "test")
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::NotEnabledError, e
      end
    end

    test "InvalidStateError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::InvalidStateError.new(state: :test)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::InvalidStateError, e
      end
    end

    test "InvalidTransitionError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::InvalidTransitionError.new(event: :test, from_state: :a, to_state: :b)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::InvalidTransitionError, e
      end
    end

    test "CheckFailedError can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::CheckFailedError.new(event: :test)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::CheckFailedError, e
      end
    end

    test "GuardFailedError (alias) can be caught as StateableError" do
      begin
        raise BetterModel::Errors::Stateable::GuardFailedError.new(event: :test)
      rescue BetterModel::Errors::Stateable::StateableError => e
        assert_instance_of BetterModel::Errors::Stateable::CheckFailedError, e
      end
    end

    test "ValidationFailedError can be caught as StateableError" do
      errors = ActiveModel::Errors.new(Article.new)
      errors.add(:base, "test")

      begin
        raise BetterModel::Errors::Stateable::ValidationFailedError.new(event: :test, errors_object: errors)
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
    # SENTRY INTEGRATION TESTS (v3.0+)
    # ========================================

    test "InvalidTransitionError includes sentry-compatible tags" do
      error = BetterModel::Errors::Stateable::InvalidTransitionError.new(
        event: :publish,
        from_state: :draft,
        to_state: :published,
        model_class: Article
      )

      assert_equal "transition", error.tags[:error_category]
      assert_equal "stateable", error.tags[:module]
      assert_equal "publish", error.tags[:event]
      assert_equal "draft", error.tags[:from_state]
      assert_equal "published", error.tags[:to_state]
    end

    test "InvalidTransitionError includes sentry-compatible context and extra" do
      error = BetterModel::Errors::Stateable::InvalidTransitionError.new(
        event: :publish,
        from_state: :draft,
        to_state: :published,
        model_class: Article
      )

      assert_equal "Article", error.context[:model_class]
      assert_equal :publish, error.extra[:event]
      assert_equal :draft, error.extra[:from_state]
      assert_equal :published, error.extra[:to_state]
    end

    test "InvalidTransitionError provides attribute readers" do
      error = BetterModel::Errors::Stateable::InvalidTransitionError.new(
        event: :publish,
        from_state: :draft,
        to_state: :published,
        model_class: Article
      )

      assert_equal :publish, error.event
      assert_equal :draft, error.from_state
      assert_equal :published, error.to_state
      assert_equal Article, error.model_class
    end

    test "CheckFailedError includes sentry-compatible data" do
      error = BetterModel::Errors::Stateable::CheckFailedError.new(
        event: :publish,
        check_description: "Must be complete",
        check_type: "predicate",
        current_state: :draft,
        model_class: Article
      )

      assert_equal "check_failed", error.tags[:error_category]
      assert_equal "stateable", error.tags[:module]
      assert_equal "publish", error.tags[:event]
      assert_equal "predicate", error.tags[:check_type]
      assert_equal "Article", error.context[:model_class]
      assert_equal :draft, error.context[:current_state]
    end

    test "ValidationFailedError includes sentry-compatible data" do
      errors = ActiveModel::Errors.new(Article.new)
      errors.add(:title, "can't be blank")

      error = BetterModel::Errors::Stateable::ValidationFailedError.new(
        event: :publish,
        errors_object: errors,
        current_state: :draft,
        target_state: :published,
        model_class: Article
      )

      assert_equal "validation", error.tags[:error_category]
      assert_equal "stateable", error.tags[:module]
      assert_equal "publish", error.tags[:event]
      assert_equal "Article", error.context[:model_class]
      assert_equal :draft, error.context[:current_state]
      assert_equal :published, error.context[:target_state]
      assert_equal [:title], error.extra[:error_fields]
    end

    test "InvalidStateError includes sentry-compatible data" do
      error = BetterModel::Errors::Stateable::InvalidStateError.new(
        state: :unknown,
        available_states: [:draft, :published, :archived],
        model_class: Article
      )

      assert_equal "invalid_state", error.tags[:error_category]
      assert_equal "stateable", error.tags[:module]
      assert_equal "Article", error.context[:model_class]
      assert_equal :unknown, error.extra[:state]
      assert_equal [:draft, :published, :archived], error.extra[:available_states]
    end

    test "NotEnabledError includes sentry-compatible data" do
      error = BetterModel::Errors::Stateable::NotEnabledError.new(
        module_name: "Stateable",
        method_called: "transition_to!",
        model_class: Article
      )

      assert_equal "not_enabled", error.tags[:error_category]
      assert_equal "stateable", error.tags[:module]
      assert_equal "Article", error.context[:model_class]
      assert_equal "Stateable", error.context[:module_name]
      assert_equal "transition_to!", error.extra[:method_called]
    end

    test "ConfigurationError includes sentry-compatible data" do
      error = BetterModel::Errors::Stateable::ConfigurationError.new(
        reason: "Unknown transition",
        model_class: Article
      )

      assert_equal "configuration", error.tags[:error_category]
      assert_equal "stateable", error.tags[:module]
      assert_equal "Article", error.context[:model_class]
      assert_equal "Unknown transition", error.extra[:reason]
    end
  end
end
