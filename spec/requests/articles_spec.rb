# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Articles Controller", type: :request do
  let(:author) { Author.create!(name: "Test Author") }

  describe "GET /articles" do
    before do
      @published = Article.create!(
        title: "Published Article",
        status: "published",
        published_at: Time.current
      )
      @draft = Article.create!(
        title: "Draft Article",
        status: "draft"
      )
      @archived = Article.create!(
        title: "Archived Article",
        status: "published",
        published_at: 1.week.ago
      )
      @archived.archive!(reason: "Outdated")
    end

    it "returns all articles" do
      get "/articles"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(3)
    end

    it "searches by title using Searchable" do
      get "/articles", params: { title_cont: "Published" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first["title"]).to eq("Published Article")
    end

    it "searches by status using Searchable" do
      get "/articles", params: { status_eq: "draft" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first["title"]).to eq("Draft Article")
    end

    it "filters archived articles using Archivable predicates" do
      get "/articles", params: { archived_at_present: true }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first["title"]).to eq("Archived Article")
    end

    it "filters active articles using Archivable predicates" do
      get "/articles", params: { archived_at_null: true }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(2)
      titles = json.map { |a| a["title"] }
      expect(titles).to include("Published Article", "Draft Article")
    end
  end

  describe "GET /articles/:id" do
    it "returns the article" do
      article = Article.create!(title: "Show Test", status: "draft")

      get "/articles/#{article.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Show Test")
    end

    it "returns 404 for non-existent article" do
      get "/articles/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /articles" do
    it "creates an article" do
      post "/articles", params: { title: "New Article", status: "draft" }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Article")
      expect(json["status"]).to eq("draft")
    end

    it "creates an article with tags using Taggable" do
      post "/articles", params: {
        title: "Tagged Article",
        status: "draft",
        tags: [ "ruby", "rails" ]
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tags"]).to include("ruby", "rails")
    end

    it "creates version on create using Traceable" do
      post "/articles", params: { title: "Traced Article", status: "draft" }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      article = Article.find(json["id"])
      expect(article.versions.count).to eq(1)
      expect(article.versions.last.event).to eq("created")
    end
  end

  describe "PATCH /articles/:id" do
    let!(:article) { Article.create!(title: "Original Title", status: "draft") }

    it "updates an article" do
      patch "/articles/#{article.id}", params: { title: "Updated Title" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Updated Title")
    end

    it "updates status using Stateable" do
      patch "/articles/#{article.id}", params: {
        status: "published",
        published_at: Time.current.iso8601
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("published")
    end

    it "creates version on update using Traceable" do
      initial_versions = article.versions.count

      patch "/articles/#{article.id}", params: { title: "New Title" }

      expect(response).to have_http_status(:ok)
      article.reload
      expect(article.versions.count).to eq(initial_versions + 1)
    end

    it "updates tags using Taggable" do
      patch "/articles/#{article.id}", params: { tags: [ "updated", "tags" ] }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tags"]).to include("updated", "tags")
    end
  end

  describe "DELETE /articles/:id" do
    it "deletes an article" do
      article = Article.create!(title: "To Delete", status: "draft")

      delete "/articles/#{article.id}"

      expect(response).to have_http_status(:no_content)
      expect { Article.find(article.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST /articles/:id/archive" do
    let!(:article) { Article.create!(title: "To Archive", status: "draft") }

    it "archives an article using Archivable" do
      post "/articles/#{article.id}/archive", params: { reason: "No longer needed" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      article.reload
      expect(article.archived?).to be true
      expect(article.archive_reason).to eq("No longer needed")
    end

    it "returns error when already archived" do
      article.archive!(reason: "First archive")

      expect {
        post "/articles/#{article.id}/archive", params: { reason: "Second archive" }
      }.to raise_error(BetterModel::Errors::Archivable::AlreadyArchivedError)
    end
  end

  describe "POST /articles/:id/restore" do
    let!(:article) do
      a = Article.create!(title: "Archived Article", status: "draft")
      a.archive!(reason: "Testing")
      a
    end

    it "restores an archived article using Archivable" do
      post "/articles/#{article.id}/restore"

      expect(response).to have_http_status(:ok)

      article.reload
      expect(article.archived?).to be false
      expect(article.archive_reason).to be_nil
    end

    it "returns error when not archived" do
      article.restore!

      expect {
        post "/articles/#{article.id}/restore"
      }.to raise_error(BetterModel::Errors::Archivable::NotArchivedError)
    end
  end

  describe "BetterModel features through controller" do
    describe "Permissible" do
      it "checks permissions on article via controller" do
        draft = Article.create!(title: "Draft", status: "draft")
        published = Article.create!(
          title: "Published",
          status: "published",
          published_at: Time.current
        )

        get "/articles/#{draft.id}"
        draft_json = JSON.parse(response.body)

        get "/articles/#{published.id}"
        published_json = JSON.parse(response.body)

        # Permissions can be checked on loaded articles
        draft_article = Article.find(draft_json["id"])
        published_article = Article.find(published_json["id"])

        expect(draft_article.permit_delete?).to be true
        expect(published_article.permit_delete?).to be false
      end
    end

    describe "Traceable audit trail" do
      it "maintains audit trail through controller operations" do
        # Create
        post "/articles", params: { title: "Audit Test", status: "draft" }
        json = JSON.parse(response.body)
        article_id = json["id"]

        # Update
        patch "/articles/#{article_id}", params: { title: "Updated Audit Test" }

        # Update again
        patch "/articles/#{article_id}", params: { status: "published", published_at: Time.current.iso8601 }

        article = Article.find(article_id)
        trail = article.audit_trail

        expect(trail.size).to eq(3)
        expect(trail.map { |t| t[:event] }).to include("created", "updated")
      end
    end

    describe "Stateable through controller" do
      it "transitions states via update" do
        article = Article.create!(title: "State Test", status: "draft")

        expect(article.is_draft?).to be true

        patch "/articles/#{article.id}", params: {
          status: "published",
          published_at: Time.current.iso8601
        }

        article.reload
        expect(article.is_published?).to be true
      end
    end

    describe "Combined module interactions" do
      it "handles full lifecycle through controller" do
        # Create with tags
        post "/articles", params: {
          title: "Lifecycle Test",
          status: "draft",
          tags: [ "test", "lifecycle" ]
        }
        json = JSON.parse(response.body)
        article_id = json["id"]

        # Update title
        patch "/articles/#{article_id}", params: { title: "Updated Lifecycle" }

        # Publish
        patch "/articles/#{article_id}", params: {
          status: "published",
          published_at: Time.current.iso8601
        }

        # Archive
        post "/articles/#{article_id}/archive", params: { reason: "Complete" }

        article = Article.find(article_id)

        # Verify all modules worked
        expect(article.title).to eq("Updated Lifecycle")
        expect(article.tags).to include("test", "lifecycle")
        expect(article.is_published?).to be true
        expect(article.archived?).to be true
        expect(article.versions.count).to be >= 3

        # Restore
        post "/articles/#{article_id}/restore"

        article.reload
        expect(article.archived?).to be false
      end
    end
  end
end
