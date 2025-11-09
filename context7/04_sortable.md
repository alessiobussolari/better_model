# Sortable - Type-Aware Ordering System

## Overview

Sortable provides a declarative, type-aware sorting system for ActiveRecord models. By simply declaring which fields should be sortable, you automatically get a rich set of ordering scopes tailored to each column's data type.

**Core Features:**
- **Type-aware scope generation** - Different scopes for strings, numbers, and dates
- **Semantic naming** - Clear, expressive method names like `sort_title_asc` and `sort_published_at_newest`
- **Case-insensitive sorting** - Built-in `_i` suffix for case-insensitive string ordering
- **NULL handling** - Explicit NULL positioning with `_nulls_last` and `_nulls_first` suffixes
- **Date semantics** - Use `_newest` and `_oldest` instead of `_desc`/`_asc` for dates
- **Chainable queries** - Stack multiple orderings with clear precedence
- **Thread-safe** - Immutable registries using frozen Sets
- **Zero runtime overhead** - All scopes compiled at class load time

**Requirements:**
- Included automatically with `BetterModel`
- No database migrations required
- Works with PostgreSQL, MySQL, and SQLite

---

## Basic Declaration and Usage

### Simple Declaration

Declare sortable fields using the `sort` method in your model:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Declare fields that should be sortable
  sort :title, :view_count, :published_at
end
```

### Auto-Generated Scopes

Once declared, Sortable automatically generates scopes based on each field's column type:

**String fields** (4 scopes per field):
```ruby
Article.sort_title_asc              # ORDER BY title ASC
Article.sort_title_desc             # ORDER BY title DESC
Article.sort_title_asc_i            # ORDER BY LOWER(title) ASC (case-insensitive)
Article.sort_title_desc_i           # ORDER BY LOWER(title) DESC
```

**Numeric fields** (6 scopes per field):
```ruby
Article.sort_view_count_asc                     # ORDER BY view_count ASC
Article.sort_view_count_desc                    # ORDER BY view_count DESC
Article.sort_view_count_asc_nulls_last          # ASC with NULL values at end
Article.sort_view_count_desc_nulls_last         # DESC with NULL values at end
Article.sort_view_count_asc_nulls_first         # ASC with NULL values at start
Article.sort_view_count_desc_nulls_first        # DESC with NULL values at start
```

**Date/DateTime fields** (6 scopes per field):
```ruby
Article.sort_published_at_asc       # ORDER BY published_at ASC
Article.sort_published_at_desc      # ORDER BY published_at DESC
Article.sort_published_at_newest    # Most recent first (alias for _desc)
Article.sort_published_at_oldest    # Oldest first (alias for _asc)
Article.sort_published_at_asc_nulls_last
Article.sort_published_at_desc_nulls_last
```

### Simple Usage Examples

```ruby
# Sort articles alphabetically
@articles = Article.sort_title_asc

# Sort by most views
@popular = Article.where(status: 'published').sort_view_count_desc

# Sort by newest first
@recent = Article.sort_published_at_newest

# Case-insensitive alphabetical (user-friendly)
@articles = Article.sort_title_asc_i
```

---

## String Field Sorting

String fields get four auto-generated scopes: ascending, descending, and case-insensitive variants of each.

### Example: Blog Post Titles

```ruby
class Post < ApplicationRecord
  include BetterModel

  sort :title, :author_name
end

# Case-sensitive alphabetical (default)
@posts = Post.sort_title_asc
# SQL: ORDER BY title ASC

# Case-insensitive alphabetical (better for user-facing lists)
@posts = Post.sort_title_asc_i
# SQL: ORDER BY LOWER(title) ASC

# Reverse alphabetical
@posts = Post.sort_title_desc
# SQL: ORDER BY title DESC

# Case-insensitive reverse
@posts = Post.sort_title_desc_i
# SQL: ORDER BY LOWER(title) DESC
```

### Why Case-Insensitive Sorting Matters

```ruby
# Without _i suffix (case-sensitive):
# Results: ["Alpha", "Beta", "alpha", "beta"]
# Capital letters sort before lowercase

@posts = Post.sort_title_asc_i
# With _i suffix (case-insensitive):
# Results: ["Alpha", "alpha", "Beta", "beta"]
# More natural for users
```

### Multi-Field String Sorting

```ruby
# Sort by author, then by title (both case-insensitive)
@posts = Post.sort_author_name_asc_i
             .sort_title_asc_i

# Primary sort: author (case-sensitive)
# Secondary sort: title (case-insensitive)
@posts = Post.sort_author_name_asc
             .sort_title_asc_i
```

---

## Numeric Field Sorting

Numeric fields get six auto-generated scopes: ascending/descending plus explicit NULL handling.

### Example: Product Pricing

```ruby
class Product < ApplicationRecord
  include BetterModel

  sort :price, :stock, :rating
end

# Cheapest first
@products = Product.sort_price_asc
# SQL: ORDER BY price ASC

# Most expensive first
@products = Product.sort_price_desc
# SQL: ORDER BY price DESC

# Cheapest first, products without price at end
@products = Product.sort_price_asc_nulls_last
# SQL: ORDER BY price ASC NULLS LAST

# Most expensive first, products without price at end
@products = Product.sort_price_desc_nulls_last
# SQL: ORDER BY price DESC NULLS LAST
```

### NULL Handling Explained

By default, database ordering behavior for NULL values varies:
- PostgreSQL: NULLs come last for ASC, first for DESC
- MySQL: NULLs come first for ASC, last for DESC
- SQLite 3.30+: NULLs come first by default

Sortable provides explicit control:

```ruby
# Show products with stock first, out-of-stock at end
@products = Product.sort_stock_desc_nulls_last

# Show highest-rated first, unrated products at end
@products = Product.sort_rating_desc_nulls_last

# Show unrated products first (for review queue)
@products = Product.sort_rating_asc_nulls_first
```

### Real-World Example: E-commerce Catalog

```ruby
class Product < ApplicationRecord
  include BetterModel

  sort :name, :price, :stock, :rating, :created_at
end

# Budget shoppers: cheapest in-stock items first
@products = Product.where('stock > 0')
                   .sort_price_asc

# Featured products: highest rated with stock
@featured = Product.where('stock > 0')
                   .sort_rating_desc_nulls_last
                   .sort_price_desc
                   .limit(10)

# New arrivals: newest first, alphabetical
@new_products = Product.sort_created_at_newest
                       .sort_name_asc_i
                       .limit(20)

# Low stock alert: items running out
@low_stock = Product.where('stock < 10')
                    .sort_stock_asc
                    .sort_name_asc_i
```

---

## Date Field Sorting

Date and datetime fields get semantic aliases (`_newest`/`_oldest`) for better readability.

### Example: Article Publishing

```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :published_at, :created_at, :updated_at
end

# Most recent articles first (semantic)
@articles = Article.sort_published_at_newest
# SQL: ORDER BY published_at DESC

# Oldest articles first (semantic)
@articles = Article.sort_published_at_oldest
# SQL: ORDER BY published_at ASC

# Standard direction scopes still work
@articles = Article.sort_published_at_desc  # Same as _newest
@articles = Article.sort_published_at_asc   # Same as _oldest

# With NULL handling: unpublished articles at end
@articles = Article.sort_published_at_newest_nulls_last
# Note: _newest_nulls_last is an alias for _desc_nulls_last
```

### Semantic Aliases for Readability

```ruby
# These are equivalent but the first is more readable:
@posts = Post.sort_published_at_newest    # ✅ Clear intent
@posts = Post.sort_published_at_desc      # ⚠️ Technical, less clear

@posts = Post.sort_created_at_oldest      # ✅ Clear intent
@posts = Post.sort_created_at_asc         # ⚠️ Technical, less clear
```

### Real-World Example: News Feed

```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :published_at, :view_count, :title
end

# Main feed: newest first
@feed = Article.where(status: 'published')
               .sort_published_at_newest
               .limit(50)

