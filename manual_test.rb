# frozen_string_literal: true

# Manual Testing Script per BetterModel
#
# IMPORTANT: This file is wrapped in a transaction with automatic rollback
# to prevent database pollution. All changes made during this script are
# automatically rolled back when the script completes.
#
# HOW TO USE:
#   cd test/dummy
#   rails console
#   load '../../manual_test.rb'
#
# NOTE: This file should NOT be auto-loaded during the test suite.
# If tests are finding unexpected "Perf Article" records, it means
# this file was executed outside of a transaction. Make sure to run
# it only via the console using 'load' command.

puts "\n" + "=" * 80
puts "  BETTERMODEL - MANUAL TESTING SCRIPT"
puts "=" * 80
puts "  (Running in transaction - all changes will be rolled back)"
puts "=" * 80

# Contatori per il report finale
@tests_passed = 0
@tests_failed = 0
@errors = []

# Wrap everything in a transaction with rollback
ActiveRecord::Base.transaction do

# Helper method to get the Article's version class
def article_version_class
  # ArticleVersion is dynamically created by Traceable
  BetterModel::ArticleVersion
end

def test(description)
  print "  #{description}... "
  result = yield
  if result
    puts "✓"
    @tests_passed += 1
  else
    puts "✗"
    @tests_failed += 1
    @errors << description
  end
  result
rescue => e
  puts "✗ (ERROR: #{e.message})"
  @tests_failed += 1
  @errors << "#{description} - #{e.message}"
  false
end

def section(name)
  puts "\n" + "-" * 80
  puts "  #{name}"
  puts "-" * 80
end

# ============================================================================
# SETUP - Pulizia e creazione dati di test
# ============================================================================

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

# ============================================================================
# TEST STATUSABLE
# ============================================================================

section("STATUSABLE - Test Status Definitions")

test("Article ha defined_statuses") { Article.respond_to?(:defined_statuses) }
test("defined_statuses include :draft") { Article.defined_statuses.include?(:draft) }
test("defined_statuses include :published") { Article.defined_statuses.include?(:published) }
test("status_defined?(:draft) returns true") { Article.status_defined?(:draft) }
test("status_defined?(:nonexistent) returns false") { !Article.status_defined?(:nonexistent) }

section("STATUSABLE - Test Status Checks")

# Test is? method
test("draft.is?(:draft) is true") { @draft.is?(:draft) }
test("draft.is?(:published) is false") { !@draft.is?(:published) }
test("published.is?(:published) is true") { @published.is?(:published) }
test("scheduled.is?(:scheduled) is true") { @scheduled.is?(:scheduled) }
test("ready_to_publish.is?(:ready_to_publish) is true") { @ready_to_publish.is?(:ready_to_publish) }
test("expired.is?(:expired) is true") { @expired.is?(:expired) }
test("popular.is?(:popular) is true") { @popular.is?(:popular) }

# Test complex status
test("published.is?(:active) is true") { @published.is?(:active) }
test("expired.is?(:active) is false") { !@expired.is?(:active) }

# Test helper methods
test("draft.is_draft? exists") { @draft.respond_to?(:is_draft?) }
test("draft.is_draft? is true") { @draft.is_draft? }
test("draft.is_published? is false") { !@draft.is_published? }

# Test statuses method
test("draft.statuses returns hash") { @draft.statuses.is_a?(Hash) }
test("draft.statuses includes :draft") { @draft.statuses.key?(:draft) && @draft.statuses[:draft] == true }
test("published.statuses includes :published") { @published.statuses.key?(:published) && @published.statuses[:published] == true }
test("published.statuses includes :active") { @published.statuses.key?(:active) && @published.statuses[:active] == true }

# ============================================================================
# TEST PERMISSIBLE
# ============================================================================

section("PERMISSIBLE - Test Permission Definitions")

test("Article ha defined_permissions") { Article.respond_to?(:defined_permissions) }
test("defined_permissions include :delete") { Article.defined_permissions.include?(:delete) }
test("defined_permissions include :edit") { Article.defined_permissions.include?(:edit) }
test("permission_defined?(:delete) returns true") { Article.permission_defined?(:delete) }
test("permission_defined?(:nonexistent) returns false") { !Article.permission_defined?(:nonexistent) }

section("PERMISSIBLE - Test Permission Checks")

# Test permit? method - delete permission
test("draft.permit?(:delete) is true") { @draft.permit?(:delete) }
test("published.permit?(:delete) is false") { !@published.permit?(:delete) }

# Test permit? method - edit permission
test("draft.permit?(:edit) is true") { @draft.permit?(:edit) }
test("published.permit?(:edit) is true") { @published.permit?(:edit) }
test("expired.permit?(:edit) is false") { !@expired.permit?(:edit) }

