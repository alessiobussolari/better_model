# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Repositable do
  # Helper repository class
  class ArticleRepository < BetterModel::Repositable::BaseRepository
    def model_class = Article

    def published
      search({ status_eq: "published" })
    end

    def popular(min_views: 150)
      search({ status_eq: "published", view_count_gteq: min_views })
    end

    def recent(days: 7)
      search({ created_at_gteq: days.days.ago })
    end
  end

  let(:repo) { ArticleRepository.new }

  before { Article.delete_all }

  describe "basic functionality" do
    it "is instantiable" do
      expect(repo).to be_a(ArticleRepository)
      expect(repo.model).to eq(Article)
    end

    it "can be initialized with model_class parameter" do
      repo = BetterModel::Repositable::BaseRepository.new(Article)
      expect(repo.model).to eq(Article)
    end

    it "has search method" do
      expect(repo).to respond_to(:search)
    end

    it "has CRUD delegate methods" do
      expect(repo).to respond_to(:find)
      expect(repo).to respond_to(:find_by)
      expect(repo).to respond_to(:create)
      expect(repo).to respond_to(:create!)
      expect(repo).to respond_to(:build)
      expect(repo).to respond_to(:update)
      expect(repo).to respond_to(:delete)
    end

    it "has ActiveRecord delegate methods" do
      expect(repo).to respond_to(:where)
      expect(repo).to respond_to(:all)
      expect(repo).to respond_to(:count)
      expect(repo).to respond_to(:exists?)
    end
  end

  describe "CRUD methods" do
    it "find returns record by id" do
      article = Article.create!(title: "Test", status: "draft")

      found = repo.find(article.id)
      expect(found.id).to eq(article.id)
      expect(found.title).to eq("Test")
    end

    it "find_by returns record by attributes" do
      Article.create!(title: "Test", status: "draft")

      found = repo.find_by(title: "Test")
      expect(found).not_to be_nil
      expect(found.title).to eq("Test")
    end

    it "create creates a new record" do
      article = repo.create(title: "New", status: "draft")

      expect(article.id).not_to be_nil
      expect(article.title).to eq("New")
    end

    it "create! creates a new record" do
      article = repo.create!(title: "New", status: "draft")

      expect(article.id).not_to be_nil
      expect(article.title).to eq("New")
    end

    it "build creates unsaved instance" do
      article = repo.build(title: "Unsaved")

      expect(article.id).to be_nil
      expect(article.title).to eq("Unsaved")
      expect(article).to be_new_record
    end

    it "update updates record by id" do
      article = Article.create!(title: "Original", status: "draft")

      updated = repo.update(article.id, title: "Updated")
      expect(updated.title).to eq("Updated")
      expect(updated.id).to eq(article.id)
    end

    it "delete deletes record by id" do
      article = Article.create!(title: "To Delete", status: "draft")

      repo.delete(article.id)
      expect(Article.find_by(id: article.id)).to be_nil
    end

    it "where delegates to model" do
      Article.create!(title: "Test 1", status: "published")
      Article.create!(title: "Test 2", status: "draft")

      results = repo.where(status: "published")
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Test 1")
    end

    it "all delegates to model" do
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "draft")

      results = repo.all
      expect(results.count).to eq(2)
    end

    it "count delegates to model" do
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "draft")

      expect(repo.count).to eq(2)
    end

    it "exists? delegates to model" do
      article = Article.create!(title: "Test", status: "draft")

      expect(repo.exists?(article.id)).to be true
      expect(repo.exists?(999999)).to be false
    end
  end

  describe "search method - basic" do
    it "without predicates returns all records" do
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "published")

      results = repo.search({})
      expect(results.count).to eq(2)
    end

    it "returns ActiveRecord::Relation by default" do
      results = repo.search({})
      expect(results).to be_a(ActiveRecord::Relation)
    end
  end

  describe "search method - predicates" do
    it "applies single predicate" do
      Article.create!(title: "Published", status: "published")
      Article.create!(title: "Draft", status: "draft")

      results = repo.search({ status_eq: "published" })
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Published")
    end

    it "applies multiple predicates (AND logic)" do
      Article.create!(title: "Rails Guide", status: "published", view_count: 150)
      Article.create!(title: "Ruby Basics", status: "published", view_count: 50)
      Article.create!(title: "Draft Post", status: "draft", view_count: 200)

      results = repo.search({ status_eq: "published", view_count_gteq: 100 })
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Rails Guide")
    end

    it "applies text contains predicate" do
      Article.create!(title: "Ruby on Rails", status: "published")
      Article.create!(title: "Python Basics", status: "published")

      results = repo.search({ title_cont: "Ruby" })
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Ruby on Rails")
    end

    it "applies comparison predicates" do
      Article.create!(title: "Popular", view_count: 150)
      Article.create!(title: "Normal", view_count: 50)
      Article.create!(title: "Unpopular", view_count: 10)

      results_gte = repo.search({ view_count_gteq: 50 })
      expect(results_gte.count).to eq(2)

      results_gt = repo.search({ view_count_gt: 50 })
      expect(results_gt.count).to eq(1)
      expect(results_gt.first.title).to eq("Popular")
    end

    it "applies date predicates" do
      Article.create!(title: "Old", published_at: 30.days.ago)
      Article.create!(title: "Recent", published_at: 5.days.ago)

      results = repo.search({ published_at_gteq: 10.days.ago })
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Recent")
    end

    it "removes nil values from predicates" do
      Article.create!(title: "Test", status: "published")

      results = repo.search({ status_eq: "published", view_count_gt: nil })
      expect(results.count).to eq(1)
    end

    it "preserves false values in predicates" do
      Article.create!(title: "Featured", featured: true)
      Article.create!(title: "Not Featured", featured: false)

      results = repo.search({ featured_eq: false })
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Not Featured")
    end
  end

  describe "search method - pagination" do
    it "uses default pagination" do
      25.times { |i| Article.create!(title: "Article #{i}", status: "draft") }

      results = repo.search({})
      expect(results.count).to eq(20) # Default per_page
    end

    it "applies custom page and per_page" do
      30.times { |i| Article.create!(title: "Article #{i}", status: "draft") }

      page1 = repo.search({}, page: 1, per_page: 10)
      page2 = repo.search({}, page: 2, per_page: 10)

      expect(page1.count).to eq(10)
      expect(page2.count).to eq(10)
      expect(page1.first.id).not_to eq(page2.first.id)
    end
  end

  describe "search method - limit" do
    it "with limit 1 returns single record" do
      Article.create!(title: "First", status: "draft")
      Article.create!(title: "Second", status: "draft")

      result = repo.search({}, limit: 1)
      expect(result).to be_a(Article)
    end

    it "with limit > 1 returns limited relation" do
      10.times { |i| Article.create!(title: "Article #{i}", status: "draft") }

      results = repo.search({}, limit: 5)
      expect(results.count).to eq(5)
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "with limit nil returns all records" do
      25.times { |i| Article.create!(title: "Article #{i}", status: "draft") }

      results = repo.search({}, limit: nil)
      expect(results.count).to eq(25)
    end

    it "limit has priority over pagination" do
      30.times { |i| Article.create!(title: "Article #{i}", status: "draft") }

      results = repo.search({}, page: 1, per_page: 20, limit: 5)
      expect(results.count).to eq(5)
    end
  end

  describe "search method - ordering" do
    it "applies SQL order" do
      Article.create!(title: "Zebra", view_count: 10)
      Article.create!(title: "Apple", view_count: 20)
      Article.create!(title: "Banana", view_count: 30)

      results = repo.search({}, order: "title ASC")
      expect(results.pluck(:title)).to eq([ "Apple", "Banana", "Zebra" ])
    end

    it "applies order hash" do
      Article.create!(title: "Low", view_count: 10)
      Article.create!(title: "High", view_count: 100)
      Article.create!(title: "Medium", view_count: 50)

      results = repo.search({}, order: { view_count: :desc })
      expect(results.pluck(:title)).to eq([ "High", "Medium", "Low" ])
    end

    it "applies order_scope using Sortable" do
      Article.create!(title: "Low", view_count: 10)
      Article.create!(title: "High", view_count: 100)
      Article.create!(title: "Medium", view_count: 50)

      results = repo.search({}, order_scope: { field: :view_count, direction: :desc })
      expect(results.pluck(:title)).to eq([ "High", "Medium", "Low" ])
    end

    it "order_scope has priority over order" do
      Article.create!(title: "A", view_count: 10)
      Article.create!(title: "B", view_count: 20)

      results = repo.search({},
        order: "view_count ASC",
        order_scope: { field: :view_count, direction: :desc }
      )
      expect(results.pluck(:title)).to eq([ "B", "A" ])
    end
  end

  describe "search method - eager loading" do
    it "applies includes for eager loading" do
      author = Author.create!(name: "John", email: "john@example.com")
      Article.create!(title: "Test", author: author)

      results = repo.search({}, includes: [ :author ])

      expect(results.count).to eq(1)
      expect(results.first.author.name).to eq("John")
    end

    it "applies joins" do
      author = Author.create!(name: "John", email: "john@example.com")
      Article.create!(title: "Test", author: author)

      results = repo.search({}, joins: [ :author ])
      expect(results.count).to eq(1)
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "applies both joins and includes" do
      author = Author.create!(name: "John", email: "john@example.com")
      Article.create!(title: "Test", author: author)

      results = repo.search({}, joins: [ :author ], includes: [ :author ])
      expect(results.count).to eq(1)
    end
  end

  describe "custom repository methods" do
    it "can use search" do
      Article.create!(title: "Published 1", status: "published")
      Article.create!(title: "Draft 1", status: "draft")

      results = repo.published
      expect(results.count).to eq(1)
      expect(results.first.status).to eq("published")
    end

    it "can chain ActiveRecord" do
      Article.create!(title: "Rails", status: "published", view_count: 100)
      Article.create!(title: "Ruby", status: "published", view_count: 50)

      results = repo.published.where("view_count > ?", 75)
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Rails")
    end

    it "are composable" do
      Article.create!(title: "Popular", status: "published", view_count: 200)
      Article.create!(title: "Normal", status: "published", view_count: 50)
      Article.create!(title: "Draft", status: "draft", view_count: 300)

      results = repo.popular
      expect(results.count).to eq(1)
      expect(results.first.title).to eq("Popular")
    end
  end

  describe "edge cases" do
    it "handles empty predicates hash" do
      Article.create!(title: "Test", status: "draft")

      expect { repo.search({}) }.not_to raise_error
      expect(repo.search({}).count).to eq(1)
    end

    it "handles nil predicates" do
      Article.create!(title: "Test", status: "draft")

      expect { repo.search(nil) }.not_to raise_error
      expect(repo.search(nil).count).to eq(1)
    end
  end

  describe "error handling" do
    it "find raises RecordNotFound for missing id" do
      expect do
        repo.find(999999)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "update raises RecordNotFound for missing id" do
      expect do
        repo.update(999999, title: "Updated")
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "delete raises RecordNotFound for missing id" do
      expect do
        repo.delete(999999)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "validates predicates with Predicable" do
      Article.create!(title: "Test", status: "draft")

      expect do
        repo.search({ invalid_predicate: "value" })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPredicateError)
    end
  end

  describe "real-world scenarios" do
    it "handles complete API request scenario" do
      Article.create!(title: "Ruby Guide", status: "published", view_count: 150, published_at: 5.days.ago)
      Article.create!(title: "Rails Tutorial", status: "published", view_count: 200, published_at: 3.days.ago)
      Article.create!(title: "Python Basics", status: "published", view_count: 50, published_at: 10.days.ago)
      Article.create!(title: "Draft Post", status: "draft", view_count: 300, published_at: nil)

      results = repo.search(
        {
          status_eq: "published",
          view_count_gteq: 100,
          published_at_gteq: 7.days.ago
        },
        page: 1,
        per_page: 10,
        order_scope: { field: :published_at, direction: :desc }
      )

      expect(results.count).to eq(2)
      expect(results.pluck(:title)).to eq([ "Rails Tutorial", "Ruby Guide" ])
    end

    it "handles multi-step query building scenario" do
      Article.create!(title: "Featured Article", status: "published", featured: true, view_count: 150)
      Article.create!(title: "Normal Article", status: "published", featured: false, view_count: 200)

      # Step 1: Get published articles
      published = repo.search({ status_eq: "published" })
      expect(published.count).to eq(2)

      # Step 2: Further filter for featured
      featured = published.where(featured: true)
      expect(featured.count).to eq(1)
      expect(featured.first.title).to eq("Featured Article")
    end

    it "demonstrates repository pattern encapsulation" do
      Article.create!(title: "Article 1", status: "published", view_count: 100)
      Article.create!(title: "Article 2", status: "published", view_count: 200)

      # Use custom method instead of raw queries
      popular_articles = repo.popular
      expect(popular_articles.count).to eq(1)
      expect(popular_articles.first.view_count).to be >= 150

      # Repositories hide complexity
      recent_articles = repo.recent(days: 30)
      expect(recent_articles).to be_a(ActiveRecord::Relation)
    end
  end
end