# Popular recent articles: last 7 days, most viewed
@trending = Article.where('published_at >= ?', 7.days.ago)
                   .where(status: 'published')
                   .sort_view_count_desc
                   .sort_published_at_newest
                   .limit(10)

# Archives: oldest first, alphabetical
@archive = Article.where(status: 'archived')
                  .sort_published_at_oldest
                  .sort_title_asc_i

# Drafts: recently updated first, drafts without update date at end
@drafts = Article.where(status: 'draft')
                 .sort_updated_at_newest_nulls_last
                 .sort_title_asc_i
```

---

## Multi-Column Sorting (Chaining)

Chain multiple sort scopes for complex ordering with clear precedence.

### How Chaining Works

Each sort scope returns an `ActiveRecord::Relation`, so you can chain them:

```ruby
# Order of chaining = order of SQL ORDER BY clauses
Article.sort_published_at_newest     # PRIMARY: published_at DESC
       .sort_view_count_desc         # SECONDARY: view_count DESC
       .sort_title_asc_i             # TERTIARY: LOWER(title) ASC

# Generated SQL:
# ORDER BY published_at DESC, view_count DESC, LOWER(title) ASC
```

### Example: Task Management

```ruby
class Task < ApplicationRecord
  include BetterModel

  sort :priority, :due_date, :title, :created_at
end

# High priority first, then by due date, then alphabetical
@tasks = Task.sort_priority_desc
             .sort_due_date_asc_nulls_last
             .sort_title_asc_i

# Overdue tasks: past due dates first, highest priority, alphabetical
@overdue = Task.where('due_date < ?', Date.today)
               .sort_due_date_asc
               .sort_priority_desc
               .sort_title_asc_i

# Completed tasks: recently completed first
@completed = Task.where(status: 'completed')
                 .sort_updated_at_newest
                 .sort_priority_desc
```

### Example: User Directory

```ruby
class User < ApplicationRecord
  include BetterModel

  sort :name, :email, :created_at, :last_sign_in_at
end

# Active users: recent activity first, alphabetical
@active = User.where('last_sign_in_at >= ?', 30.days.ago)
              .sort_last_sign_in_at_newest
              .sort_name_asc_i

# All users: active first (inactive at end), then alphabetical
@all_users = User.sort_last_sign_in_at_desc_nulls_last
                 .sort_name_asc_i

# New registrations: newest first, then by name
@new_users = User.where('created_at >= ?', 7.days.ago)
                 .sort_created_at_newest
                 .sort_name_asc_i
```

### Best Practice: Logical Ordering

```ruby
# ✅ Good: Logical precedence (primary → secondary → tertiary)
Product.sort_category_asc_i          # Group by category
       .sort_price_asc               # Then by price
       .sort_name_asc_i              # Then alphabetically

# ❌ Poor: Confusing precedence
Product.sort_name_asc_i              # Name will be overridden by price groups
       .sort_price_asc
       .sort_category_asc_i          # Category dominates, name becomes tertiary
```

---

## Complex Sort

For multi-field ordering and advanced sorting logic not covered by standard predicates, use `register_complex_sort` to define custom sorting scopes that can combine multiple fields, use CASE WHEN logic, or integrate filtering with ordering.

### API Reference: register_complex_sort

**Method Signature:**
```ruby
register_complex_sort(name, &block)
```

**Parameters:**
- `name` (Symbol): The name of the sort (will be registered as `sort_#{name}`)
- `block` (Proc): Sorting logic that returns an ActiveRecord::Relation with ORDER BY (required)

**Returns:** Registers a new scope with `sort_` prefix and adds it to `complex_sorts_registry`

**Thread Safety:** Registry is a frozen Hash, sorts defined at class load time

**Behavior:**
- The block receives optional parameters and must return an `ActiveRecord::Relation`
- Generated scope is prefixed with `sort_` (e.g., `register_complex_sort :by_popularity` → `sort_by_popularity`)
- Can be chained with other scopes and predicates
- Complex sorts appear in `complex_sorts_registry`

### Basic Examples

**Multi-field sorting:**
```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :published_at, :view_count, :title

  register_complex_sort :by_popularity do
    order(published_at: :desc, view_count: :desc, title: :asc)
  end
end

# Usage
Article.sort_by_popularity
# Equivalent to: ORDER BY published_at DESC, view_count DESC, title ASC
```

**Sorting with parameters:**
```ruby
register_complex_sort :by_relevance do |keyword|
  order(
    Arel.sql(
      "CASE WHEN title ILIKE '%#{sanitize_sql_like(keyword)}%' THEN 0 " \
      "WHEN content ILIKE '%#{sanitize_sql_like(keyword)}%' THEN 1 " \
      "ELSE 2 END ASC, " \
      "published_at DESC"
    )
  )
end

# Usage
Article.sort_by_relevance('rails')
# Title matches first, then content matches, then by date
```

**Conditional sorting with CASE WHEN:**
```ruby
register_complex_sort :by_priority do
  order(
    Arel.sql("CASE WHEN priority IS NULL THEN 1 ELSE 0 END"),
    priority: :desc,
    created_at: :desc
  )
end

# Usage
Article.sort_by_priority
# Non-NULL priorities first (highest first), then by creation date
```

**Combining filtering and sorting:**
```ruby
register_complex_sort :featured_and_recent do
  where(featured: true)
    .order(published_at: :desc, view_count: :desc)
end

# Usage
Article.sort_featured_and_recent
Article.where(status: 'published').sort_featured_and_recent
```

### Integration with Predicables

Complex sorts work seamlessly with predicates:

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :status, :view_count, :published_at
  sort :published_at

  register_complex_sort :trending do
    where("view_count >= ?", 500)
      .order(view_count: :desc, published_at: :desc)
  end
end

# Chainable usage
Article
  .status_eq("published")
  .published_at_within(30.days)
  .sort_trending
  .limit(5)
```

### Class Methods

```ruby
# Check if a complex sort is registered
Article.complex_sort?(:by_popularity)  # => true

# Get all registered complex sorts
Article.complex_sorts_registry
# => {:by_popularity => #<Proc>, :by_relevance => #<Proc>}
```

### Advanced Examples

**Real-World: Task Urgency Sorting**

```ruby
class Task < ApplicationRecord
  include BetterModel

  sort :priority, :due_date, :created_at

  # Complex urgency calculation
  register_complex_sort :by_urgency do
    order(
      Arel.sql(
        "CASE " \
        "WHEN due_date < CURRENT_DATE THEN 0 " \
        "WHEN due_date = CURRENT_DATE THEN 1 " \
        "WHEN due_date <= CURRENT_DATE + INTERVAL '3 days' THEN 2 " \
        "WHEN due_date <= CURRENT_DATE + INTERVAL '7 days' THEN 3 " \
        "ELSE 4 END"
      ),
      priority: :desc,
      due_date: :asc
    )
  end
end

# Usage
Task.where.not(status: 'completed').sort_by_urgency
# Overdue first, then due today, then due soon, etc.
```

**Real-World: E-commerce Product Ranking**

```ruby
class Product < ApplicationRecord
  include BetterModel

  sort :name, :price, :rating, :sales_count

  # Best value: good ratings, reasonable price
  register_complex_sort :best_value do
    where("rating >= ?", 4.0)
      .order(
        Arel.sql("(rating * 100) / NULLIF(price, 0) DESC"),
        sales_count: :desc
      )
  end

  # Trending: recent sales with high engagement
  register_complex_sort :trending do |days = 7|
    joins(:order_items)
      .where("order_items.created_at >= ?", days.days.ago)
      .group("products.id")
      .order(Arel.sql("COUNT(order_items.id) DESC"), rating: :desc)
  end
end

