# frozen_string_literal: true

module ManualTests
  module Fixtures
    def setup_fixtures
      section("SETUP - Preparazione Dati di Test")

      Article.delete_all
      puts "  Database pulito"

      # Attiva archivable per i test
      Article.class_eval do
        archivable do
          skip_archived_by_default true
        end
      end
      puts "  Archivable attivato su Article"

      # Crea articoli di test
      @draft = Article.create!(
        title: "Draft Article",
        content: "This is a draft",
        status: "draft",
        view_count: 10
      )

      @published = Article.create!(
        title: "Published Article",
        content: "This is published",
        status: "published",
        published_at: 2.days.ago,
        view_count: 50
      )

      @scheduled = Article.create!(
        title: "Scheduled Article",
        content: "Will be published soon",
        status: "draft",
        scheduled_at: 2.days.from_now,
        view_count: 0
      )

      @ready_to_publish = Article.create!(
        title: "Ready Article",
        content: "Should be published now",
        status: "draft",
        scheduled_at: 2.days.ago,
        view_count: 5
      )

      @expired = Article.create!(
        title: "Expired Article",
        content: "This has expired",
        status: "published",
        published_at: 10.days.ago,
        expires_at: 1.day.ago,
        view_count: 75
      )

      @popular = Article.create!(
        title: "Popular Article",
        content: "Many views",
        status: "published",
        published_at: 5.days.ago,
        view_count: 150
      )

      @featured = Article.create!(
        title: "Featured Article",
        content: "This is featured",
        status: "published",
        published_at: 3.days.ago,
        view_count: 200,
        featured: true
      )

      # Articolo vecchio per test archive
      @old_article = Article.create!(
        title: "Old Article",
        content: "Very old",
        status: "published",
        published_at: 2.years.ago,
        view_count: 30
      )
      @old_article.update_column(:created_at, 2.years.ago)

      # Articoli archiviati per test Archivable
      @archived_article = Article.unscoped.create!(
        title: "Archived Article",
        content: "This was archived",
        status: "published",
        published_at: 1.year.ago,
        view_count: 45,
        archived_at: 1.month.ago,
        archived_by_id: 999,
        archive_reason: "Content outdated"
      )

      @recently_archived = Article.unscoped.create!(
        title: "Recently Archived",
        content: "Archived recently",
        status: "published",
        published_at: 6.months.ago,
        view_count: 60,
        archived_at: 2.days.ago
      )

      puts "  Creati #{Article.unscoped.count} articoli di test (inclusi #{Article.unscoped.archived.count} archiviati)"
    end
  end
end
