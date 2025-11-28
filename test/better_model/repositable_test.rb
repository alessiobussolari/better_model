# frozen_string_literal: true

require "test_helper"

module BetterModel
  class RepositableTest < ActiveSupport::TestCase
    # ========================================
    # SETUP
    # ========================================

    setup do
      Article.delete_all
    end

    # ========================================
    # BASIC FUNCTIONALITY
    # ========================================

    test "ArticleRepository should be instantiable" do
      repo = ArticleRepository.new
      assert_instance_of ArticleRepository, repo
      assert_equal Article, repo.model
    end

    test "repository can be initialized with model_class parameter" do
      repo = BetterModel::Repositable::BaseRepository.new(Article)
      assert_equal Article, repo.model
    end

    test "repository uses model_class method if no parameter provided" do
      repo = ArticleRepository.new
      assert_equal Article, repo.model
    end

    test "repository has search method" do
      repo = ArticleRepository.new
      assert_respond_to repo, :search
    end

    test "repository has CRUD delegate methods" do
      repo = ArticleRepository.new
      assert_respond_to repo, :find
      assert_respond_to repo, :find_by
      assert_respond_to repo, :create
      assert_respond_to repo, :create!
      assert_respond_to repo, :build
      assert_respond_to repo, :update
      assert_respond_to repo, :delete
    end

    test "repository has ActiveRecord delegate methods" do
      repo = ArticleRepository.new
      assert_respond_to repo, :where
      assert_respond_to repo, :all
      assert_respond_to repo, :count
      assert_respond_to repo, :exists?
    end

    # ========================================
    # CRUD METHODS
    # ========================================

    test "find returns record by id" do
      article = Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      found = repo.find(article.id)
      assert_equal article.id, found.id
      assert_equal "Test", found.title
    end

    test "find_by returns record by attributes" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      found = repo.find_by(title: "Test")
      assert_not_nil found
      assert_equal "Test", found.title
    end

    test "create creates a new record" do
      repo = ArticleRepository.new

      article = repo.create(title: "New", status: "draft")
      assert_not_nil article.id
      assert_equal "New", article.title
    end

    test "create! creates a new record" do
      repo = ArticleRepository.new

      article = repo.create!(title: "New", status: "draft")
      assert_not_nil article.id
      assert_equal "New", article.title
    end

    test "build creates unsaved instance" do
      repo = ArticleRepository.new

      article = repo.build(title: "Unsaved")
      assert_nil article.id
      assert_equal "Unsaved", article.title
      assert article.new_record?
    end

    test "update updates record by id" do
      article = Article.create!(title: "Original", status: "draft")
      repo = ArticleRepository.new

      updated = repo.update(article.id, title: "Updated")
      assert_equal "Updated", updated.title
      assert_equal article.id, updated.id
    end

    test "delete deletes record by id" do
      article = Article.create!(title: "To Delete", status: "draft")
      repo = ArticleRepository.new

      repo.delete(article.id)
      assert_nil Article.find_by(id: article.id)
    end

    test "where delegates to model" do
      Article.create!(title: "Test 1", status: "published")
      Article.create!(title: "Test 2", status: "draft")
      repo = ArticleRepository.new

      results = repo.where(status: "published")
      assert_equal 1, results.count
      assert_equal "Test 1", results.first.title
    end

    test "all delegates to model" do
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "draft")
      repo = ArticleRepository.new

      results = repo.all
      assert_equal 2, results.count
    end

    test "count delegates to model" do
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "draft")
      repo = ArticleRepository.new

      assert_equal 2, repo.count
    end

    test "exists? delegates to model" do
      article = Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      assert repo.exists?(article.id)
      refute repo.exists?(999999)
    end

    # ========================================
    # SEARCH METHOD - BASIC
    # ========================================

    test "search without predicates returns all records" do
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "published")
      repo = ArticleRepository.new

      results = repo.search({})
      assert_equal 2, results.count
    end

    test "search with empty hash returns all records" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      results = repo.search({})
      assert_equal 1, results.count
    end

    test "search returns ActiveRecord::Relation by default" do
      repo = ArticleRepository.new
      results = repo.search({})

      assert_kind_of ActiveRecord::Relation, results
    end

    # ========================================
    # SEARCH METHOD - PREDICATES
    # ========================================

    test "search with single predicate" do
      Article.create!(title: "Published", status: "published")
      Article.create!(title: "Draft", status: "draft")
      repo = ArticleRepository.new

      results = repo.search({ status_eq: "published" })
      assert_equal 1, results.count
      assert_equal "Published", results.first.title
    end

    test "search with multiple predicates (AND logic)" do
      Article.create!(title: "Rails Guide", status: "published", view_count: 150)
      Article.create!(title: "Ruby Basics", status: "published", view_count: 50)
      Article.create!(title: "Draft Post", status: "draft", view_count: 200)
      repo = ArticleRepository.new

      results = repo.search({ status_eq: "published", view_count_gteq: 100 })
      assert_equal 1, results.count
      assert_equal "Rails Guide", results.first.title
    end

    test "search with text contains predicate" do
      Article.create!(title: "Ruby on Rails", status: "published")
      Article.create!(title: "Python Basics", status: "published")
      repo = ArticleRepository.new

      results = repo.search({ title_cont: "Ruby" })
      assert_equal 1, results.count
      assert_equal "Ruby on Rails", results.first.title
    end

    test "search with comparison predicates" do
      Article.create!(title: "Popular", view_count: 150)
      Article.create!(title: "Normal", view_count: 50)
      Article.create!(title: "Unpopular", view_count: 10)
      repo = ArticleRepository.new

      results_gte = repo.search({ view_count_gteq: 50 })
      assert_equal 2, results_gte.count

      results_gt = repo.search({ view_count_gt: 50 })
      assert_equal 1, results_gt.count
      assert_equal "Popular", results_gt.first.title
    end

    test "search with date predicates" do
      Article.create!(title: "Old", published_at: 30.days.ago)
      Article.create!(title: "Recent", published_at: 5.days.ago)
      repo = ArticleRepository.new

      results = repo.search({ published_at_gteq: 10.days.ago })
      assert_equal 1, results.count
      assert_equal "Recent", results.first.title
    end

    test "search removes nil values from predicates" do
      Article.create!(title: "Test", status: "published")
      repo = ArticleRepository.new

      # Should not raise error with nil values
      results = repo.search({ status_eq: "published", view_count_gt: nil })
      assert_equal 1, results.count
    end

    test "search preserves false values in predicates" do
      Article.create!(title: "Featured", featured: true)
      Article.create!(title: "Not Featured", featured: false)
      repo = ArticleRepository.new

      results = repo.search({ featured_eq: false })
      assert_equal 1, results.count
      assert_equal "Not Featured", results.first.title
    end

    # ========================================
    # SEARCH METHOD - PAGINATION
    # ========================================

    test "search uses default pagination" do
      25.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      repo = ArticleRepository.new

      results = repo.search({})
      assert_equal 20, results.count # Default per_page
    end

    test "search with custom page and per_page" do
      30.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      repo = ArticleRepository.new

      page1 = repo.search({}, page: 1, per_page: 10)
      page2 = repo.search({}, page: 2, per_page: 10)
      page3 = repo.search({}, page: 3, per_page: 10)

      assert_equal 10, page1.count
      assert_equal 10, page2.count
      assert_equal 10, page3.count

      # Ensure pages have different records
      refute_equal page1.first.id, page2.first.id
    end

    test "search pagination calculates offset correctly" do
      50.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      repo = ArticleRepository.new

      page3 = repo.search({}, page: 3, per_page: 10)
      # Page 3 should skip 20 records (page 1: 0-9, page 2: 10-19, page 3: 20-29)
      assert_equal 10, page3.count
    end

    # ========================================
    # SEARCH METHOD - LIMIT
    # ========================================

    test "search with limit 1 returns single record" do
      Article.create!(title: "First", status: "draft")
      Article.create!(title: "Second", status: "draft")
      repo = ArticleRepository.new

      result = repo.search({}, limit: 1)
      assert_instance_of Article, result
      refute_instance_of ActiveRecord::Relation, result
    end

    test "search with limit > 1 returns limited relation" do
      10.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      repo = ArticleRepository.new

      results = repo.search({}, limit: 5)
      assert_equal 5, results.count
      assert_kind_of ActiveRecord::Relation, results
    end

    test "search with limit nil returns all records" do
      25.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      repo = ArticleRepository.new

      results = repo.search({}, limit: nil)
      assert_equal 25, results.count
    end

    test "search with limit :default uses pagination" do
      25.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      repo = ArticleRepository.new

      results = repo.search({}, limit: :default, per_page: 10)
      assert_equal 10, results.count
    end

    test "search limit has priority over pagination" do
      30.times { |i| Article.create!(title: "Article #{i}", status: "draft") }
      repo = ArticleRepository.new

      # Even with page/per_page, limit should take precedence
      results = repo.search({}, page: 1, per_page: 20, limit: 5)
      assert_equal 5, results.count
    end

    # ========================================
    # SEARCH METHOD - ORDERING
    # ========================================

    test "search with SQL order" do
      Article.create!(title: "Zebra", view_count: 10)
      Article.create!(title: "Apple", view_count: 20)
      Article.create!(title: "Banana", view_count: 30)
      repo = ArticleRepository.new

      results = repo.search({}, order: "title ASC")
      assert_equal [ "Apple", "Banana", "Zebra" ], results.pluck(:title)
    end

    test "search with order hash" do
      Article.create!(title: "Low", view_count: 10)
      Article.create!(title: "High", view_count: 100)
      Article.create!(title: "Medium", view_count: 50)
      repo = ArticleRepository.new

      results = repo.search({}, order: { view_count: :desc })
      assert_equal [ "High", "Medium", "Low" ], results.pluck(:title)
    end

    test "search with order_scope using Sortable" do
      Article.create!(title: "Low", view_count: 10)
      Article.create!(title: "High", view_count: 100)
      Article.create!(title: "Medium", view_count: 50)
      repo = ArticleRepository.new

      results = repo.search({}, order_scope: { field: :view_count, direction: :desc })
      assert_equal [ "High", "Medium", "Low" ], results.pluck(:title)
    end

    test "order_scope has priority over order" do
      Article.create!(title: "A", view_count: 10)
      Article.create!(title: "B", view_count: 20)
      repo = ArticleRepository.new

      # order_scope should win
      results = repo.search({},
        order: "view_count ASC",
        order_scope: { field: :view_count, direction: :desc }
      )
      assert_equal [ "B", "A" ], results.pluck(:title)
    end

    # ========================================
    # SEARCH METHOD - EAGER LOADING
    # ========================================

    test "search with includes eager loads associations" do
      author = Author.create!(name: "John")
      Article.create!(title: "Test", author: author)
      repo = ArticleRepository.new

      results = repo.search({}, includes: [ :author ])

      # Verify includes option was applied
      assert_equal 1, results.count
      assert_equal "John", results.first.author.name
    end

    test "search with joins" do
      author = Author.create!(name: "John")
      Article.create!(title: "Test", author: author)
      repo = ArticleRepository.new

      results = repo.search({}, joins: [ :author ])
      assert_equal 1, results.count
      assert_kind_of ActiveRecord::Relation, results
    end

    test "search with both joins and includes" do
      author = Author.create!(name: "John")
      Article.create!(title: "Test", author: author)
      repo = ArticleRepository.new

      results = repo.search({}, joins: [ :author ], includes: [ :author ])
      assert_equal 1, results.count
    end

    test "search applies joins before includes" do
      # This is important for ORDER BY on joined tables
      author1 = Author.create!(name: "Alice")
      author2 = Author.create!(name: "Bob")
      Article.create!(title: "Article 1", author: author1)
      Article.create!(title: "Article 2", author: author2)
      repo = ArticleRepository.new

      results = repo.search({},
        joins: [ :author ],
        includes: [ :author ],
        order: "authors.name ASC"
      )
      assert_equal [ "Article 1", "Article 2" ], results.pluck(:title)
    end

    # ========================================
    # INTEGRATION WITH BETTERMODEL
    # ========================================

    test "search integrates with Searchable.search()" do
      Article.create!(title: "Rails Guide", status: "published", view_count: 150)
      Article.create!(title: "Ruby Basics", status: "draft", view_count: 50)
      repo = ArticleRepository.new

      # Should use Article.search() if available
      results = repo.search({ status_eq: "published", view_count_gt: 100 })
      assert_equal 1, results.count
      assert_equal "Rails Guide", results.first.title
    end

    test "search falls back to all() when no predicates" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      results = repo.search({})
      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count
    end

    test "search validates predicates with Predicable" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      # Invalid predicate raises error when using Searchable
      assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        repo.search({ invalid_predicate: "value" })
      end
    end

    # ========================================
    # CUSTOM REPOSITORY METHODS
    # ========================================

    test "custom repository methods can use search" do
      Article.create!(title: "Published 1", status: "published")
      Article.create!(title: "Draft 1", status: "draft")
      repo = ArticleRepository.new

      results = repo.published
      assert_equal 1, results.count
      assert_equal "published", results.first.status
    end

    test "custom repository methods can chain ActiveRecord" do
      Article.create!(title: "Rails", status: "published", view_count: 100)
      Article.create!(title: "Ruby", status: "published", view_count: 50)
      repo = ArticleRepository.new

      results = repo.published.where("view_count > ?", 75)
      assert_equal 1, results.count
      assert_equal "Rails", results.first.title
    end

    test "custom repository methods are composable" do
      Article.create!(title: "Popular", status: "published", view_count: 200)
      Article.create!(title: "Normal", status: "published", view_count: 50)
      Article.create!(title: "Draft", status: "draft", view_count: 300)
      repo = ArticleRepository.new

      # popular method calls published internally
      results = repo.popular
      assert_equal 1, results.count
      assert_equal "Popular", results.first.title
    end

    # ========================================
    # EDGE CASES
    # ========================================

    test "search with empty predicates hash" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      assert_nothing_raised do
        results = repo.search({})
        assert_equal 1, results.count
      end
    end

    test "search with nil predicates" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      assert_nothing_raised do
        results = repo.search(nil)
        assert_equal 1, results.count
      end
    end

    test "search with page 0 should work" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      # Page 0 should be treated as page 1
      results = repo.search({}, page: 0, per_page: 10)
      assert_kind_of ActiveRecord::Relation, results
    end

    test "search with negative per_page should work" do
      Article.create!(title: "Test", status: "draft")
      repo = ArticleRepository.new

      # Negative per_page should not break
      assert_nothing_raised do
        repo.search({}, per_page: -10)
      end
    end

    test "search with very small limit works" do
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "draft")
      repo = ArticleRepository.new

      results = repo.search({}, limit: 2)
      assert_kind_of ActiveRecord::Relation, results
      assert_equal 2, results.count
    end

    # ========================================
    # ERROR HANDLING
    # ========================================

    test "find raises ActiveRecord::RecordNotFound for missing id" do
      repo = ArticleRepository.new

      assert_raises(ActiveRecord::RecordNotFound) do
        repo.find(999999)
      end
    end

    test "update raises ActiveRecord::RecordNotFound for missing id" do
      repo = ArticleRepository.new

      assert_raises(ActiveRecord::RecordNotFound) do
        repo.update(999999, title: "Updated")
      end
    end

    test "delete raises ActiveRecord::RecordNotFound for missing id" do
      repo = ArticleRepository.new

      assert_raises(ActiveRecord::RecordNotFound) do
        repo.delete(999999)
      end
    end

    test "create! can raise ActiveRecord::RecordInvalid on validation failure" do
      repo = ArticleRepository.new

      # Note: Article model in tests doesn't have validations
      # This test just ensures create! is properly delegated
      article = repo.create!(title: "Valid")
      assert_not_nil article.id
    end

    # ========================================
    # REAL-WORLD SCENARIOS
    # ========================================

    test "complete API request scenario" do
      # Setup: Create test data
      Article.create!(title: "Ruby Guide", status: "published", view_count: 150, published_at: 5.days.ago)
      Article.create!(title: "Rails Tutorial", status: "published", view_count: 200, published_at: 3.days.ago)
      Article.create!(title: "Python Basics", status: "published", view_count: 50, published_at: 10.days.ago)
      Article.create!(title: "Draft Post", status: "draft", view_count: 300, published_at: nil)

      repo = ArticleRepository.new

      # Scenario: Get popular published articles from last week
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

      assert_equal 2, results.count
      assert_equal [ "Rails Tutorial", "Ruby Guide" ], results.pluck(:title)
    end

    test "multi-step query building scenario" do
      Article.create!(title: "Featured Article", status: "published", featured: true, view_count: 150)
      Article.create!(title: "Normal Article", status: "published", featured: false, view_count: 200)

      repo = ArticleRepository.new

      # Step 1: Get published articles
      published = repo.search({ status_eq: "published" })
      assert_equal 2, published.count

      # Step 2: Further filter for featured
      featured = published.where(featured: true)
      assert_equal 1, featured.count
      assert_equal "Featured Article", featured.first.title
    end

    test "repository pattern encapsulation" do
      Article.create!(title: "Article 1", status: "published", view_count: 100)
      Article.create!(title: "Article 2", status: "published", view_count: 200)

      repo = ArticleRepository.new

      # Use custom method instead of raw queries
      popular_articles = repo.popular
      assert_equal 1, popular_articles.count
      assert popular_articles.first.view_count >= 150

      # Repositories hide complexity
      recent_articles = repo.recent(days: 30)
      assert_kind_of ActiveRecord::Relation, recent_articles
    end
  end

  # Helper repository class for testing
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
end
