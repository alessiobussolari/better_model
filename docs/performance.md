# BetterModel Performance Guide

This guide covers performance considerations, best practices, and optimization strategies for each BetterModel module.

## Table of Contents

1. [General Guidelines](#general-guidelines)
2. [Module-Specific Performance](#module-specific-performance)
   - [Predicable](#predicable)
   - [Sortable](#sortable)
   - [Searchable](#searchable)
   - [Archivable](#archivable)
   - [Traceable](#traceable)
   - [Stateable](#stateable)
   - [Taggable](#taggable)
   - [Validatable](#validatable)
3. [Database Indexing](#database-indexing)
4. [Query Optimization](#query-optimization)
5. [Memory Management](#memory-management)
6. [Caching Strategies](#caching-strategies)
7. [Benchmarks](#benchmarks)

---

## General Guidelines

### 1. Only Include What You Need

BetterModel modules are opt-in. Only include the modules your model actually needs:

```ruby
# Good - only include needed modules
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status  # Only Predicable
  sort :created_at            # Only Sortable
end

# Avoid - including everything when not needed
class Article < ApplicationRecord
  include BetterModel

  # Configuring every module when only using a few
  predicates :title, :status
  sort :created_at
  archivable { }  # Don't include if not archiving
  traceable { }   # Don't include if not tracking
  stateable { }   # Don't include if no state machine
end
```

### 2. Configure Globally, Override Locally

Use global configuration to set defaults, reducing per-model overhead:

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  config.searchable_max_per_page = 100
  config.searchable_default_per_page = 25
  config.archivable_skip_archived_by_default = true
end
```

### 3. Use Strict Mode in Development

Enable strict mode to catch performance issues early:

```ruby
# config/initializers/better_model.rb
if Rails.env.development? || Rails.env.test?
  BetterModel.configure do |config|
    config.strict_mode = true
  end
end
```

---

## Module-Specific Performance

### Predicable

#### Scope Generation

Predicable generates scopes at class load time. The number of scopes depends on:
- Number of fields declared with `predicates`
- Column types (each type generates different predicates)

**Memory Impact:**
- ~10-15 scopes per string field
- ~8-10 scopes per numeric field
- ~12-14 scopes per date/datetime field

**Best Practice:** Only declare fields that need filtering:

```ruby
# Good - specific fields
predicates :title, :status, :published_at

# Avoid - unnecessary fields
predicates :title, :body, :status, :author_id, :created_at, :updated_at,
           :view_count, :slug, :meta_description, :excerpt
```

#### Query Performance

Predicable scopes translate directly to SQL conditions. Performance depends on database indexes:

```ruby
# Fast (with index on status)
Article.status_eq("published")

# Slower (LIKE queries)
Article.title_cont("Rails")  # LIKE '%Rails%'

# Faster LIKE (prefix search)
Article.title_start("Rails")  # LIKE 'Rails%'
```

**Recommendation:** Add indexes for frequently filtered columns.

### Sortable

#### Scope Generation

Sortable generates sorting scopes at class load time:

**Memory Impact:**
- String: 4 scopes (`_asc`, `_desc`, `_asc_i`, `_desc_i`)
- Numeric: 6 scopes (`_asc`, `_desc`, `_asc_nulls_last`, `_desc_nulls_last`, etc.)
- Date: 4 scopes (`_asc`, `_desc`, `_newest`, `_oldest`)

**Best Practice:** Declare only sortable fields:

```ruby
# Good
sort :title, :published_at, :view_count

# Avoid - sorting by rarely used fields
sort :title, :body, :excerpt, :meta_description, :slug
```

#### NULL Handling Performance

NULL handling uses database-specific optimizations:

```ruby
# PostgreSQL/SQLite (native support - faster)
Article.sort_view_count_desc_nulls_last
# => ORDER BY view_count DESC NULLS LAST

# MySQL (CASE expression - slightly slower)
# => ORDER BY CASE WHEN view_count IS NULL THEN 1 ELSE 0 END, view_count DESC
```

### Searchable

#### Search Operation Complexity

The `search` method combines filtering, sorting, and pagination:

```ruby
# Simple search (O(1) scope chaining)
Article.search(status_eq: "published")

# Complex search (multiple predicates + sort + pagination)
Article.search(
  { status_eq: "published", title_cont: "Rails" },
  orders: [:sort_published_at_desc],
  page: 1,
  per_page: 25
)
```

**Performance Tips:**

1. **Limit predicates:** Each predicate adds a WHERE clause
2. **Use indexed fields first:** Put indexed columns early in search
3. **Paginate always:** Never return unlimited results

```ruby
# Configure max_per_page globally
BetterModel.configure do |config|
  config.searchable_max_per_page = 100  # Prevent excessive results
end
```

### Archivable

#### Default Scope Overhead

When `skip_archived_by_default` is enabled, a default scope is added:

```ruby
archivable do
  skip_archived_by_default true  # Adds: default_scope { where(archived_at: nil) }
end
```

**Performance Impact:**
- Every query includes an additional WHERE clause
- `unscoped` is needed for archived records

**Recommendation:** Index the archive column:

```ruby
# migration
add_index :articles, :archived_at
```

#### Archive with Reason

Archiving stores metadata (by, reason, previous_status):

```ruby
article.archive!(by: user.id, reason: "Content violation")
# Updates 4 columns: archived_at, archived_by, archive_reason, status_before_archive
```

**Optimization:** Use partial indexes if most records are not archived:

```sql
CREATE INDEX idx_articles_archived ON articles(archived_at) WHERE archived_at IS NOT NULL;
```

### Traceable

#### Version Storage Overhead

Traceable creates version records on every tracked change:

**Space Complexity:** O(n) where n = number of changes

**Best Practices:**

1. **Track only essential fields:**
```ruby
traceable do
  track :title, :status, :content  # Only important fields
  ignore :view_count, :updated_at  # Skip frequently changing fields
end
```

2. **Use version limits:**
```ruby
traceable do
  max_versions 50  # Keep only last 50 versions
  cleanup_old_versions true
end
```

3. **Index version table:**
```ruby
# migration
add_index :article_versions, [:article_id, :created_at]
add_index :article_versions, :created_at
```

#### Rollback Performance

Rolling back to a previous version:

```ruby
article.rollback_to(version)  # O(1) - single update
```

**Memory for version history:**

```ruby
article.versions           # Loads all versions (avoid for many versions)
article.versions.limit(10) # Paginate version history
```

### Stateable

#### Transition Overhead

Each transition performs:
1. Check validations (O(n) where n = number of checks)
2. Execute before callbacks
3. Update state column
4. Create transition record (if tracking enabled)
5. Execute after callbacks

**Best Practices:**

1. **Keep checks lightweight:**
```ruby
transition :publish, from: :draft, to: :published do
  # Good - simple attribute check
  check { content.present? }

  # Avoid - expensive database query in check
  check { Article.where(status: :published).count < 1000 }
end
```

2. **Use database constraints:**
```ruby
# Let the database handle uniqueness
validates :slug, uniqueness: true
# Instead of
check { Article.where(slug: slug).none? }
```

3. **Index state column:**
```ruby
add_index :articles, :state
```

#### Transition History

If tracking transitions:

```ruby
# Index the transitions table
add_index :state_transitions, [:transitionable_type, :transitionable_id]
add_index :state_transitions, :created_at
```

### Taggable

#### PostgreSQL Array Performance

Taggable uses PostgreSQL arrays (or JSON in SQLite):

**Query Performance:**

```ruby
# Contains (uses GIN index)
Article.tags_contains("ruby")
# => WHERE tags @> ARRAY['ruby']

# Overlaps (uses GIN index)
Article.tags_overlaps(["ruby", "rails"])
# => WHERE tags && ARRAY['ruby', 'rails']
```

**Required Index:**

```ruby
# PostgreSQL GIN index for array operations
execute "CREATE INDEX idx_articles_tags ON articles USING GIN (tags)"
```

#### Tag Statistics

`tag_counts` and `popular_tags` iterate over records:

```ruby
# O(n) - scans all records
Article.tag_counts
Article.popular_tags(limit: 10)
```

**For large datasets, use counter caching:**

```ruby
# Create a separate tags table with counts
class Tag < ApplicationRecord
  has_many :article_tags
  has_many :articles, through: :article_tags

  # Counter cache for fast lookups
  attribute :articles_count, :integer, default: 0
end
```

### Validatable

#### Validation Group Performance

Validation groups run only specified validations:

```ruby
# Full validation (all validators)
article.valid?

# Group validation (subset of validators)
article.validate_group(:step1)  # Only step1 validators
```

**Best Practice:** Use groups for multi-step forms:

```ruby
validatable do
  # Step 1: Basic info (fast)
  group :step1, fields: [:title]

  # Step 2: Content (medium)
  group :step2, fields: [:body, :excerpt]

  # Step 3: Publishing (might be slower if checking uniqueness)
  group :step3, fields: [:slug], methods: [:publish_ready?]
end
```

---

## Database Indexing

### Recommended Indexes by Module

```ruby
# migration
class AddBetterModelIndexes < ActiveRecord::Migration[7.0]
  def change
    # Predicable - filter columns
    add_index :articles, :status
    add_index :articles, :published_at
    add_index :articles, :author_id

    # Sortable - sort columns
    add_index :articles, :created_at
    add_index :articles, :title  # For case-insensitive: LOWER(title)

    # Archivable
    add_index :articles, :archived_at

    # Stateable
    add_index :articles, :state
    add_index :state_transitions, [:transitionable_type, :transitionable_id]

    # Traceable
    add_index :article_versions, [:article_id, :created_at]

    # Taggable (PostgreSQL)
    execute "CREATE INDEX idx_articles_tags ON articles USING GIN (tags)"
  end
end
```

### Composite Indexes for Common Queries

```ruby
# Common search pattern: status + published_at
add_index :articles, [:status, :published_at]

# Archive queries
add_index :articles, [:archived_at, :status]
```

---

## Query Optimization

### Use Eager Loading

When accessing associations through BetterModel methods:

```ruby
# N+1 problem
Article.search(status_eq: "published").each do |article|
  article.author.name  # Query per article
end

# Fixed with includes
Article.search(status_eq: "published")
       .includes(:author)
       .each do |article|
  article.author.name  # No additional queries
end
```

### Batch Processing

For bulk operations:

```ruby
# Memory efficient
Article.archived.find_each(batch_size: 1000) do |article|
  article.restore!
end

# Avoid loading all records
Article.archived.each do |article|  # Loads all into memory
  article.restore!
end
```

### Pluck for Simple Queries

When you only need specific columns:

```ruby
# Full objects (slower, more memory)
Article.search(status_eq: "published").map(&:title)

# Pluck (faster, less memory)
Article.search(status_eq: "published").pluck(:title)
```

---

## Memory Management

### Scope Chain vs Immediate Execution

BetterModel scopes are lazy:

```ruby
# Lazy (no query yet)
scope = Article.status_eq("published").sort_title_asc

# Query executed here
scope.to_a
scope.each { |a| ... }
scope.count
```

### Large Result Sets

Always paginate:

```ruby
# Configure global limit
BetterModel.configure do |config|
  config.searchable_max_per_page = 100
end

# Use pagination
Article.search(
  { status_eq: "published" },
  page: 1,
  per_page: 25
)
```

### Version History Memory

For Traceable, limit loaded versions:

```ruby
# Avoid
article.versions.to_a  # Loads all versions

# Better
article.versions.limit(20).to_a
article.versions.where("created_at > ?", 1.month.ago)
```

---

## Caching Strategies

### Cache Search Results

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Rails.cache.fetch(search_cache_key, expires_in: 5.minutes) do
      Article.search(search_params, page: params[:page]).to_a
    end
  end

  private

  def search_cache_key
    "articles/search/#{search_params.to_query}/#{params[:page]}"
  end
end
```

### Cache Tag Statistics

```ruby
# Cache expensive tag operations
def popular_tags
  Rails.cache.fetch("articles/popular_tags", expires_in: 1.hour) do
    Article.popular_tags(limit: 20)
  end
end
```

### Invalidate Cache on State Change

```ruby
stateable do
  transition :publish, from: :draft, to: :published do
    after { Rails.cache.delete_matched("articles/*") }
  end
end
```

---

## Benchmarks

### Scope Generation Time

Measured at class load time (one-time cost):

| Module | Fields | Scopes Generated | Time |
|--------|--------|------------------|------|
| Predicable | 5 | ~60 | ~2ms |
| Sortable | 5 | ~25 | ~1ms |
| Combined | 5 | ~85 | ~3ms |

### Query Performance

With proper indexes (PostgreSQL, 100k records):

| Operation | Time |
|-----------|------|
| `status_eq("published")` | ~1ms |
| `title_cont("Rails")` | ~5ms |
| `search({status_eq: "published", title_cont: "Rails"}, page: 1)` | ~6ms |
| `sort_published_at_desc.limit(25)` | ~2ms |

### Memory Usage

| Operation | Memory |
|-----------|--------|
| Load 1000 Article objects | ~10MB |
| Pluck 1000 titles | ~100KB |
| Search with pagination (25 records) | ~250KB |

---

## Performance Checklist

- [ ] Index all filterable columns (Predicable)
- [ ] Index all sortable columns (Sortable)
- [ ] Index archive column (Archivable)
- [ ] Index state column (Stateable)
- [ ] Create GIN index for tags (Taggable, PostgreSQL)
- [ ] Index version table (Traceable)
- [ ] Configure max_per_page globally
- [ ] Use pagination for all searches
- [ ] Track only essential fields in Traceable
- [ ] Keep state checks lightweight
- [ ] Use eager loading for associations
- [ ] Cache expensive operations
- [ ] Enable strict mode in development

---

## Summary

BetterModel is designed with performance in mind:

1. **Lazy evaluation** - Scopes chain without executing
2. **Database-level operations** - Filtering and sorting happen in SQL
3. **Configurable limits** - Pagination and max results prevent runaway queries
4. **Opt-in modules** - Only include what you need
5. **Index-friendly** - Generated queries work well with standard indexes

For most applications, BetterModel adds minimal overhead while providing significant productivity gains. Follow the recommendations in this guide to ensure optimal performance at scale.
