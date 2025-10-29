## Searchable - Unified Search Interface

Searchable orchestrates **Predicable** and **Sortable** into a powerful, unified search interface with built-in pagination, OR conditions, security enforcement, and DoS protection.

### Overview

Instead of manually chaining predicate scopes and sort scopes, Searchable provides a single `search()` method that handles:
- **Filtering** with predicate scopes (AND logic)
- **OR Conditions** for complex logic
- **Sorting** with multiple sort scopes
- **Pagination** with configurable limits
- **Security** enforcement of required predicates
- **Validation** of all parameters

**Key Benefits:**
- Unified API reduces controller complexity
- Built-in security with required predicates
- DoS protection (max_per_page limits)
- Strong parameters integration
- Type-safe validation
- Chainable with standard ActiveRecord

### Configuration

Use the `searchable` DSL block to configure search behavior:

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at, :created_at
  sort :title, :view_count, :published_at, :created_at

  searchable do
    # Pagination settings
    per_page 25              # Default items per page
    max_per_page 100         # Maximum items per page (DoS protection)

    # Default ordering
    default_order [:sort_published_at_desc, :sort_created_at_desc]

    # Security rules (required predicates)
    security :status_required, [:status_eq]
    security :featured_only, [:featured_true]
  end
end
```

### Search Method Signature

```ruby
Model.search(predicates = {}, pagination: {}, orders: [], security: nil)
```

**Parameters:**
- `predicates` (Hash): Predicate scopes with values (e.g., `{ status_eq: "published", view_count_gt: 100 }`)
- `pagination` (Hash, optional): `{ page: 1, per_page: 25 }`
- `orders` (Array<Symbol>, optional): Sort scopes (e.g., `[:sort_title_asc, :sort_published_at_desc]`)
- `security` (Symbol, optional): Security rule name to enforce

**Returns:**
- `ActiveRecord::Relation` - Chainable with other ActiveRecord methods

### Basic Usage

#### Simple Search

```ruby
# Search without parameters (returns all, with default_order if configured)
Article.search({})

# Search with single predicate
Article.search({ status_eq: "published" })

# Search with multiple predicates (AND logic)
Article.search({
  status_eq: "published",
  view_count_gteq: 100,
  published_at_gt: 1.week.ago
})
```

#### Search with Pagination

```ruby
# Basic pagination
Article.search(
  { status_eq: "published" },
  pagination: { page: 1, per_page: 25 }
)

# Pagination without per_page (no LIMIT applied, only OFFSET)
Article.search(
  { status_eq: "published" },
  pagination: { page: 2 }  # Only page specified
)

# Respects max_per_page limit
Article.search(
  { status_eq: "published" },
  pagination: { page: 1, per_page: 500 }  # Will be capped at max_per_page (100)
)
```

#### Search with Sorting

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

# Without explicit orders, uses default_order from configuration
Article.search({ status_eq: "published" })
# Applies default_order: [:sort_published_at_desc]
```

#### Combined Search

```ruby
# Full-featured search
Article.search(
  {
    status_eq: "published",
    title_cont: "Rails",
    view_count_between: [50, 200]
  },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_published_at_desc, :sort_view_count_desc]
)
```

### OR Conditions

Use the special `:or` key to specify OR conditions alongside AND predicates:

```ruby
# Simple OR
Article.search(
  or: [
    { title_cont: "Ruby" },
    { title_cont: "Rails" }
  ]
)
# SQL: WHERE (title LIKE '%Ruby%' OR title LIKE '%Rails%')

# OR with AND predicates
Article.search(
  {
    or: [
      { view_count_gt: 100 },
      { featured_true: true }
    ],
    status_eq: "published"  # AND condition
  }
)
# SQL: WHERE ((view_count > 100 OR featured = true) AND status = 'published')

# Multiple conditions in OR
Article.search(
  or: [
    { status_eq: "published", view_count_gt: 100 },
    { status_eq: "draft", featured_true: true }
  ]
)
# SQL: WHERE ((status = 'published' AND view_count > 100) OR (status = 'draft' AND featured = true))
```

**Notes on OR:**
- OR conditions are combined with AND predicates using SQL AND logic
- Empty/nil values in OR conditions are skipped (same as AND predicates)
- OR conditions are validated same as AND predicates

