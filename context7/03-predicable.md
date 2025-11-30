# Predicable - Type-Aware Filtering System

Automatic query scope generation based on database column types. Introspects your schema and generates semantic filtering methods like `title_cont("Rails")`, `view_count_between(100, 500)`, `published_at_within(7.days)`.

**Requirements**: Rails 8.0+, Ruby 3.0+, ActiveRecord model
**Installation**: No migration required - include BetterModel and call `predicates`

**⚠️ Version 3.0.0 Compatible**: All error handling in this document uses standard Ruby exception patterns.
**⚠️ Important**: All predicates require explicit parameters - no defaults or parameterless shortcuts.

---

## Basic Setup

### Simple Predicate Registration

**Cosa fa**: Registers fields for automatic predicate generation

**Quando usarlo**: To enable filtering on specific model fields

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  # Register fields for filtering
  predicates :title, :status, :view_count, :published_at
end

# System introspects column types and generates scopes
# - title (string) → _eq, _cont, _start, _in, etc.
# - status (string) → _eq, _not_eq, _in, _not_in, etc.
# - view_count (integer) → _eq, _lt, _gt, _between, etc.
# - published_at (datetime) → _eq, _within, _between, etc.

# Usage (all require parameters)
Article.title_cont("Rails")
Article.status_eq("published")
Article.view_count_gt(100)
Article.published_at_within(7.days)
```

---

## Comparison Predicates

### Equality Comparisons

**Cosa fa**: Filters by exact match or inequality

**Quando usarlo**: For exact value matching

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :status, :view_count
end

# Exact match (parameter required)
Article.title_eq("Ruby on Rails")
Article.status_eq("published")
Article.view_count_eq(100)

# Inequality (parameter required)
Article.status_not_eq("draft")
Article.view_count_not_eq(0)

# Generated SQL
Article.title_eq("Ruby").to_sql
# => SELECT * FROM articles WHERE title = 'Ruby'
```

---

### Numeric Comparisons

**Cosa fa**: Filters with less than, greater than operators

**Quando usarlo**: For numeric and date range filtering

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel
  predicates :price, :stock_quantity, :created_at
end

# Greater than (parameter required)
Product.price_gt(50.00)
Product.stock_quantity_gt(0)

# Greater than or equal (parameter required)
Product.price_gteq(10.00)
Product.created_at_gteq(1.week.ago)

# Less than (parameter required)
Product.price_lt(100.00)
Product.stock_quantity_lt(10)

# Less than or equal (parameter required)
Product.price_lteq(50.00)
Product.created_at_lteq(Date.today)
```

---

### Range Predicates

**Cosa fa**: Filters using SQL BETWEEN operator

**Quando usarlo**: For value ranges (prices, dates, counts)

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :view_count, :published_at, :price
end

# Numeric ranges (both parameters required)
Article.view_count_between(100, 500)
Article.price_between(10.0, 50.0)

# Date ranges (both parameters required)
start_date = Date.new(2025, 1, 1)
end_date = Date.new(2025, 12, 31)
Article.published_at_between(start_date, end_date)

# Exclusion ranges (both parameters required)
Article.view_count_not_between(0, 10)

# Generated SQL
Article.view_count_between(100, 500).to_sql
# => SELECT * FROM articles WHERE view_count BETWEEN 100 AND 500
```

---

## Pattern Matching Predicates

### String Search - Case Sensitive

**Cosa fa**: Pattern matching with LIKE operator

**Quando usarlo**: For text search (case-sensitive)

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :content, :author_name
end

# Contains substring (parameter required)
Article.title_cont("Rails")
# => WHERE title LIKE '%Rails%'

# Starts with prefix (parameter required)
Article.title_start("Getting Started")
# => WHERE title LIKE 'Getting Started%'

# Ends with suffix (parameter required)
Article.title_end("Tutorial")
# => WHERE title LIKE '%Tutorial'

