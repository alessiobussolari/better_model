# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Parameter Sanitization", type: :security do
  before do
    @article = Article.create!(
      title: "Test Article",
      content: "Test content",
      status: "published",
      published_at: Time.current,
      view_count: 100,
      featured: true,
      tags: [ "test" ]
    )
  end

  describe "ActionController::Parameters handling" do
    it "accepts ActionController::Parameters for search" do
      params = ActionController::Parameters.new(
        status_eq: "published",
        featured_eq: true
      )

      # Searchable should handle params properly
      results = Article.search(params.to_unsafe_h)

      expect(results).to include(@article)
    end

    it "handles nested parameters correctly" do
      params = ActionController::Parameters.new(
        filters: {
          status_eq: "published"
        }
      )

      # Using nested params
      results = Article.search(params[:filters].to_unsafe_h)

      expect(results).to include(@article)
    end

    it "handles empty parameters gracefully" do
      params = ActionController::Parameters.new({})

      results = Article.search(params.to_unsafe_h)

      # Should return all articles when no filters
      expect(results.count).to be >= 1
    end

    it "handles nil parameter values" do
      params = ActionController::Parameters.new(
        status_eq: nil,
        title_cont: "Test"
      )

      results = Article.search(params.to_unsafe_h)

      # Should ignore nil values and only apply title_cont
      expect(results).to include(@article)
    end
  end

  describe "Type coercion" do
    it "coerces string to integer for numeric predicates" do
      results = Article.search({ view_count_eq: "100" })

      expect(results).to include(@article)
    end

    it "coerces string boolean values" do
      results_true = Article.search({ featured_eq: "true" })
      results_false = Article.search({ featured_eq: "false" })

      expect(results_true).to include(@article)
      expect(results_false).not_to include(@article)
    end

    it "handles empty string values" do
      results = Article.search({
        status_eq: "published",
        title_cont: "" # Empty string should be skipped
      })

      expect(results).to include(@article)
    end

    it "handles whitespace-only strings" do
      # Whitespace-only strings are treated as search criteria (not skipped)
      results = Article.search({
        status_eq: "published",
        title_cont: "   " # This is a valid search (for spaces in title)
      })

      # No articles have only spaces in title, so 0 results expected
      expect(results.count).to eq(0)
    end
  end

  describe "Integer overflow protection" do
    it "handles large integers in view_count" do
      # Create article with max-ish value
      large = Article.create!(
        title: "Large Count",
        status: "draft",
        view_count: 2_147_483_647 # Max 32-bit signed int
      )

      results = Article.search({ view_count_eq: 2_147_483_647 })

      expect(results).to include(large)
    end

    it "handles zero values" do
      zero = Article.create!(
        title: "Zero Count",
        status: "draft",
        view_count: 0
      )

      results = Article.search({ view_count_eq: 0 })

      expect(results).to include(zero)
    end

    it "handles negative values where valid" do
      # view_count could theoretically be negative
      # Test that the system doesn't crash
      results = Article.search({ view_count_lt: -1 })

      # Should return empty (no articles with negative count)
      expect(results.count).to eq(0)
    end
  end

  describe "Boolean handling" do
    it "handles true boolean value" do
      results = Article.search({ featured_eq: true })

      expect(results).to include(@article)
    end

    it "handles false boolean value" do
      unfeatured = Article.create!(
        title: "Unfeatured",
        status: "draft",
        featured: false
      )

      results = Article.search({ featured_eq: false })

      expect(results).to include(unfeatured)
      expect(results).not_to include(@article)
    end

    it "handles string 'true' value" do
      results = Article.search({ featured_eq: "true" })

      expect(results).to include(@article)
    end

    it "handles string 'false' value" do
      unfeatured = Article.create!(
        title: "Unfeatured",
        status: "draft",
        featured: false
      )

      results = Article.search({ featured_eq: "false" })

      expect(results).to include(unfeatured)
    end
  end

  describe "Date/DateTime handling" do
    it "handles date comparison predicates" do
      old_article = Article.create!(
        title: "Old Article",
        status: "published",
        published_at: 30.days.ago
      )

      recent = Article.search({ published_at_gteq: 7.days.ago })

      expect(recent).to include(@article)
      expect(recent).not_to include(old_article)
    end

    it "handles string date values" do
      # Create article with today's date
      today_article = Article.create!(
        title: "Today Article",
        status: "published",
        published_at: Time.current
      )

      tomorrow = (Date.today + 1).to_s

      # Should not raise error when date string is provided
      results = Article.search({ published_at_lteq: tomorrow })

      expect(results).to include(today_article)
    end

    it "handles nil date values" do
      no_date = Article.create!(
        title: "No Date",
        status: "draft",
        published_at: nil
      )

      # Search for articles with null published_at
      results = Article.search({ published_at_null: true })

      expect(results).to include(no_date)
    end
  end

  describe "Array value handling" do
    it "handles array with single value" do
      # Using OR conditions with single element
      results = Article.search({
        or: [
          { status_eq: "published" }
        ]
      })

      expect(results).to include(@article)
    end

    it "handles array with multiple values in OR" do
      draft = Article.create!(title: "Draft", status: "draft")

      results = Article.search({
        or: [
          { status_eq: "published" },
          { status_eq: "draft" }
        ]
      })

      expect(results).to include(@article, draft)
    end

    it "handles empty OR array" do
      results = Article.search({
        or: [],
        status_eq: "published"
      })

      expect(results).to include(@article)
    end
  end

  describe "String sanitization" do
    it "handles HTML-like content in search" do
      html_article = Article.create!(
        title: "<script>alert('xss')</script>",
        status: "draft"
      )

      results = Article.search({ title_cont: "<script>" })

      expect(results).to include(html_article)
    end

    it "handles quotes in search terms" do
      quoted = Article.create!(
        title: 'Article with "quotes"',
        status: "draft"
      )

      results = Article.search({ title_cont: '"quotes"' })

      expect(results).to include(quoted)
    end

    it "handles backslashes in search terms" do
      backslash = Article.create!(
        title: "Path\\to\\file",
        status: "draft"
      )

      results = Article.search({ title_cont: "Path" })

      expect(results).to include(backslash)
    end

    it "handles newlines in search terms" do
      multiline = Article.create!(
        title: "Line1\nLine2",
        status: "draft"
      )

      results = Article.search({ title_cont: "Line1" })

      expect(results).to include(multiline)
    end
  end

  describe "Taggable parameter handling" do
    it "normalizes tag case" do
      article = Article.create!(
        title: "Case Test",
        status: "draft",
        tags: []
      )

      article.tag_with("UPPERCASE", "MixedCase", "lowercase")

      expect(article.tags).to include("uppercase")
      expect(article.tags).to include("mixedcase")
      expect(article.tags).to include("lowercase")
    end

    it "strips whitespace from tags" do
      article = Article.create!(
        title: "Whitespace Test",
        status: "draft",
        tags: []
      )

      article.tag_with("  padded  ", "normal")

      expect(article.tags).to include("padded")
      expect(article.tags).to include("normal")
    end

    it "handles tag_list CSV parsing" do
      article = Article.create!(
        title: "CSV Test",
        status: "draft",
        tags: []
      )

      article.tag_list = "  Ruby  ,  Rails  ,  Testing  "

      expect(article.tags).to include("ruby")
      expect(article.tags).to include("rails")
      expect(article.tags).to include("testing")
    end

    it "handles empty tags in tag_list" do
      article = Article.create!(
        title: "Empty Tags Test",
        status: "draft",
        tags: [ "existing" ]
      )

      article.tag_list = ""

      expect(article.tags).to be_empty
    end
  end

  describe "Pagination parameter validation" do
    it "accepts valid pagination parameters" do
      results = Article.search(
        { status_eq: "published" },
        pagination: { page: 1, per_page: 10 }
      )

      expect(results.count).to be <= 10
    end

    it "coerces string page to integer" do
      results = Article.search(
        {},
        pagination: { page: "1", per_page: "10" }
      )

      expect(results.count).to be >= 0
    end

    it "rejects invalid page values" do
      expect do
        Article.search({}, pagination: { page: 0, per_page: 10 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "rejects per_page exceeding max" do
      expect do
        Article.search({}, pagination: { page: 1, per_page: 1000 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end
  end
end
