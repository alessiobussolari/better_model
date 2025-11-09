# Repositable - Repository Pattern for BetterModel

## Overview

Repositable provides infrastructure for implementing the Repository Pattern in Rails applications using BetterModel. Unlike other BetterModel concerns that are included in models, Repositable provides a `BaseRepository` class that you inherit from to create repository classes for your models.

**Key Features:**
- **Clean Architecture**: Separates data access logic from business logic
- **Testability**: Easy to mock and test in isolation
- **BetterModel Integration**: Seamless integration with Searchable, Predicable, and Sortable
- **Flexible Querying**: Unified search interface with predicates, pagination, and ordering
- **CRUD Operations**: Standard create, read, update, delete methods
- **Eager Loading**: Built-in support for includes and joins to prevent N+1 queries
- **Custom Business Logic**: Encapsulate complex queries and domain logic

**When to Use Repositable:**
- You want to separate data access from business logic
- You have complex queries that you want to encapsulate
- You need to improve testability by mocking data access
- You want a consistent interface for querying across your application
- You're building a service-oriented architecture
- You need to aggregate data from multiple models

**When NOT to Use Repositable:**
- Simple CRUD operations that don't benefit from abstraction
- Prototyping or MVPs where speed is more important than architecture
- Very small applications (< 5 models)
- When ActiveRecord's interface is sufficient

## Repository Pattern

The Repository Pattern acts as an abstraction layer between your application's business logic and data access logic. It provides a collection-like interface for accessing domain objects.

**Benefits:**
1. **Separation of Concerns**: Data access logic is isolated from business logic
2. **Testability**: Easy to swap real repositories with test doubles
3. **Consistency**: Unified interface for data access across the application
4. **Flexibility**: Easy to change data source without affecting business logic
5. **Readability**: Domain-specific query methods are more readable than raw SQL/ActiveRecord

**Architecture:**
```
Controller/Service Layer
        ↓
  Repository Layer  ← You are here
        ↓
   Model Layer (ActiveRecord)
        ↓
     Database
```

## Basic Usage

### Creating a Repository

**Step 1: Generate the repository**

```bash
rails g better_model:repository Article
```