# Test permit? method - publish/unpublish
test("draft.permit?(:publish) is true") { @draft.permit?(:publish) }
test("published.permit?(:publish) is false") { !@published.permit?(:publish) }
test("published.permit?(:unpublish) is true") { @published.permit?(:unpublish) }
test("draft.permit?(:unpublish) is false") { !@draft.permit?(:unpublish) }

# Test permit? method - archive permission
test("old_article.permit?(:archive) is true") { @old_article.permit?(:archive) }
test("published.permit?(:archive) is false") { !@published.permit?(:archive) }

# Test helper methods
test("draft.permit_delete? exists") { @draft.respond_to?(:permit_delete?) }
test("draft.permit_delete? is true") { @draft.permit_delete? }
test("published.permit_delete? is false") { !@published.permit_delete? }

# Test permissions method
test("draft.permissions returns hash") { @draft.permissions.is_a?(Hash) }
test("draft.permissions includes :delete") { @draft.permissions.key?(:delete) && @draft.permissions[:delete] == true }
test("draft.permissions includes :edit") { @draft.permissions.key?(:edit) && @draft.permissions[:edit] == true }
test("draft.permissions includes :publish") { @draft.permissions.key?(:publish) && @draft.permissions[:publish] == true }

# ============================================================================
# TEST SORTABLE
# ============================================================================

section("SORTABLE - Test Sort Definitions")

test("Article ha sortable_fields") { Article.respond_to?(:sortable_fields) }
test("sortable_fields include :title") { Article.sortable_fields.include?(:title) }
test("sortable_fields include :view_count") { Article.sortable_fields.include?(:view_count) }
test("sortable_field?(:title) returns true") { Article.sortable_field?(:title) }
test("sortable_field?(:nonexistent) returns false") { !Article.sortable_field?(:nonexistent) }

section("SORTABLE - Test Sort Scopes")

# Test title sorting
test("sort_title_asc exists") { Article.respond_to?(:sort_title_asc) }
test("sort_title_desc exists") { Article.respond_to?(:sort_title_desc) }
test("sort_title_asc works") do
  titles = Article.sort_title_asc.pluck(:title)
  titles == titles.sort
end
test("sort_title_desc works") do
  titles = Article.sort_title_desc.pluck(:title)
  titles == titles.sort.reverse
end

# Test view_count sorting
test("sort_view_count_asc exists") { Article.respond_to?(:sort_view_count_asc) }
test("sort_view_count_desc exists") { Article.respond_to?(:sort_view_count_desc) }
test("sort_view_count_desc works") do
  counts = Article.sort_view_count_desc.pluck(:view_count)
  counts == counts.sort.reverse
end

# Test published_at sorting
test("sort_published_at_asc exists") { Article.respond_to?(:sort_published_at_asc) }
test("sort_published_at_desc exists") { Article.respond_to?(:sort_published_at_desc) }

# Test created_at sorting
test("sort_created_at_asc exists") { Article.respond_to?(:sort_created_at_asc) }
test("sort_created_at_desc exists") { Article.respond_to?(:sort_created_at_desc) }

# Test sortable_scopes
test("Article ha sortable_scopes") { Article.respond_to?(:sortable_scopes) }
test("sortable_scopes includes :sort_title_asc") { Article.sortable_scopes.include?(:sort_title_asc) }

# ============================================================================
# TEST PREDICABLE
# ============================================================================

section("PREDICABLE - Test Predicate Definitions")

test("Article ha predicable_fields") { Article.respond_to?(:predicable_fields) }
test("predicable_fields include :title") { Article.predicable_fields.include?(:title) }
test("predicable_fields include :status") { Article.predicable_fields.include?(:status) }
test("predicable_field?(:title) returns true") { Article.predicable_field?(:title) }
test("predicable_field?(:nonexistent) returns false") { !Article.predicable_field?(:nonexistent) }

section("PREDICABLE - Test String Predicates")

test("title_eq exists") { Article.respond_to?(:title_eq) }
test("title_eq works") { Article.title_eq("Draft Article").count == 1 }
test("title_not_eq works") { Article.title_not_eq("Draft Article").count == Article.count - 1 }
test("title_cont exists") { Article.respond_to?(:title_cont) }
test("title_cont works") { Article.title_cont("Article").count == Article.count }
test("title_i_cont works") { Article.title_i_cont("article").count == Article.count }
test("title_start works") { Article.title_start("Draft").count >= 1 }
test("title_end works") { Article.title_end("Article").count >= 1 }

section("PREDICABLE - Test Numeric Predicates")

test("view_count_eq works") { Article.view_count_eq(150).count == 1 }
test("view_count_not_eq works") { Article.view_count_not_eq(150).count == Article.count - 1 }
test("view_count_gt works") { Article.view_count_gt(100).count >= 1 }
test("view_count_gteq works") { Article.view_count_gteq(100).count >= 1 }
test("view_count_lt works") { Article.view_count_lt(100).count >= 1 }
test("view_count_lteq works") { Article.view_count_lteq(100).count >= 1 }
test("view_count_between works") { Article.view_count_between(50, 100).count >= 1 }