# Does not contain (parameter required)
Article.title_not_cont("Deprecated")
# => WHERE title NOT LIKE '%Deprecated%'
```

---

### String Search - Case Insensitive

**Cosa fa**: Case-insensitive pattern matching

**Quando usarlo**: For user-facing search features

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :content
end

# Case-insensitive contains (parameter required)
Article.title_i_cont("ruby")
# Matches: "Ruby", "RUBY", "ruby", "RuBy"
# => WHERE LOWER(title) LIKE '%ruby%'

# Case-insensitive not contains (parameter required)
Article.title_not_i_cont("archived")
# => WHERE LOWER(title) NOT LIKE '%archived%'

# Practical usage
search_term = params[:q]  # User input: "RAILS"
Article.title_i_cont(search_term)  # Finds any casing
```

---

## Array Predicates

### IN and NOT IN Operators

**Cosa fa**: Filters by multiple values with SQL IN

**Quando usarlo**: For multi-select filters

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :status, :author_id, :category_id
end

# Include multiple values (array parameter required)
Article.status_in(["draft", "published", "scheduled"])
Article.author_id_in([1, 2, 3, 4, 5])
Article.category_id_in([10, 20, 30])

# Exclude values (array parameter required)
Article.status_not_in(["archived", "deleted"])

# Dynamic filtering from params
statuses = params[:statuses]  # ["draft", "published"]
Article.status_in(statuses) if statuses.present?

# Generated SQL
Article.status_in(["draft", "published"]).to_sql
# => SELECT * FROM articles WHERE status IN ('draft', 'published')
```

---

## Presence Predicates

### Checking for NULL/Empty

**Cosa fa**: Filters by NULL or empty values

**Quando usarlo**: To find records with/without values

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :subtitle, :published_at
end

# Has value (boolean parameter REQUIRED)
Article.title_present(true)
# => WHERE title IS NOT NULL AND title != ''

# No value (boolean parameter REQUIRED)
Article.subtitle_blank(true)
# => WHERE subtitle IS NULL OR subtitle = ''

# Is NULL (boolean parameter REQUIRED)
Article.published_at_null(true)
# => WHERE published_at IS NULL

# Is NOT NULL (boolean parameter REQUIRED)
Article.published_at_null(false)
# => WHERE published_at IS NOT NULL

# Find complete published articles
Article
  .title_present(true)
  .content_present(true)
  .published_at_null(false)
```

---

## Date Convenience Predicate

### Within Duration

**Cosa fa**: Filters by relative time from now

**Quando usarlo**: For recent/last N days queries

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :published_at, :created_at, :updated_at
end

# Within duration (parameter required)
Article.published_at_within(7.days)   # Last 7 days
Article.published_at_within(2.weeks)  # Last 2 weeks
Article.created_at_within(30.days)    # Last 30 days
Article.updated_at_within(1.hour)     # Last hour

# Numeric shorthand (interpreted as days)
Article.published_at_within(7)   # Last 7 days
Article.created_at_within(30)    # Last 30 days

# For other date conveniences, use explicit comparisons
Article.published_at_gteq(Date.today.beginning_of_day)  # Today
Article.published_at_gteq(Date.today.beginning_of_week) # This week
Article.published_at_gteq(Date.today.beginning_of_month) # This month
```

---

## PostgreSQL Array Predicates

### Array Operators

**Cosa fa**: Advanced array operations (PostgreSQL only)

**Quando usarlo**: With PostgreSQL array columns

**Esempio**:
```ruby
# Migration
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :string, array: true, default: []
    add_index :articles, :tags, using: :gin
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel
  predicates :tags
end

# Overlaps: ANY of the tags (parameter required)
Article.tags_overlaps(['ruby', 'rails'])
# => Articles with ruby OR rails OR both
# SQL: WHERE tags && ARRAY['ruby','rails']

# Contains: ALL specified tags (parameter required)
Article.tags_contains('ruby')
# => Articles that include 'ruby' tag
# SQL: WHERE tags @> ARRAY['ruby']

