# Searchable - Unified Search Interface

## Overview

Searchable is a powerful orchestrator that unifies **Predicable** (filtering), **Sortable** (ordering), and **pagination** into a single, cohesive search interface. Instead of manually chaining predicate scopes and sort scopes, Searchable provides one `search()` method that handles everything with built-in validation, security enforcement, and DoS protection.

**Core Capabilities:**
- **Unified API** - Single method for filtering, sorting, and pagination
- **Predicable orchestration** - Uses predicate scopes for filtering (AND logic by default)
- **Sortable orchestration** - Uses sort scopes for ordering with fallback to defaults
- **OR conditions** - Complex boolean logic with the special `:or` key
- **Security enforcement** - Require specific predicates with valid values
- **Pagination** - Built-in with configurable limits and DoS protection
- **Association eager loading** - Prevent N+1 queries with `includes:`, `preload:`, `eager_load:`
- **Validation** - Type-safe parameter validation with helpful error messages
- **Chainable** - Returns `ActiveRecord::Relation` for further chaining
- **Thread-safe** - Immutable configuration frozen at class load time

**Requirements:**
- **Predicable** must be configured (defines filterable fields)
- **Sortable** must be configured (defines orderable fields)
- **Searchable** configuration block (pagination, security, defaults)

---

## Basic Concepts

### The Orchestration Pattern

Searchable doesn't define its own filtering or sorting. Instead, it **orchestrates** the features you've already configured:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Step 1: Define predicable fields (filtering capabilities)
  predicates :title, :content, :status, :view_count, :published_at, :created_at

  # Step 2: Define sortable fields (ordering capabilities)
  sort :title, :view_count, :published_at, :created_at

  # Step 3: Configure searchable (orchestration layer)
  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc, :sort_created_at_desc]
    security :status_required, [:status_eq]
  end
end
```

**What happens behind the scenes:**

```ruby
# Manual approach (without Searchable):
Article.title_cont("Rails")
       .status_eq("published")
       .view_count_gt(100)
       .sort_published_at_desc
       .sort_view_count_desc
       .page(1)
       .per(25)

# Searchable approach (orchestrated):
Article.search(
  { title_cont: "Rails", status_eq: "published", view_count_gt: 100 },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_published_at_desc, :sort_view_count_desc]
)
```

Both produce the same result, but Searchable adds:
- Parameter validation
- Security enforcement
- DoS protection
- Consistent interface
- Error handling

### When to Use Searchable

✅ **Use when:**
- Building search interfaces (web forms, APIs)
- Need security enforcement (multi-tenant, role-based access)
- Want unified interface across controllers
- Need parameter validation
- Building public-facing search features

⚠️ **Consider alternatives when:**
- Simple one-off queries in service objects
- Administrative tools where security isn't a concern
- Performance-critical paths needing full control

---

## Configuration

### Configuration DSL

Use the `searchable` block to configure search behavior:

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at, :created_at
  sort :title, :view_count, :published_at, :created_at

  searchable do
    # Pagination settings
    per_page 25              # Default items per page
    max_per_page 100         # Maximum items per page (DoS protection)
    max_page 1000            # Maximum page number (DoS protection)

    # Default ordering (array of sort scopes)
    default_order [:sort_published_at_desc, :sort_created_at_desc]

    # Security rules (name => required predicates)
    security :status_required, [:status_eq]
    security :published_only, [:published_at_present]
    security :tenant_scope, [:tenant_id_eq, :status_eq]

    # DoS protection limits
    max_predicates 20        # Max predicates per search
    max_or_conditions 5      # Max OR condition groups
  end
end
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `per_page` | Integer | nil | Default records per page (optional) |
| `max_per_page` | Integer | required | Maximum allowed per_page (DoS protection) |
| `max_page` | Integer | nil | Maximum page number (DoS protection) |
| `default_order` | Array<Symbol> | nil | Default sort scopes when `orders:` not specified |
| `security` | Hash | {} | Security rules: `name, [required_predicates]` |
| `max_predicates` | Integer | nil | Maximum predicates per search (DoS protection) |
| `max_or_conditions` | Integer | nil | Maximum OR groups (DoS protection) |

---

## Search Method Signature

```ruby
Model.search(
  predicates = {},
  pagination: {},
  orders: [],
  security: nil,
  includes: nil,
  preload: nil,
  eager_load: nil
)
```

### Parameters

**`predicates`** (Hash, default: `{}`)
- Predicate scopes with their values
- Key: predicate scope name (Symbol)
- Value: predicate value (any type)
- Example: `{ status_eq: "published", view_count_gt: 100 }`
- Special key `:or` for OR conditions (Array of predicate hashes)

**`pagination:`** (Hash, optional)
- `page` (Integer): Page number (≥ 1)
- `per_page` (Integer): Records per page (≥ 1, capped at `max_per_page`)
- Example: `{ page: 1, per_page: 25 }`
- If omitted: no pagination applied (uses `per_page` from config if present)

**`orders:`** (Array<Symbol>, optional)
- Array of sort scope names
- Applied in order (primary → secondary → tertiary)
- Example: `[:sort_published_at_desc, :sort_view_count_desc]`
- If omitted: uses `default_order` from configuration

**`security:`** (Symbol, optional)
- Security rule name to enforce
- Must match a rule defined in `searchable` configuration
- Validates required predicates are present with valid values
- Example: `:status_required`

**`includes:`** (Array/Hash, optional)
- Associations to eager load (smart strategy)
- Uses LEFT OUTER JOIN or separate queries based on context
- Example: `[:author, { comments: :user }]`

**`preload:`** (Array/Hash, optional)
- Associations to eager load (separate queries)
- Always uses separate queries for each association
- Example: `[:tags, :categories]`

**`eager_load:`** (Array/Hash, optional)
- Associations to eager load (forced JOIN)
- Always uses LEFT OUTER JOIN
- Example: `[:author]`

### Return Value

**Returns:** `ActiveRecord::Relation`
- Chainable with other ActiveRecord methods
- Can call `.count`, `.pluck`, `.to_a`, `.includes()`, etc.
- Lazy evaluation (query not executed until needed)

---

## Basic Usage

### Simple Search

```ruby
# Empty search (all records, with default_order if configured)
Article.search({})

# Single predicate
Article.search({ status_eq: "published" })

# Multiple predicates (AND logic)
Article.search({
  status_eq: "published",
  view_count_gteq: 100,
  published_at_gt: 1.week.ago
})
```

### Search with Pagination

```ruby
# Basic pagination
Article.search(
  { status_eq: "published" },
  pagination: { page: 1, per_page: 25 }
)
# SQL: ... LIMIT 25 OFFSET 0

# Page 2
Article.search(
  { status_eq: "published" },
  pagination: { page: 2, per_page: 25 }
)
# SQL: ... LIMIT 25 OFFSET 25

# Only page specified (no LIMIT, only OFFSET)
Article.search(
  { status_eq: "published" },
  pagination: { page: 2 }
)
# SQL: ... OFFSET 25 (no LIMIT)

# Respects max_per_page cap
Article.search(
  { status_eq: "published" },
  pagination: { page: 1, per_page: 500 }
)
# If max_per_page is 100: LIMIT 100 (capped)
```

### Search with Sorting

```ruby
# Single sort scope
Article.search(
  { status_eq: "published" },
  orders: [:sort_published_at_desc]
)

