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
  end
end