# Contained by: Tags are subset (parameter required)
Article.tags_contained_by(['ruby', 'rails', 'python'])
# => Articles whose tags are ALL within this list
# SQL: WHERE tags <@ ARRAY[...]

# Practical usage
Article
  .tags_overlaps(['ruby', 'rails'])
  .status_eq("published")
  .view_count_gt(100)
```

---

## PostgreSQL JSONB Predicates

### JSONB Operators

**Cosa fa**: Queries structured data in JSONB columns (PostgreSQL only)

**Quando usarlo**: With PostgreSQL JSONB columns

**Esempio**:
```ruby
# Migration
class AddSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :settings, :jsonb, default: {}
    add_index :users, :settings, using: :gin
  end
end

# Model
class User < ApplicationRecord
  include BetterModel
  predicates :settings, :metadata
end

# Has key: Check if key exists (parameter required)
User.settings_has_key('email_notifications')
# => WHERE settings ? 'email_notifications'

# Has any key: ANY of the keys (array parameter required)
User.settings_has_any_key(['email', 'phone', 'sms'])
# => WHERE settings ?| ARRAY['email','phone','sms']

# Has all keys: ALL keys present (array parameter required)
User.settings_has_all_keys(['email', 'phone'])
# => WHERE settings ?& ARRAY['email','phone']

# JSONB contains: Specific key-value pairs (hash parameter required)
User.settings_jsonb_contains({active: true})
# => WHERE settings @> '{"active":true}'

User.settings_jsonb_contains({theme: 'dark', notifications: true})
# => Both conditions must match

# Practical usage
User
  .settings_has_key('email_notifications')
  .settings_jsonb_contains({active: true})
  .created_at_within(30.days)
```

---

## Predicate Generation by Type

### Understanding Column Types

**Cosa fa**: Different predicates for different column types

**Quando usarlo**: To understand what predicates are available

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  # String fields → 14 predicates each
  predicates :title, :status  # _eq, _cont, _i_cont, _in, etc.

  # Numeric fields → 11 predicates each
  predicates :view_count, :price  # _eq, _lt, _gt, _between, etc.

  # Boolean fields → 3 predicates each
  predicates :featured, :published  # _eq, _not_eq, _present

  # Date fields → 13 predicates each
  predicates :published_at, :created_at  # _eq, _within, _between, etc.

  # PostgreSQL array → 7 predicates
  predicates :tags  # _overlaps, _contains, _contained_by, etc.

  # PostgreSQL JSONB → 6 predicates
  predicates :settings  # _has_key, _has_any_key, _jsonb_contains, etc.
end

# Check what's generated
Article.predicable_fields
# => #<Set: {:title, :status, :view_count, ...}>

Article.predicable_scopes
# => #<Set: {:title_eq, :title_cont, :view_count_gt, ...}>
```

---

## Custom Complex Predicates

### Basic Complex Predicate

**Cosa fa**: Defines custom filtering logic with parameters

**Quando usarlo**: For business-specific filters not covered by standard predicates

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :view_count, :published_at, :status

  # No parameters
  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 1000, 24.hours.ago)
  end

  # With parameters
  register_complex_predicate :recent_popular do |days = 7, min_views = 100|
    where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
  end
end

# Usage
Article.trending  # Default logic
Article.recent_popular  # Default params (7 days, 100 views)
Article.recent_popular(14, 500)  # Custom params (14 days, 500 views)

# Chainable with other predicates
Article
  .recent_popular(7, 100)
  .status_eq("published")
  .featured_eq(true)
```

---

### Complex Predicate with JOIN

**Cosa fa**: Custom predicates with JOIN logic

**Quando usarlo**: For filtering based on associations

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  belongs_to :author
  has_many :comments

  predicates :title, :status

  # JOIN with association
  register_complex_predicate :with_active_author do
    joins(:author).where(authors: {active: true})
  end

  # Aggregation with HAVING
  register_complex_predicate :with_many_comments do |min_comments = 10|
    joins(:comments)
      .group("articles.id")
      .having("COUNT(comments.id) >= ?", min_comments)
  end
end

# Usage
Article.with_active_author
Article.with_many_comments(20)

# Chaining
Article
  .with_active_author
  .with_many_comments(5)
  .status_eq("published")
```

