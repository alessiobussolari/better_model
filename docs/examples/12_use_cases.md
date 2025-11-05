# Real-World Use Cases

Complete implementations for common application scenarios using BetterModel modules.

## Table of Contents
- [Blog Publishing Platform](#blog-publishing-platform)
- [E-commerce Order Management](#e-commerce-order-management)
- [CMS Content System](#cms-content-system)
- [Task Management System](#task-management-system)

---

## Blog Publishing Platform

**Modules Used**: All 9 modules for complete content lifecycle

### Requirements
- Articles with draft, review, published states
- Role-based permissions (author, editor, admin)
- Full audit trail of changes
- Search and filtering for readers
- Soft delete with archive

### Complete Implementation

See [Pattern 1: Complete Workflow](10_integration_patterns.md#pattern-1-complete-workflow) for the complete blog platform implementation with:
- Multi-role workflow (Author → Editor → Admin)
- Permission-based editing
- State machine for publishing
- Complete version history
- Searchable article library

**Additional Features**:

```ruby
# Add to Article model from Pattern 1

# Search configuration for readers
predicates :title, :content, :published_at, :category
sort :title, :published_at, :view_count

searchable do
  default_sort :published_at_desc
  default_per_page 20
end

# Public-facing search
def self.public_search(query_params)
  search(
    query_params.merge(state_eq: "published"),
    sort: query_params[:sort] || :published_at_desc
  )
end

# Archive old posts automatically
def self.archive_old_posts!
  where(state: "published")
    .where("published_at < ?", 3.years.ago)
    .find_each do |article|
      article.archive!(
        by: 0,  # System
        reason: "Archived after 3 years"
      )
    end
end
```

---

## E-commerce Order Management

**Modules Used**: Stateable + Traceable + Archivable + Searchable

### Requirements
- Order lifecycle from cart to delivery
- Payment and shipping tracking
- Complete audit trail for compliance
- Customer and admin search
- Archive completed orders

### Complete Implementation

See [Pattern 3: Audit Trail](10_integration_patterns.md#pattern-3-audit-trail) for the complete order system with:
- Payment processing workflow
- Shipping integration
- Refund handling
- Compliance exports
- Admin audit interface

**Additional Features**:

```ruby
# Add to Order model from Pattern 3

# Customer search
predicates :order_number, :state, :total, :created_at
sort :created_at, :total

searchable do
  default_sort :created_at_desc
end

# Customer-facing order history
def self.for_customer(user, filters = {})
  where(user: user)
    .not_archived
    .search(filters, sort: :created_at_desc)
end

# Admin reporting
def self.revenue_report(start_date, end_date)
  where(state: [:delivered, :refunded])
    .where(created_at: start_date..end_date)
    .group_by_day(:created_at)
    .sum(:total)
end
```

---

## CMS Content System

**Modules Used**: Validatable + Stateable + Predicable + Sortable

### Requirements
- Pages with multiple content sections
- Multi-step page builder
- Draft/publish workflow
- Content library with search
- SEO meta fields

### Implementation

```ruby
class Page < ApplicationRecord
  include BetterModel

  # Multi-step form validation
  validatable do
    # Step 1: Basic info
    validation_group :basic, [:title, :slug]
    check :title, presence: true, length: { minimum: 3 }
    check :slug, presence: true, uniqueness: true

    # Step 2: Content
    validation_group :content, [:body, :excerpt]
    check :body, presence: true, length: { minimum: 100 }
    check :excerpt, length: { maximum: 300 }

    # Step 3: SEO
    validation_group :seo, [:meta_title, :meta_description]
    check :meta_title, length: { maximum: 60 }
    check :meta_description, length: { maximum: 160 }

    # Step 4: Settings
    validation_group :settings, [:template, :published_at]
    check :template, presence: true
  end

  # Workflow
  stateable do
    state :editing, initial: true
    state :preview
    state :published

    transition :preview_page, from: :editing, to: :preview do
      guard { valid_for_groups?([:basic, :content, :seo]) }
    end

    transition :publish_page, from: [:editing, :preview], to: :published do
      guard { valid? }
      before { self.published_at = Time.current }
    end

    transition :unpublish, from: :published, to: :editing
  end

  # Search and filter
  predicates :title, :slug, :template, :published_at, :state
  sort :title, :published_at, :updated_at

  # Public pages
  scope :published_pages, -> { where(state: "published") }

  # CMS library
  def self.cms_library(filters = {})
    search(filters, sort: :updated_at_desc)
  end
end
```

---

## Task Management System

**Modules Used**: Stateable + Permissible + Statusable + Searchable

### Requirements
- Tasks with assignees
- Status workflow
- Permission based on assignment
- Search and filters
- Due date tracking

### Implementation

```ruby
class Task < ApplicationRecord
  include BetterModel

  belongs_to :project
  belongs_to :creator, class_name: "User"
  belongs_to :assignee, class_name: "User", optional: true

  # Statuses
  is :todo, -> { state == "todo" }
  is :in_progress, -> { state == "in_progress" }
  is :done, -> { state == "done" }
  is :overdue, -> { due_date.present? && due_date < Date.today && !done? }
  is :assigned_to_current_user, -> { assignee_id == Current.user&.id }
  is :created_by_current_user, -> { creator_id == Current.user&.id }

  # Permissions
  permit :edit, -> {
    is?(:assigned_to_current_user) || is?(:created_by_current_user)
  }

  permit :complete, -> { is?(:assigned_to_current_user) }
  permit :reassign, -> { is?(:created_by_current_user) }

  # Workflow
  stateable do
    state :todo, initial: true
    state :in_progress
    state :done

    transition :start, from: :todo, to: :in_progress do
      guard { can?(:edit) }
      before { self.started_at = Time.current }
    end

    transition :complete, from: [:todo, :in_progress], to: :done do
      guard { can?(:complete) }
      before { self.completed_at = Time.current }
    end

    transition :reopen, from: :done, to: :todo do
      guard { can?(:edit) }
    end
  end

  # Search
  predicates :title, :state, :assignee_id, :due_date, :priority
  sort :due_date, :priority, :created_at

  searchable do
    default_sort :due_date_asc_nulls_last
  end

  # Common queries
  def self.my_tasks(user)
    where(assignee: user).not_archived.search({}, sort: :due_date_asc)
  end

  def self.overdue_tasks
    where("due_date < ? AND state != ?", Date.today, "done")
  end
end
```

**Controller Example**:

```ruby
class TasksController < ApplicationController
  def index
    @tasks = Task.my_tasks(current_user)
  end

  def search
    @tasks = Task.search(
      search_params,
      sort: params[:sort] || :due_date_asc
    )
  end

  def start
    @task = Task.find(params[:id])
    @task.start!
    redirect_to @task, notice: "Task started"
  end

  def complete
    @task = Task.find(params[:id])
    @task.complete!
    redirect_to @task, notice: "Task completed!"
  end

  private

  def search_params
    params.fetch(:search, {}).permit(
      :title_cont, :state_eq, :assignee_id_eq,
      :due_date_lteq, :priority_gteq
    )
  end
end
```

---

## Comparative Matrix

| Feature | Blog | E-commerce | CMS | Task Mgmt |
|---------|------|------------|-----|-----------|
| **Workflow Complexity** | High | High | Medium | Low |
| **Permissions** | Role-based | Order-based | Editor-based | Assignment-based |
| **Audit Trail** | Full | Compliance | Changes only | Optional |
| **Search Complexity** | Medium | High | Medium | Low |
| **Lifecycle** | Complete | Payment-focused | Editing-focused | Simple states |

## Tips for Adapting These Use Cases

1. **Start Simple**: Implement core workflow first, add features incrementally
2. **Test Thoroughly**: Each state transition needs comprehensive tests
3. **Consider Scale**: Add indexes, optimize queries for your expected load
4. **Customize Permissions**: Adapt permission logic to your specific needs
5. **Monitor Performance**: Track version table growth, archive old data

## Related Documentation

- [Integration Patterns](10_integration_patterns.md) - Detailed pattern implementations
- [Cookbook](12_cookbook.md) - Specific problem solutions
- [Individual Modules](README.md) - Module-specific examples

---

[Back to Examples Index](README.md)
