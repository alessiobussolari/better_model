# Repositable - Repository Pattern for Better Model

## Overview

Repositable provides infrastructure for implementing the Repository Pattern in Rails applications using BetterModel. It offers a `BaseRepository` class that encapsulates data access logic and integrates seamlessly with BetterModel's Searchable, Predicable, and Sortable concerns.

**Key Features**:
- Clean separation between data access and business logic
- Unified search interface with predicates, pagination, and ordering
- Seamless integration with BetterModel features (Searchable, Predicable, Sortable)
- Standard CRUD operations with ActiveRecord delegation
- Support for eager loading to prevent N+1 queries
- Transaction support for atomic operations
- Easy to test and mock
- Generator for quick repository creation

**When to Use Repositable**:
- Complex queries that benefit from encapsulation
- Applications following service-oriented architecture
- When you need improved testability through mocking
- Multi-model data aggregation scenarios
- Consistent data access patterns across the application
- When separating concerns improves maintainability

## Basic Concepts

### Repository Pattern

The Repository Pattern mediates between the domain and data mapping layers, acting like an in-memory collection of domain objects. It provides a collection-like interface for accessing domain objects without exposing implementation details.

**Architecture**:
```
Controller/Service → Repository → Model → Database
```

### BaseRepository

The core class providing:
- `search(predicates, **options)` - Main query method
- CRUD methods: `find`, `create`, `update`, `delete`, `build`
- ActiveRecord delegates: `where`, `all`, `count`, `exists?`

### ApplicationRepository

A base class for all application repositories:
```ruby
class ApplicationRepository < BetterModel::Repositable::BaseRepository
  # Application-wide repository methods
end
```

## Configuration

Repositable doesn't require configuration in models. Simply inherit from `BaseRepository`:

```ruby
class ArticleRepository < BetterModel::Repositable::BaseRepository
  def model_class = Article

  # Custom methods
end
```

Or use the generator:
```bash
rails g better_model:repository Article
```

## Instance Methods

### search(predicates = {}, **options)

Main querying method integrating with BetterModel.

**Parameters**:
- `predicates` (Hash): Filter conditions using BetterModel predicates
- `page` (Integer): Page number (default: 1)
- `per_page` (Integer): Records per page (default: 20)
- `includes` (Array): Associations to eager load
- `joins` (Array): Associations to join
- `order` (String/Hash): SQL ORDER BY clause
- `order_scope` (Hash): BetterModel sort scope (e.g., `{ field: :created_at, direction: :desc }`)
- `limit` (Integer/Symbol/nil): Result limit
  - `1`: Returns single record
  - `2+`: Returns limited relation
  - `nil`: Returns all records
  - `:default`: Uses pagination (default)

**Returns**: `ActiveRecord::Relation` or `ActiveRecord::Base`

**Examples**:
```ruby
repo = ArticleRepository.new

# Basic search
repo.search({ status_eq: "published" })

# With pagination
repo.search({ status_eq: "published" }, page: 2, per_page: 50)

# Single record
repo.search({ id_eq: 1 }, limit: 1)

# All records
repo.search({}, limit: nil)

# With eager loading
repo.search({ status_eq: "published" }, includes: [:author, :comments])

# With ordering
repo.search({}, order_scope: { field: :published_at, direction: :desc })
```

### CRUD Methods

- `find(id)` - Find by ID
- `find_by(attributes)` - Find by attributes
- `create(attributes)` - Create record
- `create!(attributes)` - Create with validation
- `build(attributes)` - Build unsaved instance
- `update(id, attributes)` - Update record
- `delete(id)` - Delete record

### ActiveRecord Delegates

- `where(conditions)` - WHERE clause
- `all` - All records
- `count` - Count records
- `exists?(id)` - Check existence

## Real-World Examples

### Example 1: E-commerce Product Repository

