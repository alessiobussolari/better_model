# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Predicable do
  describe "module inclusion" do
    it "is defined" do
      expect(defined?(BetterModel::Predicable)).to be_truthy
    end

    it "can be included in a model" do
      test_class = create_predicable_class("PredicableInclusionTest") do
        predicates :title, :status
      end

      expect(test_class).to respond_to(:predicable_fields)
    end

    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Predicable
        end
      end.to raise_error(BetterModel::Errors::Predicable::ConfigurationError, /can only be included in ActiveRecord models/)
    end
  end

  describe "registry initialization" do
    let(:test_class) do
      create_predicable_class("PredicableRegistryTest") do
        predicates :title
      end
    end

    it "initializes predicable_fields as Set" do
      expect(test_class.predicable_fields).to be_a(Set)
    end

    it "initializes predicable_scopes as Set" do
      expect(test_class.predicable_scopes).to be_a(Set)
    end

    it "initializes complex_predicates_registry as Hash" do
      expect(test_class.complex_predicates_registry).to be_a(Hash)
    end
  end

  describe "predicates DSL" do
    context "with valid fields" do
      let(:test_class) do
        create_predicable_class("PredicateDSLTest") do
          predicates :title, :view_count, :published_at, :featured
        end
      end

      it "registers fields in predicable_fields" do
        expect(test_class.predicable_field?(:title)).to be true
        expect(test_class.predicable_field?(:view_count)).to be true
        expect(test_class.predicable_field?(:published_at)).to be true
        expect(test_class.predicable_field?(:featured)).to be true
      end

      it "returns false for non-existent fields" do
        expect(test_class.predicable_field?(:nonexistent)).to be false
      end
    end

    context "with invalid fields" do
      it "raises ConfigurationError for non-existent field" do
        expect do
          create_predicable_class("PredicateInvalidTest") do
            predicates :nonexistent_field
          end
        end.to raise_error(BetterModel::Errors::Predicable::ConfigurationError, /Invalid field name/)
      end
    end
  end

  describe "string predicates" do
    let(:test_class) do
      create_predicable_class("StringPredicateTest") do
        predicates :title
      end
    end

    it "generates all string scopes" do
      expect(test_class).to respond_to(:title_eq)
      expect(test_class).to respond_to(:title_not_eq)
      expect(test_class).to respond_to(:title_matches)
      expect(test_class).to respond_to(:title_start)
      expect(test_class).to respond_to(:title_end)
      expect(test_class).to respond_to(:title_cont)
      expect(test_class).to respond_to(:title_i_cont)
      expect(test_class).to respond_to(:title_not_cont)
      expect(test_class).to respond_to(:title_not_i_cont)
      expect(test_class).to respond_to(:title_in)
      expect(test_class).to respond_to(:title_not_in)
      expect(test_class).to respond_to(:title_present)
      expect(test_class).to respond_to(:title_blank)
      expect(test_class).to respond_to(:title_null)
    end

    describe "string scope functionality" do
      before do
        Article.create!(title: "Ruby", content: "Test", status: "draft")
        Article.create!(title: "Rails", content: "Test", status: "draft")
        Article.create!(title: "Python Guide", content: "Test", status: "draft")
      end

      it "filters by exact match with _eq" do
        expect(Article.title_eq("Ruby").pluck(:title)).to eq([ "Ruby" ])
      end

      it "filters by non-match with _not_eq" do
        expect(Article.title_not_eq("Ruby").pluck(:title).sort).to eq([ "Python Guide", "Rails" ])
      end

      it "filters by prefix with _start" do
        expect(Article.title_start("Ru").pluck(:title).sort).to eq([ "Ruby" ])
      end

      it "filters by suffix with _end" do
        expect(Article.title_end("uide").pluck(:title)).to eq([ "Python Guide" ])
      end

      it "filters by substring with _cont" do
        expect(Article.title_cont("ail").pluck(:title).sort).to eq([ "Rails" ])
      end

      it "filters case-insensitive with _i_cont" do
        Article.create!(title: "RUBY ON RAILS", content: "Test", status: "draft")
        expect(Article.title_i_cont("rails").pluck(:title).sort).to eq([ "RUBY ON RAILS", "Rails" ])
      end

      it "filters by not containing with _not_cont" do
        expect(Article.title_not_cont("Rails").pluck(:title).sort).to eq([ "Python Guide", "Ruby" ])
      end

      it "filters by array with _in" do
        expect(Article.title_in([ "Ruby", "Rails" ]).pluck(:title).sort).to eq([ "Rails", "Ruby" ])
      end

      it "filters by not in array with _not_in" do
        expect(Article.title_not_in([ "Ruby", "Rails" ]).pluck(:title)).to eq([ "Python Guide" ])
      end
    end

    describe "presence and null scopes" do
      before do
        Article.create!(title: "Ruby", content: "Test", status: "draft")
        Article.create!(title: "", content: "Test", status: "draft")
        Article.create!(title: nil, content: "Test", status: "draft")
      end

      it "filters non-null and non-empty with _present" do
        expect(Article.title_present(true).pluck(:title)).to eq([ "Ruby" ])
      end

      it "filters null or empty with _blank" do
        expect(Article.title_blank(true).count).to eq(2)
      end

      it "filters only null with _null" do
        expect(Article.title_null(true).count).to eq(1)
      end
    end
  end

  describe "numeric predicates" do
    let(:test_class) do
      create_predicable_class("NumericPredicateTest") do
        predicates :view_count
      end
    end

    it "generates all numeric scopes" do
      expect(test_class).to respond_to(:view_count_eq)
      expect(test_class).to respond_to(:view_count_not_eq)
      expect(test_class).to respond_to(:view_count_lt)
      expect(test_class).to respond_to(:view_count_lteq)
      expect(test_class).to respond_to(:view_count_gt)
      expect(test_class).to respond_to(:view_count_gteq)
      expect(test_class).to respond_to(:view_count_in)
      expect(test_class).to respond_to(:view_count_not_in)
      expect(test_class).to respond_to(:view_count_present)
      expect(test_class).to respond_to(:view_count_between)
      expect(test_class).to respond_to(:view_count_not_between)
    end

    describe "numeric scope functionality" do
      before do
        Article.create!(title: "A", content: "Test", status: "draft", view_count: 100)
        Article.create!(title: "B", content: "Test", status: "draft", view_count: 50)
        Article.create!(title: "C", content: "Test", status: "draft", view_count: 25)
      end

      it "filters by exact value with _eq" do
        expect(Article.view_count_eq(100).pluck(:view_count)).to eq([ 100 ])
      end

      it "filters by not equal with _not_eq" do
        expect(Article.view_count_not_eq(100).pluck(:view_count).sort).to eq([ 25, 50 ])
      end

      it "filters less than with _lt" do
        expect(Article.view_count_lt(75).pluck(:view_count).sort).to eq([ 25, 50 ])
      end

      it "filters less than or equal with _lteq" do
        expect(Article.view_count_lteq(50).pluck(:view_count).sort).to eq([ 25, 50 ])
      end

      it "filters greater than with _gt" do
        expect(Article.view_count_gt(40).pluck(:view_count).sort).to eq([ 50, 100 ])
      end

      it "filters greater than or equal with _gteq" do
        expect(Article.view_count_gteq(50).pluck(:view_count).sort).to eq([ 50, 100 ])
      end

      it "filters by array with _in" do
        expect(Article.view_count_in([ 50, 100 ]).pluck(:view_count).sort).to eq([ 50, 100 ])
      end

      it "filters by not in array with _not_in" do
        expect(Article.view_count_not_in([ 50, 100 ]).pluck(:view_count)).to eq([ 25 ])
      end

      it "filters within range with _between" do
        expect(Article.view_count_between(30, 75).pluck(:view_count)).to eq([ 50 ])
      end

      it "filters outside range with _not_between" do
        expect(Article.view_count_not_between(30, 75).pluck(:view_count).sort).to eq([ 25, 100 ])
      end
    end
  end

  describe "boolean predicates" do
    let(:test_class) do
      create_predicable_class("BooleanPredicateTest") do
        predicates :featured
      end
    end

    it "generates boolean scopes" do
      expect(test_class).to respond_to(:featured_eq)
      expect(test_class).to respond_to(:featured_not_eq)
      expect(test_class).to respond_to(:featured_present)
    end

    describe "boolean scope functionality" do
      before do
        Article.create!(title: "A", content: "Test", status: "draft", featured: true)
        Article.create!(title: "B", content: "Test", status: "draft", featured: false)
      end

      it "filters by boolean value with _eq" do
        expect(Article.featured_eq(true).pluck(:featured)).to eq([ true ])
      end

      it "filters by not equal boolean with _not_eq" do
        expect(Article.featured_not_eq(true).pluck(:featured)).to eq([ false ])
      end
    end
  end

  describe "date predicates" do
    let(:test_class) do
      create_predicable_class("DatePredicateTest") do
        predicates :published_at
      end
    end

    it "generates all date scopes" do
      expect(test_class).to respond_to(:published_at_eq)
      expect(test_class).to respond_to(:published_at_not_eq)
      expect(test_class).to respond_to(:published_at_lt)
      expect(test_class).to respond_to(:published_at_lteq)
      expect(test_class).to respond_to(:published_at_gt)
      expect(test_class).to respond_to(:published_at_gteq)
      expect(test_class).to respond_to(:published_at_in)
      expect(test_class).to respond_to(:published_at_not_in)
      expect(test_class).to respond_to(:published_at_present)
      expect(test_class).to respond_to(:published_at_blank)
      expect(test_class).to respond_to(:published_at_null)
      expect(test_class).to respond_to(:published_at_between)
      expect(test_class).to respond_to(:published_at_within)
    end

    describe "date scope functionality" do
      before do
        Article.create!(title: "Old", content: "Test", status: "draft", published_at: 10.days.ago)
        Article.create!(title: "Mid", content: "Test", status: "draft", published_at: 5.days.ago)
        Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)
      end

      it "filters within date range with _between" do
        expect(Article.published_at_between(7.days.ago, 3.days.ago).count).to eq(1)
      end

      it "filters outside date range with _not_between" do
        expect(Article.published_at_not_between(7.days.ago, 3.days.ago).count).to eq(2)
      end

      it "filters within days with _within (numeric)" do
        expect(Article.published_at_within(7).pluck(:title).sort).to eq([ "Mid", "Recent" ])
      end

      it "filters within duration with _within (Duration)" do
        expect(Article.published_at_within(7.days).pluck(:title).sort).to eq([ "Mid", "Recent" ])
      end
    end
  end

  describe "complex predicates" do
    it "creates custom scope with register_complex_predicate" do
      test_class = create_predicable_class("ComplexPredicateTest") do
        predicates :view_count, :published_at

        register_complex_predicate :recent_popular do |days = 7, min_views = 100|
          where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
        end
      end

      expect(test_class).to respond_to(:recent_popular)
      expect(test_class.complex_predicate?(:recent_popular)).to be true
    end

    it "requires a block" do
      expect do
        create_predicable_class("ComplexPredicateNoBlockTest") do
          register_complex_predicate :invalid
        end
      end.to raise_error(BetterModel::Errors::Predicable::ConfigurationError, /Block required/)
    end

    it "works with parameters" do
      test_class = create_predicable_class("ComplexPredicateParamsTest") do
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
      expect(results).to eq([ "Recent Popular" ])
    end

    it "returns ActiveRecord::Relation" do
      test_class = create_predicable_class("ComplexRelationTest") do
        predicates :view_count

        register_complex_predicate :popular do
          where("view_count >= ?", 100)
        end
      end

      expect(test_class.popular).to be_a(ActiveRecord::Relation)
    end

    it "is chainable with standard predicates" do
      test_class = create_predicable_class("ComplexChainTest") do
        predicates :status, :title, :view_count

        register_complex_predicate :popular do
          where("view_count >= ?", 1000)
        end
      end

      chain = test_class.popular.status_eq("published").title_cont("Ruby")
      expect(chain).to be_a(ActiveRecord::Relation)
    end
  end

  describe "thread safety" do
    let(:test_class) do
      create_predicable_class("ThreadSafetyTest") do
        predicates :title

        register_complex_predicate :test do
          where(id: 1)
        end
      end
    end

    it "freezes predicable_fields" do
      expect(test_class.predicable_fields).to be_frozen
    end

    it "freezes predicable_scopes" do
      expect(test_class.predicable_scopes).to be_frozen
    end

    it "freezes complex_predicates_registry" do
      expect(test_class.complex_predicates_registry).to be_frozen
    end
  end

  describe "scope chaining" do
    before do
      Article.create!(title: "Ruby on Rails", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Python Guide", content: "Test", status: "draft", view_count: 150)
      Article.create!(title: "Ruby Gems", content: "Test", status: "draft", view_count: 50)
    end

    it "can chain multiple predicate scopes" do
      results = Article.title_cont("Ruby").view_count_gt(75).pluck(:title)
      expect(results).to eq([ "Ruby on Rails" ])
    end

    it "can chain with sorting scopes" do
      results = Article.title_cont("Ruby").sort_view_count_desc.pluck(:title)
      expect(results).to eq([ "Ruby on Rails", "Ruby Gems" ])
    end
  end

  describe "inheritance" do
    let(:parent_class) do
      create_predicable_class("PredicableParent") do
        predicates :title
      end
    end

    it "subclasses inherit predicable fields" do
      subclass = Class.new(parent_class)
      expect(subclass.predicable_field?(:title)).to be true
      expect(subclass).to respond_to(:title_eq)
    end

    it "subclasses can define additional predicable fields" do
      subclass = Class.new(parent_class) do
        self.table_name = "articles"
        predicates :view_count
      end

      expect(subclass.predicable_field?(:title)).to be true
      expect(subclass.predicable_field?(:view_count)).to be true
      expect(parent_class.predicable_field?(:view_count)).to be false
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Predicable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Predicable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Predicable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Predicable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end

  describe "coverage tests" do
    it "generates base predicates for all predicable fields" do
      Article.predicable_fields.each do |field|
        expect(Article).to respond_to(:"#{field}_eq")
        expect(Article).to respond_to(:"#{field}_not_eq")
        expect(Article).to respond_to(:"#{field}_present")
        expect(Article.predicable_scopes).to include(:"#{field}_eq")
      end
    end

    it "executes base predicates without errors" do
      Article.predicable_fields.each do |field|
        expect(Article.send(:"#{field}_eq", "test_value")).to be_a(ActiveRecord::Relation)
        expect(Article.send(:"#{field}_not_eq", "test_value")).to be_a(ActiveRecord::Relation)
        expect(Article.send(:"#{field}_present", true)).to be_a(ActiveRecord::Relation)
      end
    end

    it "handles nil values correctly" do
      article = Article.create!(title: nil, status: "draft")

      expect(Article.title_present(true)).not_to include(article)
      expect(Article.title_blank(true)).to include(article)
    end
  end
end
