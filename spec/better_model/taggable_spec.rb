# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Taggable do
  describe "module inclusion" do
    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Taggable
        end
      end.to raise_error(BetterModel::Errors::Taggable::ConfigurationError, /Invalid configuration/)
    end

    it "initializes taggable configuration as nil" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable
      end

      expect(test_class.taggable_config).to be_nil
    end
  end

  describe "DSL configuration" do
    it "creates configuration with taggable block" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        taggable do
          tag_field :tags
        end
      end

      expect(test_class.taggable_config).not_to be_nil
      expect(test_class.taggable_config.tag_field).to eq(:tags)
    end

    it "validates tag_field exists in table" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Taggable

          taggable do
            tag_field :nonexistent_field
          end
        end
      end.to raise_error(BetterModel::Errors::Taggable::ConfigurationError, /Invalid configuration/)
    end

    it "raises error if taggable called twice" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Taggable

          taggable do
            tag_field :tags
          end

          taggable do
            tag_field :tags
          end
        end
      end.to raise_error(BetterModel::Errors::Taggable::ConfigurationError, /Invalid configuration/)
    end
  end

  describe "tag management" do
    describe "#tag_with" do
      it "adds single tag" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_with("ruby")

        expect(article.tags).to include("ruby")
      end

      it "adds multiple tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_with("ruby", "rails")

        expect(article.tags).to include("ruby")
        expect(article.tags).to include("rails")
      end

      it "does not add duplicate tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_with("ruby")
        article.tag_with("ruby")

        expect(article.tags.count("ruby")).to eq(1)
      end

      it "persists changes to database" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_with("ruby")

        article.reload
        expect(article.tags).to include("ruby")
      end
    end

    describe "#untag" do
      it "removes single tag" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        article.untag("ruby")

        expect(article.tags).not_to include("ruby")
        expect(article.tags).to include("rails")
      end

      it "removes multiple tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails", "python" ])
        article.untag("ruby", "python")

        expect(article.tags).not_to include("ruby")
        expect(article.tags).not_to include("python")
        expect(article.tags).to include("rails")
      end

      it "ignores non-existent tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
        article.untag("python")

        expect(article.tags).to include("ruby")
        expect(article.tags.size).to eq(1)
      end

      it "persists changes to database" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        article.untag("ruby")

        article.reload
        expect(article.tags).not_to include("ruby")
      end
    end

    describe "#retag" do
      it "replaces all existing tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        article.retag("python", "django")

        expect(article.tags).not_to include("ruby")
        expect(article.tags).not_to include("rails")
        expect(article.tags).to include("python")
        expect(article.tags).to include("django")
      end

      it "persists changes to database" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
        article.retag("python")

        article.reload
        expect(article.tags).to include("python")
        expect(article.tags).not_to include("ruby")
      end
    end

    describe "#tagged_with?" do
      it "returns true if tag exists" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])

        expect(article.tagged_with?("ruby")).to be true
      end

      it "returns false if tag missing" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])

        expect(article.tagged_with?("python")).to be false
      end
    end
  end

  describe "tag list (CSV)" do
    describe "#tag_list" do
      it "returns comma-separated string" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails", "tutorial" ])

        expect(article.tag_list).to eq("ruby, rails, tutorial")
      end

      it "returns empty string for no tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")

        expect(article.tag_list).to eq("")
      end

      it "uses custom delimiter if configured" do
        test_class = Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Taggable

          serialize :tags, coder: JSON, type: Array

          taggable do
            tag_field :tags
            delimiter ";"
          end
        end

        article = test_class.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        expect(article.tag_list).to eq("ruby;rails")
      end
    end

    describe "#tag_list=" do
      it "parses comma-separated string" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_list = "ruby, rails, tutorial"

        expect(article.tags).to include("ruby")
        expect(article.tags).to include("rails")
        expect(article.tags).to include("tutorial")
      end

      it "normalizes parsed tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_list = "Ruby, Rails, TUTORIAL"

        expect(article.tags).to include("ruby")
        expect(article.tags).to include("rails")
        expect(article.tags).to include("tutorial")
      end

      it "strips whitespace from tags" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_list = "  ruby  ,  rails  ,  tutorial  "

        expect(article.tags).to include("ruby")
        expect(article.tags).to include("rails")
        expect(article.tags).to include("tutorial")
      end

      it "handles empty string" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
        article.tag_list = ""

        expect(article.tags).to be_empty
      end

      it "persists changes to database" do
        article = Article.create!(title: "Test", content: "Test", status: "draft")
        article.tag_list = "ruby, rails"

        article.reload
        expect(article.tags).to include("ruby")
        expect(article.tags).to include("rails")
      end

      it "handles nil" do
        article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
        article.tag_list = nil

        expect(article.tags).to be_empty
      end
    end
  end

  describe "normalization" do
    it "converts tags to lowercase if normalize enabled" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("Ruby", "RAILS", "TuToRiAl")

      expect(article.tags).to include("ruby")
      expect(article.tags).to include("rails")
      expect(article.tags).to include("tutorial")
    end

    it "preserves case if normalize disabled" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          normalize false
        end
      end

      article = test_class.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("Ruby", "RAILS")

      expect(article.tags).to include("Ruby")
      expect(article.tags).to include("RAILS")
    end

    it "strips leading/trailing whitespace if strip enabled" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("  ruby  ", "  rails  ")

      expect(article.tags).to include("ruby")
      expect(article.tags).to include("rails")
    end

    it "preserves whitespace if strip disabled" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          strip false
          normalize false
        end
      end

      article = test_class.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("  ruby  ", "  rails  ")

      expect(article.tags).to include("  ruby  ")
      expect(article.tags).to include("  rails  ")
    end

    it "skips tags shorter than min_length" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          min_length 3
        end
      end

      article = test_class.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("r", "rb", "ruby")

      expect(article.tags).not_to include("r")
      expect(article.tags).not_to include("rb")
      expect(article.tags).to include("ruby")
    end

    it "truncates tags longer than max_length" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          max_length 5
        end
      end

      article = test_class.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("rubyonrails")

      expect(article.tags).to include("rubyo")
      expect(article.tags).not_to include("rubyonrails")
    end
  end

  describe "validations" do
    it "validates minimum number of tags" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags minimum: 2
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "ruby" ]

      expect(article).not_to be_valid
      expect(article.errors[:tags]).to include("must have at least 2 tags")
    end

    it "validates maximum number of tags" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags maximum: 3
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "ruby", "rails", "python", "django" ]

      expect(article).not_to be_valid
      expect(article.errors[:tags]).to include("must have at most 3 tags")
    end

    it "validates tags against whitelist (allowed_tags)" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags allowed_tags: [ "ruby", "rails", "python", "django" ]
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "ruby", "javascript" ]

      expect(article).not_to be_valid
      expect(article.errors[:tags]).to include("contains invalid tags: javascript")
    end

    it "validates tags against blacklist (forbidden_tags)" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags forbidden_tags: [ "spam", "nsfw", "banned" ]
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "ruby", "spam" ]

      expect(article).not_to be_valid
      expect(article.errors[:tags]).to include("contains forbidden tags: spam")
    end
  end

  describe "statistics" do
    describe ".tag_counts" do
      it "returns hash of tag frequencies" do
        Article.delete_all
        Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "python" ])
        Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby" ])

        counts = Article.tag_counts

        expect(counts["ruby"]).to eq(3)
        expect(counts["rails"]).to eq(1)
        expect(counts["python"]).to eq(1)
      end

      it "handles empty results" do
        Article.delete_all

        counts = Article.tag_counts

        expect(counts).to be_empty
      end
    end

    describe ".popular_tags" do
      it "returns top N tags by frequency" do
        Article.delete_all
        Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails", "tutorial" ])
        Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "python" ])
        Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby" ])

        popular = Article.popular_tags(limit: 2)

        expect(popular.size).to eq(2)
        expect(popular.first).to eq([ "ruby", 3 ])
      end

      it "returns array of [tag, count] pairs" do
        Article.delete_all
        Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])

        popular = Article.popular_tags(limit: 10)

        expect(popular).to be_a(Array)
        expect(popular.first).to be_a(Array)
        expect(popular.first.size).to eq(2)
      end

      it "returns empty array if no tags" do
        Article.delete_all

        popular = Article.popular_tags(limit: 10)

        expect(popular).to be_empty
      end
    end

    describe ".related_tags" do
      it "finds tags that appear together" do
        Article.delete_all
        Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails", "activerecord" ])
        Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby", "sinatra" ])

        related = Article.related_tags("ruby")

        expect(related).to include("rails")
        expect(related).to include("activerecord")
        expect(related).to include("sinatra")
      end

      it "excludes the query tag itself" do
        Article.delete_all
        Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])

        related = Article.related_tags("ruby")

        expect(related).not_to include("ruby")
      end

      it "orders by frequency" do
        Article.delete_all
        Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
        Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby", "python" ])

        related = Article.related_tags("ruby")

        expect(related.first).to eq("rails")
      end

      it "respects limit parameter" do
        Article.delete_all
        Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "a", "b", "c", "d" ])

        related = Article.related_tags("ruby", limit: 2)

        expect(related.size).to eq(2)
      end
    end
  end

  describe "#as_json" do
    it "includes tags by default" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      json = article.as_json

      expect(json.keys).to include("tags")
      expect(json["tags"]).to eq([ "ruby", "rails" ])
    end

    it "includes tag_list as string" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      json = article.as_json(include_tag_list: true)

      expect(json.keys).to include("tag_list")
      expect(json["tag_list"]).to eq("ruby, rails")
    end

    it "includes tag statistics" do
      Article.delete_all
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      json = article.as_json(include_tag_stats: true)

      expect(json.keys).to include("tag_stats")
      expect(json["tag_stats"]).to be_a(Hash)
      expect(json["tag_stats"]["count"]).to eq(2)
    end
  end

  describe "thread safety" do
    it "freezes configuration after creation" do
      expect(Article.taggable_config).to be_frozen
    end

    it "does not allow modification of config after freezing" do
      expect do
        Article.taggable_config.instance_variable_set(:@normalize, false)
      end.to raise_error(FrozenError)
    end
  end

  describe "edge cases" do
    it "handles nil tags gracefully" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with(nil)

      expect(article.tags).to be_empty
    end

    it "handles empty string tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("")

      expect(article.tags).to be_empty
    end

    it "handles tags with special characters" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("c++", "ruby/rails", "node.js")

      expect(article.tags).to include("c++")
      expect(article.tags).to include("ruby/rails")
      expect(article.tags).to include("node.js")
    end

    it "handles unicode tags (emoji)" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby❤️", "🚀rails")

      expect(article.tags).to include("ruby❤️")
      expect(article.tags).to include("🚀rails")
    end

    it "handles unicode tags (chinese)" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("红宝石", "导轨")

      expect(article.tags).to include("红宝石")
      expect(article.tags).to include("导轨")
    end

    it "handles very long tag strings" do
      long_tag = "a" * 100
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with(long_tag)

      expect(article.tags).to include(long_tag)
    end

    it "handles whitespace-only tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("   ", "\t", "\n")

      expect(article.tags).to be_empty
    end

    it "handles array with nil values" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby", nil, "rails", nil)

      expect(article.tags.size).to eq(2)
      expect(article.tags).to include("ruby")
      expect(article.tags).to include("rails")
    end

    it "handles mixed case normalization consistently" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("Ruby")
      article.tag_with("RUBY")
      article.tag_with("ruby")

      expect(article.tags.size).to eq(1)
      expect(article.tags).to eq([ "ruby" ])
    end
  end

  describe "integration" do
    it "works with Statusable" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])

      expect(article.is?(:draft)).to be true
      expect(article.tagged_with?("ruby")).to be true
    end

    it "works with Permissible" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])

      expect(article.permit?(:edit)).to be true
      expect(article.tagged_with?("ruby")).to be true
    end

    it "works with Sortable scopes" do
      Article.delete_all
      a1 = Article.create!(title: "A", content: "Test", status: "draft", tags: [ "ruby" ])
      Article.create!(title: "B", content: "Test", status: "draft", tags: [ "python" ])

      sorted = Article.sort_title_asc.to_a
      expect(sorted.first.id).to eq(a1.id)
      expect(sorted.first.tags).to include("ruby")
    end

    it "tags field is predicable" do
      expect(Article.predicable_field?(:tags)).to be true
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Taggable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Taggable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Taggable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Taggable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end
end
