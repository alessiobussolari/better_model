# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Searchable Errors", type: :unit do
  # Use Article which has Searchable, Predicable, Sortable properly configured

  describe "InvalidPredicateError" do
    it "is raised when using unknown predicate in search" do
      expect do
        Article.search({ unknown_field_eq: "value" })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPredicateError)
    end

    it "includes error message" do
      begin
        Article.search({ nonexistent_eq: "value" })
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as SearchableError" do
      expect do
        Article.search({ bad_predicate: "value" })
      end.to raise_error(BetterModel::Errors::Searchable::SearchableError)
    end

    it "can be caught as BetterModelError" do
      expect do
        Article.search({ bad_predicate: "value" })
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "InvalidOrderError" do
    it "is raised when using unknown sort order" do
      expect do
        Article.search({}, orders: [ :sort_unknown_asc ])
      end.to raise_error(BetterModel::Errors::Searchable::InvalidOrderError)
    end

    it "includes error message" do
      begin
        Article.search({}, orders: [ :sort_nonexistent_desc ])
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Searchable::InvalidOrderError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as SearchableError" do
      expect do
        Article.search({}, orders: [ :sort_bad_field ])
      end.to raise_error(BetterModel::Errors::Searchable::SearchableError)
    end
  end

  describe "InvalidPaginationError" do
    it "is raised for negative page number" do
      expect do
        Article.search({}, pagination: { page: -1, per_page: 10 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "is raised for page number 0" do
      expect do
        Article.search({}, pagination: { page: 0, per_page: 10 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "is raised for negative per_page" do
      expect do
        Article.search({}, pagination: { per_page: -5 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "is raised for per_page of 0" do
      expect do
        Article.search({}, pagination: { per_page: 0 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "is raised when per_page exceeds max_per_page" do
      # Article has max_per_page: 100 configured
      expect do
        Article.search({}, pagination: { per_page: 101 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "includes error message with details" do
      begin
        Article.search({}, pagination: { page: -1, per_page: 10 })
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as SearchableError" do
      expect do
        Article.search({}, pagination: { page: -1, per_page: 10 })
      end.to raise_error(BetterModel::Errors::Searchable::SearchableError)
    end
  end

  describe "InvalidSecurityError" do
    # Article has security :status_required, [ :status_eq ]
    # Article has security :featured_only, [ :featured_eq ]

    it "is raised when required predicate is missing" do
      expect do
        Article.search({ title_eq: "Test" }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
    end

    it "is not raised when required predicate is present" do
      expect do
        Article.search({ status_eq: "draft" }, security: :status_required)
      end.not_to raise_error
    end

    it "is raised for unknown security policy" do
      expect do
        Article.search({}, security: :nonexistent_policy)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
    end

    it "includes error message with security details" do
      begin
        Article.search({}, security: :status_required)
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as SearchableError" do
      expect do
        Article.search({}, security: :nonexistent)
      end.to raise_error(BetterModel::Errors::Searchable::SearchableError)
    end
  end

  describe "ConfigurationError" do
    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Searchable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with custom message" do
      error = BetterModel::Errors::Searchable::ConfigurationError.new("custom config error")
      expect(error.message).to eq("custom config error")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Searchable::ConfigurationError, "test"
      end.to raise_error(ArgumentError)
    end

    it "does NOT inherit from BetterModelError" do
      expect(BetterModel::Errors::Searchable::ConfigurationError < BetterModel::Errors::BetterModelError).to be_falsy
    end
  end
end
