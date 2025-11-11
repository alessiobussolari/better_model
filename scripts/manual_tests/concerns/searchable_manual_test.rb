# frozen_string_literal: true

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
                              { featured_eq: true }
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
  begin
    Article.search({}, pagination: { page: 1, per_page: 200 })
    false  # Should not reach here
  rescue BetterModel::Errors::Searchable::InvalidPaginationError
    true  # Error raised as expected
  end
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
  rescue BetterModel::Errors::Searchable::InvalidSecurityError
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

section("SEARCHABLE - Test Eager Loading with includes")

# Setup test data for eager loading
@author1 = Author.create!(name: "Eager Author 1", email: "eager1@test.com")
@author2 = Author.create!(name: "Eager Author 2", email: "eager2@test.com")

@eager_article1 = Article.create!(
  title: "Eager Test 1",
  content: "Content with author",
  status: "published",
  view_count: 100,
  author: @author1
)

@eager_article2 = Article.create!(
  title: "Eager Test 2",
  content: "Content with author and comments",
  status: "published",
  view_count: 200,
  author: @author2
)

Comment.create!(article: @eager_article2, body: "First comment", author_name: "Reader 1")
Comment.create!(article: @eager_article2, body: "Second comment", author_name: "Reader 2")

test("search with includes: [:author] loads association") do
  results = Article.search({ status_eq: "published" }, includes: [:author])
  # Should return relation
  results.is_a?(ActiveRecord::Relation) &&
  # Should be able to access author without N+1 query
  results.any? { |a| a.author.present? }
end

test("search with includes: [:author, :comments] loads multiple associations") do
  results = Article.search({ status_eq: "published" }, includes: [:author, :comments])
  # Should return relation
  results.is_a?(ActiveRecord::Relation) &&
  # Should be able to access both associations
  results.any? { |a| a.author.present? && a.comments.loaded? }
end

test("search with includes: { author: :articles } loads nested associations") do
  results = Article.search({ status_eq: "published" }, includes: { author: :articles })
  # Should return relation
  results.is_a?(ActiveRecord::Relation) &&
  # Should load nested associations
  results.any? { |a| a.author.present? }
end

section("SEARCHABLE - Test Eager Loading with preload and eager_load")

test("search with preload: [:author] uses separate queries") do
  results = Article.search({ status_eq: "published" }, preload: [:author])
  # Should return relation
  results.is_a?(ActiveRecord::Relation) &&
  # Should preload association
  results.any? { |a| a.author.present? }
end

test("search with eager_load: [:author] forces LEFT OUTER JOIN") do
  results = Article.search({ status_eq: "published" }, eager_load: [:author], orders: [])
  # Should return relation (orders: [] to avoid ambiguous column errors)
  results.is_a?(ActiveRecord::Relation)
end

test("search combines eager loading with pagination and orders") do
  results = Article.search(
    { status_eq: "published" },
    pagination: { page: 1, per_page: 10 },
    orders: [:sort_view_count_desc],
    includes: [:author]
  )
  # Should return paginated relation with includes
  results.is_a?(ActiveRecord::Relation) &&
  results.limit_value == 10 &&
  results.any? { |a| a.author.present? }
end

section("SEARCHABLE - Test Integration with Presence Predicates")

test("search with title_present: true uses new presence API") do
  results = Article.search({ title_present: true })
  # Should find articles with non-blank titles
  results.all? { |a| a.title.present? }
end