# Multiple sort scopes (applied in order)
Article.search(
  { status_eq: "published" },
  orders: [:sort_view_count_desc, :sort_title_asc]
)
# ORDER BY view_count DESC, title ASC

# No orders specified: uses default_order from config
Article.search({ status_eq: "published" })
# Uses: default_order [:sort_published_at_desc, :sort_created_at_desc]
```

### Combined Search

Full-featured search with all options:

```ruby
Article.search(
  {
    status_eq: "published",
    title_cont: "Rails",
    view_count_between: [50, 200],
    published_at_gteq: 1.month.ago
  },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_published_at_desc, :sort_view_count_desc]
)
```

### Chainability

Since `search()` returns an `ActiveRecord::Relation`, you can chain:

```ruby
# Chain with ActiveRecord methods
articles = Article.search({ status_eq: "published" })
                  .includes(:author)
                  .limit(10)

# Chain with Predicable scopes
articles = Article.search({ status_eq: "published" })
                  .view_count_gt(100)  # Additional predicate

# Chain with Sortable scopes
articles = Article.search({ status_eq: "published" })
                  .sort_title_asc

# Get count
count = Article.search({ status_eq: "published" }).count

# Pluck values
titles = Article.search({ status_eq: "published" }).pluck(:title)
```

---

## OR Conditions

Use the special `:or` key to specify OR conditions alongside AND predicates.

### Basic OR

```ruby
# Simple OR: title contains "Ruby" OR "Rails"
Article.search(
  or: [
    { title_cont: "Ruby" },
    { title_cont: "Rails" }
  ]
)
# SQL: WHERE (title LIKE '%Ruby%' OR title LIKE '%Rails%')
```

### OR with AND Predicates

OR conditions are combined with AND predicates using SQL AND logic:

```ruby
# (High views OR featured) AND published
Article.search(
  {
    or: [
      { view_count_gt: 100 },
      { featured_eq: true }
    ],
    status_eq: "published"  # AND condition
  }
)
# SQL: WHERE ((view_count > 100 OR featured = true) AND status = 'published')
```

### Complex OR Conditions

Each OR group can contain multiple predicates (AND within the group):

```ruby
# (Published with high views) OR (draft and featured)
Article.search(
  or: [
    { status_eq: "published", view_count_gt: 100 },
    { status_eq: "draft", featured_eq: true }
  ]
)
# SQL: WHERE ((status = 'published' AND view_count > 100)
#             OR (status = 'draft' AND featured = true))
```

### Multiple OR Groups

```ruby
# Complex: (Ruby OR Rails in title) AND (high views OR featured) AND published
Article.search(
  {
    or: [
      { title_cont: "Ruby" },
      { title_cont: "Rails" }
    ],
    or_views_or_featured: [
      { view_count_gt: 100 },
      { featured_eq: true }
    ],
    status_eq: "published"
  }
)
```

### OR Validation Rules

- Empty/nil values in OR conditions are skipped (same as AND predicates)
- OR conditions are validated same as AND predicates (must be valid predicate scopes)
- Raises `InvalidPredicateError` for unknown predicates
- Respects `max_or_conditions` limit (if configured)

---

## Security Enforcement

Define security rules that require specific predicates to be present with valid values.

### Defining Security Rules

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :tenant_id, :author_id
  sort :title, :created_at

  searchable do
    # Single required predicate
    security :status_required, [:status_eq]

    # Multiple required predicates (all must be present)
    security :tenant_scope, [:tenant_id_eq, :status_eq]

    # Alternative rule
    security :published_only, [:published_at_present]
  end
end
```

### Using Security Rules

```ruby
# Valid: required predicate present with value
Article.search(
  { status_eq: "published", title_cont: "Rails" },
  security: :status_required
)
# ✅ OK - status_eq is present

# Invalid: required predicate missing
Article.search(
  { title_cont: "Rails" },
  security: :status_required
)
# ❌ Raises: BetterModel::Searchable::InvalidSecurityError
#    Security :status_required requires: status_eq

# Invalid: required predicate has nil value
Article.search(
  { status_eq: nil, title_cont: "Rails" },
  security: :status_required
)
# ❌ Raises: InvalidSecurityError - nil not allowed

# Invalid: required predicate has empty string
Article.search(
  { status_eq: "", title_cont: "Rails" },
  security: :status_required
)
# ❌ Raises: InvalidSecurityError - empty string not allowed
```

### Security Validation Rules

**Required predicates must:**
- Be present in the predicates hash
- Have non-nil values
- Have non-empty values (for strings/arrays/hashes)
- `false` is considered valid (boolean predicates)

**Error cases:**
- Unknown security name → `InvalidSecurityError`
- Missing required predicate → `InvalidSecurityError`
- Predicate with nil value → `InvalidSecurityError`
- Predicate with empty value → `InvalidSecurityError`

### Multi-Tenant Security Example

```ruby
class Document < ApplicationRecord
  include BetterModel

  predicates :title, :content, :tenant_id, :status
  sort :title, :created_at

  searchable do
    security :tenant_required, [:tenant_id_eq]
  end
end

# Controller enforces tenant scoping
class DocumentsController < ApplicationController
  def index
    @documents = Document.search(
      search_params.merge(tenant_id_eq: current_tenant.id),
      pagination: pagination_params,
      security: :tenant_required  # Enforces tenant_id_eq
    )
  end
end
```

---

## Association Eager Loading

Optimize N+1 queries with built-in support for association loading strategies.

### Basic Eager Loading

```ruby
# Single association
Article.search(
  { status_eq: "published" },
  includes: [:author]
)

# Multiple associations
Article.search(
  { status_eq: "published" },
  includes: [:author, :comments, :tags]
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
    :tags,                        # Direct association
    { author: :profile },         # Nested: author → profile
    { comments: [:user, :likes] } # Multiple nested
  ]
)
```

### Loading Strategies

| Strategy | Parameter | SQL Approach | Use When |
|----------|-----------|--------------|----------|
| **Smart Load** | `includes:` | LEFT OUTER JOIN or separate queries (context-dependent) | Default choice, best for most cases |
| **Separate Queries** | `preload:` | Always uses separate queries (one per association) | Avoiding JOIN complexity, large result sets |
| **Forced JOIN** | `eager_load:` | Always uses LEFT OUTER JOIN | Need to filter/order by association columns |

```ruby
# Smart loading (recommended)
Article.search(
  { status_eq: "published" },
  includes: [:author, :comments]
)
# ActiveRecord chooses: JOIN or separate queries

# Forced separate queries
Article.search(
  { status_eq: "published" },
  preload: [:author, :comments]
)
# Always: 3 queries (articles, authors, comments)

# Forced JOIN
Article.search(
  { status_eq: "published" },
  eager_load: [:author]
)
# Always: LEFT OUTER JOIN
```

### Combined with Other Features

```ruby
# Full-featured search with eager loading
Article.search(
  {
    status_eq: "published",
    view_count_gteq: 100,
    published_at_within: 7.days
  },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_view_count_desc, :sort_title_asc],
  includes: [:author, { comments: :user }],
  preload: [:tags, :categories]
)
```

### Important Notes

**⚠️ Ambiguous Columns with eager_load:**

When using `eager_load:` with `default_order`, you may encounter "ambiguous column" errors if both tables have columns with the same name (e.g., `created_at`):