This creates:
- `app/repositories/application_repository.rb` (if it doesn't exist)
- `app/repositories/article_repository.rb`

**Step 2: Define custom methods**

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  def recent(days: 7)
    search({ created_at_gteq: days.days.ago })
  end

  def popular(min_views: 100)
    search({ view_count_gteq: min_views })
  end
end
```

**Step 3: Use in controllers or services**

```ruby
# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  def index
    @repo = ArticleRepository.new
    @articles = @repo.published.page(params[:page])
  end

  def show
    @repo = ArticleRepository.new
    @article = @repo.find(params[:id])
  end
end
```

### ApplicationRepository

The `ApplicationRepository` is a base class for all repositories in your application:

```ruby
# app/repositories/application_repository.rb
class ApplicationRepository < BetterModel::Repositable::BaseRepository
  # Add application-wide repository methods here

  def find_active(id)
    search({ id_eq: id, status_eq: "active" }, limit: 1)
  end

  def paginated_search(filters, page: 1)
    search(filters, page: page, per_page: 25)
  end
end
```

## BaseRepository API

### Search Method

The core method for querying. Integrates with BetterModel's Searchable, Predicable, and Sortable concerns.

```ruby
search(predicates = {}, page: 1, per_page: 20, includes: [], joins: [],
       order: nil, order_scope: nil, limit: :default)
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `predicates` | Hash | `{}` | Filter conditions using BetterModel predicates |
| `page` | Integer | `1` | Page number for pagination (1-indexed) |
| `per_page` | Integer | `20` | Records per page |
| `includes` | Array | `[]` | Associations to eager load |
| `joins` | Array | `[]` | Associations to join |
| `order` | String/Hash | `nil` | SQL ORDER BY clause |
| `order_scope` | Hash | `nil` | BetterModel sort scope (e.g., `{ field: :created_at, direction: :desc }`) |
| `limit` | Integer/Symbol/nil | `:default` | Result limit (see Limit Options below) |

**Returns:**
- `ActiveRecord::Relation` - When using pagination or limit > 1
- `ActiveRecord::Base` - When limit is 1 (returns single record or nil)

**Limit Options:**
- `limit: 1` - Returns single record (`.first`)
- `limit: 5` - Returns relation with `.limit(5)`
- `limit: nil` - Returns all records (no pagination)
- `limit: :default` - Uses pagination (default behavior)

**Examples:**

```ruby
repo = ArticleRepository.new

# Basic search with predicates
articles = repo.search({ status_eq: "published" })

# Search with pagination
articles = repo.search({ status_eq: "published" }, page: 2, per_page: 50)

# Single record
article = repo.search({ id_eq: 1 }, limit: 1)

# All records (no pagination)
all_articles = repo.search({}, limit: nil)

# With eager loading
articles = repo.search({ status_eq: "published" }, includes: [:author, :comments])

# With ordering
articles = repo.search({}, order_scope: { field: :published_at, direction: :desc })

# Complex search
articles = repo.search(
  {
    status_eq: "published",
    view_count_gteq: 100,
    published_at_within: 7.days
  },
  page: 1,
  per_page: 25,
  includes: [:author],
  order_scope: { field: :published_at, direction: :desc }
)
```

### CRUD Methods

All standard CRUD operations are delegated to the model:

```ruby
repo = ArticleRepository.new

# Find by ID
article = repo.find(1)
# => Article instance or raises ActiveRecord::RecordNotFound

# Find by attributes
article = repo.find_by(title: "Ruby Guide")
# => Article instance or nil

# Create
article = repo.create(title: "New Article", status: "draft")
# => Article instance (persisted)

# Create with validations
article = repo.create!(title: "New Article", status: "draft")
# => Article instance or raises ActiveRecord::RecordInvalid

# Build (not persisted)
article = repo.build(title: "Draft")
# => Article instance (new record)

# Update
article = repo.update(1, title: "Updated Title")
# => Article instance or raises errors

# Delete
repo.delete(1)
# => Deleted Article instance
```

### ActiveRecord Delegates

Common ActiveRecord methods are available:

```ruby
repo = ArticleRepository.new

# Where clause
articles = repo.where(status: "published")
# => ActiveRecord::Relation

# All records
articles = repo.all
# => ActiveRecord::Relation

# Count
count = repo.count
# => Integer

# Exists?
exists = repo.exists?(1)
# => Boolean
```

## Custom Repository Methods

Repository methods should encapsulate business logic and provide a domain-specific API.

### Simple Query Methods

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  def drafts
    search({ status_eq: "draft" })
  end

  def archived
    search({ status_eq: "archived" })
  end
end

# Usage
repo = ArticleRepository.new
published_articles = repo.published
```

### Parameterized Query Methods

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def by_author(author_id)
    search({ author_id_eq: author_id })
  end

  def by_category(category)
    search({ category_eq: category })
  end

  def recent(days: 7)
    search({ created_at_gteq: days.days.ago })
  end

  def popular(min_views: 100)
    search({ view_count_gteq: min_views })
  end
end

# Usage
repo = ArticleRepository.new
author_articles = repo.by_author(current_user.id)
recent_articles = repo.recent(days: 30)
popular_articles = repo.popular(min_views: 500)
```

### Composite Query Methods

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published_recent(days: 7)
    search({
      status_eq: "published",
      published_at_gteq: days.days.ago
    })
  end

  def popular_published(min_views: 100)
    search({
      status_eq: "published",
      view_count_gteq: min_views
    }, order_scope: { field: :view_count, direction: :desc })
  end

  def trending
    search({
      published_at_gteq: 7.days.ago,
      view_count_gteq: 50
    }, order_scope: { field: :view_count, direction: :desc })
  end
end
```

### Methods with Business Logic

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def publish_ready
    search({
      status_eq: "draft",
      scheduled_for_lteq: Time.current
    })
  end

  def needs_review
    search({
      status_eq: "draft",
      created_at_lteq: 24.hours.ago
    })
  end

  def expires_soon(hours: 48)
    search({
      status_eq: "published",
      expires_at_between: [Time.current, hours.hours.from_now]
    })
  end
end
```

### Chainable Methods

Repository methods return ActiveRecord relations, so they can be chained:

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  def with_author
    published.includes(:author)
  end

  def ordered_by_date
    published.order(published_at: :desc)
  end
end

# Usage
repo = ArticleRepository.new
articles = repo.published
              .where("view_count > ?", 100)
              .includes(:comments)
              .page(1)
```

## Integration with BetterModel

Repositable seamlessly integrates with other BetterModel concerns.

### With Searchable

If your model uses `Searchable`, the repository's `search()` method will automatically use the model's `search()` method:

```ruby
# Model with Searchable
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at
  sort :title, :view_count, :published_at

  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc]
  end
