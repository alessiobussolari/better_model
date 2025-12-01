# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Searchable do
  describe "module inclusion" do
    it "is defined" do
      expect(defined?(BetterModel::Searchable)).to be_truthy
    end

    it "Article has searchable functionality" do
      expect(Article).to respond_to(:search)
      expect(Article).to respond_to(:searchable_config)
    end

    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Searchable
        end
      end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError, /Invalid configuration/)
    end
  end

  describe "method signature" do
    it "accepts predicates hash" do
      result = Article.search({ title_cont: "Test" })
      expect(result).to be_a(ActiveRecord::Relation)
    end

    it "accepts pagination keyword argument" do
      result = Article.search({}, pagination: { page: 1, per_page: 10 })
      expect(result).to be_a(ActiveRecord::Relation)
    end

    it "accepts orders keyword argument" do
      result = Article.search({}, orders: [ :sort_title_asc ])
      expect(result).to be_a(ActiveRecord::Relation)
    end

    it "accepts all parameters" do
      result = Article.search(
        { title_cont: "Test" },
        pagination: { page: 1, per_page: 10 },
        orders: [ :sort_title_asc ]
      )
      expect(result).to be_a(ActiveRecord::Relation)
    end

    it "works with empty predicates" do
      result = Article.search({})
      expect(result).to be_a(ActiveRecord::Relation)
    end
  end

  describe "predicates" do
    it "applies single predicate" do
      a1 = Article.create!(title: "Ruby on Rails Tutorial", content: "Test", status: "draft")
      Article.create!(title: "Python Programming Guide", content: "Test", status: "draft")

      results = Article.search({ title_cont: "Ruby" }).pluck(:title)
      expect(results).to eq([ "Ruby on Rails Tutorial" ])
    end

    it "applies multiple predicates" do
      Article.create!(title: "Ruby", content: "Test", status: "published", view_count: 150)
      Article.create!(title: "Rails", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Python", content: "Test", status: "published", view_count: 200)

      results = Article.search({
        status_eq: "published",
        view_count_gt: 100
      }).pluck(:title)

      expect(results.sort).to eq([ "Python", "Ruby" ])
    end

    it "validates predicate scopes" do
      expect do
        Article.search({ nonexistent_scope: "value" })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPredicateError)
    end

    it "skips nil values" do
      Article.create!(title: "Test", content: "Test", status: "draft")

      results = Article.search({ title_cont: "Test", status_eq: nil })
      expect(results.count).to eq(1)
    end

    it "skips blank values" do
      Article.create!(title: "Test", content: "Test", status: "draft")

      results = Article.search({ title_cont: "Test", status_eq: "" })
      expect(results.count).to eq(1)
    end

    it "handles boolean predicates" do
      Article.create!(title: "Test", content: "Test", status: "draft", featured: true)
      Article.create!(title: "Test2", content: "Test", status: "draft", featured: false)

      results = Article.search({ featured_eq: true }).pluck(:featured)
      expect(results).to eq([ true ])
    end
  end

  describe "OR conditions" do
    it "applies OR conditions" do
      Article.create!(title: "Ruby on Rails", content: "Test", status: "draft")
      Article.create!(title: "Python Guide", content: "Test", status: "draft")
      Article.create!(title: "Java Tutorial", content: "Test", status: "draft")

      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Python" }
        ]
      }).pluck(:title).sort

      expect(results).to eq([ "Python Guide", "Ruby on Rails" ])
    end

    it "combines OR with AND predicates" do
      Article.create!(title: "Ruby", content: "Test", status: "published", view_count: 150)
      Article.create!(title: "Rails", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Python", content: "Test", status: "published", view_count: 200)

      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Python" }
        ],
        status_eq: "published"
      }).pluck(:title).sort

      expect(results).to eq([ "Python", "Ruby" ])
    end

    it "validates predicates in OR conditions" do
      expect do
        Article.search({
          or: [
            { nonexistent_scope: "value" }
          ]
        })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPredicateError)
    end

    it "skips empty values in OR conditions" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "Rails", content: "Test", status: "draft")

      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "" }
        ]
      }).pluck(:title)

      expect(results).to include("Ruby")
    end

    it "handles empty OR conditions array" do
      Article.create!(title: "Test", status: "draft")

      results = Article.search({
        status_eq: "draft",
        or: []
      })

      expect(results.count).to eq(1)
    end

    it "handles OR with multiple predicates per condition" do
      article1 = Article.create!(title: "Ruby", status: "published", view_count: 100)
      article2 = Article.create!(title: "Rails", status: "draft", view_count: 50)
      Article.create!(title: "Python", status: "published", view_count: 75)

      results = Article.search({
        or: [
          { title_eq: "Ruby", status_eq: "published" },
          { title_eq: "Rails", status_eq: "draft" }
        ]
      })

      expect(results.count).to eq(2)
      expect(results).to include(article1)
      expect(results).to include(article2)
    end
  end

  describe "orders" do
    it "applies single order scope" do
      Article.create!(title: "Zebra", content: "Test", status: "draft")
      Article.create!(title: "Apple", content: "Test", status: "draft")

      results = Article.search({}, orders: [ :sort_title_asc ]).pluck(:title)
      expect(results).to eq([ "Apple", "Zebra" ])
    end

    it "applies multiple order scopes" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 200)

      results = Article.search({}, orders: [ :sort_view_count_desc, :sort_title_asc ]).pluck(:title)
      expect(results).to eq([ "C", "A", "B" ])
    end

    it "validates order scopes" do
      expect do
        Article.search({}, orders: [ :nonexistent_sort ])
      end.to raise_error(BetterModel::Errors::Searchable::InvalidOrderError)
    end

    it "applies default_order when no orders specified" do
      Article.delete_all
      Article.create!(title: "First", content: "Test", status: "draft", created_at: 3.days.ago)
      Article.create!(title: "Second", content: "Test", status: "draft", created_at: 1.day.ago)
      Article.create!(title: "Third", content: "Test", status: "draft", created_at: 2.days.ago)

      results = Article.search({}).pluck(:title)
      expect(results).to eq([ "Second", "Third", "First" ])
    end

    it "orders parameter overrides default_order" do
      Article.delete_all
      Article.create!(title: "Zebra", content: "Test", status: "draft", created_at: 3.days.ago)
      Article.create!(title: "Apple", content: "Test", status: "draft", created_at: 1.day.ago)
      Article.create!(title: "Mango", content: "Test", status: "draft", created_at: 2.days.ago)

      results = Article.search({}, orders: [ :sort_title_asc ]).pluck(:title)
      expect(results).to eq([ "Apple", "Mango", "Zebra" ])
    end
  end

  describe "pagination" do
    it "applies pagination" do
      5.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      results = Article.search({}, pagination: { page: 1, per_page: 2 })
      expect(results.count).to eq(2)
    end

    it "respects max_per_page" do
      10.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      expect do
        Article.search({}, pagination: { page: 1, per_page: 200 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError, /per_page must be <= 100/)
    end

    it "works without pagination" do
      3.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      results = Article.search({})
      expect(results.count).to be >= 3
    end

    it "handles page correctly" do
      6.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      page1 = Article.search({}, pagination: { page: 1, per_page: 2 }, orders: [ :sort_title_asc ])
      page2 = Article.search({}, pagination: { page: 2, per_page: 2 }, orders: [ :sort_title_asc ])

      expect(page1.count).to eq(2)
      expect(page2.count).to eq(2)
      expect(page1.pluck(:id)).not_to eq(page2.pluck(:id))
    end

    it "raises error for invalid page" do
      expect do
        Article.search({}, pagination: { page: 0 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "raises error for invalid per_page" do
      expect do
        Article.search({}, pagination: { page: 1, per_page: 0 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "raises error when page exceeds max_page" do
      expect do
        Article.search(pagination: { page: 10_001, per_page: 10 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError, /Page number exceeds maximum allowed/)
    end

    it "pagination without per_page param returns all results" do
      Article.delete_all
      10.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      results = Article.search({}, pagination: { page: 1 })
      expect(results.count).to eq(10)
      expect(results.limit_value).to be_nil
    end
  end

  describe "securities" do
    let(:test_class) do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        predicates :status, :featured

        searchable do
          security :status_required, [ :status_eq ]
          security :multi_pred, [ :status_eq, :featured_true ]
        end
      end
      stub_const("SearchableSecurityTest", klass)
      klass
    end

    it "configures securities via DSL" do
      expect(test_class.searchable_config[:securities][:status_required]).to eq([ :status_eq ])
      expect(test_class.searchable_config[:securities][:multi_pred]).to eq([ :status_eq, :featured_true ])
    end

    it "requires at least one predicate" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel
          include BetterModel::Searchable

          searchable do
            security :empty, []
          end
        end
      end.to raise_error(BetterModel::Errors::Searchable::ConfigurationError, /Invalid configuration/)
    end

    it "passes with valid security and all required predicates" do
      Article.delete_all
      Article.create!(title: "Test", content: "Test", status: "published", featured: true)

      results = Article.search({ status_eq: "published" }, security: :status_required)
      expect(results).to be_a(ActiveRecord::Relation)
      expect(results.count).to eq(1)
    end

    it "raises error when security missing required predicate" do
      expect do
        Article.search({ title_cont: "Test" }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError, /Required security predicates missing/)
    end

    it "raises error for unknown security" do
      expect do
        Article.search({ status_eq: "published" }, security: :nonexistent)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError, /Unknown security policy/)
    end

    it "works normally without specifying security" do
      Article.delete_all
      Article.create!(title: "Test", content: "Test", status: "draft")

      results = Article.search({ title_cont: "Test" })
      expect(results.count).to eq(1)
    end

    it "rejects nil predicate value" do
      expect do
        Article.search({ status_eq: nil }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError, /Required security predicates missing/)
    end

    it "rejects empty string predicate value" do
      expect do
        Article.search({ status_eq: "" }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError, /Required security predicates missing/)
    end

    it "accepts false as valid predicate value" do
      test_class_with_security = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        predicates :featured

        searchable do
          security :featured_filter, [ :featured_eq ]
        end
      end

      result = test_class_with_security.search({ featured_eq: false }, security: :featured_filter)
      expect(result).to be_a(ActiveRecord::Relation)
    end
  end

  describe "DoS protection" do
    it "raises error when too many predicates" do
      predicates = {}
      101.times { |i| predicates["field_#{i}".to_sym] = "value" }

      expect do
        Article.search(predicates)
      end.to raise_error(ArgumentError, /Invalid configuration/)
    end

    it "raises error when too many OR conditions" do
      or_conditions = []
      51.times { |i| or_conditions << { "field_#{i}".to_sym => "value" } }

      expect do
        Article.search({ or: or_conditions })
      end.to raise_error(ArgumentError, /Invalid configuration/)
    end

    it "counts predicates inside OR conditions" do
      predicates = {}
      50.times { |i| predicates["field_#{i}".to_sym] = "value" }

      or_conditions = []
      40.times do |i|
        or_conditions << {
          "or_field_a_#{i}".to_sym => "value",
          "or_field_b_#{i}".to_sym => "value"
        }
      end

      predicates[:or] = or_conditions

      expect do
        Article.search(predicates)
      end.to raise_error(ArgumentError, /Query complexity exceeds maximum allowed predicates/)
    end
  end

  describe "integration" do
    it "returns chainable relation" do
      result = Article.search({ status_eq: "published" })
      expect(result).to be_a(ActiveRecord::Relation)

      chained = result.where("view_count > 0")
      expect(chained).to be_a(ActiveRecord::Relation)
    end

    it "chains with other scopes" do
      Article.create!(title: "Ruby", content: "Test", status: "published", view_count: 150)
      Article.create!(title: "Rails", content: "Test", status: "published", view_count: 100)

      results = Article.search({ status_eq: "published" })
                       .where("view_count > 100")
                       .pluck(:title)

      expect(results).to eq([ "Ruby" ])
    end
  end

  describe "DSL configuration" do
    it "configures per_page" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          per_page 50
        end
      end

      expect(test_class.searchable_config[:per_page]).to eq(50)
    end

    it "configures max_per_page" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          max_per_page 200
        end
      end

      expect(test_class.searchable_config[:max_per_page]).to eq(200)
    end

    it "configures default_order" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        sort :title, :created_at

        searchable do
          default_order [ :sort_created_at_desc, :sort_title_asc ]
        end
      end

      expect(test_class.searchable_config[:default_order]).to eq([ :sort_created_at_desc, :sort_title_asc ])
    end

    it "has nil defaults" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable
      end

      expect(test_class.searchable_config[:default_order]).to be_nil
      expect(test_class.searchable_config[:per_page]).to be_nil
      expect(test_class.searchable_config[:max_per_page]).to be_nil
    end
  end

  describe "introspection methods" do
    it "searchable_field? returns correct value" do
      expect(Article.searchable_field?(:title)).to be true
      expect(Article.searchable_field?(:nonexistent)).to be false
    end

    it "searchable_fields returns correct set" do
      fields = Article.searchable_fields
      expect(fields).to include(:title)
      expect(fields).to include(:status)
    end

    it "searchable_predicates_for returns available predicates" do
      predicates = Article.searchable_predicates_for(:title)
      expect(predicates).to include(:eq)
      expect(predicates).to include(:cont)
      expect(predicates).to include(:i_cont)
    end

    it "searchable_sorts_for returns available sorts" do
      sorts = Article.searchable_sorts_for(:title)
      expect(sorts).to include(:sort_title_asc)
      expect(sorts).to include(:sort_title_desc)
    end

    it "search_metadata returns complete metadata" do
      article = Article.new
      metadata = article.search_metadata

      expect(metadata).to be_a(Hash)
      expect(metadata).to have_key(:searchable_fields)
      expect(metadata).to have_key(:sortable_fields)
      expect(metadata).to have_key(:available_predicates)
      expect(metadata).to have_key(:available_sorts)
      expect(metadata).to have_key(:pagination)
    end
  end

  describe "eager loading" do
    let!(:author) { Author.create!(name: "John Doe", email: "john@example.com") }
    let!(:article) { Article.create!(title: "Test Article", content: "Test Content", status: "published", author: author) }

    it "loads single association with includes" do
      results = Article.search({ status_eq: "published" }, includes: [ :author ])

      expect(results).to be_a(ActiveRecord::Relation)
      expect(results.count).to eq(1)
      expect(results.first.author.name).to eq("John Doe")
    end

    it "loads multiple associations with includes" do
      comment1 = Comment.create!(article: article, body: "Great post!", author_name: "Reader 1")
      Comment.create!(article: article, body: "Thanks!", author_name: "Reader 2")

      results = Article.search({ status_eq: "published" }, includes: [ :author, :comments ])

      expect(results.count).to eq(1)
      article_result = results.first
      expect(article_result.author.name).to eq("John Doe")
      expect(article_result.comments.count).to eq(2)
    end

    it "handles nested associations" do
      results = Article.search(
        { status_eq: "published" },
        includes: { author: :articles }
      )

      expect(results).to be_a(ActiveRecord::Relation)
      expect(results.count).to eq(1)
    end

    it "combines includes with pagination and ordering" do
      author2 = Author.create!(name: "Author Two", email: "two@example.com")
      Article.create!(title: "Second Article", content: "Content", status: "published", author: author2, view_count: 200)
      article.update!(view_count: 100)

      results = Article.search(
        { status_eq: "published" },
        pagination: { page: 1, per_page: 10 },
        orders: [ :sort_view_count_desc ],
        includes: [ :author ]
      )

      expect(results.count).to eq(2)
      expect(results.first.title).to eq("Second Article")
      expect(results.first.author.name).to eq("Author Two")
    end

    it "does not raise error with nil includes" do
      results = Article.search({ status_eq: "published" }, includes: nil)
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "does not raise error with empty includes array" do
      results = Article.search({ status_eq: "published" }, includes: [])
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "raises ActiveRecord error with invalid association" do
      expect do
        Article.search({ status_eq: "published" }, includes: :nonexistent_association).load
      end.to raise_error(ActiveRecord::ConfigurationError)
    end

    it "returns chainable relation with includes" do
      article.update!(view_count: 150)

      results = Article.search(
        { status_eq: "published" },
        includes: [ :author ]
      ).where("view_count > 100")

      expect(results).to be_a(ActiveRecord::Relation)
      expect(results.count).to eq(1)
    end
  end

  describe "validation" do
    it "rejects unknown keyword arguments" do
      expect do
        Article.search({ title_cont: "test" }, unknown_param: "value")
      end.to raise_error(ArgumentError, /Invalid search options provided/)
    end

    it "handles ActionController::Parameters safely" do
      require "action_controller"

      params = ActionController::Parameters.new({
        title_cont: "test",
        status_eq: "draft"
      })

      Article.create!(title: "Test Article", status: "draft")

      expect do
        Article.search(params.permit(:title_cont, :status_eq))
      end.not_to raise_error
    end

    it "handles very long predicate values" do
      Article.create!(title: "Test", status: "draft")

      long_string = "a" * 10000

      expect do
        Article.search({ title_cont: long_string }).to_a
      end.not_to raise_error
    end

    it "handles special characters in predicates" do
      Article.create!(title: "Test's Article", status: "draft")

      expect do
        Article.search({ title_cont: "Test's" }).to_a
        Article.search({ title_cont: "%; DROP TABLE articles;--" }).to_a
      end.not_to raise_error
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Searchable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Searchable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Searchable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Searchable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end
end
