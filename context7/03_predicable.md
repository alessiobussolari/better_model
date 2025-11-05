# BetterModel Predicable Feature Documentation

BetterModel Predicable is a comprehensive type-aware filtering system that automatically generates query scopes for ActiveRecord models based on column types and database capabilities. Unlike manual scope definition or query builders that require verbose syntax, Predicable introspects your model's schema and generates semantic, chainable query methods like `title_cont("Rails")`, `view_count_between(100, 500)`, `published_at_within(7.days)`, and `tags_overlaps(['ruby', 'rails'])`. When you include BetterModel in any ActiveRecord model and call `predicates :field1, :field2`, the system analyzes each field's database column type and generates an appropriate set of filtering scopes: string fields receive pattern matching predicates, numeric fields get comparison and range predicates, date fields include the `_within` convenience predicate for time-based queries, and PostgreSQL-specific types like arrays and JSONB receive advanced operator predicates. All generated scopes require explicit parameters (no default values), are thread-safe with immutable registries, compile at class load time for zero runtime overhead, and produce efficient SQL queries using Arel for database portability.

Predicable excels at building complex, maintainable filtering interfaces for APIs, admin panels, search features, and report generation. Instead of manually writing dozens of scopes or using string-based WHERE clauses prone to SQL injection, you declare which fields should be filterable and the system handles the rest. The generated predicates use clear, readable names that follow Rails conventions (`_cont` for contains, `_gteq` for greater than or equal), can be chained together for complex queries (`Article.status_eq("published").view_count_gt(100).published_at_within(30.days)`), adapt to your database engine (PostgreSQL-specific predicates only generate when using PostgreSQL), and integrate seamlessly with existing scopes, pagination, and ActiveRecord query methods. The feature also supports custom complex predicates via `register_complex_predicate` for encoding business-specific filtering logic that combines multiple fields or requires custom SQL. **Important**: All predicates require explicit parameter values - there are no default values or parameterless shortcuts.

## Basic Concepts

Predicable registration and automatic scope generation

Predicable uses the `predicates` class method to register one or more field names that should have filtering scopes generated. When you call `predicates :field1, :field2`, the system introspects each field's column type from the database schema and automatically generates an appropriate set of query scopes with required parameters. String columns receive pattern matching scopes like `_cont(substring)` and `_start(prefix)`, numeric columns get comparison scopes like `_gt(value)` and `_between(min, max)`, date/time columns include `_within(duration)` for relative time filtering, and PostgreSQL array/JSONB columns receive database-specific operator scopes. All generated scopes return ActiveRecord::Relation objects, can be chained with other scopes, and require explicit parameters with no defaults.

```ruby
# Basic predicates registration
class Article < ApplicationRecord
  include BetterModel

  # Register fields for automatic predicate generation
  # System introspects column types and generates appropriate scopes
  predicates :title, :status, :view_count, :published_at, :featured
end

# The predicates method signature
# predicates :field1, :field2, :field3, ...
#            ^column names as symbols (any number of fields)

# Generated scopes depend on column types (ALL require parameters):
# - title (string) → _eq(value), _cont(substring), _start(prefix), _in(values), etc.
# - status (string) → _eq(value), _not_eq(value), _in(values), _not_in(values), etc.
# - view_count (integer) → _eq(value), _lt(value), _gt(value), _between(min, max), etc.
# - published_at (datetime) → _eq(value), _lt(value), _within(duration), etc.
# - featured (boolean) → _eq(value), _not_eq(value), _present(bool), etc.
```

```ruby
# Example: Setting up a model with predicates
class Article < ApplicationRecord
  include BetterModel

  # Columns in database:
  # - title: string
  # - status: string
  # - view_count: integer
  # - published_at: datetime
  # - featured: boolean

  # Register all fields for filtering
  predicates :title, :status, :view_count, :published_at, :featured
end

# Usage: All generated scopes require explicit parameters and return ActiveRecord::Relation
# String predicates
Article.title_eq("Ruby on Rails")
# => SELECT * FROM articles WHERE title = 'Ruby on Rails'

Article.title_cont("Rails")
# => SELECT * FROM articles WHERE title LIKE '%Rails%'

Article.status_in(["draft", "published"])
# => SELECT * FROM articles WHERE status IN ('draft', 'published')

# Numeric predicates
Article.view_count_gt(100)
# => SELECT * FROM articles WHERE view_count > 100

Article.view_count_between(50, 200)
# => SELECT * FROM articles WHERE view_count BETWEEN 50 AND 200

# Boolean predicates (use _eq with explicit value)
Article.featured_eq(true)
# => SELECT * FROM articles WHERE featured = TRUE

Article.featured_eq(false)
# => SELECT * FROM articles WHERE featured = FALSE

# Date predicates
Article.published_at_within(7.days)
# => SELECT * FROM articles WHERE published_at >= '2025-10-29'

Article.published_at_gteq(Date.today)
# => SELECT * FROM articles WHERE published_at >= '2025-11-05'

# Chaining predicates (all return ActiveRecord::Relation)
Article
  .status_eq("published")
  .view_count_gt(100)
  .published_at_within(30.days)
  .featured_eq(true)
  .limit(10)
# => Complex query combining multiple filters
```

## Complete Predicates Reference

Comprehensive predicate catalog organized by category and database support

Predicable generates different predicates based on column types and the database engine in use. Universal predicates work across SQLite, MySQL, and PostgreSQL, while some advanced predicates are PostgreSQL-specific and only generate when using that database. **All predicates require explicit parameters** - there are no parameterless shortcuts. The following tables document all available predicates with their applicable field types, database support, and example usage showing required parameters.

### Legend

- ✅ Fully supported on this database
- ❌ Not supported
- 🟢 String fields (text, varchar, string)
- 🔢 Numeric fields (integer, decimal, float, bigint)
- 📅 Date/Time fields (date, datetime, timestamp, time)
- ☑️ Boolean fields
- 🗂️ Array columns (PostgreSQL only)
- 📦 JSONB columns (PostgreSQL only)

### Comparison Predicates

Universal equality and inequality comparisons supported across all databases

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required param) | Generated SQL |
|-----------|-------------|--------|-------|------------|--------------------------|---------------|
| `_eq(value)` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `title_eq("Ruby")` | `WHERE title = 'Ruby'` |
| `_not_eq(value)` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `status_not_eq("draft")` | `WHERE status != 'draft'` |
| `_lt(value)` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_lt(100)` | `WHERE view_count < 100` |
| `_lteq(value)` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_lteq(100)` | `WHERE view_count <= 100` |
| `_gt(value)` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_gt(100)` | `WHERE view_count > 100` |
| `_gteq(value)` | 🔢 📅 | ✅ | ✅ | ✅ | `published_at_gteq(Date.today)` | `WHERE published_at >= '2025-11-05'` |

```ruby
# Comparison predicate examples (all require parameters)
Article.view_count_eq(100)        # Exactly 100 views
Article.view_count_not_eq(0)      # Not zero views
Article.view_count_lt(50)         # Less than 50 views
Article.view_count_lteq(100)      # 100 or fewer views
Article.view_count_gt(1000)       # More than 1000 views
Article.view_count_gteq(500)      # 500 or more views

# Date comparisons
Article.published_at_gt(1.week.ago)       # Published in last week
Article.created_at_lteq(Date.today)       # Created today or earlier

# Boolean comparisons (use _eq with explicit true/false)
Article.featured_eq(true)         # Featured = true
Article.archived_eq(false)        # Archived = false
```

### Range Predicates

Efficient range queries using SQL BETWEEN operator

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required params) | Generated SQL |
|-----------|-------------|--------|-------|------------|---------------------------|---------------|
| `_between(min, max)` | 🔢 📅 | ✅ | ✅ | ✅ | `view_count_between(100, 500)` | `WHERE view_count BETWEEN 100 AND 500` |
| `_not_between(min, max)` | 🔢 📅 | ✅ | ✅ | ✅ | `published_at_not_between(date1, date2)` | `WHERE published_at NOT BETWEEN ...` |

```ruby
# Numeric ranges (both parameters required)
Article.view_count_between(100, 500)       # 100 to 500 views
Article.price_between(10.0, 50.0)          # Price range

# Date ranges
start_date = Date.new(2025, 1, 1)
end_date = Date.new(2025, 12, 31)
Article.published_at_between(start_date, end_date)  # Published in 2025

# Exclusion ranges
Article.view_count_not_between(0, 10)      # Not in low view range
```

### Pattern Matching Predicates

String pattern matching with SQL LIKE operator, includes case-insensitive variants

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required param) | Generated SQL |
|-----------|-------------|--------|-------|------------|--------------------------|---------------|
| `_matches(pattern)` | 🟢 | ✅ | ✅ | ✅ | `title_matches("%Ruby%")` | `WHERE title LIKE '%Ruby%'` |
| `_start(prefix)` | 🟢 | ✅ | ✅ | ✅ | `title_start("Ruby")` | `WHERE title LIKE 'Ruby%'` |
| `_end(suffix)` | 🟢 | ✅ | ✅ | ✅ | `title_end("Rails")` | `WHERE title LIKE '%Rails'` |
| `_cont(substring)` | 🟢 | ✅ | ✅ | ✅ | `title_cont("Rails")` | `WHERE title LIKE '%Rails%'` |
| `_not_cont(substring)` | 🟢 | ✅ | ✅ | ✅ | `title_not_cont("Draft")` | `WHERE title NOT LIKE '%Draft%'` |
| `_i_cont(substring)` | 🟢 | ✅ | ✅ | ✅ | `title_i_cont("rails")` | `WHERE LOWER(title) LIKE '%rails%'` |
| `_not_i_cont(substring)` | 🟢 | ✅ | ✅ | ✅ | `title_not_i_cont("draft")` | `WHERE LOWER(title) NOT LIKE '%draft%'` |

```ruby
# Case-sensitive pattern matching (all require parameter)
Article.title_matches("%Ruby%")        # Custom LIKE pattern
Article.title_start("Getting")         # Titles starting with "Getting"
Article.title_end("Tutorial")          # Titles ending with "Tutorial"
Article.title_cont("Rails")            # Titles containing "Rails"
Article.title_not_cont("Deprecated")   # Titles not containing "Deprecated"

# Case-insensitive search (user-facing search)
Article.title_i_cont("ruby")           # Find "Ruby", "RUBY", "ruby"
Article.title_i_cont("rails")          # Find any casing of "rails"
Article.title_not_i_cont("archived")   # Exclude archived (case-insensitive)

# Combining pattern predicates
Article
  .title_i_cont(params[:query])
  .status_eq("published")
# Search published articles (case-insensitive)
```

### Array Predicates

SQL IN and NOT IN operators for matching against value lists

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required param) | Generated SQL |
|-----------|-------------|--------|-------|------------|--------------------------|---------------|
| `_in(values)` | 🟢 🔢 📅 | ✅ | ✅ | ✅ | `status_in(["draft", "published"])` | `WHERE status IN ('draft', 'published')` |
| `_not_in(values)` | 🟢 🔢 📅 | ✅ | ✅ | ✅ | `status_not_in(["archived"])` | `WHERE status NOT IN ('archived')` |

```ruby
# Include multiple values (array parameter required)
Article.status_in(["draft", "published", "scheduled"])
Article.view_count_in([100, 200, 300, 400, 500])
Article.author_id_in([1, 2, 3])

# Exclude values
Article.status_not_in(["archived", "deleted"])
Article.priority_not_in(["low"])