# Usage
Product.where("stock > 0").sort_best_value.limit(10)
Product.sort_trending(14)  # Last 14 days
```

**Real-World: Content Recommendation**

```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :published_at, :view_count, :title

  # Personalized recommendation score
  register_complex_sort :recommended_for do |user_id, limit_days = 30|
    joins(:user_interactions)
      .where("user_interactions.user_id = ?", user_id)
      .where("articles.published_at >= ?", limit_days.days.ago)
      .group("articles.id")
      .order(
        Arel.sql(
          "SUM(CASE " \
          "WHEN user_interactions.action = 'like' THEN 3 " \
          "WHEN user_interactions.action = 'share' THEN 5 " \
          "WHEN user_interactions.action = 'bookmark' THEN 4 " \
          "ELSE 1 END) DESC"
        ),
        view_count: :desc
      )
  end
end

# Usage
Article.recommended_for(current_user.id, 60)
```

### Use Cases

- **Multi-field precedence:** Order by multiple fields with clear priority
- **Relevance ranking:** Sort search results by relevance score
- **Conditional ordering:** Use CASE WHEN for custom sort logic
- **Performance-critical queries:** Pre-structure complex sorting for reusability
- **Engagement metrics:** Sort by calculated scores from related records
- **Business rules:** Encapsulate domain-specific ordering logic
- **Dynamic parameters:** Accept arguments for flexible sorting behavior

### Best Practices

1. **Use meaningful names:** Choose names that clearly describe the sorting logic
   ```ruby
   # ✅ Good
   register_complex_sort :by_popularity
   register_complex_sort :trending_last_week

   # ❌ Poor
   register_complex_sort :sort1
   register_complex_sort :custom_order
   ```

2. **Document complex logic:** Add comments explaining non-obvious CASE WHEN or calculations
   ```ruby
   # Calculate urgency score: overdue (0), due today (1), due soon (2), future (3)
   register_complex_sort :by_urgency do
     order(Arel.sql("CASE WHEN due_date < CURRENT_DATE THEN 0 ..."))
   end
   ```

3. **Validate parameters:** Check parameters to prevent errors
   ```ruby
   register_complex_sort :trending do |days = 7|
     raise ArgumentError, "days must be positive" if days.to_i <= 0
     where("view_count >= 100").order(published_at: :desc).limit(days)
   end
   ```

4. **Use Arel for complex SQL:** Arel is safer than string interpolation
   ```ruby
   # ✅ Good: Using Arel
   register_complex_sort :by_ratio do
     order(arel_table[:sales].div(arel_table[:views]).desc)
   end

   # ⚠️ Acceptable: SQL with parameter binding
   register_complex_sort :by_score do |weight|
     order(Arel.sql("(rating * ?) DESC"), weight)
   end
   ```

5. **Combine with predicates:** Use complex sorts with filtering for powerful queries
   ```ruby
   Article
     .status_eq("published")
     .published_at_within(30.days)
     .sort_trending
     .limit(10)
   ```

---

## Controller Integration

Map URL parameters to sort scopes for user-controlled ordering.

### Basic Pattern

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Apply sorting based on params
    @articles = apply_sort(@articles, params[:sort])

    @articles = @articles.page(params[:page])
  end

  private

  def apply_sort(scope, sort_param)
    case sort_param
    when 'title_asc'
      scope.sort_title_asc_i
    when 'title_desc'
      scope.sort_title_desc_i
    when 'newest'
      scope.sort_published_at_newest
    when 'oldest'
      scope.sort_published_at_oldest
    when 'popular'
      scope.sort_view_count_desc
    else
      scope.sort_published_at_newest  # Default
    end
  end
end
```

### URLs:
```
/articles?sort=title_asc
/articles?sort=newest
/articles?sort=popular
```

### Advanced: Dynamic Validation

```ruby
class ArticlesController < ApplicationController
  ALLOWED_SORTS = {
    'title_asc' => :sort_title_asc_i,
    'title_desc' => :sort_title_desc_i,
    'newest' => :sort_published_at_newest,
    'oldest' => :sort_published_at_oldest,
    'popular' => :sort_view_count_desc,
    'trending' => [:sort_view_count_desc, :sort_published_at_newest]
  }.freeze

  def index
    @articles = Article.where(status: 'published')
    @articles = apply_sort(@articles, params[:sort])
    @articles = @articles.page(params[:page])
  end

  private

  def apply_sort(scope, sort_param)
    sort_param = sort_param.to_s
    return scope.sort_published_at_newest unless ALLOWED_SORTS.key?(sort_param)

    sort_methods = Array(ALLOWED_SORTS[sort_param])
    sort_methods.reduce(scope) { |s, method| s.public_send(method) }
  end
end
```

### With Introspection

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all

    # Validate sort param against actual sortable scopes
    if params[:sort].present? && Product.sortable_scope?(params[:sort].to_sym)
      @products = @products.public_send(params[:sort])
    else
      @products = @products.sort_name_asc_i  # Default
    end

    @products = @products.page(params[:page])
  end
end
```

### URLs:
```
/products?sort=sort_name_asc_i
/products?sort=sort_price_asc
/products?sort=sort_rating_desc_nulls_last
```

---

## API Integration

### JSON API with Sort Parameters

```ruby
class Api::V1::ArticlesController < Api::BaseController
  ALLOWED_SORTS = {
    'title' => { asc: :sort_title_asc_i, desc: :sort_title_desc_i },
    'published_at' => { asc: :sort_published_at_oldest, desc: :sort_published_at_newest },
    'view_count' => { asc: :sort_view_count_asc, desc: :sort_view_count_desc }
  }.freeze

  def index
    @articles = Article.where(status: 'published')
    @articles = apply_sort(@articles)
    @articles = @articles.page(params[:page]).per(params[:per_page] || 20)

    render json: {
      articles: @articles.as_json(only: [:id, :title, :published_at, :view_count]),
      meta: {
        total: @articles.total_count,
        page: params[:page],
        sort: sort_params
      }
    }
  end

  private

  def apply_sort(scope)
    field = params[:sort_by]&.to_s
    direction = params[:sort_direction]&.to_sym || :desc

    return scope.sort_published_at_newest unless ALLOWED_SORTS.key?(field)
    return scope unless [:asc, :desc].include?(direction)

    scope.public_send(ALLOWED_SORTS[field][direction])
  end

  def sort_params
    {
      by: params[:sort_by] || 'published_at',
      direction: params[:sort_direction] || 'desc'
    }
  end
end
```

### API URLs:
```
GET /api/v1/articles?sort_by=title&sort_direction=asc
GET /api/v1/articles?sort_by=view_count&sort_direction=desc
GET /api/v1/articles?sort_by=published_at&sort_direction=desc
```

### GraphQL Integration

```ruby
module Types
  class ArticleType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :published_at, GraphQL::Types::ISO8601DateTime, null: true
    field :view_count, Integer, null: true
  end

  class QueryType < Types::BaseObject
    field :articles, [Types::ArticleType], null: false do
      argument :sort_field, String, required: false
      argument :sort_direction, String, required: false
    end

    def articles(sort_field: 'published_at', sort_direction: 'desc')
      articles = Article.where(status: 'published')

      sort_scope = case [sort_field, sort_direction]
      when ['title', 'asc']
        :sort_title_asc_i
      when ['title', 'desc']
        :sort_title_desc_i
      when ['published_at', 'asc']
        :sort_published_at_oldest
      when ['published_at', 'desc']
        :sort_published_at_newest
      when ['view_count', 'asc']
        :sort_view_count_asc
      when ['view_count', 'desc']
        :sort_view_count_desc
      else
        :sort_published_at_newest
      end

      articles.public_send(sort_scope)
    end
  end
end
```

### GraphQL Query:
```graphql
query {
  articles(sortField: "view_count", sortDirection: "desc") {
    id
    title
    publishedAt
    viewCount
  }
}
```

---

## Query Methods and Introspection

Sortable provides class methods for checking field and scope availability.

### Class Method: `sortable_field?`

Check if a field has sorting scopes:

```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :title, :view_count, :published_at
end

