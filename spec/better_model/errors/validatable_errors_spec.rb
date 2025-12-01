# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Validatable Errors", type: :unit do
  # Use Article which has Validatable properly configured

  describe "NotEnabledError" do
    def create_validatable_only_class(name_suffix)
      Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Validatable
        # Validatable is included but not configured
      end.tap do |klass|
        Object.const_set("ValidatableOnlyTest#{name_suffix}", klass)
      end
    end

    after do
      Object.constants.grep(/^ValidatableOnlyTest/).each do |const|
        Object.send(:remove_const, const)
      end
    end

    it "is raised when calling validate_group without validatable enabled" do
      test_class = create_validatable_only_class("NotEnabled1")
      article = test_class.new(title: "Test")

      expect do
        article.validate_group(:step1)
      end.to raise_error(BetterModel::Errors::Validatable::NotEnabledError)
    end

    it "is raised when calling errors_for_group without validatable enabled" do
      test_class = create_validatable_only_class("NotEnabled2")
      article = test_class.new(title: "Test")

      expect do
        article.errors_for_group(:step1)
      end.to raise_error(BetterModel::Errors::Validatable::NotEnabledError)
    end

    it "includes helpful message with method name" do
      test_class = create_validatable_only_class("NotEnabled4")
      article = test_class.new(title: "Test")

      begin
        article.validate_group(:step1)
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Validatable::NotEnabledError => e
        expect(e.message).to include("not enabled")
      end
    end

    it "can be caught as ValidatableError" do
      test_class = create_validatable_only_class("NotEnabled5")
      article = test_class.new(title: "Test")

      expect do
        article.validate_group(:step1)
      end.to raise_error(BetterModel::Errors::Validatable::ValidatableError)
    end

    it "can be caught as BetterModelError" do
      test_class = create_validatable_only_class("NotEnabled6")
      article = test_class.new(title: "Test")

      expect do
        article.validate_group(:step1)
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "ConfigurationError" do
    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Validatable::ConfigurationError).to be < ArgumentError
    end

    it "is raised when including Validatable in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Validatable
        end
      end.to raise_error(BetterModel::Errors::Validatable::ConfigurationError)
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Validatable::ConfigurationError, "config error"
      end.to raise_error(ArgumentError)
    end

    it "does NOT inherit from BetterModelError" do
      expect(BetterModel::Errors::Validatable::ConfigurationError < BetterModel::Errors::BetterModelError).to be_falsy
    end

    it "can be instantiated with custom message" do
      error = BetterModel::Errors::Validatable::ConfigurationError.new("custom config issue")
      expect(error.message).to eq("custom config issue")
    end
  end

  describe "Validation group operations with Article" do
    it "returns false for unknown validation group" do
      article = Article.new(title: "Test")
      result = article.validate_group(:nonexistent_group)

      expect(result).to be false
    end

    it "validates correctly when group is valid" do
      article = Article.new(title: "Test")
      result = article.validate_group(:basic_info)

      expect(result).to be true
    end

    it "returns errors for specific group" do
      article = Article.new(title: nil)
      article.valid?
      errors = article.errors_for_group(:basic_info)

      expect(errors).to be_a(ActiveModel::Errors)
    end
  end
end