# Dynamic filtering
statuses = params[:statuses] # ["draft", "published"]
Article.status_in(statuses) if statuses.present?
```

### Presence Predicates

NULL and empty value checking with explicit boolean parameter

**All presence predicates require an explicit boolean parameter** (no defaults). Pass `true` for the condition, `false` for its negation.

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required param) | Generated SQL |
|-----------|-------------|--------|-------|------------|--------------------------|---------------|
| `_present(bool)` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `title_present(true)` | `WHERE title IS NOT NULL AND title != ''` (string) |
| `_present(bool)` | 🟢 🔢 ☑️ 📅 | ✅ | ✅ | ✅ | `title_present(false)` | `WHERE title IS NULL OR title = ''` (string) |
| `_blank(bool)` | 🟢 📅 | ✅ | ✅ | ✅ | `title_blank(true)` | `WHERE title IS NULL OR title = ''` |
| `_blank(bool)` | 🟢 📅 | ✅ | ✅ | ✅ | `title_blank(false)` | `WHERE title IS NOT NULL AND title != ''` |
| `_null(bool)` | 🟢 📅 | ✅ | ✅ | ✅ | `published_at_null(true)` | `WHERE published_at IS NULL` |
| `_null(bool)` | 🟢 📅 | ✅ | ✅ | ✅ | `published_at_null(false)` | `WHERE published_at IS NOT NULL` |

```ruby
# Find records with values (boolean parameter REQUIRED)
Article.title_present(true)          # Has a title
Article.description_present(true)    # Has a description
Article.view_count_present(true)     # View count is not NULL

# Find records without values
Article.subtitle_blank(true)         # No subtitle (NULL or empty string)
Article.published_at_null(true)      # Not published (NULL)
Article.deleted_at_null(true)        # Not deleted

# Find records with non-NULL values (use negation)
Article.published_at_null(false)     # Published (has a date)
Article.updated_at_null(false)       # Has been updated

# Combining presence predicates
Article
  .title_present(true)
  .description_present(true)
  .published_at_null(false)
# Complete published articles

# Alternative: using _present for negation
Article.title_present(false)         # Equivalent to title_blank(true)
Article.description_present(false)   # No description
```

### Date Convenience Predicate

The `_within` predicate for relative time-based filtering

**Note**: The `_within` predicate is the only date convenience method. All other date filtering uses explicit comparison predicates (`_eq`, `_gt`, `_gteq`, `_between`, etc.). The `_within` predicate requires a duration parameter.

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required param) | Description |
|-----------|-------------|--------|-------|------------|--------------------------|-------------|
| `_within(duration)` | 📅 | ✅ | ✅ | ✅ | `created_at_within(7.days)` | Within duration from now |

```ruby
# Within duration (parameter required - no default)
Article.published_at_within(7.days)      # Last 7 days
Article.published_at_within(2.weeks)     # Last 2 weeks
Article.created_at_within(30.days)       # Last 30 days
Article.updated_at_within(1.hour)        # Last hour

# Within duration (numeric shorthand - interpreted as days)
Article.published_at_within(7)           # Last 7 days
Article.created_at_within(30)            # Last 30 days

# For other date convenience, use explicit comparisons
Article.published_at_gteq(Date.today.beginning_of_day)  # Today
Article.published_at_gteq(1.day.ago.beginning_of_day)   # Yesterday
Article.published_at_gteq(Date.today.beginning_of_week) # This week
Article.published_at_gteq(Date.today.beginning_of_month) # This month
Article.published_at_lt(Time.current)                   # Past
Article.published_at_gt(Time.current)                   # Future
```

### PostgreSQL Array Predicates

Advanced array operators available only when using PostgreSQL with array columns

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required param) | Generated SQL |
|-----------|-------------|--------|-------|------------|--------------------------|---------------|
| `_overlaps(array)` | 🗂️ | ❌ | ❌ | ✅ | `tags_overlaps(['ruby', 'rails'])` | `WHERE tags && ARRAY['ruby','rails']` |
| `_contains(value)` | 🗂️ | ❌ | ❌ | ✅ | `tags_contains('ruby')` | `WHERE tags @> ARRAY['ruby']` |
| `_contained_by(array)` | 🗂️ | ❌ | ❌ | ✅ | `tags_contained_by(['ruby', 'rails'])` | `WHERE tags <@ ARRAY['ruby','rails']` |

```ruby
# PostgreSQL array operations (automatically available with array columns)
# Migration example:
# add_column :articles, :tags, :string, array: true, default: []
# add_index :articles, :tags, using: 'gin'

# Overlaps: Find articles with ANY of the specified tags (parameter required)
Article.tags_overlaps(['ruby', 'rails'])
# => Articles tagged with ruby OR rails OR both

Article.tags_overlaps(['python', 'javascript', 'go'])
# => Articles tagged with any of these languages

# Contains: Find articles that have ALL specified tags (parameter required)
Article.tags_contains('ruby')
# => Articles that include 'ruby' tag

Article.tags_contains(['ruby', 'rails'])
# => Articles tagged with BOTH ruby AND rails

# Contained by: Find articles whose tags are a subset (parameter required)
Article.tags_contained_by(['ruby', 'rails', 'python', 'javascript'])
# => Articles whose tags are ALL within this list

# Combining array predicates
Article
  .tags_overlaps(['ruby', 'rails'])
  .status_eq("published")
  .view_count_gt(100)
# Published Ruby/Rails articles with good engagement
```

### PostgreSQL JSONB Predicates

Advanced JSONB operators for querying structured data in JSONB columns

| Predicate | Field Types | SQLite | MySQL | PostgreSQL | Example (required param) | Generated SQL |
|-----------|-------------|--------|-------|------------|--------------------------|---------------|
| `_has_key(key)` | 📦 | ❌ | ❌ | ✅ | `metadata_has_key('email')` | `WHERE metadata ? 'email'` |
| `_has_any_key(keys)` | 📦 | ❌ | ❌ | ✅ | `metadata_has_any_key(['email', 'phone'])` | `WHERE metadata ?| ARRAY['email','phone']` |
| `_has_all_keys(keys)` | 📦 | ❌ | ❌ | ✅ | `metadata_has_all_keys(['email', 'phone'])` | `WHERE metadata ?& ARRAY['email','phone']` |
| `_jsonb_contains(hash)` | 📦 | ❌ | ❌ | ✅ | `settings_jsonb_contains({active: true})` | `WHERE settings @> '{"active":true}'` |

```ruby
# PostgreSQL JSONB operations (automatically available with jsonb columns)
# Migration example:
# add_column :users, :settings, :jsonb, default: {}
# add_index :users, :settings, using: 'gin'

# Has key: Check if JSONB has a specific key (parameter required)
User.settings_has_key('email_notifications')
# => Users with email_notifications setting defined

User.metadata_has_key('premium_until')
# => Users with premium metadata

# Has any key: Check if JSONB has ANY of the specified keys (array parameter required)
User.settings_has_any_key(['email', 'phone', 'sms'])
# => Users with at least one contact preference

# Has all keys: Check if JSONB has ALL specified keys (array parameter required)
User.settings_has_all_keys(['email', 'phone'])
# => Users with both email AND phone settings

# JSONB contains: Check if JSONB contains specific key-value pairs (hash parameter required)
User.settings_jsonb_contains({active: true})
# => Users with active: true in settings

User.settings_jsonb_contains({theme: 'dark', notifications: true})
# => Users with BOTH dark theme AND notifications enabled

User.metadata_jsonb_contains({premium: true, verified: true})
# => Premium verified users

# Combining JSONB predicates
User
  .settings_has_key('email_notifications')
  .settings_jsonb_contains({active: true})
  .created_at_within(30.days)
# Active users with email notifications (last 30 days)
```

## Predicate Generation by Field Type

Understanding which predicates are generated for each column type

Predicable introspects your database schema and generates different predicate sets based on column types. **All predicates require explicit parameters**. The following table summarizes predicate generation:

| Column Type | Example Fields | Generated Predicates | Count |
|-------------|----------------|----------------------|-------|
| **String** (varchar, text, string) | `title`, `status`, `email` | `_eq(v)`, `_not_eq(v)`, `_in(arr)`, `_not_in(arr)`, `_matches(p)`, `_start(p)`, `_end(s)`, `_cont(s)`, `_not_cont(s)`, `_i_cont(s)`, `_not_i_cont(s)`, `_present(bool)`, `_blank(bool)`, `_null(bool)` | **14 scopes** |
| **Numeric** (integer, decimal, float, bigint) | `view_count`, `price`, `quantity` | `_eq(v)`, `_not_eq(v)`, `_lt(v)`, `_lteq(v)`, `_gt(v)`, `_gteq(v)`, `_between(min,max)`, `_not_between(min,max)`, `_in(arr)`, `_not_in(arr)`, `_present(bool)` | **11 scopes** |
| **Boolean** | `featured`, `active`, `archived` | `_eq(bool)`, `_not_eq(bool)`, `_present(bool)` | **3 scopes** |
| **Date/Time** (date, datetime, timestamp, time) | `published_at`, `created_at`, `due_date` | `_eq(v)`, `_not_eq(v)`, `_lt(v)`, `_lteq(v)`, `_gt(v)`, `_gteq(v)`, `_between(min,max)`, `_not_between(min,max)`, `_in(arr)`, `_not_in(arr)`, `_within(dur)`, `_blank(bool)`, `_null(bool)` | **13 scopes** |
| **Array** (PostgreSQL only) | `tags`, `categories`, `permissions` | `_in(arr)`, `_not_in(arr)`, `_overlaps(arr)`, `_contains(v)`, `_contained_by(arr)`, `_present(bool)`, `_null(bool)` | **7 scopes** |
| **JSONB** (PostgreSQL only) | `settings`, `metadata`, `preferences` | `_has_key(k)`, `_has_any_key(arr)`, `_has_all_keys(arr)`, `_jsonb_contains(h)`, `_present(bool)`, `_null(bool)` | **6 scopes** |

```ruby
# Example model demonstrating different column types
class Article < ApplicationRecord
  include BetterModel

  # String fields → 14 predicates each (all require parameters)
  predicates :title, :status, :author_name

  # Numeric fields → 11 predicates each (all require parameters)
  predicates :view_count, :likes_count, :price

  # Boolean fields → 3 predicates each (all require parameters)
  predicates :featured, :published, :archived

  # Date fields → 13 predicates each (all require parameters)
  predicates :published_at, :created_at, :updated_at

  # PostgreSQL array fields → 7 predicates each (if using PostgreSQL, all require parameters)
  predicates :tags, :categories

  # PostgreSQL JSONB fields → 6 predicates each (if using PostgreSQL, all require parameters)
  predicates :settings, :metadata
end

# Total generated scopes for this model:
# - Strings (3 fields × 14) = 42 scopes
# - Numeric (3 fields × 11) = 33 scopes
# - Boolean (3 fields × 3) = 9 scopes
# - Date (3 fields × 13) = 39 scopes
# - Array (2 fields × 7) = 14 scopes (PostgreSQL only)
# - JSONB (2 fields × 6) = 12 scopes (PostgreSQL only)
# Total: 149 scopes (123 universal + 26 PostgreSQL-specific)
```

## Custom Complex Predicates

Registering business-specific filtering logic with `register_complex_predicate`

For filtering logic that doesn't fit standard predicates or requires combining multiple fields with custom SQL, use `register_complex_predicate` to define named scopes that can accept parameters and be chained with other predicates. Complex predicates are defined with a block that receives parameters and returns an ActiveRecord::Relation, allowing you to use `where`, `joins`, `group`, and other query methods.

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :view_count, :published_at, :status

  # Register a complex predicate for popular recent articles
  register_complex_predicate :recent_popular do |days = 7, min_views = 100|
    where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
  end

  # Register a trending predicate
  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 1000, 24.hours.ago)
  end

  # Register a predicate with JOIN logic
  register_complex_predicate :with_active_author do
    joins(:author).where(authors: {active: true})
  end

  # Register a predicate with aggregation
  register_complex_predicate :with_many_comments do |min_comments = 10|
    joins(:comments)
      .group("articles.id")
      .having("COUNT(comments.id) >= ?", min_comments)
  end
end

# Usage: Complex predicates work like regular scopes
Article.recent_popular              # Default parameters (7 days, 100 views)
Article.recent_popular(14, 500)     # Custom parameters (14 days, 500 views)
Article.trending                    # No parameters

# Chaining complex predicates with generated predicates
Article
  .recent_popular(7, 100)
  .status_eq("published")
  .featured_eq(true)
  .limit(10)

Article
  .trending
  .with_active_author
  .order(published_at: :desc)

# Combining multiple complex predicates
Article
  .recent_popular
  .with_many_comments(5)
  .featured_eq(true)
```