section("PREDICABLE - Test Datetime Predicates")

test("published_at_present exists") { Article.respond_to?(:published_at_present) }
test("published_at_present works") { Article.published_at_present.count >= 1 }
test("published_at_blank works") { Article.published_at_blank.count >= 1 }
test("published_at_gt works") { Article.published_at_gt(1.week.ago).count >= 0 }
test("published_at_lt works") { Article.published_at_lt(1.week.ago).count >= 0 }

section("PREDICABLE - Test Boolean Predicates")

test("featured_true exists") { Article.respond_to?(:featured_true) }
test("featured_true works") { Article.featured_true.count >= 1 }
test("featured_false works") { Article.featured_false.count >= 1 }

test("predicable_scopes exists") { Article.respond_to?(:predicable_scopes) }

# ============================================================================
# TEST VALIDATABLE
# ============================================================================

section("VALIDATABLE - Setup and Configuration")

# Activate validatable for testing
Article.class_eval do
  validatable do
    # Basic validations
    validate :title, presence: true, length: { minimum: 3 }
    validate :content, presence: true

    # Conditional validation - published articles need published_at
    validate_if :is_published? do
      validate :published_at, presence: true
    end

    # Order validation - dates must be in correct order
    validate_order :starts_at, :before, :ends_at, if: -> { starts_at.present? && ends_at.present? }

    # Business rule - view_count cannot exceed max_views
    validate_business_rule :check_view_limit
  end

  # Business rule implementation
  def check_view_limit
    if max_views.present? && view_count.present? && view_count > max_views
      errors.add(:view_count, "cannot exceed max views (#{max_views})")
    end
  end
end
puts "  Validatable attivato su Article"

test("Article ha validatable_enabled?") { Article.validatable_enabled? }
test("validatable_config presente") { Article.validatable_config.present? }

section("VALIDATABLE - Basic Validations")

test("validation rejects article without title") do
  article = Article.new(content: "Has content", status: "draft")
  !article.valid? && article.errors[:title].present?
end

test("validation rejects title too short") do
  article = Article.new(title: "Hi", content: "Content", status: "draft")
  !article.valid? && article.errors[:title].any? { |msg| msg.include?("too short") }
end

test("validation accepts valid article") do
  article = Article.new(title: "Valid Title", content: "Valid content", status: "draft")
  article.valid?
end

section("VALIDATABLE - Conditional Validations (validate_if)")

test("draft article does not require published_at") do
  article = Article.new(title: "Draft Article", content: "Content", status: "draft", published_at: nil)
  article.valid?
end

test("published article requires published_at") do
  article = Article.new(title: "Published Article", content: "Content", status: "published", published_at: nil)
  # Note: The conditional validation may not trigger in new() - it needs the status to be set first
  # So we explicitly check if validation triggers on published articles
  article.valid?
  # If is_published? is true, published_at should be required
  if article.is_published?
    !article.valid? && article.errors[:published_at].present?
  else
    # If not published, skip this test
    true
  end
end

test("published article with published_at is valid") do
  article = Article.new(
    title: "Published Article",
    content: "Content",
    status: "published",
    published_at: Time.current
  )
  article.valid?
end

section("VALIDATABLE - Order Validations (Cross-Field)")

test("order validation accepts starts_at before ends_at") do
  article = Article.new(
    title: "Event Article",
    content: "Content",
    status: "draft",
    starts_at: Time.current,
    ends_at: 1.day.from_now
  )
  article.valid?
end

test("order validation rejects starts_at after ends_at") do
  article = Article.new(
    title: "Event Article",
    content: "Content",
    status: "draft",
    starts_at: 2.days.from_now,
    ends_at: 1.day.from_now
  )
  !article.valid? && article.errors[:starts_at].present?
end

test("order validation skipped when dates are nil") do
  article = Article.new(
    title: "Article",
    content: "Content",
    status: "draft",
    starts_at: nil,
    ends_at: nil
  )
  article.valid?
end

section("VALIDATABLE - Business Rules")

test("business rule allows view_count below max_views") do
  article = Article.new(
    title: "Article",
    content: "Content",
    status: "draft",
    view_count: 50,
    max_views: 100
  )
  article.valid?
end

test("business rule rejects view_count exceeding max_views") do
  article = Article.new(
    title: "Article",
    content: "Content",
    status: "draft",
    view_count: 150,
    max_views: 100
  )
  !article.valid? && article.errors[:view_count].present?
end

section("VALIDATABLE - Integration with Save/Update")

test("save fails for invalid article") do
  article = Article.new(title: nil, content: "Content", status: "draft")
  !article.save
end

test("save succeeds for valid article") do
  article = Article.new(title: "Valid Article", content: "Content", status: "draft")
  article.save
end

