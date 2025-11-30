# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Validatable Module Interactions", type: :integration do
  describe "Validatable + Stateable" do
    it "validatable is enabled on Article" do
      expect(Article.validatable_enabled?).to be true
    end

    it "validation groups are configured correctly" do
      groups = Article.validatable_groups

      expect(groups).to have_key(:basic_info)
      expect(groups).to have_key(:publish_info)
      expect(groups).to have_key(:date_validation)

      expect(groups[:basic_info][:fields]).to include(:title)
      expect(groups[:publish_info][:fields]).to include(:content, :published_at)
      expect(groups[:date_validation][:fields]).to include(:published_at, :expires_at)
    end

    it "validate_group checks only specified fields" do
      article = Article.new(title: nil, status: "draft")

      # Validate basic_info group - Article has no check for title in the group
      # but the mechanism should work
      result = article.validate_group(:basic_info)

      # validate_group runs validators on specified fields
      # Since no `check :title` was added to validatable block, this passes
      expect(result).to be true
    end

    it "errors_for_group filters errors to group fields" do
      article = Article.new(title: nil, status: "draft")

      # Run full validation
      article.valid?

      # Get errors for basic_info group
      basic_errors = article.errors_for_group(:basic_info)

      # Only includes fields from basic_info group
      expect(basic_errors.attribute_names.all? { |a| [ :title ].include?(a) }).to be true
    end

    it "supports multi-step validation workflow" do
      article = Article.new

      # Step 1: Basic info validation
      step1_valid = article.validate_group(:basic_info)
      expect(step1_valid).to be true  # No validators registered for title in group

      # Step 2: Publish info validation
      step2_valid = article.validate_group(:publish_info)
      expect(step2_valid).to be true  # No validators registered for these fields

      # Step 3: Date validation
      step3_valid = article.validate_group(:date_validation)
      expect(step3_valid).to be true
    end
  end

  describe "Validatable + Searchable" do
    before do
      @published = Article.create!(
        title: "Published Article",
        status: "published",
        published_at: Time.current,
        content: "Content here"
      )

      @draft = Article.create!(
        title: "Draft Article",
        status: "draft"
      )
    end

    it "searches records regardless of validation state" do
      results = Article.search({ status_eq: "published" })

      expect(results).to include(@published)
      expect(results).not_to include(@draft)
    end

    it "validation groups can be checked on search results" do
      results = Article.search({ title_cont: "Article" })

      results.each do |article|
        # Each article can be validated with groups
        expect(article.respond_to?(:validate_group)).to be true
        expect(article.validate_group(:basic_info)).to be true
      end
    end

    it "complex validations registered on Article" do
      expect(Article.complex_validation?(:valid_publish_date)).to be true
      expect(Article.complex_validation?(:content_required_for_publish)).to be true
    end
  end

  describe "Complex validations" do
    it "valid_publish_date validates date ordering" do
      # Create article with valid dates (published_at < expires_at)
      valid_article = Article.new(
        title: "Valid Dates",
        status: "draft",
        published_at: 1.day.ago,
        expires_at: 1.day.from_now
      )

      expect(valid_article.valid?).to be true
    end

    it "accepts nil dates without error" do
      article = Article.new(
        title: "No Dates",
        status: "draft",
        published_at: nil,
        expires_at: nil
      )

      expect(article.valid?).to be true
    end

    it "accepts only published_at without expires_at" do
      article = Article.new(
        title: "Published Only",
        status: "published",
        published_at: Time.current,
        expires_at: nil
      )

      expect(article.valid?).to be true
    end

    it "accepts only expires_at without published_at" do
      article = Article.new(
        title: "Expires Only",
        status: "draft",
        published_at: nil,
        expires_at: 1.day.from_now
      )

      expect(article.valid?).to be true
    end
  end

  describe "Validatable + Permissible" do
    it "validation and permissions are independent" do
      article = Article.new(title: "Test", status: "draft")

      # Validation groups work
      expect(article.validate_group(:basic_info)).to be true

      # Permissions also work (based on state)
      article.save!
      expect(article.permit_delete?).to be true
      expect(article.permit_publish?).to be true
    end

    it "permissions dont depend on validation state" do
      article = Article.create!(title: "Permission Test", status: "draft")

      # Has delete permission as draft
      expect(article.permit_delete?).to be true

      # Change to published
      article.update!(status: "published", published_at: Time.current)

      # Permission changed based on state, not validation
      expect(article.permit_delete?).to be false
    end
  end

  describe "Validatable + Taggable" do
    it "validates articles with tags" do
      article = Article.new(
        title: "Tagged Article",
        status: "draft",
        tags: [ "ruby", "rails" ]
      )

      expect(article.validate_group(:basic_info)).to be true
      expect(article.tags).to eq([ "ruby", "rails" ])
    end

    it "tags dont affect validation groups" do
      article = Article.create!(
        title: "Tag Validation",
        status: "draft",
        tags: []
      )

      article.tag_with("new-tag")

      # Validation still works
      expect(article.validate_group(:basic_info)).to be true
      expect(article.tags).to include("new-tag")
    end
  end

  describe "Validatable + Traceable" do
    it "tracks changes and validates independently" do
      article = Article.create!(
        title: "Tracked Validated",
        status: "draft"
      )

      # Has versions from traceable
      expect(article.versions.count).to eq(1)

      # Validation works
      expect(article.validate_group(:basic_info)).to be true

      # Update creates new version
      article.update!(title: "Updated Title")
      expect(article.versions.count).to eq(2)

      # Validation still works
      expect(article.validate_group(:basic_info)).to be true
    end
  end

  describe "Error handling" do
    it "handles unknown validation group gracefully" do
      article = Article.new(title: "Test")

      # Unknown group returns false
      result = article.validate_group(:nonexistent_group)
      expect(result).to be false
    end

    it "models without validatable dont have validate_group method" do
      # Author model doesnt have validatable enabled
      author = Author.new(name: "Test")

      # Without validatable module, the method doesnt exist
      expect(author.respond_to?(:validate_group)).to be false
    end
  end

  describe "Edge cases" do
    it "validates new unsaved records" do
      article = Article.new(title: "New Article", status: "draft")

      expect(article.validate_group(:basic_info)).to be true
    end

    it "validates persisted records" do
      article = Article.create!(title: "Persisted", status: "draft")

      expect(article.validate_group(:basic_info)).to be true
    end

    it "can run validation groups multiple times" do
      article = Article.new(title: "Multiple", status: "draft")

      3.times do
        expect(article.validate_group(:basic_info)).to be true
      end
    end

    it "validates with different groups sequentially" do
      article = Article.new(
        title: "Sequential",
        status: "draft",
        content: "Content",
        published_at: Time.current
      )

      expect(article.validate_group(:basic_info)).to be true
      expect(article.validate_group(:publish_info)).to be true
      expect(article.validate_group(:date_validation)).to be true
    end
  end
end
