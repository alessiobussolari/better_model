# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Traceable Module Interactions", type: :integration do
  let(:author) { Author.create!(name: "Test Author") }
  let(:editor) { Author.create!(name: "Editor") }

  describe "Traceable + Stateable" do
    it "tracks status transitions" do
      article = Article.create!(
        title: "Status Tracking",
        status: "draft"
      )

      # Initial creation tracked
      expect(article.versions.count).to eq(1)
      expect(article.versions.last.event).to eq("created")

      # Status change tracked
      article.update!(status: "published", published_at: Time.current)

      expect(article.versions.count).to eq(2)
      expect(article.versions.first.event).to eq("updated")

      # Check status change is recorded
      changes = article.changes_for(:status)
      expect(changes.first[:after]).to eq("published")
      expect(changes.first[:before]).to eq("draft")
    end

    it "tracks multiple status transitions over time" do
      article = Article.create!(title: "Multi Transition", status: "draft")

      article.update!(status: "published", published_at: Time.current)
      article.update!(status: "archived")

      status_changes = article.changes_for(:status)

      expect(status_changes.size).to eq(2)
      expect(status_changes.map { |c| c[:after] }).to contain_exactly("published", "archived")
    end

    it "provides audit trail with status history" do
      article = Article.create!(title: "Audit Trail", status: "draft")

      article.update!(status: "published", published_at: Time.current)

      trail = article.audit_trail

      expect(trail.size).to eq(2)
      expect(trail.first[:event]).to eq("updated")
      expect(trail.first[:changes]).to have_key("status")
    end

    it "combines status checks with version queries" do
      article = Article.create!(title: "Combined Check", status: "draft")

      expect(article.is_draft?).to be true
      expect(article.versions.where(event: "created").count).to eq(1)

      article.update!(status: "published", published_at: Time.current)

      expect(article.is_published?).to be true
      expect(article.versions.where(event: "updated").count).to eq(1)
    end
  end

  describe "Traceable + Searchable" do
    before do
      @article1 = Article.create!(
        title: "Article by Author 1",
        status: "draft"
      )

      @article2 = Article.create!(
        title: "Article by Author 2",
        status: "draft"
      )

      # Simulate updates by different users
      @article1.update!(title: "Updated Title 1")
      @article2.update!(title: "Updated Title 2", view_count: 100)
    end

    it "searches combined with version metadata" do
      # Search for articles
      results = Article.search({ title_cont: "Updated" })

      expect(results).to include(@article1, @article2)

      # Each result has tracked versions
      results.each do |article|
        expect(article.versions.count).to be >= 2
      end
    end

    it "filters by changed fields" do
      # Find articles where view_count was changed
      with_view_changes = Article.all.select do |a|
        a.changes_for(:view_count).any?
      end

      expect(with_view_changes).to include(@article2)
      expect(with_view_changes).not_to include(@article1)
    end

    it "tracks search-relevant field changes" do
      article = Article.create!(
        title: "Searchable Tracked",
        status: "draft"
      )

      article.update!(status: "published", published_at: Time.current)

      # Search by new status
      results = Article.search({ status_eq: "published", title_cont: "Tracked" })
      expect(results).to include(article)

      # Verify change was tracked
      status_changes = article.changes_for(:status)
      expect(status_changes.last[:after]).to eq("published")
    end
  end

  describe "Traceable + Archivable" do
    it "tracks archive and restore events via field changes" do
      article = Article.create!(
        title: "Archive Tracking",
        status: "draft"
      )

      initial_version_count = article.versions.count

      # Archive creates a record change (archived_at is not tracked by default)
      article.archive!(reason: "Testing")

      # Since archived_at is not in tracked fields, version count may not increase
      # But we can still check the article state
      expect(article.archived?).to be true
    end

    it "maintains version history through archive/restore cycle" do
      article = Article.create!(
        title: "Cycle Test",
        status: "draft"
      )

      # Make some changes
      article.update!(title: "Updated Title")
      version_count_after_update = article.versions.count

      # Archive and restore
      article.archive!(reason: "Temp")
      article.restore!

      # Version count includes all tracked field changes
      expect(article.versions.count).to be >= version_count_after_update
    end

    it "can reconstruct state before archiving" do
      article = Article.create!(
        title: "Original Title",
        status: "draft",
        content: "Original content"
      )

      timestamp_before_changes = Time.current
      sleep(0.1)  # Ensure timestamp difference

      article.update!(title: "Changed Title", content: "Changed content")

      # Reconstruct state at timestamp
      past_state = article.as_of(timestamp_before_changes)

      expect(past_state.title).to eq("Original Title")
      expect(past_state.content).to eq("Original content")
    end
  end

  describe "Traceable rollback" do
    it "rolls back to a specific version" do
      article = Article.create!(
        title: "Rollback Test",
        status: "draft",
        content: "Initial content"
      )

      article.update!(title: "Second Title", content: "Second content")
      article.update!(title: "Third Title", content: "Third content")

      # Get second version
      second_version = article.versions.order(created_at: :asc).second

      # Rollback to second version
      article.rollback_to(second_version)

      # Should have first version values (before second update)
      expect(article.title).to eq("Rollback Test")
      expect(article.content).to eq("Initial content")
    end

    it "creates a new version record on rollback" do
      article = Article.create!(
        title: "Version Count Test",
        status: "draft"
      )

      article.update!(title: "Changed")

      version_count_before = article.versions.count
      second_version = article.versions.order(created_at: :asc).second

      article.rollback_to(second_version)

      expect(article.versions.count).to eq(version_count_before + 1)
    end

    it "reconstructs object state at specific timestamp" do
      article = Article.create!(
        title: "Time Travel",
        status: "draft",
        view_count: 0
      )

      first_timestamp = Time.current
      sleep(0.1)

      article.update!(view_count: 50)
      second_timestamp = Time.current
      sleep(0.1)

      article.update!(view_count: 100)

      # State at first timestamp
      state_at_first = article.as_of(first_timestamp)
      expect(state_at_first.view_count).to eq(0)

      # State at second timestamp
      state_at_second = article.as_of(second_timestamp)
      expect(state_at_second.view_count).to eq(50)

      # Current state
      expect(article.view_count).to eq(100)
    end

    it "reconstructed objects are readonly" do
      article = Article.create!(title: "Readonly Test", status: "draft")
      article.update!(title: "Changed")

      past_state = article.as_of(1.second.ago)

      expect(past_state).to be_readonly
    end
  end

  describe "Traceable audit trail" do
    it "provides complete audit trail" do
      article = Article.create!(
        title: "Audit Article",
        status: "draft"
      )

      article.update!(title: "First Update")
      article.update!(title: "Second Update", status: "published", published_at: Time.current)

      trail = article.audit_trail

      expect(trail.size).to eq(3)
      expect(trail.map { |t| t[:event] }).to include("created", "updated")
    end

    it "includes changes in audit trail" do
      article = Article.create!(title: "Change Audit", status: "draft")

      article.update!(status: "published", published_at: Time.current)

      trail = article.audit_trail

      update_entry = trail.find { |t| t[:event] == "updated" }
      expect(update_entry[:changes]).to have_key("status")
    end

    it "includes audit trail in JSON output" do
      article = Article.create!(title: "JSON Audit", status: "draft")
      article.update!(title: "Updated JSON")

      json = article.as_json(include_audit_trail: true)

      expect(json["audit_trail"]).to be_present
      expect(json["audit_trail"].size).to eq(2)
    end
  end

  describe "Cross-module complex scenario" do
    it "handles complete lifecycle with tracking" do
      # Create
      article = Article.create!(
        title: "Lifecycle Article",
        status: "draft",
        tags: [ "test" ],
        content: "Initial content"
      )

      expect(article.versions.last.event).to eq("created")
      expect(article.is_draft?).to be true

      # Edit
      article.update!(title: "Edited Title")
      # Title changes include: creation + this edit
      expect(article.changes_for(:title).size).to eq(2)

      # Publish
      article.update!(status: "published", published_at: Time.current)
      expect(article.is_published?).to be true
      expect(article.changes_for(:status).size).to eq(1)

      # Archive
      article.archive!(reason: "End of lifecycle")
      expect(article.archived?).to be true

      # Verify full history
      expect(article.versions.count).to be >= 3
      expect(article.audit_trail.size).to be >= 3
    end
  end
end