end

# Repository automatically uses Article.search()
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def popular_published
    # Uses Article.search() internally
    search({
      status_eq: "published",
      view_count_gteq: 100
    })
  end
end
```

### With Predicable

Use all Predicable predicates in your repository methods:

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # String predicates
  def by_title(title)
    search({ title_cont: title })
  end

  def starts_with(prefix)
    search({ title_start: prefix })
  end

  # Numeric predicates
  def min_views(count)
    search({ view_count_gteq: count })
  end

  def view_range(min, max)
    search({ view_count_between: [min, max] })
  end

  # Date predicates
  def published_after(date)
    search({ published_at_gteq: date })
  end

  def published_within(duration)
    search({ published_at_within: duration })
  end

  # Boolean predicates
  def featured
    search({ featured_eq: true })
  end
end
```

### With Sortable

Use Sortable scopes for ordering:

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def recent_first
    search({}, order_scope: { field: :created_at, direction: :desc })
  end

  def oldest_first
    search({}, order_scope: { field: :created_at, direction: :asc })
  end

  def most_viewed
    search({}, order_scope: { field: :view_count, direction: :desc })
  end

  def alphabetical
    search({}, order_scope: { field: :title, direction: :asc })
  end
end
```

### With Multiple Concerns

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at
  sort :title, :view_count, :published_at

  archivable do
    skip_archived_by_default true
  end

  stateable do
    state :draft, initial: true
    state :published
    state :archived
  end
end

class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Uses Predicable + Sortable
  def trending
    search({
      status_eq: "published",
      view_count_gteq: 100,
      published_at_within: 7.days
    }, order_scope: { field: :view_count, direction: :desc })
  end

  # Uses Archivable
  def active
    Article.not_archived
  end

  # Uses Stateable
  def by_state(state)
    Article.where(state: state)
  end
end
```

## Advanced Features

### Pagination Strategies

**Default Pagination (offset-based):**

```ruby
repo = ArticleRepository.new

# Page 1: records 1-20
page1 = repo.search({}, page: 1, per_page: 20)

# Page 2: records 21-40
page2 = repo.search({}, page: 2, per_page: 20)
```

**Custom Pagination with Kaminari/Will_Paginate:**

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def paginated_search(filters, page: 1, per_page: 25)
    search(filters, limit: nil).page(page).per(per_page)
  end
end
```

**Keyset Pagination (for large datasets):**

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def keyset_paginate(last_id: nil, per_page: 20)
    scope = Article.all
    scope = scope.where("id > ?", last_id) if last_id
    scope.order(:id).limit(per_page)
  end
end
```

### Eager Loading Patterns

