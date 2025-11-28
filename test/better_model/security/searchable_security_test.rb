# frozen_string_literal: true

require "test_helper"

module BetterModel
  class SearchableSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_searchables, force: true do |t|
          t.string :title
          t.boolean :active
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_searchables"
        include BetterModel::Searchable
      end
      Object.const_set(:SecureSearchable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_searchables, if_exists: true
      end
      Object.send(:remove_const, :SecureSearchable) if Object.const_defined?(:SecureSearchable)
    end

    # ========================================
    # 1. IMMUTABILITÀ CONFIGURAZIONI
    # ========================================

    test "searchable config is frozen after setup" do
      SecureSearchable.class_eval do
        searchable do
          per_page 25
        end
      end

      assert SecureSearchable.searchable_config.frozen?
    end

    test "cannot modify config at runtime" do
      SecureSearchable.class_eval do
        searchable do
          per_page 25
        end
      end

      assert_raises(FrozenError) do
        SecureSearchable.searchable_config[:per_page] = 1000
      end
    end

    # ========================================
    # 2. PAGINAZIONE SICURA
    # ========================================

    test "search method works" do
      SecureSearchable.create!(title: "Test")

      result = SecureSearchable.search
      assert result.is_a?(ActiveRecord::Relation)
    end

    # ========================================
    # 3. THREAD SAFETY
    # ========================================

    test "config is thread-safe" do
      SecureSearchable.class_eval do
        searchable do
          per_page 25
        end
      end

      results = 3.times.map do
        Thread.new { SecureSearchable.searchable_config.object_id }
      end.map(&:value)

      assert_equal 1, results.uniq.size
    end

    # ========================================
    # 4. PAGINATION LIMITS (DoS Prevention)
    # ========================================

    test "max_page limit prevents DoS via high page numbers" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          max_page 100
        end
      end

      SecureSearchable.create!(title: "Test")

      # Valid page should work
      result = SecureSearchable.search({}, pagination: { page: 50, per_page: 10 })
      assert result.is_a?(ActiveRecord::Relation)

      # Page exceeding max should raise error
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        SecureSearchable.search({}, pagination: { page: 101, per_page: 10 })
      end

      assert_match(/exceeds maximum/i, error.message)
    end

    test "negative page number raises InvalidPaginationError" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          per_page 10
        end
      end

      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        SecureSearchable.search({}, pagination: { page: -1, per_page: 10 })
      end

      assert_match(/invalid pagination/i, error.message)
    end

    test "zero page number raises InvalidPaginationError" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          per_page 10
        end
      end

      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        SecureSearchable.search({}, pagination: { page: 0, per_page: 10 })
      end

      assert_match(/invalid pagination/i, error.message)
    end

    test "per_page exceeding max_per_page raises InvalidPaginationError" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          max_per_page 50
        end
      end

      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        SecureSearchable.search({}, pagination: { page: 1, per_page: 100 })
      end

      assert_match(/per_page must be/i, error.message)
    end

    # ========================================
    # 5. QUERY COMPLEXITY LIMITS (DoS Prevention)
    # ========================================

    test "max_predicates limit prevents DoS via complex queries" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title, :active
        searchable do
          max_predicates 3
        end
      end

      # Build a query with too many predicates
      many_predicates = {
        title_eq: "a",
        title_cont: "b",
        active_eq: true,
        title_start: "c"  # 4th predicate - should exceed limit
      }

      # Note: ConfigurationError is raised for query complexity violations
      error = assert_raises(BetterModel::Errors::Searchable::ConfigurationError) do
        SecureSearchable.search(many_predicates)
      end

      assert_match(/invalid configuration/i, error.message)
    end

    test "max_or_conditions limit prevents DoS via many OR clauses" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          max_or_conditions 2
        end
      end

      # Build a query with too many OR conditions
      too_many_ors = {
        or: [
          { title_eq: "a" },
          { title_eq: "b" },
          { title_eq: "c" }  # 3rd OR - should exceed limit of 2
        ]
      }

      # Note: ConfigurationError is raised for query complexity violations
      error = assert_raises(BetterModel::Errors::Searchable::ConfigurationError) do
        SecureSearchable.search(too_many_ors)
      end

      assert_match(/invalid configuration/i, error.message)
    end

    # ========================================
    # 6. SECURITY POLICIES
    # ========================================

    test "security policy blocks missing required predicates" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title, :active
        searchable do
          # Security policies use full predicate names (e.g., active_eq not just active)
          security :admin_only, [ :active_eq ]
        end
      end

      # Without required predicate should fail
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        SecureSearchable.search({ title_eq: "test" }, security: :admin_only)
      end

      assert_match(/required.*predicates/i, error.message)
    end

    test "security policy allows queries with required predicates" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title, :active
        searchable do
          # Security policies use full predicate names (e.g., active_eq not just active)
          security :admin_only, [ :active_eq ]
        end
      end

      SecureSearchable.create!(title: "Test", active: true)

      # With required predicate should work
      result = SecureSearchable.search({ title_eq: "Test", active_eq: true }, security: :admin_only)
      assert result.is_a?(ActiveRecord::Relation)
    end

    test "unknown security policy raises InvalidSecurityError" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          per_page 10
        end
      end

      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        SecureSearchable.search({ title_eq: "test" }, security: :nonexistent_policy)
      end

      assert_match(/unknown.*security/i, error.message)
    end

    test "security policy enforcement in OR conditions" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title, :active
        searchable do
          # Security policies use full predicate names
          security :strict, [ :active_eq ]
        end
      end

      # OR condition without required predicate should fail
      error = assert_raises(BetterModel::Errors::Searchable::InvalidSecurityError) do
        SecureSearchable.search(
          {
            active_eq: true,  # Present in main predicates
            or: [
              { title_eq: "a" }  # Missing active_eq in OR condition
            ]
          },
          security: :strict
        )
      end

      assert_match(/required.*predicates/i, error.message)
    end

    # ========================================
    # 7. SQL INJECTION PREVENTION
    # ========================================

    test "SQL injection via predicate values is prevented" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          per_page 10
        end
      end

      SecureSearchable.create!(title: "Safe Title")

      # These should not cause SQL errors or return unexpected results
      dangerous_inputs = [
        "'; DROP TABLE secure_searchables; --",
        "1' OR '1'='1",
        "1; SELECT * FROM users--",
        "' UNION SELECT * FROM secure_searchables--"
      ]

      dangerous_inputs.each do |input|
        result = SecureSearchable.search({ title_eq: input })
        assert result.is_a?(ActiveRecord::Relation), "Should handle: #{input}"
        assert_equal 0, result.count, "Should not match with SQL injection: #{input}"
      end
    end

    test "LIKE special characters in cont predicates do not cause SQL errors" do
      SecureSearchable.class_eval do
        include BetterModel::Predicable
        predicates :title
        searchable do
          per_page 10
        end
      end

      SecureSearchable.create!(title: "Test%Title")
      SecureSearchable.create!(title: "Test_Title")
      SecureSearchable.create!(title: "TestXTitle")

      # Searching with LIKE special characters should not cause errors
      # Note: Whether % is escaped depends on the database adapter
      dangerous_patterns = [ "%", "_", "%%", "__", "\\", "'", "\"" ]

      dangerous_patterns.each do |pattern|
        result = SecureSearchable.search({ title_cont: pattern })
        assert result.is_a?(ActiveRecord::Relation), "Should handle pattern: #{pattern}"
        # No SQL error should occur
      end
    end
  end
end