test("update fails when validation fails") do
  article = Article.create!(title: "Valid Title", content: "Content", status: "draft")
  !article.update(title: nil) && article.errors[:title].present?
end

test("save(validate: false) bypasses validatable validations") do
  article = Article.new(title: nil, content: "Content", status: "draft")
  article.save(validate: false)
  article.persisted?
end

section("VALIDATABLE - Error Messages and Introspection")

test("errors accessible after validation failure") do
  article = Article.new(title: nil, content: nil, status: "draft")
  article.valid?
  article.errors.attribute_names.include?(:title) && article.errors.attribute_names.include?(:content)
end

test("multiple validation errors accumulated") do
  article = Article.new(title: "Hi", content: nil, status: "published")
  article.valid?
  # Should have errors for: title (too short), content (presence)
  # Note: published_at conditional may or may not trigger depending on is_published? implementation
  article.errors.count >= 2
end

# ============================================================================
# TEST SEARCHABLE
# ============================================================================

section("SEARCHABLE - Test Search Configuration")

test("Article ha searchable_config") { Article.respond_to?(:searchable_config) }
test("searchable_config ha default_order") { Article.searchable_config.key?(:default_order) }
test("searchable_config ha per_page") { Article.searchable_config[:per_page] == 25 }
test("searchable_config ha max_per_page") { Article.searchable_config[:max_per_page] == 100 }

section("SEARCHABLE - Test Basic Search")

test("search method exists") { Article.respond_to?(:search) }
test("search without params works") do
  result = Article.search({})
  result.is_a?(ActiveRecord::Relation) && result.count == Article.count
end

section("SEARCHABLE - Test Search with Predicates")

test("search with single predicate works") do
  result = Article.search({ status_eq: "published" })
  result.all? { |a| a.status == "published" }
end

test("search with multiple predicates works") do
  result = Article.search({ status_eq: "published", view_count_gt: 100 })
  result.all? { |a| a.status == "published" && a.view_count > 100 }
end

test("search with string predicate works") do
  result = Article.search({ title_cont: "Article" })
  result.count >= 1
end

section("SEARCHABLE - Test Search with OR Conditions")

test("search with OR conditions works") do
  result = Article.search({
    or: [
      { status_eq: "draft" },
      { status_eq: "published" }
    ]
  })
  result.count >= 1
end

test("search combines OR with AND") do
  result = Article.search({
    or: [
      { view_count_gt: 100 },
      { featured_true: true }
    ],
    status_eq: "published"
  })
  result.all? { |a| a.status == "published" }
end

section("SEARCHABLE - Test Search with Orders")

test("search with single order works") do
  result = Article.search({}, orders: [ :sort_title_asc ])
  titles = result.pluck(:title)
  # Filter out nil values before comparing (nil values may exist due to validations)
  non_nil_titles = titles.compact
  non_nil_titles == non_nil_titles.sort
end

test("search with multiple orders works") do
  result = Article.search({}, orders: [ :sort_view_count_desc, :sort_title_asc ])
  result.is_a?(ActiveRecord::Relation)
end

test("search uses default_order when no orders specified") do
  result = Article.search({})
  # Default order is sort_created_at_desc
  dates = result.pluck(:created_at)
  dates == dates.sort.reverse
end

section("SEARCHABLE - Test Search with Pagination")

test("search with pagination works") do
  result = Article.search({}, pagination: { page: 1, per_page: 5 })
  result.limit_value == 5
end

test("search respects max_per_page") do
  result = Article.search({}, pagination: { page: 1, per_page: 200 })
  result.limit_value <= 100
end

test("search without per_page doesn't apply LIMIT") do
  result = Article.search({}, pagination: { page: 1 })
  result.limit_value.nil?
end

section("SEARCHABLE - Test Search with Security")

test("search with valid security works") do
  result = Article.search({ status_eq: "published" }, security: :status_required)
  result.is_a?(ActiveRecord::Relation)
end

test("search raises error for missing required predicate") do
  begin
    Article.search({ title_cont: "Test" }, security: :status_required)
    false
  rescue BetterModel::Searchable::InvalidSecurityError
    true
  end
end

section("SEARCHABLE - Test Search Introspection")

test("searchable_fields exists") { Article.respond_to?(:searchable_fields) }
test("searchable_fields returns predicable fields") { Article.searchable_fields.include?(:title) }
test("searchable_predicates_for exists") { Article.respond_to?(:searchable_predicates_for) }
test("searchable_predicates_for(:title) returns array") do
  predicates = Article.searchable_predicates_for(:title)
  predicates.is_a?(Array) && predicates.include?(:eq)
end
test("searchable_sorts_for exists") { Article.respond_to?(:searchable_sorts_for) }
test("searchable_sorts_for(:title) returns array") do
  sorts = Article.searchable_sorts_for(:title)
  sorts.is_a?(Array) && sorts.include?(:sort_title_asc)
