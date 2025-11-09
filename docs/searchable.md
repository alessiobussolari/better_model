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

**Parameters:**
- `predicates` (Hash): Predicate scopes with values (e.g., `{ status_eq: "published", view_count_gt: 100 }`)
- `pagination` (Hash, optional): `{ page: 1, per_page: 25 }`
- `orders` (Array<Symbol>, optional): Sort scopes (e.g., `[:sort_title_asc, :sort_published_at_desc]`)
- `security` (Symbol, optional): Security rule name to enforce
- `includes` (Array/Hash, optional): Associations to eager load with smart strategy
- `preload` (Array/Hash, optional): Associations to eager load with separate queries
- `eager_load` (Array/Hash, optional): Associations to eager load with LEFT OUTER JOIN

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

Searchable raises specific errors with v3.0.0 Sentry-compatible format. All errors provide attribute access, Sentry-compatible data structures, and detailed context.

#### InvalidPredicateError

Raised when using an invalid predicate in search queries.

**Required parameters:** `predicate_scope:`, **Optional:** `value:`, `available_predicates:`, `model_class:`

**Example:**
```ruby
begin
  Article.search({ title_xxx: "Rails" })
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  # Attribute access
  e.predicate_scope         # => :title_xxx
  e.value                   # => "Rails"
  e.available_predicates    # => [:title_eq, :title_cont, :title_start, ...]
  e.model_class             # => Article

  # Sentry-compatible data
  e.tags                    # => {error_category: 'invalid_predicate', module: 'searchable', predicate: 'title_xxx'}
  e.context                 # => {model_class: 'Article'}
  e.extra                   # => {predicate_scope: :title_xxx, value: 'Rails', available_predicates: [...]}

  # Sentry integration
  Sentry.capture_exception(e) do |scope|
    scope.set_context("error_details", e.context)
    scope.set_tags(e.tags)
    scope.set_extras(e.extra)
  end
end
```

**Methods that raise:** `search`, `apply_predicates`

#### InvalidOrderError

Raised when using an invalid sort scope in search queries.

**Required parameters:** `order_scope:`, **Optional:** `available_sorts:`, `model_class:`

**Example:**
```ruby
begin
  Article.search({}, orders: [:sort_title_xxx])
rescue BetterModel::Errors::Searchable::InvalidOrderError => e
  # Attribute access
  e.order_scope          # => :sort_title_xxx
  e.available_sorts      # => [:sort_title_asc, :sort_title_desc, :sort_view_count_asc, ...]
  e.model_class          # => Article

  # Sentry-compatible data
  e.tags                 # => {error_category: 'invalid_order', module: 'searchable', order_scope: 'sort_title_xxx'}
  e.context              # => {model_class: 'Article'}
  e.extra                # => {order_scope: :sort_title_xxx, available_sorts: [...]}

  # Sentry integration
  Sentry.capture_exception(e) do |scope|
    scope.set_context("error_details", e.context)
    scope.set_tags(e.tags)
    scope.set_extras(e.extra)
  end
end
```

**Methods that raise:** `search`, `apply_orders`

#### InvalidPaginationError

Raised when using invalid pagination parameters.

**Required parameters:** `parameter:`, `value:`, **Optional:** `reason:`

**Example:**
```ruby
begin
  Article.search({}, pagination: { page: 0 })
rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
  # Attribute access
  e.parameter     # => :page
  e.value         # => 0
  e.reason        # => "page must be >= 1"

  # Sentry-compatible data
  e.tags          # => {error_category: 'invalid_pagination', module: 'searchable', parameter: 'page'}
  e.context       # => {parameter: :page, value: 0}
  e.extra         # => {reason: "page must be >= 1"}

  # Sentry integration
  Sentry.capture_exception(e) do |scope|
    scope.set_context("error_details", e.context)
    scope.set_tags(e.tags)
    scope.set_extras(e.extra)
  end
end
```

**Common validation errors:**
- `page must be >= 1` - Page number is less than 1
- `per_page must be >= 1` - Items per page is less than 1

**Methods that raise:** `search`, `validate_pagination`

#### InvalidSecurityError

Raised when security requirements are not met in search queries.

**Required parameters:** `security_name:`, **Optional:** `required_predicates:`, `available_securities:`, `model_class:`

**Example:**
```ruby
begin
  Article.search({ title_cont: "Test" }, security: :status_required)
rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  # Attribute access
  e.security_name           # => :status_required
  e.required_predicates     # => [:status_eq]
  e.available_securities    # => [:status_required, :tenant_scope]
  e.model_class             # => Article

  # Sentry-compatible data
  e.tags                    # => {error_category: 'invalid_security', module: 'searchable', security_name: 'status_required'}
  e.context                 # => {model_class: 'Article', required_predicates: [:status_eq]}
  e.extra                   # => {security_name: :status_required, available_securities: [...]}

  # Sentry integration
  Sentry.capture_exception(e) do |scope|
    scope.set_context("error_details", e.context)
    scope.set_tags(e.tags)
    scope.set_extras(e.extra)
  end
end
```

