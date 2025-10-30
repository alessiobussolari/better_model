# frozen_string_literal: true

require "test_helper"

class StateableThreadSafetyTest < ActiveSupport::TestCase
  # Test models for thread safety tests
  class ThreadSafeArticle < ActiveRecord::Base
    self.table_name = "articles"
    include BetterModel

    stateable do
      state :draft, initial: true
      state :published

      transition :publish, from: :draft, to: :published

      transitions_table "thread_safe_article_transitions"
    end
  end

  class ThreadSafeDocument < ActiveRecord::Base
    self.table_name = "documents"
    include BetterModel

    stateable do
      state :pending, initial: true
      state :approved

      transition :approve, from: :pending, to: :approved

      transitions_table "thread_safe_document_transitions"
    end
  end

  test "concurrent state transition class creation is thread-safe" do
    # Remove class if it exists to test creation
    BetterModel.send(:remove_const, :ThreadSafeArticleTransition) if BetterModel.const_defined?(:ThreadSafeArticleTransition, false)

    created_classes = []
    mutex = Mutex.new

    # Spawn 10 threads that all try to create the same StateTransition class
    threads = 10.times.map do
      Thread.new do
        klass = ThreadSafeArticle.send(:create_state_transition_class_for_table, "thread_safe_article_transitions")
        mutex.synchronize { created_classes << klass }
      end
    end

    threads.each(&:join)

    # All threads should get the same class object
    assert_equal 10, created_classes.length, "All threads should complete"
    assert created_classes.all? { |k| k == created_classes.first }, "All threads should get the same class"
  end

  test "no duplicate state transition classes are created under concurrent access" do
    # Start fresh
    BetterModel.send(:remove_const, :TestConcurrentTransition) if BetterModel.const_defined?(:TestConcurrentTransition, false)

    threads = 20.times.map do
      Thread.new do
        ThreadSafeArticle.send(:create_state_transition_class_for_table, "test_concurrent_transitions")
      end
    end

    threads.each(&:join)

    # Should only have one class with this name
    assert BetterModel.const_defined?(:TestConcurrentTransition, false), "Class should be created"
    klass = BetterModel.const_get(:TestConcurrentTransition)
    assert_equal "test_concurrent_transitions", klass.table_name
  end

  test "state transition class is reused on subsequent calls" do
    # First call creates the class
    first_class = ThreadSafeArticle.send(:create_state_transition_class_for_table, "thread_safe_article_transitions")

    # Second call should return the same class
    second_class = ThreadSafeArticle.send(:create_state_transition_class_for_table, "thread_safe_article_transitions")

    assert_same first_class, second_class, "Should return the same class object"
  end

  test "multiple transition table names create different classes concurrently" do
    # Remove any existing classes
    %i[TransitionOneTransition TransitionTwoTransition TransitionThreeTransition].each do |const|
      BetterModel.send(:remove_const, const) if BetterModel.const_defined?(const, false)
    end

    classes = {}
    mutex = Mutex.new

    # Create classes for different tables concurrently
    threads = []

    5.times do
      threads << Thread.new do
        klass = ThreadSafeArticle.send(:create_state_transition_class_for_table, "transition_one_transitions")
        mutex.synchronize { classes[:transition_one] = klass }
      end

      threads << Thread.new do
        klass = ThreadSafeArticle.send(:create_state_transition_class_for_table, "transition_two_transitions")
        mutex.synchronize { classes[:transition_two] = klass }
      end

      threads << Thread.new do
        klass = ThreadSafeArticle.send(:create_state_transition_class_for_table, "transition_three_transitions")
        mutex.synchronize { classes[:transition_three] = klass }
      end
    end

    threads.each(&:join)

    # Should have 3 different classes
    assert classes[:transition_one], "transition_one class should be created"
    assert classes[:transition_two], "transition_two class should be created"
    assert classes[:transition_three], "transition_three class should be created"

    refute_same classes[:transition_one], classes[:transition_two], "Different tables should have different classes"
    refute_same classes[:transition_two], classes[:transition_three], "Different tables should have different classes"
  end

  test "class creation mutex exists and is a Mutex" do
    assert_kind_of Mutex, BetterModel::Stateable::CLASS_CREATION_MUTEX
  end

  test "state transition class creation uses mutex for synchronization" do
    # Remove class to force creation
    BetterModel.send(:remove_const, :MutexTestTransition) if BetterModel.const_defined?(:MutexTestTransition, false)

    # Create class - should use mutex internally
    klass = ThreadSafeArticle.send(:create_state_transition_class_for_table, "mutex_test_transitions")

    assert_kind_of Class, klass
    assert_equal "mutex_test_transitions", klass.table_name
  end

  test "concurrent state transitions on different records" do
    articles = []
    mutex = Mutex.new

    # Create and transition articles concurrently
    threads = 10.times.map do |i|
      Thread.new do
        article = ThreadSafeArticle.create!(title: "Article #{i}", state: "draft")
        article.publish!

        mutex.synchronize { articles << article }
      end
    end

    threads.each(&:join)

    assert_equal 10, articles.length
    articles.each do |article|
      assert article.published?, "Article should be published"
      assert_equal 1, article.state_transitions.count, "Should have one transition"
      assert_equal "publish", article.state_transitions.first.event
    end
  end

  test "concurrent transitions on same record are serialized by database" do
    article = ThreadSafeArticle.create!(title: "Test", state: "draft")

    # Try to transition the same article concurrently
    # Only one should succeed (or the database will handle it)
    results = []
    mutex = Mutex.new

    threads = 5.times.map do
      Thread.new do
        begin
          article.reload  # Reload to get fresh state
          article.publish! if article.draft?
          mutex.synchronize { results << :success }
        rescue
          mutex.synchronize { results << :error }
        end
      end
    end

    threads.each(&:join)

    # At least one should succeed
    assert results.include?(:success), "At least one transition should succeed"

    # Article should end up in published state
    article.reload
    assert article.published?, "Article should be published"
  end

  test "multiple models with different transition tables don't interfere" do
    # Create records from different models concurrently
    articles = []
    documents = []
    mutex = Mutex.new

    threads = []

    5.times do
      threads << Thread.new do
        article = ThreadSafeArticle.create!(title: "Test", state: "draft")
        article.publish!
        mutex.synchronize { articles << article }
      end

      threads << Thread.new do
        document = ThreadSafeDocument.create!(content: "Test", state: "pending")
        document.approve!
        mutex.synchronize { documents << document }
      end
    end

    threads.each(&:join)

    assert_equal 5, articles.length
    assert_equal 5, documents.length

    articles.each { |a| assert a.published? }
    documents.each { |d| assert d.approved? }
  end
end
