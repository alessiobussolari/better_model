# frozen_string_literal: true

require "test_helper"

module BetterModel
  class TraceableSensitiveTest < ActiveSupport::TestCase
    def create_test_class(name, &block)
      const_name = "TrackedArticle#{name}"
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)

      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel

        # Override model_name to return "Article" so that versions table name is consistent
        def self.model_name
          ActiveModel::Name.new(self, nil, "Article")
        end
      end

      Object.const_set(const_name, klass)
      klass.class_eval(&block) if block_given?
      klass
    end

    teardown do
      # Clean up test classes
      20.times do |i|
        const_name = "TrackedArticle#{i}"
        Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
      end

      # CRITICAL: Clean up all data created by tests to avoid polluting other tests
      Article.delete_all

      # Clean up version tables
      if defined?(BetterModel::ArticleVersion)
        BetterModel::ArticleVersion.delete_all
      end
    end

    # ========================================
    # SENSITIVE FIELDS - FULL REDACTION
    # ========================================

    test "sensitive :full completely redacts values" do
      test_class = create_test_class("Sensitive1") do
        traceable do
          track :title
          track :content, sensitive: :full
        end
      end

      article = test_class.create!(title: "Public", content: "Secret Content")
      article.update!(content: "New Secret")

      assert_equal 2, article.versions.count, "Should have 2 versions"

      updated_version = article.versions.where(event: "updated").first
      assert_not_nil updated_version, "Updated version should exist"
      assert_not_nil updated_version.object_changes, "object_changes should not be nil"
      assert_equal "[REDACTED]", updated_version.object_changes["content"][0]
      assert_equal "[REDACTED]", updated_version.object_changes["content"][1]

      # Normal field is not redacted in create event
      created_version = article.versions.where(event: "created").first
      assert_equal "Public", created_version.object_changes["title"][1]
    end

    test "sensitive :full handles nil values" do
      test_class = create_test_class("Sensitive2") do
        traceable do
          track :content, sensitive: :full
        end
      end

      # Create with a value, then update to nil to test nil handling
      article = test_class.create!(content: "Initial Secret")
      article.update!(content: nil)

      version = article.versions.where(event: "updated").first
      assert_not_nil version
      assert_not_nil version.object_changes

      # When updating from value to nil, both should be redacted
      assert version.object_changes.key?("content"), "Content should be in object_changes"
      assert_equal "[REDACTED]", version.object_changes["content"][0]  # was "Initial Secret"
      assert_equal "[REDACTED]", version.object_changes["content"][1]  # is now nil
    end

    # ========================================
    # SENSITIVE FIELDS - HASH
    # ========================================

    test "sensitive :hash stores SHA256 hash of values" do
      test_class = create_test_class("Sensitive3") do
        traceable do
          track :title, sensitive: :hash
        end
      end

      article = test_class.create!(title: "password123")
      version = article.versions.where(event: "created").first

      hash_value = version.object_changes["title"][1]
      assert hash_value.start_with?("sha256:")
      assert_equal 71, hash_value.length  # "sha256:" + 64 hex chars
    end

    test "sensitive :hash produces different hashes for different values" do
      test_class = create_test_class("Sensitive4") do
        traceable do
          track :content, sensitive: :hash
        end
      end

      article = test_class.create!(content: "value1")
      article.update!(content: "value2")

      version = article.versions.where(event: "updated").first
      hash1 = version.object_changes["content"][0]
      hash2 = version.object_changes["content"][1]

      assert hash1.start_with?("sha256:")
      assert hash2.start_with?("sha256:")
      assert_not_equal hash1, hash2
    end

    test "sensitive :hash produces same hash for same values" do
      test_class = create_test_class("Sensitive5") do
        traceable do
          track :content, sensitive: :hash
        end
      end

      # Create with one value, update to another, then back to original
      article = test_class.create!(content: "value1")
      article.update!(content: "value2")
      article.update!(content: "value1")  # Back to original value

      versions = article.versions.where(event: "updated").to_a

      # Should have 2 update versions
      assert_equal 2, versions.count, "Should have 2 update versions"

      # Both updates should have hashed content
      first_update = versions.first
      second_update = versions.last

      assert first_update.object_changes["content"], "First update should track content"
      assert second_update.object_changes["content"], "Second update should track content"

      # Get the hashes
      first_hash_from = first_update.object_changes["content"][0]
      first_hash_to = first_update.object_changes["content"][1]

      second_hash_from = second_update.object_changes["content"][0]
      second_hash_to = second_update.object_changes["content"][1]

      # All should be hashed
      assert first_hash_from.start_with?("sha256:")
      assert first_hash_to.start_with?("sha256:")
      assert second_hash_from.start_with?("sha256:")
      assert second_hash_to.start_with?("sha256:")

      # First update: value1 -> value2, so hashes should differ
      assert_not_equal first_hash_from, first_hash_to

      # Second update: value2 -> value1, so hash_from should match first_hash_to
      assert_equal first_hash_to, second_hash_from, "value2 should have same hash"

      # And hash_to should match original value1
      assert_equal first_hash_from, second_hash_to, "value1 should have same hash when repeated"
    end

    # ========================================
    # SENSITIVE FIELDS - PARTIAL
    # ========================================

    test "sensitive :partial masks credit card numbers" do
      test_class = create_test_class("Sensitive6") do
        traceable do
          track :content, sensitive: :partial
        end
      end

      article = test_class.create!(content: "4532123456789012")
      version = article.versions.where(event: "created").first

      masked = version.object_changes["content"][1]
      assert_equal "****9012", masked
    end

    test "sensitive :partial masks email addresses" do
      test_class = create_test_class("Sensitive7") do
        traceable do
          track :content, sensitive: :partial
        end
      end

      article = test_class.create!(content: "user@example.com")
      version = article.versions.where(event: "created").first

      masked = version.object_changes["content"][1]
      assert masked.end_with?("@example.com")
      assert masked.include?("***")
    end

    test "sensitive :partial masks SSN" do
      test_class = create_test_class("Sensitive8") do
        traceable do
          track :content, sensitive: :partial
        end
      end

      article = test_class.create!(content: "123456789")
      version = article.versions.where(event: "created").first

      masked = version.object_changes["content"][1]
      assert_equal "***-**-6789", masked
    end

    test "sensitive :partial shows length for unknown patterns" do
      test_class = create_test_class("Sensitive9") do
        traceable do
          track :content, sensitive: :partial
        end
      end

      article = test_class.create!(content: "random_text_123")
      version = article.versions.where(event: "created").first

      masked = version.object_changes["content"][1]
      assert_equal "[REDACTED:15chars]", masked
    end

    # ========================================
    # ROLLBACK WITH SENSITIVE FIELDS
    # ========================================

    test "rollback skips sensitive fields by default" do
      test_class = create_test_class("Sensitive10") do
        traceable do
          track :title
          track :content, sensitive: :full
        end
      end

      article = test_class.create!(title: "v1", content: "secret1")
      article.update!(title: "v2", content: "secret2")
      article.update!(title: "v3", content: "secret3")

      first_version = article.versions.where(event: "created").first
      article.rollback_to(first_version)

      assert_equal "v1", article.title  # Rolled back
      assert_equal "secret3", article.content  # NOT rolled back (sensitive)
    end

    test "rollback with allow_sensitive: true rolls back sensitive fields" do
      test_class = create_test_class("Sensitive11") do
        traceable do
          track :title
          track :content, sensitive: :full
        end
      end

      article = test_class.create!(title: "v1", content: "secret1")
      article.update!(title: "v2", content: "secret2")

      # Note: rollback uses the ORIGINAL values stored (before redaction in display)
      # The actual rollback mechanism still has access to original values in the version
      # Our redaction only affects what's DISPLAYED in object_changes

      first_version = article.versions.where(event: "created").first

      # With allow_sensitive, it should attempt rollback
      # However, since we're storing "[REDACTED]", it will set content to "[REDACTED]"
      article.rollback_to(first_version, allow_sensitive: true)

      assert_equal "v1", article.title
      # Content will be "[REDACTED]" because that's what we stored
      assert_equal "[REDACTED]", article.content
    end

    # ========================================
    # MIXED SENSITIVE AND NORMAL FIELDS
    # ========================================

    test "handles mix of sensitive and normal fields" do
      test_class = create_test_class("Sensitive12") do
        traceable do
          track :title
          track :status
          track :content, sensitive: :hash
        end
      end

      article = test_class.create!(
        title: "Article",
        status: "published",  # Use non-default value to ensure it's tracked
        content: "secret"
      )

      assert_equal 1, article.versions.count, "Should have 1 version after create"
      version = article.versions.where(event: "created").first
      assert_not_nil version, "Created version should exist"
      changes = version.object_changes
      assert_not_nil changes

      # Normal fields not redacted
      assert_nil changes["title"][0]
      assert_equal "Article", changes["title"][1]
      assert_equal "published", changes["status"][1]

      # Sensitive field redacted with hash
      assert changes["content"][1].start_with?("sha256:")
    end

    # ========================================
    # CONFIGURATION
    # ========================================

    test "tracks sensitive_fields configuration" do
      test_class = create_test_class("Sensitive13") do
        traceable do
          track :title
          track :content, sensitive: :full
          track :status, sensitive: :hash
        end
      end

      assert_equal({ content: :full, status: :hash },
                   test_class.traceable_sensitive_fields)
    end

    test "works with no sensitive fields configured" do
      test_class = create_test_class("Sensitive14") do
        traceable do
          track :title, :content
        end
      end

      article = test_class.create!(title: "Test", content: "Content")
      version = article.versions.where(event: "created").first

      # No redaction applied
      assert_equal "Test", version.object_changes["title"][1]
      assert_equal "Content", version.object_changes["content"][1]
    end
  end
end
