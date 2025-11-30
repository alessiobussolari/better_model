# Repositable - Repository Pattern for Better Model

Repository Pattern implementation that encapsulates data access logic and integrates seamlessly with BetterModel's Searchable, Predicable, and Sortable concerns. Perfect for clean architecture and improved testability.

**Requirements**: Rails 8.0+, Ruby 3.0+, BetterModel with Predicable/Searchable
**Installation**: No migration required - inherit from `BaseRepository` or use generator

**⚠️ Version 3.0.0 Compatible**: All error handling in this document uses standard Ruby exception patterns.

---

## Basic Setup

### Simple Repository

**Cosa fa**: Creates a repository for a model with default methods

**Quando usarlo**: When you need to encapsulate data access for a specific model

**Esempio**:
```ruby
class ArticleRepository < BetterModel::Repositable::BaseRepository
  def model_class = Article
end

# Usage
repo = ArticleRepository.new
articles = repo.search({ status_eq: "published" })
article = repo.find(1)
```

---

### Using Generator

**Cosa fa**: Generates a repository class for a model

**Quando usarlo**: Quick setup for new repositories

**Esempio**:
```bash
# Generate repository
rails g better_model:repository Article

# Creates app/repositories/article_repository.rb
```

```ruby
# Generated file
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Add custom methods here
end
```

---

### ApplicationRepository Base

**Cosa fa**: Provides base class for all application repositories

**Quando usarlo**: For application-wide repository methods

**Esempio**:
```ruby
# app/repositories/application_repository.rb
class ApplicationRepository < BetterModel::Repositable::BaseRepository
  # Shared methods for all repositories

  def with_eager_loading(*associations)
    search({}, includes: associations)
  end
end

# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article
end
```

---

## Search Method

### Basic Search with Predicates

**Cosa fa**: Searches using BetterModel predicates

**Quando usarlo**: For filtered queries

**Esempio**:
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article
end

repo = ArticleRepository.new

# Basic search
repo.search({ status_eq: "published" })

# Multiple predicates
repo.search({
  status_eq: "published",
  created_at_gteq: 7.days.ago
})

# With OR conditions
repo.search({
  or: [
    { status_eq: "published" },
    { status_eq: "featured" }
  ]
})
```

---

### Search with Pagination

**Cosa fa**: Searches with page and per_page options

**Quando usarlo**: For paginated lists

**Esempio**:
```ruby
repo = ArticleRepository.new

# Default pagination (page 1, 20 per page)
repo.search({ status_eq: "published" })

# Custom pagination
repo.search(
  { status_eq: "published" },
  page: 2,
  per_page: 50
)

# Access pagination metadata
results = repo.search({ status_eq: "published" }, page: 1, per_page: 25)
results.current_page  # => 1
results.total_pages   # => 4
results.total_count   # => 100
```

---

### Search with Ordering

**Cosa fa**: Searches with custom ordering

**Quando usarlo**: For sorted results

**Esempio**:
```ruby
repo = ArticleRepository.new

# Using sort scope (Sortable integration)
repo.search(
  { status_eq: "published" },
  order_scope: { field: :published_at, direction: :desc }
)

# Using SQL ORDER BY
repo.search(
  { status_eq: "published" },
  order: "created_at DESC"
)

# Multiple orderings
repo.search(
  { status_eq: "published" },
  order: { published_at: :desc, title: :asc }
)
```

---

### Search with Eager Loading

**Cosa fa**: Prevents N+1 queries by eager loading associations

**Quando usarlo**: When accessing associated records

**Esempio**:
```ruby
repo = ArticleRepository.new

# Eager load single association
repo.search(
  { status_eq: "published" },
  includes: [:author]
)

# Eager load multiple associations
repo.search(
  { status_eq: "published" },
  includes: [:author, :comments, :tags]
)

# Usage (no N+1 queries)
articles = repo.search({ status_eq: "published" }, includes: [:author])
articles.each do |article|
  puts article.author.name  # No additional query
end
```

---

### Search with Limit

**Cosa fa**: Limits the number of results

**Quando usarlo**: For top-N queries or single record retrieval

**Esempio**:
```ruby
repo = ArticleRepository.new

