# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Archivable do
  describe "module inclusion" do
    it "is defined" do
      expect(defined?(BetterModel::Archivable)).to be_truthy
    end

    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Archivable
        end
      end.to raise_error(BetterModel::Errors::Archivable::ConfigurationError, /Invalid configuration/)
    end
  end

  describe "opt-in behavior" do
    it "does not enable archivable by default" do
      test_class = create_archivable_class("ArchivableOptInTest")
      # Don't call archivable

      expect(test_class.archivable_enabled?).to be false
    end

    it "enables archivable when DSL is called" do
      test_class = create_archivable_class("ArchivableEnableTest") do
        archivable
      end

      expect(test_class.archivable_enabled?).to be true
    end

    it "raises error if archived_at column is missing" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "comments" # comments table doesn't have archived_at
        include BetterModel
      end

      expect do
        test_class.class_eval { archivable }
      end.to raise_error(BetterModel::Errors::Archivable::ConfigurationError, /Invalid configuration/)
    end
  end

  describe "predicates and scopes" do
    let(:test_class) do
      create_archivable_class("ArchivablePredicatesTest") do
        archivable
      end
    end

    it "auto-defines predicates on archived_at" do
      expect(test_class).to respond_to(:archived_at_present)
      expect(test_class).to respond_to(:archived_at_null)
      expect(test_class.predicable_field?(:archived_at)).to be true
    end

    it "auto-defines sort on archived_at" do
      expect(test_class).to respond_to(:sort_archived_at_asc)
      expect(test_class).to respond_to(:sort_archived_at_desc)
      expect(test_class.sortable_field?(:archived_at)).to be true
    end

    it "defines archived scope as alias" do
      expect(test_class).to respond_to(:archived)
      expect(test_class.archived.to_sql).to eq(test_class.archived_at_present(true).to_sql)
    end

    it "defines not_archived scope as alias" do
      expect(test_class).to respond_to(:not_archived)
      expect(test_class.not_archived.to_sql).to eq(test_class.archived_at_null(true).to_sql)
    end
  end

  describe "instance methods" do
    let(:test_class) do
      create_archivable_class("ArchivableInstanceTest") do
        archivable
      end
    end

    describe "#archive!" do
      it "sets archived_at" do
        article = test_class.create!(title: "Test")
        article.archive!

        expect(article.archived_at).to be_present
        expect(article.archived?).to be true
      end

      it "raises error if already archived" do
        article = test_class.create!(title: "Test")
        article.archive!

        expect do
          article.archive!
        end.to raise_error(BetterModel::Errors::Archivable::AlreadyArchivedError, /already archived/)
      end

      it "tracks by and reason if columns exist" do
        article = test_class.create!(title: "Test")
        article.archive!(by: 42, reason: "Obsolete")

        expect(article.archived_by_id).to eq(42)
        expect(article.archive_reason).to eq("Obsolete")
      end

      it "handles user object with id method" do
        article = test_class.create!(title: "Test")
        user = Struct.new(:id).new(42)
        article.archive!(by: user)

        expect(article.archived_by_id).to eq(42)
      end
    end

    describe "#restore!" do
      it "clears archived_at" do
        article = test_class.create!(title: "Test")
        article.archive!
        article.restore!

        expect(article.archived_at).to be_nil
        expect(article.archived?).to be false
      end

      it "raises error if not archived" do
        article = test_class.create!(title: "Test")

        expect do
          article.restore!
        end.to raise_error(BetterModel::Errors::Archivable::NotArchivedError, /not archived/)
      end
    end

    describe "#archived?" do
      it "returns correct state" do
        article = test_class.create!(title: "Test")

        expect(article.archived?).to be false
        article.archive!
        expect(article.archived?).to be true
      end
    end

    describe "#active?" do
      it "is opposite of archived?" do
        article = test_class.create!(title: "Test")

        expect(article.active?).to be true
        article.archive!
        expect(article.active?).to be false
      end
    end
  end

  describe "configuration DSL" do
    it "applies default scope with skip_archived_by_default" do
      test_class = create_archivable_class("ArchivableDefaultScopeTest") do
        archivable do
          skip_archived_by_default true
        end
      end

      active = test_class.create!(title: "Active")
      archived = test_class.create!(title: "Archived")
      archived.update_column(:archived_at, Time.current)

      expect(test_class.all.pluck(:id)).to include(active.id)
      expect(test_class.all.pluck(:id)).not_to include(archived.id)
    end

    it "works without block (defaults)" do
      test_class = create_archivable_class("ArchivableDefaultsTest") do
        archivable
      end

      expect(test_class.archivable_enabled?).to be true
    end

    it "provides archived_only scope to bypass default scope" do
      test_class = create_archivable_class("ArchivableOnlyTest") do
        archivable do
          skip_archived_by_default true
        end
      end

      expect(test_class).to respond_to(:archived_only)
    end
  end

  describe "helper methods" do
    let(:test_class) do
      create_archivable_class("ArchivableHelpersTest") do
        archivable
      end
    end

    it "provides convenience methods" do
      expect(test_class).to respond_to(:archived_today)
      expect(test_class).to respond_to(:archived_this_week)
      expect(test_class).to respond_to(:archived_recently)
    end

    it "archived_recently returns a Relation" do
      expect(test_class.archived_recently(7.days)).to be_a(ActiveRecord::Relation)
    end
  end

  describe "integration with searchable" do
    let(:test_class) do
      create_archivable_class("ArchivableSearchTest") do
        archivable
      end
    end

    it "works with searchable predicates" do
      article = test_class.create!(title: "Test", status: "published")
      article.archive!

      results = test_class.search({ archived_at_null: true })
      expect(results.pluck(:id)).not_to include(article.id)

      results = test_class.search({ archived_at_present: true })
      expect(results.pluck(:id)).to include(article.id)
    end
  end

  describe "#as_json" do
    let(:test_class) do
      create_archivable_class("ArchivableJsonTest") do
        archivable
      end
    end

    it "includes archive info when requested" do
      article = test_class.create!(title: "Test")
      article.archive!(by: 42, reason: "Test")

      json = article.as_json(include_archive_info: true)

      expect(json).to have_key("archive_info")
      expect(json["archive_info"]["archived"]).to be true
      expect(json["archive_info"]["archived_at"]).to be_present
      expect(json["archive_info"]["archived_by_id"]).to eq(42)
      expect(json["archive_info"]["archive_reason"]).to eq("Test")
    end
  end

  describe "error classes" do
    it "defines AlreadyArchivedError" do
      expect(defined?(BetterModel::Errors::Archivable::AlreadyArchivedError)).to be_truthy
    end

    it "defines NotArchivedError" do
      expect(defined?(BetterModel::Errors::Archivable::NotArchivedError)).to be_truthy
    end

    it "defines NotEnabledError" do
      expect(defined?(BetterModel::Errors::Archivable::NotEnabledError)).to be_truthy
    end
  end

  describe "NotEnabledError" do
    it "raises when archivable not configured" do
      test_class = create_archivable_class("ArchivableNotEnabledTest")
      # Don't call archivable

      article = test_class.create!(title: "Test")

      expect do
        article.archive!
      end.to raise_error(BetterModel::Errors::Archivable::NotEnabledError, /Module is not enabled/)
    end
  end

  describe "thread safety" do
    let(:test_class) do
      create_archivable_class("ArchivableThreadSafeTest") do
        archivable do
          skip_archived_by_default true
        end
      end
    end

    it "freezes archivable_config" do
      expect(test_class.archivable_config).to be_frozen
    end
  end

  describe "inheritance" do
    let(:parent_class) do
      create_archivable_class("ArchivableParent") do
        archivable do
          skip_archived_by_default true
        end
      end
    end

    it "subclasses inherit archivable config" do
      child = Class.new(parent_class)

      expect(child.archivable_enabled?).to be true
      expect(child.archivable_config).to eq(parent_class.archivable_config)
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Archivable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Archivable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Archivable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Archivable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end
end