# Check if fields are sortable
Article.sortable_field?(:title)          # => true
Article.sortable_field?(:view_count)     # => true
Article.sortable_field?(:content)        # => false (not declared)
Article.sortable_field?(:nonexistent)    # => false
```

### Class Method: `sortable_scope?`

Check if a specific scope exists:

```ruby
Article.sortable_scope?(:sort_title_asc)             # => true
Article.sortable_scope?(:sort_title_asc_i)           # => true
Article.sortable_scope?(:sort_view_count_desc)       # => true
Article.sortable_scope?(:sort_published_at_newest)   # => true
Article.sortable_scope?(:sort_invalid)               # => false
```

### Class Method: `sortable_fields`

Get all sortable fields as a frozen Set:

```ruby
Article.sortable_fields
# => #<Set: {:title, :view_count, :published_at}>

# Thread-safe: returns frozen Set
Article.sortable_fields.frozen?  # => true
```

### Class Method: `sortable_scopes`

Get all generated sort scopes:

```ruby
Article.sortable_scopes
# => #<Set: {
#   :sort_title_asc, :sort_title_desc, :sort_title_asc_i, :sort_title_desc_i,
#   :sort_view_count_asc, :sort_view_count_desc,
#   :sort_view_count_asc_nulls_last, :sort_view_count_desc_nulls_last,
#   :sort_view_count_asc_nulls_first, :sort_view_count_desc_nulls_first,
#   :sort_published_at_asc, :sort_published_at_desc,
#   :sort_published_at_newest, :sort_published_at_oldest,
#   :sort_published_at_asc_nulls_last, :sort_published_at_desc_nulls_last
# }>

# Count generated scopes
Article.sortable_scopes.size  # => 16 (4 for string, 6 for numeric, 6 for date)
```

### Using Introspection for Validation

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Safe dynamic sorting with validation
    sort_scope = params[:sort]&.to_sym

    if sort_scope && Article.sortable_scope?(sort_scope)
      @articles = @articles.public_send(sort_scope)
    else
      @articles = @articles.sort_published_at_newest  # Default
    end

    @articles = @articles.page(params[:page])
  end
end
```

### Building Dynamic Sort UI

```ruby
# In your view/helper:
def sortable_link(field, label, direction = 'asc')
  scope_name = "sort_#{field}_#{direction}"

  if Article.sortable_scope?(scope_name.to_sym)
    link_to label, articles_path(sort: scope_name)
  else
    label  # Not sortable, just show text
  end
end

# Usage in view:
<%= sortable_link('title', 'Title', 'asc') %>
<%= sortable_link('view_count', 'Views', 'desc') %>
<%= sortable_link('published_at', 'Date', 'desc') %>
```

---

## Instance Methods

### `sortable_attributes`

Get a list of sortable attribute names (as strings) for an instance, automatically excluding sensitive fields:

```ruby
article = Article.first

# Returns array of sortable attribute names
article.sortable_attributes
# => ["id", "title", "content", "status", "view_count", "published_at", "created_at", "updated_at"]

# Automatically excludes fields starting with:
# - "password"
# - "encrypted_"

class User < ApplicationRecord
  include BetterModel

  sort :name, :email, :created_at
end

user = User.first
user.sortable_attributes
# => ["id", "name", "email", "created_at", "updated_at"]
# Note: "password_digest", "encrypted_password" would be excluded
```

### Use Case: API Serialization

```ruby
class ArticleSerializer
  def initialize(article)
    @article = article
  end

  def as_json
    {
      id: @article.id,
      attributes: sortable_data,
      sortable_fields: @article.sortable_attributes
    }
  end

  private

  def sortable_data
    @article.sortable_attributes.each_with_object({}) do |attr, hash|
      hash[attr] = @article.public_send(attr)
    end
  end
end
```

---

## Advanced Patterns

### Combining with Pagination and Filtering

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all

    # Apply filters
    @products = @products.where(category: params[:category]) if params[:category].present?
    @products = @products.where('price >= ?', params[:min_price]) if params[:min_price].present?
    @products = @products.where('price <= ?', params[:max_price]) if params[:max_price].present?

    # Apply sorting
    @products = case params[:sort]
    when 'name_asc'
      @products.sort_name_asc_i
    when 'name_desc'
      @products.sort_name_desc_i
    when 'price_low'
      @products.sort_price_asc
    when 'price_high'
      @products.sort_price_desc
    when 'newest'
      @products.sort_created_at_newest
    when 'rating'
      @products.sort_rating_desc_nulls_last
    else
      @products.sort_name_asc_i
    end

    # Apply pagination (after filtering and sorting)
    @products = @products.page(params[:page]).per(20)
  end
end
```

### Scoped Sorting (Per-User/Per-Tenant)

```ruby
class TasksController < ApplicationController
  def index
    # Get user's tasks
    @tasks = current_user.tasks

    # Apply user's saved sort preference
    sort_pref = current_user.preferences[:task_sort] || 'due_date_asc'

    @tasks = case sort_pref
    when 'due_date_asc'
      @tasks.sort_due_date_asc_nulls_last.sort_priority_desc
    when 'priority'
      @tasks.sort_priority_desc.sort_due_date_asc_nulls_last
    when 'title'
      @tasks.sort_title_asc_i
    when 'created'
      @tasks.sort_created_at_newest
    else
      @tasks.sort_due_date_asc_nulls_last
    end

    @tasks = @tasks.page(params[:page])
  end

  def update_sort_preference
    current_user.update(
      preferences: current_user.preferences.merge(task_sort: params[:sort])
    )

    redirect_to tasks_path
  end
end
```

### Combining with Searchable

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Sortable fields
  sort :title, :view_count, :published_at, :created_at

  # Searchable fields
  predicates :title, :content, :status, :view_count, :published_at

  searchable do
    default_order [:sort_published_at_newest]

    # Map sort params to scopes
    sort_option 'newest', :sort_published_at_newest
    sort_option 'oldest', :sort_published_at_oldest
    sort_option 'popular', :sort_view_count_desc
    sort_option 'title_asc', :sort_title_asc_i
  end
end

# Usage in controller:
@articles = Article.search(params[:q])  # Includes sorting from params[:sort]
```

---

## Real-World Examples

### Example 1: E-commerce Product Catalog

Complete example integrating sorting with filters, pagination, and user preferences.

### Model

```ruby
class Product < ApplicationRecord
  include BetterModel

  # Sortable fields
  sort :name, :price, :stock, :rating, :created_at, :sales_count

  # Scopes for common filters
  scope :in_stock, -> { where('stock > 0') }
  scope :on_sale, -> { where('sale_price IS NOT NULL') }
  scope :by_category, ->(category) { where(category: category) }
  scope :price_range, ->(min, max) { where(price: min..max) }
end
```

### Controller

```ruby
class ProductsController < ApplicationController
  SORT_OPTIONS = {
    'name_asc' => :sort_name_asc_i,
    'name_desc' => :sort_name_desc_i,
    'price_low' => :sort_price_asc,
    'price_high' => :sort_price_desc,
    'newest' => :sort_created_at_newest,
    'popular' => :sort_sales_count_desc,
    'rating' => :sort_rating_desc_nulls_last,
    'stock' => :sort_stock_desc_nulls_last
  }.freeze

  def index
    @products = Product.all

    # Apply filters
    @products = apply_filters(@products)

    # Apply sorting
    @products = apply_sorting(@products)

    # Pagination
    @products = @products.page(params[:page]).per(24)

    # Track current sort for UI
    @current_sort = params[:sort] || 'name_asc'
  end

  private

  def apply_filters(scope)
    scope = scope.by_category(params[:category]) if params[:category].present?
    scope = scope.in_stock if params[:in_stock] == '1'
    scope = scope.on_sale if params[:on_sale] == '1'
    scope = scope.price_range(params[:min_price], params[:max_price]) if price_filter?
    scope
  end

  def apply_sorting(scope)
    sort_key = params[:sort] || 'name_asc'
    sort_method = SORT_OPTIONS[sort_key]

    if sort_method && Product.sortable_scope?(sort_method)
      scope.public_send(sort_method)
    else
      scope.sort_name_asc_i  # Fallback
    end
  end

  def price_filter?
    params[:min_price].present? && params[:max_price].present?
  end
end
```

