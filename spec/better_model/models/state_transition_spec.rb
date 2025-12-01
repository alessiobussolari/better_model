# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Models::StateTransition, type: :model do
  describe "class configuration" do
    it "has default table_name of state_transitions" do
      expect(BetterModel::Models::StateTransition.table_name).to eq("state_transitions")
    end
  end

  describe "validations" do
    it "validates presence of event" do
      transition = BetterModel::Models::StateTransition.new(from_state: "draft", to_state: "published")
      expect(transition).not_to be_valid
      expect(transition.errors[:event]).to include("can't be blank")
    end

    it "validates presence of from_state" do
      transition = BetterModel::Models::StateTransition.new(event: "publish", to_state: "published")
      expect(transition).not_to be_valid
      expect(transition.errors[:from_state]).to include("can't be blank")
    end

    it "validates presence of to_state" do
      transition = BetterModel::Models::StateTransition.new(event: "publish", from_state: "draft")
      expect(transition).not_to be_valid
      expect(transition.errors[:to_state]).to include("can't be blank")
    end

    it "is valid with all required attributes" do
      transition = BetterModel::Models::StateTransition.new(
        event: "publish",
        from_state: "draft",
        to_state: "published",
        transitionable_type: "Article",
        transitionable_id: 1
      )
      expect(transition).to be_valid
    end
  end

  describe "scopes" do
    before do
      ActiveRecord::Base.connection.execute("DELETE FROM state_transitions")

      # Create test article
      @article = Article.create!(title: "Test", status: "draft")

      # Create transitions
      BetterModel::Models::StateTransition.create!(
        transitionable_type: "Article",
        transitionable_id: @article.id,
        event: "publish",
        from_state: "draft",
        to_state: "published"
      )
      BetterModel::Models::StateTransition.create!(
        transitionable_type: "Article",
        transitionable_id: @article.id,
        event: "archive",
        from_state: "published",
        to_state: "archived"
      )
      BetterModel::Models::StateTransition.create!(
        transitionable_type: "Comment",
        transitionable_id: 1,
        event: "approve",
        from_state: "pending",
        to_state: "approved"
      )
    end

    describe ".for_model" do
      it "returns transitions for specific model" do
        result = BetterModel::Models::StateTransition.for_model(Article)
        expect(result.count).to eq(2)
        expect(result.all? { |t| t.transitionable_type == "Article" }).to be true
      end

      it "returns empty for model without transitions" do
        result = BetterModel::Models::StateTransition.for_model(Author)
        expect(result.count).to eq(0)
      end
    end

    describe ".by_event" do
      it "returns transitions for specific event" do
        result = BetterModel::Models::StateTransition.by_event(:publish)
        expect(result.count).to eq(1)
        expect(result.first.event).to eq("publish")
      end

      it "accepts string event name" do
        result = BetterModel::Models::StateTransition.by_event("archive")
        expect(result.count).to eq(1)
      end
    end

    describe ".from_state" do
      it "returns transitions from specific state" do
        result = BetterModel::Models::StateTransition.from_state(:draft)
        expect(result.count).to eq(1)
        expect(result.first.from_state).to eq("draft")
      end

      it "accepts string state name" do
        result = BetterModel::Models::StateTransition.from_state("published")
        expect(result.count).to eq(1)
      end
    end

    describe ".to_state" do
      it "returns transitions to specific state" do
        result = BetterModel::Models::StateTransition.to_state(:published)
        expect(result.count).to eq(1)
        expect(result.first.to_state).to eq("published")
      end

      it "accepts string state name" do
        result = BetterModel::Models::StateTransition.to_state("archived")
        expect(result.count).to eq(1)
      end
    end

    describe ".recent" do
      it "returns transitions within duration" do
        result = BetterModel::Models::StateTransition.recent(7.days)
        expect(result.count).to eq(3)
      end

      it "defaults to 7 days" do
        result = BetterModel::Models::StateTransition.recent
        expect(result.count).to eq(3)
      end
    end

    describe ".between" do
      it "returns transitions in date range" do
        result = BetterModel::Models::StateTransition.between(1.hour.ago, 1.hour.from_now)
        expect(result.count).to eq(3)
      end

      it "returns empty for out-of-range" do
        result = BetterModel::Models::StateTransition.between(1.day.from_now, 2.days.from_now)
        expect(result.count).to eq(0)
      end
    end
  end

  describe "instance methods" do
    describe "#description" do
      it "returns formatted description" do
        transition = BetterModel::Models::StateTransition.new(
          transitionable_type: "Article",
          transitionable_id: 123,
          event: "publish",
          from_state: "draft",
          to_state: "published"
        )

        expect(transition.description).to eq("Article#123: draft -> published (publish)")
      end
    end

    describe "#to_s" do
      it "is alias for description" do
        transition = BetterModel::Models::StateTransition.new(
          transitionable_type: "Order",
          transitionable_id: 456,
          event: "confirm",
          from_state: "pending",
          to_state: "confirmed"
        )

        expect(transition.to_s).to eq("Order#456: pending -> confirmed (confirm)")
      end
    end
  end

  describe "polymorphic association" do
    it "belongs_to transitionable" do
      association = BetterModel::Models::StateTransition.reflect_on_association(:transitionable)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:polymorphic]).to be true
    end
  end
end
