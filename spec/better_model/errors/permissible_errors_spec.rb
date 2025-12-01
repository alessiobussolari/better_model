# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Permissible Errors", type: :unit do
  # Article has Permissible configured with:
  # permit :delete, -> { is?(:draft) }
  # permit :edit, -> { is?(:draft) || (is?(:published) && !is?(:expired)) }
  # permit :publish, -> { is?(:draft) }
  # permit :unpublish, -> { is?(:published) }
  # permit :archive, -> { is?(:published) && created_at < 1.year.ago }

  describe "PermissibleError base class" do
    it "inherits from BetterModelError" do
      expect(BetterModel::Errors::Permissible::PermissibleError).to be < BetterModel::Errors::BetterModelError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Permissible::PermissibleError.new("permission issue")
      expect(error.message).to eq("permission issue")
    end

    it "can be raised and caught" do
      expect do
        raise BetterModel::Errors::Permissible::PermissibleError, "test"
      end.to raise_error(BetterModel::Errors::Permissible::PermissibleError)
    end

    it "can be caught as BetterModelError" do
      expect do
        raise BetterModel::Errors::Permissible::PermissibleError, "test"
      end.to raise_error(BetterModel::Errors::BetterModelError)
    end
  end

  describe "ConfigurationError" do
    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Permissible::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Permissible::ConfigurationError.new("config issue")
      expect(error.message).to eq("config issue")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Permissible::ConfigurationError, "test"
      end.to raise_error(ArgumentError)
    end

    it "does NOT inherit from BetterModelError" do
      expect(BetterModel::Errors::Permissible::ConfigurationError < BetterModel::Errors::BetterModelError).to be_falsy
    end

    it "is raised when permission name is blank" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit "", -> { true }
        end
      end.to raise_error(BetterModel::Errors::Permissible::ConfigurationError, /blank/)
    end

    it "is raised when no condition is provided" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :something
        end
      end.to raise_error(BetterModel::Errors::Permissible::ConfigurationError, /required/)
    end

    it "is raised when condition is not callable" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Permissible
          permit :something, "not a proc"
        end
      end.to raise_error(BetterModel::Errors::Permissible::ConfigurationError, /call/)
    end
  end

  describe "Permission checks with Article" do
    it "evaluates permission correctly for draft status" do
      article = Article.create!(title: "Draft", status: "draft")

      expect(article.permit_delete?).to be true
      expect(article.permit_edit?).to be true
      expect(article.permit_publish?).to be true
    end

    it "evaluates permission correctly for published status" do
      article = Article.create!(
        title: "Published",
        status: "published",
        published_at: Time.current
      )

      expect(article.permit_delete?).to be false
      expect(article.permit_publish?).to be false
      expect(article.permit_unpublish?).to be true
    end

    it "handles complex conditions" do
      old_article = Article.create!(
        title: "Old",
        status: "published",
        published_at: 2.years.ago,
        created_at: 2.years.ago
      )

      recent_article = Article.create!(
        title: "Recent",
        status: "published",
        published_at: 1.day.ago,
        created_at: 1.day.ago
      )

      expect(old_article.permit_archive?).to be true
      expect(recent_article.permit_archive?).to be false
    end
  end

  describe "Edge cases" do
    it "returns false for undefined permissions via permit?" do
      article = Article.create!(title: "Test", status: "draft")

      expect(article.permit?(:nonexistent_permission)).to be false
    end

    it "handles permit? method for defined permissions" do
      article = Article.create!(title: "Test", status: "draft")

      expect(article.permit?(:delete)).to eq(article.permit_delete?)
      expect(article.permit?(:edit)).to eq(article.permit_edit?)
    end
  end
end