```ruby
# Real-world examples of complex predicates

class Product < ApplicationRecord
  include BetterModel

  predicates :name, :price, :stock, :category

  # In stock with positive quantity
  register_complex_predicate :in_stock do
    where("stock > 0")
  end

  # On sale (has sale_price lower than regular price)
  register_complex_predicate :on_sale do
    where("sale_price IS NOT NULL AND sale_price < price")
  end

  # Low stock alert (below threshold)
  register_complex_predicate :low_stock do |threshold = 10|
    where("stock > 0 AND stock <= ?", threshold)
  end

  # Price range with currency conversion
  register_complex_predicate :price_range_usd do |min, max, exchange_rate = 1.0|
    where("price * ? BETWEEN ? AND ?", exchange_rate, min, max)
  end
end

class Event < ApplicationRecord
  include BetterModel

  predicates :title, :start_date, :capacity, :registered_count

  # Upcoming events with available seats
  register_complex_predicate :available_upcoming do
    where("start_date > ? AND registered_count < capacity", Time.current)
  end

  # Selling fast (90% capacity)
  register_complex_predicate :selling_fast do
    where("registered_count >= capacity * 0.9")
  end

  # Within time range
  register_complex_predicate :within_dates do |start_date, end_date|
    where(start_date: start_date..end_date)
  end
end

class User < ApplicationRecord
  include BetterModel

  predicates :email, :created_at, :last_login_at

  # Active users (logged in recently)
  register_complex_predicate :active_users do |days = 30|
    where("last_login_at >= ?", days.days.ago)
  end

  # Inactive users needing re-engagement
  register_complex_predicate :dormant_users do |days = 90|
    where("last_login_at < ? OR last_login_at IS NULL", days.days.ago)
  end

  # Premium users with specific subscription
  register_complex_predicate :premium_tier do |tier = "premium"|
    joins(:subscription)
      .where(subscriptions: {tier: tier, active: true})
  end
end
```

### Advanced Complex Predicate Patterns

```ruby
# Pattern 1: Multi-step filtering with progressive narrowing
class Report < ApplicationRecord
  include BetterModel

  predicates :title, :status, :created_at, :views, :downloads

  register_complex_predicate :high_engagement do |min_views = 1000, min_downloads = 100|
    where("views >= ? AND downloads >= ?", min_views, min_downloads)
  end

  register_complex_predicate :recent_high_engagement do |days = 30, min_views = 1000, min_downloads = 100|
    where("created_at >= ?", days.days.ago)
      .where("views >= ? AND downloads >= ?", min_views, min_downloads)
  end

  register_complex_predicate :viral_content do
    where("(downloads::float / NULLIF(views, 0)) >= 0.1")  # 10%+ conversion
      .where("views >= 500")
  end
end

# Pattern 2: Association-based complex queries
class Article < ApplicationRecord
  include BetterModel
  belongs_to :author
  has_many :comments

  predicates :title, :status, :published_at

  register_complex_predicate :by_prolific_author do |min_articles = 20|
    joins(:author)
      .group("articles.id, authors.id")
      .having("(SELECT COUNT(*) FROM articles a2 WHERE a2.author_id = authors.id) >= ?", min_articles)
  end

  register_complex_predicate :highly_discussed do |min_comments = 10|
    joins(:comments)
      .group("articles.id")
      .having("COUNT(DISTINCT comments.id) >= ?", min_comments)
  end

  register_complex_predicate :controversial do
    joins(:comments)
      .group("articles.id")
      .having("COUNT(DISTINCT comments.id) >= 50")
      .where("articles.view_count < 1000")  # Lots of comments, few views
  end
end

# Pattern 3: Date range conveniences
class Campaign < ApplicationRecord
  include BetterModel

  predicates :name, :starts_at, :ends_at, :budget, :status

  register_complex_predicate :active_now do
    where("starts_at <= ? AND ends_at >= ?", Time.current, Time.current)
  end

  register_complex_predicate :starting_soon do |hours = 24|
    future_time = hours.hours.from_now
    where("starts_at > ? AND starts_at <= ?", Time.current, future_time)
  end

  register_complex_predicate :ending_soon do |hours = 24|
    future_time = hours.hours.from_now
    where("ends_at > ? AND ends_at <= ?", Time.current, future_time)
      .where("starts_at <= ?", Time.current)  # Must be active
  end

  register_complex_predicate :in_date_range do |start_date, end_date|
    where("starts_at >= ? AND ends_at <= ?", start_date, end_date)
  end
end

# Pattern 4: Business rule encapsulation
class Subscription < ApplicationRecord
  include BetterModel

  predicates :tier, :status, :created_at, :expires_at

  register_complex_predicate :needs_renewal do |days_before_expiry = 7|
    expiry_threshold = days_before_expiry.days.from_now
    where("status = 'active'")
      .where("expires_at IS NOT NULL")
      .where("expires_at <= ?", expiry_threshold)
      .where("expires_at > ?", Time.current)
  end

  register_complex_predicate :expired_recently do |days = 30|
    where("status = 'expired'")
      .where("expires_at >= ?", days.days.ago)
  end

  register_complex_predicate :eligible_for_upgrade do
    where("tier IN ('free', 'basic')")
      .where("status = 'active'")
      .where("created_at < ?", 30.days.ago)  # Account age requirement
  end

  register_complex_predicate :at_risk_churn do
    joins(:usage_stats)
      .where("usage_stats.last_activity < ?", 14.days.ago)
      .where("subscriptions.status = 'active'")
      .where("subscriptions.tier IN ('premium', 'pro')")
  end
end
```

### Parameter Validation in Complex Predicates

```ruby
# GOOD: Validate parameters to prevent errors
class Product < ApplicationRecord
  include BetterModel

  predicates :name, :price, :stock

  register_complex_predicate :price_range do |min, max|
    raise ArgumentError, "min must be positive" if min.to_f < 0
    raise ArgumentError, "max must be positive" if max.to_f < 0
    raise ArgumentError, "min must be less than max" if min.to_f >= max.to_f

    where("price >= ? AND price <= ?", min, max)
  end

  register_complex_predicate :recent_sales do |days|
    raise ArgumentError, "days must be positive" if days.to_i <= 0
    raise ArgumentError, "days must be reasonable (max 365)" if days.to_i > 365

    joins(:order_items)
      .where("order_items.created_at >= ?", days.days.ago)
      .distinct
  end

  register_complex_predicate :low_stock_alert do |threshold = 10|
    raise ArgumentError, "threshold must be positive" if threshold.to_i <= 0

    where("stock > 0 AND stock <= ?", threshold)
  end
end

# Usage with validation
Product.price_range(10, 100)     # ✅ Valid
Product.price_range(-5, 100)     # ❌ Raises ArgumentError: "min must be positive"
Product.price_range(100, 10)     # ❌ Raises ArgumentError: "min must be less than max"
Product.recent_sales(7)          # ✅ Valid
Product.recent_sales(-1)         # ❌ Raises ArgumentError: "days must be positive"
```

### SQL Injection Prevention

```ruby
# DANGEROUS: Never use string interpolation with user input
class Article < ApplicationRecord
  include BetterModel

  # ❌ VULNERABLE TO SQL INJECTION
  register_complex_predicate :search_bad do |term|
    where("title LIKE '%#{term}%'")  # NEVER DO THIS!
  end
end

# SAFE: Always use parameter binding
class Article < ApplicationRecord
  include BetterModel

  # ✅ SAFE: Uses parameter binding
  register_complex_predicate :search_safe do |term|
    sanitized = ActiveRecord::Base.sanitize_sql_like(term)
    where("title LIKE ?", "%#{sanitized}%")
  end

  # ✅ SAFE: Uses Arel (best practice)
  register_complex_predicate :search_arel do |term|
    sanitized = ActiveRecord::Base.sanitize_sql_like(term)
    where(arel_table[:title].matches("%#{sanitized}%"))
  end

  # ✅ SAFE: Multiple parameters with binding
  register_complex_predicate :search_multi do |term1, term2|
    sanitized1 = ActiveRecord::Base.sanitize_sql_like(term1)
    sanitized2 = ActiveRecord::Base.sanitize_sql_like(term2)
    where("title LIKE ? OR content LIKE ?", "%#{sanitized1}%", "%#{sanitized2}%")
  end

  # ✅ SAFE: Array parameters with proper quoting
  register_complex_predicate :in_categories do |categories|
    # ActiveRecord handles array sanitization
    where(category: categories)
  end
end

# Security examples
Article.search_safe("Ruby' OR '1'='1")  # ✅ Sanitized, no SQL injection
Article.search_arel("'; DROP TABLE articles; --")  # ✅ Safe with Arel
```

### Integration with Searchable

```ruby
# Complex predicates can be used in Searchable security policies
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :published_at, :view_count

  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
  end

  register_complex_predicate :safe_for_public do
    where(status: "published")
      .where("published_at <= ?", Time.current)
      .where("archived_at IS NULL")
  end

  searchable do
    default_order [:published_at_desc]
    per_page 25
    max_per_page 100

    # Use complex predicates in security policies
    security :public_only, [:safe_for_public]
    security :status_required, [:status_eq]
  end
end

# Usage in controller
class ArticlesController < ApplicationController
  def public_index
    # Searchable automatically applies safe_for_public
    @articles = Article.search(
      params.permit(:title_cont, :view_count_gteq),
      securities: [:public_only]
    )

    render json: @articles
  end

  def trending
    # Combine complex predicate with search
    @articles = Article.trending
                       .search(params.permit(:title_cont))
                       .page(params[:page])

    render json: @articles
  end
end
```

### Debugging and Introspection

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count

  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
  end
end

# Check if complex predicate is registered
Article.complex_predicate?(:trending)        # => true
Article.complex_predicate?(:nonexistent)     # => false

# Get all complex predicates
Article.complex_predicates_registry
# => { trending: #<Proc:0x00007f8b...> }

# Get the proc for a complex predicate
trending_proc = Article.complex_predicates_registry[:trending]
trending_proc.class                          # => Proc
trending_proc.arity                          # => 0 (no required params)

# Inspect generated SQL
relation = Article.trending
relation.to_sql
# => "SELECT \"articles\".* FROM \"articles\" WHERE (view_count >= 500 AND published_at >= '2025-10-29')"

# Debug complex predicate chain
relation = Article.trending
                  .status_eq("published")
                  .title_cont("Ruby")
puts relation.to_sql
# => Shows complete SQL with all conditions

# Check execution plan (PostgreSQL)
relation = Article.trending.status_eq("published")
puts relation.explain
# => Shows query execution plan

# Count without loading
Article.trending.count                      # => 42 (no records loaded)
Article.trending.exists?                    # => true/false (efficient check)

