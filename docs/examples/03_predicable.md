# Predicable Examples

Predicable automatically generates powerful query scopes for your model fields, eliminating the need to write custom scopes manually.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Basic Predicates](#example-1-basic-predicates)
- [Example 2: String Predicates](#example-2-string-predicates)
- [Example 3: Numeric Predicates](#example-3-numeric-predicates)
- [Example 4: Date/DateTime Predicates](#example-4-datetime-predicates)
- [Example 5: Boolean Predicates](#example-5-boolean-predicates)
- [Example 6: Chaining Predicates](#example-6-chaining-predicates)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Migration
class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :status
      t.integer :view_count, default: 0
      t.boolean :featured, default: false
      t.datetime :published_at
      t.timestamps
    end
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel

  # Declare which fields should have predicates
  predicates :title, :status, :view_count, :featured, :published_at, :created_at
end
```

## Example 1: Basic Predicates

Every field gets `_eq`, `_not_eq`, and `_present` scopes:

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :status
end

# Create test data
Article.create!(title: "Draft", status: "draft")
Article.create!(title: "Published", status: "published")
Article.create!(title: "No Status")  # status is nil

# Equality
Article.status_eq("draft").pluck(:title)
# => ["Draft"]

# Not equal
Article.status_not_eq("draft").pluck(:title)
# => ["Published", "No Status"]

# Presence (not nil)
Article.status_present.pluck(:title)
# => ["Draft", "Published"]

# Null check
Article.status_null.pluck(:title)
# => ["No Status"]
```

**Output Explanation**: Basic predicates work for all field types and handle nil values gracefully.

## Example 2: String Predicates

String fields get additional pattern matching scopes:

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :status
end

# Test data
Article.create!(title: "Ruby on Rails Tutorial")
Article.create!(title: "Rails Performance Guide")
Article.create!(title: "Python Basics")

# Contains (case insensitive)
Article.title_cont("Rails").pluck(:title)
# => ["Ruby on Rails Tutorial", "Rails Performance Guide"]

# Starts with
Article.title_start("Ruby").pluck(:title)
# => ["Ruby on Rails Tutorial"]

# Ends with
Article.title_end("Guide").pluck(:title)
# => ["Rails Performance Guide"]

# Empty string handling
Article.create!(title: "")
Article.title_present.count
# => 3 (excludes empty string and nil)

Article.title_null.count
# => 1 (only truly nil values)
```

**Output Explanation**: String predicates are case-insensitive by default and handle empty strings intelligently.

## Example 3: Numeric Predicates

Numeric fields get comparison and range scopes:

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :view_count
end

# Test data
Article.create!(title: "Low Views", view_count: 10)
Article.create!(title: "Medium Views", view_count: 50)
Article.create!(title: "High Views", view_count: 100)
Article.create!(title: "Very High Views", view_count: 200)

# Greater than
Article.view_count_gt(50).pluck(:title)
# => ["High Views", "Very High Views"]

# Greater than or equal
Article.view_count_gteq(50).pluck(:title)
# => ["Medium Views", "High Views", "Very High Views"]

# Less than
Article.view_count_lt(50).pluck(:title)
# => ["Low Views"]

# Less than or equal
Article.view_count_lteq(50).pluck(:title)
# => ["Low Views", "Medium Views"]

# Between (inclusive)
Article.view_count_between(50, 150).pluck(:title)
# => ["Medium Views", "High Views"]

# In array
Article.view_count_in([10, 100]).pluck(:title)
# => ["Low Views", "High Views"]

# Not in array
Article.view_count_not_in([10, 100]).pluck(:title)
# => ["Medium Views", "Very High Views"]
```

**Output Explanation**: Numeric predicates provide comprehensive comparison operators for filtering.

## Example 4: Date/DateTime Predicates

Date and datetime fields get powerful time-based scopes:

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :published_at, :created_at
end

# Test data
Article.create!(title: "Today", published_at: Time.current)
Article.create!(title: "Yesterday", published_at: 1.day.ago)
Article.create!(title: "Last Week", published_at: 8.days.ago)
Article.create!(title: "Last Month", published_at: 35.days.ago)

# Comparison
Article.published_at_gt(7.days.ago).pluck(:title)
# => ["Today", "Yesterday"]

Article.published_at_lt(2.days.ago).pluck(:title)
# => ["Last Week", "Last Month"]

# Between dates
Article.published_at_between(10.days.ago, 2.days.ago).pluck(:title)
# => ["Last Week"]

# Within duration (last N days)
Article.published_at_within(7.days).pluck(:title)
# => ["Today", "Yesterday"]

# Specific time periods
Article.published_at_today.pluck(:title)
# => ["Today"]

Article.published_at_yesterday.pluck(:title)
# => ["Yesterday"]

Article.published_at_this_week.pluck(:title)
# => ["Today", "Yesterday"]

Article.published_at_this_month.pluck(:title)
# => ["Today", "Yesterday", "Last Week"]

Article.published_at_this_year.pluck(:title)
# => ["Today", "Yesterday", "Last Week", "Last Month"]

# Date components
Article.published_at_year(2025).count
# => 4 (all articles from 2025)

Article.published_at_month(10).count
# => 4 (all articles from October)

Article.published_at_day(30).count
# => 1 (articles published on 30th)
```

**Output Explanation**: Date predicates provide both relative (within, today, this_week) and absolute (year, month, day) filtering.

## Example 5: Boolean Predicates

Boolean fields get simple true/false scopes:

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :featured
end

# Test data
Article.create!(title: "Featured Article", featured: true)
Article.create!(title: "Normal Article", featured: false)
Article.create!(title: "Unset Article", featured: nil)

# Boolean checks
Article.featured_true.pluck(:title)
# => ["Featured Article"]

Article.featured_false.pluck(:title)
# => ["Normal Article", "Unset Article"]

# Note: featured_false includes nil by default
# Use presence check if needed
Article.featured_present.featured_false.pluck(:title)
# => ["Normal Article"]
```

**Output Explanation**: Boolean predicates treat nil as false by default, use `_present` to exclude nil.

## Example 6: Chaining Predicates

Combine multiple predicates for complex queries:

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :status, :view_count, :featured, :published_at
end

# Complex filtering
Article
  .status_eq("published")
  .view_count_gteq(100)
  .published_at_within(30.days)
  .featured_true
  .pluck(:title)
# => All featured, published articles with 100+ views in last 30 days

# Multiple conditions on same field
Article
  .view_count_gteq(50)
  .view_count_lt(200)
  .pluck(:title)
# => Articles with 50-199 views

# Combining presence checks
Article
  .published_at_present
  .status_eq("published")
  .count
# => Count of published articles with publication date

# Complex date filtering
Article
  .published_at_this_year
  .published_at_not_in_month(12)  # Not December
  .view_count_gt(100)
  .pluck(:title, :published_at, :view_count)
# => [[title, date, views], ...]
```

**Output Explanation**: Predicates chain naturally with ActiveRecord, enabling complex queries without custom SQL.

## Advanced Features

### Working with Associations

```ruby
class User < ApplicationRecord
  has_many :articles
end

class Article < ApplicationRecord
  include BetterModel
  belongs_to :user
  predicates :status, :published_at
end

# Query through associations
user = User.first
user.articles.status_eq("published").count
# => Count of user's published articles

user.articles
  .published_at_this_month
  .status_eq("published")
  .pluck(:title)
# => User's articles published this month
```

### Checking Available Predicates

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :status, :view_count
end

# Check if field has predicates
Article.predicable_field?(:title)
# => true

Article.predicable_field?(:content)
# => false

# Get all predicable fields
Article.predicable_fields
# => [:title, :status, :view_count]

# Get all scopes for a field
Article.predicable_scopes
# => [:title_eq, :title_not_eq, :title_present, :title_cont, ...]
```

## Tips & Best Practices

### 1. Only Enable Predicates for Filterable Fields
```ruby
# Good: Only fields you'll actually filter by
predicates :status, :published_at, :featured

# Avoid: Every field including content
predicates :title, :content, :meta_description  # content rarely filtered
```

### 2. Use Predicates with Searchable
```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :published_at, :view_count
  sort :title, :published_at, :view_count

  # Searchable uses predicates automatically
  searchable do
    default_sort :published_at_desc
  end
end

# Now you can use unified search
Article.search({
  status_eq: "published",
  view_count_gteq: 100,
  published_at_within: 30.days
})
```

### 3. Avoid Ambiguous Naming
```ruby
# Your model
class Article < ApplicationRecord
  predicates :title

  # This conflicts with generated scope
  scope :title_eq, -> { where(special_condition: true) }
end

# Better: Use different names
class Article < ApplicationRecord
  predicates :title
  scope :special_title_filter, -> { where(special_condition: true) }
end
```

### 4. Performance with Indexes
```ruby
# Add indexes for commonly filtered fields
class AddIndexesToArticles < ActiveRecord::Migration[8.1]
  def change
    add_index :articles, :status
    add_index :articles, :published_at
    add_index :articles, :featured
    add_index :articles, [:status, :published_at]  # Composite for common combo
  end
end
```

### 5. PostgreSQL/MySQL Specific Features

```ruby
# PostgreSQL array predicates (automatic)
class Article < ApplicationRecord
  include BetterModel
  predicates :tags  # Array column on PostgreSQL
end

# Automatically available on PostgreSQL
Article.tags_overlaps(["ruby", "rails"])
Article.tags_contains(["ruby"])
Article.tags_contained_by(["ruby", "rails", "python"])

# PostgreSQL JSONB predicates
class Article < ApplicationRecord
  include BetterModel
  predicates :metadata  # JSONB column
end

Article.metadata_has_key("author")
Article.metadata_has_any_key(["author", "editor"])
Article.metadata_jsonb_contains({ author: "John" })
```

## Example 7: Complex Predicates

For filtering logic that requires combining multiple fields or custom SQL, use `register_complex_predicate`:

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at

  # Register a complex predicate for trending articles
  # Combines view count and publication date logic
  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 1000, 7.days.ago)
  end

  # Register a complex predicate with parameters
  register_complex_predicate :popular_within do |days, min_views|
    where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
  end

  # Register a complex predicate with association logic
  register_complex_predicate :with_active_author do
    joins(:author).where(authors: { active: true })
  end

  # Register a complex predicate with OR conditions
  register_complex_predicate :needs_review do
    where("status = ? OR (published_at IS NULL AND created_at < ?)",
          "draft", 30.days.ago)
  end
end

# Usage: Complex predicates work like regular scopes

# Simple usage (no parameters)
@trending = Article.trending
# => Articles with 1000+ views published in last 7 days

# Parameterized usage
@popular = Article.popular_within(14, 500)
# => Articles with 500+ views published in last 14 days

# Chaining with generated predicates
@featured_trending = Article
  .trending
  .status_eq("published")
  .limit(10)
# => Top 10 published trending articles

# Combining multiple complex predicates
@high_quality = Article
  .popular_within(30, 1000)
  .with_active_author
  .status_eq("published")
# => Published articles by active authors with 1000+ views (last 30 days)

# Using OR conditions
@review_queue = Article
  .needs_review
  .order(created_at: :asc)
# => Drafts or old unpublished articles
```

### Real-World Example: E-commerce Product Filtering

```ruby
class Product < ApplicationRecord
  include BetterModel

  predicates :name, :price, :stock, :rating, :category

  # Low stock alert (complex logic)
  register_complex_predicate :low_stock do
    where("stock > 0 AND stock < 10")
  end

  # Best sellers (combines sales and ratings)
  register_complex_predicate :best_sellers do |days = 30|
    where("sales_count >= ? AND rating >= ? AND created_at >= ?",
          100, 4.0, days.days.ago)
  end

  # Clearance items (old inventory with stock)
  register_complex_predicate :clearance do
    where("stock > 0 AND created_at < ? AND sales_count < ?",
          6.months.ago, 10)
  end

  # Featured in category (joins categories table)
  register_complex_predicate :featured_in_category do |category_name|
    joins(:category)
      .where(categories: { name: category_name }, featured: true)
  end
end

# Controller usage
class ProductsController < ApplicationController
  def index
    @products = Product.all

    # Apply complex predicates based on filter params
    case params[:filter]
    when 'trending'
      @products = @products.best_sellers(7)
    when 'clearance'
      @products = @products.clearance
    when 'low_stock'
      @products = @products.low_stock
    end

    # Combine with standard predicates
    if params[:category].present?
      @products = @products.featured_in_category(params[:category])
    end

    @products = @products
      .price_between(params[:min_price], params[:max_price])
      .page(params[:page])
  end
end
```

**Output Explanation**: Complex predicates encapsulate business logic and can be combined with generated predicates for powerful, maintainable queries.

## Related Documentation

- [Main README](../../README.md#predicable) - Full Predicable documentation
- [Searchable Examples](05_searchable.md) - Use predicates in unified search
- [Sortable Examples](04_sortable.md) - Combine with sorting
- [Test File](../../test/better_model/predicable_test.rb) - Complete test coverage

---

[← Permissible Examples](02_permissible.md) | [Back to Examples Index](README.md) | [Next: Sortable Examples →](04_sortable.md)
