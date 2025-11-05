# frozen_string_literal: true

# ============================================================================
# TEST ARCHIVABLE
# ============================================================================

section("ARCHIVABLE - Test Archivable Configuration")

test("Article ha archivable_enabled?") { Article.respond_to?(:archivable_enabled?) }
test("Article.archivable_enabled? is true") { Article.archivable_enabled? }
test("Article ha archivable_config") { Article.respond_to?(:archivable_config) }
test("archivable_config is frozen") { Article.archivable_config.frozen? }

section("ARCHIVABLE - Test Scopes (Hybrid Approach)")

test("archived scope exists") { Article.respond_to?(:archived) }
test("not_archived scope exists") { Article.respond_to?(:not_archived) }
test("archived_only method exists") { Article.respond_to?(:archived_only) }

test("archived scope finds archived records") do
  Article.unscoped.archived.count >= 2
end

test("not_archived scope finds active records") do
  # Non dovrebbe includere i 2 archiviati
  active_count = Article.unscoped.not_archived.count
  total_count = Article.unscoped.count
  archived_count = Article.unscoped.archived.count
  active_count == total_count - archived_count
end

test("archived_only bypasses default scope") do
  # Con default scope attivo, archived_only trova gli archiviati
  Article.archived_only.count >= 2
end

section("ARCHIVABLE - Test Predicates (Auto-Generated)")

test("archived_at_present exists") { Article.respond_to?(:archived_at_present) }
test("archived_at_null exists") { Article.respond_to?(:archived_at_null) }
test("archived_at_within exists") { Article.respond_to?(:archived_at_within) }
test("archived_at_today exists") { Article.respond_to?(:archived_at_today) }
test("archived_at_this_week exists") { Article.respond_to?(:archived_at_this_week) }

test("archived_at_present works") do
  Article.unscoped.archived_at_present.count >= 2
end

test("archived_at_null works") do
  Article.unscoped.archived_at_null.count == Article.unscoped.count - Article.unscoped.archived.count
end

test("archived_at_within works") do
  Article.unscoped.archived_at_within(7.days).count >= 1
end

section("ARCHIVABLE - Test Helper Methods")

test("archived_today exists") { Article.respond_to?(:archived_today) }
test("archived_this_week exists") { Article.respond_to?(:archived_this_week) }
test("archived_recently exists") { Article.respond_to?(:archived_recently) }

test("archived_recently works") do
  recent = Article.unscoped.archived_recently(7.days)
  recent.is_a?(ActiveRecord::Relation)
end

section("ARCHIVABLE - Test Instance Methods - archive!")

# Usa un articolo non archiviato per testare archive!
test_article = Article.unscoped.not_archived.where.not(title: "Old Article").first

test("archive! method exists") { test_article.respond_to?(:archive!) }
test("archived? method exists") { test_article.respond_to?(:archived?) }
test("active? method exists") { test_article.respond_to?(:active?) }

test("article starts as not archived") { !test_article.archived? }
test("article starts as active") { test_article.active? }

test("archive! sets archived_at") do
  test_article.archive!
  test_article.archived_at.present?
end

test("after archive!, archived? returns true") { test_article.archived? }
test("after archive!, active? returns false") { !test_article.active? }

section("ARCHIVABLE - Test Instance Methods - archive! with tracking")

# Crea nuovo articolo per test tracking
tracking_article = Article.unscoped.create!(
  title: "Tracking Test",
  content: "Test",
  status: "published",
  published_at: 1.day.ago,
  view_count: 10
)

test("archive! with by: sets archived_by_id") do
  tracking_article.archive!(by: 42, reason: "Test reason")
  tracking_article.archived_by_id == 42
end

test("archive! with reason: sets archive_reason") do
  tracking_article.archive_reason == "Test reason"
end

section("ARCHIVABLE - Test Instance Methods - restore!")

archived_to_restore = Article.unscoped.archived.where(title: "Archived Article").first

test("restore! method exists") { archived_to_restore.respond_to?(:restore!) }

test("restore! clears archived_at") do
  archived_to_restore.restore!
  archived_to_restore.archived_at.nil?
end

test("after restore!, archived? returns false") { !archived_to_restore.archived? }
test("after restore!, active? returns true") { archived_to_restore.active? }

section("ARCHIVABLE - Test Error Handling")

test("archive! on already archived raises error") do
  already_archived = Article.unscoped.archived.first
  begin
    already_archived.archive!
    false
  rescue BetterModel::AlreadyArchivedError
    true
  end
end

test("restore! on not archived raises error") do
  active = Article.unscoped.not_archived.first
  begin
    active.restore!
    false
  rescue BetterModel::NotArchivedError
    true
  end
end

section("ARCHIVABLE - Test Integration with Searchable")

test("search with archived_at_null works") do
  results = Article.unscoped.search({ archived_at_null: true, status_eq: "published" })
  results.all? { |a| a.archived_at.nil? }
end

test("search with archived_at_present works") do
  results = Article.unscoped.search({ archived_at_present: true })
  results.all? { |a| a.archived_at.present? }
end

test("search with archived_at_within works") do
  results = Article.unscoped.search({ archived_at_within: 30.days })
  results.is_a?(ActiveRecord::Relation)
end

section("ARCHIVABLE - Test as_json Integration")

json_article = Article.unscoped.archived.first

test("as_json includes archive_info when requested") do
  json = json_article.as_json(include_archive_info: true)
  json.key?("archive_info")
end

test("archive_info contains archived status") do
  json = json_article.as_json(include_archive_info: true)
  json["archive_info"]["archived"] == true
end

test("archive_info contains archived_at") do
  json = json_article.as_json(include_archive_info: true)
  json["archive_info"]["archived_at"].present?
end

section("ARCHIVABLE - Test Default Scope Behavior")

test("Article.all hides archived by default") do
  # Con skip_archived_by_default: true, .all non dovrebbe includere archiviati
  all_count = Article.all.count
  unscoped_count = Article.unscoped.count
  unscoped_count > all_count
end

test("Article.unscoped.all shows all records") do
  Article.unscoped.count == Article.unscoped.not_archived.count + Article.unscoped.archived.count
end
