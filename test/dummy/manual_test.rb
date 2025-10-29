# frozen_string_literal: true

# Manual Testing Script per BetterModel
# Esegui con: cd test/dummy && rails console
# Poi: load 'manual_test.rb'

puts "\n" + "=" * 80
puts "  BETTERMODEL - MANUAL TESTING SCRIPT"
puts "=" * 80

# Contatori per il report finale
@tests_passed = 0
@tests_failed = 0
@errors = []

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

puts "  Creati #{Article.count} articoli di test"

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
  result = Article.search({}, orders: [:sort_title_asc])
  titles = result.pluck(:title)
  titles == titles.sort
end

test("search with multiple orders works") do
  result = Article.search({}, orders: [:sort_view_count_desc, :sort_title_asc])
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
    .status_eq("published")
    .view_count_gteq(50)
    .sort_published_at_desc
    .limit(5)
  result.count <= 5
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
    status: ["draft", "published"].sample,
    view_count: rand(0..300),
    published_at: [nil, rand(30).days.ago].sample,
    featured: [true, false].sample
  )
end

total_articles = Article.count
puts "  Totale articoli: #{total_articles}"

test("search performs well with #{total_articles} records") do
  start_time = Time.now
  result = Article.search(
    { status_eq: "published", view_count_gteq: 50 },
    orders: [:sort_view_count_desc],
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
    orders: [:sort_published_at_desc]
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

# Cleanup opzionale
if @tests_failed == 0
  print "  Vuoi pulire il database di test? (y/n): "
  if gets.chomp.downcase == "y"
    Article.delete_all
    puts "  Database pulito."
  end
end
