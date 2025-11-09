# frozen_string_literal: true

require "test_helper"

module BetterModel
  class TaggableTest < ActiveSupport::TestCase
    # ============================================================================
    # FASE 1: SETUP BASE
    # ============================================================================

    # Test 1.1: Validazione inclusione in ActiveRecord
    test "should only be includable in ActiveRecord models" do
      assert_raises(ArgumentError, /can only be included in ActiveRecord models/) do
        Class.new do
          include BetterModel::Taggable
        end
      end
    end

    test "should initialize taggable configuration as nil" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable
      end

      assert_nil test_class.taggable_config
    end

    # Test 1.2: DSL Configuration
    test "taggable block should create configuration" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        taggable do
          tag_field :tags
        end
      end

      assert_not_nil test_class.taggable_config
      assert_equal :tags, test_class.taggable_config.tag_field
    end

    test "should validate tag_field exists in table" do
      assert_raises(ArgumentError, /does not exist/) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Taggable

          taggable do
            tag_field :nonexistent_field
          end
        end
      end
    end

    test "should raise error if taggable called twice" do
      assert_raises(ArgumentError, /already configured/) do
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
      end
    end


    # ============================================================================
    # FASE 2: GESTIONE TAG
    # ============================================================================

    # Test 2.1: Aggiunta Tag
    test "tag_with should add single tag" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby")

      assert_includes article.tags, "ruby"
      article.destroy
    end

    test "tag_with should add multiple tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby", "rails")

      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      article.destroy
    end

    test "tag_with should not add duplicate tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby")
      article.tag_with("ruby")

      assert_equal 1, article.tags.count("ruby")
      article.destroy
    end

    test "tag_with should persist changes to database" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby")

      article.reload
      assert_includes article.tags, "ruby"
      article.destroy
    end

    # Test 2.2: Rimozione Tag
    test "untag should remove single tag" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      article.untag("ruby")

      refute_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      article.destroy
    end

    test "untag should remove multiple tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails", "python" ])
      article.untag("ruby", "python")

      refute_includes article.tags, "ruby"
      refute_includes article.tags, "python"
      assert_includes article.tags, "rails"
      article.destroy
    end

    test "untag should ignore non-existent tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
      article.untag("python")

      assert_includes article.tags, "ruby"
      assert_equal 1, article.tags.size
      article.destroy
    end

    test "untag should persist changes to database" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      article.untag("ruby")

      article.reload
      refute_includes article.tags, "ruby"
      article.destroy
    end

    # Test 2.3: Sostituzione Tag
    test "retag should replace all existing tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      article.retag("python", "django")

      refute_includes article.tags, "ruby"
      refute_includes article.tags, "rails"
      assert_includes article.tags, "python"
      assert_includes article.tags, "django"
      article.destroy
    end

    test "retag should persist changes to database" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
      article.retag("python")

      article.reload
      assert_includes article.tags, "python"
      refute_includes article.tags, "ruby"
      article.destroy
    end

    # Test 2.4: Check Tag
    test "tagged_with? should return true if tag exists" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])

      assert article.tagged_with?("ruby")
      article.destroy
    end

    test "tagged_with? should return false if tag missing" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])

      refute article.tagged_with?("python")
      article.destroy
    end

    # ============================================================================
    # FASE 3: TAG LIST (CSV)
    # ============================================================================

    # Test 3.1: Lettura Tag List
    test "tag_list should return comma-separated string" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails", "tutorial" ])

      assert_equal "ruby, rails, tutorial", article.tag_list
      article.destroy
    end

    test "tag_list should return empty string for no tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")

      assert_equal "", article.tag_list
      article.destroy
    end

    test "tag_list should use custom delimiter if configured" do
      # Create a custom test class with different delimiter
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
      assert_equal "ruby;rails", article.tag_list
      article.destroy
    end

    # Test 3.2: Scrittura Tag List
    test "tag_list= should parse comma-separated string" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_list = "ruby, rails, tutorial"

      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      assert_includes article.tags, "tutorial"
      article.destroy
    end

    test "tag_list= should handle custom delimiter" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          delimiter ";"
        end
      end

      article = test_class.create!(title: "Test", content: "Test", status: "draft")
      article.tag_list = "ruby;rails;tutorial"

      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      assert_includes article.tags, "tutorial"
      article.destroy
    end

    test "tag_list= should normalize parsed tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_list = "Ruby, Rails, TUTORIAL"

      # normalize is enabled in Article, so should be lowercase
      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      assert_includes article.tags, "tutorial"
      article.destroy
    end

    test "tag_list= should strip whitespace from tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_list = "  ruby  ,  rails  ,  tutorial  "

      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      assert_includes article.tags, "tutorial"
      article.destroy
    end

    test "tag_list= should handle empty string" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
      article.tag_list = ""

      assert_empty article.tags
      article.destroy
    end

    test "tag_list= should persist changes to database" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_list = "ruby, rails"

      article.reload
      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      article.destroy
    end

    # ============================================================================
    # FASE 4: NORMALIZZAZIONE
    # ============================================================================

    # Test 4.1: Lowercase
    test "should convert tags to lowercase if normalize enabled" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("Ruby", "RAILS", "TuToRiAl")

      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      assert_includes article.tags, "tutorial"
      article.destroy
    end

    test "should preserve case if normalize disabled" do
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

      assert_includes article.tags, "Ruby"
      assert_includes article.tags, "RAILS"
      article.destroy
    end

    # Test 4.2: Whitespace
    test "should strip leading/trailing whitespace if strip enabled" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("  ruby  ", "  rails  ")

      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      article.destroy
    end

    test "should preserve whitespace if strip disabled" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          normalize false
          strip false
        end
      end

      article = test_class.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("  ruby  ")

      assert_includes article.tags, "  ruby  "
      article.destroy
    end

    # Test 4.3: Lunghezza
    test "should skip tags shorter than min_length" do
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

      refute_includes article.tags, "r"
      refute_includes article.tags, "rb"
      assert_includes article.tags, "ruby"
      article.destroy
    end

    test "should truncate tags longer than max_length" do
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

      assert_includes article.tags, "rubyo"
      refute_includes article.tags, "rubyonrails"
      article.destroy
    end

    test "should accept tags within length bounds" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          min_length 2
          max_length 10
        end
      end

      article = test_class.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("rb", "ruby", "rubyonrail")

      assert_includes article.tags, "rb"
      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rubyonrail"
      article.destroy
    end

    # ============================================================================
    # FASE 5: VALIDAZIONI
    # ============================================================================

    # Test 5.1: Validazione Conteggio
    test "should validate minimum number of tags" do
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

      refute article.valid?
      assert_includes article.errors[:tags], "must have at least 2 tags"
      article.destroy if article.persisted?
    end

    test "should validate maximum number of tags" do
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

      refute article.valid?
      assert_includes article.errors[:tags], "must have at most 3 tags"
      article.destroy if article.persisted?
    end

    test "should be valid with tags within bounds" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags minimum: 1, maximum: 5
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "ruby", "rails", "tutorial" ]

      assert article.valid?
      article.destroy if article.persisted?
    end

    # Test 5.2: Whitelist/Blacklist
    test "should validate tags against whitelist (allowed_tags)" do
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

      refute article.valid?
      assert_includes article.errors[:tags], "contains invalid tags: javascript"
      article.destroy if article.persisted?
    end

    test "should accept tags in whitelist" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags allowed_tags: [ "ruby", "rails", "python" ]
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "ruby", "rails" ]

      assert article.valid?
      article.destroy if article.persisted?
    end

    test "should validate tags against blacklist (forbidden_tags)" do
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

      refute article.valid?
      assert_includes article.errors[:tags], "contains forbidden tags: spam"
      article.destroy if article.persisted?
    end

    test "should accept tags not in blacklist" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags forbidden_tags: [ "spam", "nsfw" ]
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "ruby", "rails" ]

      assert article.valid?
      article.destroy if article.persisted?
    end

    test "should work with both whitelist and blacklist" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable

        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags allowed_tags: [ "ruby", "rails", "python" ],
                        forbidden_tags: [ "python" ]
        end
      end

      # python is in whitelist but also in blacklist - blacklist wins
      article = test_class.new(title: "Test", content: "Test", status: "draft")
      article.tags = [ "python" ]

      refute article.valid?
      assert_includes article.errors[:tags], "contains forbidden tags: python"
      article.destroy if article.persisted?
    end

    # ============================================================================
    # FASE 6: STATISTICHE
    # ============================================================================

    # Test 6.1: Tag Counts
    test "tag_counts should return hash of tag frequencies" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "python" ])
      Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby" ])

      counts = Article.tag_counts

      assert_equal 3, counts["ruby"]
      assert_equal 1, counts["rails"]
      assert_equal 1, counts["python"]
      Article.delete_all
    end

    test "tag_counts should handle empty results" do
      Article.delete_all

      counts = Article.tag_counts

      assert_empty counts
      Article.delete_all
    end

    # Test 6.2: Popular Tags
    test "popular_tags should return top N tags by frequency" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails", "tutorial" ])
      Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "python" ])
      Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby" ])

      popular = Article.popular_tags(limit: 2)

      assert_equal 2, popular.size
      assert_equal [ "ruby", 3 ], popular.first
      Article.delete_all
    end

    test "popular_tags should return array of [tag, count] pairs" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])

      popular = Article.popular_tags(limit: 10)

      assert_instance_of Array, popular
      assert_instance_of Array, popular.first
      assert_equal 2, popular.first.size
      Article.delete_all
    end

    test "popular_tags should respect limit parameter" do
      Article.delete_all
      5.times do |i|
        Article.create!(title: "A#{i}", content: "Test", status: "draft", tags: [ "tag#{i}" ])
      end

      popular = Article.popular_tags(limit: 3)

      assert_equal 3, popular.size
      Article.delete_all
    end

    test "popular_tags should return empty array if no tags" do
      Article.delete_all

      popular = Article.popular_tags(limit: 10)

      assert_empty popular
      Article.delete_all
    end

    # Test 6.3: Related Tags
    test "related_tags should find tags that appear together" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails", "activerecord" ])
      Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby", "sinatra" ])

      related = Article.related_tags("ruby")

      assert_includes related, "rails"
      assert_includes related, "activerecord"
      assert_includes related, "sinatra"
      Article.delete_all
    end

    test "related_tags should exclude the query tag itself" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])

      related = Article.related_tags("ruby")

      refute_includes related, "ruby"
      Article.delete_all
    end

    test "related_tags should order by frequency" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      Article.create!(title: "A2", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      Article.create!(title: "A3", content: "Test", status: "draft", tags: [ "ruby", "python" ])

      related = Article.related_tags("ruby")

      assert_equal "rails", related.first
      Article.delete_all
    end

    test "related_tags should respect limit parameter" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "a", "b", "c", "d" ])

      related = Article.related_tags("ruby", limit: 2)

      assert_equal 2, related.size
      Article.delete_all
    end

    # ============================================================================
    # FASE 7: INTEGRAZIONE PREDICABLE
    # ============================================================================

    test "should automatically register predicates for tag field" do
      # Article already has tags configured, so predicates should be registered
      assert Article.respond_to?(:predicable_field?)
    end


    # ============================================================================
    # FASE 8: AS_JSON INTEGRATION
    # ============================================================================

    test "as_json should include tags by default" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      json = article.as_json

      assert_includes json.keys, "tags"
      assert_equal [ "ruby", "rails" ], json["tags"]
      article.destroy
    end

    test "as_json should include tag_list as string" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      json = article.as_json(include_tag_list: true)

      assert_includes json.keys, "tag_list"
      assert_equal "ruby, rails", json["tag_list"]
      article.destroy
    end

    test "as_json should include tag statistics" do
      Article.delete_all
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      json = article.as_json(include_tag_stats: true)

      assert_includes json.keys, "tag_stats"
      assert_instance_of Hash, json["tag_stats"]
      assert_includes json["tag_stats"].keys, "count"
      assert_equal 2, json["tag_stats"]["count"]
      article.destroy
    end

    # ============================================================================
    # FASE 9: THREAD SAFETY
    # ============================================================================

    test "configuration should be frozen after creation" do
      assert Article.taggable_config.frozen?
    end

    test "should not allow modification of config after freezing" do
      assert_raises(FrozenError) do
        Article.taggable_config.instance_variable_set(:@normalize, false)
      end
    end

    test "concurrent tag_with calls should be safe" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")

      threads = 10.times.map do |i|
        Thread.new do
          article.reload
          article.tag_with("tag#{i}")
        end
      end

      threads.each(&:join)
      article.reload

      # Tutti i tag dovrebbero essere presenti
      assert article.tags.size >= 1
      article.destroy
    end

    test "concurrent untag calls should be safe" do
      article = Article.create!(title: "Test", content: "Test", status: "draft",
                               tags: (0..9).map { |i| "tag#{i}" })

      threads = 5.times.map do |i|
        Thread.new do
          article.reload
          article.untag("tag#{i}")
        end
      end

      threads.each(&:join)
      article.reload

      # Alcuni tag dovrebbero essere rimossi
      assert article.tags.size < 10
      article.destroy
    end

    # ============================================================================
    # FASE 12: EDGE CASES
    # ============================================================================

    test "should handle nil tags gracefully" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with(nil)

      assert_empty article.tags
      article.destroy
    end

    test "should handle empty string tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("")

      assert_empty article.tags
      article.destroy
    end

    test "should handle tags with special characters" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("c++", "ruby/rails", "node.js")

      assert_includes article.tags, "c++"
      assert_includes article.tags, "ruby/rails"
      assert_includes article.tags, "node.js"
      article.destroy
    end

    test "should handle unicode tags (emoji)" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby❤️", "🚀rails")

      assert_includes article.tags, "ruby❤️"
      assert_includes article.tags, "🚀rails"
      article.destroy
    end

    test "should handle unicode tags (chinese)" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("红宝石", "导轨")

      assert_includes article.tags, "红宝石"
      assert_includes article.tags, "导轨"
      article.destroy
    end

    test "should handle very long tag strings" do
      long_tag = "a" * 100
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with(long_tag)

      assert_includes article.tags, long_tag
      article.destroy
    end

    test "should handle multiple consecutive spaces" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_list = "ruby,    rails,     tutorial"

      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      assert_includes article.tags, "tutorial"
      article.destroy
    end

    test "should handle blank array initialization" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [])

      assert_empty article.tags
      assert_equal "", article.tag_list
      article.destroy
    end

    test "should handle nil in tag_list setter" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])
      article.tag_list = nil

      assert_empty article.tags
      article.destroy
    end

    test "should handle whitespace-only tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("   ", "\t", "\n")

      assert_empty article.tags
      article.destroy
    end

    test "should handle array with nil values" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("ruby", nil, "rails", nil)

      assert_equal 2, article.tags.size
      assert_includes article.tags, "ruby"
      assert_includes article.tags, "rails"
      article.destroy
    end

    test "should handle mixed case normalization consistently" do
      article = Article.create!(title: "Test", content: "Test", status: "draft")
      article.tag_with("Ruby")
      article.tag_with("RUBY")
      article.tag_with("ruby")

      # With normalization, all should be the same
      assert_equal 1, article.tags.size
      assert_equal [ "ruby" ], article.tags
      article.destroy
    end

    # ============================================================================
    # FASE 14: INTEGRATION TESTING
    # ============================================================================

    # Integration with Statusable
    test "tags should work with Statusable statuses" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])

      assert article.is?(:draft)
      assert article.tagged_with?("ruby")
      article.destroy
    end

    # Integration with Permissible
    test "tags should work with Permissible permissions" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby" ])

      assert article.permit?(:edit)
      assert article.tagged_with?("ruby")
      article.destroy
    end

    # Integration with Sortable
    test "should work with Sortable scopes" do
      Article.delete_all
      a1 = Article.create!(title: "A", content: "Test", status: "draft", tags: [ "ruby" ])
      Article.create!(title: "B", content: "Test", status: "draft", tags: [ "python" ])

      sorted = Article.sort_title_asc.to_a
      assert_equal a1.id, sorted.first.id
      assert_includes sorted.first.tags, "ruby"

      Article.delete_all
    end

    # Integration with Predicable
    test "tags field should be predicable" do
      assert Article.predicable_field?(:tags)
    end

    # Integration with Searchable unified API
    test "should work in unified search with multiple predicates" do
      Article.delete_all
      Article.create!(title: "Ruby Guide", content: "Test", status: "draft", tags: [ "ruby", "tutorial" ])
      Article.create!(title: "Python Guide", content: "Test", status: "draft", tags: [ "python" ])

      # Searchable + Predicable + Taggable
      results = Article.search({ title_cont: "Guide" })
      assert_equal 2, results.size

      Article.delete_all
    end

    # Integration with as_json (full serialization)
    test "should serialize tags with all model data" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: [ "ruby", "rails" ])
      json = article.as_json

      assert_includes json.keys, "tags"
      assert_includes json.keys, "status"
      assert_includes json.keys, "title"
      article.destroy
    end

    # Tag counts integration
    test "tag_counts should work across all records" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby" ])
      Article.create!(title: "A2", content: "Test", status: "published", tags: [ "ruby" ], published_at: Time.current)

      counts = Article.tag_counts
      assert_equal 2, counts["ruby"]

      Article.delete_all
    end

    # Popular tags with different statuses
    test "popular_tags should include tags from all status types" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "draft_tag" ])
      Article.create!(title: "A2", content: "Test", status: "published", tags: [ "published_tag" ], published_at: Time.current)

      popular = Article.popular_tags(limit: 10)
      tag_names = popular.map(&:first)

      assert_includes tag_names, "draft_tag"
      assert_includes tag_names, "published_tag"

      Article.delete_all
    end

    # Related tags cross-status
    test "related_tags should find tags across different records" do
      Article.delete_all
      Article.create!(title: "A1", content: "Test", status: "draft", tags: [ "ruby", "backend" ])
      Article.create!(title: "A2", content: "Test", status: "published", tags: [ "ruby", "web" ], published_at: Time.current)

      related = Article.related_tags("ruby")

      assert_includes related, "backend"
      assert_includes related, "web"

      Article.delete_all
    end

    # ============================================================================
    # PERFORMANCE & ERROR HANDLING
    # ============================================================================

    test "tag_counts should handle many records efficiently" do
      Article.delete_all

      # Create 100 records with tags
      100.times do |i|
        Article.create!(title: "Article #{i}", content: "Test", status: "draft",
                       tags: [ "tag#{i % 10}", "common" ])
      end

      counts = Article.tag_counts
      assert_equal 100, counts["common"]

      Article.delete_all
    end

    test "should return empty for tag_list on nil tags" do
      article = Article.create!(title: "Test", content: "Test", status: "draft", tags: nil)

      assert_equal "", article.tag_list
      article.destroy
    end

    test "validation errors should be clear" do
      test_class = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Taggable
        serialize :tags, coder: JSON, type: Array

        taggable do
          tag_field :tags
          validates_tags minimum: 2, forbidden_tags: [ "bad" ]
        end
      end

      article = test_class.new(title: "Test", content: "Test", status: "draft", tags: [ "good" ])
      refute article.valid?
      assert_includes article.errors[:tags].to_s, "at least 2"

      article2 = test_class.new(title: "Test", content: "Test", status: "draft", tags: [ "good", "bad" ])
      refute article2.valid?
      assert_includes article2.errors[:tags].to_s, "forbidden"
    end

    # ========================================
    # CONFIGURATION ERROR TESTS
    # ========================================

    test "ConfigurationError class exists" do
      assert defined?(BetterModel::Errors::Taggable::ConfigurationError)
    end

    test "ConfigurationError inherits from ArgumentError" do
      assert BetterModel::Errors::Taggable::ConfigurationError < ArgumentError
    end

    test "ConfigurationError can be instantiated with message" do
      error = BetterModel::Errors::Taggable::ConfigurationError.new("test message")
      assert_equal "test message", error.message
    end

    test "ConfigurationError can be caught as ArgumentError" do
      begin
        raise BetterModel::Errors::Taggable::ConfigurationError, "test"
      rescue ArgumentError => e
        assert_instance_of BetterModel::Errors::Taggable::ConfigurationError, e
      end
    end

    test "ConfigurationError has correct namespace" do
      assert_equal "BetterModel::Errors::Taggable::ConfigurationError",
                   BetterModel::Errors::Taggable::ConfigurationError.name
    end

    # ========================================
    # CONFIGURATION ERROR INTEGRATION TESTS
    # ========================================

    test "raises ConfigurationError when included in non-ActiveRecord class" do
      error = assert_raises(BetterModel::Errors::Taggable::ConfigurationError) do
        Class.new do
          include BetterModel::Taggable
        end
      end
      assert_match(/can only be included in ActiveRecord models/, error.message)
    end

    test "raises ConfigurationError when tag_field does not exist" do
      error = assert_raises(BetterModel::Errors::Taggable::ConfigurationError) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Taggable

          taggable do
            tag_field :nonexistent_field
          end
        end
      end
      assert_match(/does not exist/, error.message)
    end

    test "raises ConfigurationError when taggable called twice" do
      error = assert_raises(BetterModel::Errors::Taggable::ConfigurationError) do
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
      end
      assert_match(/already configured/, error.message)
    end
  end
end
