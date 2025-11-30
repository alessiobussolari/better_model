## Predicable - Type-Aware Filtering System

Define filtering capabilities on your models with automatic predicate generation based on column types. Use expressive method names like `title_cont`, `view_count_between`, `published_at_within(7.days)`, and `tags_overlaps`.

**Key Benefits:**
- **Type-aware:** Different predicates for strings, numbers, dates, booleans, arrays, and JSONB
- **Semantic naming:** Clear, readable predicate names
- **Explicit parameters:** All predicates require explicit parameters (no defaults or shortcuts)
- **Range queries:** Built-in `_between` for numeric and date ranges
- **Pattern matching:** Case-sensitive and case-insensitive search
- **PostgreSQL support:** Advanced array and JSONB operators
- **Chainable:** Combine multiple filters easily
- **Thread-safe:** Immutable registries with frozen Sets

### Basic Predicable Usage

Simply call `predicates` with the fields you want to make filterable:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Auto-generate filtering scopes based on column types
  predicates :title, :status, :view_count, :published_at, :featured
end
```

### Complete Predicates Reference

#### Legend
- ✅ Fully supported on this database
- ❌ Not supported
- 🟢 String fields (text, varchar)
- 🔢 Numeric fields (integer, decimal, float, bigint)
- 📅 Date fields (date, datetime, timestamp, time)
- ☑️ Boolean fields
- 🗂️ Array columns (PostgreSQL only)
- 📦 JSONB columns (PostgreSQL only)

---

### Universal Predicates (All Databases)

#### Comparison Predicates

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_eq` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `title_eq("Ruby")` → `WHERE title = 'Ruby'` |
| `_not_eq` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `status_not_eq("draft")` → `WHERE status != 'draft'` |
| `_lt` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_lt(100)` → `WHERE view_count < 100` |
| `_lteq` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_lteq(100)` → `WHERE view_count <= 100` |
| `_gt` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_gt(100)` → `WHERE view_count > 100` |
| `_gteq` | 🔢 📅 | ✅ | ✅ | ✅ | `published_at_gteq(Date.today)` → `WHERE published_at >= '2025-10-29'` |

#### Range Predicates

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_between` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_between(100, 500)` → `WHERE view_count BETWEEN 100 AND 500` |
| `_not_between` | 🔢 📅 | ✅ | ✅ | ✅ | `published_at_not_between(date1, date2)` → `WHERE published_at NOT BETWEEN ...` |

#### Pattern Matching Predicates (String Only)

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_matches` | 🟢 | ✅ | ✅ | ✅ | `title_matches("%Ruby%")` → `WHERE title LIKE '%Ruby%'` |
| `_start` | 🟢 | ✅ | ✅ | ✅ | `title_start("Ruby")` → `WHERE title LIKE 'Ruby%'` |
| `_end` | 🟢 | ✅ | ✅ | ✅ | `title_end("Rails")` → `WHERE title LIKE '%Rails'` |
| `_cont` | 🟢 | ✅ | ✅ | ✅ | `title_cont("Rails")` → `WHERE title LIKE '%Rails%'` |
| `_not_cont` | 🟢 | ✅ | ✅ | ✅ | `title_not_cont("Draft")` → `WHERE title NOT LIKE '%Draft%'` |
| `_i_cont` | 🟢 | ✅ | ✅ | ✅ | `title_i_cont("rails")` → `WHERE LOWER(title) LIKE '%rails%'` (case-insensitive) |
| `_not_i_cont` | 🟢 | ✅ | ✅ | ✅ | `title_not_i_cont("draft")` → `WHERE LOWER(title) NOT LIKE '%draft%'` |

#### Array Predicates

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_in` | 🟢 🔢 📅 | ✅ | ✅ | ✅ | `status_in(["draft", "published"])` → `WHERE status IN ('draft', 'published')` |
| `_not_in` | 🟢 🔢 📅 | ✅ | ✅ | ✅ | `status_not_in(["archived"])` → `WHERE status NOT IN ('archived')` |

#### Presence Predicates

**IMPORTANT:** All presence predicates require an explicit boolean parameter - no defaults.

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_present(value)` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `title_present(true)` → `WHERE title IS NOT NULL` (has value)<br>`title_present(false)` → `WHERE title IS NULL` (no value) |
| `_blank(value)` | 🟢 📅 | ✅ | ✅ | ✅ | `title_blank(true)` → `WHERE title IS NULL OR title = ''`<br>`title_blank(false)` → `WHERE title IS NOT NULL AND title != ''` |
| `_null(value)` | 🟢 🔢 📅 | ✅ | ✅ | ✅ | `published_at_null(true)` → `WHERE published_at IS NULL`<br>`published_at_null(false)` → `WHERE published_at IS NOT NULL` |