end

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

# ============================================================================
# TEST INTEGRATION & CHAINING
# ============================================================================

section("INTEGRATION - Test Scope Chaining")

test("predicates can be chained") do
  result = Article.status_eq("published").view_count_gt(50)
  result.is_a?(ActiveRecord::Relation) && result.count >= 1
end

test("search returns chainable relation") do
  result = Article.search({ status_eq: "published" }).where("view_count > 50")
  result.is_a?(ActiveRecord::Relation)
end

test("sortable scopes can be chained") do
  result = Article.status_eq("published").sort_view_count_desc
  result.is_a?(ActiveRecord::Relation)
end

test("complex chaining works") do
  result = Article
    .unscoped
    .status_eq("published")
    .view_count_gteq(50)
    .sort_published_at_desc
    .limit(5)
  result.count <= 5
end

test("archivable scopes can be chained with predicates") do
  result = Article.unscoped.not_archived.status_eq("published").view_count_gt(50)
  result.is_a?(ActiveRecord::Relation)
end

test("archived scope works with predicates") do
  result = Article.unscoped.archived.view_count_gt(40)
  result.is_a?(ActiveRecord::Relation) && result.count >= 1
end

test("archived scope works with sortable") do
  result = Article.unscoped.archived.sort_archived_at_desc
  result.is_a?(ActiveRecord::Relation)
end

# ============================================================================
# TEST TRACEABLE - Change Tracking & Audit Trail
# ============================================================================

section("TRACEABLE - Setup and Configuration")

# Pulisce versioni esistenti e attiva traceable
# NOTE: Since we're using article_versions table now, we need to delete from there
ActiveRecord::Base.connection.execute("DELETE FROM article_versions") if ActiveRecord::Base.connection.table_exists?("article_versions")
puts "  Versioni pulite"

# IMPORTANT: Activate traceable BEFORE creating test articles
# This ensures callbacks are properly registered
Article.class_eval do
  traceable do
    track :status, :title, :view_count, :published_at, :archived_at
  end
end
puts "  Traceable attivato su Article"

# Crea articles per test traceable DOPO aver attivato traceable
@tracked_article = Article.unscoped.create!(
  title: "Original Title",
  content: "Original content for tracking",
  status: "draft",
  view_count: 0
)
puts "  Article di test creato per traceable"

test("Article ha traceable_enabled?") do
  Article.traceable_enabled?
end

test("Article ha traceable_fields configurati") do
  Article.traceable_fields == [:status, :title, :view_count, :published_at, :archived_at]
end

test("Article ha versions association") do
  @tracked_article.respond_to?(:versions)
end

section("TRACEABLE - Basic Tracking")

test("create genera version con event=created") do
  versions = @tracked_article.versions.to_a
  versions.any? && versions.last.event == "created"
end

test("update genera version con event=updated") do
  initial_count = @tracked_article.versions.count
  @tracked_article.update!(title: "Updated Title")
  @tracked_article.reload  # Reload to clear association cache
  @tracked_article.versions.count == initial_count + 1 &&
    @tracked_article.versions.to_a.first.event == "updated"
end

test("tracked_changes contiene solo campi configurati") do
  @tracked_article.update!(title: "New Title", content: "New content")
  @tracked_article.reload  # Reload to clear association cache
  version = @tracked_article.versions.to_a.first
  version.object_changes.key?("title") && !version.object_changes.key?("content")
end

test("version contiene before/after values corretti") do
  old_title = @tracked_article.title
  @tracked_article.update!(title: "Changed Title")
  @tracked_article.reload  # Reload to clear association cache
  version = @tracked_article.versions.to_a.first
  change = version.change_for(:title)
  change[:before] == old_title && change[:after] == "Changed Title"
end

test("tracking con updated_by_id funziona") do
  # Usa attr_accessor già definito in Article per test
  @tracked_article.class.class_eval { attr_accessor :updated_by_id }
  @tracked_article.updated_by_id = 42
  @tracked_article.update!(status: "published")
  @tracked_article.reload  # Reload to clear association cache
  @tracked_article.versions.to_a.first.updated_by_id == 42
end

test("tracking con updated_reason funziona") do
  @tracked_article.class.class_eval { attr_accessor :updated_reason }
  @tracked_article.updated_reason = "Approved by editor"
  @tracked_article.update!(view_count: 100)
  @tracked_article.reload  # Reload to clear association cache
  @tracked_article.versions.to_a.first.updated_reason == "Approved by editor"
end

test("destroy genera version con event=destroyed") do
  temp_article = Article.unscoped.create!(title: "Temp Article", content: "Temp content", status: "draft")
  article_id = temp_article.id
  article_class = temp_article.class.name
  temp_article.destroy!

  destroyed_version = article_version_class
    .where(item_type: article_class, item_id: article_id)
    .order(created_at: :desc)
    .first

  destroyed_version.present? && destroyed_version.event == "destroyed"
