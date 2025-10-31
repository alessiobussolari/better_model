# Integration Patterns

This guide shows proven patterns for combining BetterModel modules to solve common application needs.

## Table of Contents
- [Pattern 1: Complete Workflow](#pattern-1-complete-workflow)
- [Pattern 2: Search & Filter](#pattern-2-search--filter)
- [Pattern 3: Audit Trail](#pattern-3-audit-trail)
- [Pattern 4: Multi-step Form](#pattern-4-multi-step-form)
- [Pattern 5: Content Lifecycle](#pattern-5-content-lifecycle)

---

## Pattern 1: Complete Workflow

**Modules**: Stateable + Permissible + Statusable + Traceable

**When to use**: Content that requires approval workflow, role-based permissions, and complete audit trail.

**Use cases**: Article publishing, document approval, order processing

### Setup

```ruby
# Migration
class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.text :content
      t.string :state, default: "draft", null: false
      t.integer :user_id, null: false
      t.integer :reviewer_id
      t.datetime :published_at
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :articles, :state
    add_index :articles, :user_id
    add_index :articles, :reviewer_id

    create_table :article_versions do |t|
      t.string :item_type, null: false
      t.integer :item_id, null: false
      t.string :event, null: false
      t.json :object_changes
      t.integer :updated_by_id
      t.string :updated_reason
      t.datetime :created_at, null: false
    end

    add_index :article_versions, [:item_type, :item_id]
    add_index :article_versions, :event
  end
end
```

### Complete Model

```ruby
class Article < ApplicationRecord
  include BetterModel

  belongs_to :user
  belongs_to :reviewer, class_name: "User", optional: true

  # 1. Define statuses based on state and conditions
  is :draft, -> { state == "draft" }
  is :pending_review, -> { state == "pending_review" }
  is :published, -> { state == "published" && published_at.present? }
  is :owned_by_current_user, -> { user_id == Current.user&.id }
  is :reviewed_by_current_user, -> { reviewer_id == Current.user&.id }
  is :admin, -> { Current.user&.admin? }
  is :reviewer_role, -> { Current.user&.reviewer? }

  # 2. Define permissions based on statuses
  permit :edit, -> {
    return true if is?(:admin)
    is?(:draft) && is?(:owned_by_current_user)
  }

  permit :submit_for_review, -> {
    is?(:draft) && is?(:owned_by_current_user)
  }

  permit :approve, -> {
    is?(:pending_review) && (is?(:reviewer_role) || is?(:admin))
  }

  permit :reject, -> {
    is?(:pending_review) && (is?(:reviewer_role) || is?(:admin))
  }

  permit :publish_action, -> {
    is?(:admin)
  }

  permit :view, -> {
    return true if is?(:published)
    return true if is?(:owned_by_current_user)
    return true if is?(:admin)
    false
  }

  # 3. State machine with permission guards
  stateable do
    state :draft, initial: true
    state :pending_review
    state :reviewed
    state :published

    transition :submit, from: :draft, to: :pending_review do
      guard { can?(:submit_for_review) }
      guard { title.present? && content.present? }
      after :notify_reviewers
    end

    transition :approve, from: :pending_review, to: :reviewed do
      guard { can?(:approve) }
      before :set_reviewer
      before :set_reviewed_at
      after :notify_author_approved
    end

    transition :reject, from: :pending_review, to: :draft do
      guard { can?(:reject) }
      before :set_reviewer
      after :notify_author_rejected
    end

    transition :publish, from: :reviewed, to: :published do
      guard { can?(:publish_action) }
      before :set_published_at
      after :notify_subscribers
    end

    transition :unpublish, from: :published, to: :draft do
      guard { can?(:publish_action) }
      before { self.published_at = nil }
    end
  end

  # 4. Track all changes with audit trail
  traceable do
    track :title, :content, :state, :published_at, :reviewer_id
    versions_table :article_versions
  end

  private

  def set_reviewer
    self.reviewer_id = Current.user.id
  end

  def set_reviewed_at
    self.reviewed_at = Time.current
  end

  def set_published_at
    self.published_at = Time.current
  end

  def notify_reviewers
    ReviewerMailer.new_article_for_review(self).deliver_later
  end

  def notify_author_approved
    ArticleMailer.article_approved(self).deliver_later
  end

  def notify_author_rejected
    ArticleMailer.article_rejected(self).deliver_later
  end

  def notify_subscribers
    SubscriberMailer.new_article(self).deliver_later
  end
end
```

### Controller Integration

```ruby
class ArticlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article, except: [:index, :new, :create]
  before_action :authorize_action

  def index
    @articles = Article.where(user: current_user)
                      .or(Article.where(state: "published"))
                      .order(created_at: :desc)
  end

  def show
    # Article already set and authorized
  end

  def edit
    # Article already set and authorized
  end

  def update
    if @article.update(article_params)
      # Track the change with user info
      @article.versions.last&.update(
        updated_by_id: current_user.id,
        updated_reason: params[:reason]
      )

      redirect_to @article, notice: "Article updated"
    else
      render :edit
    end
  end

  def submit
    if @article.submit!
      redirect_to @article, notice: "Article submitted for review"
    else
      redirect_to @article, alert: "Cannot submit article"
    end
  rescue BetterModel::GuardFailedError => e
    redirect_to @article, alert: "Article not ready: #{e.message}"
  end

  def approve
    @article.update(reviewer_id: current_user.id)
    @article.approve!
    redirect_to @article, notice: "Article approved"
  rescue BetterModel::InvalidTransitionError => e
    redirect_to @article, alert: e.message
  end

  def reject
    @article.update(reviewer_id: current_user.id)
    @article.reject!
    redirect_to @article, notice: "Article rejected"
  end

  def publish
    @article.publish!
    redirect_to @article, notice: "Article published!"
  end

  def versions
    @versions = @article.versions
                        .order(created_at: :desc)
                        .page(params[:page])
  end

  def rollback
    version = @article.versions.find(params[:version_id])
    @article.rollback_to(version)

    # Track rollback
    @article.versions.last.update(
      updated_by_id: current_user.id,
      updated_reason: "Rolled back to version #{version.id}"
    )

    redirect_to @article, notice: "Rolled back to previous version"
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end

  def authorize_action
    action_map = {
      'show' => :view,
      'edit' => :edit,
      'update' => :edit,
      'submit' => :submit_for_review,
      'approve' => :approve,
      'reject' => :reject,
      'publish' => :publish_action
    }

    permission = action_map[action_name]
    return if permission.nil?

    unless @article.can?(permission)
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def article_params
    params.require(:article).permit(:title, :content)
  end
end
```

### Benefits

✅ **Complete workflow control** - State machine ensures valid transitions
✅ **Fine-grained permissions** - Different roles have appropriate access
✅ **Full audit trail** - Every change tracked with who and when
✅ **Flexible logic** - Statuses enable complex permission rules

### Trade-offs

⚠️ **Complexity** - More moving parts to understand
⚠️ **Performance** - Version tracking adds writes
⚠️ **Database** - Versions table can grow large

---

## Pattern 2: Search & Filter

**Modules**: Searchable + Predicable + Sortable

**When to use**: Building search UIs, API endpoints with filtering, admin panels

**Use cases**: Product catalog, user directory, content library

### Setup

```ruby
# Migration
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.string :category
      t.string :status, default: "active"
      t.decimal :price, precision: 10, scale: 2
      t.integer :stock_count, default: 0
      t.boolean :featured, default: false
      t.datetime :published_at
      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_index :products, :category
    add_index :products, :status
    add_index :products, :price
    add_index :products, :featured
    add_index :products, :published_at
  end
end
```

### Complete Model

```ruby
class Product < ApplicationRecord
  include BetterModel

  # 1. Define all filterable fields
  predicates :name, :sku, :category, :status, :price, :stock_count, :featured, :published_at, :created_at

  # 2. Define sortable fields
  sort :name, :price, :stock_count, :published_at, :created_at

  # 3. Configure searchable
  searchable do
    default_sort :published_at_desc
    default_per_page 24
    max_per_page 100
    max_page 1000
    max_predicates 50
    max_or_conditions 20
  end

  # Custom scopes for common searches
  scope :available, -> { where(status: "active").where("stock_count > ?", 0) }
  scope :on_sale, -> { where("price < original_price") }
  scope :low_stock, -> { where("stock_count > 0 AND stock_count <= 5") }
end
```

### API Controller

```ruby
class Api::V1::ProductsController < Api::V1::BaseController
  def index
    results = Product.search(
      search_predicates,
      sort: sort_param,
      pagination: pagination_params
    )

    render json: {
      data: results.map { |p| ProductSerializer.new(p).as_json },
      meta: {
        current_page: results.current_page,
        total_pages: results.total_pages,
        total_count: results.total_count,
        per_page: results.per_page
      },
      filters: available_filters
    }
  end

  def filters
    # Return available filter options
    render json: {
      categories: Product.distinct.pluck(:category).compact.sort,
      statuses: Product.distinct.pluck(:status).compact.sort,
      price_range: {
        min: Product.minimum(:price),
        max: Product.maximum(:price)
      },
      available_sorts: allowed_sorts.map { |s| { value: s, label: humanize_sort(s) } }
    }
  end

  private

  def search_predicates
    predicates = {}

    # Text search
    predicates[:name_cont] = params[:q] if params[:q].present?

    # Category filter
    predicates[:category_eq] = params[:category] if params[:category].present?

    # Status filter (multiple)
    if params[:statuses].present?
      predicates[:status_in] = params[:statuses]
    end

    # Price range
    predicates[:price_gteq] = params[:min_price] if params[:min_price].present?
    predicates[:price_lteq] = params[:max_price] if params[:max_price].present?

    # Stock filter
    predicates[:stock_count_gt] = 0 if params[:in_stock] == "true"

    # Featured
    predicates[:featured_true] = true if params[:featured] == "true"

    # Published date
    if params[:published_after].present?
      predicates[:published_at_gteq] = params[:published_after]
    end

    predicates.symbolize_keys
  end

  def sort_param
    sort = params[:sort]&.to_sym
    allowed_sorts.include?(sort) ? sort : :published_at_desc
  end

  def pagination_params
    {
      page: [params[:page].to_i, 1].max,
      per_page: [[params[:per_page].to_i, 1].max, 100].min
    }
  end

  def allowed_sorts
    %i[
      name_asc name_desc
      price_asc price_desc
      published_at_asc published_at_desc
      created_at_asc created_at_desc
      stock_count_asc stock_count_desc
    ]
  end

  def humanize_sort(sort)
    {
      name_asc: "Name (A-Z)",
      name_desc: "Name (Z-A)",
      price_asc: "Price (Low to High)",
      price_desc: "Price (High to Low)",
      published_at_desc: "Newest First",
      published_at_asc: "Oldest First",
      stock_count_desc: "Most in Stock",
      stock_count_asc: "Least in Stock"
    }[sort] || sort.to_s.titleize
  end

  def available_filters
    {
      text_search: { param: "q", type: "string" },
      category: { param: "category", type: "select", options: Product.distinct.pluck(:category) },
      status: { param: "statuses[]", type: "multi_select", options: ["active", "discontinued", "coming_soon"] },
      price_range: { min_param: "min_price", max_param: "max_price", type: "range" },
      in_stock: { param: "in_stock", type: "boolean" },
      featured: { param: "featured", type: "boolean" },
      published_after: { param: "published_after", type: "date" }
    }
  end
end
```

### Frontend Integration (JavaScript)

```javascript
// Example API usage
class ProductSearch {
  constructor() {
    this.filters = {};
    this.sort = 'published_at_desc';
    this.page = 1;
  }

  async search() {
    const params = new URLSearchParams({
      ...this.filters,
      sort: this.sort,
      page: this.page,
      per_page: 24
    });

    const response = await fetch(`/api/v1/products?${params}`);
    const data = await response.json();

    this.renderProducts(data.data);
    this.renderPagination(data.meta);
  }

  setFilter(key, value) {
    if (value) {
      this.filters[key] = value;
    } else {
      delete this.filters[key];
    }
    this.page = 1; // Reset to first page
    this.search();
  }

  setSort(sort) {
    this.sort = sort;
    this.search();
  }

  setPage(page) {
    this.page = page;
    this.search();
  }

  renderProducts(products) {
    // Render product grid
  }

  renderPagination(meta) {
    // Render pagination controls
  }
}

// Usage
const search = new ProductSearch();

// User filters by category
document.querySelector('#category-select').addEventListener('change', (e) => {
  search.setFilter('category', e.target.value);
});

// User searches by name
document.querySelector('#search-input').addEventListener('input', debounce((e) => {
  search.setFilter('q', e.target.value);
}, 300));

// User changes sort
document.querySelector('#sort-select').addEventListener('change', (e) => {
  search.setSort(e.target.value);
});
```

### Benefits

✅ **Powerful filtering** - Predicates handle complex queries
✅ **Flexible sorting** - Cross-database NULL handling
✅ **DoS protection** - Built-in limits prevent abuse
✅ **Clean API** - Unified interface for all searches

### Trade-offs

⚠️ **Index requirements** - Need indexes on filterable columns
⚠️ **Parameter validation** - Must whitelist allowed filters
⚠️ **N+1 queries** - May need includes for associations

---

## Pattern 3: Audit Trail

**Modules**: Traceable + Stateable + Archivable

**When to use**: Compliance requirements, financial records, legal documents

**Use cases**: Order processing, contracts, medical records

### Setup

```ruby
# Migration
class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :order_number, null: false
      t.integer :user_id, null: false
      t.string :state, default: "pending", null: false
      t.decimal :total, precision: 10, scale: 2
      t.string :payment_status
      t.string :shipping_status
      t.datetime :paid_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :archived_at
      t.integer :archived_by_id
      t.string :archive_reason
      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :user_id
    add_index :orders, :state
    add_index :orders, :archived_at

    create_table :order_versions do |t|
      t.string :item_type, null: false
      t.integer :item_id, null: false
      t.string :event, null: false
      t.json :object_changes
      t.integer :updated_by_id
      t.string :updated_reason
      t.datetime :created_at, null: false
    end

    add_index :order_versions, [:item_type, :item_id]
  end
end
```

### Complete Model

```ruby
class Order < ApplicationRecord
  include BetterModel

  belongs_to :user

  # 1. State machine for order lifecycle
  stateable do
    state :pending, initial: true
    state :payment_processing
    state :paid
    state :shipping
    state :shipped
    state :delivered
    state :cancelled
    state :refunded

    transition :process_payment, from: :pending, to: :payment_processing do
      guard { total > 0 }
      after :charge_payment
    end

    transition :confirm_payment, from: :payment_processing, to: :paid do
      before { self.paid_at = Time.current }
      after :send_confirmation_email
      after :notify_warehouse
    end

    transition :start_shipping, from: :paid, to: :shipping do
      after :prepare_shipment
    end

    transition :mark_shipped, from: :shipping, to: :shipped do
      before { self.shipped_at = Time.current }
      after :send_tracking_email
    end

    transition :mark_delivered, from: :shipped, to: :delivered do
      before { self.delivered_at = Time.current }
      after :send_delivery_confirmation
    end

    transition :cancel, from: [:pending, :payment_processing, :paid], to: :cancelled do
      guard { can_cancel? }
      after :process_cancellation
    end

    transition :refund, from: [:paid, :shipped, :delivered], to: :refunded do
      guard { can_refund? }
      after :process_refund
    end
  end

  # 2. Track all changes for compliance
  traceable do
    track :state, :payment_status, :shipping_status, :total,
          :paid_at, :shipped_at, :delivered_at
    versions_table :order_versions
  end

  # 3. Archive old orders
  archivable do
    skip_archived_by_default false  # Keep visible for reports
  end

  # Auto-archive old completed orders
  def self.archive_old_orders!
    where(state: [:delivered, :cancelled, :refunded])
      .where("updated_at < ?", 2.years.ago)
      .find_each do |order|
        order.archive!(
          by: 0,  # System
          reason: "Automatic archival - 2 years old"
        )
      end
  end

  # Compliance: Get complete audit trail
  def audit_trail
    versions.order(created_at: :asc).map do |v|
      {
        timestamp: v.created_at,
        event: v.event,
        changes: v.object_changes,
        user_id: v.updated_by_id,
        reason: v.updated_reason
      }
    end
  end

  # Compliance: Export for legal requests
  def compliance_export
    {
      order_number: order_number,
      user_id: user_id,
      current_state: state,
      created_at: created_at,
      updated_at: updated_at,
      archived: archived?,
      archived_at: archived_at,
      audit_trail: audit_trail,
      version_count: versions.count
    }
  end

  private

  def can_cancel?
    pending? || payment_processing? || (paid? && shipped_at.nil?)
  end

  def can_refund?
    paid? || shipped? || (delivered? && delivered_at > 30.days.ago)
  end

  def charge_payment
    PaymentProcessor.charge(self)
  end

  def process_cancellation
    PaymentProcessor.cancel(self) if paid?
  end

  def process_refund
    PaymentProcessor.refund(self)
  end

  def send_confirmation_email
    OrderMailer.confirmation(self).deliver_later
  end

  def notify_warehouse
    WarehouseJob.perform_later(id)
  end

  def prepare_shipment
    ShippingService.prepare(self)
  end

  def send_tracking_email
    OrderMailer.tracking(self).deliver_later
  end

  def send_delivery_confirmation
    OrderMailer.delivered(self).deliver_later
  end
end
```

### Admin Interface for Audit Review

```ruby
class Admin::OrderAuditsController < Admin::BaseController
  def show
    @order = Order.find(params[:order_id])
    @versions = @order.versions.order(created_at: :desc).page(params[:page])
    @audit_trail = @order.audit_trail
  end

  def export
    @order = Order.find(params[:order_id])

    respond_to do |format|
      format.json { render json: @order.compliance_export }
      format.pdf { render pdf: "order_#{@order.order_number}_audit" }
    end
  end

  def rollback
    @order = Order.find(params[:order_id])
    @version = @order.versions.find(params[:version_id])

    # Only admins can rollback
    authorize! :rollback, @order

    @order.rollback_to(@version)

    # Track the rollback itself
    @order.versions.last.update!(
      updated_by_id: current_admin.id,
      updated_reason: "Admin rollback to version #{@version.id}: #{params[:reason]}"
    )

    redirect_to admin_order_audit_path(@order),
                notice: "Order rolled back to previous state"
  end
end
```

### Benefits

✅ **Complete compliance** - Every change tracked permanently
✅ **Rollback capability** - Undo mistakes or fraudulent changes
✅ **Archive old data** - Keep database performant
✅ **Legal defensibility** - Full audit trail for disputes

### Trade-offs

⚠️ **Storage growth** - Versions table grows indefinitely
⚠️ **Privacy concerns** - May need to anonymize old data
⚠️ **Performance** - Queries may slow with large version tables

---

## Pattern 4: Multi-step Form

**Modules**: Validatable + Stateable + Permissible

**When to use**: Complex forms, wizards, progressive disclosure

**Use cases**: User onboarding, loan applications, survey forms

### Setup

```ruby
# Migration
class CreateApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :applications do |t|
      t.integer :user_id, null: false
      t.string :state, default: "personal_info", null: false

      # Step 1: Personal Info
      t.string :first_name
      t.string :last_name
      t.date :birth_date
      t.string :email
      t.string :phone

      # Step 2: Address
      t.string :street
      t.string :city
      t.string :state_province
      t.string :postal_code
      t.string :country

      # Step 3: Employment
      t.string :employer
      t.string :job_title
      t.integer :annual_income
      t.integer :years_employed

      # Step 4: Financial
      t.integer :credit_score
      t.integer :monthly_debts
      t.boolean :has_bankruptcy

      # Submission
      t.datetime :submitted_at
      t.string :status  # pending, approved, rejected
      t.integer :reviewed_by_id
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :applications, :user_id
    add_index :applications, :state
    add_index :applications, :status
  end
end
```

### Complete Model

```ruby
class Application < ApplicationRecord
  include BetterModel

  belongs_to :user
  belongs_to :reviewer, class_name: "User", optional: true

  attr_accessor :current_step

  # 1. Validation groups for each step
  validatable do
    # Step 1: Personal Info
    validation_group :personal_info, [:first_name, :last_name, :birth_date, :email, :phone]
    validate :first_name, :last_name, :email, presence: true
    validate :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validate :birth_date, presence: true
    validate :phone, format: { with: /\A\d{10}\z/ }

    validate_if -> { birth_date.present? } do
      validate_business_rule :must_be_adult
    end

    # Step 2: Address
    validation_group :address, [:street, :city, :state_province, :postal_code, :country]
    validate :street, :city, :state_province, :postal_code, :country, presence: true
    validate :postal_code, format: { with: /\A\d{5}(-\d{4})?\z/ }

    # Step 3: Employment
    validation_group :employment, [:employer, :job_title, :annual_income, :years_employed]
    validate :employer, :job_title, presence: true
    validate :annual_income, numericality: { greater_than: 0 }
    validate :years_employed, numericality: { greater_than_or_equal_to: 0 }

    # Step 4: Financial
    validation_group :financial, [:credit_score, :monthly_debts]
    validate :credit_score, numericality: { in: 300..850 }, allow_nil: false
    validate :monthly_debts, numericality: { greater_than_or_equal_to: 0 }

    # Final submission validation
    validate_if -> { state == "submitted" } do
      validate_business_rule :debt_to_income_ratio_acceptable
    end
  end

  # 2. State machine for form steps
  stateable do
    state :personal_info, initial: true
    state :address
    state :employment
    state :financial
    state :review
    state :submitted

    transition :complete_personal_info, from: :personal_info, to: :address do
      guard { valid_for_group?(:personal_info) }
    end

    transition :complete_address, from: :address, to: :employment do
      guard { valid_for_group?(:address) }
    end

    transition :complete_employment, from: :employment, to: :financial do
      guard { valid_for_group?(:employment) }
    end

    transition :complete_financial, from: :financial, to: :review do
      guard { valid_for_group?(:financial) }
    end

    transition :submit_application, from: :review, to: :submitted do
      guard { valid_for_all_groups? }
      before { self.submitted_at = Time.current }
      after :notify_admin
    end

    # Allow going back
    transition :back_to_personal_info, from: [:address, :employment, :financial, :review], to: :personal_info
    transition :back_to_address, from: [:employment, :financial, :review], to: :address
    transition :back_to_employment, from: [:financial, :review], to: :employment
    transition :back_to_financial, from: :review, to: :financial
  end

  # 3. Permissions
  is :owned_by_current_user, -> { user_id == Current.user&.id }
  is :admin, -> { Current.user&.admin? }
  is :reviewer_role, -> { Current.user&.reviewer? }

  permit :edit, -> {
    is?(:owned_by_current_user) && !submitted?
  }

  permit :submit, -> {
    is?(:owned_by_current_user) && review?
  }

  permit :review_application, -> {
    submitted? && (is?(:reviewer_role) || is?(:admin))
  }

  def valid_for_all_groups?
    valid_for_groups?([:personal_info, :address, :employment, :financial])
  end

  def progress_percentage
    steps = [:personal_info, :address, :employment, :financial, :review]
    current_index = steps.index(state.to_sym) || 0
    ((current_index + 1).to_f / steps.length * 100).round
  end

  private

  def must_be_adult
    if birth_date > 18.years.ago
      errors.add(:birth_date, "must be at least 18 years old")
    end
  end

  def debt_to_income_ratio_acceptable
    return if annual_income.nil? || monthly_debts.nil?

    monthly_income = annual_income / 12.0
    ratio = monthly_debts / monthly_income

    if ratio > 0.43  # 43% DTI ratio limit
      errors.add(:base, "Debt-to-income ratio too high")
    end
  end

  def notify_admin
    AdminMailer.new_application(self).deliver_later
  end
end
```

### Controller

```ruby
class ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, except: [:new, :create]
  before_action :authorize_application

  def new
    @application = current_user.applications.new
  end

  def create
    @application = current_user.applications.new
    @application.save!
    redirect_to edit_application_path(@application)
  end

  def edit
    # Render form for current state
  end

  def update
    if @application.update(application_params)
      # Try to advance to next step
      next_transition = next_step_transition(@application.state)

      if next_transition && params[:commit] == "Continue"
        begin
          @application.public_send("#{next_transition}!")
          redirect_to edit_application_path(@application)
        rescue BetterModel::GuardFailedError
          # Validation failed, re-render form
          render :edit
        end
      else
        redirect_to edit_application_path(@application),
                    notice: "Progress saved"
      end
    else
      render :edit
    end
  end

  def submit
    if @application.submit_application!
      redirect_to application_path(@application),
                  notice: "Application submitted successfully!"
    else
      redirect_to edit_application_path(@application),
                  alert: "Please complete all sections"
    end
  rescue BetterModel::GuardFailedError => e
    redirect_to edit_application_path(@application),
                alert: "Application incomplete: #{e.message}"
  end

  def back
    previous_transition = previous_step_transition(@application.state)
    if previous_transition
      @application.public_send("#{previous_transition}!")
    end
    redirect_to edit_application_path(@application)
  end

  private

  def set_application
    @application = Application.find(params[:id])
  end

  def authorize_application
    unless @application.can?(:edit)
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def application_params
    permitted = case @application.state
    when "personal_info"
      [:first_name, :last_name, :birth_date, :email, :phone]
    when "address"
      [:street, :city, :state_province, :postal_code, :country]
    when "employment"
      [:employer, :job_title, :annual_income, :years_employed]
    when "financial"
      [:credit_score, :monthly_debts, :has_bankruptcy]
    else
      []
    end

    params.require(:application).permit(*permitted)
  end

  def next_step_transition(current_state)
    {
      "personal_info" => :complete_personal_info,
      "address" => :complete_address,
      "employment" => :complete_employment,
      "financial" => :complete_financial,
      "review" => :submit_application
    }[current_state]
  end

  def previous_step_transition(current_state)
    {
      "address" => :back_to_personal_info,
      "employment" => :back_to_address,
      "financial" => :back_to_employment,
      "review" => :back_to_financial
    }[current_state]
  end
end
```

### View Example

```erb
<!-- app/views/applications/edit.html.erb -->
<div class="application-form">
  <div class="progress-bar">
    <div class="progress" style="width: <%= @application.progress_percentage %>%"></div>
  </div>

  <h2>Step <%= @application.progress_percentage / 20 %>: <%= @application.state.titleize %></h2>

  <%= form_with model: @application, local: true do |f| %>
    <%= render "form_#{@application.state}", f: f %>

    <div class="form-actions">
      <% if @application.state != "personal_info" %>
        <%= button_to "Back", back_application_path(@application), method: :post, class: "btn-secondary" %>
      <% end %>

      <%= f.submit "Save Progress", class: "btn-secondary" %>

      <% if @application.state == "review" %>
        <%= button_to "Submit Application", submit_application_path(@application), method: :post, class: "btn-primary" %>
      <% else %>
        <%= f.submit "Continue", class: "btn-primary" %>
      <% end %>
    </div>
  <% end %>
</div>
```

### Benefits

✅ **Progressive validation** - Only validate current step
✅ **User-friendly** - Can save and return later
✅ **Clear progress** - Users see where they are
✅ **Flexible navigation** - Can go back to edit

### Trade-offs

⚠️ **Complex state management** - Many transitions to handle
⚠️ **Partial data** - Need to handle incomplete records
⚠️ **Testing complexity** - Many paths to test

---

## Pattern 5: Content Lifecycle

**Modules**: ALL modules combined

**When to use**: Enterprise CMS, complex content workflows

**Use cases**: Publishing platform, documentation system

This pattern combines all previous patterns into a comprehensive content management system. See [Use Cases](11_use_cases.md) for complete implementation.

## Related Documentation

- [Individual Module Examples](README.md) - Detailed examples for each module
- [Use Cases](11_use_cases.md) - Real-world complete implementations
- [Cookbook](12_cookbook.md) - Solutions to specific problems

---

[Back to Examples Index](README.md)