# Inspect combined scopes
Article.predicable_scopes.grep(/trending/)   # => [:trending]
Article.predicable_scopes.size              # => Total number of scopes
```

### Testing Complex Predicates

```ruby
# test/models/article_test.rb
require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "trending predicate returns articles with high views" do
    # Create test data
    trending = Article.create!(title: "Hot Article", view_count: 1000, published_at: 3.days.ago)
    old = Article.create!(title: "Old Article", view_count: 1000, published_at: 10.days.ago)
    low_views = Article.create!(title: "Unpopular", view_count: 10, published_at: 3.days.ago)

    results = Article.trending

    assert_includes results, trending
    refute_includes results, old
    refute_includes results, low_views
  end

  test "trending predicate accepts custom parameters" do
    article = Article.create!(view_count: 200, published_at: 5.days.ago)

    # Default parameters (500 views, 7 days)
    refute Article.trending.exists?(id: article.id)

    # Custom parameters (100 views, 7 days)
    assert Article.trending(100).exists?(id: article.id)
  end

  test "complex predicate is chainable" do
    article = Article.create!(
      view_count: 1000,
      published_at: 3.days.ago,
      status: "published",
      title: "Ruby Tutorial"
    )

    results = Article.trending
                     .status_eq("published")
                     .title_cont("Ruby")

    assert_includes results, article
    assert_kind_of ActiveRecord::Relation, results
  end

  test "complex predicate returns ActiveRecord::Relation" do
    relation = Article.trending

    assert_kind_of ActiveRecord::Relation, relation
    assert_respond_to relation, :where
    assert_respond_to relation, :order
    assert_respond_to relation, :limit
  end

  test "complex_predicate? returns true for registered predicates" do
    assert Article.complex_predicate?(:trending)
    refute Article.complex_predicate?(:nonexistent)
  end

  test "complex predicates are registered in registry" do
    assert Article.complex_predicates_registry.key?(:trending)
    assert_kind_of Proc, Article.complex_predicates_registry[:trending]
  end
end
```

## Class Methods

Introspection methods for predicable fields, scopes, and complex predicates

Predicable provides class-level methods for runtime introspection of registered fields, generated scopes, and complex predicates. These methods are useful for building dynamic UIs, validating filter parameters, debugging, or metaprogramming.

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at, :featured

  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
  end
end

# Check if a field has predicates registered
Article.predicable_field?(:title)           # => true
Article.predicable_field?(:nonexistent)     # => false

# Check if a specific scope exists
Article.predicable_scope?(:title_cont)      # => true
Article.predicable_scope?(:title_foo)       # => false

# Check if a complex predicate is registered
Article.complex_predicate?(:trending)       # => true
Article.complex_predicate?(:unknown)        # => false

# Get all predicable fields (returns frozen Set)
Article.predicable_fields
# => #<Set: {:title, :status, :view_count, :published_at, :featured}>

# Get all generated predicate scopes (returns frozen Set)
Article.predicable_scopes
# => #<Set: {:title_eq, :title_not_eq, :title_cont, :title_i_cont,
#     :status_eq, :status_in, :view_count_gt, :view_count_between,
#     :published_at_within, :featured_eq, ...}>

# Get all complex predicates (returns frozen Hash)
Article.complex_predicates_registry
# => {:trending => #<Proc:0x00007f8b1c8a4c20@...>}

# Count generated scopes
Article.predicable_scopes.size              # => 54 (example)
```

```ruby
# Practical usage: Dynamic filter validation

class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Validate and apply filters from parameters
    params[:filters]&.each do |field, predicate, value|
      scope_name = "#{field}_#{predicate}".to_sym

      if Article.predicable_scope?(scope_name)
        @articles = @articles.public_send(scope_name, value)
      else
        # Invalid filter, log or show error
        Rails.logger.warn "Invalid filter: #{scope_name}"
      end
    end

    render json: @articles
  end
end

# Practical usage: Building filter UI

class FilterBuilder
  def self.available_filters(model_class)
    filters = {}

    model_class.predicable_fields.each do |field|
      column = model_class.columns_hash[field.to_s]
      next unless column

      filters[field] = {
        type: column.type,
        predicates: available_predicates_for_type(column.type)
      }
    end

    filters
  end

  def self.available_predicates_for_type(column_type)
    case column_type
    when :string
      [:eq, :not_eq, :cont, :i_cont, :start, :end, :in, :not_in, :present, :blank, :null]
    when :integer, :decimal, :float
      [:eq, :not_eq, :lt, :lteq, :gt, :gteq, :between, :in, :present]
    when :datetime, :date
      [:eq, :lt, :gt, :between, :within, :blank, :null]
    when :boolean
      [:eq, :not_eq, :present]
    else
      [:eq, :not_eq]
    end
  end
end

# Get available filters for UI
FilterBuilder.available_filters(Article)
# => {
#      title: { type: :string, predicates: [:eq, :cont, :i_cont, ...] },
#      view_count: { type: :integer, predicates: [:eq, :lt, :gt, ...] },
#      published_at: { type: :datetime, predicates: [:eq, :within, ...] },
#      ...
#    }
```

## Usage Examples and Query Patterns

Common filtering patterns and query combinations showing required parameters

The following examples demonstrate typical usage patterns for Predicable in various application scenarios, showing how to combine multiple predicates, chain with other scopes, and build complex queries. **Remember: all predicates require explicit parameters**.

### Basic Filtering Patterns

```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :status, :view_count, :published_at, :featured
end

# String filtering (all require parameters)
Article.title_eq("Ruby on Rails Guide")           # Exact match
Article.title_cont("Rails")                       # Contains "Rails"
Article.title_i_cont("rails")                     # Case-insensitive contains
Article.title_start("Getting Started")            # Starts with
Article.status_in(["draft", "published"])         # Multiple values

# Numeric filtering (all require parameters)
Article.view_count_gt(100)                        # More than 100 views
Article.view_count_between(50, 200)               # 50-200 views
Article.view_count_gteq(1000)                     # 1000+ views

# Boolean filtering (use _eq with explicit value)
Article.featured_eq(true)                         # Featured articles
Article.featured_eq(false)                        # Non-featured articles

# Date filtering (all require parameters)
Article.published_at_within(7.days)               # Last 7 days
Article.published_at_within(30)                   # Last 30 days (shorthand)
Article.published_at_gteq(1.week.ago)            # Manual date comparison
Article.published_at_gteq(Date.today.beginning_of_day)  # Today

# Presence checking (boolean parameter required)
Article.title_present(true)                       # Has a title
Article.published_at_null(false)                  # Is published (not NULL)
```

### Advanced Query Chaining

```ruby
# Multi-criteria filtering
Article
  .status_eq("published")
  .view_count_gt(100)
  .published_at_within(30.days)
  .featured_eq(true)
  .limit(10)
# => Top 10 featured published articles from last 30 days with 100+ views

# Search with filters
Article
  .title_i_cont(params[:query])
  .status_in(["published", "featured"])
  .view_count_gteq(50)
  .published_at_within(60.days)
  .order(view_count: :desc)
# => Search results filtered and sorted

# Complex date filtering
Article
  .published_at_lt(Time.current)
  .view_count_between(100, 1000)
  .status_not_in(["archived", "deleted"])
  .order(published_at: :desc)
# => Past published articles with moderate engagement

# Combining with ActiveRecord methods
Article
  .title_cont("Ruby")
  .published_at_within(30.days)
  .where.not(author_id: nil)
  .includes(:author, :comments)
  .limit(20)
# => Recent Ruby articles with authors loaded
```

### Pagination and Ordering

```ruby
# With Kaminari or will_paginate
@articles = Article
  .status_eq("published")
  .published_at_within(30.days)
  .view_count_gt(50)
  .page(params[:page])
  .per(20)

# With ordering
@articles = Article
  .status_eq("published")
  .featured_eq(true)
  .order(published_at: :desc)
  .limit(10)

# With Sortable (BetterModel feature)
@articles = Article
  .status_eq("published")
  .published_at_within(7.days)
  .sort_view_count_desc         # Using Sortable
  .limit(20)
```

## Real-World Examples

Production-ready implementations for common use cases with explicit parameters

### Blog Platform with Advanced Filtering

```ruby
class Post < ApplicationRecord
  include BetterModel

  predicates :title, :content, :status, :view_count, :published_at, :author_id, :tags, :featured

  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
  end

  register_complex_predicate :popular do |days = 30, min_views = 1000|
    where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
  end
end

# Controller: Advanced search and filtering
class PostsController < ApplicationController
  def index
    @posts = Post.all

    # Text search (parameter required)
    @posts = @posts.title_i_cont(params[:q]) if params[:q].present?

    # Status filter (parameter required)
    @posts = @posts.status_eq(params[:status]) if params[:status].present?

    # Author filter (parameter required)
    @posts = @posts.author_id_eq(params[:author_id]) if params[:author_id].present?

    # Date range filter (parameters required)
    if params[:date_range].present?
      case params[:date_range]
      when "today"
        @posts = @posts.published_at_gteq(Date.today.beginning_of_day)
      when "week"
        @posts = @posts.published_at_gteq(Date.today.beginning_of_week)
      when "month"
        @posts = @posts.published_at_gteq(Date.today.beginning_of_month)
      when "custom"
        if params[:start_date] && params[:end_date]
          @posts = @posts.published_at_between(params[:start_date], params[:end_date])
        end
      end
    end

    # View count filter (parameter required)
    if params[:min_views].present?
      @posts = @posts.view_count_gteq(params[:min_views])
    end

    # Feature flags (explicit boolean required)
    @posts = @posts.featured_eq(true) if params[:featured] == "true"

    # Sorting
    @posts = @posts.order(params[:sort] || {published_at: :desc})

    # Pagination
    @posts = @posts.page(params[:page]).per(20)

    render json: @posts
  end

  def trending
    @posts = Post
      .trending
      .status_eq("published")
      .limit(10)

    render json: @posts
  end

  def popular
    days = params[:days]&.to_i || 30
    min_views = params[:min_views]&.to_i || 1000

    @posts = Post
      .popular(days, min_views)
      .status_eq("published")
      .order(view_count: :desc)
      .limit(20)

    render json: @posts
  end
end
```

### E-commerce Product Catalog

```ruby
class Product < ApplicationRecord
  include BetterModel

  predicates :name, :description, :price, :stock, :category, :brand, :featured, :on_sale, :rating

  register_complex_predicate :in_stock do
    where("stock > 0")
  end

  register_complex_predicate :low_stock do |threshold = 10|
    where("stock > 0 AND stock <= ?", threshold)
  end

  register_complex_predicate :best_sellers do |days = 30, min_sales = 50|
    joins(:order_items)
      .where("order_items.created_at >= ?", days.days.ago)
      .group("products.id")
      .having("COUNT(order_items.id) >= ?", min_sales)
  end
end

# Controller: Product search and filtering
class ProductsController < ApplicationController
  def index
    @products = Product.all

    # Search (parameter required)
    @products = @products.name_i_cont(params[:q]) if params[:q].present?

    # Category filter (parameter required)
    @products = @products.category_eq(params[:category]) if params[:category].present?

    # Brand filter (parameter required)
    @products = @products.brand_in(params[:brands]) if params[:brands].present?

    # Price range (parameters required)
    if params[:min_price] || params[:max_price]
      min = params[:min_price]&.to_f || 0
      max = params[:max_price]&.to_f || Float::INFINITY
      @products = @products.price_between(min, max)
    end

    # Stock status (use complex predicate)
    @products = @products.in_stock if params[:in_stock] == "true"

    # Rating filter (parameter required)
    @products = @products.rating_gteq(params[:min_rating]) if params[:min_rating].present?

    # Feature flags (explicit boolean required)
    @products = @products.featured_eq(true) if params[:featured] == "true"
    @products = @products.on_sale_eq(true) if params[:on_sale] == "true"

    # Sorting
    sort_option = params[:sort] || "popularity"
    @products = case sort_option
    when "price_asc"
      @products.order(price: :asc)
    when "price_desc"
      @products.order(price: :desc)
    when "newest"
      @products.order(created_at: :desc)
    when "rating"
      @products.order(rating: :desc)
    else
      @products.order(sales_count: :desc)  # popularity
    end

    @products = @products.page(params[:page]).per(24)

    render json: @products
  end

  def best_sellers
    @products = Product
      .best_sellers(30, 50)
      .in_stock
      .limit(20)

    render json: @products
  end
end
```

