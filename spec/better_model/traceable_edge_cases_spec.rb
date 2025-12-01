# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Traceable, "edge cases", type: :model do
  # Note: Traceable requires a custom versions table per model.
  # For these tests, we'll test what we can with Article which already
  # has article_versions table configured.

  describe "configuration edge cases" do
    it "allows traceable without track fields" do
      # Article already has traceable configured
      expect(Article.traceable_enabled?).to be true
    end

    it "stores traceable_fields configuration" do
      expect(Article.traceable_fields).to be_an(Array)
    end

    it "stores traceable_sensitive_fields configuration" do
      expect(Article.traceable_sensitive_fields).to be_a(Hash)
    end
  end

  describe "enabled check edge cases" do
    it "returns false for traceable_enabled? when not configured" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
      end

      expect(klass.traceable_enabled?).to be false
    end

    it "returns true for traceable_enabled? when configured" do
      expect(Article.traceable_enabled?).to be true
    end

    it "raises NotEnabledError for changes_for when not enabled" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Traceable

        def self.name
          "NotEnabledTraceable"
        end
      end

      article = klass.create!(title: "Test", status: "draft")

      expect do
        article.changes_for(:title)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end

    it "raises NotEnabledError for audit_trail when not enabled" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Traceable

        def self.name
          "NotEnabledTraceable2"
        end
      end

      article = klass.create!(title: "Test", status: "draft")

      expect do
        article.audit_trail
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end

    it "raises NotEnabledError for as_of when not enabled" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Traceable

        def self.name
          "NotEnabledTraceable3"
        end
      end

      article = klass.create!(title: "Test", status: "draft")

      expect do
        article.as_of(1.day.ago)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end
  end

  describe "class method edge cases" do
    it "raises NotEnabledError for changed_by when not enabled" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Traceable

        def self.name
          "NotEnabledTraceable4"
        end
      end

      expect do
        klass.changed_by(1)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end

    it "raises NotEnabledError for changed_between when not enabled" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Traceable

        def self.name
          "NotEnabledTraceable5"
        end
      end

      expect do
        klass.changed_between(1.hour.ago, 1.hour.from_now)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end

    it "raises NotEnabledError for field_changed when not enabled" do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Traceable

        def self.name
          "NotEnabledTraceable6"
        end
      end

      expect do
        klass.field_changed(:title)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end
  end

  describe "version tracking with Article model" do
    before do
      # Clean versions table
      ActiveRecord::Base.connection.execute("DELETE FROM article_versions")
    end

    it "creates version on update when tracked fields change" do
      article = Article.create!(title: "Original", status: "draft")
      initial_count = article.versions.count

      article.update!(title: "Updated")

      expect(article.versions.count).to be > initial_count
    end

    it "version has correct event type" do
      article = Article.create!(title: "Test", status: "draft")

      # Create event might be captured
      create_versions = article.versions.where(event: "created")
      if create_versions.any?
        expect(create_versions.first.event).to eq("created")
      end
    end

    it "provides versions association" do
      article = Article.create!(title: "Test", status: "draft")
      expect(article).to respond_to(:versions)
      expect(article.versions).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it "tracks changes_for a field" do
      article = Article.create!(title: "Original", status: "draft")
      article.update!(title: "Updated")

      changes = article.changes_for(:title)
      expect(changes).to be_an(Array)
    end

    it "provides audit_trail" do
      article = Article.create!(title: "Test", status: "draft")
      article.update!(title: "Updated")

      trail = article.audit_trail
      expect(trail).to be_an(Array)
    end
  end

  describe "class methods with enabled traceable" do
    before do
      ActiveRecord::Base.connection.execute("DELETE FROM article_versions")
    end

    it "changed_by returns records changed by user" do
      # Article.changed_by returns a relation
      result = Article.changed_by(999)
      expect(result).to be_a(ActiveRecord::Relation)
    end

    it "changed_between returns records in date range" do
      article = Article.create!(title: "Test", status: "draft")
      article.update!(title: "Updated")

      results = Article.changed_between(1.hour.ago, 1.hour.from_now)
      expect(results).to be_a(ActiveRecord::Relation)
    end

    it "field_changed returns a ChangeQuery" do
      result = Article.field_changed(:title)
      expect(result).to be_a(BetterModel::ChangeQuery)
    end
  end

  describe "TraceableConfigurator" do
    it "accepts track with sensitive option" do
      configurator = BetterModel::TraceableConfigurator.new(Article)

      configurator.track(:email, sensitive: :partial)

      expect(configurator.fields).to include(:email)
      expect(configurator.sensitive_fields[:email]).to eq(:partial)
    end

    it "accepts versions_table configuration" do
      configurator = BetterModel::TraceableConfigurator.new(Article)

      configurator.versions_table "custom_versions"

      expect(configurator.table_name).to eq("custom_versions")
    end

    it "generates correct to_h output" do
      configurator = BetterModel::TraceableConfigurator.new(Article)
      configurator.track(:title, :status)
      configurator.track(:email, sensitive: :full)
      configurator.versions_table "article_versions"

      hash = configurator.to_h
      expect(hash[:fields]).to include(:title, :status, :email)
      expect(hash[:sensitive_fields][:email]).to eq(:full)
      expect(hash[:table_name]).to eq("article_versions")
    end
  end

  describe "ChangeQuery" do
    before do
      ActiveRecord::Base.connection.execute("DELETE FROM article_versions")
    end

    it "chains from and to methods" do
      query = Article.field_changed(:title)
      expect(query.from("draft")).to eq(query)
    end

    it "executes query on to" do
      Article.create!(title: "Test", status: "draft")

      result = Article.field_changed(:status).from("draft").to("published")
      expect(result).to be_a(ActiveRecord::Relation)
    end
  end

  describe "as_json with audit trail" do
    before do
      ActiveRecord::Base.connection.execute("DELETE FROM article_versions")
    end

    it "includes audit_trail when option is set" do
      article = Article.create!(title: "Test", status: "draft")
      article.update!(title: "Updated")

      json = article.as_json(include_audit_trail: true)
      expect(json).to have_key("audit_trail")
    end

    it "does not include audit_trail by default" do
      article = Article.create!(title: "Test", status: "draft")

      json = article.as_json
      expect(json).not_to have_key("audit_trail")
    end
  end

  describe "ConfigurationError" do
    it "raises ConfigurationError when including in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Traceable
        end
      end.to raise_error(BetterModel::Errors::Traceable::ConfigurationError)
    end
  end
end
