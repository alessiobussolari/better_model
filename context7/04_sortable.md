# Sortable - Type-Aware Ordering System

Declarative sorting system that automatically generates ordering scopes based on column types. Provides semantic names like `sort_title_asc`, `sort_published_at_newest`, with case-insensitive and NULL handling variants.

**Requirements**: Rails 8.0+, Ruby 3.0+, ActiveRecord model
**Installation**: No migration required - include BetterModel and call `sort`

**⚠️ Version 3.0.0 Compatible**: All error handling in this document uses standard Ruby exception patterns.

---

## Basic Setup

### Simple Sort Declaration

**Cosa fa**: Registers fields for automatic sort scope generation

**Quando usarlo**: To enable ordering on specific model fields

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  # Declare sortable fields
  sort :title, :view_count, :published_at
end

# System generates scopes based on column types:
# - title (string) → _asc, _desc, _asc_i, _desc_i
# - view_count (integer) → _asc, _desc, _asc_nulls_last, etc.
# - published_at (datetime) → _newest, _oldest, _asc, _desc, etc.

# Usage
Article.sort_title_asc
Article.sort_view_count_desc
Article.sort_published_at_newest
```

---

## String Field Sorting

### Alphabetical Sorting

**Cosa fa**: Case-sensitive alphabetical ordering

**Quando usarlo**: For exact alphabetical order

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  sort :title, :author_name
end

# Ascending (A-Z)
Article.sort_title_asc
# => ORDER BY title ASC

# Descending (Z-A)
Article.sort_title_desc
# => ORDER BY title DESC

# By author
Article.sort_author_name_asc
```

---

### Case-Insensitive Sorting

**Cosa fa**: Case-insensitive alphabetical ordering

**Quando usarlo**: For user-friendly listings (recommended for UI)

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  sort :title
end

# Case-insensitive ascending
Article.sort_title_asc_i
# => ORDER BY LOWER(title) ASC
# Results: ["Alpha", "alpha", "Beta", "beta"]

# Case-insensitive descending
Article.sort_title_desc_i
# => ORDER BY LOWER(title) DESC

# Why it matters:
# Case-sensitive: ["Alpha", "Beta", "alpha", "beta"]  # Capital first
# Case-insensitive: ["Alpha", "alpha", "Beta", "beta"]  # Natural order
```

---

## Numeric Field Sorting

### Basic Numeric Ordering

**Cosa fa**: Sorts by numeric values

**Quando usarlo**: For prices, counts, ratings

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel
  sort :price, :stock, :rating
end

# Lowest to highest
Product.sort_price_asc
# => ORDER BY price ASC

# Highest to lowest
Product.sort_price_desc
# => ORDER BY price DESC

# Most in stock first
Product.sort_stock_desc

# Highest rated first
Product.sort_rating_desc
```

---

### NULL Handling

**Cosa fa**: Explicit control over NULL value positioning

**Quando usarlo**: When NULL values need specific placement

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel
  sort :price, :stock, :rating
end

# Cheapest first, items without price at end
Product.sort_price_asc_nulls_last
# => ORDER BY price ASC NULLS LAST

# Most expensive first, items without price at end
Product.sort_price_desc_nulls_last
# => ORDER BY price DESC NULLS LAST

# Unrated products first (for review queue)
Product.sort_rating_asc_nulls_first
# => ORDER BY rating ASC NULLS FIRST

# Highest rated first, unrated at end
Product.sort_rating_desc_nulls_last
# => ORDER BY rating DESC NULLS LAST
```

---

## Date Field Sorting

### Semantic Date Ordering

**Cosa fa**: Uses semantic names (newest/oldest) for date sorting

**Quando usarlo**: For better readability with date fields

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  sort :published_at, :created_at, :updated_at
end

# Most recent first (semantic)
Article.sort_published_at_newest
# => ORDER BY published_at DESC

# Oldest first (semantic)
Article.sort_published_at_oldest
# => ORDER BY published_at ASC

# Standard direction scopes also work
Article.sort_published_at_desc  # Same as _newest
Article.sort_published_at_asc   # Same as _oldest

# Recently updated first
Article.sort_updated_at_newest

# Oldest creation date first
Article.sort_created_at_oldest
```