### Event Management System

```ruby
class Event < ApplicationRecord
  include BetterModel

  predicates :title, :description, :start_date, :end_date, :status, :capacity, :registered_count, :category, :price, :location

  register_complex_predicate :upcoming do
    where("start_date > ?", Time.current)
  end

  register_complex_predicate :available do
    where("start_date > ? AND registered_count < capacity", Time.current)
  end

  register_complex_predicate :selling_fast do
    where("registered_count >= capacity * 0.9 AND start_date > ?", Time.current)
  end

  register_complex_predicate :this_weekend do
    start_of_weekend = Date.current.next_occurring(:saturday).beginning_of_day
    end_of_weekend = start_of_weekend + 2.days
    where(start_date: start_of_weekend..end_of_weekend)
  end
end

# Controller: Event browsing and filtering
class EventsController < ApplicationController
  def index
    @events = Event.all

    # Search (parameter required)
    @events = @events.title_i_cont(params[:q]) if params[:q].present?

    # Time filters (use complex predicates or explicit comparisons)
    case params[:time_filter]
    when "upcoming"
      @events = @events.upcoming
    when "today"
      @events = @events.start_date_gteq(Date.today.beginning_of_day)
    when "this_week"
      @events = @events.start_date_gteq(Date.today.beginning_of_week)
    when "this_month"
      @events = @events.start_date_gteq(Date.today.beginning_of_month)
    when "weekend"
      @events = @events.this_weekend
    end

    # Category filter (parameter required)
    @events = @events.category_in(params[:categories]) if params[:categories].present?

    # Location filter (parameter required)
    @events = @events.location_eq(params[:location]) if params[:location].present?

    # Price filter (parameters required)
    if params[:price_range].present?
      case params[:price_range]
      when "free"
        @events = @events.price_eq(0)
      when "paid"
        @events = @events.price_gt(0)
      when "custom"
        if params[:min_price] && params[:max_price]
          @events = @events.price_between(params[:min_price], params[:max_price])
        end
      end
    end

    # Availability (use complex predicate)
    @events = @events.available if params[:available_only] == "true"

    # Status (parameter required)
    @events = @events.status_eq(params[:status]) if params[:status].present?

    @events = @events.order(start_date: :asc).page(params[:page]).per(20)

    render json: @events
  end

  def featured
    @events = Event
      .upcoming
      .available
      .status_eq("confirmed")
      .order(registered_count: :desc)
      .limit(6)

    render json: @events
  end

  def selling_fast
    @events = Event
      .selling_fast
      .status_eq("confirmed")
      .order(start_date: :asc)
      .limit(10)

    render json: @events
  end
end
```

### User Management and Analytics

```ruby
class User < ApplicationRecord
  include BetterModel

  predicates :email, :name, :role, :created_at, :last_login_at, :status, :subscription_tier, :settings

  register_complex_predicate :active do |days = 30|
    where("last_login_at >= ?", days.days.ago)
  end

  register_complex_predicate :dormant do |days = 90|
    where("last_login_at < ? OR last_login_at IS NULL", days.days.ago)
  end

  register_complex_predicate :premium_active do
    where(subscription_tier: ["premium", "enterprise"])
      .where("subscription_expires_at > ?", Time.current)
  end
end

# Controller: Admin user management
class Admin::UsersController < ApplicationController
  def index
    @users = User.all

    # Search (parameters required)
    if params[:q].present?
      @users = @users.where("email LIKE ? OR name LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    end

    # Activity filters (use complex predicates)
    case params[:activity]
    when "active"
      @users = @users.active(30)
    when "dormant"
      @users = @users.dormant(90)
    when "new"
      @users = @users.created_at_within(7.days)
    end

    # Role filter (parameter required)
    @users = @users.role_in(params[:roles]) if params[:roles].present?

    # Status filter (parameter required)
    @users = @users.status_eq(params[:status]) if params[:status].present?

    # Subscription filter (use complex predicate or explicit comparison)
    case params[:subscription]
    when "premium"
      @users = @users.premium_active
    when "trial"
      @users = @users.subscription_tier_eq("trial")
    when "free"
      @users = @users.subscription_tier_eq("free")
    end

    # Date registered (parameter required)
    if params[:registered_after]
      @users = @users.created_at_gteq(params[:registered_after])
    end

    @users = @users.order(params[:sort] || {created_at: :desc})
    @users = @users.page(params[:page]).per(50)

    render json: @users
  end

  def analytics
    {
      total_users: User.count,
      active_users: User.active(30).count,
      dormant_users: User.dormant(90).count,
      new_users_this_week: User.created_at_gteq(Date.today.beginning_of_week).count,
      new_users_this_month: User.created_at_gteq(Date.today.beginning_of_month).count,
      premium_users: User.premium_active.count,
      users_by_role: User.group(:role).count,
      users_by_subscription: User.group(:subscription_tier).count
    }
  end
end
```

### Advanced E-commerce Search with Faceted Filtering

```ruby
class Product < ApplicationRecord
  include BetterModel

  # Declare searchable fields for Predicable scopes
  predicable :name, :description, :sku, :brand, :category, :subcategory
  predicable :price, :sale_price, :cost, :stock_quantity, :weight
  predicable :rating_average, :reviews_count, :sales_count
  predicable :is_featured, :is_new, :is_on_sale, :is_active, :is_available
  predicable :tags, type: :array if connection.adapter_name == "PostgreSQL"
  predicable :specifications, :metadata, type: :jsonb if connection.adapter_name == "PostgreSQL"
  predicable :created_at, :updated_at, :published_at, :discontinued_at

  # Complex scopes built with multiple predicates
  scope :featured_deals, -> {
    is_featured_eq(true)
      .is_on_sale_eq(true)
      .is_active_eq(true)
      .sale_price_present(true)
      .stock_quantity_gt(0)
  }

  scope :new_arrivals, -> {
    is_new_eq(true)
      .published_at_within(30.days)
      .is_active_eq(true)
  }

  scope :clearance_items, -> {
    sale_price_present(true)
      .price_gt_than(:sale_price) # Implicit comparison
      .stock_quantity_between(1, 10)
      .discontinued_at_present(true)
  }

  scope :highly_rated, -> {
    rating_average_gteq(4.0)
      .reviews_count_gteq(10)
  }

  scope :in_stock, -> {
    stock_quantity_gt(0)
      .is_available_eq(true)
  }

  scope :low_stock_alert, -> {
    stock_quantity_between(1, 5)
      .is_active_eq(true)
  }

  # PostgreSQL-specific scopes with JSONB and arrays
  if connection.adapter_name == "PostgreSQL"
    scope :with_features, ->(feature_list) {
      tags_overlaps(feature_list)
    }

    scope :with_spec_key, ->(key) {
      specifications_has_key(key)
    }

    scope :spec_contains, ->(spec_hash) {
      specifications_jsonb_contains(spec_hash)
    }
  end
end

# Advanced search controller with faceted filtering
class ProductSearchController < ApplicationController
  def index
    @products = Product.all

    # Apply all filters from parameters
    apply_text_filters
    apply_category_filters
    apply_price_filters
    apply_rating_filters
    apply_availability_filters
    apply_feature_filters
    apply_date_filters
    apply_attribute_filters

    # Collect facet counts for UI
    @facets = calculate_facets

    # Sort and paginate
    @products = apply_sorting(@products)
    @products = @products.page(params[:page]).per(params[:per_page] || 24)

    respond_to do |format|
      format.html
      format.json { render json: products_json }
    end
  end

  def advanced_search
    # Complex search combining multiple predicate types
    @products = Product.all

    # Text search across multiple fields
    if params[:query].present?
      query = params[:query]
      name_matches = Product.name_i_cont(query)
      desc_matches = Product.description_i_cont(query)
      sku_matches = Product.sku_i_cont(query)
      brand_matches = Product.brand_i_cont(query)

      # Combine using OR logic
      @products = @products.where(
        id: (name_matches + desc_matches + sku_matches + brand_matches).pluck(:id).uniq
      )
    end

    # Price range with discount consideration
    if params[:min_price].present? || params[:max_price].present?
      min_price = params[:min_price]&.to_f || 0
      max_price = params[:max_price]&.to_f || Float::INFINITY

      # Consider both regular price and sale price
      normal_priced = Product.is_on_sale_eq(false).price_between(min_price, max_price)
      sale_priced = Product.is_on_sale_eq(true).sale_price_between(min_price, max_price)

      @products = @products.where(
        id: (normal_priced + sale_priced).pluck(:id).uniq
      )
    end

    # Category hierarchy filtering
    if params[:category].present?
      @products = @products.category_eq(params[:category])

      if params[:subcategory].present?
        @products = @products.subcategory_eq(params[:subcategory])
      end
    end

    # Multi-select brand filter
    if params[:brands].present?
      @products = @products.brand_in(params[:brands])
    end

    # Rating filter with minimum review count
    if params[:min_rating].present?
      @products = @products
                    .rating_average_gteq(params[:min_rating].to_f)
                    .reviews_count_gteq(5) # Minimum reviews for credibility
    end

    # Stock availability
    case params[:availability]
    when "in_stock"
      @products = @products.stock_quantity_gt(0)
    when "low_stock"
      @products = @products.stock_quantity_between(1, 5)
    when "out_of_stock"
      @products = @products.stock_quantity_eq(0)
    end

    # Special filters
    @products = @products.is_featured_eq(true) if params[:featured] == "true"
    @products = @products.is_new_eq(true) if params[:new_arrivals] == "true"
    @products = @products.is_on_sale_eq(true) if params[:on_sale] == "true"

    # PostgreSQL-specific feature tags
    if Product.connection.adapter_name == "PostgreSQL" && params[:features].present?
      @products = @products.tags_overlaps(params[:features])
    end

    # Date filters
    if params[:published_after].present?
      @products = @products.published_at_gteq(Date.parse(params[:published_after]))
    end

    @products = apply_sorting(@products)
    @products = @products.page(params[:page]).per(params[:per_page] || 24)

    render :index
  end

  private

  def apply_text_filters
    if params[:query].present?
      @products = @products.name_i_cont(params[:query])
        .or(@products.description_i_cont(params[:query]))
    end

    @products = @products.sku_eq(params[:sku]) if params[:sku].present?
    @products = @products.brand_eq(params[:brand]) if params[:brand].present?
  end

  def apply_category_filters
    @products = @products.category_eq(params[:category]) if params[:category].present?
    @products = @products.subcategory_in(params[:subcategories]) if params[:subcategories].present?
  end

  def apply_price_filters
    if params[:min_price].present?
      @products = @products.price_gteq(params[:min_price].to_f)
    end

    if params[:max_price].present?
      @products = @products.price_lteq(params[:max_price].to_f)
    end

    if params[:price_range].present?
      ranges = {
        "under_25" => [0, 25],
        "25_to_50" => [25, 50],
        "50_to_100" => [50, 100],
        "100_to_200" => [100, 200],
        "over_200" => [200, Float::INFINITY]
      }

      if range = ranges[params[:price_range]]
        @products = @products.price_between(range[0], range[1])
      end
    end
  end

  def apply_rating_filters
    if params[:min_rating].present?
      @products = @products.rating_average_gteq(params[:min_rating].to_f)
    end

    if params[:min_reviews].present?
      @products = @products.reviews_count_gteq(params[:min_reviews].to_i)
    end
  end

  def apply_availability_filters
    @products = @products.is_active_eq(true) # Always filter to active products

    if params[:in_stock] == "true"
      @products = @products.stock_quantity_gt(0)
    end

    if params[:available_only] == "true"
      @products = @products.is_available_eq(true)
    end
  end

  def apply_feature_filters
    @products = @products.is_featured_eq(true) if params[:featured] == "true"
    @products = @products.is_new_eq(true) if params[:new] == "true"
    @products = @products.is_on_sale_eq(true) if params[:on_sale] == "true"
  end

  def apply_date_filters
    if params[:published_after].present?
      date = Date.parse(params[:published_after]) rescue nil
      @products = @products.published_at_gteq(date) if date
    end

    if params[:published_within_days].present?
      days = params[:published_within_days].to_i
      @products = @products.published_at_within(days.days) if days > 0
    end
  end

  def apply_attribute_filters
    # Weight range for shipping calculations
    if params[:max_weight].present?
      @products = @products.weight_lteq(params[:max_weight].to_f)
    end

    # Sales performance
    if params[:min_sales].present?
      @products = @products.sales_count_gteq(params[:min_sales].to_i)
    end
  end

  def apply_sorting(scope)
    case params[:sort]
    when "price_asc"
      scope.order(price: :asc)
    when "price_desc"
      scope.order(price: :desc)
    when "rating"
      scope.order(rating_average: :desc, reviews_count: :desc)
    when "popularity"
      scope.order(sales_count: :desc)
    when "newest"
      scope.order(published_at: :desc)
    when "name"
      scope.order(name: :asc)
    else
      scope.order(created_at: :desc)
    end
  end

  def calculate_facets
    # Get facet counts based on current filters (excluding the facet being counted)
    base_products = @products.unscope(:limit, :offset)

    {
      categories: base_products.group(:category).count,
      brands: base_products.group(:brand).count,
      price_ranges: {
        under_25: base_products.price_lt(25).count,
        "25_to_50": base_products.price_between(25, 50).count,
        "50_to_100": base_products.price_between(50, 100).count,
        "100_to_200": base_products.price_between(100, 200).count,
        over_200: base_products.price_gt(200).count
      },
      ratings: {
        "4_plus": base_products.rating_average_gteq(4.0).count,
        "3_plus": base_products.rating_average_gteq(3.0).count,
        "2_plus": base_products.rating_average_gteq(2.0).count
      },
      availability: {
        in_stock: base_products.stock_quantity_gt(0).count,
        on_sale: base_products.is_on_sale_eq(true).count,
        featured: base_products.is_featured_eq(true).count,
        new: base_products.is_new_eq(true).count
      }
    }
  end

  def products_json
    {
      products: @products.map { |product|
        {
          id: product.id,
          name: product.name,
          price: product.price,
          sale_price: product.sale_price,
          rating: product.rating_average,
          reviews_count: product.reviews_count,
          in_stock: product.stock_quantity > 0,
          is_new: product.is_new,
          is_featured: product.is_featured,
          is_on_sale: product.is_on_sale
        }
      },
      facets: @facets,
      pagination: {
        current_page: @products.current_page,
        total_pages: @products.total_pages,
        total_count: @products.total_count
      }
    }
  end
end
```

