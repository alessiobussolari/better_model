# BetterModel Performance Guide

Key performance considerations and optimization tips.

## General Rules

1. **Only include needed modules** - Each module adds scopes at load time
2. **Always paginate** - Never return unlimited results
3. **Index filtered/sorted columns** - Critical for query performance
4. **Use strict mode in dev** - Catches issues early

## Module-Specific Tips

### Predicable

```ruby
# Good - specific fields only
predicates :title, :status, :published_at

# Memory: ~10-15 scopes per field

# Fast (with index)
Article.status_eq("published")

# Slower (LIKE queries)
Article.title_cont("Rails")  # LIKE '%Rails%'

# Faster LIKE
Article.title_start("Rails")  # LIKE 'Rails%'
```

### Sortable

```ruby
# Good
sort :title, :published_at

# Memory: 4-6 scopes per field

# NULL handling varies by DB:
# - PostgreSQL/SQLite: native NULLS LAST
# - MySQL: emulated with CASE
```

### Searchable

```ruby
# Always paginate
Article.search(
  { status_eq: "published" },
  page: 1,
  per_page: 25
)

# Configure max globally
BetterModel.configure do |config|
  config.searchable_max_per_page = 100
end
```

### Archivable

```ruby
# Default scope adds WHERE clause
archivable do
  skip_archived_by_default true  # Adds: WHERE archived_at IS NULL
end

# Use unscoped when needed
Article.unscoped.find(id)
```

### Traceable

```ruby
# Track only essential fields
traceable do
  track :title, :status, :content
  ignore :view_count, :updated_at  # Skip frequently changing
end

# Limit version history loads
article.versions.limit(20)  # Not article.versions.to_a
```

### Stateable

```ruby
# Keep checks lightweight
transition :publish, from: :draft, to: :published do
  # Good - attribute check
  check { content.present? }

  # Avoid - expensive query
  # check { Article.published.count < 1000 }
end
```

### Taggable (PostgreSQL)

```ruby
# Requires GIN index
# CREATE INDEX idx_articles_tags ON articles USING GIN (tags)

# Contains (uses index)
Article.tags_contains("ruby")

# For large datasets, consider counter cache
```

## Required Indexes

```ruby
# migration
class AddBetterModelIndexes < ActiveRecord::Migration[7.0]
  def change
    # Predicable/Searchable
    add_index :articles, :status
    add_index :articles, :published_at

    # Sortable
    add_index :articles, :created_at

    # Archivable
    add_index :articles, :archived_at

    # Stateable
    add_index :articles, :state
    add_index :state_transitions, [:transitionable_type, :transitionable_id]

    # Traceable
    add_index :article_versions, [:article_id, :created_at]

    # Taggable (PostgreSQL)
    execute "CREATE INDEX idx_articles_tags ON articles USING GIN (tags)"

    # Composite for common searches
    add_index :articles, [:status, :published_at]
  end
end
```

## Query Optimization

```ruby
# Use includes for associations
Article.search(status_eq: "published")
       .includes(:author)

# Batch processing
Article.archived.find_each(batch_size: 1000) do |article|
  article.restore!
end

# Pluck for simple data
Article.search(status_eq: "published").pluck(:title)
```

## Memory Tips

```ruby
# Scopes are lazy (no query until needed)
scope = Article.status_eq("published").sort_title_asc
# Query executes here:
scope.to_a

# Limit version history
article.versions.limit(20)
article.versions.where("created_at > ?", 1.month.ago)
```

## Caching

```ruby
# Cache search results
@articles = Rails.cache.fetch("articles/#{search_params}/#{page}", expires_in: 5.minutes) do
  Article.search(search_params, page: page).to_a
end

# Cache tag stats
def popular_tags
  Rails.cache.fetch("articles/popular_tags", expires_in: 1.hour) do
    Article.popular_tags(limit: 20)
  end
end
```

## Checklist

- [ ] Index all filterable columns
- [ ] Index all sortable columns
- [ ] Index state/archive columns
- [ ] Configure max_per_page
- [ ] Track only essential fields (Traceable)
- [ ] Use pagination everywhere
- [ ] Cache expensive operations
- [ ] Enable strict_mode in development