# Single record (returns ActiveRecord object or nil)
article = repo.search({ id_eq: 1 }, limit: 1)

# Limited results (returns relation)
top_articles = repo.search(
  { status_eq: "published" },
  limit: 10,
  order_scope: { field: :view_count, direction: :desc }
)

# All records (no pagination)
all_articles = repo.search({ status_eq: "published" }, limit: nil)

# Default pagination behavior
articles = repo.search({ status_eq: "published" }, limit: :default)
```

---

## CRUD Operations

### Finding Records

**Cosa fa**: Finds records by ID or attributes

**Quando usarlo**: For record retrieval

**Esempio**:
```ruby
repo = ArticleRepository.new

# Find by ID
article = repo.find(1)

# Find by ID (raises if not found)
article = repo.find!(1)

# Find by attributes
article = repo.find_by(slug: "rails-guide")

# Check existence
repo.exists?(1)  # => true/false
```

---

### Creating Records

**Cosa fa**: Creates new records

**Quando usarlo**: For record creation

**Esempio**:
```ruby
repo = ArticleRepository.new

# Create with attributes
article = repo.create(
  title: "Rails Guide",
  content: "...",
  status: "draft"
)

# Create with validation (raises on error)
article = repo.create!(
  title: "Rails Guide",
  content: "...",
  status: "draft"
)

# Build without saving
article = repo.build(title: "Draft Article")
article.content = "..."
article.save
```

---

### Updating Records

**Cosa fa**: Updates existing records

**Quando usarlo**: For record modification

**Esempio**:
```ruby
repo = ArticleRepository.new

# Update by ID
repo.update(1, title: "Updated Title", status: "published")

# Update with validation (raises on error)
repo.update!(1, title: "Updated Title")

# Update via find
article = repo.find(1)
article.update!(status: "published", published_at: Time.current)
```

---

### Deleting Records

**Cosa fa**: Deletes records by ID

**Quando usarlo**: For record removal

**Esempio**:
```ruby
repo = ArticleRepository.new

# Delete by ID
repo.delete(1)

# Delete multiple
repo.delete(1, 2, 3)

# Destroy (runs callbacks)
article = repo.find(1)
article.destroy
```

---

## Custom Query Methods

### Status Queries

**Cosa fa**: Encapsulates status-based queries

**Quando usarlo**: For common status filters

**Esempio**:
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search(
      { status_eq: "published" },
      order_scope: { field: :published_at, direction: :desc }
    )
  end

  def drafts
    search({ status_eq: "draft" })
  end

  def featured
    search({ status_eq: "published", featured_eq: true })
  end
end

# Usage
repo = ArticleRepository.new
published_articles = repo.published
draft_articles = repo.drafts
```

---

### Category/Association Queries

**Cosa fa**: Filters by associations

**Quando usarlo**: For relationship-based queries

**Esempio**:
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def by_author(author_id)
    search(
      { author_id_eq: author_id },
      order_scope: { field: :created_at, direction: :desc }
    )
  end

  def by_category(category_id)
    search({ category_id_eq: category_id, status_eq: "published" })
  end
end

# Usage
repo = ArticleRepository.new
author_articles = repo.by_author(123)
category_articles = repo.by_category(456)
```

---

### Time-Based Queries

**Cosa fa**: Filters by date/time ranges

**Quando usarlo**: For recent, trending, or scheduled content

**Esempio**:
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def recent(days: 7)
    search(
      {
        status_eq: "published",
        published_at_gteq: days.days.ago
      },
      order_scope: { field: :published_at, direction: :desc }
    )
  end

  def trending(days: 7, min_views: 100)
    search(
      {
        status_eq: "published",
        published_at_gteq: days.days.ago,
        view_count_gteq: min_views
      },
      order_scope: { field: :view_count, direction: :desc }
    )
  end
end

# Usage
repo = ArticleRepository.new
recent_articles = repo.recent(days: 30)
trending_articles = repo.trending(days: 7, min_views: 500)
```

---

### Search/Filter Methods

**Cosa fa**: Implements text search and filtering

**Quando usarlo**: For user-facing search features

