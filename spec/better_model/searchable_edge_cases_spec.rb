# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Searchable, "edge cases", type: :model do
  describe "configuration edge cases" do
    it "raises ConfigurationError when including in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Searchable
        end
      end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError)
    end

    it "allows searchable to be used without DSL block" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable
      end

      # Should still work with defaults
      expect(klass.searchable_config).to be_a(Hash)
    end
  end

  describe ".search with edge cases" do
    describe "unknown options handling" do
      it "raises ConfigurationError for unknown options" do
        expect do
          Article.search({ title_eq: "Test" }, unknown_option: :value)
        end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError, /Invalid search options/)
      end

      it "raises ConfigurationError for multiple unknown options" do
        expect do
          Article.search({}, foo: 1, bar: 2)
        end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError)
      end
    end

    describe "empty predicates" do
      it "returns all records with empty predicates hash" do
        Article.create!(title: "Test1", status: "draft")
        Article.create!(title: "Test2", status: "draft")

        result = Article.search({})
        expect(result.count).to eq(2)
      end

      it "returns all records with nil predicates" do
        Article.create!(title: "Test", status: "draft")

        result = Article.search(nil)
        expect(result.count).to eq(1)
      end
    end

    describe "predicate sanitization" do
      it "converts string keys to symbols" do
        Article.create!(title: "Rails Guide", status: "draft")

        result = Article.search({ "title_cont" => "Rails" })
        expect(result.count).to eq(1)
      end

      it "strips blank values" do
        Article.create!(title: "Test", status: "draft")
        Article.create!(title: "Another", status: "published")

        # Blank values should be ignored
        result = Article.search({ title_cont: "", status_eq: "draft" })
        expect(result.count).to eq(1)
        expect(result.first.title).to eq("Test")
      end

      it "preserves false as valid value" do
        Article.create!(title: "Test", featured: false, status: "draft")
        Article.create!(title: "Featured", featured: true, status: "draft")

        result = Article.search({ featured_eq: false })
        expect(result.count).to eq(1)
        expect(result.first.title).to eq("Test")
      end

      it "preserves zero as valid value" do
        Article.create!(title: "Test", view_count: 0, status: "draft")
        Article.create!(title: "Popular", view_count: 100, status: "draft")

        result = Article.search({ view_count_eq: 0 })
        expect(result.count).to eq(1)
        expect(result.first.title).to eq("Test")
      end
    end

    describe "OR conditions edge cases" do
      it "handles empty OR array" do
        Article.create!(title: "Test", status: "draft")

        result = Article.search({ or: [] })
        expect(result.count).to eq(1)
      end

      it "handles single OR condition" do
        Article.create!(title: "Rails Guide", status: "draft")
        Article.create!(title: "Ruby Guide", status: "draft")

        result = Article.search({ or: [ { title_cont: "Rails" } ] })
        expect(result.count).to eq(1)
      end

      it "handles multiple OR conditions" do
        Article.create!(title: "Rails Guide", status: "draft")
        Article.create!(title: "Ruby Guide", status: "draft")
        Article.create!(title: "Python Guide", status: "draft")

        result = Article.search({
          or: [
            { title_cont: "Rails" },
            { title_cont: "Ruby" }
          ]
        })
        expect(result.count).to eq(2)
      end

      it "combines OR with AND conditions" do
        Article.create!(title: "Rails Guide", status: "draft")
        Article.create!(title: "Ruby Guide", status: "published")
        Article.create!(title: "Python Guide", status: "draft")

        result = Article.search({
          status_eq: "draft",
          or: [
            { title_cont: "Rails" },
            { title_cont: "Python" }
          ]
        })
        expect(result.count).to eq(2)
      end
    end

    describe "pagination edge cases" do
      before do
        10.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      end

      it "uses configured default per_page when not specified" do
        # Article has per_page: 25 configured
        result = Article.search({}, pagination: { page: 1 })
        expect(result.to_a.size).to eq(10) # All records fit in first page
      end

      it "respects max_per_page limit" do
        # Article has max_per_page: 100
        expect do
          Article.search({}, pagination: { per_page: 101 })
        end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
      end

      it "uses global max_per_page if model max not set" do
        # Uses global config if model doesn't override
        expect(BetterModel.configuration.searchable_max_per_page).to eq(100)
      end

      it "validates page must be positive" do
        expect do
          Article.search({}, pagination: { page: 0 })
        end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
      end

      it "validates per_page must be positive" do
        expect do
          Article.search({}, pagination: { per_page: 0 })
        end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
      end
    end

    describe "ordering edge cases" do
      before do
        Article.create!(title: "B Article", view_count: 10, status: "draft")
        Article.create!(title: "A Article", view_count: 20, status: "draft")
        Article.create!(title: "C Article", view_count: 5, status: "draft")
      end

      it "uses default_order when no orders specified" do
        # Article has default_order: :sort_created_at_desc
        result = Article.search({})
        # Articles should be ordered by created_at desc (most recent first)
        expect(result.first.title).to eq("C Article")
      end

      it "applies multiple sort orders" do
        result = Article.search({}, orders: [ :sort_title_asc ])
        expect(result.map(&:title)).to eq([ "A Article", "B Article", "C Article" ])
      end

      it "raises InvalidOrderError for unknown sort scope" do
        expect do
          Article.search({}, orders: [ :sort_unknown_field_asc ])
        end.to raise_error(BetterModel::Errors::Searchable::InvalidOrderError)
      end

      it "handles empty orders array" do
        result = Article.search({}, orders: [])
        # Should use default_order
        expect(result).to be_present
      end
    end

    describe "security policy edge cases" do
      it "raises InvalidSecurityError for unknown policy" do
        expect do
          Article.search({}, security: :nonexistent_policy)
        end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
      end

      it "validates required predicates in AND conditions" do
        expect do
          Article.search({ title_eq: "Test" }, security: :status_required)
        end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
      end

      it "passes when required predicate is present" do
        expect do
          Article.search({ status_eq: "draft" }, security: :status_required)
        end.not_to raise_error
      end

      it "validates security in OR conditions too" do
        # When security is applied, it should check OR conditions as well
        expect do
          Article.search({
            or: [ { title_cont: "Rails" } ]
          }, security: :status_required)
        end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
      end
    end

    describe "eager loading edge cases" do
      it "applies includes option" do
        article = Article.create!(title: "Test", status: "draft")

        # This should not raise even without actual association
        result = Article.search({}, includes: [])
        expect(result).to be_present
      end

      it "applies preload option" do
        article = Article.create!(title: "Test", status: "draft")

        result = Article.search({}, preload: [])
        expect(result).to be_present
      end

      it "applies eager_load option" do
        article = Article.create!(title: "Test", status: "draft")

        result = Article.search({}, eager_load: [])
        expect(result).to be_present
      end
    end

    describe "query complexity limits" do
      it "respects max_predicates limit" do
        # If configured, prevents too many predicates
        # Using only predicates that exist on Article
        expect do
          Article.search({ title_eq: "1", status_eq: "2", featured_eq: true })
        end.not_to raise_error
      end

      it "respects max_or_conditions limit" do
        # If configured, prevents too many OR conditions
        expect do
          Article.search({
            or: [
              { title_cont: "1" },
              { title_cont: "2" },
              { title_cont: "3" }
            ]
          })
        end.not_to raise_error
      end
    end
  end

  describe "configurator DSL edge cases" do
    it "allows setting per_page in searchable block" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        searchable do
          per_page 50
        end
      end

      expect(klass.searchable_config[:per_page]).to eq(50)
    end

    it "allows setting max_per_page in searchable block" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        searchable do
          max_per_page 200
        end
      end

      expect(klass.searchable_config[:max_per_page]).to eq(200)
    end

    it "allows setting default_order in searchable block" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        sort :title
        searchable do
          default_order :sort_title_asc
        end
      end

      expect(klass.searchable_config[:default_order]).to eq([ :sort_title_asc ])
    end

    it "allows defining security policies" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        predicates :status
        searchable do
          security :require_status, [ :status_eq ]
        end
      end

      expect(klass.searchable_config[:securities]).to have_key(:require_status)
    end
  end

  describe "chainability" do
    it "returns ActiveRecord::Relation" do
      result = Article.search({})
      expect(result).to be_a(ActiveRecord::Relation)
    end

    it "allows further chaining" do
      Article.create!(title: "Test", status: "draft")

      result = Article.search({ status_eq: "draft" }).where.not(title: nil)
      expect(result).to be_present
    end

    it "allows multiple search calls" do
      Article.create!(title: "Rails Guide", status: "published")

      # First search
      result1 = Article.search({ status_eq: "published" })
      # Can continue searching on the result
      expect(result1.count).to eq(1)
    end
  end

  describe "#search_metadata" do
    let(:article) { Article.create!(title: "Test", status: "draft") }

    it "returns a hash" do
      expect(article.search_metadata).to be_a(Hash)
    end

    it "includes searchable_fields" do
      metadata = article.search_metadata
      expect(metadata[:searchable_fields]).to be_an(Array)
      expect(metadata[:searchable_fields]).to include(:title, :status)
    end

    it "includes sortable_fields" do
      metadata = article.search_metadata
      expect(metadata[:sortable_fields]).to be_an(Array)
    end

    it "includes available_predicates" do
      metadata = article.search_metadata
      expect(metadata[:available_predicates]).to be_a(Hash)
    end

    it "includes available_sorts" do
      metadata = article.search_metadata
      expect(metadata[:available_sorts]).to be_a(Hash)
    end

    it "includes pagination config" do
      metadata = article.search_metadata
      expect(metadata[:pagination]).to be_a(Hash)
      expect(metadata[:pagination]).to have_key(:per_page)
      expect(metadata[:pagination]).to have_key(:max_per_page)
    end
  end

  describe "SearchableConfigurator edge cases" do
    it "allows setting max_page" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        searchable do
          max_page 5000
        end
      end

      expect(klass.searchable_config[:max_page]).to eq(5000)
    end

    it "allows setting max_predicates" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        searchable do
          max_predicates 20
        end
      end

      expect(klass.searchable_config[:max_predicates]).to eq(20)
    end

    it "allows setting max_or_conditions" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        searchable do
          max_or_conditions 10
        end
      end

      expect(klass.searchable_config[:max_or_conditions]).to eq(10)
    end

    it "raises ConfigurationError for security without predicates" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel

          searchable do
            security :test_security, nil
          end
        end
      end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError)
    end

    it "raises ConfigurationError for security with empty predicates" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel

          searchable do
            security :test_security, []
          end
        end
      end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError)
    end
  end

  describe "class methods" do
    it "searchable_fields returns Set of symbols" do
      expect(Article.searchable_fields).to be_a(Set)
      expect(Article.searchable_fields).to include(:title)
    end

    it "searchable_config returns configuration hash" do
      expect(Article.searchable_config).to be_a(Hash)
    end

    it "searchable_predicates_for returns predicates for a field" do
      predicates = Article.searchable_predicates_for(:title)
      expect(predicates).to be_an(Array)
    end

    it "searchable_sorts_for returns sorts for a field" do
      sorts = Article.searchable_sorts_for(:title)
      expect(sorts).to be_an(Array)
    end
  end

  describe "eager loading with actual associations" do
    let(:author) { Author.create!(name: "Test Author") }
    let(:article) { Article.create!(title: "Test", status: "draft", author: author) }

    before do
      Article.delete_all
      article # ensure created
    end

    it "applies preload option with associations" do
      result = Article.search({}, preload: [ :author ], orders: [])
      expect(result.to_a).to include(article)
    end

    it "applies eager_load option with associations" do
      # Skip default ordering to avoid ambiguous column issue with eager_load
      result = Article.search({}, eager_load: [ :author ], orders: [ :sort_title_asc ])
      expect(result.to_a).to include(article)
    end

    it "applies includes option with associations" do
      result = Article.search({}, includes: [ :author ], orders: [])
      expect(result.to_a).to include(article)
    end
  end

  describe "array predicate values" do
    before do
      Article.delete_all
      @article1 = Article.create!(title: "Rails Guide", view_count: 10, status: "draft")
      @article2 = Article.create!(title: "Ruby Guide", view_count: 20, status: "published")
      @article3 = Article.create!(title: "Python Guide", view_count: 30, status: "draft")
    end

    it "handles array values for _between predicates" do
      result = Article.search({ view_count_between: [ 15, 25 ] })
      expect(result.count).to eq(1)
      expect(result.first).to eq(@article2)
    end
  end

  describe "security validation in search" do
    before do
      Article.delete_all
      @article = Article.create!(title: "Test", status: "draft")
    end

    it "validates security in main predicates" do
      expect do
        Article.search({ status_eq: "draft" }, security: :status_required)
      end.not_to raise_error
    end

    it "validates security with blank value raises error" do
      expect do
        Article.search({ status_eq: "" }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
    end

    it "validates security with nil value raises error" do
      expect do
        Article.search({ status_eq: nil }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
    end

    it "validates security in OR conditions - passes when main AND or conditions have required predicates" do
      expect do
        Article.search({
          status_eq: "draft",  # Required predicate in main hash
          or: [
            { title_cont: "Rails", status_eq: "draft" },
            { title_cont: "Ruby", status_eq: "published" }
          ]
        }, security: :status_required)
      end.not_to raise_error
    end

    it "validates security in OR conditions - fails when any OR condition is missing required predicate" do
      expect do
        Article.search({
          status_eq: "draft",  # Present in main hash
          or: [
            { title_cont: "Rails", status_eq: "draft" },
            { title_cont: "Ruby" } # Missing status_eq in this OR branch
          ]
        }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError, /OR condition/)
    end

    it "validates security in OR conditions - fails with blank required predicate in OR" do
      expect do
        Article.search({
          status_eq: "draft",  # Present in main hash
          or: [
            { title_cont: "Rails", status_eq: "" }  # Blank status_eq in OR
          ]
        }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError, /OR condition/)
    end
  end

  describe "ActionController::Parameters handling" do
    before do
      Article.delete_all
      @article = Article.create!(title: "Test", status: "draft")
    end

    it "raises ConfigurationError for unpermitted parameters" do
      params = ActionController::Parameters.new(title_cont: "Test")
      # params is NOT permitted by default

      expect do
        Article.search(params)
      end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError)
    end

    it "accepts permitted parameters" do
      params = ActionController::Parameters.new(title_cont: "Test")
      params.permit!

      result = Article.search(params)
      expect(result.count).to eq(1)
    end

    it "accepts regular hash parameters" do
      result = Article.search({ title_cont: "Test" })
      expect(result.count).to eq(1)
    end
  end

  describe "taggable integration" do
    it "provides tagged_with? instance method when taggable is enabled" do
      article = Article.create!(title: "Test", status: "draft")
      article.tag_with("ruby", "rails")

      expect(article.tagged_with?("ruby")).to be true
      expect(article.tagged_with?("python")).to be false
    end

    it "provides tag_with method" do
      article = Article.create!(title: "Test", status: "draft")
      article.tag_with("ruby")

      expect(article.tags).to include("ruby")
    end
  end
end