**Prevent N+1 Queries:**

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Bad: Will cause N+1
  def published
    search({ status_eq: "published" })
  end

  # Good: Eager load associations
  def published_with_author
    search({ status_eq: "published" }, includes: [:author])
  end

  # Better: Conditional eager loading
  def published_full
    search(
      { status_eq: "published" },
      includes: [:author, :comments, :tags]
    )
  end
end
```

**Complex Eager Loading:**

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def with_recent_comments
    search(
      {},
      includes: {
        comments: :author,
        author: :profile
      }
    )
  end

  def for_api
    search(
      {},
      includes: [:author, :category],
      joins: [:author], # For filtering/ordering
      order: "authors.name ASC"
    )
  end
end
```

### Complex Queries

**OR Conditions:**

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def search_text(query)
    search({
      or: [
        { title_i_cont: query },
        { content_i_cont: query }
      ]
    })
  end

  def urgent
    search({
      or: [
        { status_eq: "critical" },
        { expires_at_lteq: 1.hour.from_now }
      ]
    })
  end
end
```

**Aggregations:**

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def statistics
    {
      total: count,
      published: Article.where(status: "published").count,
      drafts: Article.where(status: "draft").count,
      avg_views: Article.average(:view_count).to_f
    }
  end

  def views_by_category
    Article.group(:category).sum(:view_count)
  end
end
```

**Subqueries:**

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def with_popular_comments
    Article.where(
      id: Comment.where("comments.likes > ?", 10)
                 .select(:article_id)
                 .distinct
    )
  end
end
```

### Transaction Support

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def publish_batch(article_ids)
    Article.transaction do
      article_ids.each do |id|
        article = find(id)
        article.update!(status: "published", published_at: Time.current)
      end
    end
  end

  def create_with_tags(attributes, tag_names)
    Article.transaction do
      article = create!(attributes)
      tag_names.each do |name|
        article.tags.create!(name: name)
      end
      article
    end
  end
end
```

## Generator Usage

### Basic Generation

```bash
# Generate repository for Article model
rails g better_model:repository Article

# Creates:
# app/repositories/application_repository.rb (if doesn't exist)
# app/repositories/article_repository.rb
```

### Generator Options

```bash
# Custom path
rails g better_model:repository Article --path app/services/repositories

# Skip ApplicationRepository creation
rails g better_model:repository Article --skip-base

# With namespace
rails g better_model:repository Article --namespace Admin

# Pretend mode (dry run)
rails g better_model:repository Article --pretend
```

### Generated Code

The generator creates a repository with:

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Add your custom query methods here
  #
  # Example methods:
  # def active
  #   search({ status_eq: "active" })
  # end
  #
  # def recent(days: 7)
  #   search({ created_at_gteq: days.days.ago }, order_scope: { field: :created_at, direction: :desc })
  # end
  #
  # def find_with_details(id)
  #   search({ id_eq: id }, includes: [:associated_records], limit: 1)
  # end
end
```

If the model uses BetterModel, the generator includes comments with available predicates and sort scopes.

## Error Handling

### Exception Classes

Repositories delegate to ActiveRecord, so standard ActiveRecord exceptions apply:

```ruby
repo = ArticleRepository.new

# ActiveRecord::RecordNotFound
begin
  article = repo.find(999999)
rescue ActiveRecord::RecordNotFound => e
  # Handle not found
end

# ActiveRecord::RecordInvalid
begin
  article = repo.create!(title: nil) # If title is required
rescue ActiveRecord::RecordInvalid => e
  # Handle validation errors
  errors = e.record.errors
end

# ActiveRecord::RecordNotSaved
begin
  article = Article.new(title: nil)
  article.save!
rescue ActiveRecord::RecordNotSaved => e
  # Handle save failure