---

### Date Sorting with NULL Handling

**Cosa fa**: Controls where unpublished/unscheduled items appear

**Quando usarlo**: When dealing with optional date fields

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  sort :published_at, :scheduled_for
end

# Published articles newest first, unpublished at end
Article.sort_published_at_newest_nulls_last
# => ORDER BY published_at DESC NULLS LAST

# Oldest first, unpublished at end
Article.sort_published_at_oldest_nulls_last
# => ORDER BY published_at ASC NULLS LAST

# Scheduled items by date, unscheduled first
Article.sort_scheduled_for_asc_nulls_first
```

---

## Multi-Column Sorting

### Chaining Sort Scopes

**Cosa fa**: Combines multiple ordering criteria

**Quando usarlo**: For complex sorting with primary, secondary, tertiary order

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  sort :published_at, :view_count, :title
end

# Primary: newest first
# Secondary: most viewed
# Tertiary: alphabetical
Article
  .sort_published_at_newest
  .sort_view_count_desc
  .sort_title_asc_i

# Generated SQL:
# ORDER BY published_at DESC, view_count DESC, LOWER(title) ASC

# Each scope returns ActiveRecord::Relation
# Chain order = SQL ORDER BY order
```

---

### Task Prioritization

**Cosa fa**: Multi-level task sorting

**Quando usarlo**: Task management, issue tracking

**Esempio**:
```ruby
class Task < ApplicationRecord
  include BetterModel
  sort :priority, :due_date, :title, :created_at
end

# High priority first, then by due date, then alphabetical
Task
  .sort_priority_desc
  .sort_due_date_asc_nulls_last
  .sort_title_asc_i

# Overdue tasks: past due first, then by priority
Task.where('due_date < ?', Date.today)
    .sort_due_date_asc
    .sort_priority_desc
    .sort_title_asc_i

# Completed recently first
Task.where(status: 'completed')
    .sort_updated_at_newest
    .sort_priority_desc
```

---

### Product Catalog Sorting

**Cosa fa**: E-commerce multi-criteria sorting

**Quando usarlo**: Product listings

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel
  sort :category, :price, :name, :created_at, :rating
end

# Group by category, then by price, then alphabetical
Product
  .sort_category_asc_i
  .sort_price_asc
  .sort_name_asc_i

# New arrivals: newest first, alphabetical
Product.where('created_at >= ?', 7.days.ago)
       .sort_created_at_newest
       .sort_name_asc_i

# Featured: highest rated with stock, expensive first
Product.where('stock > 0')
       .sort_rating_desc_nulls_last
       .sort_price_desc
       .limit(10)
```

---

## Complex Custom Sorts

### Basic Complex Sort

**Cosa fa**: Defines custom sorting logic

**Quando usarlo**: For business-specific ordering not covered by standard scopes

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  sort :name, :price, :stock

  # Custom sort with CASE logic
  register_complex_sort :by_availability do
    order(Arel.sql(<<-SQL))
      CASE
        WHEN stock > 10 THEN 1
        WHEN stock > 0 THEN 2
        ELSE 3
      END,
      name ASC
    SQL
  end

  # Custom sort by popularity
  register_complex_sort :by_popularity do
    order('view_count * 0.5 + orders_count * 2 DESC')
  end
end

# Usage
Product.sort_by_availability
Product.sort_by_popularity

# Chainable
Product.sort_by_availability.sort_price_asc
```

---

### Priority-Based Sort

**Cosa fa**: Custom priority ordering with fallback

**Quando usarlo**: Task management, issue tracking