**Esempio**:
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def search_articles(query)
    search({
      or: [
        { title_i_cont: query },
        { content_i_cont: query }
      ],
      status_eq: "published"
    })
  end

  def price_range(min, max)
    search({ price_between: [min, max] })
  end
end

# Usage
repo = ArticleRepository.new
results = repo.search_articles("rails tutorial")
affordable = repo.price_range(10, 50)
```

---

## Real-World Use Cases

### E-commerce Product Repository

**Cosa fa**: Product catalog with inventory management

**Quando usarlo**: E-commerce applications

**Esempio**:
```ruby
class ProductRepository < ApplicationRepository
  def model_class = Product

  def active
    search({ status_eq: "active", stock_quantity_gt: 0 })
  end

  def low_stock(threshold: 10)
    search({
      status_eq: "active",
      stock_quantity_lteq: threshold,
      stock_quantity_gt: 0
    })
  end

  def on_sale
    search({ status_eq: "active", sale_price_present: true })
  end

  def update_stock(product_id, quantity_change)
    product = find(product_id)
    new_quantity = product.stock_quantity + quantity_change
    raise ArgumentError, "Insufficient stock" if new_quantity < 0
    update(product_id, stock_quantity: new_quantity)
  end
end

# Usage
repo = ProductRepository.new
products = repo.active
low_stock_items = repo.low_stock(threshold: 5)
repo.update_stock(123, -1)  # Decrease by 1
```

---

### Blog Article Management

**Cosa fa**: Content management with publishing workflow

**Quando usarlo**: Blog or CMS applications

**Esempio**:
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search(
      { status_eq: "published" },
      order_scope: { field: :published_at, direction: :desc }
    )
  end

  def by_author(author_id, status: nil)
    filters = { author_id_eq: author_id }
    filters[:status_eq] = status if status
    search(filters, order_scope: { field: :created_at, direction: :desc })
  end

  def popular(limit: 10)
    search(
      { status_eq: "published" },
      limit: limit,
      order_scope: { field: :view_count, direction: :desc }
    )
  end

  def statistics
    {
      total: count,
      published: Article.where(status: "published").count,
      drafts: Article.where(status: "draft").count,
      total_views: Article.sum(:view_count)
    }
  end
end

# Usage
repo = ArticleRepository.new
articles = repo.published
author_drafts = repo.by_author(123, status: "draft")
popular_articles = repo.popular(limit: 5)
stats = repo.statistics
```

---

### User Management Repository

**Cosa fa**: User queries with authentication

**Quando usarlo**: User management systems

**Esempio**:
```ruby
class UserRepository < ApplicationRepository
  def model_class = User

  def active_users
    search({ status_eq: "active" })
  end

  def by_email(email)
    search({ email_eq: email }, limit: 1)
  end

  def admins
    search({ role_eq: "admin", status_eq: "active" })
  end

  def inactive_users(days: 90)
    search({
      last_sign_in_at_lteq: days.days.ago,
      status_eq: "active"
    })
  end

  def authenticate(email, password)
    user = by_email(email)
    return nil unless user&.authenticate(password)

    update(user.id, last_sign_in_at: Time.current)
    user.reload
  end
end

# Usage
repo = UserRepository.new
active = repo.active_users
user = repo.by_email("user@example.com")
authenticated = repo.authenticate("user@example.com", "password")
```

---

### Order Processing Repository

**Cosa fa**: Order management with states

**Quando usarlo**: E-commerce order processing

**Esempio**:
```ruby
class OrderRepository < ApplicationRepository
  def model_class = Order

  def by_user(user_id)
    search(
      { user_id_eq: user_id },
      order_scope: { field: :created_at, direction: :desc }
    )
  end

  def pending
    search({ status_eq: "pending" })
  end

  def needs_fulfillment
    search({ status_eq: "paid", created_at_lteq: 24.hours.ago })
  end

  def statistics(start_date: 30.days.ago, end_date: Time.current)
    orders = search({ created_at_between: [start_date, end_date] }, limit: nil)
    {
      total_orders: orders.count,
      total_revenue: orders.sum(:total_amount),
      avg_order_value: orders.average(:total_amount).to_f.round(2),
      by_status: orders.group(:status).count
    }
  end
end

# Usage
repo = OrderRepository.new
user_orders = repo.by_user(123)
pending_orders = repo.pending
stats = repo.statistics(start_date: 7.days.ago)
```