---

### Business Rule Predicates

**Cosa fa**: Encapsulates business logic in named predicates

**Quando usarlo**: For reusable business rules

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  predicates :name, :price, :stock, :sale_price

  # In stock check
  register_complex_predicate :in_stock do
    where("stock > 0")
  end

  # On sale logic
  register_complex_predicate :on_sale do
    where("sale_price IS NOT NULL AND sale_price < price")
  end

  # Low stock alert
  register_complex_predicate :low_stock do |threshold = 10|
    where("stock > 0 AND stock <= ?", threshold)
  end

  # Price range with conversion
  register_complex_predicate :price_range_usd do |min, max, rate = 1.0|
    where("price * ? BETWEEN ? AND ?", rate, min, max)
  end
end

# Usage
Product.in_stock
Product.on_sale
Product.low_stock(5)
Product.price_range_usd(10, 100, 1.2)  # With exchange rate
```

---

## Query Chaining

### Multi-Criteria Filtering

**Cosa fa**: Combines multiple predicates into complex queries

**Quando usarlo**: For advanced filtering scenarios

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  predicates :title, :status, :view_count, :published_at, :featured
end

# Basic chaining
Article
  .status_eq("published")
  .view_count_gt(100)
  .published_at_within(30.days)
  .limit(10)

# Search with filters
Article
  .title_i_cont(params[:query])
  .status_in(["published", "featured"])
  .view_count_gteq(50)
  .published_at_within(60.days)
  .order(view_count: :desc)

# Complex date filtering
Article
  .published_at_lt(Time.current)
  .view_count_between(100, 1000)
  .status_not_in(["archived", "deleted"])
  .order(published_at: :desc)

# With ActiveRecord methods
Article
  .title_cont("Ruby")
  .published_at_within(30.days)
  .where.not(author_id: nil)
  .includes(:author, :comments)
  .limit(20)
```

---

## Integration with Searchable

### Using Predicates in Searchable

**Cosa fa**: Complex predicates as security policies

**Quando usarlo**: To enforce access control in search

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :published_at, :view_count

  register_complex_predicate :safe_for_public do
    where(status: "published")
      .where("published_at <= ?", Time.current)
      .where("archived_at IS NULL")
  end

  searchable do
    default_order [:published_at_desc]
    per_page 25

    # Use complex predicate as security policy
    security :public_only, [:safe_for_public]
    security :status_required, [:status_eq]
  end
end

# Controller
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      params.permit(:title_cont, :view_count_gteq),
      securities: [:public_only]
    )

    render json: @articles
  end
end
```

---

## Introspection Methods

### Checking Predicates

**Cosa fa**: Runtime introspection of registered predicates

**Quando usarlo**: For building dynamic UIs or validation

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at

  register_complex_predicate :trending do
    where("view_count >= 500")
  end
end

# Check if field has predicates
Article.predicable_field?(:title)  # => true
Article.predicable_field?(:foo)    # => false

# Check if scope exists
Article.predicable_scope?(:title_cont)  # => true
Article.predicable_scope?(:title_foo)   # => false

# Check complex predicate
Article.complex_predicate?(:trending)  # => true
Article.complex_predicate?(:unknown)   # => false

# Get all fields (returns frozen Set)
Article.predicable_fields
# => #<Set: {:title, :status, :view_count, :published_at}>

# Get all scopes (returns frozen Set)
Article.predicable_scopes
# => #<Set: {:title_eq, :title_cont, :view_count_gt, ...}>

# Get complex predicates (returns frozen Hash)
Article.complex_predicates_registry
# => {:trending => #<Proc:0x...>}
```

---

### Dynamic Filter Validation

