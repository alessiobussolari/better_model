# frozen_string_literal: true

require "test_helper"

module BetterModel
  class PermissibleTest < ActiveSupport::TestCase
    setup do
      @article = Article.create!(
        title: "Test Article",
        content: "Test content",
        status: "draft",
        view_count: 0
      )
    end

    # Test basic permission definition and checking
    test "should define permission with lambda" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { status != "published" }
      end

      assert test_class.permission_defined?(:delete)
    end

    test "should check permission with permit? method" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { status != "published" }
      end

      instance = test_class.new(status: "draft")
      assert instance.permit?(:delete)

      instance.status = "published"
      refute instance.permit?(:delete)
    end

    test "should return false for undefined permission" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      instance = test_class.new
      refute instance.permit?(:nonexistent_permission)
    end

    # Test dynamic method generation
    test "should generate dynamic permit_permission? methods" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { true }
      end

      instance = test_class.new
      assert instance.respond_to?(:permit_delete?)
      assert instance.respond_to?(:permit_edit?)
    end

    test "dynamic methods should return correct values" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { status == "draft" }
        permit :edit, -> { status != "archived" }
      end

      instance = test_class.new(status: "draft")
      assert instance.permit_delete?
      assert instance.permit_edit?

      instance.status = "published"
      refute instance.permit_delete?
      assert instance.permit_edit?
    end

    # Test multiple permissions with complex conditions
    test "should handle permissions referencing statuses" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Statusable
        include BetterModel::Permissible

        is :draft, -> { status == "draft" }
        is :published, -> { status == "published" }

        permit :delete, -> { is?(:draft) }
        permit :edit, -> { is?(:draft) || is?(:published) }
      end

      instance = test_class.new(status: "draft")
      assert instance.permit_delete?
      assert instance.permit_edit?

      instance.status = "published"
      refute instance.permit_delete?
      assert instance.permit_edit?
    end

    test "should handle time-based permissions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :archive, -> { created_at.present? && created_at < 1.year.ago }
      end

      instance = test_class.new(created_at: 2.years.ago)
      assert instance.permit_archive?

      instance.created_at = 1.day.ago
      refute instance.permit_archive?
    end

    test "should handle compound conditions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :publish, -> { status == "draft" && title.present? && content.present? }
      end

      instance = test_class.new(status: "draft", title: "Title", content: "Content")
      assert instance.permit_publish?

      instance.title = nil
      refute instance.permit_publish?
    end

    # Test permissions method
    test "permissions should return hash of all permissions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { false }
      end

      instance = test_class.new
      perms = instance.permissions

      assert_instance_of Hash, perms
      assert_includes perms.keys, :delete
      assert_includes perms.keys, :edit
      assert_equal true, perms[:delete]
      assert_equal false, perms[:edit]
    end

    test "permissions should have all defined permissions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { true }
        permit :publish, -> { true }
      end

      instance = test_class.new
      perms = instance.permissions
      expected_permissions = [ :delete, :edit, :publish ]

      assert_equal expected_permissions.sort, perms.keys.sort
    end

    test "permissions should reflect current state" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { status == "draft" }
        permit :edit, -> { status != "archived" }
        permit :publish, -> { status == "draft" }
      end

      instance = test_class.new(status: "draft")
      perms = instance.permissions

      assert_equal true, perms[:delete]
      assert_equal true, perms[:edit]
      assert_equal true, perms[:publish]

      instance.status = "published"
      perms = instance.permissions

      assert_equal false, perms[:delete]
      assert_equal true, perms[:edit]
      assert_equal false, perms[:publish]
    end

    # Test helper methods
    test "has_any_permission? should return true when at least one permission is granted" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { false }
      end

      instance = test_class.new
      assert instance.has_any_permission?
    end

    test "has_any_permission? should return false when no permissions granted" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { false }
        permit :edit, -> { false }
      end

      instance = test_class.new
      refute instance.has_any_permission?
    end

    test "has_all_permissions? should return true when all specified permissions are granted" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { true }
        permit :publish, -> { false }
      end

      instance = test_class.new
      assert instance.has_all_permissions?([ :delete, :edit ])
      refute instance.has_all_permissions?([ :delete, :publish ])
    end

    test "has_all_permissions? should handle single permission" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      instance = test_class.new
      assert instance.has_all_permissions?([ :delete ])
    end

    test "has_all_permissions? should handle empty array" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      instance = test_class.new
      assert instance.has_all_permissions?([])
    end

    test "granted_permissions should return only granted permissions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { false }
        permit :publish, -> { true }
      end

      instance = test_class.new
      granted = instance.granted_permissions([ :delete, :edit, :publish ])

      assert_equal [ :delete, :publish ].sort, granted.sort
    end

    test "granted_permissions should handle empty input" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      instance = test_class.new
      granted = instance.granted_permissions([])

      assert_equal [], granted
    end

    test "granted_permissions should return empty when no permissions are granted" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { false }
        permit :edit, -> { false }
      end

      instance = test_class.new
      granted = instance.granted_permissions([ :delete, :edit ])

      assert_equal [], granted
    end

    # Test class methods
    test "defined_permissions should return all defined permission names" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { true }
        permit :publish, -> { true }
      end

      permissions = test_class.defined_permissions
      assert_instance_of Array, permissions
      expected = [ :delete, :edit, :publish ]

      assert_equal expected.sort, permissions.sort
    end

    test "permission_defined? should return true for defined permissions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { true }
      end

      assert test_class.permission_defined?(:delete)
      assert test_class.permission_defined?(:edit)
    end

    test "permission_defined? should return false for undefined permissions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      refute test_class.permission_defined?(:nonexistent)
      refute test_class.permission_defined?(:random_permission)
    end

    test "permission_defined? should accept string or symbol" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      assert test_class.permission_defined?(:delete)
      assert test_class.permission_defined?("delete")
    end

    # Test as_json integration
    test "as_json should not include permissions by default" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      instance = test_class.new
      json = instance.as_json

      refute_includes json.keys, "permissions"
    end

    test "as_json with include_permissions option should include permissions" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      instance = test_class.new
      json = instance.as_json(include_permissions: true)

      assert_includes json.keys, "permissions"
      assert_instance_of Hash, json["permissions"]
    end

    test "as_json permissions should have string keys" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
        permit :edit, -> { false }
      end

      instance = test_class.new
      json = instance.as_json(include_permissions: true)
      perms = json["permissions"]

      assert_includes perms.keys, "delete"
      assert_includes perms.keys, "edit"
      refute_includes perms.keys, :delete # should be string, not symbol
    end

    test "as_json permissions should have correct boolean values" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { status == "draft" }
        permit :edit, -> { true }
      end

      instance = test_class.new(status: "draft")
      json = instance.as_json(include_permissions: true)
      perms = json["permissions"]

      assert_equal true, perms["delete"]
      assert_equal true, perms["edit"]
    end

    # Test edge cases
    test "should handle nil values in conditions gracefully" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { published_at.nil? }
      end

      instance = test_class.new(published_at: nil)
      assert instance.permit_delete?

      instance.published_at = Time.current
      refute instance.permit_delete?
    end

    test "should handle permission name as string or symbol" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      instance = test_class.new
      assert instance.permit?(:delete)
      assert instance.permit?("delete")
    end

    # Test error handling
    test "defining permission without condition should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :test_permission
        end
      end
    end

    test "defining permission with blank name should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit "", -> { true }
        end
      end
    end

    test "defining permission with nil name should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit nil, -> { true }
        end
      end
    end

    test "defining permission with non-callable condition should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :test, "not a proc"
        end
      end
    end

    # Test block syntax
    test "should accept block instead of lambda" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete do
          status == "draft"
        end
      end

      instance = test_class.new(status: "draft")
      assert instance.permit?(:delete)
    end

    # Test thread safety
    test "permit_definitions should be frozen" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      assert test_class.permit_definitions.frozen?
    end

    test "individual conditions should be frozen" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      condition = test_class.permit_definitions[:delete]
      assert condition.frozen?
    end

    # Test inheritance
    test "subclasses should inherit permission definitions" do
      parent_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      subclass = Class.new(parent_class)

      assert subclass.permission_defined?(:delete)
    end

    test "subclasses can define additional permissions" do
      parent_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { true }
      end

      subclass = Class.new(parent_class) do
        self.table_name = "articles"
        permit :custom_action, -> { view_count > 1000 }
      end

      assert subclass.permission_defined?(:custom_action)
      assert subclass.permission_defined?(:delete) # inherited
      refute parent_class.permission_defined?(:custom_action) # not in parent
    end

    # Test complex scenarios
    test "should handle multiple permission checks" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Statusable
        include BetterModel::Permissible

        is :draft, -> { status == "draft" }
        is :published, -> { status == "published" }

        permit :delete, -> { is?(:draft) }
        permit :edit, -> { is?(:draft) || is?(:published) }
        permit :publish, -> { is?(:draft) }
        permit :unpublish, -> { is?(:published) }
      end

      instance = test_class.new(status: "draft")

      assert instance.permit_delete?
      assert instance.permit_edit?
      assert instance.permit_publish?
      refute instance.permit_unpublish?
    end

    test "should handle permission transitions correctly" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Permissible

        permit :delete, -> { status == "draft" }
        permit :publish, -> { status == "draft" }
        permit :unpublish, -> { status == "published" }
      end

      instance = test_class.new(status: "draft")

      # Draft state
      assert instance.permit_delete?
      assert instance.permit_publish?
      refute instance.permit_unpublish?

      # Transition to published
      instance.status = "published"
      refute instance.permit_delete?
      refute instance.permit_publish?
      assert instance.permit_unpublish?
    end

    # Test integration with both concerns
    test "Permissible and Statusable should work together seamlessly" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Statusable
        include BetterModel::Permissible

        is :draft, -> { status == "draft" }
        is :published, -> { status == "published" && published_at.present? }
        is :expired, -> { expires_at.present? && expires_at <= Time.current }

        permit :delete, -> { is?(:draft) }
        permit :edit, -> { is?(:draft) || (is?(:published) && !is?(:expired)) }
        permit :publish, -> { is?(:draft) && title.present? }
      end

      instance = test_class.new(
        status: "published",
        published_at: Time.current,
        title: "Test",
        expires_at: nil
      )

      assert instance.is_published?
      refute instance.is_expired?
      refute instance.permit_delete?
      assert instance.permit_edit?

      # Expire the article
      instance.expires_at = 1.hour.ago
      assert instance.is_expired?
      refute instance.permit_edit?
    end

    # ========================================
    # CONFIGURATION ERROR TESTS
    # ========================================

    test "ConfigurationError class exists" do
      assert defined?(BetterModel::Errors::Permissible::ConfigurationError)
    end

    test "ConfigurationError inherits from ArgumentError" do
      assert BetterModel::Errors::Permissible::ConfigurationError < ArgumentError
    end

    test "ConfigurationError can be instantiated with message" do
      error = BetterModel::Errors::Permissible::ConfigurationError.new("test message")
      assert_equal "test message", error.message
    end

    test "ConfigurationError can be caught as ArgumentError" do
      begin
        raise BetterModel::Errors::Permissible::ConfigurationError, "test"
      rescue ArgumentError => e
        assert_instance_of BetterModel::Errors::Permissible::ConfigurationError, e
      end
    end

    test "ConfigurationError has correct namespace" do
      assert_equal "BetterModel::Errors::Permissible::ConfigurationError",
                   BetterModel::Errors::Permissible::ConfigurationError.name
    end

    # ========================================
    # CONFIGURATION ERROR INTEGRATION TESTS
    # ========================================

    test "raises ConfigurationError when permission name is blank" do
      error = assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible

          permit "", -> { true }
        end
      end
      assert_match(/Permission name cannot be blank/, error.message)
    end

    test "raises ConfigurationError when condition is missing" do
      error = assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible

          permit :delete
        end
      end
      assert_match(/Condition proc or block is required/, error.message)
    end

    test "raises ConfigurationError when condition does not respond to call" do
      error = assert_raises(BetterModel::Errors::Permissible::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible

          permit :delete, "not a proc"
        end
      end
      assert_match(/Condition must respond to call/, error.message)
    end
  end
end