```ruby
# This might raise: "ambiguous column: created_at"
Article.search(
  { status_eq: "published" },
  eager_load: [:author]  # Both articles and authors have created_at
)
# default_order includes :sort_created_at_desc
```

**Solutions:**
1. Use `includes:` or `preload:` instead (recommended)
2. Override `orders:` with explicit scopes
3. Chain `.eager_load()` after search for full control
4. Fully qualify column names in sort scopes

**✅ Best Practices:**
- Always use array syntax (`[:author]`) even for single associations
- Prefer `includes:` for most cases (smart strategy)
- Use `preload:` to avoid ambiguous column issues
- Use `eager_load:` only when filtering/ordering by association columns

---

## Controller Integration

### Basic Controller Pattern

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      search_params,
      pagination: pagination_params,
      orders: order_params
    )

    respond_to do |format|
      format.html
      format.json { render json: @articles }
    end
  end

  private

  def search_params
    params.permit(:title_cont, :status_eq, :view_count_gteq, :published_at_gteq).to_h
  end

  def pagination_params
    {
      page: params[:page] || 1,
      per_page: params[:per_page] || 25
    }
  end

  def order_params
    return [:sort_published_at_desc] unless params[:sort]

    case params[:sort]
    when "newest" then [:sort_published_at_desc]
    when "oldest" then [:sort_published_at_asc]
    when "popular" then [:sort_view_count_desc]
    when "title" then [:sort_title_asc]
    else [:sort_published_at_desc]
    end
  end
end
```

### With Security Enforcement

```ruby
class DocumentsController < ApplicationController
  def index
    @documents = Document.search(
      search_params.merge(tenant_id_eq: current_tenant.id),
      pagination: pagination_params,
      security: :tenant_required
    )
  rescue BetterModel::Searchable::InvalidSecurityError => e
    render json: { error: e.message }, status: :forbidden
  end

  private

  def search_params
    params.permit(:title_cont, :status_eq).to_h
  end
end
```

### API Controller with Error Handling

```ruby
class Api::V1::ArticlesController < Api::BaseController
  def index
    @articles = Article.search(
      build_search_predicates,
      pagination: pagination_params,
      orders: order_params,
      includes: [:author],
      preload: [:tags]
    )

    render json: {
      articles: @articles.as_json(include: [:author, :tags]),
      pagination: {
        current_page: params[:page].to_i,
        per_page: @articles.limit_value,
        total_count: @articles.total_count
      }
    }
  rescue BetterModel::Searchable::InvalidPredicateError => e
    render json: { error: "Invalid filter", details: e.message }, status: :bad_request
  rescue BetterModel::Searchable::InvalidOrderError => e
    render json: { error: "Invalid sort", details: e.message }, status: :bad_request
  rescue BetterModel::Searchable::InvalidPaginationError => e
    render json: { error: "Invalid pagination", details: e.message }, status: :bad_request
  end

  private

  def build_search_predicates
    predicates = {}
    predicates[:title_cont] = params[:q] if params[:q].present?
    predicates[:status_eq] = params[:status] if params[:status].present?
    predicates[:view_count_gteq] = params[:min_views] if params[:min_views].present?
    predicates
  end

  def pagination_params
    {
      page: params[:page] || 1,
      per_page: [params[:per_page].to_i, 50].min
    }
  end

  def order_params
    params[:sort_by].present? ? [params[:sort_by].to_sym] : [:sort_published_at_desc]
  end
end
```

---

## Introspection Methods

### Class Methods

#### `searchable_field?(field_name)`

Check if a field is searchable:

```ruby
Article.searchable_field?(:title)       # => true
Article.searchable_field?(:nonexistent) # => false
```

#### `searchable_fields`

Get all searchable fields (predicable fields):

```ruby
Article.searchable_fields
# => #<Set: {:title, :status, :view_count, :published_at, :created_at}>
```

#### `searchable_predicates_for(field_name)`

Get available predicates for a specific field:

```ruby
Article.searchable_predicates_for(:title)
# => [:title_eq, :title_not_eq, :title_cont, :title_i_cont, :title_start,
#     :title_end, :title_not_cont, :title_not_i_cont, :title_matches,
#     :title_in, :title_not_in, :title_present, :title_blank, :title_null]

Article.searchable_predicates_for(:view_count)
# => [:view_count_eq, :view_count_not_eq, :view_count_lt, :view_count_lteq,
#     :view_count_gt, :view_count_gteq, :view_count_between,
#     :view_count_not_between, :view_count_in, :view_count_not_in, ...]
```

#### `searchable_sorts_for(field_name)`

Get available sort scopes for a specific field:

```ruby
Article.searchable_sorts_for(:title)
# => [:sort_title_asc, :sort_title_desc, :sort_title_asc_i, :sort_title_desc_i]

Article.searchable_sorts_for(:published_at)
# => [:sort_published_at_asc, :sort_published_at_desc,
#     :sort_published_at_newest, :sort_published_at_oldest,
#     :sort_published_at_asc_nulls_last, :sort_published_at_desc_nulls_last]
```

### Instance Methods

#### `search_metadata`

Get comprehensive metadata about available search options:

```ruby
article = Article.first
metadata = article.search_metadata

# Returns Hash:
{
  searchable_fields: [:title, :status, :view_count, :published_at, :created_at],
  sortable_fields: [:title, :view_count, :published_at, :created_at],
  available_predicates: {
    title: [:title_eq, :title_cont, :title_i_cont, ...],
    status: [:status_eq, :status_not_eq, :status_in, ...],
    view_count: [:view_count_eq, :view_count_gt, :view_count_between, ...]
  },
  available_sorts: {
    title: [:sort_title_asc, :sort_title_desc, :sort_title_asc_i, :sort_title_desc_i],
    view_count: [:sort_view_count_asc, :sort_view_count_desc, ...]
  },
  pagination: {
    per_page: 25,
    max_per_page: 100
  }
}
```

**Use cases:**
- Build dynamic search forms
- Generate API documentation
- Validate search parameters from external sources
- Provide auto-complete suggestions

---

## Error Handling

Searchable provides specific error classes for different failure scenarios.

### `InvalidPredicateError`

Raised when using a non-existent predicate scope:

```ruby
Article.search({ nonexistent_predicate: "value" })
# Raises: BetterModel::Searchable::InvalidPredicateError
#   Invalid predicate scope: nonexistent_predicate
#   Available predicable scopes: title_eq, title_cont, status_eq, ...

# Handling:
begin
  Article.search(params)
rescue BetterModel::Searchable::InvalidPredicateError => e
  render json: { error: "Invalid filter: #{e.message}" }, status: :bad_request
end
```

### `InvalidOrderError`

Raised when using a non-existent sort scope:

```ruby
Article.search({}, orders: [:nonexistent_sort])
# Raises: BetterModel::Searchable::InvalidOrderError
#   Invalid order scope: nonexistent_sort
#   Available sortable scopes: sort_title_asc, sort_view_count_desc, ...

# Handling:
begin
  Article.search({}, orders: params[:orders])
rescue BetterModel::Searchable::InvalidOrderError => e
  render json: { error: "Invalid sort: #{e.message}" }, status: :bad_request
