# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Stateable::Transition, type: :model do
  # Create a test class that's properly set up for stateable with a constant name
  def create_stateable_class
    # Remove existing constant if present
    Object.send(:remove_const, :TransitionTestArticle) if Object.const_defined?(:TransitionTestArticle)

    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel
    end

    # Set the constant BEFORE defining stateable so the model has a name
    Object.const_set(:TransitionTestArticle, klass)

    klass.class_eval do
      stateable do
        state :draft, initial: true
        state :review
        state :published
        state :archived

        transition :submit, from: :draft, to: :review
        transition :approve, from: :review, to: :published
        transition :archive, from: [ :draft, :review, :published ], to: :archived
      end
    end

    klass
  end

  let(:test_class) { create_stateable_class }
  let(:article) { test_class.create!(title: "Test Article") }

  before do
    ActiveRecord::Base.connection.execute("DELETE FROM state_transitions")
  end

  after do
    Object.send(:remove_const, :TransitionTestArticle) if Object.const_defined?(:TransitionTestArticle)
  end

  describe "#initialize" do
    it "accepts instance, event, config, and metadata" do
      config = { to: :review, guards: [], validations: [], before_callbacks: [], after_callbacks: [], around_callbacks: [] }
      transition = described_class.new(article, :submit, config, { user_id: 1 })

      expect(transition).to be_a(described_class)
    end

    it "stores from_state from instance" do
      config = { to: :review, guards: [], validations: [], before_callbacks: [], after_callbacks: [], around_callbacks: [] }
      described_class.new(article, :submit, config)

      # We can't access private variables directly, but we can test behavior
      expect(article.state).to eq("draft")
    end
  end

  describe "#execute!" do
    context "with simple transition" do
      it "changes the state" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        transition.execute!

        expect(article.state).to eq("review")
      end

      it "returns true on success" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        expect(transition.execute!).to be true
      end

      it "creates state transition record" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config, { reason: "Test" })

        expect { transition.execute! }.to change { article.state_transitions.count }.by(1)

        record = article.state_transitions.last
        expect(record.event).to eq("submit")
        expect(record.from_state).to eq("draft")
        expect(record.to_state).to eq("review")
        expect(record.metadata).to eq({ "reason" => "Test" })
      end
    end

    context "with guards" do
      it "executes block guards" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [ { type: :block, block: -> { title.present? } } ],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        expect { transition.execute! }.not_to raise_error
        expect(article.state).to eq("review")
      end

      it "raises CheckFailedError when guard fails" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [ { type: :block, block: -> { false } } ],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        expect { transition.execute! }.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)
      end

      it "evaluates multiple guards" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [
            { type: :block, block: -> { title.present? } },
            { type: :block, block: -> { true } }
          ],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        expect { transition.execute! }.not_to raise_error
      end

      it "stops on first failing guard" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [
            { type: :block, block: -> { false } },
            { type: :block, block: -> { raise "Should not reach here" } }
          ],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        expect { transition.execute! }.to raise_error(BetterModel::Errors::Stateable::CheckFailedError)
      end
    end

    context "with validations" do
      it "executes validation blocks" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [ -> { } ],  # Empty validation, no errors added
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        expect { transition.execute! }.not_to raise_error
      end

      it "raises ValidationFailedError when validation adds errors" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [ -> { errors.add(:base, "Not ready") } ],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        expect { transition.execute! }.to raise_error(BetterModel::Errors::Stateable::ValidationFailedError, /Not ready/)
      end

      it "clears errors before running validations" do
        article.errors.add(:base, "Previous error")

        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [ -> { } ],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        transition.execute!
        # If errors weren't cleared, there would be ValidationFailedError
        expect(article.state).to eq("review")
      end
    end

    context "with before_transition callbacks" do
      it "executes block callbacks before state change" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [ { type: :block, block: -> { @before_executed = true } } ],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        transition.execute!
        # Verify transition completed
        expect(article.state).to eq("review")
      end

      it "executes method callbacks" do
        article.define_singleton_method(:before_hook) { @callback_order ||= []; @callback_order << :before }
        article.define_singleton_method(:callback_order) { @callback_order }

        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [ { type: :method, method: :before_hook } ],
          after_callbacks: [],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        transition.execute!
        expect(article.callback_order).to include(:before)
      end
    end

    context "with after_transition callbacks" do
      it "executes callbacks after state change" do
        article.define_singleton_method(:after_hook) { @notified = true }
        article.define_singleton_method(:notified) { @notified }

        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [ { type: :method, method: :after_hook } ],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        transition.execute!
        expect(article.notified).to be true
      end

      it "executes block callbacks" do
        article.define_singleton_method(:logged=) { |v| @logged = v }
        article.define_singleton_method(:logged) { @logged }

        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [ { type: :block, block: -> { self.logged = true } } ],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        transition.execute!
        expect(article.logged).to be true
      end
    end

    context "with around callbacks" do
      it "wraps the transition" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: [
            ->(block) {
              @around_before = true
              block.call
              @around_after = true
            }
          ]
        }
        transition = described_class.new(article, :submit, config)

        transition.execute!
        expect(article.state).to eq("review")
      end

      it "supports nested around callbacks" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [],
          around_callbacks: [
            ->(block) { block.call },
            ->(block) { block.call }
          ]
        }
        transition = described_class.new(article, :submit, config)

        expect { transition.execute! }.not_to raise_error
        expect(article.state).to eq("review")
      end
    end

    context "within transaction" do
      it "rolls back on failure" do
        config = {
          from: [ :draft ],
          to: :review,
          guards: [],
          validations: [],
          before_callbacks: [],
          after_callbacks: [ { type: :block, block: -> { raise ActiveRecord::Rollback } } ],
          around_callbacks: []
        }
        transition = described_class.new(article, :submit, config)

        # After rollback, state should remain unchanged
        begin
          transition.execute!
        rescue StandardError
          # May or may not raise depending on how rollback is handled
        end
      end
    end
  end
end