**Cosa fa**: Validates filter parameters dynamically

**Quando usarlo**: For API parameter validation

**Esempio**:
```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Validate and apply filters
    params[:filters]&.each do |field, predicate, value|
      scope_name = "#{field}_#{predicate}".to_sym

      if Article.predicable_scope?(scope_name)
        @articles = @articles.public_send(scope_name, value)
      else
        Rails.logger.warn "Invalid filter: #{scope_name}"
      end
    end

    render json: @articles
  end
end

# Request example
# GET /articles?filters[][]=title&filters[][]=cont&filters[][]=Rails
# GET /articles?filters[][]=status&filters[][]=eq&filters[][]=published
```

---

## Real-World Use Cases

### Blog Platform

**Cosa fa**: Advanced article filtering and search

**Quando usarlo**: Content management systems

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :content, :status, :view_count, :published_at, :author_id

  register_complex_predicate :trending do
    where("view_count >= ? AND published_at >= ?", 500, 7.days.ago)
  end

  register_complex_predicate :popular do |days = 30, min_views = 1000|
    where("published_at >= ? AND view_count >= ?", days.days.ago, min_views)
  end
end

# Controller
class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Text search
    @articles = @articles.title_i_cont(params[:q]) if params[:q].present?

    # Status filter
    @articles = @articles.status_eq(params[:status]) if params[:status].present?

    # Date range
    case params[:date_range]
    when "today"
      @articles = @articles.published_at_gteq(Date.today.beginning_of_day)
    when "week"
      @articles = @articles.published_at_within(7.days)
    when "month"
      @articles = @articles.published_at_within(30.days)
    end

    # Minimum views
    if params[:min_views].present?
      @articles = @articles.view_count_gteq(params[:min_views])
    end

    # Pagination
    @articles = @articles.page(params[:page]).per(20)

    render json: @articles
  end

  def trending
    @articles = Article.trending.status_eq("published").limit(10)
    render json: @articles
  end
end
```

---

### E-commerce Product Catalog

**Cosa fa**: Product filtering with stock and pricing

**Quando usarlo**: Online stores

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  predicates :name, :description, :price, :stock, :category, :brand, :featured

  register_complex_predicate :in_stock do
    where("stock > 0")
  end

  register_complex_predicate :low_stock do |threshold = 10|
    where("stock > 0 AND stock <= ?", threshold)
  end

  register_complex_predicate :best_sellers do |days = 30|
    joins(:order_items)
      .where("order_items.created_at >= ?", days.days.ago)
      .group("products.id")
      .order("COUNT(order_items.id) DESC")
  end
end

# Controller
class ProductsController < ApplicationController
  def index
    @products = Product.in_stock

    # Category filter
    if params[:category].present?
      @products = @products.category_eq(params[:category])
    end

    # Brand filter
    if params[:brands].present?
      @products = @products.brand_in(params[:brands])
    end

    # Price range
    if params[:min_price] || params[:max_price]
      min = params[:min_price]&.to_f || 0
      max = params[:max_price]&.to_f || Float::INFINITY
      @products = @products.price_between(min, max)
    end

    # Search
    if params[:q].present?
      @products = @products.name_i_cont(params[:q])
    end

    # Sorting
    case params[:sort]
    when "price_asc"
      @products = @products.order(price: :asc)
    when "price_desc"
      @products = @products.order(price: :desc)
    else
      @products = @products.order(created_at: :desc)
    end

    @products = @products.page(params[:page]).per(24)

    render json: @products
  end

  def low_stock_alert
    @products = Product.low_stock(10)
    render json: @products
  end
end
```

---

### User Management

**Cosa fa**: User filtering with activity tracking

**Quando usarlo**: Admin panels and user analytics

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  predicates :email, :username, :status, :created_at, :last_login_at, :role

  register_complex_predicate :active_users do |days = 30|
    where("last_login_at >= ?", days.days.ago)
  end

  register_complex_predicate :dormant_users do |days = 90|
    where("last_login_at < ? OR last_login_at IS NULL", days.days.ago)
  end

  register_complex_predicate :premium_tier do |tier = "premium"|
    joins(:subscription)
      .where(subscriptions: {tier: tier, active: true})
  end
