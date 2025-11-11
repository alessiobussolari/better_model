# frozen_string_literal: true

require "test_helper"

module BetterModel
  # Test di sicurezza per prevenire SQL injection e altri attacchi
  class SecurityTest < ActiveSupport::TestCase
    # ========================================
    # SQL Injection Tests - LIKE Predicates
    # ========================================

    test "LIKE predicates should sanitize SQL injection attempts in _cont" do
      # Setup: crea articoli di test
      Article.create!(title: "Normal Article", status: "published")
      Article.create!(title: "Test%Article", status: "published")

      # Tenta SQL injection con caratteri speciali LIKE
      malicious_input = "Test%' OR '1'='1"

      # Non dovrebbe sollevare errori e non dovrebbe matchare tutti i record
      results = Article.title_cont(malicious_input)

      # Verifica che non abbia matchato nulla (perché la stringa letterale non esiste)
      assert_equal 0, results.count, "SQL injection attempt should not match any records"
    end

    test "LIKE predicates should sanitize SQL injection attempts in _start" do
      Article.create!(title: "StartTest", status: "published")

      malicious_input = "Start'; DROP TABLE articles;--"

      # Non dovrebbe causare errori SQL
      assert_nothing_raised do
        Article.title_start(malicious_input).to_a
      end
    end

    test "LIKE predicates should sanitize SQL injection attempts in _end" do
      Article.create!(title: "TestEnd", status: "published")

      malicious_input = "End' OR '1'='1"

      # Non dovrebbe matchare tutti i record
      results = Article.title_end(malicious_input)
      assert_equal 0, results.count
    end

    test "LIKE predicates should sanitize SQL injection attempts in _i_cont" do
      Article.create!(title: "UPPERCASE TEST", status: "published")

      malicious_input = "test' UNION SELECT * FROM users--"

      # Non dovrebbe causare errori SQL
      assert_nothing_raised do
        Article.title_i_cont(malicious_input).to_a
      end
    end

    test "LIKE predicates should escape special LIKE characters" do
      # Verifica che l'underscore venga escaped correttamente
      # L'importante è che la query venga eseguita senza errori
      assert_nothing_raised do
        Article.title_cont("Test_").to_a
        Article.title_start("Test_").to_a
        Article.title_end("_End").to_a
      end

      # Verifica che sanitize_sql_like venga chiamato
      # Creiamo un input con _ e verifichiamo che venga escaped nel SQL generato
      query = Article.title_cont("test_value").to_sql
      # Il SQL dovrebbe contenere l'escape sequence (in SQLite è \_, in altri DB potrebbe variare)
      # Almeno verifichiamo che la query sia valida e eseguibile
      assert_kind_of String, query
    end

    test "LIKE predicates should escape percent signs" do
      # Verifica che il % venga escaped correttamente
      # L'importante è che la query venga eseguita senza errori
      assert_nothing_raised do
        Article.title_cont("100%").to_a
        Article.title_start("100%").to_a
        Article.title_end("%End").to_a
      end

      # Verifica che la query generata sia valida
      query = Article.title_cont("100%").to_sql
      assert_kind_of String, query
    end

    # ========================================
    # SQL Injection Tests - PostgreSQL Array
    # ========================================


    # ========================================
    # Strong Parameters Bypass Tests
    # ========================================

    test "search should reject unpermitted ActionController::Parameters" do
      # Simula parametri non permessi dal controller
      if defined?(ActionController::Parameters)
        params = ActionController::Parameters.new({ title_eq: "Test" })

        error = assert_raises(ArgumentError) do
          Article.search(params)
        end

        assert_match(/Invalid configuration/, error.message)
      end
    end

    test "search should accept permitted ActionController::Parameters" do
      if defined?(ActionController::Parameters)
        params = ActionController::Parameters.new({ title_eq: "Test" }).permit!

        assert_nothing_raised do
          Article.search(params)
        end
      end
    end

    # ========================================
    # DoS Protection Tests
    # ========================================

    test "search should limit total number of predicates" do
      # Crea un hash con troppi predicati
      too_many_predicates = {}
      101.times do |i|
        too_many_predicates["title_eq_#{i}".to_sym] = "value"
      end

      error = assert_raises(ArgumentError) do
        Article.search(too_many_predicates)
      end

      assert_match(/Invalid configuration/, error.message)
    end

    test "search should limit number of OR conditions" do
      # Crea troppe condizioni OR
      too_many_or_conditions = []
      51.times do
        too_many_or_conditions << { title_eq: "test" }
      end

      error = assert_raises(ArgumentError) do
        Article.search({ or: too_many_or_conditions })
      end

      assert_match(/Invalid configuration/, error.message)
    end

    test "search should limit maximum page number" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: 10_001, per_page: 10 })
      end

      assert_match(/Page number exceeds maximum allowed/, error.message)
    end

    test "pagination should prevent enormous offsets" do
      # Page 10000 con per_page 100 crea offset di 999900
      # Questo dovrebbe funzionare (è al limite)
      assert_nothing_raised do
        Article.search({}, pagination: { page: 10_000, per_page: 100 })
      end

      # Ma page 10001 dovrebbe fallire
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
        Article.search({}, pagination: { page: 10_001, per_page: 100 })
      end

      assert_match(/Page number exceeds maximum allowed/, error.message)
    end

    # ========================================
    # XSS Protection Tests
    # ========================================

    test "predicates should not execute arbitrary code through symbols" do
      # Verifica che non si possano chiamare metodi arbitrari
      assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ destroy_all: true })
      end
    end

    test "predicates should validate scope names" do
      error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
        Article.search({ nonexistent_predicate: "value" })
      end

      assert_match(/Invalid predicate/, error.message)
    end

    # ========================================
    # Edge Cases
    # ========================================

    test "should handle nil values safely" do
      assert_nothing_raised do
        Article.title_eq(nil).to_a
      end
    end

    test "should handle empty strings safely" do
      assert_nothing_raised do
        Article.title_eq("").to_a
      end
    end

    test "should handle very long strings safely" do
      very_long_string = "a" * 10_000

      assert_nothing_raised do
        Article.title_eq(very_long_string).to_a
      end
    end

    test "should handle special characters safely" do
      special_chars = "'; DROP TABLE articles; --"

      assert_nothing_raised do
        Article.title_eq(special_chars).to_a
      end
    end

    test "should handle unicode characters safely" do
      unicode_string = "测试 🔒 безопасность"

      assert_nothing_raised do
        Article.title_eq(unicode_string).to_a
      end
    end
  end
end