**Common security violations:**
- Unknown security name
- Missing required predicate
- Required predicate has nil/blank value

**Methods that raise:** `search`, `enforce_security`

## Sentry Integration

Searchable errors are designed to work seamlessly with Sentry for error tracking and monitoring.

### Basic Integration

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(search_params)
  rescue BetterModel::Errors::Searchable::SearchableError => e
    # Automatically capture with full context
    Sentry.capture_exception(e) do |scope|
      scope.set_context("error_details", e.context)
      scope.set_tags(e.tags)
      scope.set_extras(e.extra)

      # Add request context
      scope.set_context("request", {
        controller: controller_name,
        action: action_name,
        params: params.to_unsafe_h
      })
    end

    # Handle gracefully
    @articles = Article.none
    flash[:alert] = "Invalid search parameters"
  end
end
```

### Error Grouping

All Searchable errors include consistent tags for Sentry grouping:

```ruby
# Common tags across all Searchable errors:
{
  error_category: 'invalid_predicate' | 'invalid_order' | 'invalid_pagination' | 'invalid_security',
  module: 'searchable'
}

# Specific tags per error type:
# InvalidPredicateError: { predicate: 'field_name_predicate' }
# InvalidOrderError: { order_scope: 'sort_field_direction' }
# InvalidPaginationError: { parameter: 'page' | 'per_page' }
# InvalidSecurityError: { security_name: 'security_rule_name' }
```

### Production Error Handling

```ruby
class ApplicationController < ActionController::Base
  rescue_from BetterModel::Errors::Searchable::InvalidPredicateError do |e|
    log_and_report_error(e, "Invalid search predicate")
    render json: { error: "Invalid search field" }, status: :bad_request
  end

  rescue_from BetterModel::Errors::Searchable::InvalidOrderError do |e|
    log_and_report_error(e, "Invalid sort field")
    render json: { error: "Invalid sort field" }, status: :bad_request
  end

  rescue_from BetterModel::Errors::Searchable::InvalidPaginationError do |e|
    log_and_report_error(e, "Invalid pagination")
    render json: { error: e.reason }, status: :bad_request
  end

  rescue_from BetterModel::Errors::Searchable::InvalidSecurityError do |e|
    log_and_report_error(e, "Security violation")
    render json: { error: "Access denied" }, status: :forbidden
  end

  private

  def log_and_report_error(exception, message)
    Rails.logger.warn "#{message}: #{exception.message}"
    Sentry.capture_exception(exception) do |scope|
      scope.set_context("error_details", exception.context)
      scope.set_tags(exception.tags)
      scope.set_extras(exception.extra)
      scope.set_user(id: current_user&.id)
    end
  end
end
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

#### Association Eager Loading

Optimize N+1 queries with built-in support for `includes:`, `preload:`, and `eager_load:` parameters:

**Basic Usage:**

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

**Nested Associations:**

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

**Combined with Other Features:**

```ruby
# Full-featured search with eager loading
Article.search(
  {
    status_eq: "published",
    view_count_gteq: 100,
    published_at_within: 7.days
  },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_view_count_desc],
  includes: [:author, { comments: :user }],
  preload: [:tags]
)
```

**Loading Strategies:**

| Strategy | Parameter | Behavior | Use When |
|----------|-----------|----------|----------|
| **Smart Load** | `includes:` | Uses LEFT OUTER JOIN or separate queries based on context | Default choice, best for most cases |
| **Separate Queries** | `preload:` | Always uses separate queries (one per association) | Avoiding JOIN complexity or ambiguous columns |
| **Force JOIN** | `eager_load:` | Always uses LEFT OUTER JOIN | Need to filter/order by association columns |

**⚠️ Important Notes:**

1. **Ambiguous Columns with eager_load:** When using `eager_load:` with default_order, you may encounter "ambiguous column" errors if both tables have the same column names (e.g., `created_at`). Solutions:
   - Use `includes:` or `preload:` instead
   - Override `orders:` with fully qualified column names
   - Chain `.eager_load()` after search for full control

2. **Array Syntax:** Always use array syntax (`[:author]`) even for single associations to maintain consistency and allow easy additions

3. **Chainability:** Since search returns `ActiveRecord::Relation`, you can still chain additional eager loading methods:

```ruby
Article.search({ status_eq: "published" })
       .includes([:author])
       .preload([:tags])
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
- Use built-in eager loading (`includes:`, `preload:`) to avoid N+1 queries
- Consider caching for expensive searches

**Index Examples:**
```ruby
add_index :articles, :status
add_index :articles, :published_at
add_index :articles, [:status, :published_at]  # Composite for common combo
```