end
```

### `InvalidPaginationError`

Raised for invalid pagination parameters:

```ruby
# page must be >= 1
Article.search({}, pagination: { page: 0 })
# Raises: BetterModel::Searchable::InvalidPaginationError
#   page must be >= 1

# per_page must be >= 1
Article.search({}, pagination: { page: 1, per_page: 0 })
# Raises: BetterModel::Searchable::InvalidPaginationError
#   per_page must be >= 1

# Handling:
begin
  Article.search({}, pagination: { page: params[:page], per_page: params[:per_page] })
rescue BetterModel::Searchable::InvalidPaginationError => e
  render json: { error: "Invalid pagination: #{e.message}" }, status: :bad_request
end
```

### `InvalidSecurityError`

Raised for security violations:

```ruby
# Unknown security name
Article.search({}, security: :nonexistent)
# Raises: BetterModel::Searchable::InvalidSecurityError
#   Unknown security: nonexistent
#   Available securities: status_required, tenant_scope

# Missing required predicate
Article.search({ title_cont: "Test" }, security: :status_required)
# Raises: BetterModel::Searchable::InvalidSecurityError
#   Security :status_required requires: status_eq
#   These predicates must be present and have non-blank values.

# Handling:
begin
  Article.search(params, security: :status_required)
rescue BetterModel::Searchable::InvalidSecurityError => e
  render json: { error: "Security violation: #{e.message}" }, status: :forbidden
end
```

### Error Handling Best Practices

```ruby
# Comprehensive error handling
def search_articles
  Article.search(
    search_params,
    pagination: pagination_params,
    orders: order_params,
    security: :tenant_required
  )
rescue BetterModel::Searchable::InvalidPredicateError => e
  flash[:error] = "Invalid search filter"
  Article.search({})  # Fallback to empty search
rescue BetterModel::Searchable::InvalidOrderError => e
  # Retry without orders
  Article.search(search_params, pagination: pagination_params)
rescue BetterModel::Searchable::InvalidPaginationError => e
  # Retry with default pagination
  Article.search(search_params, pagination: { page: 1, per_page: 25 })
rescue BetterModel::Searchable::InvalidSecurityError => e
  render json: { error: "Unauthorized" }, status: :forbidden
end
```

---

## Real-World Examples

### Example 1: Blog Article Search with Advanced Filters

Complete blog search with text, status, date range, and view count filtering.

```ruby
class Article < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: "User"
  belongs_to :category

  predicates :title, :content, :status, :view_count, :published_at, :created_at, :category_id
  sort :title, :view_count, :published_at, :created_at

  searchable do
    per_page 25
    max_per_page 100
    max_page 1000
    default_order [:sort_published_at_desc, :sort_created_at_desc]
    max_predicates 10
  end
end

# Controller
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      build_search_predicates,
      pagination: pagination_params,
      orders: order_params,
      includes: [:author, :category]
    )

    @total_count = @articles.count
    @facets = build_facets(@articles)
  end

  private

  def build_search_predicates
    predicates = {}

    # Text search
    predicates[:title_i_cont] = params[:q] if params[:q].present?

    # Status filter
    predicates[:status_eq] = params[:status] if params[:status].present?

    # Category filter
    predicates[:category_id_eq] = params[:category] if params[:category].present?

    # Date range
    if params[:from_date].present? && params[:to_date].present?
      predicates[:published_at_between] = [params[:from_date], params[:to_date]]
    elsif params[:from_date].present?
      predicates[:published_at_gteq] = params[:from_date]
    elsif params[:to_date].present?
      predicates[:published_at_lteq] = params[:to_date]
    end

    # View count range
    predicates[:view_count_gteq] = params[:min_views] if params[:min_views].present?
    predicates[:view_count_lteq] = params[:max_views] if params[:max_views].present?

    predicates
  end

  def pagination_params
    {
      page: params[:page] || 1,
      per_page: params[:per_page] || 25
    }
  end

  def order_params
    return [:sort_published_at_desc] unless params[:sort]

    case params[:sort]
    when "newest"   then [:sort_published_at_desc]
    when "oldest"   then [:sort_published_at_asc]
    when "popular"  then [:sort_view_count_desc, :sort_published_at_desc]
    when "title_az" then [:sort_title_asc_i]
    when "title_za" then [:sort_title_desc_i]
    else [:sort_published_at_desc]
    end
  end

  def build_facets(relation)
    {
      by_status: relation.unscope(:limit, :offset).group(:status).count,
      by_category: relation.unscope(:limit, :offset).group(:category_id).count,
      date_range: {
        oldest: relation.minimum(:published_at),
        newest: relation.maximum(:published_at)
      }
    }
  end
end
```

**View (search form):**
```erb
<%= form_with url: articles_path, method: :get, local: true do |f| %>
  <div class="search-filters">
    <div class="field">
      <%= f.label :q, "Search" %>
      <%= f.text_field :q, value: params[:q], placeholder: "Title..." %>
    </div>

    <div class="field">
      <%= f.label :status, "Status" %>
      <%= f.select :status,
          options_for_select([["All", ""], ["Published", "published"], ["Draft", "draft"]], params[:status]),
          {},
          class: "form-control" %>
    </div>

    <div class="field">
      <%= f.label :category, "Category" %>
      <%= f.collection_select :category, Category.all, :id, :name,
          { include_blank: "All Categories", selected: params[:category] },
          class: "form-control" %>
    </div>

    <div class="field">
      <%= f.label :from_date, "From Date" %>
      <%= f.date_field :from_date, value: params[:from_date] %>
    </div>

    <div class="field">
      <%= f.label :to_date, "To Date" %>
      <%= f.date_field :to_date, value: params[:to_date] %>
    </div>

    <div class="field">
      <%= f.label :min_views, "Min Views" %>
      <%= f.number_field :min_views, value: params[:min_views] %>
    </div>

    <div class="actions">
      <%= f.submit "Search", class: "btn btn-primary" %>
      <%= link_to "Clear", articles_path, class: "btn btn-secondary" %>
    </div>
  </div>
<% end %>

<div class="results">
  <p><%= @total_count %> articles found</p>

  <div class="sort-options">
    <%= link_to "Newest", articles_path(params.permit!.merge(sort: "newest")) %>
    <%= link_to "Popular", articles_path(params.permit!.merge(sort: "popular")) %>
    <%= link_to "Title A-Z", articles_path(params.permit!.merge(sort: "title_az")) %>
  </div>

  <%= render @articles %>

  <%= paginate @articles %>
</div>
```

---

### Example 2: E-commerce Product Search with OR Conditions

Product search with complex OR logic and faceted filtering.

```ruby
class Product < ApplicationRecord
  include BetterModel
  belongs_to :category
  belongs_to :brand
  has_many :reviews

  predicates :name, :sku, :price, :stock, :category_id, :brand_id, :status, :featured
  sort :name, :price, :stock, :created_at

  searchable do
    per_page 24
    max_per_page 96
    default_order [:sort_name_asc_i]
    security :active_only, [:status_eq]
  end
end