#### Date Range Predicates

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_within(duration)` | 📅 | ✅ | ✅ | ✅ | `created_at_within(7.days)` o `within(7)` → Ultimi 7 giorni |

---

### PostgreSQL-Specific Predicates

These predicates are automatically generated **only** when using PostgreSQL and the appropriate column types.

#### Array Predicates (PostgreSQL Arrays)

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_overlaps` | 🗂️ | ❌ | ❌ | ✅ | `tags_overlaps(['ruby', 'rails'])` → `WHERE tags && ARRAY['ruby','rails']` |
| `_contains` | 🗂️ | ❌ | ❌ | ✅ | `tags_contains('ruby')` → `WHERE tags @> ARRAY['ruby']` |
| `_contained_by` | 🗂️ | ❌ | ❌ | ✅ | `tags_contained_by(['ruby', 'rails', 'python'])` → `WHERE tags <@ ARRAY[...]` |

#### JSONB Predicates (PostgreSQL JSONB)

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_has_key` | 📦 | ❌ | ❌ | ✅ | `metadata_has_key('email')` → `WHERE metadata ? 'email'` |
| `_has_any_key` | 📦 | ❌ | ❌ | ✅ | `metadata_has_any_key(['email', 'phone'])` → `WHERE metadata ?| ARRAY['email','phone']` |
| `_has_all_keys` | 📦 | ❌ | ❌ | ✅ | `metadata_has_all_keys(['email', 'phone'])` → `WHERE metadata ?& ARRAY[...]` |
| `_jsonb_contains` | 📦 | ❌ | ❌ | ✅ | `settings_jsonb_contains({active: true})` → `WHERE settings @> '{"active":true}'` |

---

### Scope Count by Field Type

**Note:** All predicates require explicit parameters - no defaults, no shortcuts.

| Tipo Campo | Scope Base | Scope Complessi | Totale |
|------------|------------|-----------------|--------|
| **String** (`title`, `status`) | 14 scopes | - | **14 scopes** |
| **Numeric** (`view_count`, `price`) | 9 scopes | +2 range | **11 scopes** |
| **Boolean** (`featured`, `active`) | 3 scopes | - | **3 scopes** |
| **Date** (`published_at`, `created_at`) | 12 scopes | +1 convenience | **13 scopes** |
| **Array** (PostgreSQL only) | 3 base | +3 operators | **6 scopes** |
| **JSONB** (PostgreSQL only) | 3 base | +4 operators | **7 scopes** |

---

### Usage Examples

#### Basic Filtering

```ruby
# String predicates
Article.title_eq("Ruby on Rails")
Article.title_cont("Rails")
Article.title_i_cont("rails")          # Case-insensitive
Article.status_in(["draft", "published"])

# Numeric predicates
Article.view_count_gt(100)
Article.view_count_between(50, 200)

# Boolean predicates (use _eq with true/false)
Article.featured_eq(true)
Article.archived_eq(false)

# Presence predicates (require explicit boolean parameter)
Article.title_present(true)            # Has a title
Article.title_present(false)           # No title
Article.published_at_null(true)        # Is NULL
Article.published_at_null(false)       # Is NOT NULL

# Date predicates
Article.published_at_gteq(1.week.ago)
Article.published_at_gteq(Date.today.beginning_of_day)
Article.created_at_within(30.days)     # Auto-detects Duration
Article.created_at_within(30)          # Or just numeric days
```

#### Advanced Chaining

Combine multiple predicates for complex queries:

```ruby
# Find popular published articles from this month
Article
  .status_eq("published")
  .view_count_gt(100)
  .published_at_gteq(Date.today.beginning_of_month)
  .sort_view_count_desc
  .limit(10)

# Search with multiple filters
Article
  .title_i_cont("ruby")
  .view_count_between(50, 500)
  .published_at_within(60.days)
  .featured_eq(true)
  .sort_published_at_newest

# Complex date filtering
Article
  .published_at_lt(Time.current)
  .view_count_gteq(100)
  .status_not_in(["archived", "deleted"])
  .sort_view_count_desc_nulls_last
```

#### PostgreSQL-Specific Examples

```ruby
# Array operations (PostgreSQL only)
Article.tags_overlaps(['ruby', 'rails'])
Article.tags_contains('postgres')
Article.tags_contained_by(['ruby', 'rails', 'python', 'javascript'])

