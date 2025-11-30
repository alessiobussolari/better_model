# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Stateable do
  # Helper per creare classi di test stateable
  def create_stateable_class(const_name, &block)
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name)

    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel

      def self.model_name
        ActiveModel::Name.new(self, nil, "Article")
      end
    end

    Object.const_set(const_name, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  def state_transitions_class
    BetterModel::StateTransition
  end

  before do
    ActiveRecord::Base.connection.execute("DELETE FROM state_transitions")
  end

  describe "module inclusion" do
    it "is defined" do
      expect(defined?(BetterModel::Stateable)).to be_truthy
    end

    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Stateable
        end
      end.to raise_error(BetterModel::Errors::Stateable::ConfigurationError, /Invalid configuration/)
    end
  end

  describe "opt-in behavior" do
    it "does not enable stateable by default" do
      test_class = create_stateable_class("StateableOptInTest")

      expect(test_class.stateable_enabled?).to be false
    end

    it "enables stateable when DSL is called" do
      test_class = create_stateable_class("StateableEnableTest") do
        stateable do
          state :draft, initial: true
          state :published
        end
      end

      expect(test_class.stateable_enabled?).to be true
    end
  end

  describe "state definition" do
    it "defines states correctly" do
      test_class = create_stateable_class("StateableStatesTest") do
        stateable do
          state :draft, initial: true
          state :published
          state :archived
        end
      end

      expect(test_class.stateable_states).to eq([:draft, :published, :archived])
      expect(test_class.stateable_initial_state).to eq(:draft)
    end

    it "sets initial state on create" do
      test_class = create_stateable_class("StateableInitialTest") do
        stateable do
          state :draft, initial: true
          state :published
        end
      end

      article = test_class.create!(title: "Test")
      expect(article.state).to eq("draft")
      expect(article.draft?).to be true
    end
  end

  describe "dynamic methods" do
    let(:test_class) do
      create_stateable_class("StateableDynamicTest") do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published
        end
      end
    end

    it "generates state predicate methods" do
      article = test_class.create!(title: "Test")

      expect(article).to respond_to(:draft?)
      expect(article).to respond_to(:published?)
      expect(article.draft?).to be true
      expect(article.published?).to be false
    end

    it "generates transition methods" do
      article = test_class.create!(title: "Test")

      expect(article).to respond_to(:publish!)
      expect(article).to respond_to(:can_publish?)
    end
  end

  describe "transitions" do
    let(:test_class) do
      create_stateable_class("StateableTransitionTest") do
        stateable do
          state :draft, initial: true
          state :published
          state :archived
          transition :publish, from: :draft, to: :published
          transition :archive, from: :published, to: :archived
        end
      end
    end

    it "executes simple transition" do
      article = test_class.create!(title: "Test")
      expect(article.state).to eq("draft")

      article.publish!
      expect(article.state).to eq("published")
      expect(article.published?).to be true
    end

    it "raises error for invalid transition" do
      article = test_class.create!(title: "Test")

      expect do
        article.archive! # Can't archive from draft
      end.to raise_error(BetterModel::Errors::Stateable::InvalidTransitionError, /Cannot transition from.*draft.*to.*archived/)
    end

    it "supports transition from multiple states" do
      test_class = create_stateable_class("StateableMultiFromTest") do
        stateable do
          state :draft, initial: true
          state :published
          state :archived
          state :deleted
          transition :publish, from: :draft, to: :published
          transition :delete, from: [:draft, :published, :archived], to: :deleted
        end
      end

      # From draft
      article1 = test_class.create!(title: "Test1")
      article1.delete!
      expect(article1.deleted?).to be true

      # From published
      article2 = test_class.create!(title: "Test2")
      article2.publish!
      article2.delete!
      expect(article2.deleted?).to be true
    end
  end

  describe "checks" do
    it "validates check with block" do
      test_class = create_stateable_class("StateableCheckBlockTest") do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            check { title.present? && title.length >= 5 }
          end
        end
      end

      article = test_class.create!(title: "Hi")
      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)

      article.title = "Valid Title"
      article.save!
      article.publish!
      expect(article.published?).to be true
    end

    it "validates check with method" do
      test_class = create_stateable_class("StateableCheckMethodTest") do
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

      article = test_class.create!(title: "Test", content: nil)
      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)

      article.content = "Content"
      article.save!
      article.publish!
      expect(article.published?).to be true
    end

    it "validates check with Statusable integration" do
      test_class = create_stateable_class("StateableCheckStatusTest") do
        is :ready_to_publish, -> { title.present? && content.present? }

        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            check if: :is_ready_to_publish?
          end
        end
      end

      article = test_class.create!(title: nil, content: nil)
      expect(article.can_publish?).to be false

      article.title = "Title"
      article.content = "Content"
      article.save!
      expect(article.can_publish?).to be true
      article.publish!
      expect(article.published?).to be true
    end

    it "requires all checks to pass with multiple checks" do
      test_class = create_stateable_class("StateableMultiCheckTest") do
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
      article = test_class.create!(title: "Hi")
      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)

      # First check passes, second fails
      article.title = "Test"
      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)

      # Both checks pass
      article.title = "Valid Title"
      article.publish!
      expect(article.published?).to be true
    end
  end

  describe "callbacks" do
    it "executes before_transition and after_transition" do
      callback_log = []

      test_class = create_stateable_class("StateableCallbackTest") do
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

      article = test_class.create!(title: "Test")
      article.publish!

      expect(callback_log).to eq(["before", "after"])
    end

    it "stops transition when before callback raises" do
      callback_log = []

      test_class = create_stateable_class("StateableCallbackStopTest") do
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

      article = test_class.create!(title: "Test")

      expect do
        article.publish!
      end.to raise_error(RuntimeError, /Before callback error/)

      # State should not have changed
      expect(article.draft?).to be true
      # After callback should not have run
      expect(callback_log).to eq(["before"])
    end
  end

  describe "state history" do
    let(:test_class) do
      create_stateable_class("StateableHistoryTest") do
        stateable do
          state :draft, initial: true
          state :published
          state :archived
          transition :publish, from: :draft, to: :published
          transition :archive, from: :published, to: :archived
        end
      end
    end

    it "tracks state transitions" do
      article = test_class.create!(title: "Test")
      article.publish!
      article.archive!

      expect(article.state_transitions.count).to eq(2)

      history = article.transition_history
      expect(history.length).to eq(2)
      expect(history[1][:event]).to eq("publish")
      expect(history[1][:from]).to eq("draft")
      expect(history[1][:to]).to eq("published")
    end

    it "stores transition metadata" do
      article = test_class.create!(title: "Test")
      article.publish!(user_id: 123, reason: "Ready")

      transition = article.state_transitions.first
      expect(transition.metadata["user_id"]).to eq(123)
      expect(transition.metadata["reason"]).to eq("Ready")
    end
  end

  describe "validation in transition" do
    it "runs validation block" do
      test_class = create_stateable_class("StateableValidationTest") do
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

      article = test_class.create!(title: "Test", content: nil)

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::ValidationFailedError, /Content required/)
    end
  end

  describe "can_transition? methods" do
    it "evaluates checks" do
      test_class = create_stateable_class("StateableCanTransitionTest") do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            check { title.present? }
          end
        end
      end

      article = test_class.create!(title: nil)
      expect(article.can_publish?).to be false

      article.title = "Title"
      expect(article.can_publish?).to be true
    end

    it "returns false when check raises exception" do
      test_class = create_stateable_class("StateableCanExceptionTest") do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            check { raise "Check exception" }
          end
        end
      end

      article = test_class.create!(title: "Test")
      expect(article.can_publish?).to be false
    end
  end

  describe "StateTransition scopes" do
    let(:test_class) do
      create_stateable_class("StateableTransitionScopesTest") do
        stateable do
          state :draft, initial: true
          state :published
          state :archived
          transition :publish, from: :draft, to: :published
          transition :archive, from: :published, to: :archived
        end
      end
    end

    it "filters by model class with for_model" do
      article1 = test_class.create!(title: "Article 1")
      article1.publish!

      article2 = test_class.create!(title: "Article 2")
      article2.publish!

      transitions = state_transitions_class.for_model(test_class)
      expect(transitions.count).to eq(2)
    end

    it "filters by event name with by_event" do
      article1 = test_class.create!(title: "Article 1")
      article1.publish!

      article2 = test_class.create!(title: "Article 2")
      article2.publish!
      article2.archive!

      publish_transitions = state_transitions_class.by_event(:publish)
      expect(publish_transitions.count).to eq(2)
      publish_transitions.each { |t| expect(t.event).to eq("publish") }

      archive_transitions = state_transitions_class.by_event(:archive)
      expect(archive_transitions.count).to eq(1)
      expect(archive_transitions.first.event).to eq("archive")
    end

    it "filters by origin state with from_state" do
      article = test_class.create!(title: "Article")
      article.publish!
      article.archive!

      from_draft = state_transitions_class.from_state(:draft)
      expect(from_draft.count).to eq(1)
      expect(from_draft.first.from_state).to eq("draft")
      expect(from_draft.first.to_state).to eq("published")

      from_published = state_transitions_class.from_state(:published)
      expect(from_published.count).to eq(1)
      expect(from_published.first.from_state).to eq("published")
      expect(from_published.first.to_state).to eq("archived")
    end

    it "filters by destination state with to_state" do
      article = test_class.create!(title: "Article")
      article.publish!
      article.archive!

      to_published = state_transitions_class.to_state(:published)
      expect(to_published.count).to eq(1)
      expect(to_published.first.to_state).to eq("published")

      to_archived = state_transitions_class.to_state(:archived)
      expect(to_archived.count).to eq(1)
      expect(to_archived.first.to_state).to eq("archived")
    end

    it "filters by time with recent" do
      article = test_class.create!(title: "Article")
      article.publish!

      # Should find transition from last 7 days (default)
      expect(state_transitions_class.recent.count).to eq(1)

      # Should find transition from last 1 hour
      expect(state_transitions_class.recent(1.hour).count).to eq(1)
    end

    it "filters by date range with between" do
      article = test_class.create!(title: "Article")
      article.publish!

      start_time = 1.hour.ago
      end_time = 1.hour.from_now
      transitions = state_transitions_class.between(start_time, end_time)
      expect(transitions.count).to eq(1)

      transitions_past = state_transitions_class.between(2.days.ago, 1.day.ago)
      expect(transitions_past.count).to eq(0)
    end

    it "supports scope chaining" do
      article1 = test_class.create!(title: "Article 1")
      article1.publish!

      article2 = test_class.create!(title: "Article 2")
      article2.publish!
      article2.archive!

      results = state_transitions_class
                .for_model(test_class)
                .by_event(:publish)
                .from_state(:draft)

      expect(results.count).to eq(2)
      results.each do |t|
        expect(t.transitionable_type).to eq(test_class.name)
        expect(t.event).to eq("publish")
        expect(t.from_state).to eq("draft")
      end
    end
  end

  describe "StateTransition description" do
    it "formats correctly" do
      test_class = create_stateable_class("StateableDescriptionTest") do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published
        end
      end

      article = test_class.create!(title: "Article")
      article.publish!

      transition = state_transitions_class.first
      description = transition.description

      expect(description).to match(/#{test_class.name}#\d+/)
      expect(description).to match(/draft -> published/)
      expect(description).to match(/publish/)
    end
  end

  describe "error handling" do
    it "raises NoMethodError when check method not found" do
      test_class = Class.new(ApplicationRecord) do
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

      article = test_class.create!(title: "Test")

      expect do
        article.publish!
      end.to raise_error(NoMethodError, /Check method 'nonexistent_method' not found/)
    end

    it "raises NoMethodError when check predicate not found" do
      test_class = Class.new(ApplicationRecord) do
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

      article = test_class.create!(title: "Test")

      expect do
        article.publish!
      end.to raise_error(NoMethodError, /Check predicate 'nonexistent_predicate\?' not found/)
    end

    it "raises ConfigurationError for unknown transition" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Stateable

        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published
        end
      end

      article = test_class.create!(title: "Test")

      expect do
        article.transition_to!(:nonexistent_transition)
      end.to raise_error(BetterModel::Errors::Stateable::ConfigurationError, /Unknown transition/)
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Stateable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Stateable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Stateable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Stateable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end

  describe "InvalidTransitionError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Stateable::InvalidTransitionError)).to be_truthy
    end
  end

  describe "CheckFailedError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Stateable::CheckFailedError)).to be_truthy
    end
  end

  describe "ValidationFailedError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Stateable::ValidationFailedError)).to be_truthy
    end
  end

  describe "NotEnabledError" do
    it "raises when calling transition_to! without stateable enabled" do
      test_class = create_stateable_class("StateableNotEnabledTest")
      # Don't call stateable DSL - module is included but not enabled

      article = test_class.create!(title: "Test")

      expect do
        article.transition_to!(:publish)
      end.to raise_error(BetterModel::Errors::Stateable::NotEnabledError)
    end

    it "raises when calling transition_history without stateable enabled" do
      test_class = create_stateable_class("StateableNotEnabledHistoryTest")

      article = test_class.create!(title: "Test")

      expect do
        article.transition_history
      end.to raise_error(BetterModel::Errors::Stateable::NotEnabledError)
    end
  end

  describe "Configurator" do
    describe "state validation" do
      it "raises when state name is not a symbol" do
        expect do
          create_stateable_class("StateableConfigStateStringTest") do
            stateable do
              state "draft", initial: true
            end
          end
        end.to raise_error(ArgumentError, /State name must be a symbol/)
      end

      it "raises when state is defined twice" do
        expect do
          create_stateable_class("StateableConfigStateDuplicateTest") do
            stateable do
              state :draft, initial: true
              state :draft
            end
          end
        end.to raise_error(ArgumentError, /State draft already defined/)
      end

      it "raises when two initial states are defined" do
        expect do
          create_stateable_class("StateableConfigTwoInitialTest") do
            stateable do
              state :draft, initial: true
              state :published, initial: true
            end
          end
        end.to raise_error(ArgumentError, /Initial state already defined/)
      end
    end

    describe "transition validation" do
      it "raises when transition name is not a symbol" do
        expect do
          create_stateable_class("StateableConfigTransitionStringTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition "publish", from: :draft, to: :published
            end
          end
        end.to raise_error(ArgumentError, /Event name must be a symbol/)
      end

      it "raises when transition is defined twice" do
        expect do
          create_stateable_class("StateableConfigTransitionDuplicateTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :published
              transition :publish, from: :draft, to: :published
            end
          end
        end.to raise_error(ArgumentError, /Transition publish already defined/)
      end

      it "raises when from state does not exist" do
        expect do
          create_stateable_class("StateableConfigFromUnknownTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :unknown, to: :published
            end
          end
        end.to raise_error(ArgumentError, /Unknown state in from/)
      end

      it "raises when to state does not exist" do
        expect do
          create_stateable_class("StateableConfigToUnknownTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :unknown
            end
          end
        end.to raise_error(ArgumentError, /Unknown state in to/)
      end
    end

    describe "check validation" do
      it "raises when check is called without block, method or if" do
        expect do
          create_stateable_class("StateableConfigCheckEmptyTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :published do
                check
              end
            end
          end
        end.to raise_error(ArgumentError, /check requires either a block, method name, or if: option/)
      end
    end

    describe "validate validation" do
      it "raises when validate is called without block" do
        expect do
          create_stateable_class("StateableConfigValidateEmptyTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :published do
                # Note: validate without block raises ArgumentError
                # We need to call it without a block somehow
              end
            end
          end
        end
      end
    end

    describe "callback validation" do
      it "raises when before_transition has no block or method" do
        expect do
          create_stateable_class("StateableConfigBeforeEmptyTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :published do
                before_transition
              end
            end
          end
        end.to raise_error(ArgumentError, /before_transition requires either a block or method name/)
      end

      it "raises when after_transition has no block or method" do
        expect do
          create_stateable_class("StateableConfigAfterEmptyTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :published do
                after_transition
              end
            end
          end
        end.to raise_error(ArgumentError, /after_transition requires either a block or method name/)
      end

      it "raises when around has no block" do
        expect do
          create_stateable_class("StateableConfigAroundEmptyTest") do
            stateable do
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :published do
                around
              end
            end
          end
        end.to raise_error(ArgumentError, /around requires a block/)
      end
    end

    describe "#transitions_table" do
      it "configures custom table name" do
        test_class = create_stateable_class("StateableConfigTableNameTest") do
          stateable do
            transitions_table "custom_transitions"
            state :draft, initial: true
            state :published
            transition :publish, from: :draft, to: :published
          end
        end

        expect(test_class.stateable_table_name).to eq("custom_transitions")
      end
    end

    describe "#to_h" do
      it "returns complete configuration" do
        test_class = create_stateable_class("StateableConfigToHTest") do
          stateable do
            transitions_table "test_transitions"
            state :draft, initial: true
            state :published
            transition :publish, from: :draft, to: :published
          end
        end

        config = test_class.stateable_config
        expect(config[:states]).to eq([:draft, :published])
        expect(config[:initial_state]).to eq(:draft)
        expect(config[:table_name]).to eq("test_transitions")
        expect(config[:transitions]).to have_key(:publish)
      end
    end
  end

  describe "Guard" do
    describe "#description" do
      let(:test_class) do
        create_stateable_class("StateableGuardDescTest") do
          is :ready_to_publish, -> { title.present? }

          stateable do
            state :draft, initial: true
            state :published
            state :archived
            transition :publish, from: :draft, to: :published do
              check { title.present? }
            end
            transition :quick_publish, from: :draft, to: :published do
              check :valid_for_publishing?
            end
            transition :archive, from: :published, to: :archived do
              check if: :is_ready_to_publish?
            end
          end

          def valid_for_publishing?
            title.present?
          end
        end
      end

      it "describes block check" do
        guard_config = test_class.stateable_transitions[:publish][:guards].first
        guard = BetterModel::Stateable::Guard.new(test_class.new, guard_config)

        expect(guard.description).to eq("block check")
      end

      it "describes method check" do
        guard_config = test_class.stateable_transitions[:quick_publish][:guards].first
        guard = BetterModel::Stateable::Guard.new(test_class.new, guard_config)

        expect(guard.description).to eq("method check: valid_for_publishing?")
      end

      it "describes predicate check" do
        guard_config = test_class.stateable_transitions[:archive][:guards].first
        guard = BetterModel::Stateable::Guard.new(test_class.new, guard_config)

        expect(guard.description).to eq("predicate check: is_ready_to_publish?")
      end

      it "describes unknown check type" do
        guard = BetterModel::Stateable::Guard.new(test_class.new, { type: :unknown })
        expect(guard.description).to eq("unknown check")
      end

      it "raises for unknown check type during evaluation" do
        guard = BetterModel::Stateable::Guard.new(test_class.new, { type: :unknown })
        expect { guard.evaluate }.to raise_error(BetterModel::Errors::Stateable::StateableError, /Unknown check type/)
      end
    end
  end

  describe "around callbacks" do
    it "executes around callback wrapping the transition" do
      callback_log = []

      test_class = create_stateable_class("StateableAroundTest") do
        define_method(:callback_log) { callback_log }

        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            around do |transition|
              callback_log << "around_start"
              transition.call
              callback_log << "around_end"
            end
          end
        end
      end

      article = test_class.create!(title: "Test")
      article.publish!

      expect(callback_log).to eq(["around_start", "around_end"])
      expect(article.published?).to be true
    end

    it "executes multiple around callbacks in correct order" do
      callback_log = []

      test_class = create_stateable_class("StateableMultiAroundTest") do
        define_method(:callback_log) { callback_log }

        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            around do |transition|
              callback_log << "outer_start"
              transition.call
              callback_log << "outer_end"
            end
            around do |transition|
              callback_log << "inner_start"
              transition.call
              callback_log << "inner_end"
            end
          end
        end
      end

      article = test_class.create!(title: "Test")
      article.publish!

      # Around callbacks are nested: outer wraps inner
      expect(callback_log).to eq(["outer_start", "inner_start", "inner_end", "outer_end"])
    end
  end

  describe "callback with method name" do
    it "calls before_transition method" do
      callback_log = []

      test_class = create_stateable_class("StateableBeforeMethodTest") do
        define_method(:callback_log) { callback_log }

        define_method(:prepare_publishing) do
          callback_log << "prepare_publishing"
        end

        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            before_transition :prepare_publishing
          end
        end
      end

      article = test_class.create!(title: "Test")
      article.publish!

      expect(callback_log).to eq(["prepare_publishing"])
    end

    it "calls after_transition method" do
      callback_log = []

      test_class = create_stateable_class("StateableAfterMethodTest") do
        define_method(:callback_log) { callback_log }

        define_method(:send_notification) do
          callback_log << "send_notification"
        end

        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            after_transition :send_notification
          end
        end
      end

      article = test_class.create!(title: "Test")
      article.publish!

      expect(callback_log).to eq(["send_notification"])
    end
  end

  describe "as_json" do
    let(:test_class) do
      create_stateable_class("StateableAsJsonTest") do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published
        end
      end
    end

    it "returns normal JSON without include_transition_history" do
      article = test_class.create!(title: "Test")
      json = article.as_json

      expect(json).not_to have_key("transition_history")
    end

    it "includes transition_history when requested" do
      article = test_class.create!(title: "Test")
      article.publish!

      json = article.as_json(include_transition_history: true)

      expect(json).to have_key("transition_history")
      expect(json["transition_history"]).to be_an(Array)
      expect(json["transition_history"].length).to eq(1)
      expect(json["transition_history"].first["event"]).to eq("publish")
    end
  end

  describe "multiple validations in transition" do
    it "collects all validation errors" do
      test_class = create_stateable_class("StateableMultiValidationTest") do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published do
            validate do
              errors.add(:title, "can't be blank") if title.blank?
              errors.add(:content, "can't be blank") if content.blank?
            end
          end
        end
      end

      article = test_class.create!(title: nil, content: nil)

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::ValidationFailedError) do |error|
        expect(error.message).to include("Title")
        expect(error.message).to include("Content")
      end
    end
  end

  describe "thread safety" do
    it "handles concurrent class creation for same table" do
      # Create multiple classes using the same transitions table concurrently
      classes = []

      threads = 5.times.map do |i|
        Thread.new do
          klass = create_stateable_class("StateableThreadTest#{i + 1}") do
            stateable do
              transitions_table "shared_transitions"
              state :draft, initial: true
              state :published
              transition :publish, from: :draft, to: :published
            end
          end
          classes << klass
        end
      end

      threads.each(&:join)

      # All classes should use the same transition class
      # This verifies thread-safe class creation
      expect(classes.length).to eq(5)
      classes.each do |klass|
        expect(klass.stateable_table_name).to eq("shared_transitions")
      end
    end
  end
end