end

# Admin controller
class Admin::UsersController < Admin::BaseController
  def index
    @users = User.all

    # Status filter
    @users = @users.status_eq(params[:status]) if params[:status].present?

    # Role filter
    @users = @users.role_in(params[:roles]) if params[:roles].present?

    # Activity filter
    case params[:activity]
    when "active"
      @users = @users.active_users(30)
    when "dormant"
      @users = @users.dormant_users(90)
    end

    # Registration date
    if params[:registered_after].present?
      @users = @users.created_at_gteq(params[:registered_after])
    end

    # Search
    if params[:q].present?
      @users = @users.where("email LIKE ? OR username LIKE ?",
                            "%#{params[:q]}%", "%#{params[:q]}%")
    end

    @users = @users.page(params[:page]).per(50)

    render json: @users
  end

  def inactive_cleanup
    @users = User.dormant_users(180).status_eq("inactive")
    render json: { count: @users.count, users: @users }
  end
end
```

---

### Event Management

**Cosa fa**: Event filtering with availability and dates

**Quando usarlo**: Booking systems

**Esempio**:
```ruby
class Event < ApplicationRecord
  include BetterModel

  predicates :title, :start_date, :capacity, :registered_count, :category

  register_complex_predicate :available_upcoming do
    where("start_date > ? AND registered_count < capacity", Time.current)
  end

  register_complex_predicate :selling_fast do
    where("registered_count >= capacity * 0.9")
  end

  register_complex_predicate :within_dates do |start_date, end_date|
    where(start_date: start_date..end_date)
  end
end

# Controller
class EventsController < ApplicationController
  def index
    @events = Event.available_upcoming

    # Category filter
    if params[:category].present?
      @events = @events.category_eq(params[:category])
    end

    # Date range
    if params[:month].present?
      start_date = Date.parse("#{params[:month]}-01")
      end_date = start_date.end_of_month
      @events = @events.within_dates(start_date, end_date)
    end

    # Search
    if params[:q].present?
      @events = @events.title_i_cont(params[:q])
    end

    @events = @events.order(start_date: :asc).page(params[:page]).per(20)

    render json: @events
  end

  def selling_fast
    @events = Event.selling_fast.available_upcoming.limit(10)
    render json: @events
  end
end
```

---

## Best Practices

### Always Use Parameters

**Cosa fa**: All predicates require explicit parameters

**Quando usarlo**: Always - no defaults exist

**Esempio**:
```ruby
# Good - explicit parameters
Article.title_cont("Rails")
Article.view_count_gt(100)
Article.published_at_within(7.days)
Article.featured_eq(true)

# Bad - will raise error (no parameters)
# Article.title_cont      # ❌ ArgumentError
# Article.view_count_gt   # ❌ ArgumentError
# Article.featured        # ❌ NoMethodError
```

---

### Use Case-Insensitive Search

**Cosa fa**: Case-insensitive for user-facing search

**Quando usarlo**: For search boxes and filters

**Esempio**:
```ruby
# Good - case-insensitive for users
Article.title_i_cont(params[:q])

# Bad - case-sensitive (misses results)
Article.title_cont(params[:q])  # Won't find "ruby" if searching "Ruby"
```

---

### Validate Complex Predicate Parameters

**Cosa fa**: Prevents errors with parameter validation

**Quando usarlo**: In all complex predicates with parameters

**Esempio**:
```ruby
# Good - validate parameters
register_complex_predicate :price_range do |min, max|
  raise ArgumentError, "min must be positive" if min.to_f < 0
  raise ArgumentError, "max must be positive" if max.to_f < 0
  raise ArgumentError, "min must be less than max" if min.to_f >= max.to_f

  where("price >= ? AND price <= ?", min, max)
