# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Models::Version, type: :model do
  # Use the ArticleVersion class which inherits from Version
  let(:version_class) do
    # Find or create a concrete Version class for the article_versions table
    unless BetterModel.const_defined?(:ArticleVersion, false)
      Class.new(BetterModel::Models::Version) do
        self.table_name = "article_versions"
      end.tap { |k| BetterModel.const_set(:ArticleVersion, k) }
    end
    BetterModel::ArticleVersion
  end

  describe "class configuration" do
    it "is an abstract class" do
      expect(BetterModel::Models::Version.abstract_class).to be true
    end
  end

  describe "validations" do
    it "validates presence of item_type" do
      version = version_class.new(event: "created", item_id: 1)
      expect(version).not_to be_valid
      expect(version.errors[:item_type]).to include("can't be blank")
    end

    it "validates presence of event" do
      version = version_class.new(item_type: "Article", item_id: 1)
      expect(version).not_to be_valid
      expect(version.errors[:event]).to include("can't be blank")
    end

    it "validates event is one of created, updated, destroyed" do
      version = version_class.new(item_type: "Article", item_id: 1, event: "invalid")
      expect(version).not_to be_valid
      expect(version.errors[:event]).to include("is not included in the list")
    end

    it "accepts created as valid event" do
      version = version_class.new(item_type: "Article", item_id: 1, event: "created")
      version.valid?
      expect(version.errors[:event]).to be_empty
    end

    it "accepts updated as valid event" do
      version = version_class.new(item_type: "Article", item_id: 1, event: "updated")
      version.valid?
      expect(version.errors[:event]).to be_empty
    end

    it "accepts destroyed as valid event" do
      version = version_class.new(item_type: "Article", item_id: 1, event: "destroyed")
      version.valid?
      expect(version.errors[:event]).to be_empty
    end
  end

  describe "scopes" do
    before do
      ActiveRecord::Base.connection.execute("DELETE FROM article_versions")

      @article = Article.create!(title: "Test", status: "draft")
      # Article.create! triggers traceable callback creating a "created" version
      # So we add 2 more "updated" versions manually
      version_class.create!(item_type: "Article", item_id: @article.id, event: "updated", object_changes: { "title" => [ "Test", "Updated" ] }, updated_by_id: 1)
      version_class.create!(item_type: "Article", item_id: @article.id, event: "updated", object_changes: { "status" => [ "draft", "published" ] }, updated_by_id: 2)
      # Total: 1 created (from Article.create!) + 2 updated = 3 versions for @article
    end

    describe ".for_item" do
      it "returns versions for specific item" do
        result = version_class.for_item(@article)
        # 1 created + 2 updated = 3
        expect(result.count).to eq(3)
      end
    end

    describe ".created_events" do
      it "returns only created events" do
        result = version_class.created_events
        expect(result.count).to be >= 1
        expect(result.all? { |v| v.event == "created" }).to be true
      end
    end

    describe ".updated_events" do
      it "returns only updated events" do
        result = version_class.updated_events
        expect(result.count).to eq(2)
        expect(result.all? { |v| v.event == "updated" }).to be true
      end
    end

    describe ".destroyed_events" do
      it "returns only destroyed events" do
        version_class.create!(item_type: "Article", item_id: @article.id, event: "destroyed", object_changes: {})
        result = version_class.destroyed_events
        expect(result.count).to eq(1)
        expect(result.first.event).to eq("destroyed")
      end
    end

    describe ".by_user" do
      it "returns versions by specific user" do
        result = version_class.by_user(1)
        expect(result.count).to eq(1)
      end

      it "returns empty for non-existent user" do
        result = version_class.by_user(999)
        expect(result.count).to eq(0)
      end
    end

    describe ".between" do
      it "returns versions in date range" do
        result = version_class.between(1.hour.ago, 1.hour.from_now)
        # 1 created + 2 updated = 3
        expect(result.count).to eq(3)
      end

      it "returns empty for out-of-range" do
        result = version_class.between(1.day.from_now, 2.days.from_now)
        expect(result.count).to eq(0)
      end
    end

    describe ".recent" do
      it "returns limited recent versions" do
        result = version_class.recent(2)
        expect(result.count).to eq(2)
      end

      it "orders by created_at desc" do
        result = version_class.recent(10)
        expect(result.first.created_at).to be >= result.last.created_at
      end
    end
  end

  describe "instance methods" do
    before do
      ActiveRecord::Base.connection.execute("DELETE FROM article_versions")
      @article = Article.create!(title: "Test", status: "draft")
    end

    describe "#change_for" do
      let(:version) do
        version_class.create!(
          item_type: "Article",
          item_id: @article.id,
          event: "updated",
          object_changes: { "title" => [ "Old Title", "New Title" ], "status" => [ "draft", "published" ] }
        )
      end

      it "returns change hash for field" do
        result = version.change_for(:title)
        expect(result).to eq({ before: "Old Title", after: "New Title" })
      end

      it "returns nil for non-changed field" do
        result = version.change_for(:content)
        expect(result).to be_nil
      end

      it "returns nil when object_changes is nil" do
        version.object_changes = nil
        result = version.change_for(:title)
        expect(result).to be_nil
      end

      it "accepts string field names" do
        result = version.change_for("title")
        expect(result).to eq({ before: "Old Title", after: "New Title" })
      end
    end

    describe "#changed?" do
      let(:version) do
        version_class.create!(
          item_type: "Article",
          item_id: @article.id,
          event: "updated",
          object_changes: { "title" => [ "Old", "New" ] }
        )
      end

      it "returns true for changed field" do
        expect(version.changed?(:title)).to be true
      end

      it "returns false for unchanged field" do
        expect(version.changed?(:status)).to be false
      end

      it "accepts string field names" do
        expect(version.changed?("title")).to be true
      end

      it "returns false when object_changes is nil" do
        version.object_changes = nil
        expect(version.changed?(:title)).to be false
      end

      it "calls super when field_name is nil" do
        # This calls ActiveRecord's changed? method
        expect(version.changed?).to be false
      end
    end

    describe "#changed_fields" do
      let(:version) do
        version_class.create!(
          item_type: "Article",
          item_id: @article.id,
          event: "updated",
          object_changes: { "title" => [ "Old", "New" ], "status" => [ "draft", "published" ] }
        )
      end

      it "returns array of changed field names" do
        expect(version.changed_fields).to contain_exactly("title", "status")
      end

      it "returns empty array when object_changes is nil" do
        version.object_changes = nil
        expect(version.changed_fields).to eq([])
      end
    end
  end
end