# Controller
class ProductsController < ApplicationController
  def search
    @products = Product.search(
      build_search_predicates,
      pagination: { page: params[:page], per_page: 24 },
      orders: order_params,
      includes: [:category, :brand]
    )

    respond_to do |format|
      format.html
      format.json do
        render json: {
          products: @products.as_json(include: [:category, :brand]),
          pagination: pagination_meta,
          facets: build_facets
        }
      end
    end
  end

  private

  def build_search_predicates
    predicates = { status_eq: "active" }  # Always active

    # Text search across name and SKU (OR condition)
    if params[:q].present?
      predicates[:or] = [
        { name_i_cont: params[:q] },
        { sku_cont: params[:q] }
      ]
    end

    # Category filter
    if params[:category_ids].present?
      predicates[:category_id_in] = params[:category_ids]
    end

    # Brand filter
    if params[:brand_ids].present?
      predicates[:brand_id_in] = params[:brand_ids]
    end

    # Price range
    if params[:min_price].present? && params[:max_price].present?
      predicates[:price_between] = [params[:min_price], params[:max_price]]
    elsif params[:min_price].present?
      predicates[:price_gteq] = params[:min_price]
    elsif params[:max_price].present?
      predicates[:price_lteq] = params[:max_price]
    end

    # Stock filter
    predicates[:stock_gt] = 0 if params[:in_stock] == "true"

    # Featured flag
    predicates[:featured_eq] = true if params[:featured] == "true"

    predicates
  end

  def order_params
    case params[:sort]
    when "price_low"  then [:sort_price_asc]
    when "price_high" then [:sort_price_desc]
    when "newest"     then [:sort_created_at_desc]
    when "name_az"    then [:sort_name_asc_i]
    when "name_za"    then [:sort_name_desc_i]
    else [:sort_name_asc_i]
    end
  end

  def pagination_meta
    {
      current_page: params[:page].to_i || 1,
      per_page: 24,
      total_count: @products.total_count,
      total_pages: @products.total_pages
    }
  end

  def build_facets
    base_scope = Product.where(status: "active")
    {
      categories: base_scope.joins(:category).group("categories.name").count,
      brands: base_scope.joins(:brand).group("brands.name").count,
      price_ranges: {
        "under_50" => base_scope.where("price < ?", 50).count,
        "50_100" => base_scope.where("price BETWEEN ? AND ?", 50, 100).count,
        "100_200" => base_scope.where("price BETWEEN ? AND ?", 100, 200).count,
        "over_200" => base_scope.where("price > ?", 200).count
      },
      in_stock: base_scope.where("stock > 0").count
    }
  end
end
```

---

### Example 3: Multi-Tenant Document Search with Security

Comprehensive multi-tenant search with security enforcement.

```ruby
class Document < ApplicationRecord
  include BetterModel
  belongs_to :tenant
  belongs_to :folder
  belongs_to :created_by, class_name: "User"

  predicates :title, :content, :tenant_id, :folder_id, :status, :created_by_id, :created_at
  sort :title, :created_at, :updated_at

  searchable do
    per_page 50
    max_per_page 200
    default_order [:sort_updated_at_desc]

    # Security: always require tenant scoping
    security :tenant_required, [:tenant_id_eq]
    security :tenant_and_status, [:tenant_id_eq, :status_eq]

    # DoS protection
    max_predicates 15
    max_or_conditions 3
  end

  # Validation
  validates :tenant_id, presence: true
end

# Controller
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_tenant

  def index
    @documents = Document.search(
      build_search_predicates,
      pagination: pagination_params,
      orders: order_params,
      security: :tenant_required,
      includes: [:folder, :created_by]
    )

    @folders = current_tenant.folders
    @users = current_tenant.users
  rescue BetterModel::Searchable::InvalidSecurityError => e
    flash[:error] = "Unauthorized access"
    redirect_to root_path
  rescue BetterModel::Searchable::InvalidPredicateError => e
    flash[:error] = "Invalid search parameters"
    @documents = Document.search(
      { tenant_id_eq: current_tenant.id },
      security: :tenant_required
    )
  end

  def export
    @documents = Document.search(
      build_search_predicates,
      security: :tenant_required
    )

    respond_to do |format|
      format.csv do
        send_data generate_csv(@documents), filename: "documents-#{Date.today}.csv"
      end
      format.pdf do
        send_data generate_pdf(@documents), filename: "documents-#{Date.today}.pdf"
      end
    end
  end

  private

  def build_search_predicates
    # CRITICAL: Always include tenant_id (security enforcement)
    predicates = { tenant_id_eq: current_tenant.id }

    # Text search
    if params[:q].present?
      predicates[:or] = [
        { title_i_cont: params[:q] },
        { content_i_cont: params[:q] }
      ]
    end

    # Folder filter
    predicates[:folder_id_eq] = params[:folder_id] if params[:folder_id].present?

    # Status filter
    predicates[:status_eq] = params[:status] if params[:status].present?

    # Created by filter
    predicates[:created_by_id_eq] = params[:created_by] if params[:created_by].present?

    # Date filters
    if params[:date_range] == "today"
      predicates[:created_at_gteq] = Date.today.beginning_of_day
    elsif params[:date_range] == "this_week"
      predicates[:created_at_gteq] = Date.today.beginning_of_week
    elsif params[:date_range] == "this_month"
      predicates[:created_at_gteq] = Date.today.beginning_of_month
    elsif params[:from_date].present?
      predicates[:created_at_gteq] = params[:from_date]
    end

    if params[:to_date].present?
      predicates[:created_at_lteq] = params[:to_date]
    end

    predicates
  end

  def pagination_params
    {
      page: params[:page] || 1,
      per_page: params[:per_page] || 50
    }
  end

  def order_params
    case params[:sort]
    when "title" then [:sort_title_asc_i]
    when "oldest" then [:sort_created_at_asc]
    when "updated" then [:sort_updated_at_desc]
    else [:sort_updated_at_desc]
    end
  end

  def set_current_tenant
    @current_tenant = current_user.tenant
  end

  def generate_csv(documents)
    CSV.generate do |csv|
      csv << ["Title", "Folder", "Status", "Created By", "Created At"]
      documents.each do |doc|
        csv << [doc.title, doc.folder.name, doc.status, doc.created_by.name, doc.created_at]
      end
    end
  end
end
```

### Example 4: Job Board with Complex Criteria

Job listing platform with salary ranges, skills matching, and location filters.

```ruby
class JobListing < ApplicationRecord
  include BetterModel

  belongs_to :company
  belongs_to :location
  has_many :required_skills, dependent: :destroy
  has_many :skills, through: :required_skills

  searchable do
    # Text search fields
    search_fields :title, :description, :company_name

    # Filter fields
    filter_fields :employment_type, :experience_level, :remote_ok, :company_id, :location_id

    # Range fields
    range_fields :salary_min, :salary_max, :posted_at

    # Array field for skills
    array_fields :skill_names

    # Sorting
    sort_fields :posted_at, :salary_max, :title

    # Pagination
    per_page 20
    max_per_page 100

    # Security
    scope -> { where(status: 'published').where('expires_at > ? OR expires_at IS NULL', Date.current) }
  end

  # Virtual attribute for skills array
  def skill_names
    skills.pluck(:name)
  end
end