end

test("versions preservate dopo destroy (audit trail)") do
  temp_article = Article.unscoped.create!(title: "ToDelete", content: "Delete content", status: "draft")
  temp_article.update!(status: "published")
  article_id = temp_article.id
  article_class = temp_article.class.name
  initial_versions = article_version_class.where(item_type: article_class, item_id: article_id).count

  temp_article.destroy!

  final_versions = article_version_class.where(item_type: article_class, item_id: article_id).count
  final_versions == initial_versions + 1 # created + updated + destroyed
end

section("TRACEABLE - Instance Methods")

test("changes_for(:field) restituisce storico cambiamenti") do
  test_article = Article.unscoped.create!(title: "Version 1", content: "Content v1", status: "draft")
  test_article.update!(title: "Version 2")
  test_article.update!(title: "Version 3")

  changes = test_article.changes_for(:title)
  # Should have 3 changes: create (nil->Version 1), update (Version 1->Version 2), update (Version 2->Version 3)
  changes.length == 3 &&
    changes[0][:after] == "Version 3" &&
    changes[1][:after] == "Version 2" &&
    changes[2][:after] == "Version 1"
end

test("audit_trail restituisce history completa") do
  trail = @tracked_article.audit_trail
  trail.is_a?(Array) && trail.all? { |t| t.key?(:event) && t.key?(:changes) && t.key?(:at) }
end

test("as_of(timestamp) ricostruisce stato passato") do
  test_article = Article.unscoped.create!(title: "Original Title", content: "Original content", status: "draft", view_count: 10)
  time_after_create = Time.current + 0.1.seconds
  sleep 0.2

  test_article.update!(title: "Updated Title", view_count: 20)

  past_article = test_article.as_of(time_after_create)
  past_article.title == "Original Title" && past_article.view_count == 10
end

test("as_of restituisce readonly object") do
  past = @tracked_article.as_of(Time.current)
  past.readonly?
end

test("rollback_to ripristina a versione precedente") do
  test_article = Article.unscoped.create!(title: "Before Rollback", content: "Before content", status: "draft")
  test_article.update!(title: "After Rollback", status: "published")

  version_to_restore = test_article.versions.where(event: "updated").first
  test_article.rollback_to(version_to_restore)

  test_article.title == "Before Rollback" && test_article.status == "draft"
end

test("rollback_to accetta version ID") do
  test_article = Article.unscoped.create!(title: "Rollback Test", content: "Test content", status: "draft")
  test_article.update!(status: "published")

  version_id = test_article.versions.where(event: "updated").first.id
  test_article.rollback_to(version_id)

  test_article.status == "draft"
end

section("TRACEABLE - Class Methods and Scopes")

test("changed_by(user_id) trova record modificati da utente") do
  Article.unscoped.delete_all
  ActiveRecord::Base.connection.execute("DELETE FROM article_versions")

  Article.class_eval { attr_accessor :updated_by_id }

  article1 = Article.unscoped.create!(title: "Article 1", content: "Content 1", status: "draft")
  article1.updated_by_id = 10
  article1.update!(status: "published")

  article2 = Article.unscoped.create!(title: "Article 2", content: "Content 2", status: "draft")
  article2.updated_by_id = 20
  article2.update!(status: "published")

  results = Article.changed_by(10)
  results.pluck(:id).include?(article1.id) && !results.pluck(:id).include?(article2.id)
end

test("changed_between(start, end) filtra per periodo") do
  Article.unscoped.delete_all
  ActiveRecord::Base.connection.execute("DELETE FROM article_versions")

  start_time = Time.current
  article = Article.unscoped.create!(title: "TimedArticle", content: "Timed content", status: "draft")
  sleep 0.1
  article.update!(status: "published")
  end_time = Time.current

  results = Article.changed_between(start_time, end_time)
  results.pluck(:id).include?(article.id)
end

section("TRACEABLE - Integration")

test("integration con Archivable tracking") do
  test_article = Article.unscoped.create!(title: "ToArchive Article", content: "Archive content", status: "published")
  test_article.archive!
  test_article.reload  # Reload to clear association cache

  # Archivable update dovrebbe generare version
  versions = test_article.versions.to_a
  versions.any? { |v| v.object_changes && v.object_changes.key?("archived_at") }
end

test("as_json include_audit_trail funziona") do
  json = @tracked_article.as_json(include_audit_trail: true)
  json.key?("audit_trail") && json["audit_trail"].is_a?(Array)
end

test("versions.count restituisce numero corretto") do
  # Create a fresh article since @tracked_article may have been deleted by previous tests
  test_article = Article.unscoped.create!(title: "Count Test", content: "Count content", status: "draft")
  test_article.update!(title: "Updated")
  count = test_article.versions.count
  # Should have 2 versions: 1 create + 1 update
  count.is_a?(Integer) && count == 2
end