## Edge Cases and Advanced Usage

Advanced Predicable patterns for complex scenarios

This section explores sophisticated Predicable patterns including deep JSONB queries with performance optimization, handling NULL values in range queries, combining predicates with custom SQL, and optimizing predicate chains for large datasets.

### Deep JSONB Queries with Performance Optimization

```ruby
class Campaign < ApplicationRecord
  include BetterModel

  # PostgreSQL JSONB fields
  predicable :settings, type: :jsonb
  predicable :targeting_rules, type: :jsonb
  predicable :performance_metrics, type: :jsonb
  predicable :audience_data, type: :jsonb

  # Standard fields
  predicable :name, :status, :campaign_type
  predicable :budget, :spent, :impressions, :clicks, :conversions
  predicable :start_date, :end_date, :created_at

  # Efficient JSONB queries with proper indexing
  # Requires: add_index :campaigns, :settings, using: :gin
  # Requires: add_index :campaigns, :targeting_rules, using: :gin
  # Requires: add_index :campaigns, "(settings -> 'enabled')", using: :btree

  # Complex JSONB filtering with performance considerations
  scope :with_budget_threshold, ->(threshold) {
    settings_jsonb_contains({"budget_settings" => {"auto_adjust" => true}})
      .where("(settings->>'budget_threshold')::decimal >= ?", threshold)
  }

  scope :targeting_age_range, ->(min_age, max_age) {
    where(
      "targeting_rules->>'min_age' IS NOT NULL AND " \
      "(targeting_rules->>'min_age')::int <= ? AND " \
      "(targeting_rules->>'max_age')::int >= ?",
      max_age, min_age
    )
  }

  scope :targeting_locations, ->(countries) {
    where(
      "targeting_rules->'geo'->'countries' ?| array[:countries]",
      countries: countries
    )
  }

  # Performance-optimized deep JSONB path queries
  scope :high_performing, -> {
    where(
      "(performance_metrics->'ctr')::decimal > ? AND " \
      "(performance_metrics->'conversion_rate')::decimal > ? AND " \
      "(performance_metrics->>'status') = ?",
      0.05, 0.02, "active"
    )
  }

  # Combining multiple JSONB conditions efficiently
  scope :advanced_targeting, ->(params) {
    query = all

    # Use JSONB operators for exact matching
    if params[:device_types].present?
      query = query.where(
        "targeting_rules->'devices' ?| array[:types]",
        types: params[:device_types]
      )
    end

    # Use path extraction for nested values
    if params[:min_age].present?
      query = query.where(
        "(targeting_rules->'demographics'->>'min_age')::int >= ?",
        params[:min_age]
      )
    end

    # Use JSONB containment for complex objects
    if params[:required_features].present?
      query = query.where(
        "targeting_rules @> ?",
        {features: params[:required_features]}.to_json
      )
    end

    query
  end

  # Fallback for large datasets: extract JSONB to materialized columns
  # Migration: add_column :campaigns, :budget_threshold_cached, :decimal
  # After save: update(budget_threshold_cached: settings.dig("budget_settings", "threshold"))

  scope :budget_threshold_fast, ->(threshold) {
    # Use materialized column for better performance on large tables
    if column_names.include?("budget_threshold_cached")
      where("budget_threshold_cached >= ?", threshold)
    else
      # Fallback to JSONB extraction
      where("(settings->'budget_settings'->>'threshold')::decimal >= ?", threshold)
    end
  }

  # Performance monitoring helper
  def self.analyze_query_performance(scope)
    query = scope.to_sql
    result = connection.execute("EXPLAIN ANALYZE #{query}")

    {
      query: query,
      plan: result.to_a,
      execution_time: extract_execution_time(result),
      index_usage: check_index_usage(result)
    }
  end

  private_class_method def self.extract_execution_time(result)
    result.to_a.find { |row| row["QUERY PLAN"]&.include?("Execution Time") }
  end

  private_class_method def self.check_index_usage(result)
    plan = result.to_a.map { |row| row["QUERY PLAN"] }.join("\n")
    {
      using_index: plan.include?("Index Scan") || plan.include?("Bitmap Index Scan"),
      using_gin: plan.include?("Gin"),
      sequential_scan: plan.include?("Seq Scan")
    }
  end
end

# Usage example with performance optimization
class CampaignAnalyticsController < ApplicationController
  def high_performance_campaigns
    # Start with base predicates
    @campaigns = Campaign
                   .status_eq("active")
                   .start_date_lteq(Date.today)
                   .end_date_gteq(Date.today)

    # Add JSONB filters with consideration for index usage
    if params[:min_budget].present?
      @campaigns = @campaigns.budget_threshold_fast(params[:min_budget].to_f)
    end

    # PostgreSQL-specific JSONB queries
    if Campaign.connection.adapter_name == "PostgreSQL"
      # Use GIN index for containment queries
      if params[:required_settings].present?
        @campaigns = @campaigns.settings_jsonb_contains(params[:required_settings])
      end

      # Use operator classes for specific key checks
      if params[:has_auto_bidding]
        @campaigns = @campaigns.settings_has_key("auto_bidding")
      end
    end

    # Monitor query performance in development
    if Rails.env.development?
      performance = Campaign.analyze_query_performance(@campaigns)
      Rails.logger.debug "Query Performance: #{performance.inspect}"

      # Warn if not using indexes
      unless performance[:index_usage][:using_index]
        Rails.logger.warn "⚠️  Query not using indexes! Consider adding GIN index."
      end
    end

    # Paginate for large datasets
    @campaigns = @campaigns.page(params[:page]).per(50)

    render json: @campaigns
  end

  def filter_by_audience
    @campaigns = Campaign.all

    # Complex audience filtering with multiple JSONB conditions
    if params[:countries].present?
      @campaigns = @campaigns.targeting_locations(params[:countries])
    end

    if params[:age_range].present?
      min_age, max_age = params[:age_range].split("-").map(&:to_i)
      @campaigns = @campaigns.targeting_age_range(min_age, max_age)
    end

    if params[:device_types].present?
      @campaigns = @campaigns.advanced_targeting(device_types: params[:device_types])
    end

    # Performance optimization: use select to load only needed fields
    @campaigns = @campaigns.select(
      :id, :name, :status, :budget, :spent,
      :impressions, :clicks, :conversions,
      "settings->>'name' as settings_name",
      "(performance_metrics->'ctr')::decimal as ctr",
      "(performance_metrics->'conversion_rate')::decimal as conversion_rate"
    )

    render json: @campaigns
  end

  def export_with_jsonb_data
    # For large exports, consider extracting JSONB data in batches
    @campaigns = Campaign.status_eq("active")

    # Process in batches to avoid memory issues
    csv_data = CSV.generate do |csv|
      csv << [
        "ID", "Name", "Budget", "Spent",
        "Auto Bidding", "Target Countries", "Min Age", "Max Age",
        "CTR", "Conversion Rate"
      ]

      @campaigns.find_each(batch_size: 1000) do |campaign|
        csv << [
          campaign.id,
          campaign.name,
          campaign.budget,
          campaign.spent,
          campaign.settings.dig("auto_bidding", "enabled"),
          campaign.targeting_rules.dig("geo", "countries")&.join(", "),
          campaign.targeting_rules.dig("demographics", "min_age"),
          campaign.targeting_rules.dig("demographics", "max_age"),
          campaign.performance_metrics&.dig("ctr"),
          campaign.performance_metrics&.dig("conversion_rate")
        ]
      end
    end

    send_data csv_data, filename: "campaigns-#{Date.today}.csv"
  end
end
```

### Handling NULL Values and Edge Cases in Range Queries