end
```

### BetterModel Exceptions

When using Searchable, additional exceptions may be raised with full Sentry-compatible error data:

```ruby
# BetterModel::Errors::Searchable::InvalidPredicateError
begin
  repo.search({ invalid_predicate: "value" })
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  # Error attributes
  e.predicate_scope       # => :invalid_predicate
  e.value                 # => "value"
  e.available_predicates  # => [:title_eq, :title_cont, ...]
  e.model_class           # => Article

  # Sentry-compatible data
  e.tags     # => {error_category: 'invalid_predicate', module: 'searchable', predicate: 'invalid_predicate'}
  e.context  # => {model_class: 'Article'}
  e.extra    # => {predicate_scope: :invalid_predicate, value: 'value', available_predicates: [...]}

  # Error message
  e.message  # => "Invalid predicate scope: :invalid_predicate. Available predicable scopes: title_eq, title_cont, ..."
end

# BetterModel::Errors::Searchable::InvalidOrderError
begin
  repo.search({}, orders: [:invalid_sort_scope])
rescue BetterModel::Errors::Searchable::InvalidOrderError => e
  # Error attributes
  e.order_scope         # => :invalid_sort_scope
  e.available_orders    # => [:sort_title_asc, :sort_title_desc, ...]
  e.model_class         # => Article

  # Sentry-compatible data
  e.tags     # => {error_category: 'invalid_order', module: 'searchable', order: 'invalid_sort_scope'}
  e.context  # => {model_class: 'Article'}
  e.extra    # => {order_scope: :invalid_sort_scope, available_orders: [...]}

  # Error message
  e.message  # => "Invalid order scope: :invalid_sort_scope. Available sort scopes: sort_title_asc, sort_title_desc, ..."
end
```

### Best Practices for Error Handling

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def find_or_nil(id)
    find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def safe_create(attributes)
    create!(attributes)
  rescue ActiveRecord::RecordInvalid => e
    { success: false, errors: e.record.errors }
  else
    { success: true }
  end

  def bulk_update(ids, attributes)
    Article.transaction do
      ids.each { |id| update(id, attributes) }
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Bulk update failed: #{e.message}"
    raise
  end
end
```

## Real-World Examples

### Blog Application

```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  def by_category(category)
    search({ category_eq: category, status_eq: "published" })
  end

  def trending(days: 7)
    search({
      status_eq: "published",
      published_at_gteq: days.days.ago,
      view_count_gteq: 100
    }, order_scope: { field: :view_count, direction: :desc })
  end

  def featured
    search({
      status_eq: "published",
      featured_eq: true
    }, order_scope: { field: :published_at, direction: :desc })
  end

  def search_articles(query, category: nil)
    filters = {
      or: [
        { title_i_cont: query },
        { content_i_cont: query }
      ],
      status_eq: "published"
    }
    filters[:category_eq] = category if category.present?
    search(filters)
  end
end

# Controller
class ArticlesController < ApplicationController
  def index
    @repo = ArticleRepository.new
    @articles = @repo.published.page(params[:page])
  end

  def trending
    @repo = ArticleRepository.new
    @articles = @repo.trending(days: 7)
  end

  def search
    @repo = ArticleRepository.new
    @articles = @repo.search_articles(
      params[:q],
      category: params[:category]
    ).page(params[:page])
  end
end
```

### E-commerce Application

```ruby
class ProductRepository < ApplicationRepository
  def model_class = Product

  def active
    search({ status_eq: "active", stock_gteq: 1 })
  end

  def by_category(category_id)
    search({ category_id_eq: category_id, status_eq: "active" })
  end

  def on_sale
    search({
      status_eq: "active",
      discount_gt: 0
    }, order_scope: { field: :discount, direction: :desc })
  end

  def low_stock(threshold: 10)
    search({
      status_eq: "active",
      stock_lteq: threshold
    }, order_scope: { field: :stock, direction: :asc })
  end

  def price_range(min, max)
    search({
      status_eq: "active",
      price_between: [min, max]
    })
  end

  def search_products(query, filters = {})
    base_filters = {
      or: [
        { name_i_cont: query },
        { description_i_cont: query },
        { sku_eq: query }
      ],
      status_eq: "active"
    }
    search(base_filters.merge(filters))
  end
end

# Service
class ProductSearchService
  def initialize
    @repo = ProductRepository.new
  end

  def search(query, category: nil, price_min: nil, price_max: nil, page: 1)
    filters = {}
    filters[:category_id_eq] = category if category

    if price_min && price_max
      filters[:price_between] = [price_min, price_max]
    elsif price_min
      filters[:price_gteq] = price_min
    elsif price_max
      filters[:price_lteq] = price_max
    end

    @repo.search_products(query, filters).page(page)
  end
end
```