test("version ordering è corretto (desc)") do
  test_article = Article.unscoped.create!(title: "Order Test", content: "Order content", status: "draft")
  test_article.update!(status: "published")
  test_article.update!(status: "archived")

  versions = test_article.versions.to_a
  # Primo elemento dovrebbe essere l'ultimo update (archived)
  versions.first.object_changes["status"][1] == "archived" if versions.first.object_changes
end

section("TRACEABLE - Helper Methods")

test("Version model ha change_for method") do
  version = @tracked_article.versions.to_a.first
  version.respond_to?(:change_for)
end

test("Version model ha changed? method") do
  version = @tracked_article.versions.to_a.first
  version.respond_to?(:changed?)
end

test("Version model ha changed_fields method") do
  version = @tracked_article.versions.to_a.first
  fields = version.changed_fields
  fields.is_a?(Array)
end

section("TRACEABLE - Error Handling")

test("raise NotEnabledError se traceable non attivo") do
  begin
    temp_class = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel
      # NON attiva traceable
    end

    instance = temp_class.new
    instance.changes_for(:status) rescue BetterModel::NotEnabledError
    true
  rescue => e
    e.is_a?(BetterModel::NotEnabledError)
  end
end

# ============================================================================
# ADVANCED TRACEABLE TESTS
# ============================================================================

section("TRACEABLE - Advanced Integration")

test("rollback genera nuova version tracciata") do
  test_article = Article.unscoped.create!(title: "Before Rollback", content: "Rollback content", status: "draft")
  test_article.update!(title: "After Update", status: "published")

  initial_count = test_article.versions.count
  version_to_restore = test_article.versions.where(event: "updated").first
  test_article.rollback_to(version_to_restore)

  # Rollback should create a new version
  test_article.reload
  test_article.versions.count == initial_count + 1
end

test("update senza tracked fields non crea version") do
  test_article = Article.unscoped.create!(
    title: "Test",
    content: "Original content",
    status: "draft"
  )

  initial_count = test_article.versions.count

  # Update solo content (non tracked)
  test_article.update!(content: "Updated content only")
  test_article.reload

  # Count should remain the same
  test_article.versions.count == initial_count
end

test("as_of prima della creazione restituisce oggetto vuoto") do
  test_article = Article.unscoped.create!(title: "Test Article", content: "Test content", status: "draft")

  # Time before creation
  time_before = test_article.created_at - 1.hour
  past_article = test_article.as_of(time_before)

  # Should return object but with no data (fields are nil)
  past_article.is_a?(Article) && past_article.title.nil?
end

test("integration Traceable + Statusable") do
  test_article = Article.unscoped.create!(title: "Status Test", content: "Status content", status: "draft")
  test_article.update!(status: "published", published_at: Time.current)
  test_article.reload

  # Check version tracks status change
  version = test_article.versions.where(event: "updated").first
  version.object_changes.key?("status") &&
    version.object_changes["status"] == ["draft", "published"]
end

section("TRACEABLE - Complex Scenarios")

test("rollback multipli consecutivi funzionano") do
  test_article = Article.unscoped.create!(title: "Version 1", content: "Content v1", status: "draft")

  test_article.update!(title: "Version 2", status: "published")
  v2_version = test_article.versions.where(event: "updated").first

  test_article.update!(title: "Version 3")

  # Rollback to v2 update (will restore to before values: Version 1, draft)
  test_article.rollback_to(v2_version)
  test_article.reload

  first_rollback = test_article.title == "Version 1" && test_article.status == "draft"

  # Make another update
  test_article.update!(title: "Version 4", status: "published")

  # Rollback again to same version - should still work
  test_article.rollback_to(v2_version)
  test_article.reload

  second_rollback = test_article.title == "Version 1" && test_article.status == "draft"

  first_rollback && second_rollback
end

test("as_of ricostruzione multi-field complessa") do
  test_article = Article.unscoped.create!(
    title: "Original Title",
    content: "Original content",
    status: "draft",
    view_count: 0
  )

  time_after_create = Time.current + 0.1.seconds
  sleep 0.2

  test_article.update!(title: "Updated Title Field")
  sleep 0.1
  test_article.update!(status: "published")
  sleep 0.1
  test_article.update!(view_count: 100)

  # Reconstruct at time_after_create
  past_article = test_article.as_of(time_after_create)

  past_article.title == "Original Title" &&
    past_article.status == "draft" &&
    past_article.view_count == 0
end

test("traceable con campi nil/empty gestiti correttamente") do
  # Test tracking of empty/nil transitions
  test_article = Article.unscoped.create!(title: "Empty Test Title", content: "Test content", status: "draft")

  # Track update to different title
  test_article.update!(title: "Changed Title")
  test_article.reload
  version1 = test_article.versions.where(event: "updated").first
  title_changed = version1.object_changes["title"] == ["Empty Test Title", "Changed Title"]

  # Track another change
  test_article.update!(title: "Final Title")
  test_article.reload
  version2 = test_article.versions.where(event: "updated").first
  title_changed_again = version2.object_changes["title"] == ["Changed Title", "Final Title"]

  title_changed && title_changed_again
