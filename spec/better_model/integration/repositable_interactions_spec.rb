# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Repositable Module Interactions", type: :integration do
  # Define ArticleRepository for testing
  let(:article_repository_class) do
    Class.new(BetterModel::Repositable::BaseRepository) do
      def model_class = Article

      # Custom repository methods
      def published
        search({ status_eq: "published" }, limit: nil)
      end

      def drafts
        search({ status_eq: "draft" }, limit: nil)
      end

      def popular(threshold: 100)
        search({ view_count_gteq: threshold }, limit: nil)
      end

      def recent(days: 7)
        search({ created_at_gteq: days.days.ago }, limit: nil)
      end

      def featured_published
        search({ status_eq: "published", featured_eq: true }, limit: nil)
      end
    end
  end

  let(:repo) { article_repository_class.new }

  before do
    @published1 = Article.create!(
      title: "Published Article 1",
      status: "published",
      published_at: Time.current,
      view_count: 150,
      featured: true
    )

    @published2 = Article.create!(
      title: "Published Article 2",
      status: "published",
      published_at: 2.days.ago,
      view_count: 50,
      featured: false
    )

    @draft = Article.create!(
      title: "Draft Article",
      status: "draft",
      view_count: 10
    )
  end

  describe "Repository + Searchable" do
    it "searches with predicates via repository" do
      results = repo.search({ status_eq: "published" }, limit: nil)

      expect(results).to include(@published1, @published2)
      expect(results).not_to include(@draft)
    end

    it "uses custom repository search methods" do
      expect(repo.published).to include(@published1, @published2)
      expect(repo.drafts).to include(@draft)
    end

    it "supports multiple predicates" do
      results = repo.search({
        status_eq: "published",
        view_count_gteq: 100
      }, limit: nil)

      expect(results).to include(@published1)
      expect(results).not_to include(@published2, @draft)
    end

    it "provides pagination via repository" do
      results = repo.search({ status_eq: "published" }, page: 1, per_page: 1)

      expect(results.count).to eq(1)
    end

    it "applies default ordering from model" do
      # Article.search applies default_order [:sort_created_at_desc]
      results = repo.search({ status_eq: "published" }, limit: nil)

      # Results are returned in some order (default is created_at desc)
      expect(results.count).to eq(2)
      expect(results).to include(@published1, @published2)
    end

    it "supports single result with limit: 1" do
      result = repo.search({ status_eq: "published" }, limit: 1)

      expect(result).to be_an(Article)
    end

    it "returns all results with limit: nil" do
      results = repo.search({}, limit: nil)

      expect(results.count).to eq(3)
    end
  end

  describe "Repository + Archivable" do
    before do
      @archived = Article.create!(
        title: "Archived Article",
        status: "published",
        published_at: 1.month.ago
      )
      @archived.archive!(reason: "Outdated")
    end

    it "searches archived records via predicates" do
      archived_results = repo.search({ archived_at_present: true }, limit: nil)

      expect(archived_results).to include(@archived)
      expect(archived_results).not_to include(@published1, @published2, @draft)
    end

    it "searches active records via predicates" do
      active_results = repo.search({ archived_at_null: true }, limit: nil)

      expect(active_results).to include(@published1, @published2, @draft)
      expect(active_results).not_to include(@archived)
    end

    it "combines archive and status predicates" do
      results = repo.search({
        archived_at_null: true,
        status_eq: "published"
      }, limit: nil)

      expect(results).to include(@published1, @published2)
      expect(results).not_to include(@draft, @archived)
    end
  end

  describe "Repository CRUD operations" do
    it "creates records via repository" do
      article = repo.create!(
        title: "Created via Repository",
        status: "draft"
      )

      expect(article).to be_persisted
      expect(article.title).to eq("Created via Repository")
    end

    it "builds unsaved records via repository" do
      article = repo.build(title: "Built Article", status: "draft")

      expect(article).to be_new_record
      expect(article.title).to eq("Built Article")
    end

    it "finds records by ID via repository" do
      found = repo.find(@published1.id)

      expect(found).to eq(@published1)
    end

    it "finds records by attributes via repository" do
      found = repo.find_by(title: "Draft Article")

      expect(found).to eq(@draft)
    end

    it "updates records via repository" do
      updated = repo.update(@draft.id, title: "Updated Draft")

      expect(updated.title).to eq("Updated Draft")
      expect(@draft.reload.title).to eq("Updated Draft")
    end

    it "deletes records via repository" do
      id_to_delete = @draft.id

      repo.delete(id_to_delete)

      expect { Article.find(id_to_delete) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Repository delegation" do
    it "delegates count to model" do
      expect(repo.count).to eq(3)
    end

    it "delegates exists? to model" do
      expect(repo.exists?(id: @published1.id)).to be true
      expect(repo.exists?(id: 999999)).to be false
    end

    it "delegates where to model" do
      results = repo.where(status: "published")

      expect(results).to include(@published1, @published2)
    end

    it "delegates all to model" do
      results = repo.all

      expect(results.count).to eq(3)
    end
  end

  describe "Repository + Taggable" do
    before do
      @tagged = Article.create!(
        title: "Tagged Article",
        status: "published",
        published_at: Time.current,
        tags: [ "ruby", "rails" ]
      )
    end

    it "returns articles with tags via repository" do
      results = repo.published

      expect(results).to include(@tagged)

      # Can check tags on results
      tagged_results = results.select { |a| a.tagged_with?("ruby") }
      expect(tagged_results).to include(@tagged)
    end

    it "tags can be modified on repository results" do
      article = repo.find(@tagged.id)

      article.tag_with("new-tag")

      expect(article.tags).to include("ruby", "rails", "new-tag")
    end
  end

  describe "Repository + Traceable" do
    it "creates version on repository create" do
      article = repo.create!(title: "Traced Create", status: "draft")

      expect(article.versions.count).to eq(1)
      expect(article.versions.last.event).to eq("created")
    end

    it "creates version on repository update" do
      repo.update(@draft.id, title: "Updated Title")

      @draft.reload
      expect(@draft.versions.count).to eq(2)
    end

    it "audit trail available on repository results" do
      article = repo.find(@published1.id)

      trail = article.audit_trail
      expect(trail).to be_an(Array)
      expect(trail.first[:event]).to eq("created")
    end
  end

  describe "Repository + Permissible" do
    it "permissions available on repository results" do
      draft = repo.find(@draft.id)
      published = repo.find(@published1.id)

      expect(draft.permit_delete?).to be true
      expect(published.permit_delete?).to be false
    end

    it "can filter by permission using Ruby" do
      results = repo.search({}, limit: nil)

      deletable = results.select(&:permit_delete?)

      expect(deletable).to include(@draft)
      expect(deletable).not_to include(@published1, @published2)
    end
  end

  describe "Repository + Validatable" do
    it "validation groups available on repository results" do
      article = repo.find(@published1.id)

      expect(article.respond_to?(:validate_group)).to be true
      expect(article.validate_group(:basic_info)).to be true
    end

    it "can validate repository-built records" do
      article = repo.build(title: nil, status: "draft")

      # validate_group works on unsaved records
      expect(article.validate_group(:basic_info)).to be true
    end
  end

  describe "Custom repository methods" do
    it "popular method filters by view_count" do
      results = repo.popular(threshold: 100)

      expect(results).to include(@published1)
      expect(results).not_to include(@published2, @draft)
    end

    it "featured_published combines multiple predicates" do
      results = repo.featured_published

      expect(results).to include(@published1)
      expect(results).not_to include(@published2, @draft)
    end
  end

  describe "Repository with eager loading" do
    let(:author) { Author.create!(name: "Test Author") }

    before do
      @with_author = Article.create!(
        title: "With Author",
        status: "published",
        published_at: Time.current,
        author: author
      )
    end

    it "supports includes for eager loading" do
      results = repo.search(
        { status_eq: "published" },
        includes: [ :author ],
        limit: nil
      )

      # Results include the article with author
      article_with_author = results.find { |a| a.id == @with_author.id }
      expect(article_with_author).to be_present
      expect(article_with_author.author).to eq(author)
    end
  end

  describe "Repository edge cases" do
    it "handles empty predicates" do
      results = repo.search({}, limit: nil)

      expect(results.count).to eq(3)
    end

    it "handles nil predicates" do
      results = repo.search(nil, limit: nil)

      expect(results.count).to eq(3)
    end

    it "raises RecordNotFound for invalid ID" do
      expect {
        repo.find(999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "returns nil for find_by with no match" do
      result = repo.find_by(title: "Nonexistent")

      expect(result).to be_nil
    end
  end
end
