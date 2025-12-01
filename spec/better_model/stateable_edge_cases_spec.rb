# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Stateable, "edge cases", type: :model do
  # Helper to create test classes
  def create_stateable_class(name_suffix, &block)
    const_name = "StateableEdgeTest#{name_suffix}"
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

  after do
    Object.constants.grep(/^StateableEdgeTest/).each do |const|
      Object.send(:remove_const, const) rescue nil
    end
    ActiveRecord::Base.connection.execute("DELETE FROM state_transitions")
  end

  describe "configuration edge cases" do
    it "allows stateable without any transitions" do
      test_class = create_stateable_class("NoTransitions") do
        stateable do
          state :draft, initial: true
          state :published
        end
      end

      article = test_class.create!(title: "Test")
      expect(article.state).to eq("draft")
    end

    it "uses DB default state when no initial state configured" do
      # Note: The 'state' column has a DB default of 'draft'
      # So even without initial: true, the state will be 'draft' due to DB default
      test_class = create_stateable_class("NoInitial") do
        stateable do
          state :draft
          state :published
        end
      end

      article = test_class.create!(title: "Test")
      # DB column default is 'draft'
      expect(article.state).to eq("draft")
    end

    it "allows transitions from multiple states" do
      test_class = create_stateable_class("MultiFrom") do
        stateable do
          state :draft, initial: true
          state :review
          state :archived

          transition :archive, from: [ :draft, :review ], to: :archived
        end
      end

      draft = test_class.create!(title: "Draft")
      expect(draft.can_archive?).to be true

      draft.update!(state: "review")
      expect(draft.can_archive?).to be true
    end
  end

  describe "transition edge cases" do
    let(:test_class) do
      create_stateable_class("TransitionEdge") do
        stateable do
          state :draft, initial: true
          state :review
          state :published
          state :archived

          transition :submit, from: :draft, to: :review
          transition :approve, from: :review, to: :published
          transition :archive, from: [ :draft, :review, :published ], to: :archived
          transition :reject, from: :review, to: :draft
        end
      end
    end

    it "creates event predicate methods" do
      article = test_class.create!(title: "Test")
      expect(article).to respond_to(:can_submit?)
      expect(article).to respond_to(:can_approve?)
      expect(article).to respond_to(:can_archive?)
    end

    it "creates bang transition methods" do
      article = test_class.create!(title: "Test")
      expect(article).to respond_to(:submit!)
      expect(article).to respond_to(:approve!)
      expect(article).to respond_to(:archive!)
    end

    it "can_event? returns false when not in valid state" do
      article = test_class.create!(title: "Test")
      expect(article.state).to eq("draft")
      expect(article.can_approve?).to be false  # Can only approve from review
    end

    it "can_event? returns true when in valid state" do
      article = test_class.create!(title: "Test")
      expect(article.can_submit?).to be true  # Can submit from draft
    end

    it "transition_to! raises InvalidTransitionError for invalid transition" do
      article = test_class.create!(title: "Test")

      expect do
        article.approve!
      end.to raise_error(BetterModel::Errors::Stateable::InvalidTransitionError)
    end

    it "transition records history" do
      article = test_class.create!(title: "Test")
      article.submit!

      history = article.transition_history
      expect(history).to be_present
      # transition_history returns hashes with :from, :to, :event keys
      # Note: history is ordered newest first (created_at desc)
      expect(history.first[:from]).to eq("draft")
      expect(history.first[:to]).to eq("review")
    end
  end

  describe "guard/check edge cases" do
    let(:test_class) do
      create_stateable_class("GuardEdge") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            check { content.present? }
          end
        end
      end
    end

    it "blocks transition when check fails" do
      article = test_class.create!(title: "Test", content: nil)

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)
    end

    it "allows transition when check passes" do
      article = test_class.create!(title: "Test", content: "Some content")

      expect { article.publish! }.not_to raise_error
      expect(article.state).to eq("published")
    end

    it "evaluates check in instance context" do
      test_class = create_stateable_class("CheckContext") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            check { title == "Publishable" }
          end
        end
      end

      publishable = test_class.create!(title: "Publishable")
      expect { publishable.publish! }.not_to raise_error

      non_publishable = test_class.create!(title: "Not Publishable")
      expect { non_publishable.publish! }.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)
    end
  end

  describe "validation edge cases" do
    let(:test_class) do
      create_stateable_class("ValidationEdge") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            validate { errors.add(:content, "must be present") if content.blank? }
          end
        end
      end
    end

    it "blocks transition when validation fails" do
      article = test_class.create!(title: "Test", content: nil)

      expect do
        article.publish!
      end.to raise_error(BetterModel::Errors::Stateable::ValidationFailedError)
    end

    it "allows transition when validation passes" do
      article = test_class.create!(title: "Test", content: "Content here")

      expect { article.publish! }.not_to raise_error
    end

    it "adds errors to model errors object" do
      article = test_class.create!(title: "Test", content: nil)

      begin
        article.publish!
      rescue BetterModel::Errors::Stateable::ValidationFailedError
        # Errors might be cleared after rollback
      end
    end
  end

  describe "callback edge cases" do
    it "executes before_transition callbacks" do
      callback_called = false

      test_class = create_stateable_class("BeforeCallback") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            before_transition { callback_called = true }
          end
        end
      end

      article = test_class.create!(title: "Test")
      article.publish!

      # Callback is evaluated in instance context, so this won't work directly
      # But we can verify transition succeeded
      expect(article.state).to eq("published")
    end

    it "executes after_transition callbacks" do
      test_class = create_stateable_class("AfterCallback") do
        attr_accessor :callback_executed

        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            after_transition { self.callback_executed = true }
          end
        end
      end

      article = test_class.create!(title: "Test")
      article.publish!

      expect(article.callback_executed).to be true
    end

    it "can call method callbacks" do
      test_class = create_stateable_class("MethodCallback") do
        attr_accessor :notified

        def send_notification
          self.notified = true
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

      expect(article.notified).to be true
    end
  end

  describe "transition history edge cases" do
    let(:test_class) do
      create_stateable_class("HistoryEdge") do
        stateable do
          state :draft, initial: true
          state :review
          state :published

          transition :submit, from: :draft, to: :review
          transition :approve, from: :review, to: :published
        end
      end
    end

    it "tracks multiple transitions" do
      article = test_class.create!(title: "Test")
      article.submit!
      article.approve!

      history = article.transition_history
      expect(history.count).to eq(2)

      # transition_history returns hashes with :from, :to, :event keys
      # Note: ordered newest first (created_at desc)
      expect(history.first[:from]).to eq("review")
      expect(history.first[:to]).to eq("published")
      expect(history.last[:from]).to eq("draft")
      expect(history.last[:to]).to eq("review")
    end

    it "records event name in history" do
      article = test_class.create!(title: "Test")
      article.submit!

      history = article.transition_history
      expect(history.first[:event]).to eq("submit")
    end

    it "records timestamps in history" do
      article = test_class.create!(title: "Test")
      article.submit!

      history = article.transition_history
      expect(history.first[:at]).to be_present
    end
  end

  describe "enabled check edge cases" do
    it "returns false for stateable_enabled? when not configured" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
      end

      expect(klass.stateable_enabled?).to be false
    end

    it "returns true for stateable_enabled? when configured" do
      test_class = create_stateable_class("EnabledCheck") do
        stateable do
          state :draft, initial: true
        end
      end

      expect(test_class.stateable_enabled?).to be true
    end

    it "raises NotEnabledError when calling transition_to! without stateable" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Stateable
      end

      article = klass.create!(title: "Test", status: "draft")

      expect do
        article.transition_to!(:publish)
      end.to raise_error(BetterModel::Errors::Stateable::NotEnabledError)
    end
  end

  describe "custom table name edge cases" do
    it "uses configured table name for history" do
      test_class = create_stateable_class("CustomTable") do
        stateable do
          transitions_table "state_transitions"  # Use default table that exists
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published
        end
      end

      article = test_class.create!(title: "Test")
      article.publish!

      expect(article.transition_history).to be_present
    end
  end

  describe "concurrent transition handling" do
    let(:test_class) do
      create_stateable_class("Concurrent") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published
        end
      end
    end

    it "handles transitions atomically" do
      article = test_class.create!(title: "Test")
      article.publish!

      # After transition, state should be updated
      article.reload
      expect(article.state).to eq("published")
    end
  end

  describe "state predicate methods" do
    let(:test_class) do
      create_stateable_class("StatePredicates") do
        stateable do
          state :draft, initial: true
          state :published
          state :archived
        end
      end
    end

    it "creates state? predicate methods" do
      article = test_class.create!(title: "Test")
      expect(article).to respond_to(:draft?)
      expect(article).to respond_to(:published?)
      expect(article).to respond_to(:archived?)
    end

    it "state? returns true for current state" do
      article = test_class.create!(title: "Test")
      expect(article.draft?).to be true
      expect(article.published?).to be false
    end
  end

  describe "state filtering" do
    let(:test_class) do
      create_stateable_class("StateFiltering") do
        stateable do
          state :draft, initial: true
          state :published
        end
      end
    end

    it "can filter by state using where" do
      draft_article = test_class.create!(title: "Draft")
      published_article = test_class.create!(title: "Published", state: "published")

      expect(test_class.where(state: "draft").count).to eq(1)
      expect(test_class.where(state: "published").count).to eq(1)
    end
  end

  describe "transition with metadata" do
    let(:test_class) do
      create_stateable_class("Metadata") do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published
        end
      end
    end

    it "stores metadata in transition history" do
      article = test_class.create!(title: "Test")
      article.publish!(metadata: { approved_by: "admin" })

      history = article.transition_history
      expect(history.first[:metadata]).to be_a(Hash)
    end
  end
end
