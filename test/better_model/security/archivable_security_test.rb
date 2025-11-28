# frozen_string_literal: true

require "test_helper"

module BetterModel
  class ArchivableSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_archivables, force: true do |t|
          t.string :title
          t.datetime :archived_at
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_archivables"
        include BetterModel::Archivable
      end
      Object.const_set(:SecureArchivable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_archivables, if_exists: true
      end
      Object.send(:remove_const, :SecureArchivable) if Object.const_defined?(:SecureArchivable)
    end

    test "archivable module loads without errors" do
      # Verifica che il modulo sia incluso correttamente
      assert SecureArchivable.included_modules.include?(BetterModel::Archivable)
    end

    # === NotEnabledError Tests ===

    test "NotEnabledError raised when calling archive! without enabling archivable" do
      record = SecureArchivable.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
        record.archive!
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised when calling restore! without enabling archivable" do
      record = SecureArchivable.create!(title: "Test")
      # Manually set archived_at to simulate archived state
      record.update_column(:archived_at, Time.current)

      error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
        record.restore!
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised when calling archived_only without enabling archivable" do
      error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
        SecureArchivable.archived_only
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised when calling archived_today without enabling archivable" do
      error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
        SecureArchivable.archived_today
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised when calling archived_this_week without enabling archivable" do
      error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
        SecureArchivable.archived_this_week
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised when calling archived_recently without enabling archivable" do
      error = assert_raises(BetterModel::Errors::Archivable::NotEnabledError) do
        SecureArchivable.archived_recently(7.days)
      end

      assert_match(/not enabled/i, error.message)
    end

    # === Config Immutability Tests ===

    test "archivable config is frozen after setup" do
      # Create model with archivable enabled (needs full BetterModel for predicable_field?)
      enabled_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_archivables"
        include BetterModel
        archivable
      end

      assert enabled_class.archivable_config.frozen?,
        "archivable_config should be frozen after setup"
    end

    test "cannot modify archivable_config hash at runtime" do
      enabled_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_archivables"
        include BetterModel
        archivable do
          skip_archived_by_default false
        end
      end

      assert_raises(FrozenError) do
        enabled_class.archivable_config[:skip_archived_by_default] = true
      end
    end

    test "archivable_enabled attribute cannot bypass security" do
      # Verify that archivable_enabled starts as false
      assert_equal false, SecureArchivable.archivable_enabled

      # Even after manually setting, methods should respect the actual state
      # This tests that the enabled? check is robust
      refute SecureArchivable.archivable_enabled?
    end

    # === Thread Safety Tests ===

    test "config is thread-safe across multiple threads" do
      enabled_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_archivables"
        include BetterModel
        archivable
      end

      results = []
      threads = 10.times.map do
        Thread.new do
          10.times do
            results << enabled_class.archivable_enabled?
            results << enabled_class.archivable_config.frozen?
          end
        end
      end

      threads.each(&:join)

      # All results should be consistent
      assert results.all? { |r| r == true }, "Config access should be thread-safe"
    end

    # === Input Sanitization Tests ===

    test "archive_reason with special characters is handled safely" do
      # Create model with archivable enabled and archive_reason column
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.add_column :secure_archivables, :archive_reason, :string
        ActiveRecord::Migration.add_column :secure_archivables, :archived_by_id, :integer
      end

      enabled_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_archivables"
        include BetterModel
        archivable
      end

      record = enabled_class.create!(title: "Test")

      # Test with potentially dangerous input
      dangerous_inputs = [
        "<script>alert('xss')</script>",
        "'; DROP TABLE secure_archivables; --",
        "test\x00null\x00byte",
        "test\nwith\nnewlines"
      ]

      dangerous_inputs.each do |input|
        record.reload
        record.update_column(:archived_at, nil) # Reset
        record.archive!(reason: input)

        # Verify the value is stored (sanitization is responsibility of view layer)
        # but the operation doesn't break
        assert record.archived?
        assert_equal input, record.archive_reason
        record.restore!
      end
    ensure
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.remove_column :secure_archivables, :archive_reason, if_exists: true
        ActiveRecord::Migration.remove_column :secure_archivables, :archived_by_id, if_exists: true
      end
    end

    test "archived? returns false when archivable not enabled" do
      record = SecureArchivable.create!(title: "Test")
      record.update_column(:archived_at, Time.current)

      # Should return false, not raise error - safe default
      refute record.archived?
    end

    test "active? returns true when archivable not enabled" do
      record = SecureArchivable.create!(title: "Test")

      # Should return true (not archived), not raise error
      assert record.active?
    end
  end
end
