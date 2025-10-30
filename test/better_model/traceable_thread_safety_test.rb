# frozen_string_literal: true

require "test_helper"

class TraceableThreadSafetyTest < ActiveSupport::TestCase
  # Test models for thread safety tests
  class ThreadSafeArticle < ActiveRecord::Base
    self.table_name = "articles"
    include BetterModel

    traceable do
      track :title, :status
      versions_table :thread_safe_article_versions
    end
  end

  class ThreadSafeDocument < ActiveRecord::Base
    self.table_name = "documents"
    include BetterModel

    traceable do
      track :content
      versions_table :thread_safe_document_versions
    end
  end

  test "concurrent version class creation is thread-safe" do
    # Remove class if it exists to test creation
    BetterModel.send(:remove_const, :ThreadSafeArticleVersion) if BetterModel.const_defined?(:ThreadSafeArticleVersion, false)

    created_classes = []
    mutex = Mutex.new

    # Spawn 10 threads that all try to create the same Version class
    threads = 10.times.map do
      Thread.new do
        klass = ThreadSafeArticle.send(:create_version_class_for_table, "thread_safe_article_versions")
        mutex.synchronize { created_classes << klass }
      end
    end

    threads.each(&:join)

    # All threads should get the same class object
    assert_equal 10, created_classes.length, "All threads should complete"
    assert created_classes.all? { |k| k == created_classes.first }, "All threads should get the same class"
  end

  test "no duplicate classes are created under concurrent access" do
    # Start fresh
    BetterModel.send(:remove_const, :TestConcurrentVersion) if BetterModel.const_defined?(:TestConcurrentVersion, false)

    # Track const_set calls (we can't directly track, but we can check the result)
    threads = 20.times.map do
      Thread.new do
        ThreadSafeArticle.send(:create_version_class_for_table, "test_concurrent_versions")
      end
    end

    threads.each(&:join)

    # Should only have one class with this name
    assert BetterModel.const_defined?(:TestConcurrentVersion, false), "Class should be created"
    klass = BetterModel.const_get(:TestConcurrentVersion)
    assert_equal "test_concurrent_versions", klass.table_name
  end

  test "version class is reused on subsequent calls" do
    # First call creates the class
    first_class = ThreadSafeArticle.send(:create_version_class_for_table, "thread_safe_article_versions")

    # Second call should return the same class
    second_class = ThreadSafeArticle.send(:create_version_class_for_table, "thread_safe_article_versions")

    assert_same first_class, second_class, "Should return the same class object"
  end

  test "multiple table names create different classes concurrently" do
    # Remove any existing classes
    %i[TableOneVersion TableTwoVersion TableThreeVersion].each do |const|
      BetterModel.send(:remove_const, const) if BetterModel.const_defined?(const, false)
    end

    classes = {}
    mutex = Mutex.new

    # Create classes for different tables concurrently
    threads = []

    5.times do
      threads << Thread.new do
        klass = ThreadSafeArticle.send(:create_version_class_for_table, "table_one_versions")
        mutex.synchronize { classes[:table_one] = klass }
      end

      threads << Thread.new do
        klass = ThreadSafeArticle.send(:create_version_class_for_table, "table_two_versions")
        mutex.synchronize { classes[:table_two] = klass }
      end

      threads << Thread.new do
        klass = ThreadSafeArticle.send(:create_version_class_for_table, "table_three_versions")
        mutex.synchronize { classes[:table_three] = klass }
      end
    end

    threads.each(&:join)

    # Should have 3 different classes
    assert classes[:table_one], "table_one class should be created"
    assert classes[:table_two], "table_two class should be created"
    assert classes[:table_three], "table_three class should be created"

    refute_same classes[:table_one], classes[:table_two], "Different tables should have different classes"
    refute_same classes[:table_two], classes[:table_three], "Different tables should have different classes"
  end

  test "class creation mutex exists and is a Mutex" do
    assert_kind_of Mutex, BetterModel::Traceable::CLASS_CREATION_MUTEX
  end

  test "concurrent access with actual model operations" do
    articles = []
    mutex = Mutex.new

    # Create articles and track versions concurrently
    threads = 10.times.map do |i|
      Thread.new do
        article = ThreadSafeArticle.create!(title: "Article #{i}", status: "draft")
        article.update!(title: "Updated #{i}")

        mutex.synchronize { articles << article }
      end
    end

    threads.each(&:join)

    assert_equal 10, articles.length
    articles.each do |article|
      assert article.versions.any?, "Article should have versions"
      assert_equal 2, article.versions.count, "Should have created and updated versions"
    end
  end
end