### View (sorting dropdown)

```erb
<div class="sort-options">
  <%= form_with url: products_path, method: :get, local: true do |f| %>
    <%= f.select :sort,
        options_for_select([
          ['Name (A-Z)', 'name_asc'],
          ['Name (Z-A)', 'name_desc'],
          ['Price (Low to High)', 'price_low'],
          ['Price (High to Low)', 'price_high'],
          ['Newest', 'newest'],
          ['Most Popular', 'popular'],
          ['Highest Rated', 'rating'],
          ['In Stock', 'stock']
        ], @current_sort),
        {},
        { onchange: 'this.form.submit();' }
    %>

    <!-- Preserve other params -->
    <%= hidden_field_tag :category, params[:category] %>
    <%= hidden_field_tag :in_stock, params[:in_stock] %>
    <%= hidden_field_tag :on_sale, params[:on_sale] %>
  <% end %>
</div>

<div class="products-grid">
  <% @products.each do |product| %>
    <div class="product-card">
      <h3><%= product.name %></h3>
      <p class="price"><%= number_to_currency(product.price) %></p>
      <p class="rating">
        <%= product.rating ? "#{product.rating}★" : 'Not rated' %>
      </p>
      <p class="stock">
        <%= product.stock > 0 ? "#{product.stock} in stock" : 'Out of stock' %>
      </p>
    </div>
  <% end %>
</div>

<%= paginate @products %>
```

### API Endpoint

```ruby
module Api
  module V1
    class ProductsController < ApiController
      def index
        @products = Product.all

        # Filters
        @products = @products.by_category(params[:category]) if params[:category]
        @products = @products.in_stock if params[:in_stock]

        # Sorting
        @products = apply_api_sorting(@products)

        # Pagination
        @products = @products.page(params[:page]).per(params[:per_page] || 20)

        render json: {
          products: @products.as_json(
            only: [:id, :name, :price, :stock, :rating, :created_at],
            methods: [:sale_price]
          ),
          meta: {
            total: @products.total_count,
            page: @products.current_page,
            per_page: @products.limit_value,
            sort: sort_meta
          }
        }
      end

      private

      def apply_api_sorting(scope)
        field = params[:sort_by]
        direction = params[:sort_dir]&.downcase == 'desc' ? 'desc' : 'asc'

        scope_name = case field
        when 'name'
          direction == 'desc' ? :sort_name_desc_i : :sort_name_asc_i
        when 'price'
          direction == 'desc' ? :sort_price_desc : :sort_price_asc
        when 'rating'
          direction == 'desc' ? :sort_rating_desc_nulls_last : :sort_rating_asc_nulls_last
        when 'created_at'
          direction == 'desc' ? :sort_created_at_newest : :sort_created_at_oldest
        else
          :sort_name_asc_i
        end

        scope.public_send(scope_name)
      end

      def sort_meta
        {
          by: params[:sort_by] || 'name',
          direction: params[:sort_dir] || 'asc'
        }
      end
    end
  end
end
```

### API Usage

```bash
# Basic sorting
GET /api/v1/products?sort_by=name&sort_dir=asc

# Sort by price, high to low
GET /api/v1/products?sort_by=price&sort_dir=desc

# Sort by rating, with filters
GET /api/v1/products?category=electronics&sort_by=rating&sort_dir=desc&in_stock=true

# Pagination with sorting
GET /api/v1/products?sort_by=created_at&sort_dir=desc&page=2&per_page=20
```

### Example 2: Leaderboard with Multiple Metrics

Gaming or contest leaderboard with tie-breaking and performance sorting.

```ruby
class Player < ApplicationRecord
  include BetterModel

  # Sort by score (primary), then wins (secondary), then playtime (tertiary)
  sort :score, :wins, :losses, :playtime_minutes, :created_at

  # Custom sort method for win rate
  def self.sort_by_win_rate_desc
    order(Arel.sql('CAST(wins AS FLOAT) / NULLIF(wins + losses, 0) DESC NULLS LAST'))
  end

  def win_rate
    return 0 if wins + losses == 0
    (wins.to_f / (wins + losses) * 100).round(2)
  end
end

# Usage examples

# 1. Sort by score descending (primary leaderboard)
Player.sort_score_desc
# => SELECT * FROM players ORDER BY score DESC

# 2. Sort by wins, then by score (tie-breaker)
Player.sort_wins_desc.sort_score_desc
# => Most wins, then highest score for ties

# 3. Case-insensitive username sort
Player.sort_username_asc_i
# => Alphabetical by username, case-insensitive

# 4. Custom win rate sorting
Player.sort_by_win_rate_desc.limit(10)
# => Top 10 by win percentage

# 5. Newest players first
Player.sort_created_at_newest
# => Most recent signups

# 6. Controller action with multi-criteria sort
class LeaderboardController < ApplicationController
  def index
    @players = Player.all

    # Apply sorting based on mode
    @players = case params[:sort_by]
               when 'score'
                 @players.sort_score_desc.sort_wins_desc
               when 'wins'
                 @players.sort_wins_desc.sort_score_desc
               when 'win_rate'
                 @players.sort_by_win_rate_desc
               when 'playtime'
                 @players.sort_playtime_minutes_desc
               else
                 @players.sort_score_desc.sort_wins_desc
               end

    @players = @players.limit(100)
  end
end
```

### Example 3: Real Estate Property Listings

Property search with location-based and attribute sorting.

```ruby
class Property < ApplicationRecord
  include BetterModel

  belongs_to :neighborhood

  sort :price, :bedrooms, :bathrooms, :square_feet, :year_built, :listed_at

  # Custom sort by price per square foot
  scope :sort_price_per_sqft_asc, -> {
    order(Arel.sql('price / NULLIF(square_feet, 0) ASC NULLS LAST'))
  }

  scope :sort_price_per_sqft_desc, -> {
    order(Arel.sql('price / NULLIF(square_feet, 0) DESC NULLS LAST'))
  }

  # Sort by distance from coordinates (requires pg_sphere or similar)
  def self.sort_by_distance(lat, lng)
    order(Arel.sql("
      ST_Distance(
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326),
        ST_SetSRID(ST_MakePoint(#{lng.to_f}, #{lat.to_f}), 4326)
      ) ASC
    "))
  end

  def price_per_sqft
    return 0 if square_feet.to_i.zero?
    (price.to_f / square_feet).round(2)
  end
end

# Usage examples

# 1. Sort by price, low to high
Property.sort_price_asc
# => Cheapest first

# 2. Sort by size, largest first
Property.sort_square_feet_desc
# => Biggest properties first

# 3. Sort by bedrooms desc, then price asc (more beds, cheaper)
Property.sort_bedrooms_desc.sort_price_asc
# => Most bedrooms, then cheapest

# 4. Sort by price per square foot
Property.sort_price_per_sqft_asc.limit(20)
# => Best value properties

# 5. Sort by newest listings
Property.sort_listed_at_newest
# => Most recently listed

# 6. Sort by distance from location
Property.sort_by_distance(37.7749, -122.4194).limit(10)
# => Closest to San Francisco coordinates

# 7. Complex controller sorting
class PropertiesController < ApplicationController
  SORT_OPTIONS = {
    'price_low' => :sort_price_asc,
    'price_high' => :sort_price_desc,
    'beds_high' => :sort_bedrooms_desc,
    'sqft_high' => :sort_square_feet_desc,
    'newest' => :sort_listed_at_newest,
    'value' => :sort_price_per_sqft_asc
  }.freeze

  def search
    @properties = Property.where('price <= ?', params[:max_price])
    @properties = @properties.where('bedrooms >= ?', params[:min_beds]) if params[:min_beds]

    # Apply sorting
    sort_method = SORT_OPTIONS[params[:sort]] || :sort_price_asc
    @properties = @properties.public_send(sort_method)

    # Distance sorting if coordinates provided
    if params[:lat] && params[:lng]
      @properties = @properties.sort_by_distance(params[:lat], params[:lng])
    end

    @properties = @properties.page(params[:page]).per(25)
  end
end
```