---

### Multi-Tenant Repository

**Cosa fa**: Automatic tenant scoping for all queries

**Quando usarlo**: Multi-tenant SaaS applications

**Esempio**:
```ruby
# Base tenant-aware repository
class TenantAwareRepository < ApplicationRepository
  def initialize(tenant_id)
    super()
    @tenant_id = tenant_id
  end

  def search(predicates = {}, **options)
    predicates = predicates.merge(tenant_id_eq: @tenant_id)
    super(predicates, **options)
  end

  def create(attributes)
    super(attributes.merge(tenant_id: @tenant_id))
  end
end

# Model-specific repository
class ArticleRepository < TenantAwareRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end
end

# Usage
tenant_repo = ArticleRepository.new(current_tenant.id)
articles = tenant_repo.published  # Automatically scoped to tenant
new_article = tenant_repo.create(title: "Test", content: "...")
```

---

### API Repository with Pagination

**Cosa fa**: JSON API with pagination metadata

**Quando usarlo**: REST API endpoints

**Esempio**:
```ruby
class ApiRepository < ApplicationRepository
  def paginated_search(filters: {}, page: 1, per_page: 25)
    results = search(filters, page: page, per_page: per_page)

    {
      data: results,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: results.total_count,
        total_pages: results.total_pages
      }
    }
  end
end

# Controller usage
class Api::V1::ArticlesController < Api::V1::BaseController
  def index
    @repo = ArticleRepository.new
    response = @repo.paginated_search(
      filters: { status_eq: "published" },
      page: params[:page] || 1,
      per_page: params[:per_page] || 25
    )

    render json: response[:data], meta: response[:meta]
  end
end
```

---

### Dashboard/Analytics Repository

**Cosa fa**: Multi-model data aggregation

**Quando usarlo**: Reporting and analytics

**Esempio**:
```ruby
class DashboardRepository < ApplicationRepository
  def model_class = Order

  def overview(start_date: 30.days.ago, end_date: Time.current)
    {
      sales: sales_overview(start_date, end_date),
      orders: orders_overview(start_date, end_date),
      customers: customers_overview(start_date, end_date)
    }
  end

  def sales_overview(start_date, end_date)
    orders = Order.where(
      created_at: start_date..end_date,
      status: ["paid", "shipped", "delivered"]
    )

    {
      total_revenue: orders.sum(:total_amount),
      avg_order_value: orders.average(:total_amount).to_f.round(2),
      orders_count: orders.count
    }
  end

  def orders_overview(start_date, end_date)
    orders = Order.where(created_at: start_date..end_date)
    {
      total: orders.count,
      by_status: orders.group(:status).count
    }
  end

  def customers_overview(start_date, end_date)
    {
      new_customers: User.where(created_at: start_date..end_date).count,
      active_customers: User.joins(:orders)
                           .where(orders: { created_at: start_date..end_date })
                           .distinct
                           .count
    }
  end
end

# Usage
repo = DashboardRepository.new
dashboard_data = repo.overview(start_date: 7.days.ago)
```

---

## Advanced Patterns

### Transaction Support

**Cosa fa**: Ensures atomicity for multi-step operations

**Quando usarlo**: When multiple operations must succeed or fail together

**Esempio**:
```ruby
class OrderRepository < ApplicationRepository
  def model_class = Order

  def create_with_items(user:, items:, shipping_address:)
    Order.transaction do
      order = create!(
        user: user,
        shipping_address: shipping_address,
        status: "pending"
      )

      total = 0
      items.each do |item|
        order_item = order.order_items.create!(
          product_id: item[:product_id],
          quantity: item[:quantity],
          price: item[:price]
        )
        total += order_item.quantity * order_item.price
      end

      update(order.id, total_amount: total)
      order.reload
    end
  end
end

# Usage (all or nothing)
repo = OrderRepository.new
order = repo.create_with_items(
  user: current_user,
  items: [{ product_id: 1, quantity: 2, price: 29.99 }],
  shipping_address: "123 Main St"
)
```

---

### Batch Operations

