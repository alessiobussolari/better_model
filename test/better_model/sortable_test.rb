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
      Article.create!(title: "Zebra", content: "Test", status: "draft")
      Article.create!(title: "Apple", content: "Test", status: "draft")
      Article.create!(title: "Mango", content: "Test", status: "draft")

      results = Article.sort_title_asc.pluck(:title)
      assert_equal [ "Apple", "Mango", "Zebra" ], results

    end

    test "sort_title_desc orders by title descending" do
      Article.create!(title: "Zebra", content: "Test", status: "draft")
      Article.create!(title: "Apple", content: "Test", status: "draft")
      Article.create!(title: "Mango", content: "Test", status: "draft")

      results = Article.sort_title_desc.pluck(:title)
      assert_equal [ "Zebra", "Mango", "Apple" ], results

    end

    test "sort_title_asc_i orders case-insensitive ascending" do
      Article.create!(title: "zebra", content: "Test", status: "draft")
      Article.create!(title: "Apple", content: "Test", status: "draft")
      Article.create!(title: "MANGO", content: "Test", status: "draft")

      results = Article.sort_title_asc_i.pluck(:title)
      assert_equal [ "Apple", "MANGO", "zebra" ], results

    end

    test "sort_title_desc_i orders case-insensitive descending" do
      Article.create!(title: "zebra", content: "Test", status: "draft")
      Article.create!(title: "Apple", content: "Test", status: "draft")
      Article.create!(title: "MANGO", content: "Test", status: "draft")

      results = Article.sort_title_desc_i.pluck(:title)
      assert_equal [ "zebra", "MANGO", "Apple" ], results

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
      Article.create!(title: "High", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Low", content: "Test", status: "draft", view_count: 10)
      Article.create!(title: "Medium", content: "Test", status: "draft", view_count: 50)

      results = Article.sort_view_count_asc.pluck(:view_count)
      assert_equal [ 10, 50, 100 ], results

    end

    test "sort_view_count_desc orders by view_count descending" do
      Article.create!(title: "High", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Low", content: "Test", status: "draft", view_count: 10)
      Article.create!(title: "Medium", content: "Test", status: "draft", view_count: 50)

      results = Article.sort_view_count_desc.pluck(:view_count)
      assert_equal [ 100, 50, 10 ], results

    end

    test "sort_view_count_desc_nulls_last puts NULL values at end" do
      Article.create!(title: "With views", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "No views", content: "Test", status: "draft", view_count: nil)
      Article.create!(title: "More views", content: "Test", status: "draft", view_count: 100)

      results = Article.sort_view_count_desc_nulls_last.pluck(:view_count)
      assert_equal [ 100, 50, nil ], results

    end

    test "sort_view_count_asc_nulls_first puts NULL values at start" do
      Article.create!(title: "With views", content: "Test", status: "draft", view_count: 50)
      Article.create!(title: "No views", content: "Test", status: "draft", view_count: nil)
      Article.create!(title: "Fewer views", content: "Test", status: "draft", view_count: 10)

      results = Article.sort_view_count_asc_nulls_first.pluck(:view_count)
      assert_equal [ nil, 10, 50 ], results

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
      Article.create!(title: "Old", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)
      Article.create!(title: "Middle", content: "Test", status: "draft", published_at: 2.days.ago)

      results = Article.sort_published_at_newest.pluck(:title)
      assert_equal [ "Recent", "Middle", "Old" ], results

    end

    test "sort_published_at_oldest orders dates ascending (oldest first)" do
      Article.create!(title: "Old", content: "Test", status: "draft", published_at: 3.days.ago)
      Article.create!(title: "Recent", content: "Test", status: "draft", published_at: 1.day.ago)
      Article.create!(title: "Middle", content: "Test", status: "draft", published_at: 2.days.ago)

      results = Article.sort_published_at_oldest.pluck(:title)
      assert_equal [ "Old", "Middle", "Recent" ], results

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
      Article.create!(title: "A", content: "Test", status: "draft", view_count: 100, published_at: 1.day.ago)
      Article.create!(title: "B", content: "Test", status: "draft", view_count: 100, published_at: 2.days.ago)
      Article.create!(title: "C", content: "Test", status: "draft", view_count: 50, published_at: 3.days.ago)

      # Order by view_count desc, then by published_at newest
      results = Article.sort_view_count_desc.sort_published_at_newest.pluck(:title)
      assert_equal [ "A", "B", "C" ], results

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
          super + [ "password_digest", "encrypted_email" ]
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
      Article.create!(title: "Zebra", content: "Test", status: "draft", view_count: 100)
      Article.create!(title: "Apple", content: "Test", status: "draft", view_count: 50)

      assert_equal [ "Apple", "Zebra" ], Article.sort_title_asc.pluck(:title)
      assert_equal [ 100, 50 ], Article.sort_view_count_desc.pluck(:view_count)

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

    # ========================================
    # COVERAGE TESTS - Opzione B: Riflessione
    # ========================================

    test "all sort scopes are generated and registered for each field" do
      Article.sortable_fields.each do |field|
        # Verifica esistenza scope _asc
        assert Article.respond_to?(:"sort_#{field}_asc"),
               "Expected Article to have sort_#{field}_asc scope"

        # Verifica esistenza scope _desc
        assert Article.respond_to?(:"sort_#{field}_desc"),
               "Expected Article to have sort_#{field}_desc scope"

        # Verifica registrazione negli scope
        assert_includes Article.sortable_scopes, :"sort_#{field}_asc",
                        "Expected sort_#{field}_asc to be registered in sortable_scopes"
        assert_includes Article.sortable_scopes, :"sort_#{field}_desc",
                        "Expected sort_#{field}_desc to be registered in sortable_scopes"
      end
    end

    test "case insensitive sort scopes are generated for string/text fields" do
      string_fields = Article.sortable_fields.select do |field|
        [ :string, :text ].include?(Article.columns_hash[field.to_s]&.type)
      end

      string_fields.each do |field|
        # Verifica esistenza scope case-insensitive
        assert Article.respond_to?(:"sort_#{field}_asc_i"),
               "Expected Article to have sort_#{field}_asc_i scope"
        assert Article.respond_to?(:"sort_#{field}_desc_i"),
               "Expected Article to have sort_#{field}_desc_i scope"

        # Verifica registrazione
        assert_includes Article.sortable_scopes, :"sort_#{field}_asc_i"
        assert_includes Article.sortable_scopes, :"sort_#{field}_desc_i"
      end
    end

    # ========================================
    # COVERAGE TESTS - Opzione C: Esecuzione
    # ========================================

    test "all sort scopes execute without errors" do
      Article.sortable_fields.each do |field|
        # Test _asc
        result = Article.send(:"sort_#{field}_asc")
        assert result.is_a?(ActiveRecord::Relation),
               "Expected sort_#{field}_asc to return ActiveRecord::Relation"

        # Test _desc
        result = Article.send(:"sort_#{field}_desc")
        assert result.is_a?(ActiveRecord::Relation),
               "Expected sort_#{field}_desc to return ActiveRecord::Relation"
      end
    end

    test "case insensitive sort scopes execute without errors" do
      string_fields = Article.sortable_fields.select do |field|
        [ :string, :text ].include?(Article.columns_hash[field.to_s]&.type)
      end

      string_fields.each do |field|
        # Test case-insensitive scopes
        assert_nothing_raised { Article.send(:"sort_#{field}_asc_i").to_a }
        assert_nothing_raised { Article.send(:"sort_#{field}_desc_i").to_a }
      end
    end

    test "sort scopes can be chained" do
      # Verifica che i sort scope siano chainabili
      result = Article.status_eq("published").sort_title_asc
      assert result.is_a?(ActiveRecord::Relation)

      # Test chain multipla
      result = Article.sort_created_at_desc.view_count_gt(50)
      assert result.is_a?(ActiveRecord::Relation)
    end

    test "sort scopes actually order results correctly" do
      # Crea alcuni articoli con diversi titoli
      Article.create!(title: "Alpha", status: "draft")
      Article.create!(title: "Zeta", status: "draft")
      Article.create!(title: "Beta", status: "draft")

      # Test ordinamento ascendente
      titles_asc = Article.sort_title_asc.pluck(:title)
      assert titles_asc.index("Alpha") < titles_asc.index("Beta")
      assert titles_asc.index("Beta") < titles_asc.index("Zeta")

      # Test ordinamento discendente
      titles_desc = Article.sort_title_desc.pluck(:title)
      assert titles_desc.index("Zeta") < titles_desc.index("Beta")
      assert titles_desc.index("Beta") < titles_desc.index("Alpha")
    end

    # ========================================
    # COVERAGE TESTS - NULL Handling
    # ========================================

    test "nulls_order_sql generates correct SQL for SQLite/PostgreSQL" do
      # Test the SQLite/PostgreSQL path (lines 195-196)
      field_name = :view_count

      # ASC NULLS LAST
      sql_asc_last = Article.send(:nulls_order_sql, field_name, "ASC", "LAST")
      if ActiveRecord::Base.connection.adapter_name.match?(/PostgreSQL|SQLite/)
        # Match with or without quotes (SQLite quotes, PostgreSQL may not)
        assert_match(/view_count.*ASC NULLS LAST/i, sql_asc_last)
      else
        assert_match(/CASE WHEN/, sql_asc_last)
      end

      # DESC NULLS FIRST
      sql_desc_first = Article.send(:nulls_order_sql, field_name, "DESC", "FIRST")
      if ActiveRecord::Base.connection.adapter_name.match?(/PostgreSQL|SQLite/)
        assert_match(/view_count.*DESC NULLS FIRST/i, sql_desc_first)
      else
        assert_match(/CASE WHEN/, sql_desc_first)
      end
    end

    test "sort_field_asc_nulls_last orders NULL values last" do
      # Create articles with mixed NULL and non-NULL values
      Article.create!(title: "Null Article", status: "draft", view_count: nil)
      Article.create!(title: "Article 50", status: "draft", view_count: 50)
      Article.create!(title: "Article 100", status: "draft", view_count: 100)
      Article.create!(title: "Null Article 2", status: "draft", view_count: nil)

      # Sort with nulls last
      results = Article.sort_view_count_asc_nulls_last.pluck(:id, :view_count)

      # Verify NULL values are at the end
      non_null_count = results.count { |id, count| count.present? }
      null_count = results.count { |id, count| count.nil? }

      assert_equal 2, non_null_count
      assert_equal 2, null_count

      # First two should have values, last two should be NULL
      assert_not_nil results[0][1], "First result should not be NULL"
      assert_not_nil results[1][1], "Second result should not be NULL"
      assert_nil results[2][1], "Third result should be NULL"
      assert_nil results[3][1], "Fourth result should be NULL"

      # Non-NULL values should be sorted ascending
      assert results[0][1] < results[1][1], "Non-NULL values should be sorted ascending"
    end

    test "sort_field_desc_nulls_last orders NULL values last in descending order" do
      Article.create!(title: "Null Article", status: "draft", view_count: nil)
      Article.create!(title: "Article 50", status: "draft", view_count: 50)
      Article.create!(title: "Article 100", status: "draft", view_count: 100)

      results = Article.sort_view_count_desc_nulls_last.pluck(:id, :view_count)

      # First two should have values (100, 50), last should be NULL
      assert_not_nil results[0][1]
      assert_not_nil results[1][1]
      assert_nil results[2][1]

      # Non-NULL values should be sorted descending
      assert results[0][1] > results[1][1], "Non-NULL values should be sorted descending"
    end

    test "sort_field_asc_nulls_first orders NULL values first" do
      Article.create!(title: "Article 50", status: "draft", view_count: 50)
      Article.create!(title: "Null Article", status: "draft", view_count: nil)
      Article.create!(title: "Article 100", status: "draft", view_count: 100)

      results = Article.sort_view_count_asc_nulls_first.pluck(:id, :view_count)

      # First should be NULL, next two should have values (50, 100)
      assert_nil results[0][1]
      assert_not_nil results[1][1]
      assert_not_nil results[2][1]

      # Non-NULL values should be sorted ascending
      assert results[1][1] < results[2][1], "Non-NULL values should be sorted ascending"
    end

    test "sort_field_desc_nulls_first orders NULL values first in descending order" do
      Article.create!(title: "Article 50", status: "draft", view_count: 50)
      Article.create!(title: "Article 100", status: "draft", view_count: 100)
      Article.create!(title: "Null Article", status: "draft", view_count: nil)

      results = Article.sort_view_count_desc_nulls_first.pluck(:id, :view_count)

      # First should be NULL, next two should have values (100, 50)
      assert_nil results[0][1]
      assert_not_nil results[1][1]
      assert_not_nil results[2][1]

      # Non-NULL values should be sorted descending
      assert results[1][1] > results[2][1], "Non-NULL values should be sorted descending"
    end
  end
end
