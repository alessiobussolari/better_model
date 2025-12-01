# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stateable Errors", type: :unit do
  # Helper to create stateable test classes
  def create_stateable_class(name_suffix, &block)
    const_name = "StateableErrorTest#{name_suffix}"
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name)

    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel

      def self.model_name
        ActiveModel::Name.new(self, nil, "Article")
      end
    end

    Object.const_set(const_name, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  # Helper to create class with Stateable included but not enabled
  def create_stateable_only_class(name_suffix)
    const_name = "StateableOnlyTest#{name_suffix}"
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name)

    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Stateable
    end

    Object.const_set(const_name, klass)
    klass
  end

  after do
    Object.constants.grep(/^StateableErrorTest/).each do |const|
      Object.send(:remove_const, const) rescue nil
    end
    Object.constants.grep(/^StateableOnlyTest/).each do |const|
      Object.send(:remove_const, const) rescue nil
    end
  end

  before do
    ActiveRecord::Base.connection.execute("DELETE FROM state_transitions")
  end

  describe "InvalidTransitionError" do
    let(:test_class) do
      create_stateable_class("InvalidTrans") do
        stateable do
          state :draft, initial: true
          state :published
          state :archived
          transition :publish, from: :draft, to: :published
          transition :archive, from: :published, to: :archived
        end
      end
    end

    it "is raised when transition is not allowed from current state" do
      article = test_class.create!(title: "Test")

      expect do
        article.archive!
      end.to raise_error(BetterModel::Errors::Stateable::InvalidTransitionError)
    end

    it "is raised when trying to transition with unknown event" do
      article = test_class.create!(title: "Test")

      # Unknown events raise ConfigurationError, not InvalidTransitionError
      expect do
        article.transition_to!(:unknown_event)
      end.to raise_error(BetterModel::Errors::Stateable::ConfigurationError)
    end

    it "includes error message with transition details" do
      article = test_class.create!(title: "Test")

      begin
        article.archive!
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as StateableError" do
      article = test_class.create!(title: "Test")

      expect do
        article.archive!
      end.to raise_error(BetterModel::Errors::Stateable::StateableError)
    end

    it "can be caught as BetterModelError" do
      article = test_class.create!(title: "Test")

      expect do
        article.archive!
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "CheckFailedError" do
    let(:test_class) do
      create_stateable_class("CheckFailed") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            check { content.present? }
          end
        end
      end
    end

    it "is raised when transition check fails" do
      article = test_class.create!(title: "Test", content: nil)

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)
    end

    it "has GuardFailedError alias for backward compatibility" do
      expect do
        raise BetterModel::Errors::Stateable::GuardFailedError, "guard failed"
      end.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)
    end

    it "includes error message" do
      article = test_class.create!(title: "Test", content: nil)

      begin
        article.publish!
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Stateable::CheckFailedError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as StateableError" do
      article = test_class.create!(title: "Test", content: nil)

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::StateableError)
    end
  end

  describe "ValidationFailedError" do
    let(:test_class) do
      create_stateable_class("ValidationFailed") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            validate { errors.add(:base, "Custom validation error") }
          end
        end
      end
    end

    it "is raised when validation fails during transition" do
      article = test_class.create!(title: "Test")

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::ValidationFailedError)
    end

    it "includes validation errors in message" do
      article = test_class.create!(title: "Test")

      begin
        article.publish!
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Stateable::ValidationFailedError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as StateableError" do
      article = test_class.create!(title: "Test")

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::StateableError)
    end
  end

  describe "NotEnabledError" do
    it "is raised when calling transition_to! without stateable enabled" do
      test_class = create_stateable_only_class("NotEnabled1")
      article = test_class.create!(title: "Test", status: "draft")

      expect do
        article.transition_to!(:publish)
      end.to raise_error(BetterModel::Errors::Stateable::NotEnabledError)
    end

    it "is raised when calling transition_history without stateable enabled" do
      test_class = create_stateable_only_class("NotEnabled2")
      article = test_class.create!(title: "Test", status: "draft")

      expect do
        article.transition_history
      end.to raise_error(BetterModel::Errors::Stateable::NotEnabledError)
    end

    it "includes helpful message" do
      test_class = create_stateable_only_class("NotEnabled4")
      article = test_class.create!(title: "Test", status: "draft")

      begin
        article.transition_to!(:publish)
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Stateable::NotEnabledError => e
        expect(e.message).to include("not enabled")
      end
    end

    it "can be caught as StateableError" do
      test_class = create_stateable_only_class("NotEnabled5")
      article = test_class.create!(title: "Test", status: "draft")

      expect do
        article.transition_history
      end.to raise_error(BetterModel::Errors::Stateable::StateableError)
    end
  end

  describe "InvalidStateError" do
    # InvalidStateError is defined but not currently used in the implementation.
    # These tests verify the error class is properly configured for future use.

    it "inherits from StateableError" do
      expect(BetterModel::Errors::Stateable::InvalidStateError).to be < BetterModel::Errors::Stateable::StateableError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Stateable::InvalidStateError.new("invalid state")
      expect(error.message).to eq("invalid state")
    end

    it "can be caught as StateableError" do
      expect do
        raise BetterModel::Errors::Stateable::InvalidStateError, "test"
      end.to raise_error(BetterModel::Errors::Stateable::StateableError)
    end

    it "can be caught as BetterModelError" do
      expect do
        raise BetterModel::Errors::Stateable::InvalidStateError, "test"
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "ConfigurationError" do
    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Stateable::ConfigurationError).to be < ArgumentError
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Stateable::ConfigurationError, "config error"
      end.to raise_error(ArgumentError)
    end

    it "does NOT inherit from BetterModelError" do
      expect(BetterModel::Errors::Stateable::ConfigurationError < BetterModel::Errors::BetterModelError).to be_falsy
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Stateable::ConfigurationError.new("config issue")
      expect(error.message).to eq("config issue")
    end
  end
end