**Cosa fa**: Performs operations on multiple records

**Quando usarlo**: For bulk updates or processing

**Esempio**:
```ruby
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def publish_batch(article_ids)
    Article.transaction do
      article_ids.each do |id|
        article = find(id)
        article.publish!  # Stateable transition
      end
    end
  end

  def archive_old_articles(days: 365)
    old_articles = search({
      status_eq: "published",
      published_at_lteq: days.days.ago
    }, limit: nil)

    Article.transaction do
      old_articles.find_each do |article|
        article.archive!
      end
    end
  end
end

# Usage
repo = ArticleRepository.new
repo.publish_batch([1, 2, 3, 4, 5])
repo.archive_old_articles(days: 730)
```

---

### Complex Joins and Aggregations

**Cosa fa**: Performs complex queries with joins

**Quando usarlo**: For advanced reporting and analytics

**Esempio**:
```ruby
class ReportRepository < ApplicationRepository
  def model_class = Order

  def top_customers(start_date:, end_date:, limit: 10)
    User.joins(:orders)
        .where(orders: { created_at: start_date..end_date, status: "paid" })
        .group("users.id", "users.email")
        .order("SUM(orders.total_amount) DESC")
        .limit(limit)
        .pluck("users.email", "SUM(orders.total_amount)", "COUNT(orders.id)")
        .map { |email, total, count| { email: email, total: total, count: count } }
  end

  def top_products(start_date:, end_date:, limit: 10)
    OrderItem.joins(:order, :product)
             .where(orders: { created_at: start_date..end_date, status: "paid" })
             .group("products.id", "products.name")
             .order("SUM(order_items.quantity) DESC")
             .limit(limit)
             .pluck("products.name", "SUM(order_items.quantity)")
  end
end

# Usage
repo = ReportRepository.new
top_customers = repo.top_customers(
  start_date: 30.days.ago,
  end_date: Time.current,
  limit: 10
)
```

---

## Testing Repositories

### Basic Repository Test

**Cosa fa**: Tests repository methods independently

**Quando usarlo**: For TDD and ensuring repository behavior

**Esempio**:
```ruby
# spec/repositories/article_repository_spec.rb
RSpec.describe ArticleRepository, type: :repository do
  let(:repo) { described_class.new }

  describe "#published" do
    it "returns only published articles" do
      create(:article, status: "published")
      create(:article, status: "draft")

      results = repo.published
      expect(results.count).to eq(1)
      expect(results.first.status).to eq("published")
    end
  end

  describe "#by_author" do
    it "returns articles by specific author" do
      author = create(:user)
      create(:article, author: author)
      create(:article, author: create(:user))

      results = repo.by_author(author.id)
      expect(results.count).to eq(1)
      expect(results.first.author).to eq(author)
    end
  end
end
```

---

### Mocking Repositories

**Cosa fa**: Mocks repository in controller/service tests

**Quando usarlo**: For isolated unit tests

**Esempio**:
```ruby
# spec/controllers/articles_controller_spec.rb
RSpec.describe ArticlesController, type: :controller do
  let(:repo) { instance_double(ArticleRepository) }

  before do
    allow(ArticleRepository).to receive(:new).and_return(repo)
  end

  describe "GET #index" do
    it "fetches published articles" do
      articles = [build_stubbed(:article)]
      allow(repo).to receive(:published).and_return(articles)

      get :index

      expect(repo).to have_received(:published)
      expect(assigns(:articles)).to eq(articles)
    end
  end
end
```

---

## Best Practices

### Use Repositories for Complex Queries

**Cosa fa**: Encapsulates complex business logic in repositories

**Quando usarlo**: Always for non-trivial queries

**Esempio**:
```ruby
# Good - encapsulated in repository
class ArticleRepository < ApplicationRepository
  def trending(days: 7, min_views: 100)
    search({
      status_eq: "published",
      published_at_gteq: days.days.ago,
      view_count_gteq: min_views
    }, order_scope: { field: :view_count, direction: :desc })
  end
end

# Bad - complex query in controller
# ArticlesController
@articles = Article.where(status: "published")
                  .where("published_at >= ?", 7.days.ago)
                  .where("view_count >= ?", 100)
                  .order(view_count: :desc)
```