```ruby
class Event < ApplicationRecord
  include BetterModel

  predicable :title, :description, :location
  predicable :start_time, :end_time, :registration_deadline
  predicable :min_attendees, :max_attendees, :current_attendees
  predicable :price, :early_bird_price, :member_price
  predicable :is_virtual, :is_public, :is_featured
  predicable :created_at, :updated_at, :published_at, :cancelled_at

  # Safe range queries that handle NULL values
  scope :within_budget, ->(max_price) {
    # Consider free events (price = NULL or 0)
    where("price IS NULL OR price <= ?", max_price)
  }

  scope :has_capacity, -> {
    # Handle NULL max_attendees (unlimited capacity)
    where("max_attendees IS NULL OR current_attendees < max_attendees")
  }

  scope :registration_open, -> {
    now = Time.current

    # Handle NULL deadline (always open) and future deadlines
    where("registration_deadline IS NULL OR registration_deadline > ?", now)
      .where("start_time > ?", now)
      .where("cancelled_at IS NULL")
  }

  # Combining NULL handling with predicates
  scope :available_events, -> {
    is_public_eq(true)
      .where("cancelled_at IS NULL")
      .where("start_time > ?", Time.current)
      .where("max_attendees IS NULL OR current_attendees < max_attendees")
  }

  # Edge case: comparing two nullable columns
  scope :early_bird_available, -> {
    where("early_bird_price IS NOT NULL")
      .where("early_bird_price < price")
      .where("start_time > ?", 7.days.from_now)
  }

  # Safe date range with NULL handling
  scope :in_date_range, ->(start_date, end_date) {
    # Ensure we don't exclude events with NULL dates incorrectly
    query = all

    if start_date.present?
      query = query.where("start_time >= ? OR start_time IS NULL", start_date)
    end

    if end_date.present?
      query = query.where("start_time <= ? OR start_time IS NULL", end_date)
    end

    query
  }

  # Performance optimization: use COALESCE for NULL defaults
  scope :sorted_by_price, -> {
    # Treat NULL prices as 0 for sorting
    order(Arel.sql("COALESCE(price, 0) ASC"))
  }

  scope :sorted_by_capacity, -> {
    # Treat NULL max_attendees as infinity for sorting
    order(Arel.sql("COALESCE(max_attendees, 999999) DESC"))
  end

  # Handling division by zero and NULL in calculations
  scope :high_attendance_rate, -> {
    where(
      "CASE " \
      "  WHEN max_attendees IS NULL OR max_attendees = 0 THEN false " \
      "  ELSE (current_attendees::decimal / max_attendees) >= 0.8 " \
      "END"
    )
  }
end

# Controller with NULL-safe filtering
class EventsController < ApplicationController
  def index
    @events = Event.all

    # Price filter with NULL handling
    if params[:max_price].present?
      max_price = params[:max_price].to_f

      if params[:include_free] == "true"
        # Include NULL and 0 prices (free events)
        @events = @events.where("price IS NULL OR price = 0 OR price <= ?", max_price)
      else
        # Exclude NULL prices
        @events = @events.where("price IS NOT NULL AND price <= ?", max_price)
      end
    end

    # Capacity filter with NULL handling
    if params[:has_capacity] == "true"
      @events = @events.has_capacity
    end

    # Date range with NULL consideration
    if params[:start_date].present? || params[:end_date].present?
      @events = @events.in_date_range(
        params[:start_date]&.to_date,
        params[:end_date]&.to_date
      )
    end

    # Registration status with NULL deadline handling
    if params[:registration_status] == "open"
      @events = @events.registration_open
    end

    @events = @events.page(params[:page]).per(20)
    render :index
  end

  def search_with_edge_cases
    @events = Event.is_public_eq(true)

    # Handle empty search queries
    if params[:query].present? && params[:query].strip.length >= 3
      query = params[:query].strip
      @events = @events.title_i_cont(query)
        .or(@events.description_i_cont(query))
        .or(@events.location_i_cont(query))
    end

    # Handle boundary values
    if params[:min_attendees].present?
      min = [params[:min_attendees].to_i, 0].max # Ensure non-negative
      @events = @events.where("min_attendees >= ? OR min_attendees IS NULL", min)
    end

    # Handle overlapping date ranges
    if params[:date_from].present? && params[:date_to].present?
      date_from = Date.parse(params[:date_from]) rescue nil
      date_to = Date.parse(params[:date_to]) rescue nil

      if date_from && date_to && date_from <= date_to
        @events = @events.where(
          "(start_time BETWEEN ? AND ?) OR (end_time BETWEEN ? AND ?) OR " \
          "(start_time <= ? AND end_time >= ?)",
          date_from, date_to, date_from, date_to, date_from, date_to
        )
      end
    end

    render :index
  end
end
```

## Testing Predicable Models

Comprehensive testing strategies for predicate scopes and queries

Testing Predicable models requires verifying generated scopes work correctly, testing complex predicate chains, ensuring proper SQL generation, and validating NULL handling and edge cases. This section provides RSpec examples covering various testing scenarios.

### RSpec Examples for Predicate Scopes

```ruby
# spec/models/product_spec.rb
require "rails_helper"

RSpec.describe Product, type: :model do
  describe "Predicable" do
    describe "generated scopes" do
      it "generates comparison predicates for numeric fields" do
        expect(Product).to respond_to(:price_eq)
        expect(Product).to respond_to(:price_lt)
        expect(Product).to respond_to(:price_lteq)
        expect(Product).to respond_to(:price_gt)
        expect(Product).to respond_to(:price_gteq)
      end

      it "generates range predicates for numeric fields" do
        expect(Product).to respond_to(:price_between)
        expect(Product).to respond_to(:price_not_between)
      end

      it "generates pattern matching predicates for string fields" do
        expect(Product).to respond_to(:name_cont)
        expect(Product).to respond_to(:name_i_cont)
        expect(Product).to respond_to(:name_start)
        expect(Product).to respond_to(:name_end)
      end

      it "generates presence predicates for all fields" do
        expect(Product).to respond_to(:name_present)
        expect(Product).to respond_to(:name_blank)
        expect(Product).to respond_to(:name_null)
      end

      it "generates boolean predicates" do
        expect(Product).to respond_to(:is_featured_eq)
        expect(Product).to respond_to(:is_active_eq)
      end
    end

    describe "comparison predicates" do
      let!(:cheap_product) { create(:product, price: 10.00) }
      let!(:medium_product) { create(:product, price: 50.00) }
      let!(:expensive_product) { create(:product, price: 100.00) }

      describe "#price_eq" do
        it "returns products with exact price" do
          results = Product.price_eq(50.00)
          expect(results).to include(medium_product)
          expect(results).not_to include(cheap_product, expensive_product)
        end
      end

      describe "#price_lt" do
        it "returns products below price threshold" do
          results = Product.price_lt(50.00)
          expect(results).to include(cheap_product)
          expect(results).not_to include(medium_product, expensive_product)
        end
      end

      describe "#price_lteq" do
        it "returns products at or below price threshold" do
          results = Product.price_lteq(50.00)
          expect(results).to include(cheap_product, medium_product)
          expect(results).not_to include(expensive_product)
        end
      end

      describe "#price_gt" do
        it "returns products above price threshold" do
          results = Product.price_gt(50.00)
          expect(results).to include(expensive_product)
          expect(results).not_to include(cheap_product, medium_product)
        end
      end

      describe "#price_gteq" do
        it "returns products at or above price threshold" do
          results = Product.price_gteq(50.00)
          expect(results).to include(medium_product, expensive_product)
          expect(results).not_to include(cheap_product)
        end
      end

      describe "#price_between" do
        it "returns products within price range" do
          results = Product.price_between(25.00, 75.00)
          expect(results).to include(medium_product)
          expect(results).not_to include(cheap_product, expensive_product)
        end

        it "includes boundary values" do
          results = Product.price_between(10.00, 100.00)
          expect(results).to include(cheap_product, medium_product, expensive_product)
        end
      end

      describe "#price_not_between" do
        it "returns products outside price range" do
          results = Product.price_not_between(25.00, 75.00)
          expect(results).to include(cheap_product, expensive_product)
          expect(results).not_to include(medium_product)
        end
      end
    end

    describe "string pattern matching predicates" do
      let!(:rails_book) { create(:product, name: "Rails Guide") }
      let!(:ruby_book) { create(:product, name: "Ruby Programming") }
      let!(:python_book) { create(:product, name: "Python Basics") }

      describe "#name_cont" do
        it "returns products with substring match (case-sensitive)" do
          results = Product.name_cont("Rails")
          expect(results).to include(rails_book)
          expect(results).not_to include(ruby_book, python_book)
        end
      end

      describe "#name_i_cont" do
        it "returns products with substring match (case-insensitive)" do
          results = Product.name_i_cont("rails")
          expect(results).to include(rails_book)
          expect(results).not_to include(ruby_book, python_book)
        end

        it "works with mixed case" do
          results = Product.name_i_cont("RAILS")
          expect(results).to include(rails_book)
        end
      end

      describe "#name_start" do
        it "returns products with name starting with string" do
          results = Product.name_start("Rails")
          expect(results).to include(rails_book)
          expect(results).not_to include(ruby_book, python_book)
        end
      end

      describe "#name_end" do
        it "returns products with name ending with string" do
          results = Product.name_end("Guide")
          expect(results).to include(rails_book)
          expect(results).not_to include(ruby_book, python_book)
        end
      end

      describe "#name_not_cont" do
        it "returns products without substring" do
          results = Product.name_not_cont("Rails")
          expect(results).to include(ruby_book, python_book)
          expect(results).not_to include(rails_book)
        end
      end
    end

    describe "presence predicates" do
      let!(:complete_product) { create(:product, name: "Complete", description: "Full description") }
      let!(:partial_product) { create(:product, name: "Partial", description: "") }
      let!(:minimal_product) { create(:product, name: "Minimal", description: nil) }

      describe "#description_present" do
        it "returns products with non-null, non-empty description" do
          results = Product.description_present(true)
          expect(results).to include(complete_product)
          expect(results).not_to include(partial_product, minimal_product)
        end

        it "returns products without description when passed false" do
          results = Product.description_present(false)
          expect(results).to include(partial_product, minimal_product)
          expect(results).not_to include(complete_product)
        end
      end

      describe "#description_blank" do
        it "returns products with blank description" do
          results = Product.description_blank(true)
          expect(results).to include(partial_product, minimal_product)
          expect(results).not_to include(complete_product)
        end
      end

      describe "#description_null" do
        it "returns products with NULL description" do
          results = Product.description_null(true)
          expect(results).to include(minimal_product)
          expect(results).not_to include(complete_product, partial_product)
        end

        it "returns products with non-NULL description when passed false" do
          results = Product.description_null(false)
          expect(results).to include(complete_product, partial_product)
          expect(results).not_to include(minimal_product)
        end
      end
    end

    describe "boolean predicates" do
      let!(:featured_product) { create(:product, is_featured: true) }
      let!(:normal_product) { create(:product, is_featured: false) }

      describe "#is_featured_eq" do
        it "returns featured products when true" do
          results = Product.is_featured_eq(true)
          expect(results).to include(featured_product)
          expect(results).not_to include(normal_product)
        end

        it "returns non-featured products when false" do
          results = Product.is_featured_eq(false)
          expect(results).to include(normal_product)
          expect(results).not_to include(featured_product)
        end
      end
    end

    describe "date predicates" do
      let!(:new_product) { create(:product, published_at: 2.days.ago) }
      let!(:old_product) { create(:product, published_at: 10.days.ago) }
      let!(:ancient_product) { create(:product, published_at: 60.days.ago) }

      describe "#published_at_within" do
        it "returns products published within duration" do
          results = Product.published_at_within(7.days)
          expect(results).to include(new_product)
          expect(results).not_to include(old_product, ancient_product)
        end
      end

      describe "#published_at_gteq" do
        it "returns products published on or after date" do
          date = 8.days.ago
          results = Product.published_at_gteq(date)
          expect(results).to include(new_product)
          expect(results).not_to include(old_product, ancient_product)
        end
      end

      describe "#published_at_between" do
        it "returns products published within date range" do
          start_date = 15.days.ago
          end_date = 5.days.ago
          results = Product.published_at_between(start_date, end_date)
          expect(results).to include(old_product)
          expect(results).not_to include(new_product, ancient_product)
        end
      end
    end

    describe "array predicates" do
      let!(:ruby_product) { create(:product, category: "ruby") }
      let!(:rails_product) { create(:product, category: "rails") }
      let!(:python_product) { create(:product, category: "python") }

      describe "#category_in" do
        it "returns products with category in array" do
          results = Product.category_in(["ruby", "rails"])
          expect(results).to include(ruby_product, rails_product)
          expect(results).not_to include(python_product)
        end

        it "works with single-element array" do
          results = Product.category_in(["ruby"])
          expect(results).to include(ruby_product)
          expect(results).not_to include(rails_product, python_product)
        end
      end

      describe "#category_not_in" do
        it "returns products with category not in array" do
          results = Product.category_not_in(["ruby", "rails"])
          expect(results).to include(python_product)
          expect(results).not_to include(ruby_product, rails_product)
        end
      end
    end

    describe "chaining predicates" do
      let!(:featured_cheap) { create(:product, is_featured: true, price: 10, stock_quantity: 5) }
      let!(:featured_expensive) { create(:product, is_featured: true, price: 100, stock_quantity: 0) }
      let!(:normal_cheap) { create(:product, is_featured: false, price: 10, stock_quantity: 10) }

      it "chains multiple predicates with AND logic" do
        results = Product
                    .is_featured_eq(true)
                    .price_lt(50)
                    .stock_quantity_gt(0)

        expect(results).to include(featured_cheap)
        expect(results).not_to include(featured_expensive, normal_cheap)
      end

      it "chains with complex conditions" do
        results = Product
                    .price_between(5, 50)
                    .stock_quantity_gteq(5)
                    .name_present(true)

        expect(results.count).to eq(2)
        expect(results).to include(featured_cheap, normal_cheap)
      end
    end

    describe "edge cases" do
      it "handles empty arrays in _in predicates" do
        results = Product.category_in([])
        expect(results).to be_empty
      end

      it "handles nil values in comparisons" do
        product_with_nil = create(:product, sale_price: nil)
        product_with_price = create(:product, sale_price: 50)

        results = Product.sale_price_null(true)
        expect(results).to include(product_with_nil)
        expect(results).not_to include(product_with_price)
      end

      it "handles zero values correctly" do
        free_product = create(:product, price: 0)
        paid_product = create(:product, price: 10)

        results = Product.price_eq(0)
        expect(results).to include(free_product)
        expect(results).not_to include(paid_product)
      end
    end

    describe "SQL generation" do
      it "generates correct SQL for simple predicates" do
        query = Product.price_eq(50).to_sql
        expect(query).to include('price')
        expect(query).to include('50')
      end

      it "generates correct SQL for chained predicates" do
        query = Product.price_between(10, 100).is_active_eq(true).to_sql
        expect(query).to include('BETWEEN')
        expect(query).to include('is_active')
      end

      it "uses LIKE for pattern matching" do
        query = Product.name_cont("test").to_sql
        expect(query).to match(/LIKE/i)
        expect(query).to include('%test%')
      end

      it "uses LOWER for case-insensitive matching" do
        query = Product.name_i_cont("test").to_sql
        expect(query).to match(/LOWER/i)
      end
    end
  end
end
```

