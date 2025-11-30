# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Archivable Module Interactions", type: :integration do
  let(:author) { Author.create!(name: "Test Author") }

  describe "Archivable + Searchable" do
    before do
      @active1 = Article.create!(
        title: "Active Article 1",
        status: "published",
        published_at: Time.current,
        author: author
      )

      @active2 = Article.create!(
        title: "Active Article 2",
        status: "draft",
        author: author
      )

      @archived = Article.create!(
        title: "Archived Article",
        status: "published",
        published_at: 1.month.ago,
        author: author
      )
      @archived.archive!(reason: "Outdated content")
    end

    it "searches archived records with archived_at predicates" do
      # Search for archived articles
      archived_results = Article.search({ archived_at_present: true })

      expect(archived_results).to include(@archived)
      expect(archived_results).not_to include(@active1, @active2)
    end

    it "searches active records with archived_at_null predicate" do
      active_results = Article.search({ archived_at_null: true })

      expect(active_results).to include(@active1, @active2)
      expect(active_results).not_to include(@archived)
    end

    it "combines archived predicate with status search" do
      results = Article.search({
        archived_at_null: true,
        status_eq: "published"
      })

      expect(results).to include(@active1)
      expect(results).not_to include(@active2, @archived)
    end

    it "uses semantic scopes for archived filtering" do
      expect(Article.archived).to include(@archived)
      expect(Article.archived).not_to include(@active1, @active2)

      expect(Article.not_archived).to include(@active1, @active2)
      expect(Article.not_archived).not_to include(@archived)
    end

    it "sorts by archived_at" do
      # Archive another article more recently
      @active2.archive!(reason: "Also outdated")

      results = Article.search(
        { archived_at_present: true },
        orders: [ :sort_archived_at_desc ]
      )

      expect(results.first).to eq(@active2)  # More recently archived
      expect(results.last).to eq(@archived)
    end
  end

  describe "Archivable + Permissible" do
    it "denies edit permission on archived articles via custom logic" do
      article = Article.create!(
        title: "Test Article",
        status: "published",
        published_at: Time.current,
        author: author
      )

      # Active article - can be edited (published and not expired)
      expect(article.permit_edit?).to be true

      # Archive the article
      article.archive!(reason: "No longer needed")

      # Still technically editable per permission rules (not expired)
      # But archived flag can be checked separately
      expect(article.archived?).to be true

      # Application logic should check both
      can_edit = article.permit_edit? && !article.archived?
      expect(can_edit).to be false
    end

    it "maintains permission state after restore" do
      article = Article.create!(
        title: "Restorable Article",
        status: "draft",
        author: author
      )

      expect(article.permit_delete?).to be true
      expect(article.permit_publish?).to be true

      article.archive!(reason: "Temporary archive")
      expect(article.archived?).to be true

      article.restore!
      expect(article.archived?).to be false
      expect(article.permit_delete?).to be true
      expect(article.permit_publish?).to be true
    end

    it "checks archive permission based on status conditions" do
      # Create old published article
      old_article = Article.create!(
        title: "Old Article",
        status: "published",
        published_at: 2.years.ago,
        created_at: 2.years.ago,
        author: author
      )

      # Create recent published article
      recent_article = Article.create!(
        title: "Recent Article",
        status: "published",
        published_at: Time.current,
        author: author
      )

      # Archive permission requires: published AND created > 1 year ago
      expect(old_article.permit_archive?).to be true
      expect(recent_article.permit_archive?).to be false
    end
  end

  describe "Archivable + Taggable" do
    it "maintains tags after archiving" do
      article = Article.create!(
        title: "Tagged Article",
        status: "draft",
        tags: [ "ruby", "rails" ],
        author: author
      )

      article.archive!(reason: "Maintenance")

      expect(article.archived?).to be true
      expect(article.tags).to include("ruby", "rails")
    end

    it "maintains tags after restore" do
      article = Article.create!(
        title: "Tagged Article",
        status: "draft",
        tags: [ "ruby", "testing" ],
        author: author
      )

      article.archive!(reason: "Temporary")
      article.restore!

      expect(article.archived?).to be false
      expect(article.tags).to include("ruby", "testing")
    end

    it "can add tags to archived articles" do
      article = Article.create!(
        title: "Archive Tags Test",
        status: "draft",
        tags: [ "original" ],
        author: author
      )

      article.archive!(reason: "Archiving with tag test")

      # Tags can still be modified on archived records
      article.tag_with("added-while-archived")

      expect(article.tags).to include("original", "added-while-archived")
    end

    it "filters archived by tags using Ruby iteration" do
      tagged = Article.create!(title: "Tagged", status: "draft", tags: [ "important" ])
      untagged = Article.create!(title: "Untagged", status: "draft", tags: [])

      tagged.archive!(reason: "Done")
      untagged.archive!(reason: "Done")

      archived = Article.archived
      important_archived = archived.select { |a| a.tagged_with?("important") }

      expect(important_archived).to include(tagged)
      expect(important_archived).not_to include(untagged)
    end
  end

  describe "Archivable + Stateable" do
    it "archives from any status" do
      draft = Article.create!(title: "Draft", status: "draft")
      published = Article.create!(
        title: "Published",
        status: "published",
        published_at: Time.current
      )

      expect(draft.is_draft?).to be true
      expect(published.is_published?).to be true

      draft.archive!(reason: "Draft cleanup")
      published.archive!(reason: "Content outdated")

      expect(draft.archived?).to be true
      expect(published.archived?).to be true

      # Status remains unchanged after archive
      expect(draft.status).to eq("draft")
      expect(published.status).to eq("published")
    end

    it "restores to original status" do
      article = Article.create!(
        title: "Published Article",
        status: "published",
        published_at: Time.current
      )

      original_status = article.status
      article.archive!(reason: "Temporary")

      expect(article.archived?).to be true

      article.restore!

      expect(article.archived?).to be false
      expect(article.status).to eq(original_status)
      expect(article.is_published?).to be true
    end

    it "combines status checks with archive checks" do
      article = Article.create!(
        title: "Complex State",
        status: "published",
        published_at: Time.current,
        view_count: 200
      )

      # Active, published, popular
      expect(article.is_published?).to be true
      expect(article.is_popular?).to be true
      expect(article.archived?).to be false

      article.archive!(reason: "Popular but archived")

      # Still published and popular, but now archived
      expect(article.is_published?).to be true
      expect(article.is_popular?).to be true
      expect(article.archived?).to be true
    end
  end

  describe "Archivable with tracking" do
    it "records archive metadata" do
      article = Article.create!(
        title: "Tracked Archive",
        status: "draft",
        author: author
      )

      article.archive!(by: author, reason: "Compliance removal")

      expect(article.archived_at).to be_present
      expect(article.archived_by_id).to eq(author.id)
      expect(article.archive_reason).to eq("Compliance removal")
    end

    it "clears archive metadata on restore" do
      article = Article.create!(
        title: "Restorable",
        status: "draft",
        author: author
      )

      article.archive!(by: author, reason: "Temporary")
      article.restore!

      expect(article.archived_at).to be_nil
      expect(article.archived_by_id).to be_nil
      expect(article.archive_reason).to be_nil
    end

    it "includes archive info in JSON output" do
      article = Article.create!(
        title: "JSON Test",
        status: "draft",
        author: author
      )

      article.archive!(by: author, reason: "JSON test reason")

      json = article.as_json(include_archive_info: true)

      expect(json["archive_info"]).to be_present
      expect(json["archive_info"]["archived"]).to be true
      expect(json["archive_info"]["archive_reason"]).to eq("JSON test reason")
    end
  end

  describe "Error handling" do
    it "raises error when archiving already archived record" do
      article = Article.create!(title: "Already Archived", status: "draft")
      article.archive!(reason: "First archive")

      expect {
        article.archive!(reason: "Second archive")
      }.to raise_error(BetterModel::Errors::Archivable::AlreadyArchivedError)
    end

    it "raises error when restoring non-archived record" do
      article = Article.create!(title: "Not Archived", status: "draft")

      expect {
        article.restore!
      }.to raise_error(BetterModel::Errors::Archivable::NotArchivedError)
    end
  end
end