# JSONB operations (PostgreSQL only)
User.settings_has_key('email_notifications')
User.settings_has_any_key(['email', 'phone'])
User.metadata_jsonb_contains({premium: true, active: true})
```

#### Duration Auto-Detection for `_within`

The `_within` predicate accepts both numeric values (interpreted as days) and `ActiveSupport::Duration` objects:

```ruby
# Numeric (days)
Article.published_at_within(7)          # Last 7 days

# ActiveSupport::Duration (flexible)
Article.published_at_within(7.days)
Article.published_at_within(2.weeks)
Article.published_at_within(6.hours)
Article.published_at_within(1.month)
Article.created_at_within(90.days)
```

### Custom Complex Predicates

For business logic that doesn't fit standard predicates, use `register_complex_predicate`:

#### API Reference: register_complex_predicate

**Method Signature:**
```ruby
register_complex_predicate(name, &block)
```

**Parameters:**
- `name` (Symbol): The name of the predicate scope (required)
- `block` (Proc): Filtering logic that returns an ActiveRecord::Relation

**Returns:** Registers a new scope on the model and adds it to `complex_predicates_registry`

**Thread Safety:** Registry is a frozen Hash, predicates defined at class load time

#### Basic Usage

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :view_count, :published_at

  # Register a custom complex predicate
  register_complex_predicate :recent_popular do |days = 7, min_views = 100|
    where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
  end

  # Another custom predicate
  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 1000, 24.hours.ago)
  end
end

# Usage
Article.recent_popular(7, 100)  # Custom parameters
Article.trending                 # Uses defaults
Article.recent_popular.trending  # Chainable with other scopes
```

#### Advanced Examples

**Multi-field with OR conditions:**
```ruby
register_complex_predicate :high_visibility do
  where("view_count > ? OR featured = ?", 1000, true)
end

Article.high_visibility  # Articles with >1000 views OR featured
```

**Association queries:**
```ruby
register_complex_predicate :with_recent_comments do
  joins(:comments)
    .where("comments.created_at > ?", 7.days.ago)
    .distinct
end

Article.with_recent_comments  # Articles with comments from last 7 days
```

**Complex SQL with CASE WHEN:**
```ruby
register_complex_predicate :by_relevance do |keyword|
  order(
    Arel.sql(
      "CASE WHEN title ILIKE '%#{sanitize_sql_like(keyword)}%' THEN 1 " \
      "WHEN content ILIKE '%#{sanitize_sql_like(keyword)}%' THEN 2 " \
      "ELSE 3 END"
    )
  )
end

Article.by_relevance('Rails').limit(10)  # Ordered by relevance
```

**Combining filters and sorting:**
```ruby
register_complex_predicate :trending_popular do |days = 7|
  where("published_at >= ? AND view_count >= ?", days.days.ago, 500)
    .order(view_count: :desc, published_at: :desc)
end

Article.trending_popular(14)  # Last 14 days, 500+ views, sorted
```

#### Use Cases

- **Business logic aggregation:** Combine multiple conditions into named filters
- **Cross-field filtering:** Conditions spanning multiple fields or associations
- **Dynamic filtering:** Accept parameters for flexible, reusable predicates
- **Performance optimization:** Pre-structure complex queries for reusability

### Class Methods

```ruby
# Check if a field has predicates
Article.predicable_field?(:title)      # => true
Article.predicable_field?(:nonexistent) # => false

# Check if a predicate scope exists
Article.predicable_scope?(:title_cont)  # => true

# Check if a complex predicate is registered
Article.complex_predicate?(:recent_popular)  # => true

# Get all predicable fields
Article.predicable_fields
# => #<Set: {:title, :status, :view_count, :published_at, :featured}>

# Get all predicate scopes
Article.predicable_scopes
# => #<Set: {:title_eq, :title_cont, :view_count_gt, :published_at_today, ...}>

# Get all complex predicates
Article.complex_predicates_registry
# => {:recent_popular => #<Proc>, :trending => #<Proc>}
```

### Real-World Examples

**Blog Platform:**
```ruby
class Post < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at, :tags

  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
  end
end

# Featured trending posts
@posts = Post.status_eq("published")
             .trending
             .featured_eq(true)
             .sort_view_count_desc
             .limit(5)

# Search posts
@results = Post.title_i_cont(params[:query])
               .published_at_gteq(Date.today.beginning_of_month)
               .view_count_gt(50)
```

