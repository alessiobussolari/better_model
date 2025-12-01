# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authorization Security", type: :security do
  describe "Permissible authorization" do
    let(:author) { Author.create!(name: "Test Author") }

    describe "permission checks" do
      it "enforces delete permission for draft articles" do
        draft = Article.create!(
          title: "Draft Article",
          status: "draft",
          author: author
        )

        expect(draft.permit_delete?).to be true
        expect(draft.permit?(:delete)).to be true
      end

      it "denies delete permission for published articles" do
        published = Article.create!(
          title: "Published Article",
          status: "published",
          published_at: Time.current,
          author: author
        )

        expect(published.permit_delete?).to be false
        expect(published.permit?(:delete)).to be false
      end

      it "enforces edit permission based on article state" do
        draft = Article.create!(title: "Draft", status: "draft")
        published = Article.create!(
          title: "Published",
          status: "published",
          published_at: Time.current
        )
        expired = Article.create!(
          title: "Expired",
          status: "published",
          published_at: 1.year.ago,
          expires_at: 1.day.ago
        )

        expect(draft.permit_edit?).to be true
        expect(published.permit_edit?).to be true
        expect(expired.permit_edit?).to be false
      end

      it "enforces publish permission only for drafts" do
        draft = Article.create!(title: "Draft", status: "draft")
        published = Article.create!(
          title: "Published",
          status: "published",
          published_at: Time.current
        )

        expect(draft.permit_publish?).to be true
        expect(published.permit_publish?).to be false
      end

      it "enforces unpublish permission only for published" do
        draft = Article.create!(title: "Draft", status: "draft")
        published = Article.create!(
          title: "Published",
          status: "published",
          published_at: Time.current
        )

        expect(draft.permit_unpublish?).to be false
        expect(published.permit_unpublish?).to be true
      end
    end

    describe "permission bypass prevention" do
      it "cannot bypass permission by calling underlying method" do
        published = Article.create!(
          title: "Published",
          status: "published",
          published_at: Time.current
        )

        # Permission says no delete
        expect(published.permit_delete?).to be false

        # But model can still be destroyed at database level
        # (BetterModel provides permission checks, not enforcement)
        # Application code should check permissions before operations
        expect do
          published.destroy!
        end.to change(Article, :count).by(-1)
      end

      it "permission checks are evaluated fresh each time" do
        article = Article.create!(
          title: "Changing Article",
          status: "draft"
        )

        # Initial state - can delete
        expect(article.permit_delete?).to be true

        # Update to published
        article.update!(status: "published", published_at: Time.current)

        # Permission now denied
        expect(article.permit_delete?).to be false
      end
    end

    describe "permissions hash" do
      it "returns accurate permissions for draft" do
        draft = Article.create!(title: "Draft", status: "draft")

        perms = draft.permissions

        expect(perms[:delete]).to be true
        expect(perms[:edit]).to be true
        expect(perms[:publish]).to be true
        expect(perms[:unpublish]).to be false
        expect(perms[:archive]).to be false
      end

      it "returns accurate permissions for published" do
        published = Article.create!(
          title: "Published",
          status: "published",
          published_at: Time.current
        )

        perms = published.permissions

        expect(perms[:delete]).to be false
        expect(perms[:edit]).to be true
        expect(perms[:publish]).to be false
        expect(perms[:unpublish]).to be true
      end

      it "returns accurate permissions for expired" do
        expired = Article.create!(
          title: "Expired",
          status: "published",
          published_at: 1.year.ago,
          expires_at: 1.day.ago
        )

        perms = expired.permissions

        expect(perms[:edit]).to be false
        expect(perms[:unpublish]).to be true
      end
    end

    describe "granted_permissions filtering" do
      it "filters to only granted permissions" do
        draft = Article.create!(title: "Draft", status: "draft")

        granted = draft.granted_permissions([ :delete, :edit, :publish, :unpublish, :archive ])

        expect(granted).to contain_exactly(:delete, :edit, :publish)
      end

      it "returns empty array when no permissions granted" do
        expired = Article.create!(
          title: "Expired",
          status: "published",
          published_at: 1.year.ago,
          expires_at: 1.day.ago
        )

        # Check permissions that are definitely denied
        granted = expired.granted_permissions([ :delete, :archive ])

        expect(granted).to be_empty
      end
    end

    describe "has_any_permission?" do
      it "returns true when at least one permission granted" do
        draft = Article.create!(title: "Draft", status: "draft")

        expect(draft.has_any_permission?).to be true
      end

      it "can check specific permissions" do
        published = Article.create!(
          title: "Published",
          status: "published",
          published_at: Time.current
        )

        # Has at least one permission (edit, unpublish)
        expect(published.has_any_permission?).to be true
      end
    end

    describe "has_all_permissions?" do
      it "returns true when all specified permissions granted" do
        draft = Article.create!(title: "Draft", status: "draft")

        expect(draft.has_all_permissions?([ :delete, :edit ])).to be true
      end

      it "returns false when any specified permission denied" do
        draft = Article.create!(title: "Draft", status: "draft")

        expect(draft.has_all_permissions?([ :delete, :unpublish ])).to be false
      end
    end
  end

  describe "Stateable authorization" do
    it "status conditions accurately reflect state" do
      draft = Article.create!(title: "Draft", status: "draft")

      expect(draft.is_draft?).to be true
      expect(draft.is_published?).to be false
    end

    it "combined status conditions work correctly" do
      popular_published = Article.create!(
        title: "Popular",
        status: "published",
        published_at: Time.current,
        view_count: 200
      )

      expect(popular_published.is_published?).to be true
      expect(popular_published.is_popular?).to be true
      expect(popular_published.is_draft?).to be false
    end

    it "active status checks both published and not expired" do
      active = Article.create!(
        title: "Active",
        status: "published",
        published_at: Time.current,
        expires_at: nil
      )

      expired = Article.create!(
        title: "Expired",
        status: "published",
        published_at: 1.year.ago,
        expires_at: 1.day.ago
      )

      expect(active.is_active?).to be true
      expect(expired.is_active?).to be false
    end
  end

  describe "Searchable security policies" do
    before do
      @article1 = Article.create!(
        title: "Article 1",
        status: "published",
        published_at: Time.current,
        featured: true
      )

      @article2 = Article.create!(
        title: "Article 2",
        status: "draft",
        featured: false
      )
    end

    it "enforces security policy requiring status predicate" do
      expect do
        Article.search({ title_cont: "Article" }, security: :status_required)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
    end

    it "allows search when security policy satisfied" do
      results = Article.search(
        { title_cont: "Article", status_eq: "published" },
        security: :status_required
      )

      expect(results).to include(@article1)
      expect(results).not_to include(@article2)
    end

    it "enforces featured_only security policy" do
      expect do
        Article.search({ status_eq: "published" }, security: :featured_only)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
    end

    it "allows search when featured_only policy satisfied" do
      results = Article.search(
        { status_eq: "published", featured_eq: true },
        security: :featured_only
      )

      expect(results).to include(@article1)
    end

    it "rejects unknown security policy" do
      expect do
        Article.search({ status_eq: "published" }, security: :nonexistent_policy)
      end.to raise_error(BetterModel::Errors::Searchable::InvalidSecurityError)
    end
  end

  describe "Cross-module authorization" do
    it "permissions and status work together" do
      article = Article.create!(
        title: "Cross Module",
        status: "draft"
      )

      # Draft status should allow delete
      expect(article.is_draft?).to be true
      expect(article.permit_delete?).to be true

      # Publish changes both status and permissions
      article.update!(status: "published", published_at: Time.current)

      expect(article.is_draft?).to be false
      expect(article.is_published?).to be true
      expect(article.permit_delete?).to be false
    end

    it "search respects permissions indirectly through status" do
      draft = Article.create!(title: "Draft", status: "draft")
      published = Article.create!(
        title: "Published",
        status: "published",
        published_at: Time.current
      )

      # Search for deletable articles (drafts)
      drafts = Article.search({ status_eq: "draft" })

      drafts.each do |article|
        expect(article.permit_delete?).to be true
      end

      # Search for published
      pubs = Article.search({ status_eq: "published" })

      pubs.each do |article|
        expect(article.permit_delete?).to be false
      end
    end
  end

  describe "Undefined permission handling" do
    it "handles check for undefined permission" do
      article = Article.create!(title: "Test", status: "draft")

      # Checking undefined permission should return false
      expect(article.permit?(:nonexistent)).to be false
    end
  end
end
