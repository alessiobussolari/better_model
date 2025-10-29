# frozen_string_literal: true

require "test_helper"

module BetterModel
  class SortableTest < ActiveSupport::TestCase
    # Test che Article include Sortable tramite BetterModel
    test "Article should have sortable functionality" do
      assert Article.respond_to?(:sort)
      assert Article.respond_to?(:sortable_fields)
      assert Article.respond_to?(:sortable_scopes)
    end

    # Test validazione ActiveRecord
    test "should only be includable in ActiveRecord models" do
      assert_raises(ArgumentError, /can only be included in ActiveRecord models/) do
        Class.new do
          include BetterModel::Sortable
        end
      end
    end

    # Test registry initialization
    test "sortable_fields should be initialized as Set" do
      assert_instance_of Set, Article.sortable_fields
    end

    test "sortable_scopes should be initialized as Set" do
      assert_instance_of Set, Article.sortable_scopes
    end

    # Test DSL sort method
    test "sort should validate field existence" do
      assert_raises(ArgumentError, /Invalid field name/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Sortable

          sort :nonexistent_field
        end
      end
    end

    test "sort should register fields in sortable_fields" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :title, :view_count
      end

      assert test_class.sortable_field?(:title)
      assert test_class.sortable_field?(:view_count)
      refute test_class.sortable_field?(:nonexistent)
    end

    # Test String sorting scopes
    test "sort generates string scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :title
      end

      assert test_class.respond_to?(:sort_title_asc)
      assert test_class.respond_to?(:sort_title_desc)
      assert test_class.respond_to?(:sort_title_asc_i)
      assert test_class.respond_to?(:sort_title_desc_i)
    end

    test "sort_title_asc orders by title ascending" do
      article1 = Article.create!(title: "Zebra", content: "Test", status: "draft")
      article2 = Article.create!(title: "Apple", content: "Test", status: "draft")
      article3 = Article.create!(title: "Mango", content: "Test", status: "draft")

      results = Article.sort_title_asc.pluck(:title)
      assert_equal ["Apple", "Mango", "Zebra"], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    test "sort_title_desc orders by title descending" do
      article1 = Article.create!(title: "Zebra", content: "Test", status: "draft")
      article2 = Article.create!(title: "Apple", content: "Test", status: "draft")
      article3 = Article.create!(title: "Mango", content: "Test", status: "draft")

      results = Article.sort_title_desc.pluck(:title)
      assert_equal ["Zebra", "Mango", "Apple"], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    test "sort_title_asc_i orders case-insensitive ascending" do
      article1 = Article.create!(title: "zebra", content: "Test", status: "draft")
      article2 = Article.create!(title: "Apple", content: "Test", status: "draft")
      article3 = Article.create!(title: "MANGO", content: "Test", status: "draft")

      results = Article.sort_title_asc_i.pluck(:title)
      assert_equal ["Apple", "MANGO", "zebra"], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    test "sort_title_desc_i orders case-insensitive descending" do
      article1 = Article.create!(title: "zebra", content: "Test", status: "draft")
      article2 = Article.create!(title: "Apple", content: "Test", status: "draft")
      article3 = Article.create!(title: "MANGO", content: "Test", status: "draft")

      results = Article.sort_title_desc_i.pluck(:title)
      assert_equal ["zebra", "MANGO", "Apple"], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    # Test Numeric sorting scopes
    test "sort generates numeric scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :view_count
      end

      assert test_class.respond_to?(:sort_view_count_asc)
      assert test_class.respond_to?(:sort_view_count_desc)
      assert test_class.respond_to?(:sort_view_count_asc_nulls_last)
      assert test_class.respond_to?(:sort_view_count_desc_nulls_last)
      assert test_class.respond_to?(:sort_view_count_asc_nulls_first)
      assert test_class.respond_to?(:sort_view_count_desc_nulls_first)
    end

    test "sort_view_count_asc orders by view_count ascending" do
      article1 = Article.create!(title: "High", content: "Test", status: "draft", view_count: 100)
      article2 = Article.create!(title: "Low", content: "Test", status: "draft", view_count: 10)
      article3 = Article.create!(title: "Medium", content: "Test", status: "draft", view_count: 50)

      results = Article.sort_view_count_asc.pluck(:view_count)
      assert_equal [10, 50, 100], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    test "sort_view_count_desc orders by view_count descending" do
      article1 = Article.create!(title: "High", content: "Test", status: "draft", view_count: 100)
      article2 = Article.create!(title: "Low", content: "Test", status: "draft", view_count: 10)
      article3 = Article.create!(title: "Medium", content: "Test", status: "draft", view_count: 50)

      results = Article.sort_view_count_desc.pluck(:view_count)
      assert_equal [100, 50, 10], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    test "sort_view_count_desc_nulls_last puts NULL values at end" do
      article1 = Article.create!(title: "With views", content: "Test", status: "draft", view_count: 50)
      article2 = Article.create!(title: "No views", content: "Test", status: "draft", view_count: nil)
      article3 = Article.create!(title: "More views", content: "Test", status: "draft", view_count: 100)

      results = Article.sort_view_count_desc_nulls_last.pluck(:view_count)
      assert_equal [100, 50, nil], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    test "sort_view_count_asc_nulls_first puts NULL values at start" do
      article1 = Article.create!(title: "With views", content: "Test", status: "draft", view_count: 50)
      article2 = Article.create!(title: "No views", content: "Test", status: "draft", view_count: nil)
      article3 = Article.create!(title: "Fewer views", content: "Test", status: "draft", view_count: 10)

      results = Article.sort_view_count_asc_nulls_first.pluck(:view_count)
      assert_equal [nil, 10, 50], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    # Test Date sorting scopes
    test "sort generates date scopes" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :published_at
      end

      assert test_class.respond_to?(:sort_published_at_asc)
      assert test_class.respond_to?(:sort_published_at_desc)
      assert test_class.respond_to?(:sort_published_at_newest)
      assert test_class.respond_to?(:sort_published_at_oldest)
    end

    test "sort_published_at_newest orders dates descending (most recent first)" do
      article1 = Article.create!(title: "Old", content: "Test", status: "draft", published_at: 3.days.ago)
      article2 = Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)
      article3 = Article.create!(title: "Middle", content: "Test", status: "draft", published_at: 2.days.ago)

      results = Article.sort_published_at_newest.pluck(:title)
      assert_equal ["Recent", "Middle", "Old"], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    test "sort_published_at_oldest orders dates ascending (oldest first)" do
      article1 = Article.create!(title: "Old", content: "Test", status: "draft", published_at: 3.days.ago)
      article2 = Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)
      article3 = Article.create!(title: "Middle", content: "Test", status: "draft", published_at: 2.days.ago)

      results = Article.sort_published_at_oldest.pluck(:title)
      assert_equal ["Old", "Middle", "Recent"], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    # Test registry tracking
    test "sortable_scopes tracks all generated scopes for strings" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :title
      end

      assert test_class.sortable_scope?(:sort_title_asc)
      assert test_class.sortable_scope?(:sort_title_desc)
      assert test_class.sortable_scope?(:sort_title_asc_i)
      assert test_class.sortable_scope?(:sort_title_desc_i)
    end

    test "sortable_scopes tracks all generated scopes for numerics" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :view_count
      end

      assert test_class.sortable_scope?(:sort_view_count_asc)
      assert test_class.sortable_scope?(:sort_view_count_desc)
      assert test_class.sortable_scope?(:sort_view_count_asc_nulls_last)
      assert test_class.sortable_scope?(:sort_view_count_desc_nulls_last)
      assert test_class.sortable_scope?(:sort_view_count_asc_nulls_first)
      assert test_class.sortable_scope?(:sort_view_count_desc_nulls_first)
    end

    test "sortable_scopes tracks all generated scopes for dates" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :published_at
      end

      assert test_class.sortable_scope?(:sort_published_at_asc)
      assert test_class.sortable_scope?(:sort_published_at_desc)
      assert test_class.sortable_scope?(:sort_published_at_newest)
      assert test_class.sortable_scope?(:sort_published_at_oldest)
    end

    # Test thread-safety
    test "sortable_fields should be frozen" do
      assert Article.sortable_fields.frozen?
    end

    test "sortable_scopes should be frozen" do
      assert Article.sortable_scopes.frozen?
    end

    # Test chaining
    test "can chain multiple sort scopes" do
      article1 = Article.create!(title: "A", content: "Test", status: "draft", view_count: 100, published_at: 1.day.ago)
      article2 = Article.create!(title: "B", content: "Test", status: "draft", view_count: 100, published_at: 2.days.ago)
      article3 = Article.create!(title: "C", content: "Test", status: "draft", view_count: 50, published_at: 3.days.ago)

      # Order by view_count desc, then by published_at newest
      results = Article.sort_view_count_desc.sort_published_at_newest.pluck(:title)
      assert_equal ["A", "B", "C"], results

      article1.destroy
      article2.destroy
      article3.destroy
    end

    # Test instance methods
    test "sortable_attributes returns column names" do
      article = Article.new
      attributes = article.sortable_attributes

      assert_includes attributes, "title"
      assert_includes attributes, "content"
      assert_includes attributes, "view_count"
    end

    test "sortable_attributes excludes sensitive fields" do
      # Creiamo un modello test con campi sensibili
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        # Simuliamo la presenza di campi sensibili aggiungendoli manualmente
        def self.column_names
          super + ["password_digest", "encrypted_email"]
        end
      end

      instance = test_class.new
      attributes = instance.sortable_attributes

      refute_includes attributes, "password_digest"
      refute_includes attributes, "encrypted_email"
    end

    # Test multiple fields
    test "sort can define multiple fields at once" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :title, :view_count, :published_at
      end

      assert test_class.sortable_field?(:title)
      assert test_class.sortable_field?(:view_count)
      assert test_class.sortable_field?(:published_at)
    end

    # Test inheritance
    test "subclasses inherit sortable fields" do
      parent_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :title
      end

      subclass = Class.new(parent_class)

      assert subclass.sortable_field?(:title)
      assert subclass.respond_to?(:sort_title_asc)
    end

    test "subclasses can define additional sortable fields" do
      parent_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :title
      end

      subclass = Class.new(parent_class) do
        self.table_name = "articles"
        sort :view_count
      end

      assert subclass.sortable_field?(:title)
      assert subclass.sortable_field?(:view_count)
      refute parent_class.sortable_field?(:view_count)
    end

    # Test con Article reale
    test "Article has sort methods defined" do
      assert Article.respond_to?(:sort_title_asc)
      assert Article.respond_to?(:sort_view_count_desc)
      assert Article.respond_to?(:sort_published_at_newest)
    end

    test "Article sorts correctly with real data" do
      a1 = Article.create!(title: "Zebra", content: "Test", status: "draft", view_count: 100)
      a2 = Article.create!(title: "Apple", content: "Test", status: "draft", view_count: 50)

      assert_equal ["Apple", "Zebra"], Article.sort_title_asc.pluck(:title)
      assert_equal [100, 50], Article.sort_view_count_desc.pluck(:view_count)

      a1.destroy
      a2.destroy
    end

    # Test validation errors for coverage
    test "sort raises error for invalid field name" do
      assert_raises(ArgumentError, /Invalid field name.*does not exist in the table/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Sortable

          sort :nonexistent_field
        end
      end
    end

    test "sort handles text column types with case insensitive sorting" do
      # This test ensures text columns get case-insensitive sorting options
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Sortable

        sort :content  # content is a text field
      end

      # Text columns should have case-insensitive scopes
      assert test_class.respond_to?(:sort_content_asc)
      assert test_class.respond_to?(:sort_content_desc)
      assert test_class.respond_to?(:sort_content_asc_i)
      assert test_class.respond_to?(:sort_content_desc_i)
    end
  end
end
