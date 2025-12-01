# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Archivable Errors", type: :unit do
  # Use Article which has all modules properly configured

  describe "AlreadyArchivedError" do
    it "is raised when archiving already archived record" do
      article = Article.create!(title: "Test", status: "draft")
      article.archive!(reason: "First archive")

      expect do
        article.archive!(reason: "Second archive")
      end.to raise_error(BetterModel::Errors::Archivable::AlreadyArchivedError)
    end

    it "includes error message" do
      article = Article.create!(title: "Test", status: "draft")
      article.archive!(reason: "First")

      begin
        article.archive!(reason: "Second")
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as ArchivableError" do
      article = Article.create!(title: "Test", status: "draft")
      article.archive!(reason: "First")

      expect do
        article.archive!(reason: "Second")
      end.to raise_error(BetterModel::Errors::Archivable::ArchivableError)
    end

    it "can be caught as BetterModelError" do
      article = Article.create!(title: "Test", status: "draft")
      article.archive!(reason: "First")

      expect do
        article.archive!(reason: "Second")
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "NotArchivedError" do
    it "is raised when restoring non-archived record" do
      article = Article.create!(title: "Test", status: "draft")

      expect do
        article.restore!
      end.to raise_error(BetterModel::Errors::Archivable::NotArchivedError)
    end

    it "is raised when restoring already restored record" do
      article = Article.create!(title: "Test", status: "draft")
      article.archive!(reason: "Archive")
      article.restore!

      expect do
        article.restore!
      end.to raise_error(BetterModel::Errors::Archivable::NotArchivedError)
    end

    it "includes error message" do
      article = Article.create!(title: "Test", status: "draft")

      begin
        article.restore!
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Archivable::NotArchivedError => e
        expect(e.message).to be_present
      end
    end

    it "can be caught as ArchivableError" do
      article = Article.create!(title: "Test", status: "draft")

      expect do
        article.restore!
      end.to raise_error(BetterModel::Errors::Archivable::ArchivableError)
    end

    it "can be caught as BetterModelError" do
      article = Article.create!(title: "Test", status: "draft")

      expect do
        article.restore!
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "NotEnabledError" do
    def create_archivable_only_class(name_suffix)
      Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Archivable
        # Archivable is included but not configured with archivable block
      end.tap do |klass|
        Object.const_set("ArchivableOnlyTest#{name_suffix}", klass)
      end
    end

    after do
      Object.constants.grep(/^ArchivableOnlyTest/).each do |const|
        Object.send(:remove_const, const)
      end
    end

    it "is raised when calling archive! without archivable enabled" do
      test_class = create_archivable_only_class("NotEnabled1")
      article = test_class.create!(title: "Test", status: "draft")

      expect do
        article.archive!(reason: "Test")
      end.to raise_error(BetterModel::Errors::Archivable::NotEnabledError)
    end

    it "is raised when calling restore! without archivable enabled" do
      test_class = create_archivable_only_class("NotEnabled2")
      article = test_class.create!(title: "Test", status: "draft")

      expect do
        article.restore!
      end.to raise_error(BetterModel::Errors::Archivable::NotEnabledError)
    end

    it "archived? returns false when archivable not enabled instead of raising" do
      test_class = create_archivable_only_class("NotEnabled3")
      article = test_class.create!(title: "Test", status: "draft")

      # archived? doesn't raise - it returns false when not enabled
      expect(article.archived?).to be false
    end

    it "includes helpful message" do
      test_class = create_archivable_only_class("NotEnabled4")
      article = test_class.create!(title: "Test", status: "draft")

      begin
        article.archive!(reason: "Test")
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Archivable::NotEnabledError => e
        expect(e.message).to include("not enabled")
      end
    end

    it "can be caught as ArchivableError" do
      test_class = create_archivable_only_class("NotEnabled5")
      article = test_class.create!(title: "Test", status: "draft")

      expect do
        article.archive!
      end.to raise_error(BetterModel::Errors::Archivable::ArchivableError)
    end
  end

  describe "ConfigurationError" do
    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Archivable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Archivable::ConfigurationError.new("config issue")
      expect(error.message).to eq("config issue")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Archivable::ConfigurationError, "test"
      end.to raise_error(ArgumentError)
    end
  end
end
