# frozen_string_literal: true

require "test_helper"

module BetterModel
  module Integration
    class MultiModuleTest < ActiveSupport::TestCase
      def setup
        @articles_table = "multi_module_articles"
        @versions_table = "multi_module_article_versions"
        @transitions_table = "multi_module_state_transitions"

        create_test_tables
      end

      def teardown
        drop_test_tables
      end

      # ========================================
      # Combined Module Tests
      # ========================================

      test "model can use Archivable and Traceable together" do
        model_class = create_model_class do
          traceable do
            track :title, :status
          end

          archivable
        end

        record = model_class.create!(title: "Test", status: "draft")

        # Use archivable
        record.archive!(reason: "Test archive")
        assert record.archived?
        assert_not_nil record.archived_at

        # Check traceable recorded the status change
        # (archived_at is not tracked by default, but status might be)
        assert record.respond_to?(:versions)
      end

      test "model can use Searchable with Predicable and Sortable" do
        model_class = create_model_class do
          predicates :title, :status
          sort :title, :created_at
        end

        model_class.create!(title: "Ruby Guide", status: "published")
        model_class.create!(title: "Rails Tutorial", status: "draft")
        model_class.create!(title: "Python Basics", status: "published")

        # Predicable scopes work
        assert_equal 2, model_class.status_eq("published").count
        assert_equal 1, model_class.title_cont("Ruby").count

        # Sortable works
        sorted = model_class.sort_title_asc
        assert_equal "Python Basics", sorted.first.title

        # Search combines them
        results = model_class.search({ status_eq: "published" }, orders: [ :sort_title_asc ])
        assert_equal 2, results.count
        assert_equal "Python Basics", results.first.title
      end

      test "model can use Stateable with Validatable" do
        model_class = create_stateable_model_class do
          register_complex_validation :title_present do
            errors.add(:title, "can't be blank") if title.blank?
          end

          validatable do
            check_complex :title_present
          end

          stateable do
            state :draft, initial: true
            state :published

            transition :publish, from: :draft, to: :published do
              validate { errors.add(:base, "Title required") if title.blank? }
            end
          end
        end

        record = model_class.create!(title: "Test Article")
        assert_equal "draft", record.state
        assert record.can_publish?

        record.publish!
        assert_equal "published", record.state
      end

      test "model can use Archivable with default scope and Searchable" do
        model_class = create_model_class do
          archivable do
            skip_archived_by_default true
          end

          predicates :title
          sort :title
        end

        active = model_class.create!(title: "Active Article")
        archived = model_class.create!(title: "Archived Article")
        archived.archive!

        # Default scope hides archived
        assert_equal 1, model_class.count
        assert_equal "Active Article", model_class.first.title

        # Can access archived with archived_only
        assert_equal 1, model_class.archived_only.count

        # Searchable respects default scope
        results = model_class.search({ title_cont: "Article" })
        assert_equal 1, results.count
      end

      test "model can use Traceable with Stateable for full audit trail" do
        model_class = create_stateable_model_class do
          traceable do
            track :title, :state
          end

          stateable do
            state :draft, initial: true
            state :review
            state :published

            transition :submit, from: :draft, to: :review
            transition :approve, from: :review, to: :published
          end
        end

        record = model_class.create!(title: "Audited Article")
        assert_equal 1, record.versions.count # Create version

        record.submit!
        assert_equal "review", record.state

        record.approve!
        assert_equal "published", record.state

        # Check versions recorded state changes (3 versions: create + 2 transitions)
        assert record.versions.count >= 3
        assert record.respond_to?(:audit_trail)
      end

      test "model can use Taggable with Searchable" do
        # Skip on SQLite - Taggable requires PostgreSQL array columns
        skip "Taggable requires PostgreSQL array columns" unless postgres?

        model_class = create_taggable_model_class do
          taggable do
            tag_field :tags
            normalize true
          end
        end

        record = model_class.create!(title: "Tagged Article", tags: [ "ruby", "rails" ])
        assert record.tagged_with?("ruby")

        # Taggable auto-registers predicates
        assert model_class.respond_to?(:tags_contains)
      end

      # ========================================
      # Error Handling Across Modules
      # ========================================

      test "modules raise appropriate errors when not enabled" do
        # Model without any modules enabled
        model_class = create_base_model_class

        record = model_class.create!(title: "Test")

        # Archivable not enabled
        error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
          record.archive!
        end
        assert_match(/not enabled/i, error.message)

        # Traceable not enabled
        error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
          record.changes_for(:title)
        end
        assert_match(/not enabled/i, error.message)

        # Validatable not enabled
        error = assert_raises(BetterModel::Errors::Validatable::NotEnabledError) do
          record.validate_group(:step1)
        end
        assert_match(/not enabled/i, error.message)
      end

      test "all modules preserve their configuration isolation" do
        # Create two different model classes
        model_class_a = create_model_class do
          predicates :title
        end

        model_class_b = Class.new(ActiveRecord::Base) do
          self.table_name = "multi_module_articles"

          def self.name
            "MultiModuleArticleB"
          end

          include BetterModel
          predicates :status
        end

        # Each has its own predicates
        assert model_class_a.respond_to?(:title_eq)
        refute model_class_a.respond_to?(:status_eq) # unless status is in predicates

        assert model_class_b.respond_to?(:status_eq)
      end

      # ========================================
      # Thread Safety Tests
      # ========================================

      test "modules are thread-safe when used concurrently" do
        model_class = create_model_class do
          predicates :title, :status
          sort :title
          archivable
        end

        records = 10.times.map do |i|
          model_class.create!(title: "Article #{i}", status: "draft")
        end

        threads = []
        errors = []

        # Multiple threads using different modules simultaneously
        10.times do |i|
          threads << Thread.new do
            begin
              record = records[i]
              record.archive! if i.even?

              model_class.title_cont("Article")
              model_class.sort_title_asc
            rescue => e
              errors << e
            end
          end
        end

        threads.each(&:join)

        assert_empty errors, "Errors during concurrent access: #{errors.map(&:message).join(', ')}"

        # Verify results
        archived_count = model_class.unscoped.where.not(archived_at: nil).count
        assert_equal 5, archived_count
      end

      # ========================================
      # JSON Serialization Tests
      # ========================================

      test "as_json combines options from multiple modules" do
        model_class = create_stateable_model_class do
          archivable

          stateable do
            state :draft, initial: true
            state :published
            transition :publish, from: :draft, to: :published
          end
        end

        record = model_class.create!(title: "JSON Test")
        record.publish!

        json = record.as_json(
          include_archive_info: true,
          include_transition_history: true
        )

        assert json.key?("archive_info")
        assert json.key?("transition_history")
        assert_equal false, json["archive_info"]["archived"]
        assert_equal 1, json["transition_history"].size
      end

      private

      def create_test_tables
        ActiveRecord::Base.connection.create_table(@articles_table, force: true) do |t|
          t.string :title
          t.string :status, default: "draft"
          t.string :state
          t.text :tags  # JSON serialized in SQLite
          t.datetime :archived_at
          t.integer :archived_by_id
          t.string :archive_reason
          t.integer :updated_by_id
          t.string :updated_reason
          t.timestamps
        end

        ActiveRecord::Base.connection.create_table(@versions_table, force: true) do |t|
          t.string :item_type
          t.integer :item_id
          t.string :event
          t.text :object_changes
          t.integer :updated_by_id
          t.string :updated_reason
          t.timestamps
        end

        ActiveRecord::Base.connection.create_table(@transitions_table, force: true) do |t|
          t.string :transitionable_type
          t.integer :transitionable_id
          t.string :event
          t.string :from_state
          t.string :to_state
          t.text :metadata
          t.timestamps
        end
      end

      def drop_test_tables
        ActiveRecord::Base.connection.drop_table(@articles_table, if_exists: true)
        ActiveRecord::Base.connection.drop_table(@versions_table, if_exists: true)
        ActiveRecord::Base.connection.drop_table(@transitions_table, if_exists: true)

        # Clean up dynamic constants
        %w[MultiModuleArticle MultiModuleArticleVersion MultiModuleStateTransition].each do |const|
          BetterModel.send(:remove_const, const) if BetterModel.const_defined?(const, false)
        end
      end

      def create_base_model_class
        Class.new(ActiveRecord::Base) do
          self.table_name = "multi_module_articles"

          def self.name
            "MultiModuleArticle"
          end

          include BetterModel
        end
      end

      def create_model_class(&block)
        klass = create_base_model_class
        klass.class_eval(&block) if block_given?
        klass
      end

      def create_stateable_model_class(&block)
        Class.new(ActiveRecord::Base) do
          self.table_name = "multi_module_articles"

          def self.name
            "MultiModuleArticle"
          end

          include BetterModel

          class_eval(&block) if block
        end
      end

      def create_taggable_model_class(&block)
        Class.new(ActiveRecord::Base) do
          self.table_name = "multi_module_articles"

          def self.name
            "MultiModuleArticle"
          end

          include BetterModel

          class_eval(&block) if block
        end
      end

      def postgres?
        ActiveRecord::Base.connection.adapter_name.downcase == "postgresql"
      end
    end
  end
end