**Esempio**:
```ruby
class Task < ApplicationRecord
  include BetterModel

  sort :title, :due_date, :created_at

  # Priority: critical > high > medium > low > none
  register_complex_sort :by_priority do
    order(Arel.sql(<<-SQL))
      CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        ELSE 5
      END,
      due_date ASC NULLS LAST,
      created_at DESC
    SQL
  end
end

# Usage
Task.where(status: 'open').sort_by_priority
```

---

### Geographic Distance Sort

**Cosa fa**: Sorts by calculated distance

**Quando usarlo**: Location-based services

**Esempio**:
```ruby
class Store < ApplicationRecord
  include BetterModel

  sort :name, :rating

  # Sort by distance from coordinates
  register_complex_sort :by_distance do |lat, lng|
    distance_formula = <<-SQL
      (6371 * acos(
        cos(radians(#{lat})) *
        cos(radians(latitude)) *
        cos(radians(longitude) - radians(#{lng})) +
        sin(radians(#{lat})) *
        sin(radians(latitude))
      ))
    SQL

    order(Arel.sql(distance_formula))
  end
end

# Usage with parameters
Store.sort_by_distance(40.7128, -74.0060)  # NYC coordinates
```

---

### Time-Based Smart Sort

**Cosa fa**: Different sorting based on time criteria

**Quando usarlo**: Content feeds, activity streams

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :title, :published_at, :view_count

  # Recent articles: by date; older articles: by popularity
  register_complex_sort :smart do
    order(Arel.sql(<<-SQL))
      CASE
        WHEN published_at >= NOW() - INTERVAL '7 days'
          THEN published_at
        ELSE NULL
      END DESC NULLS LAST,
      CASE
        WHEN published_at < NOW() - INTERVAL '7 days'
          THEN view_count
        ELSE 0
      END DESC,
      published_at DESC
    SQL
  end
end

# Usage
Article.where(status: 'published').sort_smart
```

---

## Real-World Use Cases

### News Feed

**Cosa fa**: Content feed with recency and engagement

**Quando usarlo**: Blog, news, social media

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :published_at, :view_count, :title

  register_complex_sort :trending do
    where('published_at >= ?', 7.days.ago)
      .order('view_count DESC, published_at DESC')
  end
end

# Main feed: newest first
@feed = Article.where(status: 'published')
               .sort_published_at_newest
               .limit(50)

# Trending: recent + popular
@trending = Article.sort_trending.limit(10)

# Archives: oldest first, alphabetical
@archive = Article.where(status: 'archived')
                  .sort_published_at_oldest
                  .sort_title_asc_i
```

---

### E-commerce Product Listing

**Cosa fa**: Multi-faceted product sorting

**Quando usarlo**: Online stores

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  sort :name, :price, :stock, :rating, :created_at

  register_complex_sort :recommended do
    order('rating DESC NULLS LAST, orders_count DESC, created_at DESC')
  end
end

# Controller with sorting options
class ProductsController < ApplicationController
  def index
    @products = Product.where('stock > 0')

    case params[:sort]
    when 'price_low'
      @products = @products.sort_price_asc
    when 'price_high'
      @products = @products.sort_price_desc
    when 'newest'
      @products = @products.sort_created_at_newest
    when 'rating'
      @products = @products.sort_rating_desc_nulls_last
    when 'name'
      @products = @products.sort_name_asc_i
    else
      @products = @products.sort_recommended
    end

    @products = @products.page(params[:page]).per(24)
  end
end
```

---

### User Directory

**Cosa fa**: User listing with activity sorting

**Quando usarlo**: Admin panels, member directories

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  sort :name, :email, :created_at, :last_sign_in_at

  register_complex_sort :by_activity do
    order(Arel.sql(<<-SQL))
      CASE
        WHEN last_sign_in_at >= NOW() - INTERVAL '7 days' THEN 1
        WHEN last_sign_in_at >= NOW() - INTERVAL '30 days' THEN 2
        WHEN last_sign_in_at IS NOT NULL THEN 3
        ELSE 4
      END,
      last_sign_in_at DESC NULLS LAST,
      name ASC
    SQL
  end
end

# Active users: recent activity first, alphabetical
@active = User.where('last_sign_in_at >= ?', 30.days.ago)
              .sort_last_sign_in_at_newest
              .sort_name_asc_i

# All users: active first, alphabetical
@all = User.sort_by_activity

# New registrations
@new = User.where('created_at >= ?', 7.days.ago)
           .sort_created_at_newest
           .sort_name_asc_i
```