### Example 4: Employee Directory with Custom Sort

HR system with case-insensitive name sorting and department hierarchy.

```ruby
class Employee < ApplicationRecord
  include BetterModel

  belongs_to :department
  belongs_to :manager, class_name: 'Employee', optional: true

  sort :last_name, :first_name, :hire_date, :salary, :employee_id

  # Custom sort by department name (join)
  scope :sort_by_department_asc, -> {
    joins(:department).order('departments.name ASC, last_name ASC')
  }

  scope :sort_by_department_desc, -> {
    joins(:department).order('departments.name DESC, last_name ASC')
  }

  # Sort by tenure (years of service)
  scope :sort_by_tenure_desc, -> {
    order(Arel.sql('EXTRACT(YEAR FROM AGE(CURRENT_DATE, hire_date)) DESC'))
  }

  scope :sort_by_tenure_asc, -> {
    order(Arel.sql('EXTRACT(YEAR FROM AGE(CURRENT_DATE, hire_date)) ASC'))
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  def years_of_service
    ((Date.current - hire_date) / 365.25).floor
  end
end

# Usage examples

# 1. Sort by last name, case-insensitive
Employee.sort_last_name_asc_i
# => Alphabetical by last name, ignoring case

# 2. Sort by hire date, newest first
Employee.sort_hire_date_newest
# => Most recent hires first

# 3. Sort by salary, highest first
Employee.sort_salary_desc
# => Highest paid employees first

# 4. Sort by employee ID (default order)
Employee.sort_employee_id_asc
# => Chronological by employee number

# 5. Sort by department, then last name
Employee.sort_by_department_asc
# => Grouped by department, alphabetical within

# 6. Sort by tenure (longest serving)
Employee.sort_by_tenure_desc.limit(10)
# => 10 most senior employees by hire date

# 7. Directory controller with multiple sort options
class EmployeeDirectoryController < ApplicationController
  def index
    @employees = Employee.includes(:department)

    # Apply filters
    @employees = @employees.where(department_id: params[:department_id]) if params[:department_id]
    @employees = @employees.where(active: true) if params[:active_only]

    # Apply sorting
    @employees = case params[:sort]
                 when 'name'
                   @employees.sort_last_name_asc_i.sort_first_name_asc_i
                 when 'department'
                   @employees.sort_by_department_asc
                 when 'hire_date'
                   @employees.sort_hire_date_oldest
                 when 'tenure'
                   @employees.sort_by_tenure_desc
                 when 'salary'
                   @employees.sort_salary_desc
                 else
                   @employees.sort_last_name_asc_i
                 end

    @employees = @employees.page(params[:page]).per(50)
  end
end

# 8. Export sorted data to CSV
csv_data = Employee.sort_by_department_asc.map do |emp|
  [emp.employee_id, emp.full_name, emp.department.name, emp.hire_date, emp.salary]
end
```

### Example 5: Task Management Priority System

Project task board with priority, deadline, and status sorting.

```ruby
class Task < ApplicationRecord
  include BetterModel

  belongs_to :project
  belongs_to :assigned_to, class_name: 'User', optional: true

  enum priority: { low: 0, medium: 1, high: 2, critical: 3 }
  enum status: { todo: 0, in_progress: 1, review: 2, done: 3 }

  sort :priority, :due_date, :created_at, :title, :status

  # Custom sort by urgency (due soon + high priority)
  scope :sort_by_urgency_desc, -> {
    order(Arel.sql('
      CASE
        WHEN due_date < CURRENT_DATE THEN 0
        WHEN due_date = CURRENT_DATE THEN 1
        WHEN due_date <= CURRENT_DATE + INTERVAL \'3 days\' THEN 2
        WHEN due_date <= CURRENT_DATE + INTERVAL \'7 days\' THEN 3
        ELSE 4
      END ASC,
      priority DESC
    '))
  }

  # Sort by completion percentage (requires subtasks)
  def self.sort_by_progress_asc
    left_joins(:subtasks)
      .group('tasks.id')
      .order(Arel.sql('
        CAST(COUNT(CASE WHEN subtasks.completed THEN 1 END) AS FLOAT) /
        NULLIF(COUNT(subtasks.id), 0) ASC NULLS LAST
      '))
  end

  def self.sort_by_progress_desc
    left_joins(:subtasks)
      .group('tasks.id')
      .order(Arel.sql('
        CAST(COUNT(CASE WHEN subtasks.completed THEN 1 END) AS FLOAT) /
        NULLIF(COUNT(subtasks.id), 0) DESC NULLS LAST
      '))
  end

  def days_until_due
    return nil if due_date.blank?
    (due_date - Date.current).to_i
  end

  def overdue?
    due_date.present? && due_date < Date.current
  end
end

# Usage examples

# 1. Sort by priority, highest first
Task.where(status: [:todo, :in_progress]).sort_priority_desc
# => Critical tasks first

# 2. Sort by due date, soonest first
Task.sort_due_date_asc_nulls_last
# => Upcoming deadlines, tasks without due dates at end

# 3. Sort by creation date, newest first
Task.sort_created_at_newest
# => Most recently created tasks

# 4. Sort by urgency (custom logic)
Task.where.not(status: :done).sort_by_urgency_desc
# => Overdue + high priority first

# 5. Sort by progress (completion percentage)
Task.where(status: :in_progress).sort_by_progress_desc
# => Tasks closest to completion

# 6. Sort by title, case-insensitive
Task.sort_title_asc_i
# => Alphabetical by task name

# 7. Kanban board controller
class TaskBoardController < ApplicationController
  def index
    @project = Project.find(params[:project_id])
    @tasks = @project.tasks

    # Group by status
    @todo = @tasks.where(status: :todo)
    @in_progress = @tasks.where(status: :in_progress)
    @review = @tasks.where(status: :review)
    @done = @tasks.where(status: :done)

    # Sort each column
    @todo = @todo.sort_priority_desc.sort_due_date_asc_nulls_last
    @in_progress = @in_progress.sort_by_urgency_desc
    @review = @review.sort_created_at_newest
    @done = @done.sort_created_at_newest.limit(20)
  end

  def my_tasks
    @tasks = current_user.assigned_tasks.where.not(status: :done)

    # Sort by user preference
    @tasks = case current_user.preferred_task_sort
             when 'urgency'
               @tasks.sort_by_urgency_desc
             when 'due_date'
               @tasks.sort_due_date_asc_nulls_last
             when 'priority'
               @tasks.sort_priority_desc
             else
               @tasks.sort_by_urgency_desc
             end

    @tasks = @tasks.limit(50)
  end
end
```

### Example 6: Investment Portfolio Tracker

Financial portfolio with performance metrics and custom calculations.