# Controller
class JobsController < ApplicationController
  def search
    @jobs = JobListing.search(search_params)

    # Additional filters with OR logic
    if params[:remote_or_hybrid].present?
      @jobs = @jobs.where(employment_type: ['remote', 'hybrid'])
    end

    # Skill matching - require ALL skills
    if params[:required_skills].present?
      skill_ids = Skill.where(name: params[:required_skills]).pluck(:id)
      @jobs = @jobs.joins(:required_skills)
                   .where(required_skills: { skill_id: skill_ids })
                   .group('job_listings.id')
                   .having('COUNT(DISTINCT required_skills.skill_id) = ?', skill_ids.count)
    end

    respond_to do |format|
      format.html
      format.json { render json: @jobs }
    end
  end

  private

  def search_params
    params.permit(
      :q,                    # Text search
      :employment_type,       # full_time, part_time, contract
      :experience_level,      # junior, mid, senior
      :remote_ok,            # true/false
      :company_id,
      :location_id,
      :salary_min_gteq,      # Minimum salary at least X
      :salary_max_lteq,      # Maximum salary at most X
      :posted_at_gteq,       # Posted after date
      :sort,
      :page,
      :per_page
    )
  end
end

# Usage Examples

# 1. Simple keyword search
JobListing.search(q: 'ruby developer')
# => Search title, description, company_name for "ruby developer"

# 2. Search with employment type filter
JobListing.search(q: 'engineer', employment_type: 'full_time')
# => Full-time engineering jobs

# 3. Salary range search
JobListing.search(
  salary_min_gteq: 80_000,  # Min salary at least $80k
  salary_max_lteq: 150_000  # Max salary at most $150k
)
# => Jobs paying between $80k-$150k

# 4. Recent postings with remote work
JobListing.search(
  remote_ok: true,
  posted_at_gteq: 7.days.ago,
  sort: 'posted_at_desc'
)
# => Remote jobs posted in last 7 days, newest first

# 5. Experience level filter
JobListing.search(
  q: 'data scientist',
  experience_level: 'senior',
  sort: 'salary_max_desc'
)
# => Senior data scientist jobs, highest salary first

# 6. Pagination
JobListing.search(q: 'developer', page: 2, per_page: 25)
# => Page 2 of results, 25 per page

# 7. Advanced API query
GET /api/v1/jobs?q=backend+engineer&employment_type=full_time&remote_ok=true&salary_min_gteq=100000&sort=posted_at_desc&page=1

# Response
{
  "results": [
    {
      "id": 123,
      "title": "Senior Backend Engineer",
      "company_name": "Tech Corp",
      "salary_range": "$120k-$160k",
      "remote_ok": true,
      "posted_at": "2025-01-10"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 98,
    "per_page": 20
  }
}
```

### Example 5: Real Estate Advanced Property Search

Property search with geo-location, price ranges, and amenities filtering.

```ruby
class Property < ApplicationRecord
  include BetterModel

  belongs_to :neighborhood
  has_many :amenities, dependent: :destroy

  searchable do
    # Text search
    search_fields :address, :description, :neighborhood_name

    # Filters
    filter_fields :property_type, :listing_type, :status, :neighborhood_id

    # Ranges
    range_fields :price, :bedrooms, :bathrooms, :square_feet, :year_built, :lot_size

    # Array for amenities
    array_fields :amenity_names

    # Sorting
    sort_fields :price, :bedrooms, :square_feet, :listed_at, :price_per_sqft

    # Pagination
    per_page 24
    max_per_page 100

    # Only active listings
    scope -> { where(status: 'active') }
  end

  # Virtual attributes
  def neighborhood_name
    neighborhood&.name
  end

  def amenity_names
    amenities.pluck(:name)
  end

  def price_per_sqft
    return 0 if square_feet.to_i.zero?
    (price.to_f / square_feet).round(2)
  end

  # Custom scope for distance search (requires PostGIS)
  scope :within_radius, ->(lat, lng, radius_miles) {
    where(
      "ST_DWithin(
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
        ?
      )",
      lng, lat, radius_miles * 1609.34  # Convert miles to meters
    )
  }
end

# Controller
class PropertiesController < ApplicationController
  def search
    @properties = Property.search(search_params)

    # Geo-location search
    if params[:lat] && params[:lng] && params[:radius]
      @properties = @properties.within_radius(
        params[:lat].to_f,
        params[:lng].to_f,
        params[:radius].to_f
      )
    end

    # Amenities filtering (require ANY of the amenities)
    if params[:amenities].present?
      amenity_ids = Amenity.where(name: params[:amenities]).pluck(:id)
      @properties = @properties.joins(:amenities)
                               .where(amenities: { id: amenity_ids })
                               .distinct
    end

    # Must-have amenities (require ALL)
    if params[:must_have_amenities].present?
      amenity_ids = Amenity.where(name: params[:must_have_amenities]).pluck(:id)
      @properties = @properties.joins(:amenities)
                               .where(amenities: { id: amenity_ids })
                               .group('properties.id')
                               .having('COUNT(DISTINCT amenities.id) = ?', amenity_ids.count)
    end

    # Price per sqft filter
    if params[:max_price_per_sqft].present?
      @properties = @properties.where(
        'price / NULLIF(square_feet, 0) <= ?',
        params[:max_price_per_sqft]
      )
    end

    respond_to do |format|
      format.html
      format.json { render json: property_json }
    end
  end

  private

  def search_params
    params.permit(
      :q,                       # Text search
      :property_type,            # house, condo, townhouse
      :listing_type,             # sale, rent
      :status,
      :neighborhood_id,
      :price_gteq,              # Minimum price
      :price_lteq,              # Maximum price
      :bedrooms_gteq,           # Min bedrooms
      :bathrooms_gteq,          # Min bathrooms
      :square_feet_gteq,        # Min square footage
      :year_built_gteq,         # Built after year
      :lot_size_gteq,           # Min lot size
      :sort,
      :page,
      :per_page
    )
  end
end

# Usage Examples

# 1. Basic keyword search
Property.search(q: 'downtown loft')
# => Search address, description for "downtown loft"

# 2. Price range with bedroom requirement
Property.search(
  price_gteq: 400_000,
  price_lteq: 600_000,
  bedrooms_gteq: 3,
  bathrooms_gteq: 2
)
# => 3+ bed, 2+ bath homes between $400k-$600k

# 3. Property type filter
Property.search(
  property_type: 'house',
  listing_type: 'sale',
  sort: 'price_asc'
)
# => Houses for sale, cheapest first

# 4. Size and lot requirements
Property.search(
  square_feet_gteq: 2000,
  lot_size_gteq: 5000,
  year_built_gteq: 2000
)
# => 2000+ sqft, 5000+ sqft lot, built after 2000

# 5. Recent listings in neighborhood
Property.search(
  neighborhood_id: 123,
  listed_at_gteq: 7.days.ago,
  sort: 'listed_at_desc'
)
# => New listings in specific neighborhood

# 6. Geo-location search
Property.search({}).within_radius(37.7749, -122.4194, 5)
# => Properties within 5 miles of San Francisco

# 7. Complex API query with geo + filters
GET /api/v1/properties?lat=37.7749&lng=-122.4194&radius=10&price_lteq=800000&bedrooms_gteq=2&amenities[]=pool&amenities[]=garage&sort=price_asc

