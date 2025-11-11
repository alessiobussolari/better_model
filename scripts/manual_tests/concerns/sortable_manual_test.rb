# frozen_string_literal: true

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