Complete product catalog implementation with filtering, search, and inventory management.

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  include BetterModel

  # Associations
  belongs_to :category
  belongs_to :brand
  has_many :images
  has_many :reviews

  # BetterModel features
  predicates :name, :sku, :price, :stock_quantity, :status, :category_id, :brand_id
  sort :name, :price, :stock_quantity, :created_at

  archivable do
    skip_archived_by_default true
  end

  # Validations
  validates :name, :sku, :price, presence: true
  validates :sku, uniqueness: true
  validates :price, numericality: { greater_than: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
end

# app/repositories/product_repository.rb
class ProductRepository < ApplicationRepository
  def model_class = Product

  # Status queries
  def active
    search({ status_eq: "active", stock_quantity_gt: 0 })
  end

  def in_stock
    search({ status_eq: "active", stock_quantity_gt: 0 })
  end

  def low_stock(threshold: 10)
    search({
      status_eq: "active",
      stock_quantity_lteq: threshold,
      stock_quantity_gt: 0
    }, order_scope: { field: :stock_quantity, direction: :asc })
  end

  def out_of_stock
    search({ status_eq: "active", stock_quantity_eq: 0 })
  end

  # Category queries
  def by_category(category_id)
    search({ category_id_eq: category_id, status_eq: "active" })
  end

  def by_brand(brand_id)
    search({ brand_id_eq: brand_id, status_eq: "active" })
  end

  # Pricing queries
  def price_range(min, max)
    search({
      status_eq: "active",
      price_between: [min, max]
    })
  end

  def on_sale
    search({
      status_eq: "active",
      sale_price_present: true
    }, order_scope: { field: :sale_price, direction: :asc })
  end

  def under_price(max_price)
    search({
      status_eq: "active",
      price_lteq: max_price
    })
  end

  # Search & discovery
  def search_products(query)
    search({
      or: [
        { name_i_cont: query },
        { description_i_cont: query },
        { sku_eq: query }
      ],
      status_eq: "active"
    })
  end

  def featured
    search({
      status_eq: "active",
      featured_eq: true
    }, order_scope: { field: :created_at, direction: :desc })
  end

  def new_arrivals(days: 30)
    search({
      status_eq: "active",
      created_at_gteq: days.days.ago
    }, order_scope: { field: :created_at, direction: :desc })
  end

  def best_sellers(min_sales: 50)
    search({
      status_eq: "active",
      total_sales_gteq: min_sales
    }, order_scope: { field: :total_sales, direction: :desc })
  end

  # Inventory management
  def needs_restock(threshold: 10)
    search({
      stock_quantity_lteq: threshold,
      status_eq: "active"
    })
  end

  def update_stock(product_id, quantity_change)
    product = find(product_id)
    new_quantity = product.stock_quantity + quantity_change

    raise ArgumentError, "Insufficient stock" if new_quantity < 0

    update(product_id, stock_quantity: new_quantity)
  end

  def bulk_price_update(category_id, percentage_change)
    products = by_category(category_id)

    Product.transaction do
      products.find_each do |product|
        new_price = product.price * (1 + percentage_change / 100.0)
        update(product.id, price: new_price.round(2))
      end
    end
  end
end

# app/services/product_search_service.rb
class ProductSearchService
  def initialize(repo: ProductRepository.new)
    @repo = repo
  end

  def search(query:, category: nil, brand: nil, price_min: nil, price_max: nil, page: 1, per_page: 24)
    filters = build_filters(category, brand, price_min, price_max)

    if query.present?
      @repo.search_products(query)
           .merge(Product.where(filters))
           .page(page)
           .per(per_page)
    else
      @repo.search(filters, page: page, per_page: per_page)
    end
  end

  private

  def build_filters(category, brand, price_min, price_max)
    filters = { status_eq: "active" }
    filters[:category_id_eq] = category if category.present?
    filters[:brand_id_eq] = brand if brand.present?
    filters[:price_gteq] = price_min if price_min.present?
    filters[:price_lteq] = price_max if price_max.present?
    filters
  end
end

# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  def index
    @repo = ProductRepository.new
    @products = @repo.active.page(params[:page])
  end

  def search
    @search_service = ProductSearchService.new
    @products = @search_service.search(
      query: params[:q],
      category: params[:category],
      brand: params[:brand],
      price_min: params[:price_min],
      price_max: params[:price_max],
      page: params[:page]
    )
    render :index
  end

  def low_stock
    @repo = ProductRepository.new
    @products = @repo.low_stock(threshold: 10)
    render :index
  end
end
```

### Example 2: Blog Article Management

Complete blog system with publishing workflow, categories, and trending content.

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  include BetterModel

  belongs_to :author, class_name: "User"
  belongs_to :category, optional: true
  has_many :comments, dependent: :destroy
  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  predicates :title, :status, :view_count, :published_at, :category_id, :featured
  sort :title, :view_count, :published_at, :created_at

  stateable do
    state :draft, initial: true
    state :published
    state :archived

    transition :publish, from: :draft, to: :published do
      check { published_at.present? }
      before_transition { self.published_at ||= Time.current }
    end

    transition :archive, from: [:draft, :published], to: :archived
  end

  traceable do
    track :title, :content, :status, :published_at
  end
end

# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Status queries
  def published
    search({ status_eq: "published" }, order_scope: { field: :published_at, direction: :desc })
  end

  def drafts
    search({ status_eq: "draft" }, order_scope: { field: :updated_at, direction: :desc })
  end

  def archived
    search({ status_eq: "archived" })
  end

  # Author queries
  def by_author(author_id, status: nil)
    filters = { author_id_eq: author_id }
    filters[:status_eq] = status if status
    search(filters, order_scope: { field: :created_at, direction: :desc })
  end

  # Category queries
  def by_category(category_id)
    search({ category_id_eq: category_id, status_eq: "published" })
  end

  # Trending & popular
  def trending(days: 7, min_views: 100)
    search({
      status_eq: "published",
      published_at_gteq: days.days.ago,
      view_count_gteq: min_views
    }, order_scope: { field: :view_count, direction: :desc })
  end

  def popular(limit: 10)
    search({ status_eq: "published" }, limit: limit, order_scope: { field: :view_count, direction: :desc })
  end

  def featured
    search({
      status_eq: "published",
      featured_eq: true
    }, order_scope: { field: :published_at, direction: :desc })
  end

  # Time-based queries
  def recent(days: 7)
    search({
      status_eq: "published",
      published_at_gteq: days.days.ago
    }, order_scope: { field: :published_at, direction: :desc })
  end

  def scheduled_for_today
    search({
      status_eq: "draft",
      scheduled_for_between: [Time.current.beginning_of_day, Time.current.end_of_day]
    })
  end

  def ready_to_publish
    search({
      status_eq: "draft",
      scheduled_for_lteq: Time.current
    })
  end

  # Review & moderation
  def needs_review
    search({
      status_eq: "draft",
      created_at_lteq: 24.hours.ago
    })
  end

  def with_pending_comments
    Article.joins(:comments)
           .where(comments: { status: "pending" })
           .distinct
  end

  # Search
  def search_articles(query)
    search({
      or: [
        { title_i_cont: query },
        { content_i_cont: query }
      ],
      status_eq: "published"
    })
  end

  # Statistics
  def statistics
    {
      total: count,
      published: Article.where(status: "published").count,
      drafts: Article.where(status: "draft").count,
      archived: Article.where(status: "archived").count,
      total_views: Article.sum(:view_count),
      avg_views: Article.average(:view_count).to_f.round(2)
    }
  end

  def author_statistics(author_id)
    articles = by_author(author_id)
    {
      total_articles: articles.count,
      published: articles.where(status: "published").count,
      drafts: articles.where(status: "draft").count,
      total_views: articles.sum(:view_count),
      avg_views: articles.average(:view_count).to_f.round(2)
    }
  end

  # Batch operations
  def publish_batch(article_ids)
    Article.transaction do
      article_ids.each do |id|
        article = find(id)
        article.publish! # Uses Stateable transition
      end
    end
  end
end

# app/services/article_publish_service.rb
class ArticlePublishService
  def initialize(repo: ArticleRepository.new)
    @repo = repo
  end

  def publish(article_id)
    article = @repo.find(article_id)

    ActiveRecord::Base.transaction do
      article.publish! # Stateable transition
      notify_subscribers(article)
      update_search_index(article)
    end
  end

  def publish_scheduled
    @repo.ready_to_publish.find_each do |article|
      publish(article.id)
    end
  end

  private

  def notify_subscribers(article)
    article.author.followers.find_each do |follower|
      ArticleNotificationMailer.new_article(follower, article).deliver_later
    end
  end

  def update_search_index(article)
    ArticleIndexJob.perform_later(article.id)
  end
end
```

### Example 3: User Management with Authentication

Complete user management system with roles, authentication, and activity tracking.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include BetterModel

  has_many :articles
  has_many :comments
  belongs_to :role

  predicates :email, :username, :status, :role_id, :last_sign_in_at, :created_at
  sort :email, :username, :created_at, :last_sign_in_at

  archivable do
    skip_archived_by_default true
  end

  traceable do
    track :email, :username, :role_id, :status
    track :password_digest, sensitive: :full
  end

  validates :email, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
end

# app/repositories/user_repository.rb
class UserRepository < ApplicationRepository
  def model_class = User

  def active_users
    search({ status_eq: "active" })
  end

  def by_email(email)
    search({ email_eq: email }, limit: 1)
  end

  def by_username(username)
    search({ username_eq: username }, limit: 1)
  end

  def by_role(role_id)
    search({ role_id_eq: role_id, status_eq: "active" })
  end

  def admins
    search({
      role_id_eq: Role.find_by(name: "admin")&.id,
      status_eq: "active"
    })
  end

  def recent_signups(days: 30)
    search({
      created_at_gteq: days.days.ago,
      status_eq: "active"
    }, order_scope: { field: :created_at, direction: :desc })
  end

  def inactive_users(days: 90)
    search({
      last_sign_in_at_lteq: days.days.ago,
      status_eq: "active"
    })
  end

  def search_users(query)
    search({
      or: [
        { email_i_cont: query },
        { username_i_cont: query }
      ],
      status_eq: "active"
    })
  end

  def with_activity
    search({}, includes: [:articles, :comments])
  end

  def authenticate(email, password)
    user = by_email(email)
    return nil unless user&.authenticate(password)

    update(user.id, last_sign_in_at: Time.current)
    user.reload
  end

  def create_with_role(attributes, role_name)
    role = Role.find_by(name: role_name)
    create!(attributes.merge(role: role))
  end
end
```

### Example 4: Order Processing System

E-commerce order management with states, payment processing, and fulfillment tracking.

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  include BetterModel

  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  predicates :status, :total_amount, :user_id, :created_at, :fulfilled_at
  sort :created_at, :total_amount, :fulfilled_at

  stateable do
    state :pending, initial: true
    state :paid
    state :processing
    state :shipped
    state :delivered
    state :cancelled

    transition :pay, from: :pending, to: :paid do
      check { payment_method.present? }
      after_transition { process_payment }
    end

    transition :process, from: :paid, to: :processing
    transition :ship, from: :processing, to: :shipped do
      before_transition { self.shipped_at = Time.current }
    end

    transition :deliver, from: :shipped, to: :delivered do
      before_transition { self.delivered_at = Time.current }
    end

    transition :cancel, from: [:pending, :paid, :processing], to: :cancelled
  end

  traceable do
    track :status, :total_amount, :shipping_address, :payment_method
  end
end

# app/repositories/order_repository.rb
class OrderRepository < ApplicationRepository
  def model_class = Order

  def by_user(user_id)
    search({ user_id_eq: user_id }, order_scope: { field: :created_at, direction: :desc })
  end

  def by_status(status)
    search({ status_eq: status })
  end

  def pending
    search({ status_eq: "pending" })
  end

  def paid_unprocessed
    search({ status_eq: "paid" })
  end

  def needs_fulfillment
    search({
      status_eq: "paid",
      created_at_lteq: 24.hours.ago
    })
  end

  def in_transit
    search({ status_eq: "shipped" })
  end

  def recent_orders(days: 30)
    search({
      created_at_gteq: days.days.ago
    }, order_scope: { field: :created_at, direction: :desc })
  end

  def high_value(min_amount: 1000)
    search({
      total_amount_gteq: min_amount,
      status_eq: "paid"
    })
  end

  def statistics(start_date: 30.days.ago, end_date: Time.current)
    orders = search({
      created_at_between: [start_date, end_date]
    }, limit: nil)

    {
      total_orders: orders.count,
      total_revenue: orders.sum(:total_amount),
      avg_order_value: orders.average(:total_amount).to_f.round(2),
      by_status: orders.group(:status).count
    }
  end

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
```

### Example 5: Inventory Management

Stock tracking, low stock alerts, and supplier management.

```ruby
# app/models/inventory_item.rb
class InventoryItem < ApplicationRecord
  include BetterModel

  belongs_to :product
  belongs_to :warehouse, optional: true

  predicates :product_id, :warehouse_id, :quantity, :reorder_level, :status
  sort :quantity, :reorder_level, :updated_at

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
end

# app/repositories/inventory_repository.rb
class InventoryRepository < ApplicationRepository
  def model_class = InventoryItem

  def by_product(product_id)
    search({ product_id_eq: product_id })
  end

  def by_warehouse(warehouse_id)
    search({ warehouse_id_eq: warehouse_id })
  end

  def in_stock
    search({ quantity_gt: 0, status_eq: "active" })
  end

  def out_of_stock
    search({ quantity_eq: 0, status_eq: "active" })
  end

  def low_stock
    InventoryItem.where("quantity <= reorder_level")
                 .where(status: "active")
  end

  def needs_reorder
    low_stock.where("quantity > 0")
  end

  def total_quantity(product_id)
    by_product(product_id).sum(:quantity)
  end

  def adjust_stock(id, quantity_change, reason:)
    inventory_item = find(id)
    new_quantity = inventory_item.quantity + quantity_change

    raise ArgumentError, "Insufficient stock" if new_quantity < 0

    InventoryItem.transaction do
      update(id, quantity: new_quantity)

      StockMovement.create!(
        inventory_item: inventory_item,
        quantity_change: quantity_change,
        reason: reason,
        balance_after: new_quantity
      )
    end
  end

  def transfer_stock(from_warehouse_id, to_warehouse_id, product_id, quantity)
    InventoryItem.transaction do
      from_item = InventoryItem.find_by(warehouse_id: from_warehouse_id, product_id: product_id)
      to_item = InventoryItem.find_or_initialize_by(warehouse_id: to_warehouse_id, product_id: product_id)

      raise ArgumentError, "Insufficient stock in source warehouse" if from_item.quantity < quantity

      adjust_stock(from_item.id, -quantity, reason: "transfer_out")
      adjust_stock(to_item.id, quantity, reason: "transfer_in")
    end
  end
end
```

### Example 6: Reporting & Analytics Dashboard

Multi-model data aggregation for business intelligence.

```ruby
# app/repositories/dashboard_repository.rb
class DashboardRepository < ApplicationRepository
  def model_class = Order # Primary model

  def overview(start_date: 30.days.ago, end_date: Time.current)
    {
      sales: sales_overview(start_date, end_date),
      orders: orders_overview(start_date, end_date),
      customers: customers_overview(start_date, end_date),
      products: products_overview(start_date, end_date),
      trends: trends_overview(start_date, end_date)
    }
  end

  def sales_overview(start_date, end_date)
    orders = Order.where(created_at: start_date..end_date, status: ["paid", "shipped", "delivered"])

    {
      total_revenue: orders.sum(:total_amount),
      avg_order_value: orders.average(:total_amount).to_f.round(2),
      orders_count: orders.count,
      by_day: orders.group_by_day(:created_at).sum(:total_amount)
    }
  end

  def orders_overview(start_date, end_date)
    orders = Order.where(created_at: start_date..end_date)

    {
      total: orders.count,
      by_status: orders.group(:status).count,
      pending: orders.where(status: "pending").count,
      processing: orders.where(status: ["paid", "processing"]).count,
      fulfilled: orders.where(status: ["shipped", "delivered"]).count,
      cancelled: orders.where(status: "cancelled").count
    }
  end

  def customers_overview(start_date, end_date)
    {
      total_customers: User.count,
      new_customers: User.where(created_at: start_date..end_date).count,
      active_customers: User.joins(:orders)
                            .where(orders: { created_at: start_date..end_date })
                            .distinct
                            .count,
      top_customers: User.joins(:orders)
                         .where(orders: { created_at: start_date..end_date })
                         .group("users.id")
                         .order("SUM(orders.total_amount) DESC")
                         .limit(10)
                         .pluck("users.email", "SUM(orders.total_amount)")
    }
  end

  def products_overview(start_date, end_date)
    {
      total_products: Product.count,
      active_products: Product.where(status: "active").count,
      low_stock: Product.where("stock_quantity <= reorder_level").count,
      top_sellers: OrderItem.joins(:order)
                            .where(orders: { created_at: start_date..end_date })
                            .group(:product_id)
                            .order("SUM(quantity) DESC")
                            .limit(10)
                            .includes(:product)
                            .pluck("products.name", "SUM(order_items.quantity)")
    }
  end

  def trends_overview(start_date, end_date)
    {
      daily_revenue: Order.where(created_at: start_date..end_date)
                          .group_by_day(:created_at)
                          .sum(:total_amount),
      daily_orders: Order.where(created_at: start_date..end_date)
                         .group_by_day(:created_at)
                         .count,
      category_sales: OrderItem.joins(:product, order: :order)
                               .where(orders: { created_at: start_date..end_date })
                               .group("products.category_id")
                               .sum("order_items.quantity * order_items.price")
    }
  end
end
```

### Example 7: Multi-Tenant Application

Tenant isolation and scoping.

```ruby
# app/repositories/tenant_aware_repository.rb
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

# app/repositories/article_repository.rb
class ArticleRepository < TenantAwareRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  # All queries automatically scoped to tenant
end

# Usage
tenant_repo = ArticleRepository.new(current_tenant.id)
articles = tenant_repo.published # Only current tenant's articles
```

### Example 8: API Repository with Serialization

JSON API implementation with pagination metadata.

```ruby
# app/repositories/api_repository.rb
class ApiRepository < ApplicationRepository
  def paginated_search(filters: {}, page: 1, per_page: 25)
    results = search(filters, page: page, per_page: per_page)

    {
      data: results,
      meta: pagination_meta(results, page, per_page)
    }
  end

  private

  def pagination_meta(results, page, per_page)
    {
      current_page: page,
      per_page: per_page,
      total_count: results.total_count,
      total_pages: results.total_pages
    }
  end
end

# app/controllers/api/v1/articles_controller.rb
class Api::V1::ArticlesController < Api::V1::BaseController
  def index
    @repo = ArticleRepository.new
    response = @repo.paginated_search(
      filters: permitted_filters,
      page: params[:page] || 1,
      per_page: params[:per_page] || 25
    )

    render json: response[:data],
           meta: response[:meta],
           each_serializer: ArticleSerializer
  end
end
```

### Example 9: Background Job Repository

Queue management and job processing.

```ruby
# app/repositories/background_job_repository.rb
class BackgroundJobRepository < ApplicationRepository
  def model_class = BackgroundJob

  def pending
    search({ status_eq: "pending" }, order_scope: { field: :created_at, direction: :asc })
  end

  def processing
    search({ status_eq: "processing" })
  end

  def failed
    search({ status_eq: "failed" })
  end

  def stuck_jobs(threshold: 1.hour)
    search({
      status_eq: "processing",
      updated_at_lteq: threshold.ago
    })
  end

  def retry_failed(max_attempts: 3)
    failed.where("attempts < ?", max_attempts).find_each do |job|
      update(job.id, status: "pending", attempts: job.attempts + 1)
    end
  end
end
```

### Example 10: Search Engine Repository

Full-text search integration.

```ruby
# app/repositories/search_repository.rb
class SearchRepository < ApplicationRepository
  def model_class = Article

  def fulltext_search(query, filters: {}, page: 1, per_page: 25)
    # Combine full-text search with filters
    results = Article.where("to_tsvector('english', title || ' ' || content) @@ plainto_tsquery('english', ?)", query)

    filters.each do |key, value|
      results = results.where(key => value)
    end

    results.order("ts_rank(to_tsvector('english', title || ' ' || content), plainto_tsquery('english', ?)) DESC", query)
           .page(page)
           .per(per_page)
  end

  def suggest(query, limit: 5)
    search({ title_start: query }, limit: limit)
  end
end
```

## Best Practices

### ✅ Do

1. **Use repositories for complex queries**
   ```ruby
   def trending
     search({
       status_eq: "published",
       published_at_gteq: 7.days.ago,
       view_count_gteq: 100
     }, order_scope: { field: :view_count, direction: :desc })
   end
   ```

2. **Encapsulate business logic**
   ```ruby
   def needs_review
     search({
       status_eq: "draft",
       created_at_lteq: 24.hours.ago
     })
   end
   ```

3. **Use meaningful method names**
   ```ruby
   def active_admins
     search({ status_eq: "active", role_eq: "admin" })
   end
   ```

4. **Keep repositories focused**
   ```ruby
   class ArticleRepository < ApplicationRepository
     def model_class = Article
     # Only Article-specific methods
   end
   ```

5. **Test repositories independently**
   ```ruby
   RSpec.describe ArticleRepository do
     it "returns published articles" do
       create(:article, status: "published")
       repo = described_class.new
       expect(repo.published.count).to eq(1)
     end
   end
   ```

### ❌ Don't

1. **Don't create repositories for simple models**
   ```ruby
   # Bad: Unnecessary for Tag
   class TagRepository < ApplicationRepository
     def model_class = Tag
   end

   # Good: Use Tag model directly
   Tag.all
   Tag.find_by(name: "ruby")
   ```

2. **Don't bypass repositories in controllers**
   ```ruby
   # Bad
   @articles = Article.where(status: "published")

   # Good
   @repo = ArticleRepository.new
   @articles = @repo.published
   ```

3. **Don't put too much logic in repositories**
   ```ruby
   # Bad: Repository doing too much
   def publish_and_notify(id)
     article = find(id)
     article.update!(status: "published")
     send_emails(article)
     post_to_social(article)
   end

   # Good: Use service objects
   class PublishService
     def call(article_id)
       article = @repo.find(article_id)
       article.publish!
       NotificationService.call(article)
       SocialService.call(article)
     end
   end
   ```

## Key Takeaways

1. Repositable provides the Repository Pattern infrastructure for BetterModel applications
2. Use `BaseRepository` as the parent class for all repositories
3. The `search()` method integrates with Searchable, Predicable, and Sortable
4. Repositories encapsulate complex queries and business rules
5. Generator (`rails g better_model:repository`) creates repositories quickly
6. CRUD operations are delegated to ActiveRecord (find, create, update, delete)
7. Use predicates from Predicable for type-safe querying
8. Leverage Sortable scopes for ordering
9. Eager loading (includes/joins) prevents N+1 queries
10. Repositories improve testability through dependency injection
11. Keep repositories focused on a single model or bounded context
12. Don't create repositories for simple models with basic CRUD
13. Service objects should use repositories, not direct model access
14. Transactions ensure data consistency in multi-step operations
15. ApplicationRepository provides application-wide repository methods
16. Pagination supports offset-based, keyset, and custom strategies
17. Integration with Searchable provides powerful query capabilities
18. Thread-safe: Repository instances can be created in any thread
19. Use meaningful method names that describe business intent
20. Test repositories independently from controllers and services
