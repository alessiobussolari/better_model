# frozen_string_literal: true

require "test_helper"

module BetterModel
  class PredicableTest < ActiveSupport::TestCase
    # Test che Article include Predicable tramite BetterModel
    test "Article should have predicable functionality" do
      assert Article.respond_to?(:predicates)
      assert Article.respond_to?(:predicable_fields)
      assert Article.respond_to?(:predicable_scopes)
      assert Article.respond_to?(:complex_predicates_registry)
    end

    # Test validazione ActiveRecord
    test "should only be includable in ActiveRecord models" do
      assert_raises(ArgumentError, /Invalid configuration/) do
        Class.new do
          include BetterModel::Predicable
        end
      end
    end

    # Test registry initialization
    test "predicable_fields should be initialized as Set" do
      assert_instance_of Set, Article.predicable_fields
    end

    test "predicable_scopes should be initialized as Set" do
      assert_instance_of Set, Article.predicable_scopes
    end

    test "complex_predicates_registry should be initialized as Hash" do
      assert_instance_of Hash, Article.complex_predicates_registry
    end

    # Test DSL predicates method
    test "predicates should validate field existence" do
      assert_raises(ArgumentError, /Invalid field name/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Predicable

          predicates :nonexistent_field
        end
      end
    end

    test "predicates should register fields in predicable_fields" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title, :view_count
      end

      assert test_class.predicable_field?(:title)
      assert test_class.predicable_field?(:view_count)
      refute test_class.predicable_field?(:nonexistent)
    end

    # Test String predicates
    test "predicates generates string scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title
      end

      assert test_class.respond_to?(:title_eq)
      assert test_class.respond_to?(:title_not_eq)
      assert test_class.respond_to?(:title_matches)
      assert test_class.respond_to?(:title_start)
      assert test_class.respond_to?(:title_end)
      assert test_class.respond_to?(:title_cont)
      assert test_class.respond_to?(:title_i_cont)
      assert test_class.respond_to?(:title_not_cont)
      assert test_class.respond_to?(:title_not_i_cont)
      assert test_class.respond_to?(:title_in)
      assert test_class.respond_to?(:title_not_in)
      assert test_class.respond_to?(:title_present)
      assert test_class.respond_to?(:title_blank)
      assert test_class.respond_to?(:title_null)
    end

    test "title_eq filters by exact match" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "Rails", content: "Test", status: "draft")

      results = Article.title_eq("Ruby").pluck(:title)
      assert_equal [ "Ruby" ], results
    end

    test "title_not_eq filters by non-match" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "Rails", content: "Test", status: "draft")

      results = Article.title_not_eq("Ruby").pluck(:title)
      assert_equal [ "Rails" ], results
    end

    test "title_start filters by prefix" do
      Article.create!(title: "Ruby on Rails", content: "Test", status: "draft")
      Article.create!(title: "Python Guide", content: "Test", status: "draft")
      Article.create!(title: "Ruby Gems", content: "Test", status: "draft")

      results = Article.title_start("Ruby").pluck(:title).sort
      assert_equal [ "Ruby Gems", "Ruby on Rails" ], results
    end

    test "title_end filters by suffix" do
      Article.create!(title: "Learning Rails", content: "Test", status: "draft")
      Article.create!(title: "Python Guide", content: "Test", status: "draft")
      Article.create!(title: "Ruby on Rails", content: "Test", status: "draft")

      results = Article.title_end("Rails").pluck(:title)
      assert_equal [ "Learning Rails", "Ruby on Rails" ], results.sort
    end

    test "title_cont filters by substring" do
      Article.create!(title: "Ruby on Rails", content: "Test", status: "draft")
      Article.create!(title: "Python Guide", content: "Test", status: "draft")
      Article.create!(title: "Rails Tutorial", content: "Test", status: "draft")

      results = Article.title_cont("Rails").pluck(:title)
      assert_equal [ "Rails Tutorial", "Ruby on Rails" ], results.sort
    end

    test "title_i_cont filters case-insensitive" do
      Article.create!(title: "Ruby on RAILS", content: "Test", status: "draft")
      Article.create!(title: "Python Guide", content: "Test", status: "draft")
      Article.create!(title: "rails tutorial", content: "Test", status: "draft")

      results = Article.title_i_cont("rails").pluck(:title)
      assert_equal [ "Ruby on RAILS", "rails tutorial" ], results.sort
    end

    test "title_not_cont filters by not containing substring" do
      Article.create!(title: "Ruby on Rails", content: "Test", status: "draft")
      Article.create!(title: "Python Guide", content: "Test", status: "draft")

      results = Article.title_not_cont("Rails").pluck(:title)
      assert_equal [ "Python Guide" ], results
    end

    test "title_not_i_cont filters case-insensitive not containing" do
      Article.create!(title: "Ruby on RAILS", content: "Test", status: "draft")
      Article.create!(title: "Python Guide", content: "Test", status: "draft")

      results = Article.title_not_i_cont("rails").pluck(:title)
      assert_equal [ "Python Guide" ], results
    end

    test "title_in filters by array of values" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "Rails", content: "Test", status: "draft")
      Article.create!(title: "Python", content: "Test", status: "draft")

      results = Article.title_in([ "Ruby", "Rails" ]).pluck(:title)
      assert_equal [ "Rails", "Ruby" ], results.sort
    end

    test "title_not_in filters by not in array" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "Rails", content: "Test", status: "draft")
      Article.create!(title: "Python", content: "Test", status: "draft")

      results = Article.title_not_in([ "Ruby", "Rails" ]).pluck(:title)
      assert_equal [ "Python" ], results
    end

    test "title_present filters non-null and non-empty" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "", content: "Test", status: "draft")
      Article.create!(title: nil, content: "Test", status: "draft")

      results = Article.title_present(true).pluck(:title)
      assert_equal [ "Ruby" ], results
    end

    test "title_blank filters null or empty" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "", content: "Test", status: "draft")
      Article.create!(title: nil, content: "Test", status: "draft")

      results = Article.title_blank(true).count
      assert_equal 2, results
    end

    test "title_null filters only null" do
      Article.create!(title: "Ruby", content: "Test", status: "draft")
      Article.create!(title: "", content: "Test", status: "draft")
      Article.create!(title: nil, content: "Test", status: "draft")

      results = Article.title_null(true).count
      assert_equal 1, results
    end

    # Test Numeric predicates
    test "predicates generates numeric scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :view_count
      end

      assert test_class.respond_to?(:view_count_eq)
      assert test_class.respond_to?(:view_count_not_eq)
      assert test_class.respond_to?(:view_count_lt)
      assert test_class.respond_to?(:view_count_lteq)
      assert test_class.respond_to?(:view_count_gt)
      assert test_class.respond_to?(:view_count_gteq)
      assert test_class.respond_to?(:view_count_in)
      assert test_class.respond_to?(:view_count_not_in)
      assert test_class.respond_to?(:view_count_present)
    end

    test "view_count_eq filters by exact value" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)

      results = Article.view_count_eq(100).pluck(:view_count)
      assert_equal [ 100 ], results
    end

    test "view_count_not_eq filters by not equal" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)

      results = Article.view_count_not_eq(100).pluck(:view_count)
      assert_equal [ 50 ], results
    end

    test "view_count_lt filters less than" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 25)

      results = Article.view_count_lt(75).pluck(:view_count)
      assert_equal [ 25, 50 ], results.sort
    end

    test "view_count_lteq filters less than or equal" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 25)

      results = Article.view_count_lteq(50).pluck(:view_count)
      assert_equal [ 25, 50 ], results.sort
    end

    test "view_count_gt filters greater than" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 25)

      results = Article.view_count_gt(40).pluck(:view_count)
      assert_equal [ 50, 100 ], results.sort
    end

    test "view_count_gteq filters greater than or equal" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 25)

      results = Article.view_count_gteq(50).pluck(:view_count)
      assert_equal [ 50, 100 ], results.sort
    end

    test "view_count_in filters by array" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 25)

      results = Article.view_count_in([ 50, 100 ]).pluck(:view_count)
      assert_equal [ 50, 100 ], results.sort
    end

    test "view_count_not_in filters by not in array" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 25)

      results = Article.view_count_not_in([ 50, 100 ]).pluck(:view_count)
      assert_equal [ 25 ], results
    end

    test "view_count_present filters non-null" do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: nil)

      results = Article.view_count_present(true).pluck(:view_count)
      assert_equal [ 100 ], results
    end

    # Test Boolean predicates
    test "predicates generates boolean scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :featured
      end

      assert test_class.respond_to?(:featured_eq)
      assert test_class.respond_to?(:featured_not_eq)
      assert test_class.respond_to?(:featured_present)
    end

    test "featured_eq filters by boolean value" do
      Article.create!(title: "A", content: "Test", status: "draft", featured: true)
      Article.create!(title: "B", content: "Test", status: "draft", featured: false)

      results = Article.featured_eq(true).pluck(:featured)
      assert_equal [ true ], results
    end

    test "featured_not_eq filters by not equal boolean" do
      Article.create!(title: "A", content: "Test", status: "draft", featured: true)
      Article.create!(title: "B", content: "Test", status: "draft", featured: false)

      results = Article.featured_not_eq(true).pluck(:featured)
      assert_equal [ false ], results
    end


    test "featured_present filters non-null" do
      Article.create!(title: "A", content: "Test", status: "draft", featured: true)
      Article.create!(title: "B", content: "Test", status: "draft", featured: nil)

      results = Article.featured_present(true).count
      assert_equal 1, results
    end

    # Test Date predicates
    test "predicates generates date scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :published_at
      end

      assert test_class.respond_to?(:published_at_eq)
      assert test_class.respond_to?(:published_at_not_eq)
      assert test_class.respond_to?(:published_at_lt)
      assert test_class.respond_to?(:published_at_lteq)
      assert test_class.respond_to?(:published_at_gt)
      assert test_class.respond_to?(:published_at_gteq)
      assert test_class.respond_to?(:published_at_in)
      assert test_class.respond_to?(:published_at_not_in)
      assert test_class.respond_to?(:published_at_present)
      assert test_class.respond_to?(:published_at_blank)
      assert test_class.respond_to?(:published_at_null)
    end

    test "published_at_eq filters by exact date" do
      date = 1.day.ago
      Article.create!(title: "A", content: "Test", status: "draft", published_at: date)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: 2.days.ago)

      results = Article.published_at_eq(date).count
      assert_equal 1, results
    end

    test "published_at_not_eq filters by not equal date" do
      date = 1.day.ago
      Article.create!(title: "A", content: "Test", status: "draft", published_at: date)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: 2.days.ago)

      results = Article.published_at_not_eq(date).count
      assert_equal 1, results
    end

    test "published_at_lt filters before date" do
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: 1.day.ago)

      results = Article.published_at_lt(2.days.ago).count
      assert_equal 1, results
    end

    test "published_at_lteq filters before or equal date" do
      date = 2.days.ago
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: date)
      Article.create!(title: "C", content: "Test", status: "draft", published_at: 1.day.ago)

      results = Article.published_at_lteq(date).count
      assert_equal 2, results
    end

    test "published_at_gt filters after date" do
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: 1.day.ago)

      results = Article.published_at_gt(2.days.ago).count
      assert_equal 1, results
    end

    test "published_at_gteq filters after or equal date" do
      date = 2.days.ago
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: date)
      Article.create!(title: "C", content: "Test", status: "draft", published_at: 1.day.ago)

      results = Article.published_at_gteq(date).count
      assert_equal 2, results
    end

    test "published_at_in filters by array of dates" do
      date1 = 1.day.ago
      date2 = 2.days.ago
      Article.create!(title: "A", content: "Test", status: "draft", published_at: date1)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: date2)
      Article.create!(title: "C", content: "Test", status: "draft", published_at: 3.days.ago)

      results = Article.published_at_in([ date1, date2 ]).count
      assert_equal 2, results
    end

    test "published_at_not_in filters by not in array" do
      date1 = 1.day.ago
      date2 = 2.days.ago
      Article.create!(title: "A", content: "Test", status: "draft", published_at: date1)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: date2)
      Article.create!(title: "C", content: "Test", status: "draft", published_at: 3.days.ago)

      results = Article.published_at_not_in([ date1, date2 ]).count
      assert_equal 1, results
    end

    test "published_at_present filters non-null" do
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 1.day.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: nil)

      results = Article.published_at_present(true).count
      assert_equal 1, results
    end

    test "published_at_blank filters null" do
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 1.day.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: nil)

      results = Article.published_at_blank(true).count
      assert_equal 1, results
    end

    test "published_at_null filters null" do
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 1.day.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: nil)

      results = Article.published_at_null(true).count
      assert_equal 1, results
    end

    test "published_at_null(false) filters non-null" do
      Article.create!(title: "A", content: "Test", status: "draft", published_at: 1.day.ago)
      Article.create!(title: "B", content: "Test", status: "draft", published_at: nil)

      results = Article.published_at_null(false).count
      assert_equal 1, results
    end

    # Test Complex Predicates
    test "register_complex_predicate creates custom scope" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :view_count, :published_at

        register_complex_predicate :recent_popular do |days = 7, min_views = 100|
          where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
        end
      end

      assert test_class.respond_to?(:recent_popular)
      assert test_class.complex_predicate?(:recent_popular)
    end

    test "complex predicate works with parameters" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :view_count, :published_at

        register_complex_predicate :recent_popular do |days = 7, min_views = 100|
          where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
        end
      end

      test_class.create!(title: "Recent Popular", content: "Test", status: "draft",
                         view_count: 150, published_at: 3.days.ago)
      test_class.create!(title: "Old Popular", content: "Test", status: "draft",
                         view_count: 150, published_at: 10.days.ago)
      test_class.create!(title: "Recent Unpopular", content: "Test", status: "draft",
                         view_count: 50, published_at: 3.days.ago)

      results = test_class.recent_popular(7, 100).pluck(:title)
      assert_equal [ "Recent Popular" ], results
    end

    test "register_complex_predicate requires block" do
      assert_raises(ArgumentError, /Block required/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Predicable

          register_complex_predicate :invalid
        end
      end
    end

    # Test registry tracking
    test "predicable_scopes tracks all generated scopes for strings" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title
      end

      assert test_class.predicable_scope?(:title_eq)
      assert test_class.predicable_scope?(:title_cont)
      assert test_class.predicable_scope?(:title_i_cont)
      assert test_class.predicable_scope?(:title_in)
      assert test_class.predicable_scope?(:title_present)
    end

    test "predicable_scopes tracks all generated scopes for numerics" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :view_count
      end

      assert test_class.predicable_scope?(:view_count_eq)
      assert test_class.predicable_scope?(:view_count_lt)
      assert test_class.predicable_scope?(:view_count_gt)
      assert test_class.predicable_scope?(:view_count_in)
      assert test_class.predicable_scope?(:view_count_present)
    end

    test "predicable_scopes tracks all generated scopes for booleans" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :featured
      end

      assert test_class.predicable_scope?(:featured_eq)
      assert test_class.predicable_scope?(:featured_present)
    end

    test "predicable_scopes tracks all generated scopes for dates" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :published_at
      end

      assert test_class.predicable_scope?(:published_at_eq)
      assert test_class.predicable_scope?(:published_at_lt)
      assert test_class.predicable_scope?(:published_at_gt)
      assert test_class.predicable_scope?(:published_at_in)
      assert test_class.predicable_scope?(:published_at_present)
      assert test_class.predicable_scope?(:published_at_null)
    end

    # Test thread-safety
    test "predicable_fields should be frozen" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title
      end

      assert test_class.predicable_fields.frozen?
    end

    test "predicable_scopes should be frozen" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title
      end

      assert test_class.predicable_scopes.frozen?
    end

    test "complex_predicates_registry should be frozen" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        register_complex_predicate :test do
          where(id: 1)
        end
      end

      assert test_class.complex_predicates_registry.frozen?
    end

    # Test chaining
    test "can chain multiple predicate scopes" do
      Article.create!(title: "Ruby on Rails", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Python Guide", content: "Test", status: "draft", view_count: 150)
      Article.create!(title: "Ruby Gems", content: "Test", status: "draft", view_count: 50)

      results = Article.title_cont("Ruby").view_count_gt(75).pluck(:title)
      assert_equal [ "Ruby on Rails" ], results
    end

    test "can chain with sorting scopes" do
      Article.create!(title: "Ruby B", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Ruby A", content: "Test", status: "draft", view_count: 150)
      Article.create!(title: "Python", content: "Test", status: "draft", view_count: 50)

      results = Article.title_cont("Ruby").sort_view_count_desc.pluck(:title)
      assert_equal [ "Ruby A", "Ruby B" ], results
    end

    # Test multiple fields
    test "predicates can define multiple fields at once" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title, :view_count, :published_at, :featured
      end

      assert test_class.predicable_field?(:title)
      assert test_class.predicable_field?(:view_count)
      assert test_class.predicable_field?(:published_at)
      assert test_class.predicable_field?(:featured)
    end

    # Test inheritance
    test "subclasses inherit predicable fields" do
      parent_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title
      end

      subclass = Class.new(parent_class)

      assert subclass.predicable_field?(:title)
      assert subclass.respond_to?(:title_eq)
    end

    test "subclasses can define additional predicable fields" do
      parent_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :title
      end

      subclass = Class.new(parent_class) do
        self.table_name = "articles"
        predicates :view_count
      end

      assert subclass.predicable_field?(:title)
      assert subclass.predicable_field?(:view_count)
      refute parent_class.predicable_field?(:view_count)
    end

    # Test Complex Predicates: Range Queries (_between, _not_between)
    test "view_count_between filters within numeric range" do
      Article.create!(title: "Low", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "Medium", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "High", content: "Test", status: "draft", view_count: 200)

      results = Article.view_count_between(75, 150).pluck(:view_count)
      assert_equal [ 100 ], results
    end

    test "view_count_not_between filters outside numeric range" do
      Article.create!(title: "Low", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "Medium", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "High", content: "Test", status: "draft", view_count: 200)

      results = Article.view_count_not_between(75, 150).pluck(:view_count).sort
      assert_equal [ 50, 200 ], results
    end

    test "published_at_between filters within date range" do
      Article.create!(title: "Old", content: "Test", status: "draft", published_at: 10.days.ago)
      Article.create!(title: "Mid", content: "Test", status: "draft", published_at: 5.days.ago)
      Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)

      results = Article.published_at_between(7.days.ago, 3.days.ago).count
      assert_equal 1, results
    end

    test "published_at_not_between filters outside date range" do
      Article.create!(title: "Old", content: "Test", status: "draft", published_at: 10.days.ago)
      Article.create!(title: "Mid", content: "Test", status: "draft", published_at: 5.days.ago)
      Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)

      results = Article.published_at_not_between(7.days.ago, 3.days.ago).count
      assert_equal 2, results
    end


    # Test _within with auto-detection
    test "published_at_within accepts numeric days" do
      Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "Old", content: "Test", status: "draft", published_at: 10.days.ago)

      results = Article.published_at_within(7).pluck(:title)
      assert_equal [ "Recent" ], results
    end

    test "published_at_within accepts ActiveSupport::Duration" do
      Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "Old", content: "Test", status: "draft", published_at: 10.days.ago)

      results = Article.published_at_within(7.days).pluck(:title)
      assert_equal [ "Recent" ], results
    end

    test "published_at_within works with hours" do
      Article.create!(title: "Very recent", content: "Test", status: "draft", published_at: 1.hour.ago)
      Article.create!(title: "Old", content: "Test", status: "draft", published_at: 2.days.ago)

      results = Article.published_at_within(6.hours).pluck(:title)
      assert_equal [ "Very recent" ], results
    end

    test "created_at_within works with weeks" do
      Article.create!(title: "Recent", content: "Test", status: "draft", created_at: 5.days.ago)
      Article.create!(title: "Old", content: "Test", status: "draft", created_at: 3.weeks.ago)

      results = Article.created_at_within(2.weeks).pluck(:title)
      assert_equal [ "Recent" ], results
    end

    # Test scope generation for complex predicates
    test "numeric fields generate _between and _not_between scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :view_count
      end

      assert test_class.respond_to?(:view_count_between)
      assert test_class.respond_to?(:view_count_not_between)
      assert test_class.predicable_scope?(:view_count_between)
      assert test_class.predicable_scope?(:view_count_not_between)
    end

    test "date fields generate all convenience scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable

        predicates :published_at
      end

      # Range
      assert test_class.respond_to?(:published_at_between)
      assert test_class.respond_to?(:published_at_not_between)

      # Convenience
      assert test_class.respond_to?(:published_at_within)

      # Registry
      assert test_class.predicable_scope?(:published_at_between)
      assert test_class.predicable_scope?(:published_at_within)
    end

    # Test PostgreSQL-specific predicates (conditional based on adapter)
    # These tests will be skipped if not using PostgreSQL
    # Note: Since the dummy app uses SQLite, these tests verify the methods exist but won't test functionality

    test "postgresql_adapter? returns false for SQLite" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
      end

      refute test_class.send(:postgresql_adapter?)
    end

    # Test validation errors for coverage
    test "predicates raises error for invalid field name" do
      assert_raises(ArgumentError, /Invalid field name.*does not exist in the table/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Predicable

          predicates :nonexistent_field
        end
      end
    end

    test "register_complex_predicate raises error without block" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
      end

      assert_raises(ArgumentError, /Block required for complex predicate/) do
        test_class.register_complex_predicate(:test_predicate)
      end
    end


    # ========================================
    # COVERAGE TESTS - Opzione B: Riflessione
    # ========================================

    test "all base predicates are generated and registered for each field" do
      Article.predicable_fields.each do |field|
        # Verifica esistenza scope _eq
        assert Article.respond_to?(:"#{field}_eq"),
               "Expected Article to have #{field}_eq scope"

        # Verifica esistenza scope _not_eq
        assert Article.respond_to?(:"#{field}_not_eq"),
               "Expected Article to have #{field}_not_eq scope"

        # Verifica esistenza scope _present
        assert Article.respond_to?(:"#{field}_present"),
               "Expected Article to have #{field}_present scope"

        # Verifica registrazione negli scope
        assert_includes Article.predicable_scopes, :"#{field}_eq",
                        "Expected #{field}_eq to be registered in predicable_scopes"
        assert_includes Article.predicable_scopes, :"#{field}_not_eq",
                        "Expected #{field}_not_eq to be registered in predicable_scopes"
        assert_includes Article.predicable_scopes, :"#{field}_present",
                        "Expected #{field}_present to be registered in predicable_scopes"
      end
    end

    test "all string predicates are generated for string fields" do
      string_fields = Article.predicable_fields.select do |field|
        Article.columns_hash[field.to_s]&.type == :string
      end

      string_fields.each do |field|
        # Verifica predicati string
        assert Article.respond_to?(:"#{field}_cont"), "Expected #{field}_cont"
        assert Article.respond_to?(:"#{field}_not_cont"), "Expected #{field}_not_cont"
        assert Article.respond_to?(:"#{field}_i_cont"), "Expected #{field}_i_cont"
        assert Article.respond_to?(:"#{field}_not_i_cont"), "Expected #{field}_not_i_cont"
        assert Article.respond_to?(:"#{field}_start"), "Expected #{field}_start"
        assert Article.respond_to?(:"#{field}_end"), "Expected #{field}_end"
        # Note: _i_eq is not generated by define_string_predicates
      end
    end

    test "all numeric predicates are generated for numeric fields" do
      numeric_fields = Article.predicable_fields.select do |field|
        [ :integer, :decimal, :float ].include?(Article.columns_hash[field.to_s]&.type)
      end

      numeric_fields.each do |field|
        # Verifica predicati numeric
        assert Article.respond_to?(:"#{field}_gt"), "Expected #{field}_gt"
        assert Article.respond_to?(:"#{field}_gteq"), "Expected #{field}_gteq"
        assert Article.respond_to?(:"#{field}_lt"), "Expected #{field}_lt"
        assert Article.respond_to?(:"#{field}_lteq"), "Expected #{field}_lteq"
        assert Article.respond_to?(:"#{field}_between"), "Expected #{field}_between"
      end
    end

    test "all datetime predicates are generated for datetime fields" do
      datetime_fields = Article.predicable_fields.select do |field|
        [ :datetime, :date, :time ].include?(Article.columns_hash[field.to_s]&.type)
      end

      datetime_fields.each do |field|
        # Verifica predicati datetime
        assert Article.respond_to?(:"#{field}_gt"), "Expected #{field}_gt"
        assert Article.respond_to?(:"#{field}_lt"), "Expected #{field}_lt"
        assert Article.respond_to?(:"#{field}_gteq"), "Expected #{field}_gteq"
        assert Article.respond_to?(:"#{field}_lteq"), "Expected #{field}_lteq"
        assert Article.respond_to?(:"#{field}_between"), "Expected #{field}_between"
        assert Article.respond_to?(:"#{field}_blank"), "Expected #{field}_blank"
      end
    end

    test "all boolean predicates are generated for boolean fields" do
      boolean_fields = Article.predicable_fields.select do |field|
        Article.columns_hash[field.to_s]&.type == :boolean
      end

      boolean_fields.each do |field|
        # Verifica predicati boolean (use _eq instead of _true/_false)
        assert Article.respond_to?(:"#{field}_eq"), "Expected #{field}_eq"
      end
    end

    # ========================================
    # COVERAGE TESTS - Opzione C: Esecuzione
    # ========================================

    test "all base predicates execute without errors" do
      Article.predicable_fields.each do |field|
        # Test _eq
        result = Article.send(:"#{field}_eq", "test_value")
        assert result.is_a?(ActiveRecord::Relation),
               "Expected #{field}_eq to return ActiveRecord::Relation"

        # Test _not_eq
        result = Article.send(:"#{field}_not_eq", "test_value")
        assert result.is_a?(ActiveRecord::Relation),
               "Expected #{field}_not_eq to return ActiveRecord::Relation"

        # Test _present
        result = Article.send(:"#{field}_present", true)
        assert result.is_a?(ActiveRecord::Relation),
               "Expected #{field}_present to return ActiveRecord::Relation"
      end
    end

    test "string predicates execute without errors for string fields" do
      string_fields = Article.predicable_fields.select do |field|
        Article.columns_hash[field.to_s]&.type == :string
      end

      string_fields.each do |field|
        # Test alcuni predicati string
        assert_nothing_raised { Article.send(:"#{field}_cont", "test").to_a }
        assert_nothing_raised { Article.send(:"#{field}_i_cont", "test").to_a }
        assert_nothing_raised { Article.send(:"#{field}_start", "test").to_a }
      end
    end

    test "numeric predicates execute without errors for numeric fields" do
      numeric_fields = Article.predicable_fields.select do |field|
        [ :integer, :decimal, :float ].include?(Article.columns_hash[field.to_s]&.type)
      end

      numeric_fields.each do |field|
        # Test alcuni predicati numeric
        assert_nothing_raised { Article.send(:"#{field}_gt", 10).to_a }
        assert_nothing_raised { Article.send(:"#{field}_between", 1, 100).to_a }
      end
    end

    test "datetime predicates execute without errors for datetime fields" do
      datetime_fields = Article.predicable_fields.select do |field|
        [ :datetime, :date, :time ].include?(Article.columns_hash[field.to_s]&.type)
      end

      datetime_fields.each do |field|
        # Test alcuni predicati datetime
        assert_nothing_raised { Article.send(:"#{field}_gt", 1.day.ago).to_a }
        assert_nothing_raised { Article.send(:"#{field}_between", 1.week.ago, Time.current).to_a }
      end
    end

    test "boolean predicates execute without errors for boolean fields" do
      boolean_fields = Article.predicable_fields.select do |field|
        Article.columns_hash[field.to_s]&.type == :boolean
      end

      boolean_fields.each do |field|
        # Test predicati boolean (use _eq with true/false)
        assert_nothing_raised { Article.send(:"#{field}_eq", true).to_a }
        assert_nothing_raised { Article.send(:"#{field}_eq", false).to_a }
      end
    end

    # ========================================
    # COVERAGE TESTS - Edge Cases
    # ========================================

    test "predicates work with nil values" do
      # Test che i predicati gestiscano correttamente nil
      article = Article.create!(title: nil, status: "draft")

      # title_present dovrebbe ESCLUDERE record con title nil
      refute_includes Article.title_present(true), article

      # title_blank dovrebbe INCLUDERE record con title nil
      assert_includes Article.title_blank(true), article
    end

    test "predicates can be chained" do
      # Verifica che i predicati siano chainabili
      result = Article.status_eq("published").view_count_gt(50)
      assert result.is_a?(ActiveRecord::Relation)

      # Test chain multipla
      result = Article.status_eq("draft").title_cont("test").view_count_lteq(100)
      assert result.is_a?(ActiveRecord::Relation)
    end

    # ========================================
    # COVERAGE TESTS - PostgreSQL-specific Predicates Documentation
    # Note: These predicates require PostgreSQL adapter and cannot be fully tested with SQLite
    # ========================================

    test "postgresql array and jsonb predicates are not generated for SQLite" do
      # Verify that PostgreSQL-specific predicates are not generated when using SQLite
      # These include: _overlaps, _contains, _contained_by (for arrays)
      # and _has_key, _has_any_key, _has_all_keys, _jsonb_contains (for JSONB)

      # Since we're using SQLite, these methods should not exist
      refute Article.respond_to?(:tags_overlaps), "Array predicate should not exist for SQLite"
      refute Article.respond_to?(:metadata_has_key), "JSONB predicate should not exist for SQLite"

      # NOTE: To fully test PostgreSQL-specific predicates (lines 294-392 in predicable.rb),
      # you would need to:
      # 1. Set up a PostgreSQL database in the test environment
      # 2. Create test tables with array and jsonb column types
      # 3. Test that the predicates are generated and work correctly
      #
      # These lines are intentionally uncovered in the SQLite test suite:
      # - Lines 294-343: define_postgresql_array_predicates (3 scopes)
      # - Lines 346-392: define_postgresql_jsonb_predicates (4 scopes)
      # - Line 476: postgresql_adapter? helper method (partially covered above)
    end

    # ========================================
    # Test: No Method Redefinition Warnings
    # ========================================

    test "no method redefinition warnings for string _present scopes" do
      # Capture warnings during scope definition
      original_stderr = $stderr
      $stderr = StringIO.new

      begin
        # Create a new class with string predicates
        test_class = Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Predicable

          predicates :title, :status
        end

        # Get captured warnings
        warnings = $stderr.string

        # Verify no "method redefined" warnings for _present scopes
        refute_match(/warning: method redefined.*title_present/, warnings,
                     "Should not have method redefinition warning for title_present")
        refute_match(/warning: method redefined.*status_present/, warnings,
                     "Should not have method redefinition warning for status_present")
        refute_match(/warning: previous definition of title_present/, warnings,
                     "Should not have previous definition warning for title_present")
        refute_match(/warning: previous definition of status_present/, warnings,
                     "Should not have previous definition warning for status_present")

        # Verify the scopes still work correctly
        assert test_class.respond_to?(:title_present)
        assert test_class.respond_to?(:status_present)
      ensure
        $stderr = original_stderr
      end
    end
  end

  # ==============================================================================
  # COMPLEX PREDICATES COMPREHENSIVE TESTS
  # ==============================================================================

  class ComplexPredicatesTest < ActiveSupport::TestCase
    test "complex predicate returns ActiveRecord::Relation" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :view_count, :published_at

        register_complex_predicate :trending do
          where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
        end
      end

      relation = test_class.trending
      assert_kind_of ActiveRecord::Relation, relation
      assert_respond_to relation, :where
      assert_respond_to relation, :order
      assert_respond_to relation, :limit
      assert_respond_to relation, :count
    end

    test "complex predicate is chainable with standard predicates" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status, :title, :view_count

        register_complex_predicate :popular do
          where("view_count >= ?", 1000)
        end
      end

      # Chain with standard predicates
      chain = test_class.popular.status_eq("published").title_cont("Ruby")
      assert_kind_of ActiveRecord::Relation, chain
      assert_respond_to chain, :to_sql
    end

    test "complex predicate accepts multiple parameters with defaults" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :view_count, :published_at

        register_complex_predicate :trending do |days = 7, min_views = 100|
          where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
        end
      end

      # Should work with no parameters (defaults)
      relation1 = test_class.trending
      assert_kind_of ActiveRecord::Relation, relation1

      # Should work with custom parameters
      relation2 = test_class.trending(14, 500)
      assert_kind_of ActiveRecord::Relation, relation2
    end

    test "complex predicates registry is thread-safe (frozen)" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status

        register_complex_predicate :test_predicate do
          where(status: "published")
        end
      end

      registry = test_class.complex_predicates_registry
      assert registry.frozen?, "Registry should be frozen for thread-safety"
    end

    test "complex predicates are inherited by subclasses" do
      parent_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status

        register_complex_predicate :parent_predicate do
          where(status: "draft")
        end
      end

      child_class = Class.new(parent_class)

      assert child_class.respond_to?(:parent_predicate)
      relation = child_class.parent_predicate
      assert_kind_of ActiveRecord::Relation, relation
    end

    test "complex_predicate? introspection method works" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status

        register_complex_predicate :published do
          where(status: "published")
        end
      end

      assert test_class.complex_predicate?(:published)
      refute test_class.complex_predicate?(:nonexistent)
      refute test_class.complex_predicate?(:status_eq) # Standard predicate, not complex
    end

    test "complex predicates integrate with existing model scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status, :view_count

        scope :recent, -> { where("created_at >= ?", 1.week.ago) }

        register_complex_predicate :popular do
          where("view_count >= ?", 1000)
        end
      end

      # Should be able to chain with existing scopes
      chain = test_class.recent.popular.status_eq("published")
      assert_kind_of ActiveRecord::Relation, chain
    end

    test "complex predicates generate valid SQL" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :view_count, :published_at

        register_complex_predicate :trending do |min_views = 100|
          where("view_count >= ?", min_views)
        end
      end

      sql = test_class.trending(500).to_sql
      assert_includes sql, "view_count >= 500"
    end

    test "complex predicates work with count and exists" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :view_count

        register_complex_predicate :popular do
          where("view_count >= ?", 1000)
        end
      end

      # These should not raise errors
      assert_respond_to test_class.popular, :count
      assert_respond_to test_class.popular, :exists?
    end

    test "complex predicates registry tracks all registered predicates" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status

        register_complex_predicate :first_predicate do
          where(status: "published")
        end

        register_complex_predicate :second_predicate do
          where(status: "draft")
        end
      end

      registry = test_class.complex_predicates_registry
      assert_includes registry.keys, :first_predicate
      assert_includes registry.keys, :second_predicate
      assert_equal 2, registry.size
    end

    test "multiple complex predicates can be registered and used together" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status, :view_count, :published_at

        register_complex_predicate :popular do
          where("view_count >= ?", 1000)
        end

        register_complex_predicate :recent do
          where("published_at >= ?", 7.days.ago)
        end
      end

      # Should be able to chain multiple complex predicates
      chain = test_class.popular.recent.status_eq("published")
      assert_kind_of ActiveRecord::Relation, chain
      assert_respond_to chain, :to_sql
    end

    test "complex predicates with parameter validation" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :view_count

        register_complex_predicate :min_views do |count|
          raise ArgumentError, "count must be positive" unless count.to_i > 0
          where("view_count >= ?", count.to_i)
        end
      end

      # Should work with valid parameter
      assert_kind_of ActiveRecord::Relation, test_class.min_views(100)

      # Should raise with invalid parameter
      assert_raises(ArgumentError) { test_class.min_views(-1) }
      assert_raises(ArgumentError) { test_class.min_views(0) }
    end

    test "complex predicates with association queries" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :status

        # Simulate association by using table name in query
        register_complex_predicate :with_comments do |min_count = 1|
          where("(SELECT COUNT(*) FROM comments WHERE comments.article_id = articles.id) >= ?", min_count)
        end
      end

      relation = test_class.with_comments(5)
      assert_kind_of ActiveRecord::Relation, relation
      sql = relation.to_sql
      assert_includes sql, "SELECT COUNT(*) FROM comments"
    end

    test "complex predicates prevent SQL injection" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Predicable
        predicates :title

        register_complex_predicate :safe_search do |search_term|
          # Use proper parameterization - the ? placeholder handles SQL escaping
          sanitized = ActiveRecord::Base.sanitize_sql_like(search_term)
          where("title LIKE ?", "%#{sanitized}%")
        end
      end

      # Malicious input should be safely handled
      malicious_input = "'; DROP TABLE articles; --"
      relation = test_class.safe_search(malicious_input)

      # The query should execute without raising an error (proof it's safe)
      assert_kind_of ActiveRecord::Relation, relation
      assert_nothing_raised { relation.to_sql }

      # Verify the query structure is safe - it should use parameterized LIKE
      sql = relation.to_sql
      assert_includes sql, "LIKE", "Should contain LIKE clause"

      # The quotes should be escaped (doubled) in the SQL output
      # When ActiveRecord escapes, ' becomes '' in the SQL string representation
      assert_includes sql, "''", "Single quotes should be escaped (doubled)"
    end

    test "complex predicates with empty blocks raise error" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Predicable
          predicates :status

          register_complex_predicate :empty_predicate
        end
      end
    end

    # ========================================
    # CONFIGURATION ERROR TESTS
    # ========================================

    test "ConfigurationError class exists" do
      assert defined?(BetterModel::Errors::Predicable::ConfigurationError)
    end

    test "ConfigurationError inherits from ArgumentError" do
      assert BetterModel::Errors::Predicable::ConfigurationError < ArgumentError
    end

    test "ConfigurationError can be instantiated with message" do
      error = BetterModel::Errors::Predicable::ConfigurationError.new("test message")
      assert_equal "test message", error.message
    end

    test "ConfigurationError can be caught as ArgumentError" do
      begin
        raise BetterModel::Errors::Predicable::ConfigurationError.new("test")
      rescue ArgumentError => e
        assert_instance_of BetterModel::Errors::Predicable::ConfigurationError, e
      end
    end

    test "ConfigurationError has correct namespace" do
      assert_equal "BetterModel::Errors::Predicable::ConfigurationError",
                   BetterModel::Errors::Predicable::ConfigurationError.name
    end

    # ========================================
    # CONFIGURATION ERROR INTEGRATION TESTS
    # ========================================

    test "raises ConfigurationError when included in non-ActiveRecord class" do
      error = assert_raises(BetterModel::Errors::Predicable::ConfigurationError) do
        Class.new do
          include BetterModel::Predicable
        end
      end
      assert_match(/can only be included in ActiveRecord models/, error.message)
    end

    test "raises ConfigurationError when field does not exist" do
      error = assert_raises(BetterModel::Errors::Predicable::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Predicable

          predicates :nonexistent_field
        end
      end
      assert_match(/Invalid field name/, error.message)
      assert_match(/does not exist/, error.message)
    end

    test "raises ConfigurationError when register_complex_predicate has no block" do
      error = assert_raises(BetterModel::Errors::Predicable::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Predicable

          register_complex_predicate :test_predicate
        end
      end
      assert_match(/Block required for complex predicate/, error.message)
    end
  end
end
