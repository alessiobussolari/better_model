# frozen_string_literal: true

require "test_helper"

class BetterModel::StateableTest < ActiveSupport::TestCase
  def setup
    # Clean up any previously defined test classes
    %i[StateableArticle1 StateableArticle2 StateableArticle3 StateableArticle4
       StateableArticle5 StateableArticle6 StateableArticle7 StateableArticle8
       StateableArticle9 StateableArticle10 StateableArticle11 StateableArticle12
       StateableArticle13 StateableArticle14 StateableArticle15 StateableArticle16
       StateableArticle17 StateableArticle18].each do |const_name|
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    end

    # Clean state_transitions using raw SQL
    ActiveRecord::Base.connection.execute("DELETE FROM state_transitions")
  end

  def create_stateable_class(const_name, &block)
    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel

      # Override model_name to return "Article"
      def self.model_name
        ActiveModel::Name.new(self, nil, "Article")
      end
    end

    Object.const_set(const_name, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  def state_transitions_class
    # Return the base StateTransition class
    BetterModel::StateTransition
  end

  # Test 1: Opt-in behavior
  test "stateable is not enabled by default" do
    article_class = create_stateable_class(:StateableArticle1)
    assert_not article_class.stateable_enabled?
  end

  test "stateable can be enabled with stateable do...end" do
    article_class = create_stateable_class(:StateableArticle2) do
      stateable do
        state :draft, initial: true
        state :published
      end
    end

    assert article_class.stateable_enabled?
  end

  # Test 2: State definition
  test "states are defined correctly" do
    article_class = create_stateable_class(:StateableArticle3) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
      end
    end

    assert_equal [ :draft, :published, :archived ], article_class.stateable_states
    assert_equal :draft, article_class.stateable_initial_state
  end

  test "initial state is set on create" do
    article_class = create_stateable_class(:StateableArticle4) do
      stateable do
        state :draft, initial: true
        state :published
      end
    end

    article = article_class.create!(title: "Test")
    assert_equal "draft", article.state
    assert article.draft?
  end

  # Test 3: Dynamic methods
  test "state predicate methods are generated" do
    article_class = create_stateable_class(:StateableArticle5) do
      stateable do
        state :draft, initial: true
        state :published
      end
    end

    article = article_class.create!(title: "Test")
    assert article.respond_to?(:draft?)
    assert article.respond_to?(:published?)
    assert article.draft?
    assert_not article.published?
  end

  test "transition methods are generated" do
    article_class = create_stateable_class(:StateableArticle6) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Test")
    assert article.respond_to?(:publish!)
    assert article.respond_to?(:can_publish?)
  end

  # Test 4: Transitions
  test "simple transition works" do
    article_class = create_stateable_class(:StateableArticle7) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Test")
    assert_equal "draft", article.state

    article.publish!
    assert_equal "published", article.state
    assert article.published?
  end

  test "invalid transition raises error" do
    article_class = create_stateable_class(:StateableArticle8) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        transition :publish, from: :draft, to: :published
        transition :archive, from: :published, to: :archived
      end
    end

    article = article_class.create!(title: "Test")

    error = assert_raises(BetterModel::Stateable::InvalidTransitionError) do
      article.archive!  # Can't archive from draft
    end

    assert_match(/Cannot transition from.*draft.*to.*archived/, error.message)
  end

  # Test 5: Checks
  test "check with block works" do
    article_class = create_stateable_class(:StateableArticle9) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          check { title.present? && title.length >= 5 }
        end
      end
    end

    article = article_class.create!(title: "Hi")
    assert_raises(BetterModel::Stateable::CheckFailedError) do
      article.publish!
    end

    article.title = "Valid Title"
    article.save!
    article.publish!
    assert article.published?
  end

  test "check with method works" do
    article_class = create_stateable_class(:StateableArticle10) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          check :valid_for_publishing?
        end
      end

      def valid_for_publishing?
        title.present? && content.present?
      end
    end

    article = article_class.create!(title: "Test", content: nil)
    assert_raises(BetterModel::Stateable::CheckFailedError) do
      article.publish!
    end

    article.content = "Content"
    article.save!
    article.publish!
    assert article.published?
  end

  test "check with Statusable integration works" do
    article_class = create_stateable_class(:StateableArticle11) do
      is :ready_to_publish, -> { title.present? && content.present? }

      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          check if: :is_ready_to_publish?
        end
      end
    end

    article = article_class.create!(title: nil, content: nil)
    assert_not article.can_publish?

    article.title = "Title"
    article.content = "Content"
    article.save!
    assert article.can_publish?
    article.publish!
    assert article.published?
  end

  # Test 6: Callbacks
  test "before_transition and after_transition callbacks work" do
    callback_log = []

    article_class = create_stateable_class(:StateableArticle12) do
      define_method(:callback_log) { callback_log }

      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          before_transition { callback_log << "before" }
          after_transition { callback_log << "after" }
        end
      end
    end

    article = article_class.create!(title: "Test")
    article.publish!

    assert_equal [ "before", "after" ], callback_log
  end

  # Test 7: State history
  test "state transitions are tracked" do
    article_class = create_stateable_class(:StateableArticle13) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        transition :publish, from: :draft, to: :published
        transition :archive, from: :published, to: :archived
      end
    end

    article = article_class.create!(title: "Test")
    article.publish!
    article.archive!

    assert_equal 2, article.state_transitions.count

    history = article.transition_history
    assert_equal 2, history.length
    assert_equal "publish", history[1][:event]
    assert_equal "draft", history[1][:from]
    assert_equal "published", history[1][:to]
  end

  # Test 8: Multiple from states
  test "transition from multiple states works" do
    article_class = create_stateable_class(:StateableArticle14) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        state :deleted

        transition :publish, from: :draft, to: :published
        transition :delete, from: [ :draft, :published, :archived ], to: :deleted
      end
    end

    # From draft
    article1 = article_class.create!(title: "Test1")
    article1.delete!
    assert article1.deleted?

    # From published
    article2 = article_class.create!(title: "Test2")
    article2.publish!
    article2.delete!
    assert article2.deleted?
  end

  # Test 9: Custom table name
  test "custom table name works" do
    # Test that the DSL correctly registers custom table name
    article_class = create_stateable_class(:StateableArticle15) do
      stateable do
        state :draft, initial: true
        transitions_table "state_transitions"  # Use default
      end
    end

    assert_equal "state_transitions", article_class.stateable_table_name
  end

  # Test 10: Metadata support
  test "transition metadata is stored" do
    article_class = create_stateable_class(:StateableArticle16) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Test")
    article.publish!(user_id: 123, reason: "Ready")

    transition = article.state_transitions.first
    assert_equal 123, transition.metadata["user_id"]
    assert_equal "Ready", transition.metadata["reason"]
  end

  # Test 11: Validation in transition
  test "validation in transition works" do
    article_class = create_stateable_class(:StateableArticle17) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          validate do
            errors.add(:base, "Content required") if content.blank?
          end
        end
      end
    end

    article = article_class.create!(title: "Test", content: nil)

    error = assert_raises(BetterModel::Stateable::ValidationFailedError) do
      article.publish!
    end

    assert_match(/Content required/, error.message)
  end

  # Test 12: can_transition_to? method
  test "can_transition_to? evaluates checks" do
    article_class = create_stateable_class(:StateableArticle18) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          check { title.present? }
        end
      end
    end

    article = article_class.create!(title: nil)
    assert_not article.can_publish?

    article.title = "Title"
    assert article.can_publish?
  end

  # ========================================
  # COVERAGE TESTS - StateTransition Scopes
  # ========================================

  test "StateTransitions.for_model filters by model class" do
    # Create articles with transitions
    article_class = create_stateable_class(:StateableArticle19) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article1 = article_class.create!(title: "Article 1")
    article1.publish!

    article2 = article_class.create!(title: "Article 2")
    article2.publish!

    # Filter by model class
    transitions = state_transitions_class.for_model(article_class)
    assert_equal 2, transitions.count

    # Verify all transitions are for the correct model (uses actual class name)
    transitions.each do |t|
      assert_equal article_class.name, t.transitionable_type
    end
  end

  test "StateTransitions.by_event filters by event name" do
    article_class = create_stateable_class(:StateableArticle20) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        transition :publish, from: :draft, to: :published
        transition :archive, from: :published, to: :archived
      end
    end

    article1 = article_class.create!(title: "Article 1")
    article1.publish!

    article2 = article_class.create!(title: "Article 2")
    article2.publish!
    article2.archive!

    # Filter by publish event
    publish_transitions = state_transitions_class.by_event(:publish)
    assert_equal 2, publish_transitions.count
    publish_transitions.each do |t|
      assert_equal "publish", t.event
    end

    # Filter by archive event
    archive_transitions = state_transitions_class.by_event(:archive)
    assert_equal 1, archive_transitions.count
    assert_equal "archive", archive_transitions.first.event
  end

  test "StateTransitions.from_state filters by origin state" do
    article_class = create_stateable_class(:StateableArticle21) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        transition :publish, from: :draft, to: :published
        transition :archive, from: :published, to: :archived
      end
    end

    article = article_class.create!(title: "Article")
    article.publish!
    article.archive!

    # Filter transitions from draft
    from_draft = state_transitions_class.from_state(:draft)
    assert_equal 1, from_draft.count
    assert_equal "draft", from_draft.first.from_state
    assert_equal "published", from_draft.first.to_state

    # Filter transitions from published
    from_published = state_transitions_class.from_state(:published)
    assert_equal 1, from_published.count
    assert_equal "published", from_published.first.from_state
    assert_equal "archived", from_published.first.to_state
  end

  test "StateTransitions.to_state filters by destination state" do
    article_class = create_stateable_class(:StateableArticle22) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        transition :publish, from: :draft, to: :published
        transition :archive, from: :published, to: :archived
      end
    end

    article = article_class.create!(title: "Article")
    article.publish!
    article.archive!

    # Filter transitions to published
    to_published = state_transitions_class.to_state(:published)
    assert_equal 1, to_published.count
    assert_equal "published", to_published.first.to_state

    # Filter transitions to archived
    to_archived = state_transitions_class.to_state(:archived)
    assert_equal 1, to_archived.count
    assert_equal "archived", to_archived.first.to_state
  end

  test "StateTransitions.recent filters by time duration" do
    article_class = create_stateable_class(:StateableArticle23) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Article")
    article.publish!

    # Should find transition from last 7 days (default)
    recent = state_transitions_class.recent
    assert_equal 1, recent.count

    # Should find transition from last 1 hour
    recent_hour = state_transitions_class.recent(1.hour)
    assert_equal 1, recent_hour.count

    # Should not find transition from last 0 seconds
    # (need to artificially age the transition)
    transition = state_transitions_class.first
    transition.update_column(:created_at, 2.days.ago)

    recent_day = state_transitions_class.recent(1.day)
    assert_equal 0, recent_day.count
  end

  test "StateTransitions.between filters by date range" do
    article_class = create_stateable_class(:StateableArticle24) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Article")
    article.publish!

    # Should find transition within range
    start_time = 1.hour.ago
    end_time = 1.hour.from_now
    transitions = state_transitions_class.between(start_time, end_time)
    assert_equal 1, transitions.count

    # Should not find transition outside range
    transitions_past = state_transitions_class.between(2.days.ago, 1.day.ago)
    assert_equal 0, transitions_past.count
  end

  test "StateTransition scopes can be chained" do
    article_class = create_stateable_class(:StateableArticle25) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        transition :publish, from: :draft, to: :published
        transition :archive, from: :published, to: :archived
      end
    end

    article1 = article_class.create!(title: "Article 1")
    article1.publish!

    article2 = article_class.create!(title: "Article 2")
    article2.publish!
    article2.archive!

    # Chain scopes: for_model + by_event + from_state
    results = state_transitions_class
              .for_model(article_class)
              .by_event(:publish)
              .from_state(:draft)

    assert_equal 2, results.count
    results.each do |t|
      assert_equal article_class.name, t.transitionable_type
      assert_equal "publish", t.event
      assert_equal "draft", t.from_state
    end
  end

  test "StateTransition description method formats correctly" do
    article_class = create_stateable_class(:StateableArticle26) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Article")
    article.publish!

    transition = state_transitions_class.first
    description = transition.description

    # Should include model type, id, states, and event
    assert_match(/#{article_class.name}#\d+/, description)
    assert_match(/draft -> published/, description)
    assert_match(/publish/, description)
  end

  # ========================================
  # COVERAGE TESTS - Stateable Edge Cases
  # ========================================

  test "transition with multiple checks - all must pass" do
    article_class = create_stateable_class(:StateableArticle27) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          check { title.present? }
          check { title.length >= 5 }
        end
      end
    end

    # Both checks fail
    article = article_class.create!(title: "Hi")
    assert_raises(BetterModel::Stateable::CheckFailedError) do
      article.publish!
    end

    # First check passes, second fails
    article.title = "Test"
    assert_raises(BetterModel::Stateable::CheckFailedError) do
      article.publish!
    end

    # Both checks pass
    article.title = "Valid Title"
    article.publish!
    assert article.published?
  end

  test "transition check with exception" do
    article_class = create_stateable_class(:StateableArticle28) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          check { raise "Check error" }
        end
      end
    end

    article = article_class.create!(title: "Test")

    # Check exception should be propagated
    assert_raises(RuntimeError, /Check error/) do
      article.publish!
    end
  end

  test "transition validation with exception" do
    article_class = create_stateable_class(:StateableArticle29) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          validate do
            raise "Validation error"
          end
        end
      end
    end

    article = article_class.create!(title: "Test")

    # Validation exception should be propagated
    assert_raises(RuntimeError, /Validation error/) do
      article.publish!
    end
  end

  test "callback with exception stops transition" do
    callback_log = []

    article_class = create_stateable_class(:StateableArticle30) do
      define_method(:callback_log) { callback_log }

      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          before_transition { callback_log << "before"; raise "Before callback error" }
          after_transition { callback_log << "after" }
        end
      end
    end

    article = article_class.create!(title: "Test")

    # Before callback exception should prevent transition
    assert_raises(RuntimeError, /Before callback error/) do
      article.publish!
    end

    # State should not have changed
    assert article.draft?
    # After callback should not have run
    assert_equal [ "before" ], callback_log
  end

  test "transition with invalid from state" do
    article_class = create_stateable_class(:StateableArticle31) do
      stateable do
        state :draft, initial: true
        state :published
        state :archived
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Test")
    article.publish!

    # Try to publish again from published state (invalid)
    error = assert_raises(BetterModel::Stateable::InvalidTransitionError) do
      article.publish!
    end

    assert_match(/Cannot transition/, error.message)
  end

  test "can_transition? with check that raises exception" do
    article_class = create_stateable_class(:StateableArticle32) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published do
          check { raise "Check exception" }
        end
      end
    end

    article = article_class.create!(title: "Test")

    # can_publish? should return false when check raises (not propagate exception)
    refute article.can_publish?
  end

  test "transition with nil state value" do
    article_class = create_stateable_class(:StateableArticle33) do
      stateable do
        state :draft, initial: true
        state :published
        transition :publish, from: :draft, to: :published
      end
    end

    article = article_class.create!(title: "Test")

    # Try to bypass the state machine by directly manipulating state
    # This tests that the state machine handles nil state gracefully
    article.write_attribute(:state, nil)

    # Should raise error trying to transition from nil
    # The implementation raises NoMethodError for nil.to_sym
    assert_raises(NoMethodError) do
      article.publish!
    end
  end

  # ========================================
  # ERROR HANDLING TESTS - Checks
  # ========================================

  test "should raise NoMethodError when check method not found" do
    article_class = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Stateable

      stateable do
        state :draft, initial: true
        state :published

        transition :publish, from: :draft, to: :published do
          check :nonexistent_method
        end
      end
    end

    article = article_class.create!(title: "Test")

    error = assert_raises(NoMethodError) do
      article.publish!
    end

    assert_match(/Check method 'nonexistent_method' not found/, error.message)
  end

  test "should raise NoMethodError when check predicate not found" do
    article_class = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Stateable

      stateable do
        state :draft, initial: true
        state :published

        transition :publish, from: :draft, to: :published do
          check if: :nonexistent_predicate?
        end
      end
    end

    article = article_class.create!(title: "Test")

    error = assert_raises(NoMethodError) do
      article.publish!
    end

    assert_match(/Check predicate 'nonexistent_predicate\?' not found/, error.message)
  end

  test "should raise StateableError for unknown check type" do
    article_class = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Stateable

      stateable do
        state :draft, initial: true
        state :published

        transition :publish, from: :draft, to: :published
      end

      # Helper to inject invalid check type
      def self.inject_invalid_check
        # Access the stateable configuration
        config = stateable_config
        config[:transitions][:publish][:guards] << { type: :invalid_type, something: :value }
      end
    end

    # Inject invalid check type after class definition
    article_class.inject_invalid_check

    article = article_class.create!(title: "Test")

    error = assert_raises(BetterModel::Stateable::StateableError) do
      article.publish!
    end

    assert_match(/Unknown check type: invalid_type/, error.message)
  end
end
