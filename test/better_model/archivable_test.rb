# frozen_string_literal: true

require "test_helper"

module BetterModel
  class ArchivableTest < ActiveSupport::TestCase
    setup do
      @article = Article.create!(title: "Test Article", status: "published")
    end

    teardown do
      # Reset Article class per evitare side effects tra test
      # Non possiamo "disabilitare" archivable, ma possiamo rimuovere gli scope dinamici
      if Article.respond_to?(:archived)
        Article.singleton_class.send(:remove_method, :archived) rescue nil
        Article.singleton_class.send(:remove_method, :not_archived) rescue nil
      end
    end

    # ========================================
    # FASE 2: Funzionalità Base (Opt-In)
    # ========================================

    test "should not enable archivable by default" do
      # Crea una nuova classe SENZA chiamare archivable
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        # NON chiamiamo archivable qui
      end

      # Archiviable non dovrebbe essere attivo automaticamente
      assert_equal false, test_class.archivable_enabled?
    end

    test "archived? should return false when archivable not enabled" do
      assert_equal false, @article.archived?
    end

    test "archivable DSL should enable archivable" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel  # Include tutto per avere predicable
        archivable
      end

      assert test_class.archivable_enabled?
    end

    test "archivable should raise error if archived_at column missing" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Archivable

        # Simula colonna mancante
        def self.column_names
          [ "id", "title", "status" ]  # senza archived_at
        end
      end

      error = assert_raises(ArgumentError) do
        test_class.class_eval { archivable }
      end

      assert_match(/Invalid configuration/, error.message)
    end

    # ========================================
    # FASE 3: Predicati e Scopes
    # ========================================

    test "archivable should auto-define predicates on archived_at" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable
      end

      assert test_class.respond_to?(:archived_at_present)
      assert test_class.respond_to?(:archived_at_null)
      assert test_class.predicable_field?(:archived_at)
    end

    test "archivable should auto-define sort on archived_at" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable
      end

      assert test_class.respond_to?(:sort_archived_at_asc)
      assert test_class.respond_to?(:sort_archived_at_desc)
      assert test_class.sortable_field?(:archived_at)
    end

    test "should define archived scope as alias" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable
      end

      assert test_class.respond_to?(:archived)
      # Verifica che usi predicato sotto
      assert_equal test_class.archived_at_present(true).to_sql, test_class.archived.to_sql
    end

    test "should define not_archived scope as alias" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable
      end

      assert test_class.respond_to?(:not_archived)
      assert_equal test_class.archived_at_null(true).to_sql, test_class.not_archived.to_sql
    end

    test "archived_only should bypass default scope" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable do
          skip_archived_by_default true
        end
      end

      assert test_class.respond_to?(:archived_only)
    end

    # ========================================
    # FASE 4: Metodi Istanza
    # ========================================

    test "archive! should set archived_at" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")

      article.archive!

      assert article.archived_at.present?
      assert article.archived?
    end

    test "archive! should raise error if already archived" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")
      article.archive!

      error = assert_raises(BetterModel::Errors::Archivable::AlreadyArchivedError) do
        article.archive!
      end

      assert_match(/already archived/, error.message)
    end

    test "archive! should track by and reason if columns exist" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")
      user_id = 42

      article.archive!(by: user_id, reason: "Obsolete")

      assert_equal user_id, article.archived_by_id
      assert_equal "Obsolete", article.archive_reason
    end

    test "restore! should clear archived_at" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")
      article.archive!

      article.restore!

      assert_nil article.archived_at
      assert_not article.archived?
    end

    test "restore! should raise error if not archived" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Archivable::NotArchivedError) do
        article.restore!
      end

      assert_match(/not archived/, error.message)
    end

    test "archived? should return correct state" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")

      assert_not article.archived?
      article.archive!
      assert article.archived?
    end

    test "active? should be opposite of archived?" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")

      assert article.active?
      article.archive!
      assert_not article.active?
    end

    # ========================================
    # FASE 5: Configurazione DSL
    # ========================================

    test "skip_archived_by_default should apply default scope" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable do
          skip_archived_by_default true
        end
      end

      # Crea record archiviato e non
      active = test_class.create!(title: "Active")
      archived = test_class.create!(title: "Archived")
      archived.update_column(:archived_at, Time.current)

      # all dovrebbe vedere solo active
      assert_includes test_class.all.pluck(:id), active.id
      assert_not_includes test_class.all.pluck(:id), archived.id
    end

    test "archivable without block should work with defaults" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable  # Senza blocco
      end

      assert test_class.archivable_enabled?
      # Default: NON nasconde archiviati
      assert_equal test_class.all.to_sql, test_class.unscoped.all.to_sql
    end

    # ========================================
    # FASE 6: Helper Methods
    # ========================================

    test "should provide convenience methods as aliases" do
      Article.class_eval { archivable }

      assert Article.respond_to?(:archived_today)
      assert Article.respond_to?(:archived_this_week)
      assert Article.respond_to?(:archived_recently)
    end

    test "archived_recently should use archived_at_within" do
      Article.class_eval { archivable }

      # Verifica che il metodo esista e restituisca una Relation
      assert Article.respond_to?(:archived_recently)
      assert_kind_of ActiveRecord::Relation, Article.archived_recently(7.days)

      # Verifica che contenga la stessa logica (stesso WHERE clause pattern)
      sql1 = Article.archived_at_within(7.days).to_sql
      sql2 = Article.archived_recently(7.days).to_sql

      # Entrambi dovrebbero avere ">=" nell'SQL
      assert_match(/>=/, sql1)
      assert_match(/>=/, sql2)
    end

    # ========================================
    # FASE 7: Integrazione
    # ========================================

    test "should work with searchable predicates" do
      Article.class_eval { archivable }

      article = Article.create!(title: "Test", status: "published")
      article.archive!

      # Cerca con predicato
      results = Article.search({ archived_at_null: true })
      assert_not_includes results.pluck(:id), article.id

      results = Article.search({ archived_at_present: true })
      assert_includes results.pluck(:id), article.id
    end

    test "as_json should include archive info when requested" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")
      article.archive!(by: 42, reason: "Test")

      json = article.as_json(include_archive_info: true)

      assert json.key?("archive_info")
      assert_equal true, json["archive_info"]["archived"]
      assert json["archive_info"]["archived_at"].present?
      assert_equal 42, json["archive_info"]["archived_by_id"]
      assert_equal "Test", json["archive_info"]["archive_reason"]
    end

    # ========================================
    # FASE 8: Error Handling e Edge Cases
    # ========================================

    test "should define custom error classes" do
      assert defined?(BetterModel::Errors::Archivable::AlreadyArchivedError)
      assert defined?(BetterModel::Errors::Archivable::NotArchivedError)
      assert defined?(BetterModel::Errors::Archivable::NotEnabledError)
    end

    test "should raise ArchivableNotEnabledError if archivable not configured" do
      # Crea una classe SENZA archivable configurato
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        # NON chiamiamo archivable qui
      end

      article = test_class.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
        article.archive!
      end

      assert_match(/Module is not enabled/, error.message)
    end

    test "archivable_config should be frozen" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable do
          skip_archived_by_default true
        end
      end

      assert test_class.archivable_config.frozen?
    end

    test "subclasses should inherit archivable config" do
      parent = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        archivable do
          skip_archived_by_default true
        end
      end

      child = Class.new(parent)

      assert child.archivable_enabled?
      assert_equal parent.archivable_config, child.archivable_config
    end

    # ========================================
    # ERROR HANDLING TESTS - User Tracking
    # ========================================

    test "archive! should handle user object with id method" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")

      # Simulate user object with .id method
      user = Struct.new(:id).new(42)

      article.archive!(by: user)

      assert_equal 42, article.archived_by_id
    end

    test "archive! should handle direct integer ID" do
      Article.class_eval { archivable }
      article = Article.create!(title: "Test")

      # Direct ID (not object)
      article.archive!(by: 99)

      assert_equal 99, article.archived_by_id
    end

    test "archive! should not fail when archived_by_id column missing" do
      # Create a class without archived_by_id column
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        # Override respond_to? to simulate missing setter
        def respond_to?(method, include_private = false)
          return false if method == :archived_by_id=
          super
        end

        archivable
      end

      article = test_class.create!(title: "Test", created_at: Time.current, updated_at: Time.current)

      # Should not raise error even when trying to set archived_by
      assert_nothing_raised do
        article.archive!(by: 42)
      end

      # archived_at should still be set
      assert article.archived_at.present?
    end

    test "archive! should not fail when archive_reason column missing" do
      # Create a class without archive_reason column
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        # Override respond_to? to simulate missing setter
        def respond_to?(method, include_private = false)
          return false if method == :archive_reason=
          super
        end

        archivable
      end

      article = test_class.create!(title: "Test", created_at: Time.current, updated_at: Time.current)

      # Should not raise error even when trying to set reason
      assert_nothing_raised do
        article.archive!(by: 42, reason: "Obsolete")
      end

      # archived_at and archived_by_id should still be set
      assert article.archived_at.present?
      assert_equal 42, article.archived_by_id
    end

    # ========================================
    # CONFIGURATION ERROR TESTS
    # ========================================

    test "ConfigurationError class exists" do
      assert defined?(BetterModel::Errors::Archivable::ConfigurationError)
    end

    test "ConfigurationError inherits from ArgumentError" do
      assert BetterModel::Errors::Archivable::ConfigurationError < ArgumentError
    end

    test "ConfigurationError can be instantiated with message" do
      error = BetterModel::Errors::Archivable::ConfigurationError.new("test message")
      assert_equal "test message", error.message
    end

    test "ConfigurationError can be caught as ArgumentError" do
      begin
        raise BetterModel::Errors::Archivable::ConfigurationError.new("test")
      rescue ArgumentError => e
        assert_instance_of BetterModel::Errors::Archivable::ConfigurationError, e
      end
    end

    test "ConfigurationError has correct namespace" do
      assert_equal "BetterModel::Errors::Archivable::ConfigurationError",
                   BetterModel::Errors::Archivable::ConfigurationError.name
    end

    # ========================================
    # CONFIGURATION ERROR INTEGRATION TESTS
    # ========================================

    test "raises ConfigurationError when included in non-ActiveRecord class" do
      error = assert_raises(BetterModel::Errors::Archivable::ConfigurationError) do
        Class.new do
          include BetterModel::Archivable
        end
      end
      assert_match(/Invalid configuration/, error.message)
    end

    test "raises ConfigurationError when archived_at column is missing" do
      # Create a test class without archived_at column
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "comments"  # comments table doesn't have archived_at
        include BetterModel
      end

      error = assert_raises(BetterModel::Errors::Archivable::ConfigurationError) do
        test_class.class_eval do
          archivable
        end
      end
      assert_match(/Invalid configuration/, error.message)
    end
  end
end
