# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Full Workflow Integration", type: :integration do
  describe "Article lifecycle workflow" do
    let(:author) { Author.create!(name: "Test Author") }

    it "creates an article with all modules active" do
      article = Article.create!(
        title: "Integration Test Article",
        content: "This is a comprehensive test",
        status: "draft",
        author: author,
        tags: [ "ruby", "rails", "testing" ]
      )

      expect(article).to be_persisted
      expect(article.tags).to eq([ "ruby", "rails", "testing" ])
      expect(article.author).to eq(author)
      expect(article.is_draft?).to be true
    end

    it "completes full article lifecycle: create -> publish -> archive" do
      # Step 1: Create draft article
      article = Article.create!(
        title: "Lifecycle Test",
        content: "Testing full lifecycle",
        status: "draft",
        author: author
      )

      expect(article.is_draft?).to be true
      expect(article.permit_delete?).to be true
      expect(article.permit_publish?).to be true

      # Step 2: Publish article
      article.update!(status: "published", published_at: Time.current)

      expect(article.is_published?).to be true
      expect(article.permit_delete?).to be false
      expect(article.permit_unpublish?).to be true

      # Step 3: Verify permissions changed
      expect(article.permit_edit?).to be true
    end

    it "tracks all changes throughout lifecycle" do
      article = Article.create!(
        title: "Tracking Test",
        content: "Initial content",
        status: "draft"
      )

      # Make several updates
      article.update!(title: "Updated Title")
      article.update!(content: "Updated content")
      article.update!(status: "published", published_at: Time.current)

      # Article should have all attributes properly set
      expect(article.title).to eq("Updated Title")
      expect(article.content).to eq("Updated content")
      expect(article.status).to eq("published")
    end
  end

  describe "Search workflow" do
    before do
      @author = Author.create!(name: "Search Author")

      # Create test articles with various attributes
      @article1 = Article.create!(
        title: "Ruby Guide",
        content: "Learn Ruby basics",
        status: "published",
        published_at: 2.days.ago,
        view_count: 150,
        featured: true,
        author: @author,
        tags: [ "ruby", "programming" ]
      )

      @article2 = Article.create!(
        title: "Rails Tutorial",
        content: "Build web apps with Rails",
        status: "published",
        published_at: 1.day.ago,
        view_count: 50,
        featured: false,
        author: @author,
        tags: [ "rails", "web" ]
      )

      @article3 = Article.create!(
        title: "Testing Best Practices",
        content: "Write better tests",
        status: "draft",
        view_count: 0,
        featured: false,
        tags: [ "testing" ]
      )
    end

    it "searches with single predicate" do
      results = Article.search({ status_eq: "published" })

      expect(results.count).to eq(2)
      expect(results).to include(@article1, @article2)
      expect(results).not_to include(@article3)
    end

    it "searches with multiple predicates" do
      results = Article.search({
        status_eq: "published",
        featured_eq: true
      })

      expect(results.count).to eq(1)
      expect(results.first).to eq(@article1)
    end

    it "searches with comparison predicates" do
      results = Article.search({ view_count_gteq: 100 })

      expect(results.count).to eq(1)
      expect(results.first).to eq(@article1)
    end

    it "searches with text predicates" do
      results = Article.search({ title_cont: "Ruby" })

      expect(results.count).to eq(1)
      expect(results.first).to eq(@article1)
    end

    it "combines search with sorting" do
      results = Article.search(
        { status_eq: "published" },
        orders: [ :sort_view_count_desc ]
      )

      expect(results.first).to eq(@article1) # Higher view count
      expect(results.last).to eq(@article2)
    end

    it "combines search with pagination" do
      results = Article.search(
        { status_eq: "published" },
        pagination: { per_page: 1, page: 1 }
      )

      expect(results.count).to eq(1)
    end

    it "uses OR conditions" do
      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Rails" }
        ]
      })

      expect(results.count).to eq(2)
      expect(results).to include(@article1, @article2)
    end

    it "combines OR conditions with AND predicates" do
      results = Article.search({
        or: [
          { title_cont: "Ruby" },
          { title_cont: "Testing" }
        ],
        status_eq: "published"
      })

      expect(results.count).to eq(1)
      expect(results.first).to eq(@article1)
    end
  end

  describe "Permission workflow" do
    let(:author) { Author.create!(name: "Permission Author") }

    it "checks view permissions based on status" do
      draft_article = Article.create!(
        title: "Draft",
        status: "draft",
        author: author
      )

      published_article = Article.create!(
        title: "Published",
        status: "published",
        published_at: Time.current,
        author: author
      )

      # Draft article - can delete
      expect(draft_article.permit_delete?).to be true
      expect(draft_article.permit_publish?).to be true

      # Published article - cannot delete
      expect(published_article.permit_delete?).to be false
      expect(published_article.permit_unpublish?).to be true
    end

    it "checks edit permissions correctly" do
      draft = Article.create!(title: "Draft", status: "draft")
      published = Article.create!(title: "Published", status: "published", published_at: Time.current)

      expect(draft.permit_edit?).to be true
      expect(published.permit_edit?).to be true
    end

    it "returns all permissions as hash" do
      article = Article.create!(title: "Test", status: "draft")

      permissions = article.permissions

      expect(permissions).to be_a(Hash)
      expect(permissions).to have_key(:delete)
      expect(permissions).to have_key(:edit)
      expect(permissions).to have_key(:publish)
    end

    it "filters granted permissions" do
      article = Article.create!(title: "Test", status: "draft")

      granted = article.granted_permissions([ :delete, :edit, :publish, :unpublish ])

      expect(granted).to include(:delete)
      expect(granted).to include(:edit)
      expect(granted).to include(:publish)
      expect(granted).not_to include(:unpublish)
    end

    it "checks if has any permission" do
      article = Article.create!(title: "Test", status: "draft")

      expect(article.has_any_permission?).to be true
    end

    it "checks if has all specified permissions" do
      article = Article.create!(title: "Test", status: "draft")

      expect(article.has_all_permissions?([ :delete, :edit ])).to be true
      expect(article.has_all_permissions?([ :delete, :unpublish ])).to be false
    end
  end

  describe "Status workflow" do
    it "evaluates status conditions correctly" do
      draft = Article.create!(title: "Draft", status: "draft")
      scheduled = Article.create!(
        title: "Scheduled",
        status: "draft",
        scheduled_at: 1.day.from_now
      )
      popular = Article.create!(
        title: "Popular",
        status: "published",
        published_at: 1.day.ago,
        view_count: 150
      )

      expect(draft.is_draft?).to be true
      expect(scheduled.is_scheduled?).to be true
      expect(popular.is_popular?).to be true
    end

    it "checks combined status conditions" do
      expired = Article.create!(
        title: "Expired",
        status: "published",
        published_at: 1.year.ago,
        expires_at: 1.day.ago
      )

      expect(expired.is_expired?).to be true
      expect(expired.is_active?).to be false
    end
  end

  describe "Taggable workflow" do
    it "manages tags through full lifecycle" do
      article = Article.create!(
        title: "Tagged Article",
        status: "draft",
        tags: [ "ruby" ]
      )

      expect(article.tags).to include("ruby")

      # Add tags
      article.tag_with("rails")
      expect(article.tags).to include("rails")

      # Remove tags
      article.untag("ruby")
      expect(article.tags).not_to include("ruby")
      expect(article.tags).to include("rails")

      # Replace tags with retag
      article.retag("testing", "rspec")
      expect(article.tags).to eq([ "testing", "rspec" ])
    end

    it "normalizes tags when configured" do
      article = Article.create!(
        title: "Normalized Tags",
        status: "draft",
        tags: []
      )

      # Add tags with mixed case - they should be normalized on save
      article.tag_with("Ruby", "RAILS", "Testing")

      expect(article.tags).to include("ruby")
      expect(article.tags).to include("rails")
      expect(article.tags).to include("testing")
    end

    it "checks if article has specific tag" do
      article = Article.create!(
        title: "Tagged",
        status: "draft",
        tags: [ "ruby", "rails" ]
      )

      expect(article.tagged_with?("ruby")).to be true
      expect(article.tagged_with?("python")).to be false
    end

    it "uses tag_list for CSV representation" do
      article = Article.create!(
        title: "Tagged",
        status: "draft",
        tags: [ "ruby", "rails", "testing" ]
      )

      expect(article.tag_list).to eq("ruby, rails, testing")
    end

    it "sets tags from CSV via tag_list=" do
      article = Article.create!(
        title: "Tagged",
        status: "draft",
        tags: []
      )

      article.tag_list = "ruby, rails, testing"

      expect(article.tags).to include("ruby")
      expect(article.tags).to include("rails")
      expect(article.tags).to include("testing")
    end
  end

  describe "Complete multi-module interaction" do
    let(:author) { Author.create!(name: "Complete Test Author") }

    it "uses all modules together in realistic scenario" do
      # Create article with all features
      article = Article.create!(
        title: "Complete Integration Test",
        content: "Testing all modules together",
        status: "draft",
        author: author,
        tags: [ "integration", "testing" ],
        featured: true
      )

      # Check initial state
      expect(article.is_draft?).to be true
      expect(article.permit_publish?).to be true
      expect(article.tags).to include("integration")

      # Search for it
      found = Article.search({ title_cont: "Complete", status_eq: "draft" })
      expect(found).to include(article)

      # Update and check searchable
      article.update!(status: "published", published_at: Time.current, view_count: 200)

      expect(article.is_published?).to be true
      expect(article.is_popular?).to be true

      # Search by new criteria
      popular_found = Article.search({ view_count_gteq: 100, status_eq: "published" })
      expect(popular_found).to include(article)

      # Check permissions changed
      expect(article.permit_delete?).to be false
      expect(article.permit_unpublish?).to be true

      # Get permissions hash for API
      perms = article.permissions
      expect(perms[:delete]).to be false
      expect(perms[:edit]).to be true

      # Tag operations
      article.tag_with("complete")
      expect(article.tagged_with?("complete")).to be true
    end
  end
end
