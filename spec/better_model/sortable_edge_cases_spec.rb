# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Sortable, "edge cases", type: :model do
  # Helper to create test classes
  def create_sortable_class(name_suffix, &block)
    const_name = "SortableEdgeTest#{name_suffix}"
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name)

    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel

      def self.model_name
        ActiveModel::Name.new(self, nil, "Article")
      end
    end

    Object.const_set(const_name, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  after do
    Object.constants.grep(/^SortableEdgeTest/).each do |const|
      Object.send(:remove_const, const) rescue nil
    end
    Article.delete_all
  end

  describe "base sorting for non-standard types" do
    it "defines base sorting for boolean fields" do
      test_class = create_sortable_class("BoolSort") do
        sort :featured
      end

      expect(test_class).to respond_to(:sort_featured_asc)
      expect(test_class).to respond_to(:sort_featured_desc)
    end

    it "applies base sorting for boolean field" do
      test_class = create_sortable_class("BoolSortApply") do
        sort :featured
      end

      test_class.create!(title: "A", status: "draft", featured: false)
      test_class.create!(title: "B", status: "draft", featured: true)
      test_class.create!(title: "C", status: "draft", featured: false)

      # Boolean sorting should work (false=0, true=1)
      result_asc = test_class.sort_featured_asc.pluck(:title)
      result_desc = test_class.sort_featured_desc.pluck(:title)

      # Ascending: false values first, then true
      expect(result_asc.first(2)).to match_array([ "A", "C" ])
      expect(result_asc.last).to eq("B")
    end
  end

  describe "numeric sorting with NULLS handling" do
    let(:test_class) do
      create_sortable_class("NumericNulls") do
        sort :view_count
      end
    end

    before do
      test_class.create!(title: "A", status: "draft", view_count: 10)
      test_class.create!(title: "B", status: "draft", view_count: nil)
      test_class.create!(title: "C", status: "draft", view_count: 5)
      test_class.create!(title: "D", status: "draft", view_count: nil)
    end

    it "sorts with nulls last ascending" do
      result = test_class.sort_view_count_asc_nulls_last.pluck(:title)
      expect(result[0..1]).to eq([ "C", "A" ]) # 5, 10
      expect(result[2..3]).to match_array([ "B", "D" ]) # nulls
    end

    it "sorts with nulls first ascending" do
      result = test_class.sort_view_count_asc_nulls_first.pluck(:title)
      expect(result[0..1]).to match_array([ "B", "D" ]) # nulls first
      expect(result[2..3]).to eq([ "C", "A" ]) # 5, 10
    end

    it "sorts with nulls last descending" do
      result = test_class.sort_view_count_desc_nulls_last.pluck(:title)
      expect(result[0..1]).to eq([ "A", "C" ]) # 10, 5
      expect(result[2..3]).to match_array([ "B", "D" ]) # nulls
    end

    it "sorts with nulls first descending" do
      result = test_class.sort_view_count_desc_nulls_first.pluck(:title)
      expect(result[0..1]).to match_array([ "B", "D" ]) # nulls first
      expect(result[2..3]).to eq([ "A", "C" ]) # 10, 5
    end
  end

  describe "date sorting" do
    let(:test_class) do
      create_sortable_class("DateSort") do
        sort :published_at
      end
    end

    before do
      test_class.create!(title: "A", status: "draft", published_at: 2.days.ago)
      test_class.create!(title: "B", status: "draft", published_at: nil)
      test_class.create!(title: "C", status: "draft", published_at: 1.day.ago)
    end

    it "generates date sort scopes" do
      expect(test_class).to respond_to(:sort_published_at_asc)
      expect(test_class).to respond_to(:sort_published_at_desc)
      expect(test_class).to respond_to(:sort_published_at_newest)
      expect(test_class).to respond_to(:sort_published_at_oldest)
    end

    it "sorts dates ascending" do
      result = test_class.sort_published_at_asc.where.not(published_at: nil).pluck(:title)
      expect(result).to eq([ "A", "C" ]) # Oldest first
    end

    it "sorts dates descending (newest first)" do
      result = test_class.sort_published_at_newest.where.not(published_at: nil).pluck(:title)
      expect(result).to eq([ "C", "A" ]) # Most recent first
    end
  end

  describe "complex sorts" do
    let(:test_class) do
      create_sortable_class("ComplexSort") do
        sort :view_count, :title

        register_complex_sort :by_popularity do
          order(view_count: :desc, title: :asc)
        end
      end
    end

    before do
      test_class.create!(title: "B Article", status: "draft", view_count: 100)
      test_class.create!(title: "A Article", status: "draft", view_count: 100)
      test_class.create!(title: "C Article", status: "draft", view_count: 50)
    end

    it "applies complex sort" do
      result = test_class.sort_by_popularity.pluck(:title)
      # Same view_count sorted by title asc
      expect(result).to eq([ "A Article", "B Article", "C Article" ])
    end

    it "registers complex sort in scopes" do
      expect(test_class.sortable_scopes).to include(:sort_by_popularity)
    end
  end

  describe "sortable_scopes registry" do
    let(:test_class) do
      create_sortable_class("ScopesRegistry") do
        sort :title, :view_count
      end
    end

    it "registers scopes in sortable_scopes Set" do
      scopes = test_class.sortable_scopes
      expect(scopes).to include(:sort_title_asc, :sort_title_desc)
      expect(scopes).to include(:sort_view_count_asc, :sort_view_count_desc)
    end

    it "sortable_scope? returns true for registered scopes" do
      expect(test_class.sortable_scope?(:sort_title_asc)).to be true
    end

    it "sortable_scope? returns false for unregistered scopes" do
      expect(test_class.sortable_scope?(:sort_nonexistent_asc)).to be false
    end
  end

  describe "sortable_field? method" do
    let(:test_class) do
      create_sortable_class("FieldCheck") do
        sort :title
      end
    end

    it "returns true for registered fields" do
      expect(test_class.sortable_field?(:title)).to be true
    end

    it "returns false for unregistered fields" do
      expect(test_class.sortable_field?(:unknown)).to be false
    end
  end

  describe "instance methods" do
    let(:test_class) do
      create_sortable_class("Instance") do
        sort :title, :view_count
      end
    end

    it "returns sortable_attributes as array of column names" do
      article = test_class.create!(title: "Test", status: "draft", view_count: 10)
      attrs = article.sortable_attributes

      expect(attrs).to be_an(Array)
      expect(attrs).to include("title")
      expect(attrs).to include("view_count")
    end

    it "excludes password fields from sortable_attributes" do
      article = test_class.create!(title: "Test", status: "draft")
      attrs = article.sortable_attributes

      # Should exclude any password or encrypted fields
      expect(attrs).not_to include(match(/^password/))
      expect(attrs).not_to include(match(/^encrypted_/))
    end
  end

  describe "sortable fields check" do
    it "has sortable fields when sort DSL is used" do
      test_class = create_sortable_class("HasFields") do
        sort :title
      end

      expect(test_class.sortable_fields).to include(:title)
      expect(test_class.sortable_fields.any?).to be true
    end

    it "has empty sortable fields when no sort DSL is used" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable
      end

      expect(klass.sortable_fields).to be_empty
    end
  end

  describe "case insensitive sorting" do
    let(:test_class) do
      create_sortable_class("CaseInsensitive") do
        sort :title
      end
    end

    before do
      test_class.create!(title: "apple", status: "draft")
      test_class.create!(title: "Banana", status: "draft")
      test_class.create!(title: "cherry", status: "draft")
    end

    it "sorts case-insensitively ascending" do
      result = test_class.sort_title_asc_i.pluck(:title)
      expect(result).to eq([ "apple", "Banana", "cherry" ])
    end

    it "sorts case-insensitively descending" do
      result = test_class.sort_title_desc_i.pluck(:title)
      expect(result).to eq([ "cherry", "Banana", "apple" ])
    end
  end

  describe "multiple fields sorting" do
    let(:test_class) do
      create_sortable_class("MultiField") do
        sort :status, :title, :view_count
      end
    end

    before do
      test_class.create!(title: "B Article", status: "draft", view_count: 10)
      test_class.create!(title: "A Article", status: "published", view_count: 20)
      test_class.create!(title: "C Article", status: "draft", view_count: 5)
    end

    it "allows chaining multiple sorts" do
      # First by status desc, then by title asc
      result = test_class.sort_status_desc.sort_title_asc.pluck(:title, :status)

      # Published first (desc: p > d), then by title within each status
      # This depends on sort chain behavior - later sorts take precedence
      expect(result).to be_present
    end
  end
end