### API Application

```ruby
class UserRepository < ApplicationRepository
  def model_class = User

  def active_users
    search({ status_eq: "active" })
  end

  def by_email(email)
    search({ email_eq: email }, limit: 1)
  end

  def by_role(role)
    search({ role_eq: role })
  end

  def recent_signups(days: 30)
    search({
      created_at_gteq: days.days.ago
    }, order_scope: { field: :created_at, direction: :desc })
  end

  def for_export
    search({}, limit: nil, includes: [:profile, :roles])
  end
end

# API Controller
class Api::V1::UsersController < Api::V1::BaseController
  def index
    @repo = UserRepository.new
    @users = @repo.active_users
                  .page(params[:page])
                  .per(params[:per_page] || 25)

    render json: @users, meta: pagination_meta(@users)
  end

  def search
    @repo = UserRepository.new
    @users = @repo.search(
      permitted_search_params,
      page: params[:page],
      per_page: params[:per_page] || 25
    )

    render json: @users
  end

  private

  def permitted_search_params
    params.require(:search).permit(:email_cont, :role_eq, :status_eq)
  end
end
```

## Best Practices

### ✅ Do

**Use repositories for complex queries:**
```ruby
class ArticleRepository < ApplicationRepository
  def popular_recent
    search({
      status_eq: "published",
      published_at_gteq: 7.days.ago,
      view_count_gteq: 100
    }, order_scope: { field: :view_count, direction: :desc })
  end
end
```

**Encapsulate business logic:**
```ruby
class OrderRepository < ApplicationRepository
  def needs_fulfillment
    search({
      status_eq: "paid",
      fulfilled_eq: false,
      created_at_lteq: 24.hours.ago
    })
  end
end
```

**Use meaningful method names:**
```ruby
class UserRepository < ApplicationRepository
  def active_admins
    search({ status_eq: "active", role_eq: "admin" })
  end

  def recent_signups(days: 7)
    search({ created_at_gteq: days.days.ago })
  end
end
```

**Keep repositories thin:**
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Good: Simple query encapsulation
  def published
    search({ status_eq: "published" })
  end

  # Avoid: Complex business logic (use services instead)
  # def publish_and_notify(id)
  #   article = find(id)
  #   article.update!(status: "published")
  #   NotificationService.notify_subscribers(article)
  # end
end
```

**Test repositories independently:**
```ruby
RSpec.describe ArticleRepository do
  it "returns published articles" do
    create(:article, status: "published")
    create(:article, status: "draft")

    repo = described_class.new
    expect(repo.published.count).to eq(1)
  end
end
```

### ❌ Don't

**Don't create repositories for every model:**
```ruby
# Bad: Unnecessary abstraction for simple CRUD
class TagRepository < ApplicationRepository
  def model_class = Tag
end

# Good: Use Tag model directly for simple operations
Tag.all
Tag.find_by(name: "ruby")
```

**Don't bypass repositories:**
```ruby
# Bad: Direct model access in controllers
class ArticlesController < ApplicationController
  def index
    @articles = Article.where(status: "published")
  end
end

# Good: Use repository
class ArticlesController < ApplicationController
  def index
    @repo = ArticleRepository.new
    @articles = @repo.published
  end
