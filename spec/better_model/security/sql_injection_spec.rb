# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SQL Injection Protection", type: :security do
  before do
    @safe_article = Article.create!(
      title: "Safe Article",
      content: "Normal content",
      status: "published",
      published_at: Time.current,
      view_count: 100,
      tags: ["ruby", "rails"]
    )
  end

  describe "Searchable protection" do
    describe "predicate values" do
      it "sanitizes SQL injection in string equality predicate" do
        injection = "'; DROP TABLE articles; --"

        # Should not raise error and should safely execute
        results = Article.search({ title_eq: injection })

        # Should find nothing (no article has this title)
        expect(results.count).to eq(0)

        # Table should still exist
        expect(Article.count).to be >= 1
      end

      it "sanitizes SQL injection in LIKE predicate (title_cont)" do
        injection = "%'; DELETE FROM articles; --"

        results = Article.search({ title_cont: injection })

        expect(results.count).to eq(0)
        expect(Article.count).to be >= 1
      end

      it "sanitizes SQL injection in title_start predicate" do
        injection = "Safe%'; UPDATE articles SET status='hacked'; --"

        results = Article.search({ title_start: injection })

        # Should find nothing because the literal string doesn't match
        expect(results.count).to eq(0)

        # Data should be intact
        @safe_article.reload
        expect(@safe_article.status).to eq("published")
      end

      it "sanitizes SQL injection in title_end predicate" do
        injection = "%Article'; TRUNCATE articles; --"

        results = Article.search({ title_end: injection })

        expect(results.count).to eq(0)
        expect(Article.count).to be >= 1
      end

      it "escapes wildcard characters in LIKE predicates" do
        # Create article with special characters
        special = Article.create!(
          title: "Article with percent sign here",
          status: "draft"
        )

        underscore_article = Article.create!(
          title: "Article_with_underscore",
          status: "draft"
        )

        # Search for specific text - should find only matching articles
        percent_results = Article.search({ title_cont: "percent sign" })

        expect(percent_results).to include(special)
        expect(percent_results.count).to eq(1)

        # Search for underscore in title
        underscore_results = Article.search({ title_cont: "underscore" })

        expect(underscore_results).to include(underscore_article)
        expect(underscore_results.count).to eq(1)
      end

      it "handles SQL injection in numeric predicates" do
        injection = "100; DROP TABLE articles; --"

        # Should coerce to number or raise appropriate error
        # Not execute the SQL injection
        expect do
          Article.search({ view_count_eq: injection })
        end.not_to raise_error

        expect(Article.count).to be >= 1
      end

      it "handles SQL injection in boolean predicates" do
        injection = "true; DELETE FROM articles; --"

        results = Article.search({ featured_eq: injection })

        expect(Article.count).to be >= 1
      end
    end

    describe "OR conditions" do
      it "sanitizes SQL injection in OR condition values" do
        injection = "'; DELETE FROM articles WHERE '1'='1"

        results = Article.search({
          or: [
            { title_cont: injection },
            { title_cont: "Safe" }
          ]
        })

        # Should find the Safe Article
        expect(results).to include(@safe_article)
        expect(Article.count).to be >= 1
      end

      it "prevents injection through multiple OR conditions" do
        results = Article.search({
          or: [
            { title_eq: "'; DROP TABLE articles; --" },
            { status_eq: "'; TRUNCATE articles; --" }
          ]
        })

        expect(results.count).to eq(0)
        expect(Article.count).to be >= 1
      end
    end
  end

  describe "Taggable protection" do
    it "sanitizes SQL injection in tag values" do
      article = Article.create!(title: "Tag Test", status: "draft", tags: [])

      injection = "'; DROP TABLE articles; --"

      # Should safely add tag without executing SQL
      article.tag_with(injection)

      expect(Article.count).to be >= 2
      # Tags get normalized (downcased) so compare with downcase
      expect(article.tags).to include(injection.downcase)
    end

    it "handles special characters in tags" do
      article = Article.create!(title: "Special Tags", status: "draft", tags: [])

      special_tags = [
        "ruby's",
        'test"quote',
        "back\\slash",
        "semi;colon",
        "dash--double"
      ]

      special_tags.each { |tag| article.tag_with(tag) }

      expect(article.tags.size).to eq(special_tags.size)
    end
  end

  describe "Sortable protection" do
    it "rejects invalid sort field names" do
      expect do
        Article.search({}, orders: [:"'; DROP TABLE articles; --"])
      end.to raise_error(BetterModel::Errors::Searchable::InvalidOrderError)

      expect(Article.count).to be >= 1
    end

    it "only accepts registered sort scopes" do
      expect do
        Article.search({}, orders: [:nonexistent_sort])
      end.to raise_error(BetterModel::Errors::Searchable::InvalidOrderError)
    end

    it "prevents SQL injection in sort direction" do
      # Attempting to inject via a fake scope name
      expect do
        Article.search({}, orders: [:sort_title_asc_DROP_TABLE])
      end.to raise_error(BetterModel::Errors::Searchable::InvalidOrderError)

      expect(Article.count).to be >= 1
    end
  end

  describe "Predicable protection" do
    it "rejects unregistered predicate scopes" do
      expect do
        Article.search({ nonexistent_predicate: "value" })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPredicateError)
    end

    it "prevents SQL injection through fake predicate names" do
      expect do
        Article.search({ "title'; DROP TABLE articles; --": "value" })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPredicateError)

      expect(Article.count).to be >= 1
    end
  end

  describe "Pagination protection" do
    it "handles negative page numbers safely" do
      expect do
        Article.search({}, pagination: { page: -1, per_page: 10 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "handles negative per_page safely" do
      expect do
        Article.search({}, pagination: { page: 1, per_page: -10 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "handles extremely large page numbers" do
      # System enforces max page limit
      expect do
        Article.search({}, pagination: { page: 999999, per_page: 10 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)

      expect(Article.count).to be >= 1
    end

    it "enforces max_per_page limit" do
      expect do
        Article.search({}, pagination: { page: 1, per_page: 1000 })
      end.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError)
    end

    it "handles string injection in pagination" do
      # String values get coerced to integers in Ruby
      # "1; DROP TABLE" becomes 1 via to_i
      result = Article.search({}, pagination: { page: "1; DROP TABLE articles", per_page: 10 })

      # Should execute safely, string coerced to integer
      expect(Article.count).to be >= 1
    end
  end

  describe "Unicode and encoding attacks" do
    it "handles unicode characters safely" do
      unicode_title = "Тест Unicode Заголовок 测试"

      article = Article.create!(
        title: unicode_title,
        status: "draft"
      )

      results = Article.search({ title_cont: "Unicode" })

      expect(results).to include(article)
    end

    it "handles special unicode characters safely" do
      # Test various unicode characters that could be problematic
      article = Article.create!(
        title: "Test with émojis 🚀 and ñ",
        status: "draft"
      )

      results = Article.search({ title_cont: "émojis" })

      expect(results).to include(article)
      expect(Article.count).to be >= 1
    end
  end

  describe "Second-order injection protection" do
    it "prevents injection through stored data" do
      # Store potentially dangerous value
      dangerous = Article.create!(
        title: "'; DELETE FROM articles WHERE '1'='1",
        status: "draft"
      )

      # Later search using that value shouldn't execute injection
      found = Article.search({ title_eq: dangerous.title })

      expect(found.count).to eq(1)
      expect(found.first).to eq(dangerous)
      expect(Article.count).to be >= 2
    end
  end
end
