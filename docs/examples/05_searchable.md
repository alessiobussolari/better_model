# Searchable Examples

Searchable provides a unified interface for filtering, sorting, and pagination—perfect for building search UIs and API endpoints.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Simple Search](#example-1-simple-search)
- [Example 2: Search with Sorting](#example-2-search-with-sorting)
- [Example 3: Search with Pagination](#example-3-search-with-pagination)
- [Example 4: OR Conditions](#example-4-or-conditions)
- [Example 5: Complex Search Queries](#example-5-complex-search-queries)
- [Example 6: Building Search UIs](#example-6-building-search-uis)
- [Eager Loading Associations](#eager-loading-associations)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Model
class Article < ApplicationRecord
  include BetterModel

  # Predicates and sort must be defined first
  predicates :title, :status, :view_count, :published_at, :featured
  sort :title, :view_count, :published_at

  # Configure searchable
  searchable do
    default_order [:sort_published_at_desc]
    per_page 25
    max_per_page 100
  end
end
```

## Example 1: Simple Search

```ruby
# Search with predicates
results = Article.search({
  status_eq: "published",
  featured_true: true
})

results.pluck(:title)
# => ["Featured Article 1", "Featured Article 2"]

# Empty predicates returns all
Article.search({}).count == Article.count
# => true

# Single predicate
Article.search({ status_eq: "draft" })
# => All draft articles

# Multiple predicates (AND logic)
Article.search({
  status_eq: "published",
  view_count_gteq: 100
})
# => Published articles with 100+ views
```

**Output Explanation**: `search` accepts a hash of predicate scopes and chains them with AND logic.

## Example 2: Search with Sorting

```ruby
# Default sort (from searchable configuration)
Article.search({
  status_eq: "published"
})
# => Uses :published_at_desc from config

# Override default order
Article.search(
  { status_eq: "published" },
  orders: [:sort_view_count_desc]
)
# => Published articles sorted by view count

# Multiple sorts via array
Article.search(
  { status_eq: "published" },
  orders: [:sort_status_asc, :sort_view_count_desc]
)
# => Sorted by status, then view count

# No sorting (override default)
Article.search(
  { status_eq: "published" },
  orders: []
)
# => Natural database order (or uses default_order if configured)
```

**Output Explanation**: Orders parameter accepts array of sort scope symbols.

## Example 3: Search with Pagination

```ruby
# With pagination
result = Article.search(
  { status_eq: "published" },
  pagination: { page: 1, per_page: 10 }
)

result.pluck(:title)
# => First 10 published articles

# Pagination metadata
result.current_page  # => 1
result.total_pages   # => 5 (if 50 total results)
result.total_count   # => 50
result.per_page      # => 10

# Next page
result = Article.search(
  { status_eq: "published" },
  pagination: { page: 2, per_page: 10 }
)
# => Articles 11-20

# Use default per_page from config
result = Article.search(
  { status_eq: "published" },
  pagination: { page: 1 }
)
# => Uses per_page: 25 from config
```

**Output Explanation**: Pagination returns enriched ActiveRecord::Relation with metadata methods.

## Example 4: OR Conditions

```ruby
# OR logic for same field
results = Article.search({
  or: [
    { status_eq: "published" },
    { status_eq: "featured" }
  ]
})
# => SQL: WHERE (status = 'published' OR status = 'featured')

# OR across different fields
results = Article.search({
  or: [
    { status_eq: "draft" },
    { view_count_gteq: 1000 }
  ]
})
# => Drafts OR articles with 1000+ views

# Combining AND and OR
results = Article.search({
  featured_true: true,  # AND
  or: [
    { status_eq: "published" },
    { status_eq: "archived" }
  ]
})
# => Featured articles that are (published OR archived)
```

**Output Explanation**: Use `or` key with array of predicate hashes for OR logic.

## Example 5: Complex Search Queries

```ruby
# Kitchen sink example
results = Article.search(
  {
    # AND conditions
    featured_true: true,
    view_count_gteq: 50,
    published_at_within: 30.days,

    # OR conditions
    or: [
      { status_eq: "published" },
      { status_eq: "scheduled" }
    ]
  },
  orders: [:sort_featured_desc, :sort_view_count_desc],
  pagination: { page: 1, per_page: 20 }
)

# Generated SQL equivalent:
# SELECT * FROM articles
# WHERE featured = true
#   AND view_count >= 50
#   AND published_at >= '30 days ago'
#   AND (status = 'published' OR status = 'scheduled')
# ORDER BY featured DESC, view_count DESC
# LIMIT 20 OFFSET 0

results.pluck(:title, :status, :view_count, :featured)
# => [[title, status, count, featured], ...]
```

**Output Explanation**: Complex queries remain readable and maintainable.

## Example 6: Building Search UIs

### Rails Controller Example

```ruby
class ArticlesController < ApplicationController
  def index
    @results = Article.search(
      search_params,
      orders: parse_sort_param,
      pagination: {
        page: params[:page] || 1,
        per_page: params[:per_page] || 25
      }
    )
  end

  private

  def search_params
    params.fetch(:search, {}).permit(
      :status_eq,
      :title_cont,
      :view_count_gteq,
      :view_count_lteq,
      :published_at_within,
      :featured_true,
      or: [
        :status_eq,
        :featured_true
      ]
    )
  end

  def parse_sort_param
    return nil unless params[:sort].present?

    case params[:sort]
    when "newest" then [:sort_published_at_desc]
    when "oldest" then [:sort_published_at_asc]
    when "popular" then [:sort_view_count_desc]
    when "title" then [:sort_title_asc]
    else nil  # Use default_order
    end
  end
end
```

### API Response Example

```ruby
class Api::ArticlesController < ApplicationController
  def index
    results = Article.search(
      search_predicates,
      orders: sort_param,
      pagination: pagination_params
    )

    render json: {
      data: results.as_json(only: [:id, :title, :status, :view_count]),
      meta: {
        current_page: results.current_page,
        total_pages: results.total_pages,
        total_count: results.total_count,
        per_page: results.per_page
      }
    }
  end

  private

  def search_predicates
    params.fetch(:filters, {}).permit(
      :status_eq, :title_cont, :featured_true
    ).to_h.symbolize_keys
  end

  def sort_param
    allowed_sorts = %i[
      sort_title_asc sort_title_desc
      sort_view_count_asc sort_view_count_desc
      sort_published_at_asc sort_published_at_desc
    ]

    sort = params[:sort]&.to_sym
    allowed_sorts.include?(sort) ? [sort] : [:sort_published_at_desc]
  end

  def pagination_params
    {
      page: params[:page] || 1,
      per_page: [params[:per_page]&.to_i || 25, 100].min
    }
  end
end

# Example API request:
# GET /api/articles?filters[status_eq]=published&sort=sort_view_count_desc&page=1

# Response:
# {
#   "data": [
#     {"id": 1, "title": "Top Article", "status": "published", "view_count": 500},
#     {"id": 2, "title": "Second", "status": "published", "view_count": 300}
#   ],
#   "meta": {
#     "current_page": 1,
#     "total_pages": 4,
#     "total_count": 87,
#     "per_page": 25
#   }
# }
```

### Search Form Example

```erb
<!-- app/views/articles/index.html.erb -->
<%= form_with url: articles_path, method: :get, local: true do |f| %>
  <div class="filters">
    <%= f.text_field "search[title_cont]", placeholder: "Search by title" %>

    <%= f.select "search[status_eq]",
        options_for_select(["published", "draft", "archived"], params.dig(:search, :status_eq)),
        { include_blank: "All Statuses" } %>

    <%= f.number_field "search[view_count_gteq]", placeholder: "Min views" %>

    <%= f.check_box "search[featured_true]", {}, "true", nil %>
    <%= f.label "search[featured_true]", "Featured only" %>
  </div>

  <div class="sorting">
    <%= f.select :sort,
        options_for_select([
          ["Newest First", "published_at_desc"],
          ["Oldest First", "published_at_asc"],
          ["Most Views", "view_count_desc"],
          ["Least Views", "view_count_asc"],
          ["Title A-Z", "title_asc"],
          ["Title Z-A", "title_desc"]
        ], params[:sort]) %>
  </div>

  <%= f.submit "Search" %>
<% end %>

<!-- Results -->
<div class="results">
  <% @results.each do |article| %>
    <div class="article">
      <h3><%= article.title %></h3>
      <p><%= article.status %> | <%= article.view_count %> views</p>
    </div>
  <% end %>
</div>

<!-- Pagination -->
<%= paginate @results %>
```

## Eager Loading Associations

Optimize N+1 queries with built-in support for `includes:`, `preload:`, and `eager_load:` parameters:

### Basic Usage

```ruby
# Single association (always use array syntax for consistency)
Article.search(
  { status_eq: "published" },
  includes: [:author]
)

# Multiple associations
Article.search(
  { status_eq: "published" },
  includes: [:author, :comments],
  preload: [:tags]
)
```

### Nested Associations

```ruby
# Simple nested
Article.search(
  { status_eq: "published" },
  includes: [{ author: :profile }]
)

# Complex nested mix
Article.search(
  { status_eq: "published" },
  includes: [
    :tags,                          # Direct association
    { author: :profile },           # Nested: author -> profile
    { comments: [:user, :likes] }   # Multiple nested
  ]
)
```

### Combined with Search Features

```ruby
# Full-featured search with eager loading
Article.search(
  {
    status_eq: "published",
    view_count_gteq: 100
  },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_view_count_desc],
  includes: [:author, { comments: :user }],
  preload: [:tags]
)
```

### Loading Strategies

| Strategy | Parameter | Behavior | Use When |
|----------|-----------|----------|----------|
| **Smart Load** | `includes:` | Uses LEFT OUTER JOIN or separate queries based on context | Default choice, best for most cases |
| **Separate Queries** | `preload:` | Always uses separate queries (one per association) | Avoiding JOIN complexity or ambiguous columns |
| **Force JOIN** | `eager_load:` | Always uses LEFT OUTER JOIN | Need to filter/order by association columns |

**⚠️ Important Note**: When using `eager_load:` with `default_order`, you may encounter "ambiguous column" errors if both tables have the same column names (e.g., `created_at`). In such cases, use `includes:` or `preload:` instead, or chain `.eager_load()` after search for full control.

## Tips & Best Practices

### 1. Always Validate Sort Parameters
```ruby
# Bad: Allows SQL injection
sort_param = params[:sort]
Article.search({}, orders: [sort_param&.to_sym])

# Good: Whitelist allowed sorts
ALLOWED_SORTS = %i[sort_title_asc sort_title_desc sort_view_count_desc sort_published_at_desc]
sort_param = params[:sort]&.to_sym
orders = ALLOWED_SORTS.include?(sort_param) ? [sort_param] : nil
Article.search({}, orders: orders)
```

### 2. Set Reasonable Defaults
```ruby
class Article < ApplicationRecord
  searchable do
    default_order [:sort_published_at_desc]  # Sensible default
    per_page 25                              # Default items per page
    max_per_page 100                         # Prevent abuse
  end
end
```

### 3. Use Strong Parameters
```ruby
def search_params
  params.fetch(:search, {}).permit(
    # Whitelist only searchable predicates
    :status_eq,
    :title_cont,
    :view_count_gteq,
    # etc.
  )
end
```

### 4. Cache Expensive Searches
```ruby
# Cache search results
def index
  cache_key = "articles_search_#{search_params.to_json}_#{params[:page]}"

  @results = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
    Article.search(
      search_params,
      orders: sort_param,
      pagination: pagination_params
    ).to_a  # Convert to array for caching
  end
end
```

### 5. Combine with Background Jobs
```ruby
# For expensive exports
class ArticleExportJob < ApplicationJob
  def perform(search_params, user_id)
    articles = Article.search(search_params, pagination: nil)

    csv = generate_csv(articles)

    UserMailer.search_export(user_id, csv).deliver_now
  end
end

# In controller
def export
  ArticleExportJob.perform_later(search_params, current_user.id)
  redirect_to articles_path, notice: "Export will be emailed shortly"
end
```

## Related Documentation

- [Main README](../../README.md#searchable) - Full Searchable documentation
- [Predicable Examples](03_predicable.md) - Available predicates
- [Sortable Examples](04_sortable.md) - Sorting options
- [Test File](../../test/better_model/searchable_test.rb) - Complete test coverage

---

[← Sortable Examples](04_sortable.md) | [Back to Examples Index](README.md) | [Next: Archivable Examples →](06_archivable.md)
