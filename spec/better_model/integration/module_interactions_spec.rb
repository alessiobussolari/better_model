# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Module Interactions", type: :integration do
  describe "Searchable + Predicable + Sortable" do
    before do
      @article1 = Article.create!(
        title: "Ruby Programming",
        content: "Learn Ruby basics",
        status: "published",
        published_at: 3.days.ago,
        view_count: 200
      )

      @article2 = Article.create!(
        title: "Rails Development",
        content: "Build web apps",
        status: "published",
        published_at: 1.day.ago,
        view_count: 100
      )

      @article3 = Article.create!(
        title: "Testing Guide",
        content: "Write better tests",
        status: "draft",
        view_count: 50
      )
    end

    it "combines predicates and sorting" do
      results = Article.search(
        { status_eq: "published" },
        orders: [ :sort_view_count_desc ]
      )

      expect(results.first).to eq(@article1)
      expect(results.last).to eq(@article2)
    end

    it "applies multiple predicates with sorting" do
      results = Article.search(
        { status_eq: "published", view_count_gteq: 100 },
        orders: [ :sort_title_asc ]
      )

      expect(results.count).to eq(2)
      expect(results.first).to eq(@article2) # "Rails" comes before "Ruby"
    end

    it "uses predicates with pagination and sorting" do
      results = Article.search(
        { status_eq: "published" },
        orders: [ :sort_view_count_desc ],
        pagination: { page: 1, per_page: 1 }
      )

      expect(results.count).to eq(1)
      expect(results.first).to eq(@article1) # Highest view count
    end

    it "chains multiple sort fields" do
      @article4 = Article.create!(
        title: "Advanced Ruby",
        content: "Deep dive",
        status: "published",
        published_at: 2.days.ago,
        view_count: 200 # Same as @article1
      )

      results = Article.search(
        { status_eq: "published" },
        orders: [ :sort_view_count_desc, :sort_title_asc ]
      )

      # Both articles with view_count 200 should be first, sorted by title
      expect(results.first).to eq(@article4) # "Advanced Ruby" before "Ruby Programming"
    end
  end

  describe "Stateable + Permissible" do
    let(:author) { Author.create!(name: "Test Author") }

    it "permissions reflect status changes" do
      article = Article.create!(
        title: "State Permission Test",
        status: "draft",
        author: author
      )

      # Draft state
      expect(article.is_draft?).to be true
      expect(article.permit_delete?).to be true
      expect(article.permit_publish?).to be true
      expect(article.permit_unpublish?).to be false

      # Transition to published
      article.update!(status: "published", published_at: Time.current)

      # Published state
      expect(article.is_published?).to be true
      expect(article.permit_delete?).to be false
      expect(article.permit_publish?).to be false
      expect(article.permit_unpublish?).to be true
    end

    it "complex status affects permissions" do
      article = Article.create!(
        title: "Complex State Test",
        status: "published",
        published_at: 1.year.ago, # Old article
        expires_at: 1.day.ago, # Expired
        author: author
      )

      expect(article.is_expired?).to be true
      expect(article.is_active?).to be false

      # Edit permissions should be affected by expired status
      expect(article.permit_edit?).to be false
    end

    it "permissions hash shows all current permissions" do
      article = Article.create!(title: "Hash Test", status: "draft")

      perms = article.permissions

      expect(perms[:delete]).to be true
      expect(perms[:edit]).to be true
      expect(perms[:publish]).to be true
      expect(perms[:unpublish]).to be false
      expect(perms[:archive]).to be false
    end
  end

  describe "Taggable + Searchable" do
    before do
      @ruby_article = Article.create!(
        title: "Ruby Guide",
        status: "published",
        published_at: Time.current,
        tags: [ "ruby", "programming" ]
      )

      @rails_article = Article.create!(
        title: "Rails Guide",
        status: "published",
        published_at: Time.current,
        tags: [ "rails", "web" ]
      )

      @both_article = Article.create!(
        title: "Full Stack",
        status: "published",
        published_at: Time.current,
        tags: [ "ruby", "rails", "full-stack" ]
      )
    end

    it "searches and filters by tags using iteration" do
      # Since tags are serialized JSON, use Ruby-based filtering
      published = Article.search({ status_eq: "published" })

      ruby_articles = published.select { |a| a.tagged_with?("ruby") }

      expect(ruby_articles.count).to eq(2)
      expect(ruby_articles).to include(@ruby_article, @both_article)
    end

    it "combines text search with tag filtering" do
      results = Article.search({ title_cont: "Guide", status_eq: "published" })

      # Filter by tag at application level
      ruby_guides = results.select { |a| a.tagged_with?("ruby") }

      expect(ruby_guides.count).to eq(1)
      expect(ruby_guides.first).to eq(@ruby_article)
    end

    it "manages tags after search operations" do
      article = Article.search({ title_cont: "Ruby" }).first

      article.tag_with("tutorial")
      article.reload

      expect(article.tagged_with?("tutorial")).to be true
      expect(article.tags).to include("ruby", "programming", "tutorial")
    end
  end

  describe "Predicable field types" do
    it "handles string predicates" do
      Article.create!(title: "Exact Match", status: "draft")
      Article.create!(title: "Partial Match Here", status: "draft")

      exact = Article.search({ title_eq: "Exact Match" })
      expect(exact.count).to eq(1)

      partial = Article.search({ title_cont: "Match" })
      expect(partial.count).to eq(2)

      starts_with = Article.search({ title_start: "Exact" })
      expect(starts_with.count).to eq(1)

      ends_with = Article.search({ title_end: "Here" })
      expect(ends_with.count).to eq(1)
    end

    it "handles numeric predicates" do
      Article.create!(title: "A", status: "draft", view_count: 50)
      Article.create!(title: "B", status: "draft", view_count: 100)
      Article.create!(title: "C", status: "draft", view_count: 150)

      gt = Article.search({ view_count_gt: 100 })
      expect(gt.count).to eq(1)

      gteq = Article.search({ view_count_gteq: 100 })
      expect(gteq.count).to eq(2)

      lt = Article.search({ view_count_lt: 100 })
      expect(lt.count).to eq(1)

      lteq = Article.search({ view_count_lteq: 100 })
      expect(lteq.count).to eq(2)
    end

    it "handles boolean predicates" do
      Article.create!(title: "Featured", status: "draft", featured: true)
      Article.create!(title: "Not Featured", status: "draft", featured: false)

      featured = Article.search({ featured_eq: true })
      expect(featured.count).to eq(1)
      expect(featured.first.title).to eq("Featured")

      not_featured = Article.search({ featured_eq: false })
      expect(not_featured.count).to eq(1)
      expect(not_featured.first.title).to eq("Not Featured")
    end

    it "handles date predicates" do
      Article.create!(title: "Old", status: "published", published_at: 10.days.ago)
      Article.create!(title: "Recent", status: "published", published_at: 2.days.ago)
      Article.create!(title: "Today", status: "published", published_at: Time.current)

      old_articles = Article.search({ published_at_lt: 5.days.ago })
      expect(old_articles.count).to eq(1)
      expect(old_articles.first.title).to eq("Old")

      recent = Article.search({ published_at_gteq: 3.days.ago })
      expect(recent.count).to eq(2)
    end

    it "handles NOT_EQ predicates" do
      Article.create!(title: "Draft", status: "draft")
      Article.create!(title: "Published", status: "published", published_at: Time.current)
      Article.create!(title: "Archived", status: "archived")

      not_draft = Article.search({ status_not_eq: "draft" })
      expect(not_draft.count).to eq(2)
      expect(not_draft.pluck(:status)).to contain_exactly("published", "archived")
    end
  end

  describe "All modules together" do
    let(:author) { Author.create!(name: "Integration Author") }

    it "performs complex workflow with all modules" do
      # Create article with all features
      article = Article.create!(
        title: "Complete Module Test",
        content: "Testing all modules",
        status: "draft",
        view_count: 0,
        featured: false,
        author: author,
        tags: [ "testing" ]
      )

      # Verify initial state
      expect(article.is_draft?).to be true
      expect(article.permit_publish?).to be true
      expect(article.tagged_with?("testing")).to be true

      # Search for it
      results = Article.search({ status_eq: "draft", title_cont: "Module" })
      expect(results).to include(article)

      # Add more tags
      article.tag_with("integration", "comprehensive")
      expect(article.tags.size).to eq(3)

      # Update to popular published article
      article.update!(
        status: "published",
        published_at: Time.current,
        view_count: 200,
        featured: true
      )

      # Verify state changed
      expect(article.is_published?).to be true
      expect(article.is_popular?).to be true
      expect(article.permit_delete?).to be false
      expect(article.permit_unpublish?).to be true

      # Search with new criteria
      popular = Article.search(
        { featured_eq: true, view_count_gteq: 100 },
        orders: [ :sort_view_count_desc ]
      )
      expect(popular).to include(article)

      # Verify permissions changed
      perms = article.permissions
      expect(perms[:delete]).to be false
      expect(perms[:edit]).to be true

      # Check tag operations still work
      article.untag("comprehensive")
      expect(article.tags).not_to include("comprehensive")
      expect(article.tags).to include("testing", "integration")
    end

    it "handles edge cases across modules" do
      # Article at boundary of popular threshold
      article = Article.create!(
        title: "Boundary Test",
        status: "published",
        published_at: Time.current,
        view_count: 99, # Just below popular threshold of 100
        tags: []
      )

      expect(article.is_popular?).to be false
      expect(article.is_published?).to be true

      # Increase to exactly 100
      article.update!(view_count: 100)
      expect(article.is_popular?).to be true

      # Search with boundary value
      results = Article.search({ view_count_gteq: 100 })
      expect(results).to include(article)

      exact_results = Article.search({ view_count_eq: 100 })
      expect(exact_results).to include(article)
    end
  end

  describe "Sortable field combinations" do
    before do
      @a1 = Article.create!(
        title: "Alpha",
        status: "published",
        published_at: 3.days.ago,
        view_count: 100
      )
      @a2 = Article.create!(
        title: "Beta",
        status: "published",
        published_at: 1.day.ago,
        view_count: 100
      )
      @a3 = Article.create!(
        title: "Gamma",
        status: "published",
        published_at: 2.days.ago,
        view_count: 200
      )
    end

    it "sorts by single field ascending" do
      results = Article.search({}, orders: [ :sort_title_asc ])
      expect(results.map(&:title)).to eq([ "Alpha", "Beta", "Gamma" ])
    end

    it "sorts by single field descending" do
      results = Article.search({}, orders: [ :sort_title_desc ])
      expect(results.map(&:title)).to eq([ "Gamma", "Beta", "Alpha" ])
    end

    it "applies secondary sort for ties" do
      results = Article.search(
        {},
        orders: [ :sort_view_count_asc, :sort_title_asc ]
      )

      # view_count 100: Alpha, Beta (sorted by title)
      # view_count 200: Gamma
      expect(results.map(&:title)).to eq([ "Alpha", "Beta", "Gamma" ])
    end

    it "uses default order when no orders specified" do
      results = Article.search({})

      # Default order is sort_created_at_desc
      # So newest articles first
      expect(results.first.title).to eq("Gamma") # Last created
    end
  end
end
