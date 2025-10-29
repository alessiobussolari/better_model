## Predicable - Type-Aware Filtering System

Define filtering capabilities on your models with automatic predicate generation based on column types. Use expressive method names like `title_cont`, `view_count_between`, `published_at_today`, and `tags_overlaps`.

**Key Benefits:**
- **Type-aware:** Different predicates for strings, numbers, dates, booleans, arrays, and JSONB
- **Semantic naming:** Clear, readable predicate names
- **Range queries:** Built-in `_between` for numeric and date ranges
- **Date convenience:** Shortcuts like `_today`, `_this_week`, `_past`, `_future`
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

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_present` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `title_present` → `WHERE title IS NOT NULL AND title != ''` (string) |
| `_blank` | 🟢 📅 | ✅ | ✅ | ✅ | `title_blank` → `WHERE title IS NULL OR title = ''` |
| `_null` | 🟢 📅 | ✅ | ✅ | ✅ | `published_at_null` → `WHERE published_at IS NULL` |
| `_not_null` | 📅 | ✅ | ✅ | ✅ | `published_at_not_null` → `WHERE published_at IS NOT NULL` |

#### Boolean Predicates

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_true` | ☑️ | ✅ | ✅ | ✅ | `featured_true` → `WHERE featured = TRUE` |
| `_false` | ☑️ | ✅ | ✅ | ✅ | `featured_false` → `WHERE featured = FALSE` |

#### Date Convenience Predicates

| Predicato | Tipi Campo | SQLite | MySQL | PostgreSQL | Esempio |
|-----------|-----------|--------|-------|------------|---------|
| `_today` | 📅 | ✅ | ✅ | ✅ | `published_at_today` → Records pubblicati oggi |
| `_yesterday` | 📅 | ✅ | ✅ | ✅ | `published_at_yesterday` → Records di ieri |
| `_this_week` | 📅 | ✅ | ✅ | ✅ | `published_at_this_week` → Da inizio settimana |
| `_this_month` | 📅 | ✅ | ✅ | ✅ | `published_at_this_month` → Da inizio mese |
| `_this_year` | 📅 | ✅ | ✅ | ✅ | `published_at_this_year` → Da inizio anno |
| `_past` | 📅 | ✅ | ✅ | ✅ | `scheduled_at_past` → `WHERE scheduled_at < NOW()` |
| `_future` | 📅 | ✅ | ✅ | ✅ | `scheduled_at_future` → `WHERE scheduled_at > NOW()` |
| `_within` | 📅 | ✅ | ✅ | ✅ | `created_at_within(7.days)` o `within(7)` → Ultimi 7 giorni |

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

| Tipo Campo | Scope Base | Scope Complessi | Totale |
|------------|------------|-----------------|--------|
| **String** (`title`, `status`) | 14 scopes | - | **14 scopes** |
| **Numeric** (`view_count`, `price`) | 9 scopes | +2 range | **11 scopes** |
| **Boolean** (`featured`, `active`) | 5 scopes | - | **5 scopes** |
| **Date** (`published_at`, `created_at`) | 12 scopes | +10 convenience | **22 scopes** |
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

# Boolean predicates
Article.featured_true

# Date predicates
Article.published_at_gteq(1.week.ago)
Article.published_at_today
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
  .published_at_this_month
  .sort_view_count_desc
  .limit(10)

# Search with multiple filters
Article
  .title_i_cont("ruby")
  .view_count_between(50, 500)
  .published_at_within(60.days)
  .featured_true
  .sort_published_at_newest

# Complex date filtering
Article
  .published_at_past
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
Article.recent_popular(7, 100)
Article.trending
Article.recent_popular.trending  # Can chain with other scopes
```

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
             .featured_true
             .sort_view_count_desc
             .limit(5)

# Search posts
@results = Post.title_i_cont(params[:query])
               .published_at_this_month
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
                   .featured_true
                   .sort_price_asc
```

**Event Management:**
```ruby
class Event < ApplicationRecord
  include BetterModel

  predicates :title, :start_date, :end_date, :status, :capacity
end

# Upcoming events
@events = Event.start_date_future
              .status_not_in(["cancelled", "completed"])
              .capacity_gt(0)
              .sort_start_date_asc
              .limit(10)

# This week's events
@events = Event.start_date_this_week
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
| **Date Convenience** (`_today`, `_within`) | ✅ | ✅ | ✅ | ActiveSupport date helpers |
| **Array Operators** (`_overlaps`) | ❌ | ❌ | ✅ | PostgreSQL array types only |
| **JSONB Operators** (`_has_key`) | ❌ | ❌ | ✅ | PostgreSQL JSONB only |

### Best Practices

1. **Use semantic predicates** - `published_at_today` is clearer than `published_at_between(Date.today.beginning_of_day, Date.today.end_of_day)`
2. **Leverage case-insensitive search** - Use `_i_cont` for user-facing search
3. **Chain predicates logically** - Filter first (most restrictive), then sort
4. **Use `_within` for recency** - More readable than manual date comparisons
5. **Register complex business logic** - Use `register_complex_predicate` for multi-field filters
6. **Avoid N+1 queries** - Load associations before applying predicates
7. **Index filtered columns** - Add database indexes for frequently filtered fields

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

