# frozen_string_literal: true

require "test_helper"

module BetterModel
  class StatusableTest < ActiveSupport::TestCase
    setup do
      @article = Article.create!(
        title: "Test Article",
        content: "Test content",
        status: "draft",
        view_count: 0
      )
    end

    # Test basic status definition and checking
    test "should define status with lambda" do
      assert Article.status_defined?(:draft)
      assert Article.status_defined?(:published)
    end

    test "should check status with is? method" do
      assert @article.is?(:draft)
      refute @article.is?(:published)
    end

    test "should return false for undefined status" do
      refute @article.is?(:nonexistent_status)
    end

    # Test dynamic method generation
    test "should generate dynamic is_status? methods" do
      assert @article.respond_to?(:is_draft?)
      assert @article.respond_to?(:is_published?)
      assert @article.respond_to?(:is_scheduled?)
    end

    test "dynamic methods should return correct values" do
      assert @article.is_draft?
      refute @article.is_published?
      refute @article.is_scheduled?
    end

    # Test multiple statuses with complex conditions
    test "should handle published status correctly" do
      @article.update!(status: "published", published_at: Time.current)
      assert @article.is_published?
      assert @article.is?(:published)
    end

    test "should handle scheduled status correctly" do
      future_time = 1.day.from_now
      @article.update!(scheduled_at: future_time)
      assert @article.is_scheduled?
      refute @article.is_ready_to_publish?
    end

    test "should handle ready_to_publish status correctly" do
      past_time = 1.hour.ago
      @article.update!(scheduled_at: past_time)
      refute @article.is_scheduled?
      assert @article.is_ready_to_publish?
    end

    test "should handle expired status correctly" do
      @article.update!(expires_at: 1.hour.ago)
      assert @article.is_expired?
    end

    test "should handle popular status based on view_count" do
      refute @article.is_popular?
      @article.update!(view_count: 100)
      assert @article.is_popular?
      @article.update!(view_count: 150)
      assert @article.is_popular?
    end

    test "should handle active status with compound conditions" do
      @article.update!(status: "published")
      refute @article.is_active? # published_at is nil

      @article.update!(published_at: Time.current)
      assert @article.is_active? # published and not expired

      @article.update!(expires_at: 1.hour.ago)
      refute @article.is_active? # expired
    end

    # Test statuses method
    test "statuses should return hash of all statuses" do
      statuses = @article.statuses
      assert_instance_of Hash, statuses
      assert_includes statuses.keys, :draft
      assert_includes statuses.keys, :published
      assert_includes statuses.keys, :scheduled
      assert_equal true, statuses[:draft]
      assert_equal false, statuses[:published]
    end

    test "statuses should have all defined statuses" do
      statuses = @article.statuses
      expected_statuses = [ :draft, :published, :scheduled, :ready_to_publish, :expired, :popular, :active ]
      assert_equal expected_statuses.sort, statuses.keys.sort
    end

    test "statuses should reflect current state" do
      @article.update!(status: "published", published_at: Time.current, view_count: 150)
      statuses = @article.statuses

      assert_equal true, statuses[:published]
      assert_equal true, statuses[:popular]
      assert_equal true, statuses[:active]
      assert_equal false, statuses[:draft]
      assert_equal false, statuses[:expired]
    end

    # Test helper methods
    test "has_any_status? should return true when at least one status is active" do
      assert @article.has_any_status? # draft is active
    end

    test "has_any_status? should work with different states" do
      @article.update!(status: "published", published_at: Time.current)
      assert @article.has_any_status?
    end

    test "has_all_statuses? should return true when all specified statuses are active" do
      @article.update!(status: "published", published_at: Time.current, view_count: 150)
      assert @article.has_all_statuses?([ :published, :popular, :active ])
      refute @article.has_all_statuses?([ :published, :draft ])
    end

    test "has_all_statuses? should handle single status" do
      assert @article.has_all_statuses?([ :draft ])
      refute @article.has_all_statuses?([ :published ])
    end

    test "has_all_statuses? should handle empty array" do
      assert @article.has_all_statuses?([])
    end

    test "active_statuses should return only active statuses" do
      @article.update!(status: "published", published_at: Time.current, view_count: 150)
      active = @article.active_statuses([ :published, :draft, :popular, :expired ])
      assert_equal [ :published, :popular ].sort, active.sort
    end

    test "active_statuses should handle empty input" do
      active = @article.active_statuses([])
      assert_equal [], active
    end

    test "active_statuses should return empty when no statuses are active" do
      active = @article.active_statuses([ :published, :expired, :popular ])
      assert_equal [], active
    end

    # Test class methods
    test "defined_statuses should return all defined status names" do
      statuses = Article.defined_statuses
      assert_instance_of Array, statuses
      expected = [ :draft, :published, :scheduled, :ready_to_publish, :expired, :popular, :active ]
      assert_equal expected.sort, statuses.sort
    end

    test "status_defined? should return true for defined statuses" do
      assert Article.status_defined?(:draft)
      assert Article.status_defined?(:published)
      assert Article.status_defined?(:scheduled)
    end

    test "status_defined? should return false for undefined statuses" do
      refute Article.status_defined?(:nonexistent)
      refute Article.status_defined?(:random_status)
    end

    test "status_defined? should accept string or symbol" do
      assert Article.status_defined?(:draft)
      assert Article.status_defined?("draft")
    end

    # Test as_json integration
    test "as_json should not include statuses by default" do
      json = @article.as_json
      refute_includes json.keys, "statuses"
    end

    test "as_json with include_statuses option should include statuses" do
      json = @article.as_json(include_statuses: true)
      assert_includes json.keys, "statuses"
      assert_instance_of Hash, json["statuses"]
    end

    test "as_json statuses should have string keys" do
      json = @article.as_json(include_statuses: true)
      statuses = json["statuses"]

      assert_includes statuses.keys, "draft"
      assert_includes statuses.keys, "published"
      refute_includes statuses.keys, :draft # should be string, not symbol
    end

    test "as_json statuses should have correct boolean values" do
      @article.update!(status: "published", published_at: Time.current)
      json = @article.as_json(include_statuses: true)
      statuses = json["statuses"]

      assert_equal true, statuses["published"]
      assert_equal false, statuses["draft"]
    end

    # Test edge cases
    test "should handle nil values in conditions gracefully" do
      @article.update!(scheduled_at: nil, expires_at: nil)
      refute @article.is_scheduled?
      refute @article.is_expired?
    end

    test "should handle status name as string or symbol" do
      assert @article.is?(:draft)
      assert @article.is?("draft")
    end

    # Test error handling
    test "defining status without condition should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is :test_status
        end
      end
    end

    test "defining status with blank name should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is "", -> { true }
        end
      end
    end

    test "defining status with nil name should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is nil, -> { true }
        end
      end
    end

    test "defining status with non-callable condition should raise ArgumentError" do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is :test, "not a proc"
        end
      end
    end

    # Test block syntax
    test "should accept block instead of lambda" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Statusable

        is :block_status do
          status == "draft"
        end
      end

      article = test_class.new(status: "draft")
      assert article.is?(:block_status)
    end

    # Test thread safety
    test "is_definitions should be frozen" do
      assert Article.is_definitions.frozen?
    end

    test "individual conditions should be frozen" do
      condition = Article.is_definitions[:draft]
      assert condition.frozen?
    end

    # Test inheritance
    test "subclasses should inherit status definitions" do
      subclass = Class.new(Article)
      assert subclass.status_defined?(:draft)
      assert subclass.status_defined?(:published)
    end

    test "subclasses can define additional statuses" do
      subclass = Class.new(Article) do
        self.table_name = "articles"
        is :custom_status, -> { view_count > 1000 }
      end

      assert subclass.status_defined?(:custom_status)
      assert subclass.status_defined?(:draft) # inherited
      refute Article.status_defined?(:custom_status) # not in parent
    end

    # Test complex scenarios
    test "should handle chained status checks" do
      @article.update!(
        status: "published",
        published_at: Time.current,
        scheduled_at: 1.hour.ago,
        view_count: 150
      )

      assert @article.is_published?
      assert @article.is_ready_to_publish?
      assert @article.is_popular?
      assert @article.is_active?
      refute @article.is_draft?
      refute @article.is_scheduled?
    end

    test "should handle status transitions correctly" do
      # Start as draft
      assert @article.is_draft?
      refute @article.is_published?

      # Transition to published
      @article.update!(status: "published", published_at: Time.current)
      refute @article.is_draft?
      assert @article.is_published?
      assert @article.is_active?

      # Expire
      @article.update!(expires_at: 1.hour.ago)
      assert @article.is_published?
      assert @article.is_expired?
      refute @article.is_active?
    end

    # ========================================
    # CONFIGURATION ERROR TESTS
    # ========================================

    test "ConfigurationError class exists" do
      assert defined?(BetterModel::Errors::Statusable::ConfigurationError)
    end

    test "ConfigurationError inherits from ArgumentError" do
      assert BetterModel::Errors::Statusable::ConfigurationError < ArgumentError
    end

    test "ConfigurationError can be instantiated with message" do
      error = BetterModel::Errors::Statusable::ConfigurationError.new("test message")
      assert_equal "test message", error.message
    end

    test "ConfigurationError can be caught as ArgumentError" do
      begin
        raise BetterModel::Errors::Statusable::ConfigurationError.new("test")
      rescue ArgumentError => e
        assert_instance_of BetterModel::Errors::Statusable::ConfigurationError, e
      end
    end

    test "ConfigurationError has correct namespace" do
      assert_equal "BetterModel::Errors::Statusable::ConfigurationError",
                   BetterModel::Errors::Statusable::ConfigurationError.name
    end

    # ========================================
    # CONFIGURATION ERROR INTEGRATION TESTS
    # ========================================

    test "raises ConfigurationError when status name is blank" do
      error = assert_raises(BetterModel::Errors::Statusable::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Statusable

          is "", -> { true }
        end
      end
      assert_match(/Status name cannot be blank/, error.message)
    end

    test "raises ConfigurationError when condition is missing" do
      error = assert_raises(BetterModel::Errors::Statusable::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Statusable

          is :draft
        end
      end
      assert_match(/Condition proc or block is required/, error.message)
    end

    test "raises ConfigurationError when condition does not respond to call" do
      error = assert_raises(BetterModel::Errors::Statusable::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Statusable

          is :draft, "not a proc"
        end
      end
      assert_match(/Condition must respond to call/, error.message)
    end
  end
end