# Response with map view data
{
  "results": [
    {
      "id": 456,
      "address": "123 Main St, San Francisco, CA",
      "price": 750000,
      "bedrooms": 3,
      "bathrooms": 2,
      "square_feet": 1800,
      "price_per_sqft": 417,
      "latitude": 37.7849,
      "longitude": -122.4094,
      "amenities": ["pool", "garage", "fireplace"],
      "distance_miles": 2.3
    }
  ],
  "pagination": { "current_page": 1, "total_count": 15 },
  "filters_applied": {
    "price_range": "$0 - $800,000",
    "min_bedrooms": 2,
    "radius": "10 miles",
    "amenities": ["pool", "garage"]
  }
}
```

### Example 6: Healthcare Provider Directory Search

Medical provider search with specialties, insurance, and availability filtering.

```ruby
class HealthcareProvider < ApplicationRecord
  include BetterModel

  has_many :provider_specialties, dependent: :destroy
  has_many :specialties, through: :provider_specialties
  has_many :provider_insurances, dependent: :destroy
  has_many :accepted_insurances, through: :provider_insurances, source: :insurance
  has_many :office_locations, dependent: :destroy

  searchable do
    # Text search
    search_fields :first_name, :last_name, :credentials, :practice_name, :bio

    # Filters
    filter_fields :provider_type, :gender, :accepting_new_patients, :telehealth_available

    # Arrays
    array_fields :specialty_names, :insurance_names, :language_names

    # Ranges
    range_fields :years_experience, :average_rating

    # Sorting
    sort_fields :last_name, :years_experience, :average_rating, :distance

    # Pagination
    per_page 15
    max_per_page 50

    # Only active providers
    scope -> { where(status: 'active', verified: true) }
  end

  # Virtual attributes
  def specialty_names
    specialties.pluck(:name)
  end

  def insurance_names
    accepted_insurances.pluck(:name)
  end

  def language_names
    (languages || []).map(&:downcase)
  end

  def full_name
    "#{prefix} #{first_name} #{last_name}, #{credentials}".strip
  end

  # Distance scope (requires geocoded addresses)
  scope :near_location, ->(lat, lng, radius_miles) {
    joins(:office_locations).where(
      "ST_DWithin(
        ST_SetSRID(ST_MakePoint(office_locations.longitude, office_locations.latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
        ?
      )",
      lng, lat, radius_miles * 1609.34
    ).distinct
  }
end

# Controller
class ProvidersController < ApplicationController
  def search
    @providers = HealthcareProvider.search(search_params)

    # Specialty filter (require ANY specialty)
    if params[:specialties].present?
      specialty_ids = Specialty.where(name: params[:specialties]).pluck(:id)
      @providers = @providers.joins(:provider_specialties)
                             .where(provider_specialties: { specialty_id: specialty_ids })
                             .distinct
    end

    # Insurance filter (require ANY accepted insurance)
    if params[:insurances].present?
      insurance_ids = Insurance.where(name: params[:insurances]).pluck(:id)
      @providers = @providers.joins(:provider_insurances)
                             .where(provider_insurances: { insurance_id: insurance_ids })
                             .distinct
    end

    # Language filter
    if params[:languages].present?
      language_conditions = params[:languages].map { |lang|
        "languages @> ?::jsonb"
      }.join(' OR ')

      @providers = @providers.where(
        language_conditions,
        *params[:languages].map { |lang| [lang.downcase].to_json }
      )
    end

    # Location-based search
    if params[:lat] && params[:lng]
      radius = (params[:radius] || 25).to_f
      @providers = @providers.near_location(
        params[:lat].to_f,
        params[:lng].to_f,
        radius
      )
    end

    # Availability filter
    if params[:available_within_days].present?
      @providers = @providers.where(
        'next_available_appointment <= ?',
        params[:available_within_days].to_i.days.from_now
      )
    end

    respond_to do |format|
      format.html
      format.json { render json: provider_json }
    end
  end

  private

  def search_params
    params.permit(
      :q,                          # Name or practice search
      :provider_type,               # physician, nurse_practitioner, physician_assistant
      :gender,                      # male, female, non_binary
      :accepting_new_patients,      # true/false
      :telehealth_available,        # true/false
      :years_experience_gteq,       # Minimum experience
      :average_rating_gteq,         # Minimum rating
      :sort,
      :page,
      :per_page
    )
  end
end

# Usage Examples

# 1. Search by name
HealthcareProvider.search(q: 'Dr. Smith')
# => Find providers with "Smith" in name or practice

# 2. Search by specialty
HealthcareProvider.search({}).joins(:specialties).where(specialties: { name: 'Cardiology' })
# => All cardiologists

# 3. Accepting new patients with telehealth
HealthcareProvider.search(
  accepting_new_patients: true,
  telehealth_available: true,
  sort: 'average_rating_desc'
)
# => Providers accepting new patients via telehealth, highest rated first

# 4. Experience and rating filters
HealthcareProvider.search(
  years_experience_gteq: 10,
  average_rating_gteq: 4.5
)
# => Experienced providers (10+ years) with high ratings (4.5+)

# 5. Gender preference
HealthcareProvider.search(
  provider_type: 'physician',
  gender: 'female',
  specialty: 'Obstetrics'
)
# => Female physicians specializing in obstetrics

# 6. Location-based search
HealthcareProvider.search({}).near_location(40.7128, -74.0060, 10)
# => Providers within 10 miles of New York City

# 7. Complex API query
GET /api/v1/providers?q=orthopedic&lat=34.0522&lng=-118.2437&radius=15&insurances[]=Blue+Cross&insurances[]=Aetna&accepting_new_patients=true&telehealth_available=true&sort=distance_asc

# Response with detailed provider info
{
  "results": [
    {
      "id": 789,
      "full_name": "Dr. Jane Smith, MD",
      "provider_type": "physician",
      "specialties": ["Orthopedic Surgery", "Sports Medicine"],
      "practice_name": "City Orthopedics",
      "years_experience": 15,
      "average_rating": 4.8,
      "accepting_new_patients": true,
      "telehealth_available": true,
      "accepted_insurances": ["Blue Cross", "Aetna", "United Healthcare"],
      "languages": ["English", "Spanish"],
      "office_locations": [
        {
          "address": "123 Medical Plaza, Los Angeles, CA",
          "distance_miles": 3.2,
          "phone": "(555) 123-4567"
        }
      ],
      "next_available_appointment": "2025-01-20",
      "profile_url": "/providers/789"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 42
  },
  "filters_applied": {
    "specialty": "Orthopedic Surgery",
    "location": "Los Angeles, CA (15 mile radius)",
    "insurances": ["Blue Cross", "Aetna"],
    "accepting_new_patients": true,
    "telehealth_available": true
  },
  "facets": {
    "specialties": {
      "Orthopedic Surgery": 28,
      "Sports Medicine": 15,
      "Hand Surgery": 8
    },
    "insurances": {
      "Blue Cross": 42,
      "Aetna": 38,
      "United Healthcare": 35
    },
    "gender": {
      "male": 25,
      "female": 17
    }
  }
}

# 8. Advanced filtering with availability
HealthcareProvider.search(
  specialty: 'Primary Care',
  accepting_new_patients: true,
  available_within_days: 7
).near_location(current_user.latitude, current_user.longitude, 5)
# => Primary care doctors accepting new patients, available this week, within 5 miles
```

---

## Best Practices

### 1. Always Use Strong Parameters

Sanitize user input with Rails strong parameters:

```ruby
# ✅ Good: Whitelist allowed predicates
def search_params
  params.permit(:title_cont, :status_eq, :view_count_gteq).to_h
end

Article.search(search_params, ...)

# ❌ Bad: Allows arbitrary predicates (security risk)
Article.search(params.to_unsafe_h, ...)
```

### 2. Leverage Security Rules for Multi-Tenant Apps

Always enforce tenant scoping:

```ruby
# ✅ Good: Security enforced
class Document < ApplicationRecord
  searchable do
    security :tenant_required, [:tenant_id_eq]
  end
end

Document.search(
  { tenant_id_eq: current_tenant.id, ... },
  security: :tenant_required
)

# ❌ Bad: No security enforcement
Document.search({ ... })
```

### 3. Configure max_per_page (DoS Protection)

Always set reasonable limits:

```ruby
# ✅ Good: Prevents excessive queries
searchable do
  max_per_page 100
  max_page 1000
end

# ❌ Bad: No limits (DoS risk)
searchable do
  # Missing max_per_page
end
```

### 4. Use Default Order for Consistency

Provide sensible defaults:

```ruby
# ✅ Good: Consistent ordering
searchable do
  default_order [:sort_created_at_desc, :sort_id_desc]
end

# ⚠️ Acceptable but unpredictable
searchable do
  # No default_order - database order
end
```

### 5. Optimize with Eager Loading

Prevent N+1 queries:

```ruby
# ✅ Good: Eager load associations
Article.search(
  { status_eq: "published" },
  includes: [:author, :comments]
)

# ❌ Bad: N+1 queries
articles = Article.search({ status_eq: "published" })
articles.each { |a| puts a.author.name }  # N queries
```

### 6. Handle Errors Gracefully

Provide user-friendly error messages:

```ruby
# ✅ Good: Specific error handling
begin
  Article.search(params)
rescue BetterModel::Searchable::InvalidPredicateError => e
  render json: { error: "Invalid filter" }, status: :bad_request
rescue BetterModel::Searchable::InvalidSecurityError => e
  render json: { error: "Unauthorized" }, status: :forbidden
end

# ❌ Bad: Generic rescue
begin
  Article.search(params)
rescue => e
  render json: { error: "Something went wrong" }
end
```

### 7. Use Introspection for Dynamic UIs

Build search forms from metadata:

```ruby
# ✅ Good: Dynamic form based on available predicates
metadata = Article.first.search_metadata

metadata[:available_predicates].each do |field, predicates|
  # Generate form fields dynamically
end
```

### 8. Validate Sort Parameters

Map user-friendly names to sort scopes:

```ruby
# ✅ Good: Whitelist approach
ALLOWED_SORTS = {
  "newest" => :sort_published_at_desc,
  "popular" => :sort_view_count_desc,
  "title" => :sort_title_asc
}.freeze

def order_params
  sort_key = params[:sort]
  ALLOWED_SORTS[sort_key] ? [ALLOWED_SORTS[sort_key]] : [:sort_published_at_desc]
end

# ❌ Bad: Direct parameter usage (injection risk)
orders: [params[:sort].to_sym]
```

### 9. Use OR Conditions for Flexible Search

Implement "search any" functionality:

```ruby
# ✅ Good: Search title OR content
Article.search(
  or: [
    { title_i_cont: query },
    { content_i_cont: query }
  ]
)
```

### 10. Chain for Additional Logic

Searchable returns `ActiveRecord::Relation`:

```ruby
# ✅ Good: Chain additional methods
articles = Article.search({ status_eq: "published" })
                  .where.not(author_id: blocked_author_ids)
                  .includes(:tags)
```

---

## Thread Safety

Searchable is designed to be thread-safe for concurrent Rails applications.

### Immutable Configuration

All configuration is frozen at class load time:

```ruby
class Article < ApplicationRecord
  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc]
  end
end

# Configuration is frozen and immutable
Article.searchable_config.frozen?  # => true
```

### No Mutable Shared State

Each search call operates independently:

```ruby
# ✅ Thread-safe: Each operates independently
Thread.new { Article.search({ status_eq: "published" }) }
Thread.new { Article.search({ status_eq: "draft" }) }
Thread.new { Article.search({ view_count_gt: 100 }) }

# No shared mutable state, no race conditions
```

### Stateless Operations

Search method is stateless:

```ruby
# Each call creates new ActiveRecord::Relation
relation1 = Article.search({ status_eq: "published" })
relation2 = Article.search({ status_eq: "draft" })

# Completely independent, no interference
```

---

## Performance Considerations

### Query Efficiency

Searchable generates a single optimized SQL query:

```ruby
# Single query with all predicates
Article.search(
  {
    status_eq: "published",
    view_count_gteq: 100,
    published_at_within: 7.days
  },
  orders: [:sort_published_at_desc],
  pagination: { page: 1, per_page: 25 }
)

# Generated SQL (single query):
# SELECT * FROM articles
# WHERE status = 'published'
#   AND view_count >= 100
#   AND published_at >= '2025-10-29'
# ORDER BY published_at DESC
# LIMIT 25 OFFSET 0
```

### Indexing Recommendations

Add indexes for frequently filtered columns:

```ruby
# Essential indexes
add_index :articles, :status
add_index :articles, :published_at
add_index :articles, :view_count

# Composite indexes for common combinations
add_index :articles, [:status, :published_at]
add_index :articles, [:status, :view_count]

# Partial indexes for specific queries
add_index :articles, :view_count, where: "status = 'published'"
```

### N+1 Query Prevention

Use built-in eager loading:

```ruby
# ✅ Good: 3 queries (articles, authors, comments)
Article.search(
  { status_eq: "published" },
  includes: [:author, :comments]
)

# ❌ Bad: 1 + N queries
articles = Article.search({ status_eq: "published" })
articles.each { |a| puts a.author.name }  # N queries
```

### Caching Strategies

Consider caching for expensive searches:

```ruby
# Fragment caching
<% cache ["articles-search", params[:q], params[:page]] do %>
  <%= render @articles %>
<% end %>

# Low-level caching
articles = Rails.cache.fetch(["articles", search_params], expires_in: 5.minutes) do
  Article.search(search_params, ...)
end
```

### Pagination Best Practices

```ruby
# ✅ Good: Reasonable page size
pagination: { page: 1, per_page: 25 }

# ⚠️ Avoid: Large page sizes (slow)
pagination: { page: 1, per_page: 1000 }

# ✅ Good: Use cursor pagination for large datasets
# (implement custom logic on top of search)
```

---

## Key Takeaways

1. **Orchestrates features** - Searchable unifies Predicable + Sortable + Pagination
2. **Single method API** - Use `search()` for filtering, sorting, and pagination
3. **Security built-in** - Enforce required predicates with security rules
4. **DoS protection** - Configure `max_per_page`, `max_page`, `max_predicates`
5. **OR conditions** - Use special `:or` key for complex boolean logic
6. **Eager loading** - Use `includes:`, `preload:`, `eager_load:` parameters
7. **Strong parameters** - Always sanitize user input with strong parameters
8. **Error handling** - Catch specific error classes for better UX
9. **Introspection** - Use `search_metadata` for dynamic UIs
10. **Chainable** - Returns `ActiveRecord::Relation` for further operations
11. **Thread-safe** - Frozen configuration, no mutable shared state
12. **Performance** - Single SQL query, use indexes, eager load associations
13. **Multi-tenant** - Always enforce tenant scoping with security rules
14. **Validation** - All parameters validated with helpful error messages
15. **Default order** - Configure sensible defaults for consistency
