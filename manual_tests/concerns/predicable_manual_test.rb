# frozen_string_literal: true

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

section("PREDICABLE - Test Presence Predicates with Boolean Parameters")

# Setup test data for presence predicates
Article.create!(title: "Non-empty Title", content: "Content", status: "draft", view_count: 50)
Article.create!(title: "", content: "Empty title", status: "draft", view_count: nil)
Article.create!(title: nil, content: "Nil title", status: "draft")

test("title_present(true) finds non-nil and non-empty titles") do
  results = Article.title_present(true)
  # Should find articles with actual title content (not nil, not empty)
  results.all? { |a| a.title.present? }
end

test("title_present(false) finds nil or empty titles") do
  results = Article.title_present(false)
  # Should find articles with nil or empty titles
  results.all? { |a| a.title.blank? }
end

test("title_blank(true) finds blank titles (nil or empty)") do
  results = Article.title_blank(true)
  # Should find articles where title is nil or empty string
  results.all? { |a| a.title.blank? }
end

test("title_blank(false) finds non-blank titles") do
  results = Article.title_blank(false)
  # Should find articles with actual content in title
  results.all? { |a| a.title.present? }
end

test("title_null(true) finds only nil titles") do
  results = Article.title_null(true)
  # Should find only articles where title is explicitly nil
  results.all? { |a| a.title.nil? }
end

test("title_null(false) finds non-nil titles") do
  results = Article.title_null(false)
  # Should find articles where title is not nil (could be empty string)
  results.all? { |a| !a.title.nil? }
end

test("view_count_present(true) finds non-nil numeric values") do
  results = Article.view_count_present(true)
  # For numeric fields, present means not nil
  results.all? { |a| !a.view_count.nil? }
end

test("view_count_present(false) finds nil numeric values") do
  results = Article.view_count_present(false)
  # Should find articles where view_count is nil
  results.all? { |a| a.view_count.nil? }
end

section("PREDICABLE - Test Range Predicates")

# Setup test data for range predicates
Article.create!(title: "Low Views", content: "Content", status: "draft", view_count: 25)
Article.create!(title: "Mid Views", content: "Content", status: "draft", view_count: 75)
Article.create!(title: "High Views", content: "Content", status: "draft", view_count: 125)

test("view_count_between(min, max) filters within numeric range") do
  results = Article.view_count_between(50, 100)
  # Should find articles with view_count between 50 and 100 (inclusive)
  results.all? { |a| a.view_count && a.view_count >= 50 && a.view_count <= 100 }
end

test("view_count_not_between(min, max) excludes numeric range") do
  results = Article.view_count_not_between(50, 100)
  # Should find articles with view_count outside 50-100 range
  results.all? { |a| a.view_count.nil? || a.view_count < 50 || a.view_count > 100 }
end

# Setup test data for date range predicates
Article.create!(title: "Very Old", content: "Content", status: "draft", published_at: 20.days.ago)
Article.create!(title: "Recent", content: "Content", status: "draft", published_at: 3.days.ago)
Article.create!(title: "Today", content: "Content", status: "draft", published_at: Time.current)

test("published_at_between(start, end) filters within date range") do
  start_date = 7.days.ago
  end_date = 1.day.ago
  results = Article.published_at_between(start_date, end_date)
  # Should find articles published between start and end dates
  results.all? { |a| a.published_at && a.published_at >= start_date && a.published_at <= end_date }
end

test("published_at_not_between(start, end) excludes date range") do
  start_date = 7.days.ago
  end_date = 1.day.ago
  results = Article.published_at_not_between(start_date, end_date)
  # Should find articles outside the date range
  results.all? { |a| a.published_at.nil? || a.published_at < start_date || a.published_at > end_date }
end

section("PREDICABLE - Test Date Within Predicate")

# Data already created above
test("published_at_within(days) with numeric value") do
  results = Article.published_at_within(7)
  # Should find articles published within last 7 days
  cutoff = 7.days.ago
  results.all? { |a| a.published_at && a.published_at >= cutoff }
end

test("published_at_within(duration) with ActiveSupport::Duration") do
  results = Article.published_at_within(12.hours)
  # Should find articles published within last 12 hours
  cutoff = 12.hours.ago
  results.all? { |a| a.published_at && a.published_at >= cutoff }
end

section("PREDICABLE - Test Boolean Predicate Changes")

# Setup test data for boolean predicates
Article.create!(title: "Featured Article", content: "Content", status: "draft", featured: true)
Article.create!(title: "Not Featured", content: "Content", status: "draft", featured: false)
Article.create!(title: "Nil Featured", content: "Content", status: "draft", featured: nil)

test("featured_eq(true) works for boolean true") do
  results = Article.featured_eq(true)
  # Should find articles where featured is explicitly true
  results.all? { |a| a.featured == true }
end

test("featured_eq(false) works for boolean false") do
  results = Article.featured_eq(false)
  # Should find articles where featured is explicitly false
  results.all? { |a| a.featured == false }
end
