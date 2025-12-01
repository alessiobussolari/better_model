# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Traceable Errors", type: :unit do
  # Use Article which has Traceable properly configured

  describe "NotEnabledError" do
    def create_traceable_only_class(name_suffix)
      Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Traceable
        # Traceable is included but not configured
      end.tap do |klass|
        Object.const_set("TraceableOnlyTest#{name_suffix}", klass)
      end
    end

    after do
      Object.constants.grep(/^TraceableOnlyTest/).each do |const|
        Object.send(:remove_const, const)
      end
    end

    it "is raised when calling changed_by without traceable enabled" do
      test_class = create_traceable_only_class("NotEnabled1")

      expect do
        test_class.changed_by(1)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end

    it "is raised when calling changed_between without traceable enabled" do
      test_class = create_traceable_only_class("NotEnabled2")

      expect do
        test_class.changed_between(1.day.ago, Time.current)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end

    it "is raised when calling field_changed without traceable enabled" do
      test_class = create_traceable_only_class("NotEnabled3")

      expect do
        test_class.field_changed(:title)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError)
    end

    it "includes helpful message" do
      test_class = create_traceable_only_class("NotEnabled4")

      begin
        test_class.changed_by(1)
        fail "Expected error to be raised"
      rescue BetterModel::Errors::Traceable::NotEnabledError => e
        expect(e.message).to include("not enabled")
      end
    end

    it "can be caught as TraceableError" do
      test_class = create_traceable_only_class("NotEnabled5")

      expect do
        test_class.changed_by(1)
      end.to raise_error(BetterModel::Errors::Traceable::TraceableError)
    end

    it "can be caught as BetterModelError" do
      test_class = create_traceable_only_class("NotEnabled6")

      expect do
        test_class.changed_by(1)
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "ConfigurationError" do
    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Traceable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Traceable::ConfigurationError.new("config issue")
      expect(error.message).to eq("config issue")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Traceable::ConfigurationError, "test"
      end.to raise_error(ArgumentError)
    end

    it "does NOT inherit from BetterModelError" do
      expect(BetterModel::Errors::Traceable::ConfigurationError < BetterModel::Errors::BetterModelError).to be_falsy
    end
  end

  describe "Version operations with Article" do
    it "tracks versions correctly" do
      article = Article.create!(title: "Test", status: "draft")
      expect(article.versions.count).to eq(1)

      article.update!(title: "Updated")
      expect(article.versions.count).to eq(2)
    end

    it "provides audit trail" do
      article = Article.create!(title: "Test", status: "draft")
      trail = article.audit_trail

      expect(trail).to be_an(Array)
      expect(trail.first[:event]).to eq("created")
    end

    it "tracks changes for specific field" do
      article = Article.create!(title: "Original", status: "draft")
      article.update!(title: "Updated")

      changes = article.changes_for(:title)
      expect(changes.size).to eq(2)
    end

    it "can reconstruct state at timestamp" do
      article = Article.create!(title: "Original", status: "draft")
      timestamp = Time.current
      sleep(0.1)
      article.update!(title: "Updated")

      past_state = article.as_of(timestamp)
      expect(past_state.title).to eq("Original")
    end

    it "can rollback to previous version" do
      article = Article.create!(title: "Original", status: "draft")
      article.update!(title: "Updated")

      version = article.versions.order(created_at: :asc).second
      article.rollback_to(version)

      expect(article.title).to eq("Original")
    end
  end
end