---

### Event Calendar

**Cosa fa**: Event sorting with time awareness

**Quando usarlo**: Event management, booking systems

**Esempio**:
```ruby
class Event < ApplicationRecord
  include BetterModel

  sort :start_date, :title, :capacity, :registered_count

  register_complex_sort :upcoming do
    where('start_date >= ?', Date.today)
      .order('start_date ASC, title ASC')
  end

  register_complex_sort :availability do
    order(Arel.sql(<<-SQL))
      CASE
        WHEN registered_count >= capacity THEN 3
        WHEN registered_count >= capacity * 0.9 THEN 2
        ELSE 1
      END,
      start_date ASC
    SQL
  end
end

# Upcoming events
@upcoming = Event.sort_upcoming.limit(20)

# Events by availability (spaces available first)
@events = Event.where('start_date >= ?', Date.today)
               .sort_availability

# Past events: most recent first
@past = Event.where('start_date < ?', Date.today)
             .sort_start_date_newest
```

---

### Job Queue

**Cosa fa**: Job/task queue with priority sorting

**Quando usarlo**: Background job systems

**Esempio**:
```ruby
class Job < ApplicationRecord
  include BetterModel

  sort :priority, :created_at, :scheduled_for

  register_complex_sort :queue_order do
    order(Arel.sql(<<-SQL))
      CASE status
        WHEN 'failed' THEN 1
        WHEN 'running' THEN 2
        WHEN 'pending' THEN 3
        ELSE 4
      END,
      priority DESC,
      scheduled_for ASC NULLS LAST,
      created_at ASC
    SQL
  end
end

# Processing queue
@queue = Job.where(status: ['pending', 'failed'])
            .sort_queue_order
            .limit(100)

# Failed jobs: oldest first
@failed = Job.where(status: 'failed')
             .sort_created_at_oldest

# Scheduled jobs: next scheduled first
@scheduled = Job.where('scheduled_for IS NOT NULL')
                .sort_scheduled_for_asc
```

---

## Introspection Methods

### Checking Sort Scopes

**Cosa fa**: Runtime introspection of registered sorts

**Quando usarlo**: For building dynamic UIs or validation

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :title, :published_at, :view_count

  register_complex_sort :trending do
    order('view_count DESC, published_at DESC')
  end
end

# Check if field is sortable
Article.sortable_field?(:title)  # => true
Article.sortable_field?(:foo)    # => false

# Check if scope exists
Article.sortable_scope?(:sort_title_asc)  # => true
Article.sortable_scope?(:sort_foo_asc)    # => false

# Check complex sort
Article.complex_sort?(:trending)  # => true
Article.complex_sort?(:unknown)   # => false

# Get all sortable fields (returns frozen Set)
Article.sortable_fields
# => #<Set: {:title, :published_at, :view_count}>

# Get all sort scopes (returns frozen Set)
Article.sortable_scopes
# => #<Set: {:sort_title_asc, :sort_title_desc, :sort_published_at_newest, ...}>

# Get complex sorts (returns frozen Hash)
Article.complex_sorts_registry
# => {:trending => #<Proc:0x...>}
```

---

### Dynamic Sort Builder

**Cosa fa**: Builds sort from user parameters

**Quando usarlo**: For API sorting parameters

**Esempio**:
```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Validate and apply sort
    if params[:sort].present?
      field = params[:sort][:field]
      direction = params[:sort][:direction] || 'asc'
      scope_name = "sort_#{field}_#{direction}".to_sym

      if Article.sortable_scope?(scope_name)
        @articles = @articles.public_send(scope_name)
      else
        Rails.logger.warn "Invalid sort: #{scope_name}"
      end
    end

    render json: @articles
  end