## Database Compatibility Matrix

Feature support across SQLite, MySQL, and PostgreSQL

| Feature Category | SQLite | MySQL | PostgreSQL | Implementation Notes |
|------------------|--------|-------|------------|----------------------|
| **Comparison Predicates** (`_eq`, `_lt`, `_gt`, etc.) | ✅ | ✅ | ✅ | Universal Arel-based implementation, all require parameters |
| **Range Predicates** (`_between`, `_not_between`) | ✅ | ✅ | ✅ | Native SQL BETWEEN clause, requires min and max parameters |
| **Pattern Matching** (`_cont`, `_start`, `_end`, `_matches`) | ✅ | ✅ | ✅ | SQL LIKE operator, requires pattern parameter |
| **Case-Insensitive** (`_i_cont`, `_not_i_cont`) | ✅ | ✅ | ✅ | LOWER() function wrapper, requires substring parameter |
| **Array Predicates** (`_in`, `_not_in`) | ✅ | ✅ | ✅ | Standard SQL IN operator, requires array parameter |
| **Presence Predicates** (`_present`, `_blank`, `_null`) | ✅ | ✅ | ✅ | IS NULL / IS NOT NULL checks, requires boolean parameter |
| **Date Within** (`_within`) | ✅ | ✅ | ✅ | ActiveSupport date helpers, requires duration parameter |
| **Array Operators** (`_overlaps`, `_contains`, `_contained_by`) | ❌ | ❌ | ✅ | PostgreSQL array operators (&&, @>, <@), require parameters |
| **JSONB Operators** (`_has_key`, `_jsonb_contains`) | ❌ | ❌ | ✅ | PostgreSQL JSONB operators (?, @>), require parameters |

```ruby
# Database detection and feature availability
# Predicable automatically detects your database adapter

# Universal predicates (work everywhere, all require parameters)
Article.title_cont("Rails")              # ✅ SQLite, MySQL, PostgreSQL
Article.view_count_between(100, 500)     # ✅ SQLite, MySQL, PostgreSQL
Article.published_at_within(7.days)      # ✅ SQLite, MySQL, PostgreSQL

# PostgreSQL-only predicates (only generated when using PostgreSQL, require parameters)
if Article.connection.adapter_name == "PostgreSQL"
  Article.tags_overlaps(['ruby', 'rails'])        # ✅ PostgreSQL only
  Article.settings_has_key('notifications')       # ✅ PostgreSQL only
  # These methods exist only when using PostgreSQL
end

# Attempting PostgreSQL-specific predicates on other databases
# will result in NoMethodError since they're not generated

# Safe cross-database code
if Article.respond_to?(:tags_overlaps)
  # Using PostgreSQL
  @articles = Article.tags_overlaps(requested_tags)
else
  # Using SQLite or MySQL - use alternative approach
  # (e.g., serialized array with string matching)
  @articles = Article.all  # Apply filtering differently
end
```

## Best Practices

Guidelines for effective Predicable usage in production applications with explicit parameters

```ruby
# GOOD: All parameters are explicit and required
Article.published_at_gteq(Date.today.beginning_of_day)  # Today's articles
Article.published_at_gteq(Date.today.beginning_of_week) # This week
Article.view_count_between(100, 500)                    # View count range
Article.title_present(true)                              # Has a title
Article.featured_eq(true)                                # Is featured

# AVOID: No default values or shortcuts exist
# Article.published_at_today        # ❌ Does not exist
# Article.featured_true             # ❌ Does not exist
# Article.title_present()           # ❌ Error - parameter required

# GOOD: Leverage case-insensitive search for user-facing features
Article.title_i_cont(params[:query])

# AVOID: Manual LOWER() wrapping
Article.where("LOWER(title) LIKE ?", "%#{params[:query].downcase}%")

# GOOD: Chain predicates logically - filter first, then sort
Article
  .status_eq("published")
  .view_count_gt(100)
  .published_at_within(30.days)
  .order(view_count: :desc)

# GOOD: Use _within for recency (requires parameter)
Article.published_at_within(7.days)
Article.updated_at_within(24.hours)

# AVOID: Manual date math (less readable)
Article.where("published_at >= ?", 7.days.ago)

# GOOD: Register complex business logic as complex predicates
register_complex_predicate :trending do
  where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
end

# AVOID: Repeating complex conditions
Article.where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
Article.where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)  # Duplicate

# GOOD: Boolean fields use _eq with explicit value
Article.featured_eq(true)
Article.archived_eq(false)

# AVOID: Non-existent shortcuts
# Article.featured_true    # ❌ Does not exist
# Article.archived_false   # ❌ Does not exist

# GOOD: Presence checks with explicit boolean
Article.title_present(true)          # Has title
Article.title_present(false)         # No title
Article.published_at_null(true)      # Not published
Article.published_at_null(false)     # Is published

# GOOD: Load associations before applying predicates (avoid N+1)
articles = Article
  .includes(:author, :comments)
  .status_eq("published")
  .published_at_within(30.days)

# GOOD: Add database indexes for frequently filtered columns
# db/migrate/xxx_add_indexes_to_articles.rb
class AddIndexesToArticles < ActiveRecord::Migration[7.0]
  def change
    add_index :articles, :status
    add_index :articles, :published_at
    add_index :articles, :view_count
    add_index :articles, [:status, :published_at]  # Composite index
  end
end

# GOOD: Validate filter parameters before applying
def apply_filters(scope, params)
  if params[:status].present? && valid_statuses.include?(params[:status])
    scope = scope.status_eq(params[:status])
  end

  if params[:min_views].present? && params[:min_views].to_i > 0
    scope = scope.view_count_gteq(params[:min_views].to_i)
  end

  scope
end

# GOOD: Use predicable_scope? for dynamic filtering
def apply_dynamic_filter(scope, field, predicate, value)
  scope_name = "#{field}_#{predicate}".to_sym

  if scope.predicable_scope?(scope_name)
    scope.public_send(scope_name, value)
  else
    raise ArgumentError, "Invalid filter: #{scope_name}"
  end
end

# GOOD: Combine with pagination
@articles = Article
  .status_eq("published")
  .published_at_within(30.days)
  .view_count_gt(50)
  .page(params[:page])
  .per(20)

# GOOD: Use PostgreSQL-specific predicates when available
if Article.respond_to?(:tags_overlaps)
  Article.tags_overlaps(requested_tags)
else
  # Fallback for non-PostgreSQL databases
  Article.all  # Or alternative implementation
end

# GOOD: Date filtering with explicit comparisons instead of removed shortcuts
# Instead of: Article.published_at_today (removed)
Article.published_at_gteq(Date.today.beginning_of_day)

# Instead of: Article.published_at_this_week (removed)
Article.published_at_gteq(Date.today.beginning_of_week)

# Instead of: Article.published_at_past (removed)
Article.published_at_lt(Time.current)

# Instead of: Article.published_at_future (removed)
Article.published_at_gt(Time.current)
```

## Thread Safety and Performance

Concurrency guarantees and optimization characteristics

### Thread Safety

Predicable is designed for thread-safe operation in concurrent Rails applications. All registry data structures use frozen immutable collections, scopes are defined once at class load time, and no mutable shared state exists between requests.

```ruby
# Thread-safe registry implementation
Article.predicable_fields
# => #<Set: {:title, :status, ...}>  (frozen)

Article.predicable_scopes
# => #<Set: {:title_eq, :title_cont, ...}>  (frozen)

Article.complex_predicates_registry
# => {:trending => #<Proc>, ...}  (frozen Hash)

# Scope definitions are created once at class load
# Concurrent requests using the same scope are safe
# Thread 1
Article.status_eq("published").view_count_gt(100)

# Thread 2 (concurrent)
Article.status_eq("draft").published_at_within(7.days)

# No interference between threads
```

### Performance Characteristics

Predicable is optimized for production use with minimal overhead:

- **Zero runtime overhead**: All predicates are compiled at class load time via `define_singleton_method`
- **Efficient SQL generation**: Uses Arel for universal predicates, raw SQL only for PostgreSQL-specific operators
- **Registry lookups**: O(1) constant time with Set and Hash data structures
- **Memory footprint**: Approximately 150-200 bytes per model for registries (negligible)
- **Conditional generation**: PostgreSQL-specific predicates only generated when needed
- **No default parameter overhead**: All parameters are required, eliminating default value processing

```ruby
# Performance example: Predicate compilation happens once
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at
  # All scopes compiled here at class load time
end

# Runtime: No overhead, direct method call
Article.title_cont("Rails")  # Direct method call, no metaprogramming
Article.view_count_gt(100)   # Pre-compiled scope
Article.published_at_within(7.days)  # Pre-compiled date scope

# Benchmark example (illustrative)
require 'benchmark'

Benchmark.bm do |x|
  x.report("Predicable:") do
    10_000.times { Article.status_eq("published").view_count_gt(100) }
  end

  x.report("Manual where:") do
    10_000.times { Article.where(status: "published").where("view_count > ?", 100) }
  end
end

# Results: Nearly identical performance (Predicable uses same Arel underneath)
#                 user     system      total        real
# Predicable:  0.050000   0.000000   0.050000 (  0.052340)
# Manual where: 0.051000   0.000000   0.051000 (  0.053120)

# Database query optimization
# Always add indexes to frequently filtered columns
add_index :articles, :status
add_index :articles, :view_count
add_index :articles, :published_at
add_index :articles, [:status, :published_at]  # Composite for common combinations

# PostgreSQL-specific: GIN indexes for arrays and JSONB
add_index :articles, :tags, using: 'gin'
add_index :users, :settings, using: 'gin'
```