```ruby
class Investment < ApplicationRecord
  include BetterModel

  belongs_to :portfolio
  belongs_to :asset

  sort :purchase_date, :purchase_price, :current_value, :quantity, :ticker

  # Sort by total return (gain/loss amount)
  scope :sort_by_return_amount_desc, -> {
    order(Arel.sql('(current_value - purchase_price * quantity) DESC'))
  }

  scope :sort_by_return_amount_asc, -> {
    order(Arel.sql('(current_value - purchase_price * quantity) ASC'))
  }

  # Sort by return percentage
  scope :sort_by_return_percent_desc, -> {
    order(Arel.sql('
      ((current_value - purchase_price * quantity) / NULLIF(purchase_price * quantity, 0)) * 100 DESC NULLS LAST
    '))
  }

  scope :sort_by_return_percent_asc, -> {
    order(Arel.sql('
      ((current_value - purchase_price * quantity) / NULLIF(purchase_price * quantity, 0)) * 100 ASC NULLS LAST
    '))
  }

  # Sort by holding period
  scope :sort_by_holding_period_desc, -> {
    order(Arel.sql('CURRENT_DATE - purchase_date DESC'))
  }

  scope :sort_by_holding_period_asc, -> {
    order(Arel.sql('CURRENT_DATE - purchase_date ASC'))
  }

  # Sort by portfolio weight (percentage of total portfolio value)
  def self.sort_by_weight_desc
    total = sum(:current_value)
    order(Arel.sql("current_value / #{total.to_f} DESC"))
  end

  def return_amount
    current_value - (purchase_price * quantity)
  end

  def return_percentage
    return 0 if purchase_price.zero?
    ((current_value - purchase_price * quantity) / (purchase_price * quantity) * 100).round(2)
  end

  def holding_days
    (Date.current - purchase_date).to_i
  end

  def portfolio_weight(total_value)
    return 0 if total_value.zero?
    (current_value / total_value * 100).round(2)
  end
end

# Usage examples

# 1. Sort by purchase date, oldest first
Investment.sort_purchase_date_oldest
# => Longest held positions first

# 2. Sort by current value, largest first
Investment.sort_current_value_desc
# => Biggest positions by current market value

# 3. Sort by return amount (profit/loss)
Investment.sort_by_return_amount_desc
# => Best performing investments by dollar amount

# 4. Sort by return percentage
Investment.sort_by_return_percent_desc
# => Best performing investments by percentage gain

# 5. Sort by holding period
Investment.sort_by_holding_period_desc.limit(10)
# => 10 longest held positions

# 6. Sort by ticker symbol (alphabetical)
Investment.sort_ticker_asc_i
# => Alphabetical by stock symbol

# 7. Portfolio dashboard controller
class PortfolioController < ApplicationController
  def show
    @portfolio = current_user.portfolio
    @investments = @portfolio.investments

    # Calculate total value for weight calculations
    @total_value = @investments.sum(:current_value)

    # Apply sorting
    @investments = case params[:sort]
                   when 'value'
                     @investments.sort_current_value_desc
                   when 'return_amount'
                     @investments.sort_by_return_amount_desc
                   when 'return_percent'
                     @investments.sort_by_return_percent_desc
                   when 'holding_period'
                     @investments.sort_by_holding_period_desc
                   when 'ticker'
                     @investments.sort_ticker_asc_i
                   when 'weight'
                     @investments.sort_by_weight_desc
                   else
                     @investments.sort_current_value_desc
                   end

    # Performance metrics
    @total_return = @investments.sum(&:return_amount)
    @avg_return_percent = @investments.average(&:return_percentage)
  end

  def gainers_losers
    @top_gainers = Investment.where(portfolio: current_user.portfolio)
                             .sort_by_return_percent_desc
                             .limit(5)

    @top_losers = Investment.where(portfolio: current_user.portfolio)
                            .sort_by_return_percent_asc
                            .limit(5)
  end
end

# 8. Export for tax reporting (sorted by purchase date)
tax_report = Investment.where(portfolio: current_user.portfolio)
                       .where('purchase_date >= ?', Date.new(2024, 1, 1))
                       .sort_purchase_date_oldest
                       .map do |inv|
  {
    ticker: inv.ticker,
    purchase_date: inv.purchase_date,
    quantity: inv.quantity,
    purchase_price: inv.purchase_price,
    current_value: inv.current_value,
    return: inv.return_amount,
    holding_period: inv.holding_days
  }
end
```

---

## Database Compatibility

Sortable automatically adapts to your database, using native features when available and falling back to compatible SQL for older versions.

### NULL Handling Across Databases

| Database | NULLS LAST/FIRST Support | Sortable Behavior |
|----------|--------------------------|-------------------|
| **PostgreSQL** | ✅ Native (all versions) | Uses `NULLS LAST/FIRST` syntax |
| **MySQL/MariaDB** | ❌ Not supported | Emulates with `CASE WHEN field IS NULL` |
| **SQLite 3.30+** | ✅ Native | Uses `NULLS LAST/FIRST` syntax |
| **SQLite < 3.30** | ❌ Not supported | Emulates with `CASE WHEN field IS NULL` |

### Case-Insensitive Sorting

All databases support `LOWER()` function for case-insensitive sorting:

```ruby
# All databases generate equivalent SQL:
Article.sort_title_asc_i

# PostgreSQL: ORDER BY LOWER(title) ASC
# MySQL: ORDER BY LOWER(title) ASC
# SQLite: ORDER BY LOWER(title) ASC
```

### Automatic Adapter Detection

Sortable detects your database adapter automatically:

```ruby
# In your model (works across all databases):
class Product < ApplicationRecord
  include BetterModel
  sort :name, :price
end

# BetterModel detects the adapter and uses appropriate SQL:
# - PostgreSQL: Native NULLS LAST
# - MySQL: CASE emulation
# - SQLite: Native NULLS LAST (3.30+) or CASE emulation
```

### Cursor-Based Pagination for Large Datasets

```ruby
class Feed < ApplicationRecord
  include BetterModel

  sort :created_at, :id, :score, :engagement_rate

  # Cursor-based pagination for infinite scroll
  scope :after_cursor, ->(cursor_data) {
    if cursor_data.present?
      where("(created_at, id) < (?, ?)", cursor_data[:created_at], cursor_data[:id])
    else
      all
    end
  }

  scope :before_cursor, ->(cursor_data) {
    if cursor_data.present?
      where("(created_at, id) > (?, ?)", cursor_data[:created_at], cursor_data[:id])
    else
      all
    end
  }

  def cursor
    { created_at: created_at, id: id }
  end
end

# Controller with cursor pagination
class FeedsController < ApplicationController
  def index
    @feeds = Feed.all

    # Apply cursor pagination
    if params[:after_cursor].present?
      cursor_data = JSON.parse(params[:after_cursor]).symbolize_keys
      @feeds = @feeds.after_cursor(cursor_data)
    end

    # Stable sort with tie-breaker
    @feeds = @feeds
               .sort_created_at_newest
               .sort_id_desc # Tie-breaker for same timestamp
               .limit(params[:per_page] || 20)

    # Generate next cursor
    @next_cursor = @feeds.last&.cursor&.to_json if @feeds.any?

    render json: {
      items: @feeds,
      next_cursor: @next_cursor,
      has_more: @feeds.size == (params[:per_page] || 20).to_i
    }
  end
end
```

### Advanced NULL Handling and Collations

```ruby
class Document < ApplicationRecord
  include BetterModel

  sort :title, :priority, :due_date, :owner_name

  # PostgreSQL-specific collations
  if connection.adapter_name == "PostgreSQL"
    scope :sort_title_natural, -> {
      order(Arel.sql("title COLLATE \"en_US\""))
    }

    scope :sort_title_numeric, -> {
      # Natural sort for strings with numbers
      order(Arel.sql("REGEXP_REPLACE(title, '[^0-9]', '', 'g')::int NULLS LAST, title"))
    }
  end

  # Mixed NULL strategies
  scope :sort_by_priority_and_date, -> {
    # High priority first, then by due date (NULL dates last)
    sort_priority_desc_nulls_last.sort_due_date_asc_nulls_last
  }

  scope :sort_by_assigned_status, -> {
    # Assigned documents first (NOT NULL), then by priority
    order(Arel.sql("CASE WHEN owner_name IS NULL THEN 1 ELSE 0 END"))
      .sort_priority_desc
  }
end
```

### Testing Sortable Scopes

