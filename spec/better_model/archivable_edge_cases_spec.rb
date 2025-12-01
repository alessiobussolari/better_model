# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Archivable, "edge cases", type: :model do
  # Helper to create test classes
  def create_archivable_class(name_suffix, &block)
    const_name = "ArchivableEdgeTest#{name_suffix}"
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
    Object.constants.grep(/^ArchivableEdgeTest/).each do |const|
      Object.send(:remove_const, const) rescue nil
    end
  end

  describe "configuration edge cases" do
    it "allows archivable without configuration block" do
      test_class = create_archivable_class("NoConfig") do
        archivable
      end

      expect(test_class.archivable_enabled?).to be true
    end

    it "allows skip_archived_by_default option" do
      test_class = create_archivable_class("SkipArchived") do
        archivable do
          skip_archived_by_default true
        end
      end

      # Create archived and non-archived articles
      active = test_class.create!(title: "Active", status: "draft")
      archived = test_class.create!(title: "Archived", status: "draft", archived_at: Time.current)

      # Default scope should hide archived
      expect(test_class.all.count).to eq(1)
      expect(test_class.unscoped.count).to eq(2)
    end
  end

  describe "archive! edge cases" do
    let(:test_class) do
      create_archivable_class("ArchiveEdge") do
        archivable
      end
    end

    it "sets archived_at timestamp" do
      article = test_class.create!(title: "Test", status: "draft")
      before_archive = Time.current

      article.archive!(reason: "Test reason")

      expect(article.archived_at).to be >= before_archive
      expect(article.archived_at).to be <= Time.current
    end

    it "stores archive reason" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "Content policy violation")

      expect(article.archive_reason).to eq("Content policy violation")
    end

    it "raises AlreadyArchivedError when archiving archived record" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "First")

      expect do
        article.archive!(reason: "Second")
      end.to raise_error(BetterModel::Errors::Archivable::AlreadyArchivedError)
    end

    it "archives without reason" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!

      expect(article.archived?).to be true
      expect(article.archive_reason).to be_nil
    end
  end

  describe "restore! edge cases" do
    let(:test_class) do
      create_archivable_class("RestoreEdge") do
        archivable
      end
    end

    it "clears archived_at timestamp" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "Test")
      article.restore!

      expect(article.archived_at).to be_nil
    end

    it "clears archive reason" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "Test reason")
      article.restore!

      expect(article.archive_reason).to be_nil
    end

    it "raises NotArchivedError when restoring non-archived record" do
      article = test_class.create!(title: "Test", status: "draft")

      expect do
        article.restore!
      end.to raise_error(BetterModel::Errors::Archivable::NotArchivedError)
    end

    it "allows re-archiving after restore" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "First")
      article.restore!
      article.archive!(reason: "Second")

      expect(article.archived?).to be true
      expect(article.archive_reason).to eq("Second")
    end
  end

  describe "archived? edge cases" do
    let(:test_class) do
      create_archivable_class("ArchivedCheck") do
        archivable
      end
    end

    it "returns false for new records" do
      article = test_class.new(title: "Test", status: "draft")
      expect(article.archived?).to be false
    end

    it "returns false for non-archived records" do
      article = test_class.create!(title: "Test", status: "draft")
      expect(article.archived?).to be false
    end

    it "returns true for archived records" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!
      expect(article.archived?).to be true
    end

    it "returns false when archivable not enabled" do
      non_archivable = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Archivable
      end

      article = non_archivable.create!(title: "Test", status: "draft")
      expect(article.archived?).to be false
    end
  end

  describe "scope edge cases" do
    let(:test_class) do
      create_archivable_class("ScopeEdge") do
        archivable
      end
    end

    before do
      @active1 = test_class.create!(title: "Active 1", status: "draft")
      @active2 = test_class.create!(title: "Active 2", status: "draft")
      @archived = test_class.create!(title: "Archived", status: "draft")
      @archived.archive!(reason: "Test")
    end

    it "provides archived scope" do
      expect(test_class.archived.count).to eq(1)
      expect(test_class.archived.first).to eq(@archived)
    end

    it "provides not_archived scope" do
      expect(test_class.not_archived.count).to eq(2)
      expect(test_class.not_archived).to include(@active1, @active2)
    end

    it "provides archived_at_between predicate scope" do
      # Use the predicate scope (not archived_between which doesn't exist)
      expect(test_class.archived_at_between(1.hour.ago, 1.hour.from_now).count).to eq(1)
    end

    it "archived_at_between returns empty for out-of-range" do
      expect(test_class.archived_at_between(1.day.from_now, 2.days.from_now).count).to eq(0)
    end
  end

  describe "enabled check edge cases" do
    it "returns false for archivable_enabled? when not configured" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
      end

      expect(klass.archivable_enabled?).to be false
    end

    it "returns true for archivable_enabled? when configured" do
      test_class = create_archivable_class("EnabledCheck") do
        archivable
      end

      expect(test_class.archivable_enabled?).to be true
    end

    it "raises NotEnabledError when calling archive! without archivable" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Archivable
      end

      article = klass.create!(title: "Test", status: "draft")

      expect do
        article.archive!(reason: "Test")
      end.to raise_error(BetterModel::Errors::Archivable::NotEnabledError)
    end
  end

  describe "persistence edge cases" do
    let(:test_class) do
      create_archivable_class("PersistenceEdge") do
        archivable
      end
    end

    it "persists archive state to database" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "Test")

      reloaded = test_class.find(article.id)
      expect(reloaded.archived?).to be true
      expect(reloaded.archive_reason).to eq("Test")
    end

    it "persists restore state to database" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "Test")
      article.restore!

      reloaded = test_class.find(article.id)
      expect(reloaded.archived?).to be false
    end
  end

  describe "archive with metadata" do
    let(:test_class) do
      create_archivable_class("MetadataEdge") do
        archivable
      end
    end

    it "allows archiving with reason" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "Spam content detected")

      expect(article.archive_reason).to eq("Spam content detected")
    end

    it "allows updating reason on re-archive" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "First reason")
      article.restore!
      article.archive!(reason: "Second reason")

      expect(article.archive_reason).to eq("Second reason")
    end
  end

  describe "default scope with skip_archived" do
    it "includes all records when skip_archived_by_default is false" do
      test_class = create_archivable_class("NoSkip") do
        archivable do
          skip_archived_by_default false
        end
      end

      active = test_class.create!(title: "Active", status: "draft")
      archived = test_class.create!(title: "Archived", status: "draft", archived_at: Time.current)

      expect(test_class.all.count).to eq(2)
    end

    it "excludes archived when skip_archived_by_default is true" do
      test_class = create_archivable_class("WithSkip") do
        archivable do
          skip_archived_by_default true
        end
      end

      active = test_class.create!(title: "Active", status: "draft")
      archived = test_class.create!(title: "Archived", status: "draft", archived_at: Time.current)

      expect(test_class.all.count).to eq(1)
      expect(test_class.all.first.title).to eq("Active")
    end
  end

  describe "archived_only class method" do
    let(:test_class) do
      create_archivable_class("ArchivedOnly") do
        archivable do
          skip_archived_by_default true
        end
      end
    end

    it "returns only archived records, bypassing default scope" do
      active = test_class.create!(title: "Active", status: "draft")
      archived = test_class.create!(title: "Archived", status: "draft")
      archived.archive!

      result = test_class.archived_only
      expect(result.count).to eq(1)
      expect(result.first).to eq(archived)
    end
  end

  describe "helper methods" do
    let(:test_class) do
      create_archivable_class("Helpers") do
        archivable
      end
    end

    it "provides archived_recently helper" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!

      expect(test_class.archived_recently(7.days).count).to eq(1)
    end

    it "provides archived_within predicate scope" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!

      expect(test_class.archived_at_within(1.day).count).to eq(1)
      expect(test_class.archived_at_within(1.day).first).to eq(article)
    end

    it "archived_at_within returns empty for articles archived earlier" do
      article = test_class.create!(title: "Test", status: "draft")
      article.update_column(:archived_at, 2.weeks.ago)

      # Should not find articles archived more than 1 day ago
      expect(test_class.archived_at_within(1.day).count).to eq(0)
    end

    it "archived_at_within accepts numeric value (days)" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!

      # Numeric value is treated as days
      expect(test_class.archived_at_within(7).count).to eq(1)
    end
  end

  describe "as_json with archive info" do
    let(:test_class) do
      create_archivable_class("AsJson") do
        archivable
      end
    end

    it "includes archive_info when option is set" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!(reason: "Test reason")

      json = article.as_json(include_archive_info: true)
      expect(json["archive_info"]).to be_a(Hash)
      expect(json["archive_info"]["archived"]).to eq(true)
      expect(json["archive_info"]["archive_reason"]).to eq("Test reason")
    end

    it "does not include archive_info by default" do
      article = test_class.create!(title: "Test", status: "draft")

      json = article.as_json
      expect(json).not_to have_key("archive_info")
    end
  end

  describe "active? method" do
    let(:test_class) do
      create_archivable_class("ActiveMethod") do
        archivable
      end
    end

    it "returns true for non-archived records" do
      article = test_class.create!(title: "Test", status: "draft")
      expect(article.active?).to be true
    end

    it "returns false for archived records" do
      article = test_class.create!(title: "Test", status: "draft")
      article.archive!
      expect(article.active?).to be false
    end
  end
end
