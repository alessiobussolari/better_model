# Sortable Examples

Sortable provides declarative sorting with database-agnostic NULL handling and convenient shortcuts for common sort patterns.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Basic Sorting](#example-1-basic-sorting)
- [Example 2: NULL Handling](#example-2-null-handling)
- [Example 3: Date Sorting Shortcuts](#example-3-date-sorting-shortcuts)
- [Example 4: Multiple Field Sorting](#example-4-multiple-field-sorting)
- [Example 5: Custom Sort Logic](#example-5-custom-sort-logic)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Model
class Article < ApplicationRecord
  include BetterModel

  # Declare sortable fields
  sort :title, :view_count, :published_at, :created_at
end
```

## Example 1: Basic Sorting

```ruby
# Test data
Article.create!(title: "Zebra", view_count: 10)
Article.create!(title: "Alpha", view_count: 50)
Article.create!(title: "Beta", view_count: 30)

# Ascending
Article.sort_title_asc.pluck(:title)
# => ["Alpha", "Beta", "Zebra"]

# Descending
Article.sort_view_count_desc.pluck(:view_count)
# => [50, 30, 10]

# Chaining with other scopes
Article
  .status_eq("published")  # Predicate
  .sort_title_asc          # Sort
  .limit(10)
# => First 10 published articles, sorted by title
```

**Output Explanation**: Every sortable field gets `_asc` and `_desc` scopes automatically.

## Example 2: NULL Handling

Sortable handles NULL values consistently across databases (SQLite, PostgreSQL, MySQL):

```ruby
# Test data with NULL values
Article.create!(title: "Has Date", published_at: 2.days.ago)
Article.create!(title: "No Date", published_at: nil)
Article.create!(title: "Recent", published_at: Time.current)

# NULLS LAST (default for ASC)
Article.sort_published_at_asc_nulls_last.pluck(:title)
# => ["Has Date", "Recent", "No Date"]

# NULLS FIRST
Article.sort_published_at_asc_nulls_first.pluck(:title)
# => ["No Date", "Has Date", "Recent"]

# DESC with NULLS LAST
Article.sort_published_at_desc_nulls_last.pluck(:title)
# => ["Recent", "Has Date", "No Date"]

# DESC with NULLS FIRST (default for DESC)
Article.sort_published_at_desc_nulls_first.pluck(:title)
# => ["No Date", "Recent", "Has Date"]
```

**Output Explanation**: NULL handling is consistent across all databases thanks to BetterModel's cross-database SQL generation.

## Example 3: Date Sorting Shortcuts

Date/datetime fields get convenient shortcuts:

```ruby
# Test data
Article.create!(title: "Old", published_at: 30.days.ago)
Article.create!(title: "Recent", published_at: 1.day.ago)
Article.create!(title: "New", published_at: Time.current)

# Newest first (desc with nulls last)
Article.sort_published_at_newest.pluck(:title)
# => ["New", "Recent", "Old"]
# Equivalent to: sort_published_at_desc_nulls_last

# Oldest first (asc with nulls last)
Article.sort_published_at_oldest.pluck(:title)
# => ["Old", "Recent", "New"]
# Equivalent to: sort_published_at_asc_nulls_last

# These shortcuts are only available for date/datetime fields
Article.sort_created_at_newest
Article.sort_created_at_oldest
```

**Output Explanation**: `_newest` and `_oldest` provide intuitive sorting for date fields with sensible NULL handling.

## Example 4: Multiple Field Sorting

Chain sort scopes for multi-level sorting:

```ruby
# Test data
Article.create!(status: "published", view_count: 100, title: "Z Article")
Article.create!(status: "published", view_count: 100, title: "A Article")
Article.create!(status: "draft", view_count: 50, title: "B Article")
Article.create!(status: "draft", view_count: 200, title: "C Article")

# Sort by status, then view_count
Article
  .sort_status_asc
  .sort_view_count_desc
  .pluck(:status, :view_count, :title)
# => [
#   ["draft", 200, "C Article"],
#   ["draft", 50, "B Article"],
#   ["published", 100, "Z Article"],
#   ["published", 100, "A Article"]
# ]

# Sort by status, view_count, then title
Article
  .sort_status_asc
  .sort_view_count_desc
  .sort_title_asc
  .pluck(:status, :view_count, :title)
# => [
#   ["draft", 200, "C Article"],
#   ["draft", 50, "B Article"],
#   ["published", 100, "A Article"],  # Title breaks tie
#   ["published", 100, "Z Article"]
# ]
```

**Output Explanation**: Chaining sorts creates SQL `ORDER BY` clauses in the correct order.

## Example 5: Custom Sort Logic

Integrate with custom scopes:

```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :title, :view_count, :published_at

  # Custom scope with sorting
  scope :popular, -> { where("view_count > ?", 100).sort_view_count_desc }

  # Method that uses sorting
  def self.trending
    published
      .sort_published_at_newest
      .sort_view_count_desc
      .limit(10)
  end

  # Sort by calculated field
  def self.by_engagement
    select("articles.*, (view_count + comments_count * 5) as engagement")
      .order("engagement DESC")
  end
end

# Usage
Article.popular.pluck(:title, :view_count)
# => [["Most Popular", 500], ["Also Popular", 250]]

Article.trending
# => Top 10 recently published articles by views

Article.by_engagement.first(5)
# => Top 5 by custom engagement metric
```

**Output Explanation**: Sortable scopes integrate seamlessly with custom business logic.

## Checking Available Sorts

```ruby
class Article < ApplicationRecord
  include BetterModel
  sort :title, :view_count
end

# Check if field is sortable
Article.sortable_field?(:title)
# => true

Article.sortable_field?(:content)
# => false

# Get all sortable fields
Article.sortable_fields
# => [:title, :view_count]
```

## Tips & Best Practices

### 1. Add Database Indexes
```ruby
# Always index sortable columns for performance
class AddIndexesToArticles < ActiveRecord::Migration[8.1]
  def change
    add_index :articles, :title
    add_index :articles, :view_count
    add_index :articles, :published_at
    add_index :articles, [:status, :published_at]  # Composite
  end
end
```

### 2. Use Appropriate NULL Handling
```ruby
# For dates: newest/oldest usually want NULLS LAST
Article.sort_published_at_newest  # NULLS LAST

# For optional fields: be explicit about NULL position
Article.sort_expires_at_asc_nulls_first  # Never-expiring items first
Article.sort_expires_at_asc_nulls_last   # Never-expiring items last
```

### 3. Combine with Searchable
```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :status, :view_count
  sort :title, :view_count, :published_at

  searchable do
    default_sort :published_at_desc
  end
end

# Unified search with sorting
Article.search({ status_eq: "published" }, sort: :view_count_desc)
```

### 4. Avoid Sorting Large Result Sets
```ruby
# Bad: Sorts entire table
Article.all.sort_title_asc

# Good: Filter first, then sort
Article
  .status_eq("published")
  .published_at_this_month
  .sort_view_count_desc
  .limit(50)
```

### 5. Use Pagination with Sorting
```ruby
# With Kaminari
Article
  .sort_published_at_newest
  .page(params[:page])
  .per(25)

# With will_paginate
Article
  .sort_view_count_desc
  .paginate(page: params[:page], per_page: 25)

# With Searchable built-in pagination
Article.search(
  { status_eq: "published" },
  sort: :published_at_desc,
  pagination: { page: 1, per_page: 25 }
)
```

## Database-Specific Notes

### PostgreSQL & SQLite
- Native `NULLS FIRST/LAST` support
- Optimal performance

### MySQL/MariaDB
- BetterModel emulates `NULLS FIRST/LAST` using `CASE` statements
- Slightly less performant but functionally equivalent
- Example generated SQL:
  ```sql
  ORDER BY
    CASE WHEN published_at IS NULL THEN 1 ELSE 0 END,
    published_at DESC
  ```

## Related Documentation

- [Main README](../../README.md#sortable) - Full Sortable documentation
- [Searchable Examples](05_searchable.md) - Sorting in unified search
- [Predicable Examples](03_predicable.md) - Filtering before sorting
- [Test File](../../test/better_model/sortable_test.rb) - Complete test coverage

---

[← Predicable Examples](03_predicable.md) | [Back to Examples Index](README.md) | [Next: Searchable Examples →](05_searchable.md)