**E-commerce:**
```ruby
class Product < ApplicationRecord
  include BetterModel

  predicates :name, :price, :stock, :category, :featured

  register_complex_predicate :in_stock do
    where("stock > 0")
  end
end

# Browse products
@products = Product.category_eq("electronics")
                   .price_between(100, 500)
                   .in_stock
                   .featured_eq(true)
                   .sort_price_asc
```

**Event Management:**
```ruby
class Event < ApplicationRecord
  include BetterModel

  predicates :title, :start_date, :end_date, :status, :capacity
end

# Upcoming events
@events = Event.start_date_gt(Time.current)
              .status_not_in(["cancelled", "completed"])
              .capacity_gt(0)
              .sort_start_date_asc
              .limit(10)

# This week's events
@events = Event.start_date_gteq(Date.today.beginning_of_week)
              .start_date_lteq(Date.today.end_of_week)
              .status_eq("confirmed")
```

### Database Compatibility Matrix

| Feature Category | SQLite | MySQL/MariaDB | PostgreSQL | Notes |
|------------------|--------|---------------|------------|-------|
| **Comparison** (`_eq`, `_lt`, etc.) | ✅ | ✅ | ✅ | Universal support |
| **Range** (`_between`) | ✅ | ✅ | ✅ | Native BETWEEN clause |
| **Pattern Matching** (`_cont`, `_start`) | ✅ | ✅ | ✅ | LIKE-based, SQL injection safe |
| **Case-Insensitive** (`_i_cont`) | ✅ | ✅ | ✅ | LOWER() function |
| **Array Operations** (`_in`) | ✅ | ✅ | ✅ | Standard SQL IN |
| **Presence** (`_present`, `_null`) | ✅ | ✅ | ✅ | Require explicit boolean parameter |
| **Date Range** (`_within`) | ✅ | ✅ | ✅ | ActiveSupport duration support |
| **Array Operators** (`_overlaps`) | ❌ | ❌ | ✅ | PostgreSQL array types only |
| **JSONB Operators** (`_has_key`) | ❌ | ❌ | ✅ | PostgreSQL JSONB only |

### Best Practices

1. **Always use explicit parameters** - All predicates require explicit parameters (no defaults). Use `title_present(true)` not `title_present`
2. **Use `_eq` for booleans** - Use `featured_eq(true)` instead of removed `featured_true` shortcut
3. **Leverage case-insensitive search** - Use `_i_cont` for user-facing search
4. **Chain predicates logically** - Filter first (most restrictive), then sort
5. **Use `_within` for recency** - More readable than manual date comparisons: `published_at_within(7.days)`
6. **Register complex business logic** - Use `register_complex_predicate` for multi-field filters
7. **Avoid N+1 queries** - Load associations before applying predicates
8. **Index filtered columns** - Add database indexes for frequently filtered fields

### Thread Safety

Predicable registries are thread-safe:
- `predicable_fields` is a frozen Set
- `predicable_scopes` is a frozen Set
- `complex_predicates_registry` is a frozen Hash
- Scopes are defined once at class load time
- No mutable shared state

### Performance Notes

- **Zero runtime overhead** - Predicates compiled at class load time
- **Efficient SQL** - Uses Arel for universal predicates, raw SQL only for PostgreSQL-specific
- **Registry lookups** - O(1) with Set/Hash data structures
- **Memory footprint** - ~150-200 bytes per model for registries
- **Conditional generation** - PostgreSQL predicates only generated when needed

### Error Handling

> **ℹ️ Version 3.0.0 Compatible**: All error examples use standard Ruby exception patterns with `e.message`. Domain-specific attributes and Sentry helpers have been removed in v3.0.0 for simplicity.

Predicable raises ConfigurationError for invalid configuration during class definition:

```ruby
# Invalid field type
begin
  predicates :nonexistent_field
rescue BetterModel::Errors::Predicable::ConfigurationError => e
  # Only message available in v3.0.0
  e.message
  # => "Field does not exist in model: nonexistent_field"

  # Log or report
  Rails.logger.error("Predicable configuration error: #{e.message}")
  Sentry.capture_exception(e)
end
```

**Integration with Sentry:**

```ruby
rescue_from BetterModel::Errors::Predicable::ConfigurationError do |error|
  Rails.logger.error("Configuration error: #{error.message}")
  Sentry.capture_exception(error)
  render json: { error: "Server configuration error" }, status: :internal_server_error
end
```

