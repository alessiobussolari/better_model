# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Statusable do
  let(:article) { create(:article, status: "draft", view_count: 0) }

  describe "basic status definition and checking" do
    it "defines status with lambda" do
      expect(Article.status_defined?(:draft)).to be true
      expect(Article.status_defined?(:published)).to be true
    end

    it "checks status with is? method" do
      expect(article.is?(:draft)).to be true
      expect(article.is?(:published)).to be false
    end

    it "returns false for undefined status" do
      expect(article.is?(:nonexistent_status)).to be false
    end
  end

  describe "dynamic method generation" do
    it "generates dynamic is_status? methods" do
      expect(article).to respond_to(:is_draft?)
      expect(article).to respond_to(:is_published?)
      expect(article).to respond_to(:is_scheduled?)
    end

    it "returns correct values for dynamic methods" do
      expect(article.is_draft?).to be true
      expect(article.is_published?).to be false
      expect(article.is_scheduled?).to be false
    end
  end

  describe "complex status conditions" do
    it "handles published status correctly" do
      article.update!(status: "published", published_at: Time.current)
      expect(article.is_published?).to be true
      expect(article.is?(:published)).to be true
    end

    it "handles scheduled status correctly" do
      article.update!(scheduled_at: 1.day.from_now)
      expect(article.is_scheduled?).to be true
      expect(article.is_ready_to_publish?).to be false
    end

    it "handles ready_to_publish status correctly" do
      article.update!(scheduled_at: 1.hour.ago)
      expect(article.is_scheduled?).to be false
      expect(article.is_ready_to_publish?).to be true
    end

    it "handles expired status correctly" do
      article.update!(expires_at: 1.hour.ago)
      expect(article.is_expired?).to be true
    end

    it "handles popular status based on view_count" do
      expect(article.is_popular?).to be false
      article.update!(view_count: 100)
      expect(article.is_popular?).to be true
      article.update!(view_count: 150)
      expect(article.is_popular?).to be true
    end

    it "handles active status with compound conditions" do
      article.update!(status: "published")
      expect(article.is_active?).to be false # published_at is nil

      article.update!(published_at: Time.current)
      expect(article.is_active?).to be true # published and not expired

      article.update!(expires_at: 1.hour.ago)
      expect(article.is_active?).to be false # expired
    end
  end

  describe "#statuses" do
    it "returns hash of all statuses" do
      statuses = article.statuses
      expect(statuses).to be_a(Hash)
      expect(statuses.keys).to include(:draft, :published, :scheduled)
      expect(statuses[:draft]).to be true
      expect(statuses[:published]).to be false
    end

    it "has all defined statuses" do
      statuses = article.statuses
      expected_statuses = %i[draft published scheduled ready_to_publish expired popular active]
      expect(statuses.keys.sort).to eq(expected_statuses.sort)
    end

    it "reflects current state" do
      article.update!(status: "published", published_at: Time.current, view_count: 150)
      statuses = article.statuses

      expect(statuses[:published]).to be true
      expect(statuses[:popular]).to be true
      expect(statuses[:active]).to be true
      expect(statuses[:draft]).to be false
      expect(statuses[:expired]).to be false
    end
  end

  describe "helper methods" do
    describe "#has_any_status?" do
      it "returns true when at least one status is active" do
        expect(article.has_any_status?).to be true
      end

      it "works with different states" do
        article.update!(status: "published", published_at: Time.current)
        expect(article.has_any_status?).to be true
      end
    end

    describe "#has_all_statuses?" do
      it "returns true when all specified statuses are active" do
        article.update!(status: "published", published_at: Time.current, view_count: 150)
        expect(article.has_all_statuses?(%i[published popular active])).to be true
        expect(article.has_all_statuses?(%i[published draft])).to be false
      end

      it "handles single status" do
        expect(article.has_all_statuses?([ :draft ])).to be true
        expect(article.has_all_statuses?([ :published ])).to be false
      end

      it "handles empty array" do
        expect(article.has_all_statuses?([])).to be true
      end
    end

    describe "#active_statuses" do
      it "returns only active statuses" do
        article.update!(status: "published", published_at: Time.current, view_count: 150)
        active = article.active_statuses(%i[published draft popular expired])
        expect(active.sort).to eq(%i[popular published].sort)
      end

      it "handles empty input" do
        expect(article.active_statuses([])).to eq([])
      end

      it "returns empty when no statuses are active" do
        expect(article.active_statuses(%i[published expired popular])).to eq([])
      end
    end
  end

  describe "class methods" do
    describe ".defined_statuses" do
      it "returns all defined status names" do
        statuses = Article.defined_statuses
        expect(statuses).to be_an(Array)
        expected = %i[draft published scheduled ready_to_publish expired popular active]
        expect(statuses.sort).to eq(expected.sort)
      end
    end

    describe ".status_defined?" do
      it "returns true for defined statuses" do
        expect(Article.status_defined?(:draft)).to be true
        expect(Article.status_defined?(:published)).to be true
        expect(Article.status_defined?(:scheduled)).to be true
      end

      it "returns false for undefined statuses" do
        expect(Article.status_defined?(:nonexistent)).to be false
        expect(Article.status_defined?(:random_status)).to be false
      end

      it "accepts string or symbol" do
        expect(Article.status_defined?(:draft)).to be true
        expect(Article.status_defined?("draft")).to be true
      end
    end
  end

  describe "#as_json" do
    it "does not include statuses by default" do
      json = article.as_json
      expect(json.keys).not_to include("statuses")
    end

    it "includes statuses with include_statuses option" do
      json = article.as_json(include_statuses: true)
      expect(json.keys).to include("statuses")
      expect(json["statuses"]).to be_a(Hash)
    end

    it "has string keys for statuses" do
      json = article.as_json(include_statuses: true)
      statuses = json["statuses"]

      expect(statuses.keys).to include("draft", "published")
      expect(statuses.keys).not_to include(:draft)
    end

    it "has correct boolean values" do
      article.update!(status: "published", published_at: Time.current)
      json = article.as_json(include_statuses: true)
      statuses = json["statuses"]

      expect(statuses["published"]).to be true
      expect(statuses["draft"]).to be false
    end
  end

  describe "edge cases" do
    it "handles nil values in conditions gracefully" do
      article.update!(scheduled_at: nil, expires_at: nil)
      expect(article.is_scheduled?).to be false
      expect(article.is_expired?).to be false
    end

    it "handles status name as string or symbol" do
      expect(article.is?(:draft)).to be true
      expect(article.is?("draft")).to be true
    end
  end

  describe "error handling" do
    it "raises ArgumentError when defining status without condition" do
      expect do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is :test_status
        end
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when defining status with blank name" do
      expect do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is "", -> { true }
        end
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when defining status with nil name" do
      expect do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is nil, -> { true }
        end
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when defining status with non-callable condition" do
      expect do
        Class.new(ApplicationRecord) do
          include BetterModel::Statusable
          is :test, "not a proc"
        end
      end.to raise_error(ArgumentError)
    end
  end

  describe "block syntax" do
    it "accepts block instead of lambda" do
      test_class = create_statusable_class("StatusableBlockTest1") do
        is :block_status do
          status == "draft"
        end
      end

      instance = test_class.new(status: "draft")
      expect(instance.is?(:block_status)).to be true
    end
  end

  describe "thread safety" do
    it "has frozen is_definitions" do
      expect(Article.is_definitions).to be_frozen
    end

    it "has frozen individual conditions" do
      condition = Article.is_definitions[:draft]
      expect(condition).to be_frozen
    end
  end

  describe "inheritance" do
    it "subclasses inherit status definitions" do
      subclass = Class.new(Article)
      expect(subclass.status_defined?(:draft)).to be true
      expect(subclass.status_defined?(:published)).to be true
    end

    it "subclasses can define additional statuses" do
      subclass = Class.new(Article) do
        self.table_name = "articles"
        is :custom_status, -> { view_count > 1000 }
      end

      expect(subclass.status_defined?(:custom_status)).to be true
      expect(subclass.status_defined?(:draft)).to be true
      expect(Article.status_defined?(:custom_status)).to be false
    end
  end

  describe "complex scenarios" do
    it "handles chained status checks" do
      article.update!(
        status: "published",
        published_at: Time.current,
        scheduled_at: 1.hour.ago,
        view_count: 150
      )

      expect(article.is_published?).to be true
      expect(article.is_ready_to_publish?).to be true
      expect(article.is_popular?).to be true
      expect(article.is_active?).to be true
      expect(article.is_draft?).to be false
      expect(article.is_scheduled?).to be false
    end

    it "handles status transitions correctly" do
      # Start as draft
      expect(article.is_draft?).to be true
      expect(article.is_published?).to be false

      # Transition to published
      article.update!(status: "published", published_at: Time.current)
      expect(article.is_draft?).to be false
      expect(article.is_published?).to be true
      expect(article.is_active?).to be true

      # Expire
      article.update!(expires_at: 1.hour.ago)
      expect(article.is_published?).to be true
      expect(article.is_expired?).to be true
      expect(article.is_active?).to be false
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Statusable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Statusable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Statusable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Statusable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end

    it "has correct namespace" do
      expect(BetterModel::Errors::Statusable::ConfigurationError.name).to eq(
        "BetterModel::Errors::Statusable::ConfigurationError"
      )
    end
  end

  describe "ConfigurationError integration" do
    it "raises ConfigurationError when status name is blank" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Statusable
          is "", -> { true }
        end
      end.to raise_error(BetterModel::Errors::Statusable::ConfigurationError, /Status name cannot be blank/)
    end

    it "raises ConfigurationError when condition is missing" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Statusable
          is :draft
        end
      end.to raise_error(BetterModel::Errors::Statusable::ConfigurationError, /Condition proc or block is required/)
    end

    it "raises ConfigurationError when condition does not respond to call" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Statusable
          is :draft, "not a proc"
        end
      end.to raise_error(BetterModel::Errors::Statusable::ConfigurationError, /Condition must respond to call/)
    end
  end
end