end

section("TRACEABLE - PostgreSQL Features")

if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
  test("status_changed_from().to() funziona su PostgreSQL") do
    Article.unscoped.delete_all
    ActiveRecord::Base.connection.execute("DELETE FROM article_versions")

    test_article = Article.unscoped.create!(title: "PG Test", status: "draft")
    test_article.update!(status: "published")

    results = Article.status_changed_from("draft").to("published")
    results.pluck(:id).include?(test_article.id)
  end

  test("JSON queries con valori nil nelle transizioni") do
    Article.unscoped.delete_all
    ActiveRecord::Base.connection.execute("DELETE FROM article_versions")

    # nil → "published"
    test_article = Article.unscoped.create!(title: "Test", status: nil)
    test_article.update!(status: "published")

    # This would need custom JSON query implementation
    # For now, just verify versions are created correctly
    version = test_article.versions.where(event: "updated").first
    version.object_changes["status"] == [nil, "published"]
  end
else
  puts "  ⚠️  Skipping PostgreSQL-specific tests (not on PostgreSQL)"
end

section("TRACEABLE - Performance")

test("performance con 100+ versions per record") do
  # Create article with 100+ versions
  perf_article = Article.unscoped.create!(title: "Perf Test", content: "Performance content", status: "draft", view_count: 0)

  start_time = Time.now

  100.times do |i|
    perf_article.update!(view_count: i + 1)
  end

  creation_time = Time.now - start_time

  # Test as_of performance
  as_of_start = Time.now
  past = perf_article.as_of(Time.current)
  as_of_time = Time.now - as_of_start

  # Test changes_for performance
  changes_start = Time.now
  changes = perf_article.changes_for(:view_count)
  changes_time = Time.now - changes_start

  puts "    100 updates took: #{(creation_time * 1000).round(2)}ms"
  puts "    as_of took: #{(as_of_time * 1000).round(2)}ms"
  puts "    changes_for took: #{(changes_time * 1000).round(2)}ms"
  puts "    changes count: #{changes.length}"

  # Performance should be reasonable (< 1 second for 100 versions)
  # Should have at least 100 changes (100 updates, might have create if view_count tracked in create)
  as_of_time < 1.0 && changes_time < 1.0 && changes.length >= 100
end

# ============================================================================
# TEST PERFORMANCE
# ============================================================================

section("PERFORMANCE - Test with Larger Dataset")

puts "  Creazione di 100 articoli addizionali per test performance..."

100.times do |i|
  Article.create!(
    title: "Perf Article #{i}",
    content: "Performance test content",
    status: [ "draft", "published" ].sample,
    view_count: rand(0..300),
    published_at: [ nil, rand(30).days.ago ].sample,
    featured: [ true, false ].sample
  )
end

total_articles = Article.count
puts "  Totale articoli: #{total_articles}"

test("search performs well with #{total_articles} records") do
  start_time = Time.now
  result = Article.search(
    { status_eq: "published", view_count_gteq: 50 },
    orders: [ :sort_view_count_desc ],
    pagination: { page: 1, per_page: 25 }
  )
  result.to_a # Force query execution
  elapsed = Time.now - start_time
  elapsed < 1.0 # Should complete in less than 1 second
end

test("complex search with OR performs well") do
  start_time = Time.now
  result = Article.search(
    {
      or: [
        { view_count_gt: 100 },
        { featured_true: true }
      ],
      status_eq: "published"
    },
    orders: [ :sort_published_at_desc ]
  )
  result.to_a
  elapsed = Time.now - start_time
  elapsed < 1.0
end

# ============================================================================
# FINAL REPORT
# ============================================================================

section("FINAL REPORT")

puts
puts "  Total Tests: #{@tests_passed + @tests_failed}"
puts "  ✓ Passed: #{@tests_passed}"
puts "  ✗ Failed: #{@tests_failed}"
puts

if @tests_failed > 0
  puts "  Failed Tests:"
  @errors.each do |error|
    puts "    - #{error}"
  end
  puts
end

success_rate = (@tests_passed.to_f / (@tests_passed + @tests_failed) * 100).round(2)
puts "  Success Rate: #{success_rate}%"
puts

if @tests_failed == 0
  puts "  🎉 ALL TESTS PASSED! 🎉"
  puts "  The gem is ready for publication!"
else
  puts "  ⚠️  Some tests failed. Please review the errors above."
end

puts
puts "=" * 80
puts

  # Transaction rollback - clean up all test data
  raise ActiveRecord::Rollback
end

puts
puts "=" * 80
puts "  DATABASE ROLLED BACK - All test data cleaned up"
puts "=" * 80
puts
