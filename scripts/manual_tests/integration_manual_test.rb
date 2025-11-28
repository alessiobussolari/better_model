# frozen_string_literal: true

# ==== TEST INTEGRATION & CHAINING ====
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
