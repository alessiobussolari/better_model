# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Sortable do
  describe "module inclusion" do
    it "is defined" do
      expect(defined?(BetterModel::Sortable)).to be_truthy
    end

    it "can be included in a model" do
      test_class = create_sortable_class("SortableInclusionTest") do
        sort :title, :view_count
      end

      expect(test_class).to respond_to(:sortable_fields)
    end

    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Sortable
        end
      end.to raise_error(BetterModel::Errors::Sortable::ConfigurationError, /can only be included in ActiveRecord models/)
    end
  end

  describe "registry initialization" do
    let(:test_class) do
      create_sortable_class("SortableRegistryTest") do
        sort :title
      end
    end

    it "initializes sortable_fields as Set" do
      expect(test_class.sortable_fields).to be_a(Set)
    end

    it "initializes sortable_scopes as Set" do
      expect(test_class.sortable_scopes).to be_a(Set)
    end

    it "initializes complex_sorts_registry as Hash" do
      expect(test_class.complex_sorts_registry).to be_a(Hash)
    end
  end

  describe "sort DSL" do
    context "with valid fields" do
      let(:test_class) do
        create_sortable_class("SortDSLTest") do
          sort :title, :view_count, :published_at
        end
      end

      it "registers fields in sortable_fields" do
        expect(test_class.sortable_field?(:title)).to be true
        expect(test_class.sortable_field?(:view_count)).to be true
        expect(test_class.sortable_field?(:published_at)).to be true
      end

      it "returns false for non-existent fields" do
        expect(test_class.sortable_field?(:nonexistent)).to be false
      end
    end

    context "with invalid fields" do
      it "raises ConfigurationError for non-existent field" do
        expect do
          create_sortable_class("SortInvalidTest") do
            sort :nonexistent_field
          end
        end.to raise_error(BetterModel::Errors::Sortable::ConfigurationError, /Invalid field name/)
      end
    end
  end

  describe "string sorting scopes" do
    let(:test_class) do
      create_sortable_class("StringSortTest") do
        sort :title
      end
    end

    it "generates all string sort scopes" do
      expect(test_class).to respond_to(:sort_title_asc)
      expect(test_class).to respond_to(:sort_title_desc)
      expect(test_class).to respond_to(:sort_title_asc_i)
      expect(test_class).to respond_to(:sort_title_desc_i)
    end

    describe "string sort functionality" do
      before do
        Article.create!(title: "Zebra", content: "Test", status: "draft")
        Article.create!(title: "Apple", content: "Test", status: "draft")
        Article.create!(title: "Mango", content: "Test", status: "draft")
      end

      it "orders by title ascending" do
        expect(Article.sort_title_asc.pluck(:title)).to eq([ "Apple", "Mango", "Zebra" ])
      end

      it "orders by title descending" do
        expect(Article.sort_title_desc.pluck(:title)).to eq([ "Zebra", "Mango", "Apple" ])
      end

      it "orders case-insensitive ascending" do
        Article.delete_all
        Article.create!(title: "zebra", content: "Test", status: "draft")
        Article.create!(title: "Apple", content: "Test", status: "draft")
        Article.create!(title: "MANGO", content: "Test", status: "draft")

        expect(Article.sort_title_asc_i.pluck(:title)).to eq([ "Apple", "MANGO", "zebra" ])
      end

      it "orders case-insensitive descending" do
        Article.delete_all
        Article.create!(title: "zebra", content: "Test", status: "draft")
        Article.create!(title: "Apple", content: "Test", status: "draft")
        Article.create!(title: "MANGO", content: "Test", status: "draft")

        expect(Article.sort_title_desc_i.pluck(:title)).to eq([ "zebra", "MANGO", "Apple" ])
      end
    end
  end

  describe "numeric sorting scopes" do
    let(:test_class) do
      create_sortable_class("NumericSortTest") do
        sort :view_count
      end
    end

    it "generates all numeric sort scopes" do
      expect(test_class).to respond_to(:sort_view_count_asc)
      expect(test_class).to respond_to(:sort_view_count_desc)
      expect(test_class).to respond_to(:sort_view_count_asc_nulls_last)
      expect(test_class).to respond_to(:sort_view_count_desc_nulls_last)
      expect(test_class).to respond_to(:sort_view_count_asc_nulls_first)
      expect(test_class).to respond_to(:sort_view_count_desc_nulls_first)
    end

    describe "numeric sort functionality" do
      before do
        Article.create!(title: "High", content: "Test", status: "draft", view_count: 100)
        Article.create!(title: "Low", content: "Test", status: "draft", view_count: 10)
        Article.create!(title: "Medium", content: "Test", status: "draft", view_count: 50)
      end

      it "orders by view_count ascending" do
        expect(Article.sort_view_count_asc.pluck(:view_count)).to eq([ 10, 50, 100 ])
      end

      it "orders by view_count descending" do
        expect(Article.sort_view_count_desc.pluck(:view_count)).to eq([ 100, 50, 10 ])
      end
    end

    describe "null handling" do
      before do
        Article.create!(title: "With views", content: "Test", status: "draft", view_count: 50)
        Article.create!(title: "No views", content: "Test", status: "draft", view_count: nil)
        Article.create!(title: "More views", content: "Test", status: "draft", view_count: 100)
      end

      it "puts NULL values at end with nulls_last" do
        results = Article.sort_view_count_desc_nulls_last.pluck(:view_count)
        expect(results).to eq([ 100, 50, nil ])
      end

      it "puts NULL values at start with nulls_first" do
        results = Article.sort_view_count_asc_nulls_first.pluck(:view_count)
        expect(results).to eq([ nil, 50, 100 ])
      end
    end
  end

  describe "date sorting scopes" do
    let(:test_class) do
      create_sortable_class("DateSortTest") do
        sort :published_at
      end
    end

    it "generates all date sort scopes" do
      expect(test_class).to respond_to(:sort_published_at_asc)
      expect(test_class).to respond_to(:sort_published_at_desc)
      expect(test_class).to respond_to(:sort_published_at_newest)
      expect(test_class).to respond_to(:sort_published_at_oldest)
    end

    describe "date sort functionality" do
      before do
        Article.create!(title: "Old", content: "Test", status: "draft", published_at: 3.days.ago)
        Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)
        Article.create!(title: "Middle", content: "Test", status: "draft", published_at: 2.days.ago)
      end

      it "orders newest first" do
        expect(Article.sort_published_at_newest.pluck(:title)).to eq([ "Recent", "Middle", "Old" ])
      end

      it "orders oldest first" do
        expect(Article.sort_published_at_oldest.pluck(:title)).to eq([ "Old", "Middle", "Recent" ])
      end
    end
  end

  describe "complex sorts" do
    it "requires a block" do
      expect do
        create_sortable_class("ComplexSortNoBlockTest") do
          register_complex_sort :by_something
        end
      end.to raise_error(BetterModel::Errors::Sortable::ConfigurationError, /Block required/)
    end

    it "creates scope with sort_ prefix" do
      test_class = create_sortable_class("ComplexSortTest") do
        register_complex_sort :by_popularity do
          order(view_count: :desc, published_at: :desc)
        end
      end

      expect(test_class).to respond_to(:sort_by_popularity)
      expect(test_class.complex_sort?(:by_popularity)).to be true
    end

    it "registers in complex_sorts_registry" do
      test_class = create_sortable_class("ComplexSortRegistryTest") do
        register_complex_sort :by_popularity do
          order(view_count: :desc)
        end
      end

      expect(test_class.complex_sorts_registry).to have_key(:by_popularity)
    end

    it "works with multi-field ordering" do
      test_class = create_sortable_class("ComplexSortMultiTest") do
        register_complex_sort :by_popularity do
          order(view_count: :desc, published_at: :desc)
        end
      end

      test_class.create!(title: "A", view_count: 100, published_at: 3.days.ago)
      test_class.create!(title: "B", view_count: 100, published_at: 1.day.ago)
      test_class.create!(title: "C", view_count: 50, published_at: 2.days.ago)

      results = test_class.sort_by_popularity.pluck(:title)
      expect(results[0]).to eq("B")
      expect(results[1]).to eq("A")
      expect(results[2]).to eq("C")
    end

    it "can be chained with other scopes" do
      test_class = create_sortable_class("ComplexSortChainTest") do
        register_complex_sort :by_views do
          order(view_count: :desc)
        end

        scope :published, -> { where(status: "published") }
      end

      test_class.create!(title: "A", status: "published", view_count: 100)
      test_class.create!(title: "B", status: "draft", view_count: 200)
      test_class.create!(title: "C", status: "published", view_count: 50)

      results = test_class.published.sort_by_views.pluck(:title)
      expect(results).to eq([ "A", "C" ])
    end
  end

  describe "thread safety" do
    let(:test_class) do
      create_sortable_class("ThreadSafetyTest") do
        sort :title

        register_complex_sort :by_popularity do
          order(view_count: :desc)
        end
      end
    end

    it "freezes sortable_fields" do
      expect(test_class.sortable_fields).to be_frozen
    end

    it "freezes sortable_scopes" do
      expect(test_class.sortable_scopes).to be_frozen
    end

    it "freezes complex_sorts_registry" do
      expect(test_class.complex_sorts_registry).to be_frozen
    end
  end

  describe "scope chaining" do
    before do
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100, published_at: 1.day.ago)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 100, published_at: 2.days.ago)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 50, published_at: 3.days.ago)
    end

    it "can chain multiple sort scopes" do
      results = Article.sort_view_count_desc.sort_published_at_newest.pluck(:title)
      expect(results).to eq([ "A", "B", "C" ])
    end

    it "can chain with predicate scopes" do
      results = Article.status_eq("draft").sort_title_asc
      expect(results).to be_a(ActiveRecord::Relation)
    end
  end

  describe "inheritance" do
    let(:parent_class) do
      create_sortable_class("SortableParent") do
        sort :title
      end
    end

    it "subclasses inherit sortable fields" do
      subclass = Class.new(parent_class)
      expect(subclass.sortable_field?(:title)).to be true
      expect(subclass).to respond_to(:sort_title_asc)
    end

    it "subclasses can define additional sortable fields" do
      subclass = Class.new(parent_class) do
        self.table_name = "articles"
        sort :view_count
      end

      expect(subclass.sortable_field?(:title)).to be true
      expect(subclass.sortable_field?(:view_count)).to be true
      expect(parent_class.sortable_field?(:view_count)).to be false
    end
  end

  describe "instance methods" do
    it "returns column names with sortable_attributes" do
      article = Article.new
      attributes = article.sortable_attributes

      expect(attributes).to include("title")
      expect(attributes).to include("content")
      expect(attributes).to include("view_count")
    end

    it "excludes sensitive fields from sortable_attributes" do
      test_class = create_sortable_class("SensitiveFieldsTest") do
        def self.column_names
          super + [ "password_digest", "encrypted_email" ]
        end
      end

      instance = test_class.new
      attributes = instance.sortable_attributes

      expect(attributes).not_to include("password_digest")
      expect(attributes).not_to include("encrypted_email")
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Sortable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Sortable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Sortable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Sortable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end

  describe "coverage tests" do
    it "generates sort scopes for all sortable fields" do
      Article.sortable_fields.each do |field|
        expect(Article).to respond_to(:"sort_#{field}_asc")
        expect(Article).to respond_to(:"sort_#{field}_desc")
        expect(Article.sortable_scopes).to include(:"sort_#{field}_asc")
        expect(Article.sortable_scopes).to include(:"sort_#{field}_desc")
      end
    end

    it "executes sort scopes without errors" do
      Article.sortable_fields.each do |field|
        expect(Article.send(:"sort_#{field}_asc")).to be_a(ActiveRecord::Relation)
        expect(Article.send(:"sort_#{field}_desc")).to be_a(ActiveRecord::Relation)
      end
    end

    it "generates case-insensitive scopes for string/text fields" do
      string_fields = Article.sortable_fields.select do |field|
        [ :string, :text ].include?(Article.columns_hash[field.to_s]&.type)
      end

      string_fields.each do |field|
        expect(Article).to respond_to(:"sort_#{field}_asc_i")
        expect(Article).to respond_to(:"sort_#{field}_desc_i")
      end
    end
  end
end
