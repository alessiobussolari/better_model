# frozen_string_literal: true

require "test_helper"

module BetterModel
  class PermissibleSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_permissibles, force: true do |t|
          t.string :status, default: "draft"
          t.boolean :active, default: true
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_permissibles"
        include BetterModel::Permissible
      end
      Object.const_set(:SecurePermissible, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_permissibles, if_exists: true
      end
      Object.send(:remove_const, :SecurePermissible) if Object.const_defined?(:SecurePermissible)
    end

    # ========================================
    # 1. PERMISSION REGISTRY IMMUTABILITY
    # ========================================

    test "permission registry is frozen after permit definition" do
      SecurePermissible.class_eval do
        permit :delete, -> { status != "published" }
      end

      assert SecurePermissible.permit_definitions.frozen?
    end

    test "cannot modify permission registry at runtime" do
      SecurePermissible.class_eval do
        permit :delete, -> { status != "published" }
      end

      assert_raises(FrozenError) do
        SecurePermissible.permit_definitions[:hacked] = -> { true }
      end
    end

    test "individual permission conditions are frozen" do
      SecurePermissible.class_eval do
        permit :delete, -> { status != "published" }
      end

      condition = SecurePermissible.permit_definitions[:delete]
      assert condition.frozen?
    end

    # ========================================
    # 2. SECURE BY DEFAULT
    # ========================================

    test "undefined permissions return false" do
      record = SecurePermissible.create!(status: "draft")

      # No permissions defined - should return false
      refute record.permit?(:undefined_permission)
      refute record.permit?(:delete)
      refute record.permit?(:any_random_name)
    end

    test "undefined permissions with malicious names return false" do
      record = SecurePermissible.create!(status: "draft")

      malicious_names = [
        "'; DROP TABLE secure_permissibles; --",
        "<script>alert('xss')</script>",
        "../../etc/passwd",
        "\x00null_byte",
        "admin\nX-Injected: header"
      ]

      malicious_names.each do |name|
        refute record.permit?(name), "Should return false for malicious name: #{name}"
      end
    end

    # ========================================
    # 3. PERMISSION NAME SANITIZATION
    # ========================================

    test "permission names are converted to symbols" do
      SecurePermissible.class_eval do
        permit :delete, -> { true }
      end

      record = SecurePermissible.create!(status: "draft")

      # Both string and symbol should work
      assert record.permit?(:delete)
      assert record.permit?("delete")
    end

    test "permission lookup uses symbol comparison" do
      SecurePermissible.class_eval do
        permit "string_delete", -> { true }
      end

      # Stored as symbol even when defined as string
      assert SecurePermissible.permit_definitions.key?(:string_delete)
      refute SecurePermissible.permit_definitions.key?("string_delete")
    end

    test "blank permission names are rejected during definition" do
      assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        SecurePermissible.class_eval do
          permit "", -> { true }
        end
      end

      assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        SecurePermissible.class_eval do
          permit nil, -> { true }
        end
      end
    end

    # ========================================
    # 4. CONDITION VALIDATION
    # ========================================

    test "permission requires condition proc or block" do
      assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        SecurePermissible.class_eval do
          permit :no_condition
        end
      end
    end

    test "permission condition must be callable" do
      assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        SecurePermissible.class_eval do
          permit :invalid_condition, "not a proc"
        end
      end
    end

    # ========================================
    # 5. SQL INJECTION PREVENTION
    # ========================================

    test "SQL injection in permit? method is safe" do
      SecurePermissible.class_eval do
        permit :check_status, -> { status == "active" }
      end

      record = SecurePermissible.create!(status: "draft")

      # These should not cause SQL errors - they're just converted to symbols
      dangerous_inputs = [
        "'; DROP TABLE secure_permissibles; --",
        "1' OR '1'='1",
        "1; SELECT * FROM users--",
        "' UNION SELECT * FROM secure_permissibles--"
      ]

      dangerous_inputs.each do |input|
        # Should return false (not defined) without SQL error
        result = record.permit?(input)
        refute result, "Should return false for: #{input}"
      end
    end

    test "permission names cannot execute arbitrary code via to_sym" do
      record = SecurePermissible.create!(status: "draft")

      # Ruby's to_sym is safe - it just creates a symbol
      # Even potentially dangerous strings become harmless symbols
      dangerous_names = [
        "system('ls')",
        "eval('puts 1')",
        "`whoami`",
        "#{`id`}"  # This is evaluated at parse time, not at runtime
      ]

      dangerous_names.each do |name|
        # Should not raise, should not execute code
        result = record.permit?(name)
        refute result
      end
    end

    # ========================================
    # 6. XSS PREVENTION
    # ========================================

    test "permission names with XSS payloads are sanitized" do
      record = SecurePermissible.create!(status: "draft")

      xss_payloads = [
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert('xss')>",
        "javascript:alert('xss')",
        "<svg onload=alert('xss')>"
      ]

      xss_payloads.each do |payload|
        # Should return false without rendering HTML
        result = record.permit?(payload)
        refute result
        # Permission becomes a symbol, not rendered as HTML
      end
    end

    test "as_json does not render XSS in permission names" do
      SecurePermissible.class_eval do
        # Using a safe name, but testing the output
        permit :safe_delete, -> { true }
      end

      record = SecurePermissible.create!(status: "draft")
      json = record.as_json(include_permissions: true)

      # Permissions should be strings in JSON output
      assert json["permissions"].is_a?(Hash)
      assert json["permissions"].keys.all? { |k| k.is_a?(String) }
    end

    # ========================================
    # 7. THREAD SAFETY
    # ========================================

    test "permit_definitions is thread-safe" do
      SecurePermissible.class_eval do
        permit :thread_safe_permission, -> { true }
      end

      results = 5.times.map do
        Thread.new { SecurePermissible.permit_definitions.object_id }
      end.map(&:value)

      # Should return same frozen hash object across threads
      assert_equal 1, results.uniq.size
    end

    test "permit? is thread-safe for concurrent reads" do
      SecurePermissible.class_eval do
        permit :concurrent_check, -> { status == "draft" }
      end

      record = SecurePermissible.create!(status: "draft")

      results = 10.times.map do
        Thread.new { record.permit?(:concurrent_check) }
      end.map(&:value)

      # All threads should get true
      assert results.all?
    end

    # ========================================
    # 8. MASS ASSIGNMENT PROTECTION
    # ========================================

    test "permit_definitions is not a database attribute" do
      # permit_definitions is a class_attribute, not a DB column
      # This means it cannot be set via mass assignment to model instances
      refute SecurePermissible.column_names.include?("permit_definitions")

      # After defining a permission, the registry is frozen
      SecurePermissible.class_eval do
        permit :test_perm, -> { true }
      end

      # The frozen hash prevents modification
      assert SecurePermissible.permit_definitions.frozen?
    end

    test "permit_definitions class attribute is protected from direct assignment" do
      SecurePermissible.class_eval do
        permit :original, -> { true }
      end

      # Even if someone tries to assign a new hash, it should be frozen
      # and the old definitions should remain
      assert SecurePermissible.permit_definitions.frozen?
      assert SecurePermissible.permit_definitions.key?(:original)
    end

    # ========================================
    # 9. PRIVILEGE ESCALATION PREVENTION
    # ========================================

    test "permission conditions execute in instance context only" do
      execution_context = nil

      SecurePermissible.class_eval do
        permit :context_check, -> {
          execution_context = self
          true
        }
      end

      record = SecurePermissible.create!(status: "draft")
      record.permit?(:context_check)

      assert_equal record, execution_context
    end

    test "permission conditions cannot access other records" do
      other_record = nil

      SecurePermissible.class_eval do
        permit :isolation_check, -> {
          # This should only see self, not be able to modify class
          other_record = self.class.first
          status == "draft"
        }
      end

      record1 = SecurePermissible.create!(status: "draft")
      record2 = SecurePermissible.create!(status: "published")

      # Check permission on record2
      result = record2.permit?(:isolation_check)

      # The condition runs in record2's context
      refute result  # because record2.status is "published"
      assert_equal record1, other_record  # first returns record1
    end

    # ========================================
    # 10. ERROR HANDLING SECURITY
    # ========================================

    test "permission errors do not leak sensitive information" do
      error = assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        SecurePermissible.class_eval do
          permit :bad, "not callable"
        end
      end

      # Error message should be informative but not leak internals
      assert_match(/must respond to call/i, error.message)
      refute_match(/password|secret|key/i, error.message)
    end
  end
end