end

# Request example:
# GET /articles?sort[field]=published_at&sort[direction]=newest
# GET /articles?sort[field]=title&sort[direction]=asc_i
```

---

## Best Practices

### Use Case-Insensitive for UI

**Cosa fa**: Case-insensitive sorting for better UX

**Quando usarlo**: For user-facing alphabetical lists

**Esempio**:
```ruby
# Good - case-insensitive for users
Article.sort_title_asc_i

# Bad - case-sensitive (capitals first)
Article.sort_title_asc  # "Alpha", "Beta", "alpha"
```

---

### Use Semantic Date Names

**Cosa fa**: Uses newest/oldest for readability

**Quando usarlo**: Always with date fields

**Esempio**:
```ruby
# Good - clear intent
Article.sort_published_at_newest
Article.sort_created_at_oldest

# OK but less readable
Article.sort_published_at_desc
Article.sort_created_at_asc
```

---

### Handle NULLs Explicitly

**Cosa fa**: Controls NULL positioning

**Quando usarlo**: When NULL values need specific placement

**Esempio**:
```ruby
# Good - explicit NULL handling
Product.sort_price_asc_nulls_last
Product.sort_rating_desc_nulls_last

# Can be ambiguous - NULL position varies by database
Product.sort_price_asc
Product.sort_rating_desc
```

---

### Chain Logically

**Cosa fa**: Orders chains by importance

**Quando usarlo**: For multi-column sorting

**Esempio**:
```ruby
# Good - logical precedence
Product
  .sort_category_asc_i      # Group by category
  .sort_price_asc           # Then by price
  .sort_name_asc_i          # Then alphabetically

# Confusing - name gets overridden
Product
  .sort_name_asc_i          # Will be tertiary
  .sort_price_asc           # Will be secondary
  .sort_category_asc_i      # Will be primary
```

---

### Validate Complex Sort SQL

**Cosa fa**: Tests complex sort SQL for correctness

**Quando usarlo**: Always with custom SQL

**Esempio**:
```ruby
# Good - test the SQL
RSpec.describe Product do
  it "sorts by availability correctly" do
    in_stock = create(:product, stock: 15)
    low_stock = create(:product, stock: 5)
    out_of_stock = create(:product, stock: 0)

    results = Product.sort_by_availability

    expect(results.first).to eq(in_stock)
    expect(results.last).to eq(out_of_stock)
  end
end

# Good - check generated SQL
puts Product.sort_by_availability.to_sql
```

---

## Summary

**Core Features**:
- **Type-Aware Generation**: Different scopes for strings, numbers, dates
- **Semantic Naming**: `_newest/_oldest` for dates, `_i` for case-insensitive
- **NULL Handling**: `_nulls_first/_nulls_last` variants
- **Chainable**: Stack multiple orderings
- **Thread-Safe**: Frozen registries
- **Zero Runtime Overhead**: Compiled at class load

**Scope Patterns**:
- **String**: `_asc`, `_desc`, `_asc_i`, `_desc_i`
- **Numeric**: `_asc`, `_desc`, `_asc_nulls_last`, `_desc_nulls_last`, `_asc_nulls_first`, `_desc_nulls_first`
- **Date**: `_newest`, `_oldest`, `_asc`, `_desc`, plus NULL variants

**Key Methods**:
- `sort :field1, :field2` - Register fields
- `register_complex_sort :name do...end` - Custom sorts
- `sortable_field?(:name)` - Check if field sortable
- `sortable_scope?(:name)` - Check if scope exists
- `complex_sort?(:name)` - Check if complex sort exists
- `sortable_fields` - All registered fields
- `sortable_scopes` - All generated scopes
- `complex_sorts_registry` - All complex sorts

**Thread-safe**, **database-portable**, **integrated with Searchable**.