---

### Don't Create Unnecessary Repositories

**Cosa fa**: Uses model directly for simple operations

**Quando usarlo**: For simple models with basic CRUD

**Esempio**:
```ruby
# Bad - unnecessary repository
class TagRepository < ApplicationRepository
  def model_class = Tag
end

# Good - use model directly
Tag.all
Tag.find_by(name: "ruby")
Tag.create!(name: "rails")
```

---

### Keep Repositories Focused

**Cosa fa**: One repository per model/bounded context

**Quando usarlo**: Always - maintains single responsibility

**Esempio**:
```ruby
# Good - focused on Article
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  def by_category(category_id)
    search({ category_id_eq: category_id })
  end
end

# Bad - mixing concerns
class ContentRepository < ApplicationRepository
  def articles
    Article.all
  end

  def posts
    Post.all
  end

  def pages
    Page.all
  end
end
```

---

### Use Services for Complex Business Logic

**Cosa fa**: Separates data access from business logic

**Quando usarlo**: For operations involving multiple models or external services

**Esempio**:
```ruby
# Bad - too much logic in repository
class ArticleRepository < ApplicationRepository
  def publish_and_notify(id)
    article = find(id)
    article.update!(status: "published")
    send_emails(article)
    post_to_social(article)
    update_search_index(article)
  end
end

# Good - use service object
class PublishArticleService
  def initialize(repo: ArticleRepository.new)
    @repo = repo
  end

  def call(article_id)
    article = @repo.find(article_id)
    article.publish!  # Stateable transition
    NotificationService.notify(article)
    SocialMediaService.post(article)
    SearchIndexService.index(article)
  end
end
```

---

### Use Meaningful Method Names

**Cosa fa**: Names describe business intent, not implementation

**Quando usarlo**: Always - improves readability

**Esempio**:
```ruby
# Good - describes intent
def needs_review
  search({ status_eq: "draft", created_at_lteq: 24.hours.ago })
end

def inactive_users(days: 90)
  search({ last_sign_in_at_lteq: days.days.ago })
end

# Bad - generic names
def query1
  search({ status_eq: "draft" })
end

def get_some_data
  search({})
end
```

---

### Always Eager Load Associations

**Cosa fa**: Prevents N+1 queries

**Quando usarlo**: When accessing associated records

**Esempio**:
```ruby
# Good - eager loading
def with_details
  search(
    { status_eq: "published" },
    includes: [:author, :comments, :tags]
  )
end

# Usage (no N+1)
articles = repo.with_details
articles.each do |article|
  puts article.author.name  # No extra query
  puts article.comments.count  # No extra query
end

# Bad - N+1 queries
articles = repo.search({ status_eq: "published" })
articles.each do |article|
  puts article.author.name  # N queries!
end
```

---

## Summary

**Core Concepts**:
- **Repository Pattern**: Mediates between domain and data layers
- **BaseRepository**: Core class providing search() and CRUD methods
- **ApplicationRepository**: Base for all application repositories
- **Integration**: Seamless with Predicable, Sortable, Searchable

**Key Methods**:
- `search(predicates, **options)` - Main query method
- `find(id)` / `find_by(attributes)` - Record retrieval
- `create(attributes)` / `create!(attributes)` - Record creation
- `update(id, attributes)` - Record updates
- `delete(id)` - Record deletion
- `where(conditions)` / `all` / `count` - ActiveRecord delegates

**Options for search()**:
- `page`, `per_page` - Pagination
- `includes`, `joins` - Eager loading
- `order`, `order_scope` - Sorting
- `limit` - Result limiting

**When to Use**:
- Complex queries needing encapsulation
- Service-oriented architecture
- Improved testability
- Multi-model aggregation
- Consistent data access patterns

**When NOT to Use**:
- Simple models with basic CRUD
- Single-use queries
- Overhead not justified

**Best Practices**:
- Encapsulate complex queries
- Use meaningful method names
- Keep repositories focused
- Eager load associations
- Test independently
- Use services for business logic
- Don't bypass repositories
- Transaction support for atomic operations

**Thread-safe**, **testable**, **integrated with BetterModel features**.
