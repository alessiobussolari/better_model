# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Taggable Errors", type: :unit do
  # Use Article which has Taggable properly configured

  describe "TaggableError base class" do
    it "inherits from BetterModelError" do
      expect(BetterModel::Errors::Taggable::TaggableError).to be < BetterModel::Errors::BetterModelError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Taggable::TaggableError.new("taggable issue")
      expect(error.message).to eq("taggable issue")
    end

    it "can be raised and caught" do
      expect do
        raise BetterModel::Errors::Taggable::TaggableError, "test"
      end.to raise_error(BetterModel::Errors::Taggable::TaggableError)
    end

    it "can be caught as BetterModelError" do
      expect do
        raise BetterModel::Errors::Taggable::TaggableError, "test"
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "ConfigurationError" do
    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Taggable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Taggable::ConfigurationError.new("config issue")
      expect(error.message).to eq("config issue")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Taggable::ConfigurationError, "test"
      end.to raise_error(ArgumentError)
    end

    it "does NOT inherit from BetterModelError" do
      expect(BetterModel::Errors::Taggable::ConfigurationError < BetterModel::Errors::BetterModelError).to be_falsy
    end
  end

  describe "Tagging operations with Article" do
    it "allows tagging when properly configured" do
      article = Article.create!(title: "Test", status: "draft")
      article.tag_with("ruby", "rails")

      expect(article.tags).to include("ruby", "rails")
    end

    it "allows checking if tagged with specific tag" do
      article = Article.create!(title: "Test", status: "draft", tags: [ "ruby" ])

      expect(article.tagged_with?("ruby")).to be true
      expect(article.tagged_with?("python")).to be false
    end

    it "allows untagging" do
      article = Article.create!(title: "Test", status: "draft", tags: [ "ruby", "rails" ])
      article.untag("ruby")

      expect(article.tags).not_to include("ruby")
      expect(article.tags).to include("rails")
    end
  end

  describe "Edge cases" do
    it "handles empty tags array" do
      article = Article.create!(title: "Test", status: "draft", tags: [])
      expect(article.tags).to eq([])
    end

    it "handles nil tags" do
      article = Article.new(title: "Test", status: "draft")
      article.tags = nil
      article.save!

      expect(article.tags).to eq([])
    end

    it "normalizes tags on assignment" do
      article = Article.create!(title: "Test", status: "draft")
      article.tag_with("  Ruby  ", "RAILS")

      expect(article.tags).to include("ruby", "rails")
    end

    it "removes duplicate tags" do
      article = Article.create!(title: "Test", status: "draft")
      article.tag_with("ruby", "ruby", "RUBY")

      expect(article.tags.count("ruby")).to eq(1)
    end
  end
end
