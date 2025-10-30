# ⚡ Performance Guide

This guide provides comprehensive performance optimization strategies for BetterModel concerns. Learn about indexing, query optimization, caching, and best practices to keep your application fast even with complex model behaviors.

## Table of Contents

- [Overview](#overview)
- [Database Indexing](#database-indexing)
  - [Core Indexes](#core-indexes)
  - [Compound Indexes](#compound-indexes)
  - [Concern-Specific Indexes](#concern-specific-indexes)
- [Query Optimization](#query-optimization)
  - [N+1 Query Prevention](#n1-query-prevention)
  - [Eager Loading](#eager-loading)
  - [Select Optimization](#select-optimization)
  - [Batch Processing](#batch-processing)
- [Concern-Specific Optimizations](#concern-specific-optimizations)
  - [Predicable Performance](#predicable-performance)
  - [Sortable Performance](#sortable-performance)
  - [Searchable Performance](#searchable-performance)
  - [Traceable Performance](#traceable-performance)
  - [Stateable Performance](#stateable-performance)
  - [Archivable Performance](#archivable-performance)
- [Caching Strategies](#caching-strategies)
- [Data Volume Management](#data-volume-management)
- [Database-Specific Optimizations](#database-specific-optimizations)
- [Monitoring and Profiling](#monitoring-and-profiling)
- [Real-world Benchmarks](#real-world-benchmarks)
- [Best Practices](#best-practices)

## Overview

BetterModel concerns are designed for performance, but proper configuration is essential:

**Key Performance Principles:**
1. **Index Strategically** - Index columns used in WHERE, JOIN, ORDER BY
2. **Eager Load Associations** - Prevent N+1 queries
3. **Select Only Needed Columns** - Reduce data transfer
4. **Batch Process Large Datasets** - Avoid memory bloat
5. **Cache Derived Data** - Reduce computation
6. **Monitor Query Performance** - Identify bottlenecks

## Database Indexing

### Core Indexes

Every BetterModel application should have these essential indexes:

```ruby
class AddBetterModelIndexes < ActiveRecord::Migration[8.1]
  def change
    # Primary key (automatic)
    # add_index :articles, :id

    # Timestamps (common queries)
    add_index :articles, :created_at
    add_index :articles, :updated_at

    # Foreign keys (associations)
    add_index :articles, :author_id
    add_index :articles, :category_id

    # Status columns
    add_index :articles, :status
    add_index :articles, :published_at
  end
end
```

### Compound Indexes

Optimize multi-condition queries with compound indexes:

```ruby
class AddCompoundIndexes < ActiveRecord::Migration[8.1]
  def change
    # Archivable + State queries
    add_index :orders, [:archived_at, :state]

    # User + Date range queries
    add_index :orders, [:customer_id, :created_at]

    # State + Status queries
    add_index :orders, [:state, :payment_status]

    # Polymorphic associations
    add_index :versions, [:item_type, :item_id]
    add_index :state_transitions, [:transitionable_type, :transitionable_id]
  end
end
```

**Index Order Matters:**

```ruby
# ✅ Good: Index order matches query
add_index :orders, [:customer_id, :created_at]

Order.where(customer_id: 123).where("created_at > ?", 1.week.ago)
# Uses index efficiently

# ❌ Bad: Index order doesn't match
add_index :orders, [:created_at, :customer_id]

Order.where(customer_id: 123).where("created_at > ?", 1.week.ago)
# May not use index optimally
```

### Concern-Specific Indexes

#### Archivable

```ruby
# Essential
add_index :articles, :archived_at

# Compound with other fields
add_index :articles, [:archived_at, :status]
add_index :articles, [:archived_at, :author_id]

# Tracking fields (if using with_by, with_reason)
add_index :articles, :archive_by_id
```

#### Stateable

```ruby
# Essential
add_index :orders, :state

# State transitions table
create_table :state_transitions do |t|
  t.string :transitionable_type
  t.bigint :transitionable_id
  t.string :event
  t.string :from_state
  t.string :to_state
  t.json :metadata
  t.timestamps
end

add_index :state_transitions, [:transitionable_type, :transitionable_id], name: 'index_state_transitions_on_transitionable'
add_index :state_transitions, :event
add_index :state_transitions, :created_at
add_index :state_transitions, [:transitionable_type, :transitionable_id, :created_at], name: 'index_state_transitions_composite'
```

#### Traceable

```ruby
# Versions table
create_table :article_versions do |t|
  t.string :item_type
  t.bigint :item_id
  t.string :event
  t.jsonb :object_changes  # PostgreSQL: use jsonb
  t.bigint :updated_by_id
  t.string :updated_reason
  t.timestamps
end

# Essential indexes
add_index :article_versions, [:item_type, :item_id]
add_index :article_versions, :updated_by_id
add_index :article_versions, :created_at
add_index :article_versions, [:item_type, :item_id, :created_at], name: 'index_versions_composite'

# PostgreSQL: GIN index for JSONB
add_index :article_versions, :object_changes, using: :gin
```

#### Predicable

Index columns used in predicates:

```ruby
# String predicates
add_index :articles, :title
add_index :articles, :status

# Numeric predicates
add_index :orders, :total_amount

# DateTime predicates
add_index :articles, :published_at
add_index :orders, :shipped_at

# Boolean predicates
add_index :articles, :featured

# Case-insensitive (PostgreSQL)
add_index :articles, "LOWER(title)"
add_index :articles, "LOWER(author_email)"
```

#### Sortable

Index columns used for sorting:

```ruby
# Common sort fields
add_index :articles, :created_at
add_index :articles, :updated_at
add_index :articles, :published_at
add_index :articles, :view_count

# String sorting (consider case-insensitive)
add_index :articles, :title
add_index :articles, "LOWER(title)"  # PostgreSQL

# Compound for sort + filter
add_index :articles, [:status, :created_at]
add_index :articles, [:author_id, :published_at]
```

## Query Optimization

### N+1 Query Prevention

**Problem:**

```ruby
# N+1 query problem
articles = Article.limit(10)

articles.each do |article|
  puts article.versions.count         # N queries for versions
  puts article.state_transitions.count # N queries for transitions
  puts article.author.name            # N queries for author
end

# Total: 1 + (10 * 3) = 31 queries
```

**Solution:**

```ruby
# Eager load associations
articles = Article.includes(:versions, :state_transitions, :author).limit(10)

articles.each do |article|
  puts article.versions.count         # No extra query
  puts article.state_transitions.count # No extra query
  puts article.author.name            # No extra query
end

# Total: 4 queries (articles, versions, transitions, authors)
```

### Eager Loading

#### With Traceable

```ruby
# ❌ Bad: N+1 for audit trail
articles = Article.limit(10)
articles.each { |a| a.audit_trail }
# 1 + 10 queries

# ✅ Good: Eager load versions
articles = Article.includes(:versions).limit(10)
articles.each { |a| a.audit_trail }
# 2 queries
```

#### With Stateable

```ruby
# ❌ Bad: N+1 for transition history
orders = Order.limit(10)
orders.each { |o| o.transition_history }
# 1 + 10 queries

# ✅ Good: Eager load state_transitions
orders = Order.includes(:state_transitions).limit(10)
orders.each { |o| o.transition_history }
# 2 queries
```

#### With Searchable

```ruby
# Searchable includes associations automatically when needed
results = Article.search(
  status_eq: "published",
  order_by: :created_at,
  include: [:author, :category]  # Pass includes to search
)

# Or manually
results = Article.includes(:author, :category)
               .status_eq("published")
               .order_by_created_at_desc
```

### Select Optimization

Only load needed columns:

```ruby
# ❌ Bad: Load all columns
articles = Article.all
# SELECT * FROM articles

# ✅ Good: Select only needed columns
articles = Article.select(:id, :title, :status, :created_at)
# SELECT id, title, status, created_at FROM articles

# With associations
articles = Article.select(:id, :title)
                  .includes(:author)
                  .references(:author)

# For JSON APIs
articles = Article.select(:id, :title, :status)
                  .where(status: "published")
                  .as_json(only: [:id, :title, :status])
```

### Batch Processing

Process large datasets in batches:

```ruby
# ❌ Bad: Load all records in memory
Article.all.each do |article|
  article.update_search_index
end
# Memory: O(n) - can crash with large datasets

# ✅ Good: Batch processing
Article.find_each(batch_size: 1000) do |article|
  article.update_search_index
end
# Memory: O(batch_size)

# With conditions
Article.status_eq("published")
       .find_each(batch_size: 500) do |article|
  article.process
end

# Batch update
Article.in_batches(of: 1000) do |batch|
  batch.update_all(processed: true)
end
```

## Concern-Specific Optimizations

### Predicable Performance

#### Index Predicate Columns

```ruby
# Ensure columns used in predicates are indexed
add_index :articles, :status          # status_eq
add_index :articles, :published_at    # published_at_gt, published_at_lt
add_index :articles, :view_count      # view_count_gteq

# Compound for multiple predicates
add_index :articles, [:status, :published_at]
```

#### Use Specific Predicates

```ruby
# ❌ Slow: Generic _cont predicate (LIKE)
Article.title_cont("Rails")
# SELECT * FROM articles WHERE title LIKE '%Rails%'
# Cannot use index efficiently

# ✅ Fast: Specific predicates when possible
Article.title_start("Rails")
# SELECT * FROM articles WHERE title LIKE 'Rails%'
# Can use index

Article.status_eq("published")
# SELECT * FROM articles WHERE status = 'published'
# Uses index efficiently
```

#### PostgreSQL Full-Text Search

```ruby
# For complex text search, use PostgreSQL full-text
class AddFullTextSearch < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      ALTER TABLE articles
      ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
      ) STORED;
    SQL

    add_index :articles, :search_vector, using: :gin
  end
end

# Use raw SQL for full-text search
Article.where("search_vector @@ to_tsquery('english', ?)", "Rails & guide")
```

### Sortable Performance

#### Index Sort Columns

```ruby
# Ensure sort columns are indexed
add_index :articles, :created_at      # order_by_created_at_desc
add_index :articles, :title           # order_by_title_asc

# For NULLS FIRST/LAST, ensure database supports it
add_index :articles, :published_at
```

#### Avoid Sorting Large Datasets

```ruby
# ❌ Bad: Sort all records then limit
Article.all.order_by_created_at_desc.limit(10)
# Sorts all records, then takes 10

# ✅ Good: Filter first, then sort
Article.status_eq("published")
       .order_by_created_at_desc
       .limit(10)
# Filters first, sorts only matching records
```

#### Case-Insensitive Sorting

```ruby
# PostgreSQL: Use expression index
add_index :articles, "LOWER(title)"

# Then use case-insensitive sort
Article.order_by_title_asc_i
# Uses LOWER(title) index
```

### Searchable Performance

#### Security + Performance

```ruby
# Configure Searchable with limits
class Article < ApplicationRecord
  searchable do
    max_per_page 100          # Prevent large page sizes
    default_order :created_at, :desc
    require_predicates :status_eq  # Ensure filtering
  end
end

# Query with limits
Article.search(
  status_eq: "published",  # Required filter (uses index)
  page: 1,
  per_page: 20             # Reasonable page size
)
```

#### Pagination Efficiency

```ruby
# ✅ Good: Use cursor pagination for large datasets
class Article < ApplicationRecord
  def self.cursor_paginate(cursor: nil, limit: 20)
    query = status_eq("published").order_by_id_asc

    if cursor
      query = query.id_gt(cursor)
    end

    query.limit(limit)
  end
end

# Usage
articles = Article.cursor_paginate(limit: 20)
next_cursor = articles.last.id
articles = Article.cursor_paginate(cursor: next_cursor, limit: 20)
```

### Traceable Performance

#### Limit Version Queries

```ruby
# ❌ Bad: Load all versions
article.versions
# Could be thousands of records

# ✅ Good: Limit versions
article.versions.limit(10).order(created_at: :desc)

# Only recent versions
article.versions.where("created_at > ?", 30.days.ago)

# Only specific events
article.versions.where(event: "updated")
```

#### Archive Old Versions

```ruby
# Periodic cleanup job
class ArchiveOldVersions < ApplicationJob
  def perform
    cutoff = 2.years.ago

    ArticleVersion.where("created_at < ?", cutoff)
                  .find_in_batches(batch_size: 1000) do |batch|
      # Move to archive storage (S3, etc.)
      archive_to_storage(batch)

      # Delete from database
      batch.each(&:destroy)
    end
  end
end
```

#### Selective Tracking

```ruby
# ❌ Bad: Track all fields
traceable do
  track :title, :content, :summary, :meta_description, :keywords, :status, ...
end
# Large object_changes, slow queries

# ✅ Good: Track only critical fields
traceable do
  track :title, :status, :published_at
  # Don't track large text fields
end
```

#### PostgreSQL JSONB Optimization

```ruby
# Use jsonb instead of json
create_table :article_versions do |t|
  t.jsonb :object_changes  # Not json
end

# Add GIN index
add_index :article_versions, :object_changes, using: :gin

# Query efficiently
ArticleVersion.where("object_changes @> ?", {status: ["draft", "published"]}.to_json)
```

### Stateable Performance

#### Minimize Callbacks

```ruby
# ❌ Bad: Heavy computation in callbacks
transition :publish, from: :draft, to: :published do
  after do
    regenerate_all_thumbnails    # Slow
    reindex_search               # Slow
    notify_all_followers         # Slow
  end
end

# ✅ Good: Background jobs for heavy work
transition :publish, from: :draft, to: :published do
  after :enqueue_publish_jobs
end

def enqueue_publish_jobs
  RegenerateThumbnailsJob.perform_later(id)
  ReindexSearchJob.perform_later(id)
  NotifyFollowersJob.perform_later(id)
end
```

#### Cache Guard Evaluations

```ruby
# ❌ Bad: Expensive guard evaluated multiple times
stateable do
  transition :ship, from: :paid, to: :shipped do
    guard { complex_inventory_check }  # Expensive
  end
end

order.can_ship?  # Evaluates guard
order.ship!      # Evaluates guard again

# ✅ Good: Cache guard result
def can_ship_cached?
  @can_ship_cached ||= complex_inventory_check
end

stateable do
  transition :ship, from: :paid, to: :shipped do
    guard :can_ship_cached?
  end
end
```

### Archivable Performance

#### Default Scope Consideration

```ruby
# With default_scope_exclude_archived
archivable do
  default_scope_exclude_archived
end

# All queries automatically filter archived
Article.all
# SELECT * FROM articles WHERE archived_at IS NULL

# Index is essential
add_index :articles, :archived_at

# To include archived (opt-in)
Article.with_archived.all
```

#### Compound Indexes with Archived

```ruby
# Common query pattern
Article.not_archived.where(status: "published").order(created_at: :desc)

# Optimal compound index
add_index :articles, [:archived_at, :status, :created_at]
```

## Caching Strategies

### Statusable Caching

```ruby
# Expensive status computation
class Order < ApplicationRecord
  statusable do
    status :shippable do
      # Expensive computation
      items.all? { |i| i.in_stock? } &&
        shipping_address_valid? &&
        payment_cleared?
    end
  end
end

# ✅ Cache status results
class Order < ApplicationRecord
  def is_shippable?
    Rails.cache.fetch("order:#{id}:shippable", expires_in: 5.minutes) do
      super
    end
  end
end
```

### Query Result Caching

```ruby
# Cache expensive queries
class Article < ApplicationRecord
  def self.published_this_week
    Rails.cache.fetch("articles:published_this_week", expires_in: 1.hour) do
      status_eq("published")
        .published_at_within(1.week)
        .order_by_published_at_desc
        .to_a
    end
  end
end
```

### Fragment Caching

```ruby
# View caching with concern data
<% @articles.each do |article| %>
  <% cache article do %>
    <div class="article">
      <h2><%= article.title %></h2>
      <% if article.can_edit? %>
        <%= link_to "Edit", edit_article_path(article) %>
      <% end %>
    </div>
  <% end %>
<% end %>
```

## Data Volume Management

### Partitioning Large Tables

```ruby
# PostgreSQL: Partition versions table by date
CREATE TABLE article_versions (
  ...
) PARTITION BY RANGE (created_at);

CREATE TABLE article_versions_2024_q1
  PARTITION OF article_versions
  FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE article_versions_2024_q2
  PARTITION OF article_versions
  FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
```

### Retention Policies

```ruby
# Keep only recent versions
class VersionRetentionJob < ApplicationJob
  RETENTION_PERIOD = 1.year
  MAX_VERSIONS_PER_RECORD = 100

  def perform
    # Time-based retention
    cutoff = RETENTION_PERIOD.ago
    ArticleVersion.where("created_at < ?", cutoff).delete_all

    # Count-based retention
    Article.find_each do |article|
      versions = article.versions.order(created_at: :desc)
      versions.offset(MAX_VERSIONS_PER_RECORD).destroy_all
    end
  end
end
```

## Database-Specific Optimizations

### PostgreSQL

```ruby
# Use JSONB for better performance
create_table :versions do |t|
  t.jsonb :object_changes  # Not json
end

# GIN indexes for JSONB
add_index :versions, :object_changes, using: :gin

# Expression indexes
add_index :articles, "LOWER(title)"

# Partial indexes
add_index :articles, :published_at, where: "archived_at IS NULL"

# ANALYZE for query planning
execute "ANALYZE articles"
```

### MySQL

```ruby
# Use appropriate index types
add_index :articles, :title, type: :fulltext

# Optimize JSON queries (5.7+)
add_index :versions, :object_changes, type: :json

# Use covering indexes
add_index :articles, [:status, :published_at, :title]
```

### SQLite

```ruby
# Enable WAL mode for better concurrency
execute "PRAGMA journal_mode=WAL"

# Increase cache size
execute "PRAGMA cache_size=-64000"  # 64MB

# Analyze tables regularly
execute "ANALYZE"
```

## Monitoring and Profiling

### Query Analysis

```ruby
# Log slow queries
# config/environments/development.rb
config.active_record.verbose_query_logs = true

# Use explain
Article.status_eq("published")
       .order_by_created_at_desc
       .explain

# Bullet gem for N+1 detection
# Gemfile
gem 'bullet', group: :development

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
end
```

### Query Benchmarking

```ruby
# Benchmark different approaches
require 'benchmark'

Benchmark.bm do |x|
  x.report("Without index:") do
    Article.where("LOWER(title) LIKE ?", "%rails%").count
  end

  x.report("With index:") do
    Article.title_i_cont("rails").count
  end
end
```

### APM Tools

- **New Relic** - Transaction tracing, slow query detection
- **Skylight** - Rails-specific performance monitoring
- **Scout APM** - Query performance tracking
- **DataDog** - Infrastructure and application monitoring

## Real-world Benchmarks

### Predicable Performance

```ruby
# Dataset: 100,000 articles
# Indexed: status, created_at

# Simple predicate (indexed)
Benchmark.measure { Article.status_eq("published").count }
# => 0.003s (uses index)

# Multiple predicates (compound index)
Benchmark.measure { Article.status_eq("published").created_at_gt(1.month.ago).count }
# => 0.005s (uses compound index)

# LIKE predicate (no index)
Benchmark.measure { Article.title_cont("Rails").count }
# => 1.2s (full table scan)
```

### Traceable Performance

```ruby
# Dataset: 10,000 articles, 100,000 versions

# Without eager loading
Benchmark.measure do
  Article.limit(100).each { |a| a.audit_trail }
end
# => 5.2s (101 queries)

# With eager loading
Benchmark.measure do
  Article.includes(:versions).limit(100).each { |a| a.audit_trail }
end
# => 0.3s (2 queries)
```

## Best Practices

### ✅ Do

- **Index foreign keys** - All `_id` columns
- **Index datetime columns** - Used in range queries
- **Use compound indexes** - For multi-condition queries
- **Eager load associations** - Prevent N+1 queries
- **Batch process large datasets** - Use `find_each`
- **Cache expensive computations** - Status checks, complex queries
- **Monitor query performance** - Use APM tools
- **Set query timeouts** - Prevent runaway queries
- **Archive old data** - Move to cold storage
- **Use database-specific features** - JSONB, full-text search

### ❌ Don't

- **Don't skip indexes** - On foreign keys, state columns
- **Don't load unnecessary data** - Use `select` to limit columns
- **Don't forget to eager load** - Associations used in loops
- **Don't sort without filtering** - Filter first, then sort
- **Don't use wildcards at start** - `LIKE '%term'` can't use index
- **Don't keep unlimited versions** - Implement retention policy
- **Don't ignore query plans** - Use `EXPLAIN` to understand queries
- **Don't over-index** - Too many indexes slow writes
- **Don't cache forever** - Set reasonable expiration times

---

**Related Documentation:**
- [Integration Guide](integration_guide.md) - Combining multiple concerns efficiently
- [Migration Guide](migration_guide.md) - Adding indexes during migrations
- Individual concern docs for feature-specific optimizations

**Performance Checklist:**

- [ ] All foreign keys indexed
- [ ] State/status columns indexed
- [ ] Compound indexes for common queries
- [ ] Versions/transitions tables indexed
- [ ] Eager loading configured for associations
- [ ] Batch processing for large datasets
- [ ] Query timeouts configured
- [ ] APM tool installed and monitoring
- [ ] Retention policy for audit data
- [ ] Database vacuuming/optimization scheduled
