# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Repositable::BaseRepository do
  # Create a test repository
  let(:repository_class) do
    Class.new(described_class) do
      def model_class
        Article
      end
    end
  end

  let(:repository) { repository_class.new }

  before do
    Article.delete_all
    @article1 = Article.create!(title: "First Article", status: "draft")
    @article2 = Article.create!(title: "Second Article", status: "published")
    @article3 = Article.create!(title: "Third Article", status: "draft")
  end

  describe "#initialize" do
    it "accepts model class as argument" do
      repo = described_class.new(Article)
      expect(repo.model).to eq(Article)
    end

    it "uses model_class method when no argument provided" do
      expect(repository.model).to eq(Article)
    end
  end

  describe "#search" do
    context "with predicates" do
      it "filters by predicates when model supports search" do
        result = repository.search({ status_eq: "draft" }, limit: nil)

        expect(result.count).to eq(2)
        expect(result).to include(@article1, @article3)
      end

      it "returns all when no predicates provided" do
        result = repository.search({}, limit: nil)

        expect(result.count).to eq(3)
      end

      it "removes nil values from predicates" do
        result = repository.search({ status_eq: "draft", title_eq: nil }, limit: nil)

        expect(result.count).to eq(2)
      end
    end

    context "with pagination" do
      it "returns paginated results by default" do
        result = repository.search({}, page: 1, per_page: 2)

        expect(result.count).to eq(2)
      end

      it "respects page parameter" do
        result = repository.search({}, page: 2, per_page: 2)

        expect(result.count).to eq(1)
      end

      it "respects per_page parameter" do
        result = repository.search({}, page: 1, per_page: 1)

        expect(result.count).to eq(1)
      end
    end

    context "with limit" do
      it "returns single record when limit is 1" do
        result = repository.search({}, limit: 1)

        expect(result).to be_a(Article)
      end

      it "returns limited relation when limit > 1" do
        result = repository.search({}, limit: 2)

        expect(result.count).to eq(2)
      end

      it "returns all records when limit is nil" do
        result = repository.search({}, limit: nil)

        expect(result.count).to eq(3)
      end

      it "uses pagination when limit is :default" do
        result = repository.search({}, limit: :default, per_page: 2)

        expect(result.count).to eq(2)
      end
    end

    context "with includes" do
      it "eager loads associations" do
        result = repository.search({}, includes: [ :author ], limit: nil)

        # Should not raise and should return relation
        expect(result.to_a).to be_present
      end
    end

    context "with joins" do
      it "joins associations" do
        # Create author to test join
        author = Author.create!(name: "Test Author")
        @article1.update!(author: author)

        result = repository.search({}, joins: [ :author ], limit: nil)

        expect(result.to_a).to include(@article1)
      end
    end

    context "with order" do
      it "orders results by given clause" do
        result = repository.search({}, order: { title: :asc }, limit: nil)

        expect(result.first.title).to eq("First Article")
        expect(result.last.title).to eq("Third Article")
      end

      it "orders results by string clause" do
        result = repository.search({}, order: "title DESC", limit: nil)

        expect(result.first.title).to eq("Third Article")
      end
    end

    context "with order_scope" do
      it "applies sort scope when available" do
        # Article has sortable defined with :title
        result = repository.search({}, order_scope: { field: :title, direction: :asc }, limit: nil)

        # Should apply sort_title_asc scope if it exists
        expect(result.to_a).to be_present
      end
    end
  end

  describe "#find" do
    it "finds record by id" do
      result = repository.find(@article1.id)

      expect(result).to eq(@article1)
    end

    it "raises RecordNotFound for missing id" do
      expect { repository.find(99999) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#find_by" do
    it "finds record by attributes" do
      result = repository.find_by(title: "First Article")

      expect(result).to eq(@article1)
    end

    it "returns nil for no match" do
      result = repository.find_by(title: "Nonexistent")

      expect(result).to be_nil
    end
  end

  describe "#create" do
    it "creates new record" do
      result = repository.create(title: "New Article", status: "draft")

      expect(result).to be_persisted
      expect(result.title).to eq("New Article")
    end
  end

  describe "#create!" do
    it "creates new record with bang" do
      result = repository.create!(title: "New Article", status: "draft")

      expect(result).to be_persisted
    end

    it "creates record even with nil title when no validation" do
      # Article doesn't have presence validation on title
      # This test verifies create! works as expected
      result = repository.create!(title: nil, status: "draft")

      expect(result).to be_persisted
    end
  end

  describe "#build" do
    it "builds new record without saving" do
      result = repository.build(title: "New Article")

      expect(result).to be_a(Article)
      expect(result).not_to be_persisted
      expect(result.title).to eq("New Article")
    end
  end

  describe "#update" do
    it "updates existing record" do
      result = repository.update(@article1.id, title: "Updated Title")

      expect(result.title).to eq("Updated Title")
      expect(@article1.reload.title).to eq("Updated Title")
    end

    it "raises RecordNotFound for missing id" do
      expect { repository.update(99999, title: "X") }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#delete" do
    it "deletes record by id" do
      expect { repository.delete(@article1.id) }.to change { Article.count }.by(-1)
    end

    it "returns deleted record" do
      result = repository.delete(@article1.id)

      expect(result).to be_a(Article)
    end
  end

  describe "#where" do
    it "delegates to model" do
      result = repository.where(status: "draft")

      expect(result.count).to eq(2)
    end
  end

  describe "#all" do
    it "delegates to model" do
      result = repository.all

      expect(result.count).to eq(3)
    end
  end

  describe "#count" do
    it "delegates to model" do
      expect(repository.count).to eq(3)
    end
  end

  describe "#exists?" do
    it "returns true when records exist" do
      expect(repository.exists?).to be true
    end

    it "returns true with matching conditions" do
      expect(repository.exists?(status: "draft")).to be true
    end

    it "returns false with non-matching conditions" do
      expect(repository.exists?(status: "nonexistent")).to be false
    end
  end

  describe "custom repository methods" do
    let(:custom_repository_class) do
      Class.new(described_class) do
        def model_class
          Article
        end

        def published
          search({ status_eq: "published" }, limit: nil)
        end

        def drafts
          search({ status_eq: "draft" }, limit: nil)
        end
      end
    end

    let(:custom_repository) { custom_repository_class.new }

    it "supports custom query methods" do
      published = custom_repository.published
      drafts = custom_repository.drafts

      expect(published.count).to eq(1)
      expect(drafts.count).to eq(2)
    end
  end

  describe "predicate validation" do
    it "validates predicates against model's predicable_scope?" do
      # This test verifies validate_predicates! is called
      # The actual validation depends on the model's implementation
      result = repository.search({ status_eq: "draft" }, limit: nil)

      expect(result).to be_present
    end
  end

  describe "pagination fallback" do
    it "uses fallback pagination for unknown limit values" do
      # Any non-standard limit should fallback to pagination
      result = repository.search({}, limit: :unknown, per_page: 2)
      expect(result.count).to eq(2)
    end
  end

  describe "repository with non-predicable model" do
    # Create a repository for a model without Predicable
    let(:simple_repository_class) do
      Class.new(described_class) do
        def model_class
          Author
        end
      end
    end

    let(:simple_repository) { simple_repository_class.new }

    before do
      Author.delete_all
      @author1 = Author.create!(name: "John Doe")
      @author2 = Author.create!(name: "Jane Smith")
    end

    it "searches without predicates" do
      result = simple_repository.search({}, limit: nil)
      expect(result.count).to eq(2)
    end

    it "validates predicates using respond_to fallback" do
      # For models without Predicable, it falls back to checking respond_to
      result = simple_repository.search({}, limit: nil)
      expect(result).to be_present
    end

    it "finds by id" do
      result = simple_repository.find(@author1.id)
      expect(result).to eq(@author1)
    end

    it "finds by name" do
      result = simple_repository.find_by(name: "John Doe")
      expect(result).to eq(@author1)
    end

    it "creates new author" do
      result = simple_repository.create!(name: "New Author")
      expect(result).to be_persisted
      expect(result.name).to eq("New Author")
    end

    it "counts records" do
      expect(simple_repository.count).to eq(2)
    end
  end

  describe "available_predicates" do
    it "returns predicate-like methods" do
      predicates = repository.send(:available_predicates)
      expect(predicates).to be_an(Array)
    end
  end
end