```ruby
# spec/models/article_spec.rb
require "rails_helper"

RSpec.describe Article, type: :model do
  describe "Sortable" do
    describe "sort scopes" do
      let!(:article_a) { create(:article, title: "Alpha", views_count: 100, published_at: 3.days.ago) }
      let!(:article_b) { create(:article, title: "Beta", views_count: 200, published_at: 2.days.ago) }
      let!(:article_c) { create(:article, title: "Gamma", views_count: 150, published_at: 1.day.ago) }

      it "sorts by title ascending" do
        results = Article.sort_title_asc
        expect(results.map(&:title)).to eq(["Alpha", "Beta", "Gamma"])
      end

      it "sorts by views descending" do
        results = Article.sort_views_count_desc
        expect(results.map(&:views_count)).to eq([200, 150, 100])
      end

      it "sorts by date newest first" do
        results = Article.sort_published_at_newest
        expect(results).to eq([article_c, article_b, article_a])
      end

      it "chains multiple sort criteria" do
        # First by views desc, then by title asc as tie-breaker
        results = Article.sort_views_count_desc.sort_title_asc
        expect(results.first).to eq(article_b) # 200 views
      end

      it "handles NULL values with nulls_last" do
        article_no_views = create(:article, title: "No Views", views_count: nil)

        results = Article.sort_views_count_desc_nulls_last
        expect(results.last).to eq(article_no_views)
      end

      it "handles case-insensitive sorting" do
        create(:article, title: "zebra")
        create(:article, title: "Apple")

        results = Article.sort_title_asc_i
        expect(results.first.title).to eq("Apple")
      end
    end
  end
end
```

---

## Best Practices

### 1. Use Semantic Names for Dates

Prefer `_newest` and `_oldest` over `_desc` and `_asc` for date fields:

```ruby
# ✅ Good: Clear intent
@articles = Article.sort_published_at_newest

# ⚠️ Acceptable but less clear
@articles = Article.sort_published_at_desc
```

### 2. Leverage Case-Insensitive for User-Facing Strings

Always use `_i` suffix for string fields shown to users:

```ruby
# ✅ Good: Natural alphabetical order
@products = Product.sort_name_asc_i

# ❌ Poor: Capital letters sort before lowercase
@products = Product.sort_name_asc
```

### 3. Handle NULLs Explicitly for Optional Fields

Use `_nulls_last` or `_nulls_first` for fields that can be NULL:

```ruby
# ✅ Good: Explicit NULL handling
@products = Product.sort_rating_desc_nulls_last

# ⚠️ Unclear: NULL behavior depends on database
@products = Product.sort_rating_desc
```

### 4. Chain Logically (Primary → Secondary → Tertiary)

Order your chains from most important to least:

```ruby
# ✅ Good: Clear precedence
Task.sort_priority_desc         # PRIMARY: High priority first
    .sort_due_date_asc_nulls_last  # SECONDARY: Earliest due dates
    .sort_title_asc_i           # TERTIARY: Alphabetical

# ❌ Poor: Confusing precedence
Task.sort_title_asc_i
    .sort_due_date_asc_nulls_last
    .sort_priority_desc
```

### 5. Define Selectively

Only make frequently-sorted fields sortable:

```ruby
# ✅ Good: Common sort fields
class Article < ApplicationRecord
  include BetterModel
  sort :title, :published_at, :view_count  # User-facing sorts
end

# ❌ Poor: Too many fields
class Article < ApplicationRecord
  include BetterModel
  sort :id, :title, :content, :status, :view_count,
       :published_at, :created_at, :updated_at, :slug,
       :author_id, :category_id  # Overkill
end
```

### 6. Validate Sort Parameters

Always validate user-provided sort parameters:

```ruby
# ✅ Good: Whitelist approach
ALLOWED_SORTS = {
  'newest' => :sort_published_at_newest,
  'oldest' => :sort_published_at_oldest,
  'popular' => :sort_view_count_desc
}.freeze

def apply_sort(scope)
  sort_method = ALLOWED_SORTS[params[:sort]]
  sort_method ? scope.public_send(sort_method) : scope
end

# ❌ Dangerous: Arbitrary public_send
def apply_sort(scope)
  scope.public_send(params[:sort])  # Security risk!
end
```

### 7. Provide Sensible Defaults

Always have a default sort order:

```ruby
# ✅ Good: Default fallback
def index
  @articles = Article.all
  @articles = apply_sort(@articles) || @articles.sort_published_at_newest
end

# ❌ Poor: No default
def index
  @articles = Article.all
  @articles = apply_sort(@articles)  # Could be unsorted
end
```

### 8. Use Introspection for Dynamic Sorting

Use `sortable_scope?` to validate dynamically:

```ruby
# ✅ Good: Safe dynamic sorting
sort_scope = params[:sort]&.to_sym

if sort_scope && Product.sortable_scope?(sort_scope)
  @products = Product.public_send(sort_scope)
else
  @products = Product.sort_name_asc_i
end
```

---

## Thread Safety

Sortable registries are designed to be thread-safe for use in concurrent Rails applications.

### Immutable Registries

All registries are frozen after initialization:

```ruby
class Article < ApplicationRecord
  include BetterModel
  sort :title, :view_count
end

# Registries are frozen Sets
Article.sortable_fields.frozen?   # => true
Article.sortable_scopes.frozen?   # => true

# Attempts to modify will raise FrozenError
Article.sortable_fields << :new_field  # => FrozenError
```

### Scopes Defined at Class Load Time

All sort scopes are defined once when the class is loaded:

```ruby
# When Rails loads Article model:
# 1. `sort :title, :view_count` is executed
# 2. All scopes are defined via `scope` method
# 3. Registries are populated and frozen
# 4. No runtime scope generation

# In production with multiple threads:
# - All threads share the same pre-defined scopes
# - No mutex locks needed
# - No race conditions
# - Zero performance penalty
```

### No Mutable Shared State

Sortable does not maintain any mutable shared state:

```ruby
# ✅ Thread-safe: Each query is independent
Thread.new { Article.sort_title_asc.to_a }
Thread.new { Article.sort_view_count_desc.to_a }
Thread.new { Article.sort_published_at_newest.to_a }

# Each thread gets its own ActiveRecord::Relation
# No shared mutable state
# No synchronization needed
```

---

## Performance Notes

### Zero Runtime Overhead

All sort scopes are compiled at class load time:

```ruby
# When Rails boots:
class Article < ApplicationRecord
  include BetterModel
  sort :title, :view_count, :published_at
end
# At this moment, all 16 scopes are defined via ActiveRecord's `scope` method
# No runtime metaprogramming
# No dynamic scope generation

# In production:
Article.sort_title_asc  # Direct scope call, no overhead
```

### Efficient SQL Generation

Uses Arel for optimal query building:

```ruby
# Sortable uses Arel internally:
Article.sort_title_asc
# Generates: SELECT * FROM articles ORDER BY title ASC

# Arel handles:
# - Proper SQL escaping
# - Database-specific syntax
# - Query optimization
```

### Registry Lookups are O(1)

Uses Set data structure for constant-time lookups:

```ruby
Article.sortable_field?(:title)      # O(1) Set lookup
Article.sortable_scope?(:sort_title_asc)  # O(1) Set lookup

# Even with 100 sortable fields:
# Lookup time remains constant
```

### Memory Footprint

Minimal memory usage per model:

```ruby
# For a model with 5 sortable fields:
# - sortable_fields: ~200 bytes (frozen Set with 5 symbols)
# - sortable_scopes: ~800 bytes (frozen Set with ~30 symbols)
# Total: ~1 KB per model class

# For 100 models: ~100 KB total
# Negligible in typical Rails application
```

---

## Key Takeaways

1. **Declare fields with `sort`** - Simple declaration auto-generates all necessary scopes
2. **Type-aware scopes** - Get the right scopes for strings, numbers, and dates automatically
3. **Semantic aliases** - Use `_newest`/`_oldest` for dates, `_i` for case-insensitive strings
4. **Explicit NULL handling** - Always use `_nulls_last`/`_nulls_first` for nullable fields
5. **Chain for multi-column** - Stack scopes for complex ordering with clear precedence
6. **Validate sort params** - Always whitelist allowed sort options in controllers
7. **Use introspection** - Check fields and scopes with `sortable_field?` and `sortable_scope?`
8. **Thread-safe by design** - Frozen registries, no mutable state, no race conditions
9. **Zero runtime overhead** - All scopes compiled at class load time
10. **Database agnostic** - Works across PostgreSQL, MySQL, and SQLite with automatic adaptation
