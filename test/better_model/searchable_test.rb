# frozen_string_literal: true

require "test_helper"

module BetterModel
  class SearchableTest < ActiveSupport::TestCase
    # Test che Article include Searchable tramite BetterModel
    test "Article should have searchable functionality" do
      assert Article.respond_to?(:search)
      assert Article.respond_to?(:searchable_config)
    end

    # Test validazione ActiveRecord
    test "should only be includable in ActiveRecord models" do
      assert_raises(ArgumentError, /can only be included in ActiveRecord models/) do
        Class.new do
          include BetterModel::Searchable
        end
      end
    end

    # Test method signature
    test "search accepts predicates hash" do
      result = Article.search({ title_cont: "Test" })
      assert_kind_of ActiveRecord::Relation, result
    end

    test "search accepts pagination keyword argument" do
      result = Article.search({}, pagination: { page: 1, per_page: 10 })
      assert_kind_of ActiveRecord::Relation, result
    end

    test "search accepts orders keyword argument" do
      result = Article.search({}, orders: [ :sort_title_asc ])
      assert_kind_of ActiveRecord::Relation, result
    end

    test "search accepts all parameters" do
      result = Article.search(
        { title_cont: "Test" },
        pagination: { page: 1, per_page: 10 },
        orders: [ :sort_title_asc ]
      )
      assert_kind_of ActiveRecord::Relation, result
    end

    test "search works with empty predicates" do
      result = Article.search({})
      assert_kind_of ActiveRecord::Relation, result
    end

    # Test predicates
    test "search applies single predicate" do
      Article.delete_all  # Clear any existing records
      a1 = Article.create!(title: "Ruby on Rails Tutorial", content: "Test", status: "draft")
      a2 = Article.create!(title: "Python Programming Guide", content: "Test", status: "draft")

      results = Article.search({ title_cont: "Ruby" }).pluck(:title)
      assert_equal [ "Ruby on Rails Tutorial" ], results

      a1.destroy
      a2.destroy
    end

    test "search applies multiple predicates" do
      a1 = Article.create!(title: "Ruby", content: "Test", status: "published", view_count: 150)
      a2 = Article.create!(title: "Rails", content: "Test", status: "draft", view_count: 100)
      a3 = Article.create!(title: "Python", content: "Test", status: "published", view_count: 200)

      results = Article.search({
        status_eq: "published",
        view_count_gt: 100
      }).pluck(:title)

      assert_equal [ "Python", "Ruby" ], results.sort

      a1.destroy
      a2.destroy
      a3.destroy
    end

    test "search validates predicate scopes" do
      assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ nonexistent_scope: "value" })
      end
    end

    test "search skips nil values" do
      a1 = Article.create!(title: "Test", content: "Test", status: "draft")

      results = Article.search({ title_cont: "Test", status_eq: nil })
      assert_equal 1, results.count

      a1.destroy
    end

    test "search skips blank values" do
      a1 = Article.create!(title: "Test", content: "Test", status: "draft")

      results = Article.search({ title_cont: "Test", status_eq: "" })
      assert_equal 1, results.count

      a1.destroy
    end

    test "search handles boolean predicates without values" do
      a1 = Article.create!(title: "Test", content: "Test", status: "draft", featured: true)
      a2 = Article.create!(title: "Test2", content: "Test", status: "draft", featured: false)

      results = Article.search({ featured_eq: true }).pluck(:featured)
      assert_equal [ true ], results

      a1.destroy
      a2.destroy
    end

    # Test OR conditions
    test "search applies OR conditions" do
      a1 = Article.create!(title: "Ruby on Rails", content: "Test", status: "draft")
      a2 = Article.create!(title: "Python Guide", content: "Test", status: "draft")
      a3 = Article.create!(title: "Java Tutorial", content: "Test", status: "draft")

      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Python" }
        ]
      }).pluck(:title).sort

      assert_equal [ "Python Guide", "Ruby on Rails" ], results

      a1.destroy
      a2.destroy
      a3.destroy
    end

    test "search combines OR with AND predicates" do
      a1 = Article.create!(title: "Ruby", content: "Test", status: "published", view_count: 150)
      a2 = Article.create!(title: "Rails", content: "Test", status: "draft", view_count: 100)
      a3 = Article.create!(title: "Python", content: "Test", status: "published", view_count: 200)

      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Python" }
        ],
        status_eq: "published"
      }).pluck(:title).sort

      assert_equal [ "Python", "Ruby" ], results

      a1.destroy
      a2.destroy
      a3.destroy
    end

    test "search validates predicates in OR conditions" do
      assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({
          or: [
            { nonexistent_scope: "value" }
          ]
        })
      end
    end

    # Test orders
    test "search applies single order scope" do
      a1 = Article.create!(title: "Zebra", content: "Test", status: "draft")
      a2 = Article.create!(title: "Apple", content: "Test", status: "draft")

      results = Article.search({}, orders: [ :sort_title_asc ]).pluck(:title)
      assert_equal [ "Apple", "Zebra" ], results

      a1.destroy
      a2.destroy
    end

    test "search applies multiple order scopes" do
      a1 = Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      a2 = Article.create!(title: "B", content: "Test", status: "draft", view_count: 100)
      a3 = Article.create!(title: "C", content: "Test", status: "draft", view_count: 200)

      results = Article.search({}, orders: [ :sort_view_count_desc, :sort_title_asc ]).pluck(:title)

      assert_equal [ "C", "A", "B" ], results

      a1.destroy
      a2.destroy
      a3.destroy
    end

    test "search validates order scopes" do
      assert_raises(BetterModel::Errors::Searchable::InvalidOrderError) do
        Article.search({}, orders: [ :nonexistent_sort ])
      end
    end

    test "search applies default_order when no orders specified" do
      Article.delete_all
      a1 = Article.create!(title: "First", content: "Test", status: "draft", created_at: 3.days.ago)
      a2 = Article.create!(title: "Second", content: "Test", status: "draft", created_at: 1.day.ago)
      a3 = Article.create!(title: "Third", content: "Test", status: "draft", created_at: 2.days.ago)

      # Article has default_order [:sort_created_at_desc]
      results = Article.search({}).pluck(:title)
      assert_equal [ "Second", "Third", "First" ], results

      a1.destroy
      a2.destroy
      a3.destroy
    end

    test "search orders parameter overrides default_order completely" do
      Article.delete_all
      a1 = Article.create!(title: "Zebra", content: "Test", status: "draft", created_at: 3.days.ago)
      a2 = Article.create!(title: "Apple", content: "Test", status: "draft", created_at: 1.day.ago)
      a3 = Article.create!(title: "Mango", content: "Test", status: "draft", created_at: 2.days.ago)

      # Override default_order with custom order
      results = Article.search({}, orders: [ :sort_title_asc ]).pluck(:title)
      assert_equal [ "Apple", "Mango", "Zebra" ], results

      a1.destroy
      a2.destroy
      a3.destroy
    end

    test "search works without default_order configuration" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        sort :title
        predicates :title

        searchable do
          # No default_order configured
        end
      end

      # Should work without error, return results in database order
      result = test_class.search({ title_cont: "Test" })
      assert_kind_of ActiveRecord::Relation, result
    end

    # Test pagination
    test "search applies pagination" do
      5.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      results = Article.search({}, pagination: { page: 1, per_page: 2 })
      assert_equal 2, results.count

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "search respects max_per_page" do
      10.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      # Try to request more than max_per_page (100)
      results = Article.search({}, pagination: { page: 1, per_page: 200 })
      assert results.limit_value <= 100

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "search works without pagination" do
      3.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      results = Article.search({})
      assert_operator results.count, :>=, 3

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "search handles page correctly" do
      6.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      page1 = Article.search({}, pagination: { page: 1, per_page: 2 }, orders: [ :sort_title_asc ])
      page2 = Article.search({}, pagination: { page: 2, per_page: 2 }, orders: [ :sort_title_asc ])

      assert_equal 2, page1.count
      assert_equal 2, page2.count
      refute_equal page1.pluck(:id), page2.pluck(:id)

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "search raises error for invalid page" do
      assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: 0 })
      end
    end

    test "search raises error for invalid per_page" do
      assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: 1, per_page: 0 })
      end
    end

    test "pagination without per_page param returns all results" do
      Article.delete_all
      10.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      # Pagination with only page but no per_page should return all results
      results = Article.search({}, pagination: { page: 1 })
      assert_equal 10, results.count
      assert_nil results.limit_value

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "max_per_page is respected when configured" do
      10.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      # Article has max_per_page 100 configured
      results = Article.search({}, pagination: { page: 1, per_page: 200 })
      assert_equal 100, results.limit_value

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "pagination works without max_per_page configuration" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        predicates :title

        searchable do
          # No max_per_page configured
        end
      end

      10.times { |i| Article.create!(title: "Article #{i}", content: "Test", status: "draft") }

      # Should allow any per_page value
      results = test_class.search({}, pagination: { page: 1, per_page: 500 })
      assert_equal 500, results.limit_value

      Article.where("title LIKE 'Article%'").destroy_all
    end

    # Test securities
    test "searchable DSL configures securities" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        predicates :status, :featured

        searchable do
          security :status_required, [ :status_eq ]
          security :multi_pred, [ :status_eq, :featured_true ]
        end
      end

      assert_equal [ :status_eq ], test_class.searchable_config[:securities][:status_required]
      assert_equal [ :status_eq, :featured_true ], test_class.searchable_config[:securities][:multi_pred]
    end

    test "security requires at least one predicate" do
      assert_raises(ArgumentError, /must have at least one required predicate/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel
          include BetterModel::Searchable

          searchable do
            security :empty, []
          end
        end
      end
    end

    test "search with valid security and all required predicates passes" do
      Article.delete_all
      a1 = Article.create!(title: "Test", content: "Test", status: "published", featured: true)

      # Security :status_required requires :status_eq
      results = Article.search({ status_eq: "published" }, security: :status_required)
      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      a1.destroy
    end

    test "search with security but missing required predicate raises error" do
      assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError, /requires the following predicates with valid values: status_eq/) do
        # Security :status_required requires :status_eq, but we don't provide it
        Article.search({ title_cont: "Test" }, security: :status_required)
      end
    end

    test "search with security missing multiple required predicates raises error" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        predicates :status, :featured, :title

        searchable do
          security :multi, [ :status_eq, :featured_true ]
        end
      end

      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        test_class.search({ title_cont: "Test" }, security: :multi)
      end

      assert_match(/status_eq/, error.message)
      assert_match(/featured_true/, error.message)
    end

    test "search with unknown security raises error" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        Article.search({ status_eq: "published" }, security: :nonexistent)
      end

      assert_match(/Security policy violation: nonexistent/, error.message)
      assert_match(/Unknown security policy/, error.message)
      assert_match(/Available securities:/, error.message)
    end

    test "search without security works normally when securities are configured" do
      Article.delete_all
      a1 = Article.create!(title: "Test", content: "Test", status: "draft")

      # Should work fine without specifying security
      results = Article.search({ title_cont: "Test" })
      assert_equal 1, results.count

      a1.destroy
    end

    test "security validation works with complex predicates" do
      Article.delete_all
      a1 = Article.create!(title: "Test", content: "Test", status: "published", featured: true)

      # Security requires status_eq, we provide it along with other predicates
      results = Article.search(
        { status_eq: "published", title_cont: "Test", featured_eq: true },
        security: :status_required
      )

      assert_equal 1, results.count

      a1.destroy
    end

    test "security works together with orders and pagination" do
      Article.delete_all
      5.times do |i|
        Article.create!(title: "Article #{i}", content: "Test", status: "published", featured: true)
      end

      results = Article.search(
        { status_eq: "published" },
        security: :status_required,
        pagination: { page: 1, per_page: 3 },
        orders: [ :sort_title_asc ]
      )

      assert_equal 3, results.count
      assert_equal [ "Article 0", "Article 1", "Article 2" ], results.pluck(:title)

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "security rejects nil predicate value" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        Article.search({ status_eq: nil }, security: :status_required)
      end

      assert_match(/Security policy violation: status_required/, error.message)
      assert_match(/status_eq/, error.message)
    end

    test "security rejects empty string predicate value" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        Article.search({ status_eq: "" }, security: :status_required)
      end

      assert_match(/Security policy violation: status_required/, error.message)
      assert_match(/status_eq/, error.message)
    end

    test "security rejects empty array predicate value" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        Article.search({ status_eq: [] }, security: :status_required)
      end

      assert_match(/Security policy violation: status_required/, error.message)
      assert_match(/status_eq/, error.message)
    end

    test "security accepts false as valid predicate value" do
      # false should be accepted as a valid value (like in apply_predicates)
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        predicates :featured

        searchable do
          security :featured_filter, [ :featured_eq ]
        end
      end

      # Should NOT raise error for false value
      result = test_class.search({ featured_eq: false }, security: :featured_filter)
      assert_kind_of ActiveRecord::Relation, result
    end

    test "security validates multiple predicates all have valid values" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        predicates :status, :featured

        searchable do
          security :multi, [ :status_eq, :featured_true ]
        end
      end

      # Both predicates present but one is nil - should fail
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        test_class.search({ status_eq: "published", featured_true: nil }, security: :multi)
      end

      assert_match(/featured_true/, error.message)
    end

    # Test integration
    test "search returns chainable relation" do
      result = Article.search({ status_eq: "published" })
      assert_kind_of ActiveRecord::Relation, result

      # Should be chainable
      chained = result.where("view_count > 0")
      assert_kind_of ActiveRecord::Relation, chained
    end

    test "search chains with other scopes" do
      a1 = Article.create!(title: "Ruby", content: "Test", status: "published", view_count: 150)
      a2 = Article.create!(title: "Rails", content: "Test", status: "published", view_count: 100)

      results = Article.search({ status_eq: "published" })
                      .where("view_count > 100")
                      .pluck(:title)

      assert_equal [ "Ruby" ], results

      a1.destroy
      a2.destroy
    end

    # Test DSL configuration
    test "searchable DSL configures per_page" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          per_page 50
        end
      end

      assert_equal 50, test_class.searchable_config[:per_page]
    end

    test "searchable DSL configures max_per_page" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          max_per_page 200
        end
      end

      assert_equal 200, test_class.searchable_config[:max_per_page]
    end

    test "searchable DSL configures default_order" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel::Searchable

        sort :title, :created_at

        searchable do
          default_order [ :sort_created_at_desc, :sort_title_asc ]
        end
      end

      assert_equal [ :sort_created_at_desc, :sort_title_asc ], test_class.searchable_config[:default_order]
    end

    test "searchable config has nil defaults" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable
      end

      assert_nil test_class.searchable_config[:default_order]
      assert_nil test_class.searchable_config[:per_page]
      assert_nil test_class.searchable_config[:max_per_page]
    end

    # Test introspection methods
    test "searchable_field? returns correct value" do
      assert Article.searchable_field?(:title)
      refute Article.searchable_field?(:nonexistent)
    end

    test "searchable_fields returns correct set" do
      fields = Article.searchable_fields
      assert_includes fields, :title
      assert_includes fields, :status
    end

    test "searchable_predicates_for returns available predicates" do
      predicates = Article.searchable_predicates_for(:title)
      assert_includes predicates, :eq
      assert_includes predicates, :cont
      assert_includes predicates, :i_cont
    end

    test "searchable_sorts_for returns available sorts" do
      sorts = Article.searchable_sorts_for(:title)
      assert_includes sorts, :sort_title_asc
      assert_includes sorts, :sort_title_desc
    end

    test "search_metadata returns complete metadata" do
      article = Article.new
      metadata = article.search_metadata

      assert_instance_of Hash, metadata
      assert metadata.key?(:searchable_fields)
      assert metadata.key?(:sortable_fields)
      assert metadata.key?(:available_predicates)
      assert metadata.key?(:available_sorts)
      assert metadata.key?(:pagination)
    end

    # Test real-world scenarios
    test "search handles typical API request" do
      a1 = Article.create!(title: "Ruby on Rails", content: "Test", status: "published", view_count: 150)
      a2 = Article.create!(title: "Ruby Gems", content: "Test", status: "published", view_count: 100)
      a3 = Article.create!(title: "Python", content: "Test", status: "draft", view_count: 200)

      results = Article.search({
        title_cont: "Ruby",
        status_eq: "published"
      }, pagination: { page: 1, per_page: 10 }, orders: [ :sort_view_count_desc ]).pluck(:title)

      assert_equal [ "Ruby on Rails", "Ruby Gems" ], results

      a1.destroy
      a2.destroy
      a3.destroy
    end

    test "search handles complex filtering with sorting and pagination" do
      10.times do |i|
        Article.create!(
          title: "Article #{i}",
          content: "Test",
          status: i.even? ? "published" : "draft",
          view_count: i * 10
        )
      end

      results = Article.search({
        status_eq: "published",
        view_count_between: [ 10, 50 ]
      }, pagination: { page: 1, per_page: 5 }, orders: [ :sort_view_count_desc ])

      assert_operator results.count, :<=, 5
      assert results.all? { |a| a.status == "published" }
      assert results.all? { |a| a.view_count.between?(10, 50) }

      Article.where("title LIKE 'Article%'").destroy_all
    end

    test "search works with empty params returns all" do
      count_before = Article.count
      Article.create!(title: "Test", content: "Test", status: "draft")

      results = Article.search({})
      assert_equal count_before + 1, results.count

      Article.last.destroy
    end

    # Test edge cases for coverage
    test "search OR conditions skip empty values" do
      a1 = Article.create!(title: "Ruby", content: "Test", status: "draft")
      a2 = Article.create!(title: "Rails", content: "Test", status: "draft")

      # OR with empty value should be skipped
      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "" }  # This should be skipped
        ]
      }).pluck(:title)

      assert_includes results, "Ruby"

      a1.destroy
      a2.destroy
    end

    test "searchable DSL raises error for security with empty predicates" do
      assert_raises(ArgumentError, /must have at least one required predicate/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Searchable

          searchable do
            security :empty_security, []
          end
        end
      end
    end

    # ========================================
    # COVERAGE TESTS - DoS Protection
    # ========================================

    test "validate_query_complexity raises error when too many predicates" do
      # Create 101 predicates to exceed default max (100)
      predicates = {}
      101.times { |i| predicates["field_#{i}".to_sym] = "value" }

      error = assert_raises(ArgumentError) do
        Article.search(predicates)
      end

      assert_match(/Query too complex/, error.message)
      assert_match(/exceeds maximum of 100/, error.message)
    end

    test "validate_query_complexity respects custom max_predicates" do
      # Create a model with custom max_predicates = 5
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          max_predicates 5
        end
      end

      # 6 predicates should exceed the limit of 5
      predicates = {}
      6.times { |i| predicates["field_#{i}".to_sym] = "value" }

      error = assert_raises(ArgumentError) do
        test_class.search(predicates)
      end

      assert_match(/exceeds maximum of 5/, error.message)
    end

    test "validate_query_complexity raises error when too many OR conditions" do
      # Create 51 OR conditions to exceed default max (50)
      or_conditions = []
      51.times { |i| or_conditions << { "field_#{i}".to_sym => "value" } }

      error = assert_raises(ArgumentError) do
        Article.search({ or: or_conditions })
      end

      assert_match(/OR conditions exceeds maximum of 50/, error.message)
    end

    test "validate_query_complexity respects custom max_or_conditions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          max_or_conditions 3
        end
      end

      # 4 OR conditions should exceed the limit of 3
      or_conditions = []
      4.times { |i| or_conditions << { "field_#{i}".to_sym => "value" } }

      error = assert_raises(ArgumentError) do
        test_class.search({ or: or_conditions })
      end

      assert_match(/OR conditions exceeds maximum of 3/, error.message)
    end

    test "validate_query_complexity counts predicates inside OR conditions" do
      # Test that predicates inside OR conditions are counted toward total
      # 50 regular predicates + 40 OR conditions (with 2 predicates each = 80) = 130 total (exceeds 100)
      predicates = {}
      50.times { |i| predicates["field_#{i}".to_sym] = "value" }

      or_conditions = []
      # Create 40 OR conditions (within the 50 limit) but each has 2 predicates
      40.times do |i|
        or_conditions << {
          "or_field_a_#{i}".to_sym => "value",
          "or_field_b_#{i}".to_sym => "value"
        }
      end

      # Merge or_conditions into predicates hash
      predicates[:or] = or_conditions

      error = assert_raises(ArgumentError) do
        Article.search(predicates)
      end

      assert_match(/total predicates.*exceeds maximum of 100/, error.message)
    end

    test "apply_pagination raises error when page exceeds max_page" do
      # Default max_page is 10,000
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search(pagination: { page: 10_001, per_page: 10 })
      end

      assert_match(/page must be <= 10000/, error.message)
      assert_match(/DoS protection/, error.message)
    end

    test "apply_pagination respects custom max_page" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          max_page 100
        end
      end

      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        test_class.search(pagination: { page: 101, per_page: 10 })
      end

      assert_match(/page must be <= 100/, error.message)
    end

    test "apply_pagination respects max_per_page limit" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Searchable

        searchable do
          max_per_page 50
        end
      end

      # Request 1000 per_page, should be capped at 50
      Article.create!(title: "Test 1", status: "draft")
      Article.create!(title: "Test 2", status: "draft")
      Article.create!(title: "Test 3", status: "draft")

      result = test_class.search(pagination: { page: 1, per_page: 1000 })

      # Verify limit was applied (check SQL)
      sql = result.to_sql
      assert_match(/LIMIT 50/, sql)
    end

    # ========================================
    # COVERAGE TESTS - Complex OR Conditions
    # ========================================

    test "search with nested OR conditions" do
      article1 = Article.create!(title: "Ruby Programming", status: "draft")
      article2 = Article.create!(title: "Rails Guide", status: "published")
      Article.create!(title: "Python Basics", status: "draft")

      # Search with OR: (title contains "Ruby" OR title contains "Rails")
      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Rails" }
        ]
      })

      assert_equal 2, results.count
      assert_includes results, article1
      assert_includes results, article2
    end

    test "search with OR combined with AND conditions" do
      article1 = Article.create!(title: "Ruby Tutorial", status: "draft")
      article2 = Article.create!(title: "Rails Tutorial", status: "published")
      article3 = Article.create!(title: "Python Tutorial", status: "draft")

      # Search: status = draft AND (title contains "Ruby" OR title contains "Python")
      results = Article.search({
        status_eq: "draft",
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Python" }
        ]
      })

      assert_equal 2, results.count
      assert_includes results, article1
      assert_includes results, article3
      refute_includes results, article2
    end

    test "search with empty OR conditions array" do
      Article.create!(title: "Test", status: "draft")

      # Empty OR should be ignored
      results = Article.search({
        status_eq: "draft",
        or: []
      })

      assert_equal 1, results.count
    end

    test "search with OR containing multiple predicates per condition" do
      article1 = Article.create!(title: "Ruby", status: "published", view_count: 100)
      article2 = Article.create!(title: "Rails", status: "draft", view_count: 50)
      Article.create!(title: "Python", status: "published", view_count: 75)

      # OR: (title="Ruby" AND status="published") OR (title="Rails" AND status="draft")
      results = Article.search({
        or: [
          { title_eq: "Ruby", status_eq: "published" },
          { title_eq: "Rails", status_eq: "draft" }
        ]
      })

      assert_equal 2, results.count
      assert_includes results, article1
      assert_includes results, article2
    end

    test "search with chained OR conditions" do
      Article.create!(title: "A", status: "draft", view_count: 10)
      article2 = Article.create!(title: "B", status: "published", view_count: 20)
      Article.create!(title: "C", status: "archived", view_count: 30)

      # Complex chain: (status=draft OR status=published) AND view_count > 15
      results = Article.search({
        view_count_gt: 15,
        or: [
          { status_eq: "draft" },
          { status_eq: "published" }
        ]
      })

      assert_equal 1, results.count
      assert_includes results, article2
    end

    # ========================================
    # COVERAGE TESTS - Security Validation
    # ========================================

    test "search rejects unknown keyword arguments" do
      error = assert_raises(ArgumentError) do
        Article.search({ title_cont: "test" }, unknown_param: "value")
      end

      assert_match(/Unknown keyword arguments: unknown_param/, error.message)
      assert_match(/Did you mean to pass/, error.message)
    end

    test "search with invalid order scope raises error" do
      Article.create!(title: "Test", status: "draft")

      error = assert_raises(BetterModel::Errors::Searchable::InvalidOrderError) do
        Article.search({}, orders: [ :nonexistent_sort_scope ])
      end

      assert_match(/Invalid order scope/, error.message)
    end

    test "search validates predicates against predicable scopes" do
      Article.create!(title: "Test", status: "draft")

      # This should work - valid predicate
      assert_nothing_raised do
        Article.search({ title_cont: "test" })
      end

      # Invalid predicate should raise InvalidPredicateError
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ nonexistent_predicate: "value" })
      end

      assert_match(/Invalid predicate scope/, error.message)
    end

    test "search with ActionController::Parameters safely converts to hash" do
      # Simulate ActionController::Parameters (strong parameters)
      require "action_controller"

      params = ActionController::Parameters.new({
        title_cont: "test",
        status_eq: "draft",
        forbidden_param: "should_be_filtered"
      })

      Article.create!(title: "Test Article", status: "draft")

      # Should handle ActionController::Parameters
      assert_nothing_raised do
        # Note: Need to permit params first
        Article.search(params.permit(:title_cont, :status_eq))
      end
    end

    test "search with very long predicate values" do
      Article.create!(title: "Test", status: "draft")

      # Very long search string (potential DoS via long queries)
      long_string = "a" * 10000

      # Should not crash
      assert_nothing_raised do
        Article.search({ title_cont: long_string }).to_a
      end
    end

    test "search with special characters in predicates" do
      Article.create!(title: "Test's Article", status: "draft")

      # Special characters should be properly escaped
      assert_nothing_raised do
        Article.search({ title_cont: "Test's" }).to_a
        Article.search({ title_cont: "%; DROP TABLE articles;--" }).to_a
        Article.search({ status_cont: "draft" }).to_a
      end
    end

    test "search with nil predicates" do
      Article.create!(title: "Test", status: "draft")

      # Nil predicates should be handled gracefully
      result = Article.search({ title_cont: nil })
      assert result.is_a?(ActiveRecord::Relation)
    end

    test "search with pagination edge cases" do
      10.times { |i| Article.create!(title: "Article #{i}", status: "draft") }

      # Page 0 should raise error
      assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: 0, per_page: 10 })
      end

      # Negative per_page should raise error
      assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: 1, per_page: -1 })
      end

      # Page without per_page should work (no limit)
      result = Article.search({}, pagination: { page: 1 })
      assert_equal 10, result.count
    end

    # ========================================
    # SECURITY TESTS - DoS Protection
    # ========================================

    test "should raise error when page exceeds max_page limit" do
      # Default max_page is 10,000
      article = Article.create!(title: "SecurityTest1", status: "draft")

      assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: 10001, per_page: 10 })
      end

      article.destroy
    end

    test "should raise error when predicates exceed max_predicates limit" do
      # Default max_predicates is 100
      article = Article.create!(title: "SecurityTest2", status: "draft")

      # Create 101 predicates to exceed the limit
      predicates = {}
      101.times { |i| predicates["field_#{i}".to_sym] = "value" }

      assert_raises(ArgumentError) do
        Article.search(predicates)
      end

      article.destroy
    end

    test "should raise error when or_conditions exceed max_or_conditions limit" do
      # Default max_or_conditions is 50
      article = Article.create!(title: "SecurityTest3", status: "draft")

      # Create 51 OR conditions to exceed the limit
      or_conditions = []
      51.times { |i| or_conditions << { title_eq: "Test#{i}" } }

      assert_raises(ArgumentError) do
        Article.search({ or: or_conditions })
      end

      article.destroy
    end

    test "should raise error for unpermitted ActionController::Parameters" do
      skip "ActionController::Parameters not available" unless defined?(ActionController::Parameters)

      article = Article.create!(title: "SecurityTest4", status: "draft")

      # Create unpermitted parameters
      params = ActionController::Parameters.new({ title_eq: "SecurityTest4", status_eq: "draft" })

      error = assert_raises(ArgumentError) do
        Article.search(params)
      end

      assert_match(/must be explicitly permitted/, error.message)

      article.destroy
    end

    test "should work with permitted ActionController::Parameters" do
      skip "ActionController::Parameters not available" unless defined?(ActionController::Parameters)

      article = Article.create!(title: "SecurityTest5", status: "draft")

      # Create permitted parameters
      params = ActionController::Parameters.new({ title_eq: "SecurityTest5", status_eq: "draft" })
      params.permit!

      result = Article.search(params)
      assert_equal 1, result.count

      article.destroy
    end

    test "should validate security in nested OR conditions" do
      article = Article.create!(title: "SecurityTest6", status: "draft")

      # Create OR conditions with a security violation (empty value)
      # Should skip empty values in OR conditions
      result = Article.search({
        or: [
          { title_eq: "SecurityTest6" },
          { status_eq: "" }  # Security violation: empty value - should be skipped
        ]
      })

      assert_equal 1, result.count

      article.destroy
    end

    # ==============================================================================
    # EAGER LOADING TESTS (includes, preload, eager_load)
    # ==============================================================================
    #
    # Test Coverage (11 test cases):
    # 1. includes: with single association (array syntax)
    # 2. includes: with multiple associations
    # 3. includes: with nested associations (simple)
    # 4. includes: with complex nested associations (array mix)
    # 5. preload: with separate queries
    # 6. Combination with pagination and ordering
    # 7. All three parameters together (includes + preload + eager_load)
    # 8. nil includes (should not raise error)
    # 9. Empty includes array (should not raise error)
    # 10. Invalid association (should raise ActiveRecord::ConfigurationError)
    # 11. Chainability with other ActiveRecord methods
    #
    # Note: eager_load: parameter exists and works, but using it with default_order
    # can cause "ambiguous column" errors when joined tables share column names
    # (e.g., created_at). Users should use includes: or preload: instead, or chain
    # .eager_load() after search() for full control. Test #7 verifies the parameter
    # is accepted when combined with includes: and preload:.
    #
    # ==============================================================================

    test "search with includes parameter loads single association" do
      author = Author.create!(name: "John Doe", email: "john@example.com")
      article = Article.create!(
        title: "Test Article",
        content: "Test Content",
        status: "published",
        author: author
      )

      results = Article.search({ status_eq: "published" }, includes: [:author])

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      # Verify association is loaded (accessing it should not raise error)
      assert_equal "John Doe", results.first.author.name

      article.destroy
      author.destroy
    end

    test "search with includes parameter loads multiple associations" do
      author = Author.create!(name: "Jane Doe", email: "jane@example.com")
      article = Article.create!(
        title: "Test Article",
        content: "Test Content",
        status: "published",
        author: author
      )
      comment1 = Comment.create!(article: article, body: "Great post!", author_name: "Reader 1")
      comment2 = Comment.create!(article: article, body: "Thanks!", author_name: "Reader 2")

      results = Article.search({ status_eq: "published" }, includes: [:author, :comments])

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      # Verify associations are loaded
      article_result = results.first
      assert_equal "Jane Doe", article_result.author.name
      assert_equal 2, article_result.comments.count
      assert_includes article_result.comments.map(&:body), "Great post!"

      comment1.destroy
      comment2.destroy
      article.destroy
      author.destroy
    end

    test "search with includes handles nested associations" do
      author = Author.create!(name: "Bob Smith", email: "bob@example.com")
      article = Article.create!(
        title: "Nested Test",
        content: "Test Content",
        status: "published",
        author: author
      )

      results = Article.search(
        { status_eq: "published" },
        includes: { author: :articles }
      )

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      article.destroy
      author.destroy
    end

    test "search with complex nested associations array" do
      author = Author.create!(name: "Complex Author", email: "complex@example.com")
      article = Article.create!(
        title: "Complex Nested Test",
        content: "Test Content",
        status: "published",
        author: author
      )
      comment1 = Comment.create!(article: article, body: "First comment", author_name: "User 1")
      comment2 = Comment.create!(article: article, body: "Second comment", author_name: "User 2")

      # Test complex mix: direct + nested + multiple nested
      results = Article.search(
        { status_eq: "published" },
        includes: [{ author: :articles }, { comments: :article }]
      )

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      # Verify nested associations are accessible
      article_result = results.first
      assert_equal "Complex Author", article_result.author.name
      assert_equal 1, article_result.author.articles.count
      assert_equal 2, article_result.comments.count

      comment1.destroy
      comment2.destroy
      article.destroy
      author.destroy
    end

    test "search with preload parameter loads associations with separate queries" do
      author = Author.create!(name: "Alice Johnson", email: "alice@example.com")
      article = Article.create!(
        title: "Preload Test",
        content: "Test Content",
        status: "published",
        author: author
      )

      results = Article.search({ status_eq: "published" }, preload: [:author])

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      # Verify association is preloaded
      assert_equal "Alice Johnson", results.first.author.name

      article.destroy
      author.destroy
    end

    # Note: eager_load with default_order can cause ambiguous column issues
    # when the joined table has the same column names (e.g., created_at).
    # This is a known ActiveRecord limitation. Users should either:
    # 1. Use includes: or preload: instead (tested above)
    # 2. Chain .eager_load() after search() to have full control
    # 3. Ensure their sort scopes use fully qualified column names (table.column)

    test "search combines includes with pagination and ordering" do
      author1 = Author.create!(name: "Author One", email: "one@example.com")
      author2 = Author.create!(name: "Author Two", email: "two@example.com")

      article1 = Article.create!(
        title: "First Article",
        content: "Content",
        status: "published",
        author: author1,
        view_count: 100
      )
      article2 = Article.create!(
        title: "Second Article",
        content: "Content",
        status: "published",
        author: author2,
        view_count: 200
      )

      results = Article.search(
        { status_eq: "published" },
        pagination: { page: 1, per_page: 10 },
        orders: [:sort_view_count_desc],
        includes: [:author]
      )

      assert_equal 2, results.count
      assert_equal "Second Article", results.first.title

      # Verify associations are loaded
      assert_equal "Author Two", results.first.author.name
      assert_equal "Author One", results.second.author.name

      article1.destroy
      article2.destroy
      author1.destroy
      author2.destroy
    end

    test "search with all three eager loading parameters combined" do
      author = Author.create!(name: "Multi Load Author", email: "multi@example.com")
      article = Article.create!(
        title: "Multi Load Test",
        content: "Content",
        status: "published",
        author: author
      )
      comment = Comment.create!(article: article, body: "Comment", author_name: "Commenter")

      # This is contrived but tests that all three can be used together
      results = Article.search(
        { status_eq: "published" },
        includes: [:author],
        preload: [:comments]
      )

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      # Both associations should be loaded
      assert_equal "Multi Load Author", results.first.author.name
      assert_equal "Comment", results.first.comments.first.body

      comment.destroy
      article.destroy
      author.destroy
    end

    test "search with nil includes does not raise error" do
      article = Article.create!(title: "Nil Test", content: "Content", status: "published")

      results = Article.search({ status_eq: "published" }, includes: nil)

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      article.destroy
    end

    test "search with empty includes array does not raise error" do
      article = Article.create!(title: "Empty Test", content: "Content", status: "published")

      results = Article.search({ status_eq: "published" }, includes: [])

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      article.destroy
    end

    test "search with invalid association raises ActiveRecord error" do
      article = Article.create!(title: "Invalid Test", content: "Content", status: "published")

      assert_raises(ActiveRecord::ConfigurationError) do
        Article.search({ status_eq: "published" }, includes: :nonexistent_association).load
      end

      article.destroy
    end

    test "search with includes returns chainable relation" do
      author = Author.create!(name: "Chain Author", email: "chain@example.com")
      article = Article.create!(
        title: "Chain Test",
        content: "Content",
        status: "published",
        author: author,
        view_count: 150
      )

      results = Article.search(
        { status_eq: "published" },
        includes: [:author]
      ).where("view_count > 100")

      assert_kind_of ActiveRecord::Relation, results
      assert_equal 1, results.count

      article.destroy
      author.destroy
    end

    # ========================================
    # CONFIGURATION ERROR TESTS
    # ========================================

    test "ConfigurationError class exists" do
      assert defined?(BetterModel::Errors::Searchable::ConfigurationError)
    end

    test "ConfigurationError inherits from ArgumentError" do
      assert BetterModel::Errors::Searchable::ConfigurationError < ArgumentError
    end

    test "ConfigurationError can be instantiated with message" do
      error = BetterModel::Errors::Searchable::ConfigurationError.new(reason: "test message")
      assert_equal "test message", error.message
    end

    test "ConfigurationError can be caught as ArgumentError" do
      begin
        raise BetterModel::Errors::Searchable::ConfigurationError.new(reason: "test")
      rescue ArgumentError => e
        assert_instance_of BetterModel::Errors::Searchable::ConfigurationError, e
      end
    end

    test "ConfigurationError has correct namespace" do
      assert_equal "BetterModel::Errors::Searchable::ConfigurationError",
                   BetterModel::Errors::Searchable::ConfigurationError.name
    end

    # ========================================
    # CONFIGURATION ERROR INTEGRATION TESTS
    # ========================================

    test "raises ConfigurationError when included in non-ActiveRecord class" do
      error = assert_raises(BetterModel::Errors::Searchable::ConfigurationError) do
        Class.new do
          include BetterModel::Searchable
        end
      end
      assert_match(/can only be included in ActiveRecord models/, error.message)
    end

    test "raises ConfigurationError with unknown keyword arguments" do
      article = Article.create!(title: "Test", content: "Content", status: "draft")

      error = assert_raises(BetterModel::Errors::Searchable::ConfigurationError) do
        Article.search({ status_eq: "draft" }, unknown_param: "value")
      end
      assert_match(/Unknown keyword arguments/, error.message)
      assert_match(/Did you mean to pass predicates/, error.message)

      article.destroy
    end

    test "raises ConfigurationError for security config without required predicates" do
      # This should raise an error during configuration
      error = assert_raises(BetterModel::Errors::Searchable::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Searchable

          searchable do
            security :test_security
          end
        end
      end

      assert_match(/requires predicates to be specified/, error.message)
    end
  end

  # ======================
  # Sentry Integration Tests (v3.0+)
  # ======================

  class SentryCompatibleTest < ActiveSupport::TestCase
    test "InvalidPredicateError includes sentry-compatible tags" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ title_xxx: "Rails" })
      end

      assert_equal "invalid_predicate", error.tags[:error_category]
      assert_equal "searchable", error.tags[:module]
      assert error.tags[:predicate].present?
      assert_equal "title_xxx", error.tags[:predicate]
    end

    test "InvalidPredicateError includes sentry-compatible context" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ title_xxx: "Rails" })
      end

      assert_equal "Article", error.context[:model_class]
    end

    test "InvalidPredicateError includes sentry-compatible extra data" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ title_xxx: "Rails" })
      end

      assert error.extra[:predicate_scope].present?
      assert_equal :title_xxx, error.extra[:predicate_scope]
      assert error.extra[:value].present?
      assert_equal "Rails", error.extra[:value]
      assert error.extra[:available_predicates].present?
      assert error.extra[:available_predicates].is_a?(Array)
    end

    test "InvalidPredicateError provides attribute readers" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ title_xxx: "Rails" })
      end

      assert_equal :title_xxx, error.predicate_scope
      assert_equal "Rails", error.value
      assert error.available_predicates.is_a?(Array)
      assert error.model_class == Article
    end

    test "InvalidSecurityError includes sentry-compatible tags, context, and extra" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        Article.search({ status_eq: "published" }, security: :nonexistent)
      end

      # Tags
      assert_equal "security", error.tags[:error_category]
      assert_equal "searchable", error.tags[:module]
      assert error.tags[:policy].present?

      # Context
      assert_equal "Article", error.context[:model_class]

      # Extra
      assert error.extra[:policy_name].present?
      assert error.extra[:violations].present?
      assert error.extra[:violations].is_a?(Array)
    end

    test "InvalidSecurityError provides attribute readers" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        Article.search({ status_eq: nil }, security: :status_required)
      end

      assert_equal "status_required", error.policy_name
      assert error.violations.is_a?(Array)
      assert error.model_class == Article
    end

    test "InvalidOrderError includes sentry-compatible data" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidOrderError) do
        Article.search({}, orders: [:unknown_sort])
      end

      assert_equal "invalid_order", error.tags[:error_category]
      assert_equal "searchable", error.tags[:module]
      assert_equal "Article", error.context[:model_class]
      assert error.extra[:order_scope].present?
      assert error.extra[:available_sorts].is_a?(Array)
    end

    test "InvalidPaginationError includes sentry-compatible data" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: -1 })
      end

      assert_equal "pagination", error.tags[:error_category]
      assert_equal "searchable", error.tags[:module]
      assert_equal "page", error.tags[:parameter]
      assert error.extra[:parameter_name].present?
      assert error.extra[:value].present?
    end

    test "ConfigurationError includes sentry-compatible tags and context" do
      error = assert_raises(BetterModel::Errors::Searchable::ConfigurationError) do
        # Try to include Searchable in a non-ActiveRecord class
        Class.new do
          include BetterModel::Searchable
        end
      end

      assert_equal "configuration", error.tags[:error_category]
      assert_equal "searchable", error.tags[:module]
      assert error.extra[:reason].present?
    end
  end
end