### Security Enforcement

Define security rules that require specific predicates to be present with valid values:

```ruby
class Article < ApplicationRecord
  searchable do
    security :status_required, [:status_eq]
    security :tenant_scope, [:tenant_id_eq]
    security :multi_required, [:status_eq, :tenant_id_eq]
  end
end

# Valid - required predicate present
Article.search(
  { status_eq: "published", title_cont: "Rails" },
  security: :status_required
)

# Raises InvalidSecurityError - required predicate missing
Article.search(
  { title_cont: "Rails" },
  security: :status_required
)

# Raises InvalidSecurityError - required predicate has nil value
Article.search(
  { status_eq: nil },
  security: :status_required
)

# Raises InvalidSecurityError - required predicate has empty value
Article.search(
  { status_eq: "" },
  security: :status_required
)
```

**Security Validation:**
- Required predicates must be present in the predicates hash
- Values must not be `nil`
- Values must not be empty (for strings/arrays/hashes)
- `false` is considered a valid value
- Unknown security names raise `InvalidSecurityError`

### Rails Controller Integration

```ruby
class ArticlesController < ApplicationController
  def index
    # Strong parameters
    search_params = params.permit(:title_cont, :status_eq, :view_count_gteq, :page, :per_page)

    @articles = Article.search(
      search_params.except(:page, :per_page).to_h,
      pagination: {
        page: search_params[:page] || 1,
        per_page: search_params[:per_page] || 25
      },
      orders: [:sort_published_at_desc]
    )

    # Still chainable
    @articles = @articles.includes(:author, :comments)

    render json: {
      articles: @articles.as_json,
      page: search_params[:page],
      per_page: @articles.limit_value
    }
  end
end
```

### Configuration Options

#### Pagination Configuration

```ruby
searchable do
  per_page 25          # Default items per page (optional)
  max_per_page 100     # Maximum items per page (required for DoS protection)
end
```

- `per_page`: Default value when pagination[:per_page] not specified
- `max_per_page`: Hard limit capping pagination[:per_page] value
- If `per_page` not in config and not in params, no LIMIT is applied

#### Order Configuration

```ruby
searchable do
  default_order [:sort_published_at_desc, :sort_created_at_desc]
end
```

- `default_order`: Applied when `orders:` parameter not specified
- Accepts array of sort scope symbols
- Overridden completely by `orders:` parameter (not merged)

#### Security Configuration

```ruby
searchable do
  security :name, [:required_predicate_1, :required_predicate_2]
end
```

- Define multiple security rules
- Each rule has a name and list of required predicates
- Applied via `security:` parameter in search call

### Instance Methods

#### search_metadata

Returns metadata about available search options:

```ruby
article = Article.new
metadata = article.search_metadata

# Returns:
{
  searchable_fields: [:title, :status, :view_count, ...],
  sortable_fields: [:title, :view_count, :published_at, ...],
  available_predicates: {
    title: [:eq, :not_eq, :cont, :i_cont, ...],
    status: [:eq, :not_eq, :in, ...],
    view_count: [:eq, :gt, :gteq, :lt, :lteq, :between, ...]
  },
  available_sorts: {
    title: [:sort_title_asc, :sort_title_desc, :sort_title_asc_i, :sort_title_desc_i],
    view_count: [:sort_view_count_asc, :sort_view_count_desc]
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
- Validate search parameters

### Class Methods

#### searchable_field?(field_name)

```ruby
Article.searchable_field?(:title)       # => true
Article.searchable_field?(:nonexistent) # => false
```

#### searchable_fields

```ruby
Article.searchable_fields
# => Set[:title, :status, :view_count, :published_at, ...]
```

#### searchable_predicates_for(field_name)

```ruby
Article.searchable_predicates_for(:title)
# => [:eq, :not_eq, :cont, :i_cont, :start, :end, ...]
```

#### searchable_sorts_for(field_name)

```ruby
Article.searchable_sorts_for(:title)
# => [:sort_title_asc, :sort_title_desc, :sort_title_asc_i, :sort_title_desc_i]
```

### Error Handling

#### InvalidPredicateError

Raised when using non-existent predicate scope:

```ruby
Article.search({ nonexistent_predicate: "value" })
# Raises: BetterModel::Searchable::InvalidPredicateError
#   Invalid predicate scope: nonexistent_predicate
#   Available predicable scopes: title_eq, title_cont, status_eq, ...
```

#### InvalidOrderError

Raised when using non-existent sort scope:

```ruby
Article.search({}, orders: [:nonexistent_sort])
# Raises: BetterModel::Searchable::InvalidOrderError
#   Invalid order scope: nonexistent_sort
#   Available sortable scopes: sort_title_asc, sort_view_count_desc, ...
```

#### InvalidPaginationError

Raised for invalid pagination parameters:

```ruby
# page must be >= 1
Article.search({}, pagination: { page: 0 })
# Raises: BetterModel::Searchable::InvalidPaginationError: page must be >= 1

