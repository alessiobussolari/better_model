# frozen_string_literal: true

require "test_helper"

module BetterModel
  class TraceableSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_traceables, force: true do |t|
          t.string :title
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_traceables"
        include BetterModel::Traceable
      end
      Object.const_set(:SecureTraceable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_traceables, if_exists: true
      end
      Object.send(:remove_const, :SecureTraceable) if Object.const_defined?(:SecureTraceable)
    end

    test "traceable config is frozen after setup" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      assert SecureTraceable.traceable_config.frozen?
    end

    test "cannot modify config at runtime" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      assert_raises(FrozenError) do
        SecureTraceable.traceable_config[:tracked_fields] = []
      end
    end

    test "config is thread-safe" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      results = 3.times.map do
        Thread.new { SecureTraceable.traceable_config.object_id }
      end.map(&:value)

      assert_equal 1, results.uniq.size
    end

    # ========================================
    # 4. NotEnabledError - Class Methods
    # ========================================

    test "NotEnabledError raised for changed_by without enabling traceable" do
      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        SecureTraceable.changed_by(1)
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised for changed_between without enabling traceable" do
      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        SecureTraceable.changed_between(1.day.ago, Time.current)
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised for field_changed without enabling traceable" do
      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        SecureTraceable.field_changed(:title)
      end

      assert_match(/not enabled/i, error.message)
    end

    # ========================================
    # 5. NotEnabledError - Instance Methods
    # ========================================

    test "NotEnabledError raised for changes_for without enabling traceable" do
      record = SecureTraceable.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        record.changes_for(:title)
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised for audit_trail without enabling traceable" do
      record = SecureTraceable.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        record.audit_trail
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised for rollback_to without enabling traceable" do
      record = SecureTraceable.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        record.rollback_to(nil)
      end

      assert_match(/not enabled/i, error.message)
    end

    test "NotEnabledError raised for as_of without enabling traceable" do
      record = SecureTraceable.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        record.as_of(1.day.ago)
      end

      assert_match(/not enabled/i, error.message)
    end

    # ========================================
    # 6. Sensitive Field Security
    # ========================================

    test "sensitive field configuration with :full level is accepted" do
      # Verify that sensitive field configuration works without error
      sensitive_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_traceables"
        def self.name
          "SensitiveFullTraceable"
        end
        include BetterModel::Traceable
      end

      assert_nothing_raised do
        sensitive_class.class_eval do
          traceable do
            track :title, sensitive: :full
          end
        end
      end

      # Verify the configuration was stored in traceable_sensitive_fields
      assert_equal :full, sensitive_class.traceable_sensitive_fields[:title]
      assert_includes sensitive_class.traceable_fields, :title
    end

    test "sensitive field configuration with :hash level is accepted" do
      # Verify that sensitive field configuration works without error
      sensitive_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_traceables"
        def self.name
          "SensitiveHashTraceable"
        end
        include BetterModel::Traceable
      end

      assert_nothing_raised do
        sensitive_class.class_eval do
          traceable do
            track :title, sensitive: :hash
          end
        end
      end

      # Verify the configuration was stored in traceable_sensitive_fields
      assert_equal :hash, sensitive_class.traceable_sensitive_fields[:title]
      assert_includes sensitive_class.traceable_fields, :title
    end

    # ========================================
    # 7. Rollback Security
    # ========================================

    test "rollback_to raises NotEnabledError if traceable not enabled" do
      record = SecureTraceable.create!(title: "Test")

      error = assert_raises(BetterModel::Errors::Traceable::NotEnabledError) do
        record.rollback_to(nil)
      end

      assert_match(/not enabled/i, error.message)
    end

    test "rollback method signature includes allow_sensitive parameter" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      # Verify method signature by checking method parameters
      method = SecureTraceable.instance_method(:rollback_to)
      param_names = method.parameters.map(&:last)

      assert_includes param_names, :allow_sensitive
    end

    # ========================================
    # 8. Traceable Enabled Check Safety
    # ========================================

    test "traceable_enabled? returns false when not configured" do
      refute SecureTraceable.traceable_enabled?
    end

    test "traceable_enabled? returns true after configuration" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      assert SecureTraceable.traceable_enabled?
    end
  end
end