end

# Bad - no validation
register_complex_predicate :price_range do |min, max|
  where("price >= ? AND price <= ?", min, max)  # Can fail silently
end
```

---

### Prevent SQL Injection

**Cosa fa**: Uses parameter binding for security

**Quando usarlo**: Always with user input

**Esempio**:
```ruby
# Good - parameter binding
register_complex_predicate :search_safe do |term|
  sanitized = ActiveRecord::Base.sanitize_sql_like(term)
  where("title LIKE ?", "%#{sanitized}%")
end

# Good - Arel (best practice)
register_complex_predicate :search_arel do |term|
  sanitized = ActiveRecord::Base.sanitize_sql_like(term)
  where(arel_table[:title].matches("%#{sanitized}%"))
end

# Bad - SQL injection vulnerability
register_complex_predicate :search_bad do |term|
  where("title LIKE '%#{term}%'")  # ❌ NEVER DO THIS!
end
```

---

### Chain Predicates Efficiently

**Cosa fa**: Builds efficient queries through chaining

**Quando usarlo**: For complex filtering

**Esempio**:
```ruby
# Good - chained queries
@articles = Article
  .status_eq("published")
  .view_count_gt(100)
  .published_at_within(30.days)
  .order(view_count: :desc)
  .limit(10)

# All combined in single SQL query

# Bad - multiple database calls
@articles = Article.status_eq("published").to_a
@articles = @articles.select { |a| a.view_count > 100 }
@articles = @articles.select { |a| a.published_at >= 30.days.ago }
@articles = @articles.sort_by(&:view_count).reverse.take(10)
```

---

### Use Introspection for Dynamic UIs

**Cosa fa**: Validates filters dynamically

**Quando usarlo**: For API parameter validation

**Esempio**:
```ruby
# Good - validate before applying
def apply_filters(relation, filters)
  filters.each do |field, predicate, value|
    scope_name = "#{field}_#{predicate}".to_sym

    if relation.class.predicable_scope?(scope_name)
      relation = relation.public_send(scope_name, value)
    else
      Rails.logger.warn "Invalid filter: #{scope_name}"
    end
  end

  relation
end

# Bad - no validation
def apply_filters(relation, filters)
  filters.each do |field, predicate, value|
    relation = relation.public_send("#{field}_#{predicate}", value)  # Can raise
  end
end
```

---

## Summary

**Core Features**:
- **Automatic Scope Generation**: Introspects column types
- **Type-Aware**: Different predicates for strings, numbers, dates, arrays, JSONB
- **Chainable**: Returns ActiveRecord::Relation
- **Thread-Safe**: Frozen registries
- **Zero Runtime Overhead**: Compiled at class load

**Predicate Categories**:
- **Comparison**: `_eq`, `_not_eq`, `_lt`, `_lteq`, `_gt`, `_gteq`
- **Range**: `_between`, `_not_between`
- **Pattern**: `_cont`, `_i_cont`, `_start`, `_end`, `_matches`
- **Array**: `_in`, `_not_in`
- **Presence**: `_present`, `_blank`, `_null`
- **Date**: `_within` (convenience)
- **PostgreSQL Array**: `_overlaps`, `_contains`, `_contained_by`
- **PostgreSQL JSONB**: `_has_key`, `_has_any_key`, `_has_all_keys`, `_jsonb_contains`

**Key Methods**:
- `predicates :field1, :field2` - Register fields
- `register_complex_predicate :name do...end` - Custom predicates
- `predicable_field?(:name)` - Check if field registered
- `predicable_scope?(:name)` - Check if scope exists
- `complex_predicate?(:name)` - Check if complex predicate exists
- `predicable_fields` - All registered fields
- `predicable_scopes` - All generated scopes
- `complex_predicates_registry` - All complex predicates

**Important**: All predicates require explicit parameters - no defaults or parameterless shortcuts.

**Thread-safe**, **database-portable**, **integrated with Searchable**.