end
```

**Don't put too much logic in repositories:**
```ruby
# Bad: Repository doing too much
class ArticleRepository < ApplicationRepository
  def publish_with_notifications(id)
    article = find(id)
    article.update!(status: "published")
    send_to_subscribers(article)
    post_to_social_media(article)
    update_search_index(article)
  end
end

# Good: Use service objects
class ArticlePublishService
  def initialize(repo: ArticleRepository.new)
    @repo = repo
  end

  def publish(id)
    article = @repo.find(id)
    article.update!(status: "published")
    NotificationService.notify(article)
    SocialMediaService.post(article)
    SearchIndexService.update(article)
  end
end
```

**Don't ignore BetterModel features:**
```ruby
# Bad: Manual predicate building
class ArticleRepository < ApplicationRepository
  def by_title(title)
    Article.where("title LIKE ?", "%#{title}%")
  end
end

# Good: Use Predicable predicates
class ArticleRepository < ApplicationRepository
  def by_title(title)
    search({ title_cont: title })
  end
end
```

## Performance Considerations

### Query Optimization

**Use selective eager loading:**
```ruby
class ArticleRepository < ApplicationRepository
  def for_index
    search({}, includes: [:author]) # Only what's needed
  end

  def for_show(id)
    search({ id_eq: id }, includes: [:author, :comments, :tags], limit: 1)
  end
end
```

**Avoid loading unnecessary columns:**
```ruby
class ArticleRepository < ApplicationRepository
  def titles_only
    Article.select(:id, :title, :published_at)
  end

  def for_export
    # Don't load large text columns for exports
    Article.select(Article.column_names - ["content"])
  end
end
```

### Indexing

Ensure database indexes support your repository queries:

```ruby
class ArticleRepository < ApplicationRepository
  # This query needs indexes on: status, published_at, view_count
  def trending
    search({
      status_eq: "published",
      published_at_gteq: 7.days.ago,
      view_count_gteq: 100
    })
  end
end

# Migration
add_index :articles, [:status, :published_at, :view_count]
```

### Caching

```ruby
class ArticleRepository < ApplicationRepository
  def trending(days: 7)
    Rails.cache.fetch("trending_articles/#{days}", expires_in: 1.hour) do
      search({
        status_eq: "published",
        published_at_gteq: days.days.ago,
        view_count_gteq: 100
      }, order_scope: { field: :view_count, direction: :desc })
      .limit(10)
      .to_a
    end
  end
end
```

### Batch Processing

```ruby
class ArticleRepository < ApplicationRepository
  def process_in_batches(batch_size: 1000)
    Article.find_each(batch_size: batch_size) do |article|
      yield article
    end
  end

  def bulk_update(ids, attributes)
    Article.where(id: ids).update_all(attributes)
  end
end
```

## Thread Safety

The `BaseRepository` class is thread-safe:

- Repository instances can be created in any thread
- The `search()` method is stateless
- ActiveRecord connections are managed by Rails' connection pool

**Safe Usage:**

```ruby
# Thread-safe: Each thread creates its own instance
Thread.new do
  repo = ArticleRepository.new
  articles = repo.published
end

# Thread-safe: Readonly operations
repo = ArticleRepository.new
10.times.map do |i|
  Thread.new { repo.find(i) }
end.each(&:join)
```

**Not Thread-Safe:**

```ruby
# Not safe: Shared mutable state
class ArticleRepository < ApplicationRepository
  attr_accessor :current_user # Mutable instance variable

  def published_by_current_user
    search({ author_id_eq: @current_user.id })
  end
end
```

## See Also

- [Searchable Documentation](searchable.md) - Unified search interface
- [Predicable Documentation](predicable.md) - Filter predicates
- [Sortable Documentation](sortable.md) - Sorting scopes
- [Repository Pattern Examples](examples/14_repositable.md) - Practical examples
- [Repository Pattern Guide (Context7)](../context7/11_repositable.md) - Complete guide
