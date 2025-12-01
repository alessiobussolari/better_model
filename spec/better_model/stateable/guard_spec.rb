# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Stateable::Guard, type: :model do
  # Create a simple test instance
  let(:test_instance) do
    article = Article.new(title: "Test", content: "Content", status: "draft")
    # Define dynamic methods for testing
    article.define_singleton_method(:customer_valid?) { true }
    article.define_singleton_method(:private_check) { true }
    article.define_singleton_method(:failing_check) { false }
    article
  end

  describe "#initialize" do
    it "accepts instance and guard_config" do
      guard = BetterModel::Stateable::Guard.new(test_instance, { type: :block, block: -> { true } })
      expect(guard).to be_a(BetterModel::Stateable::Guard)
    end
  end

  describe "#evaluate" do
    context "with block type" do
      it "evaluates block in instance context" do
        guard_config = { type: :block, block: -> { title.present? } }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.evaluate).to be true
      end

      it "returns false when block condition fails" do
        guard_config = { type: :block, block: -> { title.nil? } }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.evaluate).to be false
      end

      it "can access instance attributes" do
        guard_config = { type: :block, block: -> { content == "Content" } }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.evaluate).to be true
      end
    end

    context "with method type" do
      it "calls public method on instance" do
        guard_config = { type: :method, method: :customer_valid? }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.evaluate).to be true
      end

      it "calls private method on instance" do
        guard_config = { type: :method, method: :private_check }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.evaluate).to be true
      end

      it "returns false when method returns false" do
        guard_config = { type: :method, method: :failing_check }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.evaluate).to be false
      end

      it "raises NoMethodError for missing method" do
        guard_config = { type: :method, method: :nonexistent_method }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect { guard.evaluate }.to raise_error(NoMethodError, /not found/)
      end

      it "provides helpful error message for missing method" do
        guard_config = { type: :method, method: :missing_method }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect { guard.evaluate }.to raise_error(NoMethodError, /Define it in your model/)
      end
    end

    context "with predicate type" do
      it "calls predicate method on instance" do
        # Article has is :draft defined
        guard_config = { type: :predicate, predicate: :is_draft? }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.evaluate).to be true
      end

      it "raises NoMethodError for missing predicate" do
        guard_config = { type: :predicate, predicate: :is_nonexistent? }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect { guard.evaluate }.to raise_error(NoMethodError, /not found/)
      end

      it "provides helpful error message for missing predicate" do
        guard_config = { type: :predicate, predicate: :is_missing? }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect { guard.evaluate }.to raise_error(NoMethodError, /Statusable/)
      end
    end

    context "with unknown type" do
      it "raises StateableError" do
        guard_config = { type: :invalid }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect { guard.evaluate }.to raise_error(
          BetterModel::Errors::Stateable::StateableError,
          /Unknown check type/
        )
      end
    end
  end

  describe "#description" do
    context "with block type" do
      it "returns 'block check'" do
        guard_config = { type: :block, block: -> { true } }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.description).to eq("block check")
      end
    end

    context "with method type" do
      it "returns method check description with method name" do
        guard_config = { type: :method, method: :customer_valid? }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.description).to eq("method check: customer_valid?")
      end
    end

    context "with predicate type" do
      it "returns predicate check description with predicate name" do
        guard_config = { type: :predicate, predicate: :is_ready? }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.description).to eq("predicate check: is_ready?")
      end
    end

    context "with unknown type" do
      it "returns 'unknown check'" do
        guard_config = { type: :invalid }
        guard = BetterModel::Stateable::Guard.new(test_instance, guard_config)

        expect(guard.description).to eq("unknown check")
      end
    end
  end
end