# per_page must be >= 1
Article.search({}, pagination: { page: 1, per_page: 0 })
# Raises: BetterModel::Searchable::InvalidPaginationError: per_page must be >= 1
```

#### InvalidSecurityError

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
#   Security :status_required requires the following predicates with valid values: status_eq
#   These predicates must be present and have non-blank values in the search parameters.
```

### Real-World Examples

#### Blog Article Search

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      search_params.to_h,
      pagination: pagination_params,
      orders: order_params
    )
  end

  private

  def search_params
    params.permit(:title_cont, :status_eq, :category_id_eq, :published_at_gteq)
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

#### E-commerce Product Search

```ruby
class ProductsController < ApplicationController
  def search
    @products = Product.search(
      build_search_predicates,
      pagination: { page: params[:page], per_page: 24 },
      orders: [:sort_popularity_desc, :sort_price_asc]
    )

    render json: {
      products: @products.as_json(include: :images),
      total_count: @products.count,
      page: params[:page],
      facets: build_facets(@products)
    }
  end

  private

  def build_search_predicates
    predicates = {}

    predicates[:name_i_cont] = params[:q] if params[:q].present?
    predicates[:category_id_eq] = params[:category] if params[:category].present?
    predicates[:price_between] = [params[:min_price], params[:max_price]] if price_range_present?
    predicates[:in_stock_true] = true if params[:in_stock] == "1"

    predicates
  end
end
```

### Best Practices

#### Use Strong Parameters

Always use Rails strong parameters to sanitize input:

```ruby
# Good
search_params = params.permit(:title_cont, :status_eq).to_h
Article.search(search_params)

# Bad - opens security vulnerability
Article.search(params.to_unsafe_h)
```

#### Leverage Security Rules

For multi-tenant apps, always enforce tenant scoping:

```ruby
class Document < ApplicationRecord
  searchable do
    security :tenant_required, [:tenant_id_eq]
  end
end

# In controller
def index
  @documents = Document.search(
    search_params.merge(tenant_id_eq: current_tenant.id),
    security: :tenant_required
  )
end
```

#### Use Default Order

Configure sensible defaults to avoid forgotten sorting:

```ruby
searchable do
  default_order [:sort_created_at_desc]
end
```

#### Limit max_per_page

Always configure `max_per_page` to prevent DoS:

```ruby
searchable do
  max_per_page 100  # Prevents users from requesting 1M records
end
```

#### Chain with Eager Loading

Search returns regular ActiveRecord::Relation, so chain freely:

```ruby
Article.search(predicates, pagination: pagination, orders: orders)
       .includes(:author, :comments)
       .preload(:tags)
```

### Thread Safety

**Guaranteed thread-safe:**
- All configuration frozen at class load time
- `searchable_config` is immutable frozen Hash
- No mutable shared state
- Safe for concurrent requests

### Performance Considerations

**Query Efficiency:**
- Search builds single SQL query (no N+1)
- Predicates use indexed columns when available
- OR conditions use SQL OR (efficient with proper indexes)
- Pagination uses LIMIT/OFFSET

**Recommendations:**
- Add indexes on frequently filtered columns
- Add composite indexes for common filter combinations
- Use `includes`/`preload` for associations
- Consider caching for expensive searches

**Index Examples:**
```ruby
add_index :articles, :status
add_index :articles, :published_at
add_index :articles, [:status, :published_at]  # Composite for common combo
```

