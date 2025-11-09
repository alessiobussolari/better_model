# Archivable - Declarative Soft Delete System

## Overview

Archivable provides a powerful, declarative soft-delete system for Rails models with comprehensive archive tracking, audit trails, and restoration capabilities. Unlike traditional soft-delete gems, Archivable is opt-in, integrates seamlessly with BetterModel's Predicable and Searchable concerns, and provides rich query capabilities for managing archived records.

**Core Features:**
- **Opt-in activation** - Not enabled by default; explicitly opt in with `archivable`
- **Soft delete pattern** - Archive records instead of permanently deleting them
- **Archive tracking** - Track who archived a record, when, and why
- **Restoration** - Restore archived records with a single method call
- **Status predicates** - Check if records are archived or active
- **Powerful scopes** - Query archived, active, or all records with semantic methods
- **Automatic predicates** - Get datetime predicates for `archived_at` via Predicable integration
- **Helper methods** - Semantic aliases like `archived_today`, `archived_recently`
- **Optional default scope** - Hide archived records by default (configurable)
- **Searchable integration** - Use archive predicates in unified search queries
- **JSON serialization** - Include archive metadata in API responses
- **Thread-safe** - Immutable configuration with frozen registries

**Requirements:**
- **Database column**: `archived_at` (datetime) - required
- **Optional columns**: `archived_by_id` (integer), `archive_reason` (string)
- **Generator available**: `rails generate better_model:archivable Model`
- **Opt-in feature**: Must explicitly call `archivable` in model

---

## Basic Concepts

### What is Soft Delete?

Instead of permanently deleting records from the database, soft delete marks them as "deleted" by setting a timestamp. This allows:
- **Data retention** for compliance and auditing
- **Recovery** of accidentally deleted records
- **Historical analysis** of deleted data
- **Referential integrity** - foreign keys remain valid

### The Archivable Pattern

```ruby
# Traditional hard delete:
article.destroy  # ❌ Gone forever

# Archivable soft delete:
article.archive!  # ✅ Marked as archived, can be restored
article.restore!  # ✅ Bring it back
```

### Archive Lifecycle

```
┌─────────┐     archive!      ┌──────────┐      restore!     ┌─────────┐
│ Active  │ ───────────────→  │ Archived │  ───────────────→ │ Active  │
│ Record  │                   │  Record  │                   │ Record  │
└─────────┘                   └──────────┘                   └─────────┘
```

### Opt-In Philosophy

Archivable follows an **opt-in** approach:
- Not all models need soft delete
- Explicitly enable only where needed
- No performance overhead for models that don't use it
- Clear intent in model definition

---

## Database Setup

### Using the Generator (Recommended)

BetterModel provides generators for creating archivable migrations.

#### Basic Setup (archived_at only)

```bash
rails generate better_model:archivable Article
rails db:migrate
```

**Generated migration:**
```ruby
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    change_table :articles do |t|
      t.datetime :archived_at
    end

    add_index :articles, :archived_at
  end
end
```

#### With Full Tracking (who + why)

```bash
rails generate better_model:archivable Article --with-tracking
rails db:migrate
```

**Generated migration:**
```ruby
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    change_table :articles do |t|
      t.datetime :archived_at
      t.integer :archived_by_id     # Track who archived
      t.string :archive_reason      # Track why archived
    end

    add_index :articles, :archived_at
    add_index :articles, :archived_by_id
  end
end
```

### Generator Options

| Option | Adds Column(s) | Use Case |
|--------|---------------|----------|
| **(none)** | `archived_at` | Basic soft delete |
| `--with-tracking` | `archived_at`, `archived_by_id`, `archive_reason` | Full audit trail |
| `--with-by` | `archived_at`, `archived_by_id` | Track who archived |
| `--with-reason` | `archived_at`, `archive_reason` | Track why archived |
| `--skip-indexes` | *(no indexes)* | Skip index creation (not recommended) |

**Examples:**

```bash
# Only track who archived
rails g better_model:archivable User --with-by

# Only track reason
rails g better_model:archivable Task --with-reason

# Without indexes (not recommended)
rails g better_model:archivable Product --skip-indexes
```

### Manual Migration

If you prefer not to use the generator:

```ruby
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    change_table :articles do |t|
      # Required: timestamp when archived
      t.datetime :archived_at

      # Optional: track who archived
      t.integer :archived_by_id

      # Optional: track reason
      t.string :archive_reason
    end

    # Performance indexes
    add_index :articles, :archived_at
    add_index :articles, :archived_by_id
  end
end
```

### Column Reference

| Column | Type | Required | Description | Index? |
|--------|------|----------|-------------|--------|
| `archived_at` | datetime | ✅ Yes | Timestamp when record was archived | ✅ Yes |
| `archived_by_id` | integer | ⚪ No | ID of user who archived the record | ✅ Recommended |
| `archive_reason` | string | ⚪ No | Reason for archiving | ⚪ Optional |

---

## Configuration

### Basic Activation

Enable Archivable in your model:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable archivable (opt-in)
  archivable
end
```

**This automatically:**
- Adds instance methods: `archive!`, `restore!`, `archived?`, `active?`
- Adds scopes: `archived`, `not_archived`, `archived_only`
- Generates predicates for `archived_at` via Predicable
- Adds helper methods: `archived_today`, `archived_this_week`, `archived_recently`

### With Configuration Block

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable with configuration
  archivable do
    skip_archived_by_default true  # Hide archived records by default
  end
end
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `skip_archived_by_default` | Boolean | `false` | When `true`, applies a default scope to hide archived records. Use `archived_only` or `unscoped` to query archived records. |

**When to use `skip_archived_by_default`:**
- ✅ Most queries should only see active records
- ✅ Model represents "current state" (e.g., active users, published articles)
- ❌ Avoid if you frequently query archived records
- ❌ Be careful with associations (can cause unexpected behavior)

**Example with default scope:**

```ruby
class User < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true  # Hide archived users by default
  end
end

# Queries
User.all           # => Only active users (archived hidden)
User.count         # => Count of active users only
User.archived      # => Empty (default scope filters them out)
User.archived_only # => Bypasses default scope, shows archived users
User.unscoped.all  # => All users (active + archived)
```

---

## Instance Methods

### `archive!(by:, reason:)`

Archive a record with optional tracking.

**Signature:**
```ruby
def archive!(by: nil, reason: nil)
```

**Parameters:**
- `by` (optional): User ID (Integer) or User object (responds to `.id`)
- `reason` (optional): String explaining why the record was archived

**Returns:** `self`

**Raises:**
- `BetterModel::Errors::Archivable::NotEnabledError` - If archivable is not enabled
- `BetterModel::Errors::Archivable::AlreadyArchivedError` - If record is already archived

**Examples:**

```ruby
# Basic archiving (no tracking)
article = Article.find(1)
article.archive!
# => archived_at: 2025-11-05 10:30:00

# With user tracking (User object)
article.archive!(by: current_user)
# => archived_at: 2025-11-05 10:30:00
#    archived_by_id: 123

# With user tracking (User ID)
article.archive!(by: 123)
# => archived_at: 2025-11-05 10:30:00
#    archived_by_id: 123

# With reason only
article.archive!(reason: "Content is outdated")
# => archived_at: 2025-11-05 10:30:00
#    archive_reason: "Content is outdated"

# With both tracking options
article.archive!(
  by: current_user,
  reason: "Policy violation - inappropriate content"
)
# => archived_at: 2025-11-05 10:30:00
#    archived_by_id: 123
#    archive_reason: "Policy violation - inappropriate content"
```

**Error handling:**

```ruby
# Trying to archive without enabling archivable
article.archive!
# => BetterModel::Errors::Archivable::NotEnabledError

# Trying to archive already archived record
article.archive!
article.archive!  # Second time
# => BetterModel::Errors::Archivable::AlreadyArchivedError
```

### `restore!`

Restore an archived record to active state.

**Signature:**
```ruby
def restore!
```

**Returns:** `self`

**Raises:**
- `BetterModel::Errors::Archivable::NotEnabledError` - If archivable is not enabled
- `BetterModel::Errors::Archivable::NotArchivedError` - If record is not archived

**Examples:**

```ruby
# Restore archived article
article = Article.archived.find(1)
article.restore!
# => archived_at: nil
#    archived_by_id: nil
#    archive_reason: nil

# Chaining
article.archive!(by: admin, reason: "Test").restore!

# Error handling
article.restore!
article.restore!  # Second time
# => BetterModel::Errors::Archivable::NotArchivedError
```

**What it does:**
- Sets `archived_at` to `nil`
- Clears `archived_by_id` (if present)
- Clears `archive_reason` (if present)
- Saves the record

### `archived?`

Check if the record is archived.

**Signature:**
```ruby
def archived?
```

**Returns:** `Boolean` - `true` if `archived_at` is present, `false` otherwise

**Examples:**

```ruby
article = Article.find(1)

article.archived?
# => false

article.archive!
article.archived?
# => true

article.restore!
article.archived?
# => false
```

### `active?`

Check if the record is NOT archived (active).

**Signature:**
```ruby
def active?
```

**Returns:** `Boolean` - `true` if `archived_at` is nil, `false` otherwise

**Examples:**

```ruby
article = Article.find(1)

article.active?
# => true

article.archive!
article.active?
# => false

article.restore!
article.active?
# => true
```

**Relationship:**
```ruby
article.active? == !article.archived?  # Always true
```

---

## Scopes

Archivable provides semantic scopes for querying records based on archive status.

### `archived`

Find all archived records.

**Alias for:** `archived_at_present(true)`

**SQL:** `WHERE archived_at IS NOT NULL`

**Examples:**

```ruby
# All archived articles
Article.archived
# => #<ActiveRecord::Relation [...]>

# Count archived
Article.archived.count
# => 15

# Chain with other scopes
Article.archived.where(status: "published")
# => Archived published articles

# Order by archive date
Article.archived.order(archived_at: :desc)
# => Most recently archived first
```

### `not_archived`

Find all active (non-archived) records.

**Alias for:** `archived_at_null(true)`

**SQL:** `WHERE archived_at IS NULL`

**Examples:**

```ruby
# All active articles
Article.not_archived
# => #<ActiveRecord::Relation [...]>

# Count active
Article.not_archived.count
# => 42

# Chain with other scopes
Article.not_archived.where(status: "published")
# => Active published articles

# Order by creation date
Article.not_archived.order(created_at: :desc)
# => Newest active articles first
```

### `archived_only`

Find ONLY archived records, **bypassing any default scope**.

**When to use:** When `skip_archived_by_default` is enabled.

**Examples:**

```ruby
# With skip_archived_by_default: true

Article.all
# => Only active records (default scope hides archived)

Article.archived
# => Empty (default scope prevents seeing archived)

Article.archived_only
# => Explicitly shows archived records (bypasses default scope)

Article.unscoped.archived
# => Alternative way to see archived records
```

**Comparison:**

```ruby
# With skip_archived_by_default: false (default behavior)
Article.archived == Article.archived_only  # Same results

# With skip_archived_by_default: true
Article.archived          # => [] (empty, filtered by default scope)
Article.archived_only     # => [archived records] (bypasses default scope)
```

### Chaining Scopes

All archivable scopes are chainable with other scopes:

```ruby
# Archived articles from last week
Article.archived
       .where("archived_at >= ?", 1.week.ago)
       .order(archived_at: :desc)

# Active published articles by specific author
Article.not_archived
       .where(status: "published", author_id: 123)
       .order(published_at: :desc)

# Archived articles with specific reason
Article.archived
       .where(archive_reason: "Spam")
       .includes(:author)

# Complex query: active OR recently archived
Article.not_archived
       .or(Article.archived_at_gteq(30.days.ago))
       .order(created_at: :desc)
```

---

## Predicates Integration

When you enable archivable, **all datetime predicates** for `archived_at` are automatically generated via Predicable. This gives you powerful querying capabilities.

### Standard Datetime Predicates

```ruby
# Presence checks (require explicit boolean parameter)
Article.archived_at_present(true)   # archived_at IS NOT NULL
Article.archived_at_null(true)      # archived_at IS NULL
Article.archived_at_blank(true)     # archived_at IS NULL OR ''

# Equality
Article.archived_at_eq(date)        # archived_at = date
Article.archived_at_not_eq(date)    # archived_at != date

# Comparisons
Article.archived_at_gt(date)        # archived_at > date
Article.archived_at_gteq(date)      # archived_at >= date
Article.archived_at_lt(date)        # archived_at < date
Article.archived_at_lteq(date)      # archived_at <= date

# Range queries
Article.archived_at_between(start_date, end_date)
# => WHERE archived_at BETWEEN start_date AND end_date

Article.archived_at_not_between(start_date, end_date)
# => WHERE archived_at NOT BETWEEN start_date AND end_date

# Array queries
Article.archived_at_in([date1, date2, date3])
Article.archived_at_not_in([date1, date2])

# Duration-based
Article.archived_at_within(7.days)
# => Archived in last 7 days (within duration from now)
```

### Date Convenience Predicates

⚠️ **Note:** Date convenience predicates like `_today`, `_this_week` etc. were removed in recent versions. Use explicit date comparisons instead:

```ruby
# ❌ REMOVED (no longer available):
# Article.archived_at_today
# Article.archived_at_this_week
# Article.archived_at_this_month

# ✅ USE INSTEAD:
Article.archived_at_gteq(Date.today.beginning_of_day)
Article.archived_at_gteq(Date.today.beginning_of_week)
Article.archived_at_gteq(Date.today.beginning_of_month)

# Or use _within for relative queries:
Article.archived_at_within(1.day)    # Last 24 hours
Article.archived_at_within(7.days)   # Last 7 days
Article.archived_at_within(30.days)  # Last 30 days
```

### Helper Methods

Archivable provides semantic aliases for common queries:

#### `archived_today`

**Alias for:** `archived_at_gteq(Date.today.beginning_of_day)`

```ruby
Article.archived_today
# => Articles archived today
# SQL: WHERE archived_at >= '2025-11-05 00:00:00'
```

#### `archived_this_week`

**Alias for:** `archived_at_gteq(Date.today.beginning_of_week)`

```ruby
Article.archived_this_week
# => Articles archived this week
# SQL: WHERE archived_at >= '2025-11-04 00:00:00' (Monday)
```

#### `archived_recently(duration = 7.days)`

**Alias for:** `archived_at_within(duration)`

```ruby
# Default: last 7 days
Article.archived_recently
# => Articles archived in last 7 days

# Custom duration
Article.archived_recently(30.days)
# => Articles archived in last 30 days

Article.archived_recently(1.hour)
# => Articles archived in last hour

Article.archived_recently(2.weeks)
# => Articles archived in last 2 weeks
```

### Real-World Predicate Examples

```ruby
# Articles archived by specific user
Article.archived.where(archived_by_id: current_user.id)

# Articles archived in Q4 2024
Article.archived_at_between(
  Date.new(2024, 10, 1),
  Date.new(2024, 12, 31)
)

# Articles archived more than 90 days ago (retention policy)
Article.archived_at_lt(90.days.ago)

# Articles archived in last 24 hours (for review)
Article.archived_recently(1.day)

# Articles archived with specific reasons
Article.archived.where(
  archive_reason: ["Spam", "Inappropriate", "Duplicate"]
)

# Complex query: active OR recently archived
Article.not_archived
       .or(Article.archived_at_gteq(7.days.ago))
```

---

## Default Scope Behavior

The `skip_archived_by_default` option applies a default scope to hide archived records.

### Enabling Default Scope

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end
end
```

### Behavior Comparison

#### Without Default Scope (default behavior)

```ruby
class Article < ApplicationRecord
  archivable  # skip_archived_by_default: false (default)
end

Article.all           # => All records (active + archived)
Article.count         # => 100 (total count)
Article.archived      # => 20 archived records
Article.not_archived  # => 80 active records
```

#### With Default Scope

```ruby
class Article < ApplicationRecord
  archivable do
    skip_archived_by_default true
  end
end

Article.all           # => Only active records (archived hidden)
Article.count         # => 80 (only active)
Article.archived      # => [] (empty - default scope prevents it)
Article.not_archived  # => 80 active records
Article.archived_only # => 20 archived records (bypasses default scope)
Article.unscoped.all  # => 100 (all records)
```

### Bypassing Default Scope

Three ways to access archived records when default scope is enabled:

```ruby
# 1. Use archived_only scope (recommended)
Article.archived_only

# 2. Use unscoped
Article.unscoped.archived

# 3. Use unscoped with where
Article.unscoped.where.not(archived_at: nil)
```

### Best Practices for Default Scope

**Use when:**
```ruby
# ✅ User accounts (soft delete pattern)
class User < ApplicationRecord
  archivable do
    skip_archived_by_default true  # Hide deleted accounts
  end
end

# ✅ Published content (hide archived posts)
class Article < ApplicationRecord
  archivable do
    skip_archived_by_default true  # Only show active articles
  end
end
```

**Avoid when:**
```ruby
# ❌ Audit/history models (need all records)
class AuditLog < ApplicationRecord
  archivable  # Don't use default scope
end

# ❌ Models with frequent archive queries
class Task < ApplicationRecord
  archivable  # Don't use default scope if you often query archived tasks
end
```

**Cautions:**
```ruby
# ⚠️ Can affect associations
class Article < ApplicationRecord
  has_many :comments
  archivable do
    skip_archived_by_default true
  end
end

article = Article.find(1)  # Might fail if archived
article.comments           # Might be empty due to default scope

# Better:
article = Article.archived_only.find(1)
article.comments
```

---

## Searchable Integration

Archivable works seamlessly with BetterModel's Searchable concern for unified querying.

### Model Setup

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end

  predicates :title, :status, :archived_at
  sort :title, :published_at, :archived_at

  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_created_at_desc]
  end
end
```

### Search Examples

#### Basic Archive Filtering

```ruby
# Find active (non-archived) articles
Article.search(
  { archived_at_null: true }
)

# Find archived articles
Article.search(
  { archived_at_present: true }
)
```

#### Combined Filters

```ruby
# Active published articles
Article.search(
  {
    archived_at_null: true,
    status_eq: "published"
  },
  orders: [:sort_published_at_desc]
)

# Archived articles from last 7 days
Article.search(
  { archived_at_within: 7.days },
  orders: [:sort_archived_at_desc]
)

# Archived articles with specific reason
Article.search(
  {
    archived_at_present: true,
    archive_reason_cont: "spam"
  }
)
```

#### Complex Queries with OR

```ruby
# Published articles (active OR recently archived)
Article.search(
  { status_eq: "published" },
  or_conditions: [
    { archived_at_null: true },
    { archived_at_gt: 30.days.ago }
  ],
  orders: [:sort_published_at_desc]
)
```

#### With Pagination

```ruby
# Paginated archive search
Article.search(
  {
    archived_at_between: [1.month.ago, Time.current],
    status_eq: "published"
  },
  orders: [:sort_archived_at_desc],
  pagination: { page: params[:page], per_page: 25 }
)
```

### Controller Integration

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      search_params,
      orders: order_params,
      pagination: { page: params[:page] }
    )
  end

  def archived
    @articles = Article.search(
      search_params.merge(archived_at_present: true),
      orders: [:sort_archived_at_desc],
      pagination: { page: params[:page] }
    )
  end

  private

  def search_params
    params.permit(:title_cont, :status_eq, :archived_at_null, :archived_at_within)
  end

  def order_params
    params[:orders] || [:sort_created_at_desc]
  end
end
```

---

## JSON Serialization

Archivable enhances `as_json` to include archive metadata for API responses.

### Basic Serialization

```ruby
article = Article.find(1)
article.archive!(by: current_user, reason: "Outdated content")

# Default JSON (includes archived_at)
article.as_json
# => {
#      "id" => 1,
#      "title" => "Getting Started with Rails",
#      "status" => "published",
#      "archived_at" => "2025-11-05T10:30:00Z",
#      "created_at" => "2025-01-15T08:00:00Z",
#      "updated_at" => "2025-11-05T10:30:00Z"
#    }
```

### With Archive Info

Use `include_archive_info: true` to get structured archive metadata:

```ruby
article.as_json(include_archive_info: true)
# => {
#      "id" => 1,
#      "title" => "Getting Started with Rails",
#      "status" => "published",
#      "created_at" => "2025-01-15T08:00:00Z",
#      "updated_at" => "2025-11-05T10:30:00Z",
#      "archive_info" => {
#        "archived" => true,
#        "archived_at" => "2025-11-05T10:30:00Z",
#        "archived_by_id" => 123,
#        "archive_reason" => "Outdated content"
#      }
#    }
```

### Active Record Serialization

```ruby
# Active (non-archived) article
active_article.as_json(include_archive_info: true)
# => {
#      "id" => 2,
#      "title" => "Ruby 3.0 Features",
#      "archive_info" => {
#        "archived" => false,
#        "archived_at" => nil,
#        "archived_by_id" => nil,
#        "archive_reason" => nil
#      }
#    }
```

### API Controller Example

```ruby
class Api::V1::ArticlesController < Api::BaseController
  def index
    @articles = Article.not_archived.limit(20)

    render json: {
      articles: @articles.as_json(include_archive_info: true),
      meta: {
        total: @articles.count,
        page: 1
      }
    }
  end

  def show
    @article = Article.find(params[:id])

    render json: @article.as_json(
      include_archive_info: true,
      include: {
        author: { only: [:id, :name, :email] }
      }
    )
  end

  def archived
    @articles = Article.archived_only.limit(20)

    render json: {
      archived_articles: @articles.as_json(include_archive_info: true),
      meta: {
        total: Article.archived.count
      }
    }
  end
end
```

---

## Real-World Examples

### Example 1: Article Management System

Complete article management with soft delete and restoration.

```ruby
class Article < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: "User"

  # Enable archivable with default scope
  archivable do
    skip_archived_by_default true
  end

  predicates :title, :status, :archived_at
  sort :title, :published_at, :archived_at, :created_at

  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc]
  end

  # Validation: require reason when archiving
  validates :archive_reason, presence: true, if: :archived?
end

# Usage in controller
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      params.permit(:status_eq, :title_cont),
      orders: params[:orders],
      pagination: { page: params[:page] }
    )
  end

  def archive
    @article = Article.find(params[:id])

    if @article.archive!(by: current_user, reason: archive_params[:reason])
      redirect_to articles_path, notice: "Article archived successfully"
    else
      redirect_to article_path(@article), alert: "Failed to archive article"
    end
  rescue BetterModel::Errors::Archivable::AlreadyArchivedError
    redirect_to article_path(@article), alert: "Article is already archived"
  end

  def archived
    @articles = Article.archived_only.page(params[:page])
  end

  def restore
    @article = Article.archived_only.find(params[:id])
    @article.restore!

    redirect_to article_path(@article), notice: "Article restored successfully"
  rescue BetterModel::Errors::Archivable::NotArchivedError
    redirect_to articles_path, alert: "Article is not archived"
  end

  private

  def archive_params
    params.require(:article).permit(:reason)
  end
end
```

**Routes:**
```ruby
resources :articles do
  member do
    post :archive
    post :restore
  end

  collection do
    get :archived
  end
end
```

**View (archive button):**
```erb
<% if @article.active? %>
  <%= button_to "Archive Article",
      archive_article_path(@article),
      method: :post,
      data: {
        confirm: "Are you sure you want to archive this article?",
        turbo_confirm: "Reason for archiving:"
      },
      class: "btn btn-warning" %>
<% else %>
  <%= button_to "Restore Article",
      restore_article_path(@article),
      method: :post,
      class: "btn btn-success" %>
<% end %>
```

---

### Example 2: User Account Soft Delete

Soft delete pattern for user accounts with account deletion requests.

```ruby
class User < ApplicationRecord
  include BetterModel
  has_many :articles, foreign_key: :author_id

  # Archive instead of hard delete
  archivable do
    skip_archived_by_default true  # Hide deleted accounts
  end

  predicates :email, :name, :archived_at
  sort :email, :created_at, :archived_at

  # Override destroy to use archiving
  def destroy
    archive!(reason: "User requested account deletion")
  end

  # Anonymize user data on archive
  after_create_commit :anonymize_data, if: :archived?

  private

  def anonymize_data
    update_columns(
      email: "deleted_#{id}@example.com",
      name: "Deleted User #{id}"
    )
  end
end

# Usage in controller
class UsersController < ApplicationController
  def destroy
    @user = User.find(params[:id])

    # This calls user.destroy which archives instead
    if @user.destroy
      sign_out @user if @user == current_user
      redirect_to root_path, notice: "Your account has been deleted"
    else
      redirect_to settings_path, alert: "Failed to delete account"
    end
  end

  def restore
    # Admin can restore archived users
    @user = User.archived_only.find(params[:id])
    @user.restore!

    redirect_to admin_users_path, notice: "User account restored"
  end
end

# Background job to permanently delete old archived users
class PurgeArchivedUsersJob < ApplicationJob
  queue_as :default

  def perform
    # Find users archived more than 90 days ago
    users_to_purge = User.archived_only
                         .where("archived_at < ?", 90.days.ago)

    users_to_purge.find_each do |user|
      # Hard delete after 90 days
      user.really_destroy!  # If using Paranoia or similar
      # Or: user.delete (bypass callbacks)
    end
  end
end
```

---

### Example 3: Task Management with Audit Trail

Comprehensive task archiving with full audit trail.

```ruby
class Task < ApplicationRecord
  include BetterModel
  belongs_to :user
  belongs_to :project

  # Enable archivable WITHOUT default scope (tasks need to be queryable)
  archivable

  predicates :title, :status, :priority, :archived_at
  sort :title, :due_date, :priority, :archived_at

  # Validations
  validates :title, presence: true
  validates :archive_reason, presence: true, if: :archived?

  # Scopes
  scope :completed, -> { where(status: "completed") }
  scope :overdue, -> { where("due_date < ? AND status != ?", Date.today, "completed") }
end

# Service object for task archival
class TaskArchiver
  def self.archive_completed_tasks(older_than: 30.days, user: nil)
    tasks = Task.completed
                .not_archived
                .where("completed_at < ?", older_than.ago)

    archived_count = 0
    errors = []

    tasks.find_each do |task|
      begin
        task.archive!(
          by: user,
          reason: "Automatically archived: completed #{older_than.inspect} ago"
        )
        archived_count += 1
      rescue => e
        errors << { task_id: task.id, error: e.message }
      end
    end

    {
      archived: archived_count,
      errors: errors,
      total: tasks.count
    }
  end

  def self.archive_abandoned_tasks(older_than: 90.days, user: nil)
    tasks = Task.not_archived
                .where(status: "in_progress")
                .where("updated_at < ?", older_than.ago)

    tasks.find_each do |task|
      task.archive!(
        by: user,
        reason: "Automatically archived: no activity for #{older_than.inspect}"
      )
    end

    tasks.count
  end
end

# Background job
class ArchiveCompletedTasksJob < ApplicationJob
  queue_as :default

  def perform(older_than: 90.days)
    result = TaskArchiver.archive_completed_tasks(
      older_than: older_than,
      user: nil  # System user
    )

    Rails.logger.info "Archived #{result[:archived]} tasks"
    Rails.logger.error "Failed to archive #{result[:errors].count} tasks" if result[:errors].any?
  end
end

# Schedule in config/initializers/scheduler.rb
# Runs every Sunday at 2 AM
Sidekiq::Cron::Job.create(
  name: 'Archive completed tasks',
  cron: '0 2 * * 0',
  class: 'ArchiveCompletedTasksJob'
)
```

**Controller:**
```ruby
class TasksController < ApplicationController
  def index
    @tasks = Task.not_archived
                 .where(user: current_user)
                 .order(due_date: :asc)
  end

  def archived
    @tasks = Task.archived
                 .where(user: current_user)
                 .order(archived_at: :desc)
                 .page(params[:page])
  end

  def archive
    @task = current_user.tasks.find(params[:id])

    if @task.archive!(by: current_user, reason: params[:reason])
      respond_to do |format|
        format.html { redirect_to tasks_path, notice: "Task archived" }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to task_path(@task), alert: "Failed to archive" }
        format.json { render json: { error: "Failed" }, status: :unprocessable_entity }
      end
    end
  end
end
```

---

### Example 4: Product Catalog with Discontinuation Tracking

E-commerce product archiving for discontinued items.

```ruby
class Product < ApplicationRecord
  include BetterModel
  belongs_to :category
  has_many :order_items

  # Archive discontinued products
  archivable

  predicates :name, :sku, :status, :price, :archived_at
  sort :name, :price, :stock, :archived_at

  searchable do
    per_page 50
    max_per_page 200
    default_order [:sort_name_asc]

    # Security: public API only shows active products
    security :active_only, [:archived_at_null]
  end

  # Validations
  validates :sku, presence: true, uniqueness: true
  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  # Business logic for discontinuation
  def discontinue!(reason:, by: nil)
    transaction do
      archive!(by: by, reason: reason)
      update!(status: "discontinued", stock: 0)
    end
  end

  def reintroduce!(by: nil)
    transaction do
      restore!
      update!(status: "active")
    end
  end

  # Check if product can be ordered
  def orderable?
    active? && stock > 0 && status == "active"
  end
end

# Admin controller
class Admin::ProductsController < Admin::BaseController
  def index
    @products = Product.not_archived
                       .page(params[:page])
  end

  def archived
    @products = Product.archived_only
                       .order(archived_at: :desc)
                       .page(params[:page])
  end

  def discontinue
    @product = Product.find(params[:id])

    if @product.discontinue!(
      reason: params[:reason],
      by: current_admin
    )
      redirect_to admin_products_path,
                  notice: "Product discontinued and archived"
    else
      redirect_to admin_product_path(@product),
                  alert: "Failed to discontinue product"
    end
  end

  def reintroduce
    @product = Product.archived_only.find(params[:id])

    if @product.reintroduce!(by: current_admin)
      redirect_to admin_product_path(@product),
                  notice: "Product reintroduced"
    else
      redirect_to admin_archived_products_path,
                  alert: "Failed to reintroduce product"
    end
  end
end

# Public API controller
class Api::V1::ProductsController < Api::BaseController
  def index
    # Security enforced: only active products
    @products = Product.search(
      { archived_at_null: true },  # Explicit filter
      orders: [:sort_name_asc],
      pagination: { page: params[:page], per_page: 50 }
    )

    render json: {
      products: @products.as_json(
        only: [:id, :name, :sku, :price, :stock, :status],
        include_archive_info: false  # Don't expose archive info to public
      ),
      meta: pagination_meta(@products)
    }
  end

  def show
    @product = Product.not_archived.find(params[:id])

    render json: @product.as_json(
      only: [:id, :name, :sku, :description, :price, :stock, :status]
    )
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product not found or discontinued" },
           status: :not_found
  end
end
```

**Statistics and Reporting:**
```ruby
class ProductStatistics
  def self.generate_report
    {
      total_products: Product.unscoped.count,
      active_products: Product.not_archived.count,
      archived_products: Product.archived.count,
      recently_discontinued: Product.archived_recently(30.days).count,
      discontinuation_reasons: Product.archived
                                     .group(:archive_reason)
                                     .count
    }
  end
end

# => {
#      total_products: 1500,
#      active_products: 1350,
#      archived_products: 150,
#      recently_discontinued: 12,
#      discontinuation_reasons: {
#        "End of life" => 45,
#        "Low sales" => 32,
#        "Supplier discontinued" => 28,
#        "Quality issues" => 15,
#        "Replaced by new model" => 30
#      }
#    }
```

---

### Example 5: Bulk Archive Operations

Background job for bulk archiving with progress tracking.

```ruby
class BulkArchiveJob < ApplicationJob
  queue_as :default

  def perform(model_class, record_ids, reason:, archived_by_id: nil)
    model = model_class.constantize

    total = record_ids.size
    archived = 0
    failed = []

    record_ids.each do |id|
      begin
        record = model.find(id)
        record.archive!(by: archived_by_id, reason: reason)
        archived += 1
      rescue => e
        failed << { id: id, error: e.message }
      end
    end

    # Notify admin of results
    AdminMailer.bulk_archive_complete(
      model: model_class,
      total: total,
      archived: archived,
      failed: failed
    ).deliver_later

    { total: total, archived: archived, failed: failed }
  end
end

# Service object for bulk operations
class BulkArchiver
  def self.archive_by_ids(model_class, ids, reason:, user:)
    # Validate
    raise ArgumentError, "No IDs provided" if ids.blank?
    raise ArgumentError, "Reason required" if reason.blank?

    # Enqueue job
    BulkArchiveJob.perform_later(
      model_class.name,
      ids,
      reason: reason,
      archived_by_id: user&.id
    )
  end

  def self.archive_by_criteria(model_class, criteria, reason:, user:)
    # Find matching records
    records = model_class.where(criteria)
    ids = records.pluck(:id)

    archive_by_ids(model_class, ids, reason: reason, user: user)
  end
end

# Controller for bulk operations
class Admin::BulkArchiveController < Admin::BaseController
  def create
    model_class = params[:model].constantize
    ids = params[:ids].map(&:to_i)

    BulkArchiver.archive_by_ids(
      model_class,
      ids,
      reason: params[:reason],
      user: current_admin
    )

    redirect_to admin_path, notice: "Bulk archive job queued. You'll receive an email when complete."
  end

  def archive_old_articles
    # Archive all articles older than 2 years with no activity
    BulkArchiver.archive_by_criteria(
      Article,
      { updated_at: ...2.years.ago, status: "draft" },
      reason: "Automatically archived: inactive for 2+ years",
      user: current_admin
    )

    redirect_to admin_articles_path, notice: "Bulk archive job started"
  end
end
```

---

### Example 6: Retention Policies and Automatic Archiving

Scheduled jobs for automatic archiving based on business rules.

```ruby
# Retention policy service
class RetentionPolicy
  POLICIES = {
    articles: {
      draft_inactive: {
        scope: -> { Article.where(status: "draft").where("updated_at < ?", 6.months.ago) },
        reason: "Draft inactive for 6+ months",
        duration: 6.months
      },
      unpublished_old: {
        scope: -> { Article.where(published_at: nil).where("created_at < ?", 1.year.ago) },
        reason: "Unpublished for 1+ year",
        duration: 1.year
      }
    },
    users: {
      unverified: {
        scope: -> { User.where(verified: false).where("created_at < ?", 30.days.ago) },
        reason: "Email not verified within 30 days",
        duration: 30.days
      },
      inactive: {
        scope: -> { User.where("last_sign_in_at < ?", 2.years.ago) },
        reason: "No activity for 2+ years",
        duration: 2.years
      }
    },
    tasks: {
      completed_old: {
        scope: -> { Task.where(status: "completed").where("completed_at < ?", 90.days.ago) },
        reason: "Completed 90+ days ago",
        duration: 90.days
      }
    }
  }.freeze

  def self.apply_all
    results = {}

    POLICIES.each do |model_name, policies|
      results[model_name] = {}

      policies.each do |policy_name, config|
        count = apply_policy(
          config[:scope].call,
          config[:reason]
        )
        results[model_name][policy_name] = count
      end
    end

    results
  end

  def self.apply_policy(scope, reason)
    archived_count = 0

    scope.find_each do |record|
      next if record.archived?

      begin
        record.archive!(reason: reason)
        archived_count += 1
      rescue => e
        Rails.logger.error "Failed to archive #{record.class.name}##{record.id}: #{e.message}"
      end
    end

    archived_count
  end
end

# Scheduled job
class ApplyRetentionPoliciesJob < ApplicationJob
  queue_as :default

  def perform
    results = RetentionPolicy.apply_all

    # Log results
    results.each do |model, policies|
      policies.each do |policy, count|
        Rails.logger.info "Retention policy #{model}.#{policy}: archived #{count} records"
      end
    end

    # Notify admins
    AdminMailer.retention_policy_applied(results).deliver_later if results.values.any?(&:positive?)
  end
end

# Schedule in config/initializers/scheduler.rb
# Runs daily at 3 AM
Sidekiq::Cron::Job.create(
  name: 'Apply retention policies',
  cron: '0 3 * * *',
  class: 'ApplyRetentionPoliciesJob'
)
```

**Admin dashboard:**
```ruby
class Admin::RetentionPoliciesController < Admin::BaseController
  def index
    @policies = RetentionPolicy::POLICIES

    @preview = {}
    @policies.each do |model_name, policies|
      @preview[model_name] = {}

      policies.each do |policy_name, config|
        @preview[model_name][policy_name] = config[:scope].call.count
      end
    end
  end

  def apply
    ApplyRetentionPoliciesJob.perform_later

    redirect_to admin_retention_policies_path,
                notice: "Retention policies job queued"
  end

  def preview
    policy = RetentionPolicy::POLICIES.dig(
      params[:model].to_sym,
      params[:policy].to_sym
    )

    @records = policy[:scope].call.limit(100)

    render json: {
      total: policy[:scope].call.count,
      reason: policy[:reason],
      preview: @records.as_json(only: [:id, :created_at, :updated_at])
    }
  end
end
```

### GDPR Compliance and Data Retention System

```ruby
class GdprComplianceService
  # GDPR Article 17: Right to erasure
  class << self
    def process_deletion_request(user)
      user.transaction do
        # Archive user data (for legal retention period)
        user.archive!(
          reason: "GDPR deletion request",
          by: user
        )

        # Anonymize personal data
        user.update!(
          email: "deleted-#{user.id}@example.com",
          name: "Deleted User",
          phone: nil,
          address: nil
        )

        # Archive associated records
        archive_user_content(user)

        # Schedule permanent deletion after legal retention
        SchedulePermanentDeletionJob.set(wait: 30.days).perform_later(user.id)
      end
    end

    def archive_user_content(user)
      # Archive all user-created content
      user.articles.find_each { |article| article.archive!(reason: "User deletion") }
      user.comments.find_each { |comment| comment.archive!(reason: "User deletion") }
      user.uploads.find_each { |upload| upload.archive!(reason: "User deletion") }
    end

    def apply_retention_policies
      # Data older than retention period
      archive_inactive_accounts
      archive_old_logs
      purge_expired_archives
    end

    private

    def archive_inactive_accounts
      # Archive accounts inactive for 3 years
      User
        .not_archived
        .where("last_login_at < ?", 3.years.ago)
        .find_each do |user|
          user.archive!(reason: "Inactive for 3 years")
        end
    end

    def archive_old_logs
      # Archive logs older than 1 year
      ActivityLog
        .not_archived
        .where("created_at < ?", 1.year.ago)
        .find_in_batches(batch_size: 1000) do |batch|
          batch.each { |log| log.archive!(reason: "Retention policy") }
        end
    end

    def purge_expired_archives
      # Permanently delete archives older than legal retention period
      User
        .archived
        .where("archived_at < ?", 7.years.ago)
        .destroy_all

      Article
        .archived
        .where("archived_at < ?", 5.years.ago)
        .destroy_all
    end
  end
end

# Scheduled job
class DataRetentionJob < ApplicationJob
  queue_as :default

  def perform
    GdprComplianceService.apply_retention_policies
  end
end
```

### Cascade Archiving with Dependent Records

```ruby
class Project < ApplicationRecord
  include BetterModel
  archivable tracking: true

  has_many :tasks, dependent: :destroy
  has_many :milestones, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :team_members, dependent: :destroy

  # Cascade archive to all dependent records
  def archive_with_dependencies!(by:, reason:)
    transaction do
      # Archive all dependent records first
      tasks.not_archived.find_each do |task|
        task.archive!(by: by, reason: "Parent project archived: #{reason}")
      end

      milestones.not_archived.find_each do |milestone|
        milestone.archive!(by: by, reason: "Parent project archived")
      end

      documents.not_archived.find_each do |doc|
        doc.archive!(by: by, reason: "Parent project archived")
      end

      # Archive the project itself
      archive!(by: by, reason: reason)

      # Notify team members
      ProjectMailer.project_archived(self, team_members).deliver_later
    end
  end

  # Restore with dependencies
  def restore_with_dependencies!(by:)
    transaction do
      # Restore project first
      restore!(by: by)

      # Restore dependent records
      tasks.archived_only.find_each(&:restore!)
      milestones.archived_only.find_each(&:restore!)
      documents.archived_only.find_each(&:restore!)

      # Notify team
      ProjectMailer.project_restored(self, team_members).deliver_later
    end
  end
end

# Migration from paranoia/acts_as_paranoid
class MigrateToArchivable < ActiveRecord::Migration[7.0]
  def up
    # Rename deleted_at to archived_at
    rename_column :articles, :deleted_at, :archived_at

    # Add tracking columns
    add_column :articles, :archived_by_id, :integer
    add_column :articles, :archive_reason, :text

    # Add indexes
    add_index :articles, :archived_at
    add_index :articles, :archived_by_id

    # Update existing archived records
    Article.where.not(archived_at: nil).find_each do |article|
      article.update_column(:archive_reason, "Migrated from soft delete")
    end
  end

  def down
    rename_column :articles, :archived_at, :deleted_at
    remove_column :articles, :archived_by_id
    remove_column :articles, :archive_reason
  end
end
```

### Testing Archivable Models

```ruby
# spec/models/article_spec.rb
require "rails_helper"

RSpec.describe Article, type: :model do
  describe "Archivable" do
    let(:user) { create(:user) }
    let(:article) { create(:article) }

    describe "#archive!" do
      it "sets archived_at timestamp" do
        expect {
          article.archive!
        }.to change { article.archived_at }.from(nil)
      end

      it "records who archived" do
        article.archive!(by: user)
        expect(article.archived_by).to eq(user)
      end

      it "records archive reason" do
        article.archive!(reason: "Policy violation")
        expect(article.archive_reason).to eq("Policy violation")
      end

      it "runs callbacks" do
        expect(article).to receive(:before_archive_callback)
        article.archive!
      end

      it "raises error if already archived" do
        article.archive!
        expect {
          article.archive!
        }.to raise_error("Article is already archived")
      end
    end

    describe "#restore!" do
      before { article.archive! }

      it "clears archived_at" do
        expect {
          article.restore!
        }.to change { article.archived_at }.to(nil)
      end

      it "clears archive tracking" do
        article.archive!(by: user, reason: "Test")
        article.restore!

        expect(article.archived_by).to be_nil
        expect(article.archive_reason).to be_nil
      end

      it "runs restore callbacks" do
        expect(article).to receive(:after_restore_callback)
        article.restore!
      end
    end

    describe "scopes" do
      let!(:active_article) { create(:article) }
      let!(:archived_article) { create(:article, archived_at: 1.day.ago) }

      describe ".not_archived" do
        it "returns only non-archived records by default" do
          expect(Article.all).to include(active_article)
          expect(Article.all).not_to include(archived_article)
        end
      end

      describe ".archived" do
        it "returns archived records" do
          results = Article.archived
          expect(results).to include(archived_article)
          expect(results).not_to include(active_article)
        end
      end

      describe ".archived_only" do
        it "returns only archived records" do
          results = Article.archived_only
          expect(results).to eq([archived_article])
        end
      end

      describe ".with_archived" do
        it "includes both archived and active records" do
          results = Article.with_archived
          expect(results).to include(active_article, archived_article)
        end
      end
    end

    describe "cascade archiving" do
      let(:project) { create(:project) }
      let!(:task1) { create(:task, project: project) }
      let!(:task2) { create(:task, project: project) }

      it "archives all dependent records" do
        project.archive_with_dependencies!(by: user, reason: "Completed")

        expect(project.archived?).to be true
        expect(task1.reload.archived?).to be true
        expect(task2.reload.archived?).to be true
      end

      it "restores all dependent records" do
        project.archive_with_dependencies!(by: user, reason: "Test")
        project.restore_with_dependencies!(by: user)

        expect(project.archived?).to be false
        expect(task1.reload.archived?).to be false
        expect(task2.reload.archived?).to be false
      end
    end

    describe "GDPR compliance" do
      let(:user) { create(:user) }

      before do
        create_list(:article, 3, author: user)
        create_list(:comment, 5, user: user)
      end

      it "archives all user content on deletion request" do
        GdprComplianceService.process_deletion_request(user)

        expect(user.archived?).to be true
        expect(user.articles.all?(&:archived?)).to be true
        expect(user.comments.all?(&:archived?)).to be true
      end

      it "anonymizes user personal data" do
        original_email = user.email
        GdprComplianceService.process_deletion_request(user)

        expect(user.reload.email).not_to eq(original_email)
        expect(user.email).to match(/deleted-\d+@example.com/)
        expect(user.name).to eq("Deleted User")
      end
    end

    describe "retention policies" do
      let!(:old_user) { create(:user, last_login_at: 4.years.ago) }
      let!(:active_user) { create(:user, last_login_at: 1.day.ago) }

      it "archives inactive accounts" do
        GdprComplianceService.apply_retention_policies

        expect(old_user.reload.archived?).to be true
        expect(active_user.reload.archived?).to be false
      end

      it "purges old archives" do
        article = create(:article, archived_at: 6.years.ago)

        expect {
          GdprComplianceService.apply_retention_policies
        }.to change { Article.with_archived.count }.by(-1)
      end
    end
  end
end
```

---

## Best Practices

### 1. Always Use Tracking Columns for Important Models

Track who archived and why for audit trails:

```ruby
# ✅ Good: Full audit trail
article.archive!(
  by: current_user,
  reason: "Policy violation - inappropriate content"
)

# ⚠️ Acceptable for less critical models
article.archive!(reason: "Outdated")

# ❌ Poor: No audit trail
article.archive!  # Can't track who or why
```

### 2. Use Semantic Scopes for Readability

```ruby
# ✅ Good: Clear intent
Article.not_archived.where(status: "published")

# ⚠️ Acceptable but less clear
Article.archived_at_null(true).where(status: "published")
```

### 3. Index Archive Columns

Always add database indexes:

```ruby
# ✅ Good: Indexed for performance
add_index :articles, :archived_at
add_index :articles, :archived_by_id

# ❌ Poor: No indexes (slow queries)
# (missing indexes)
```

### 4. Validate Archive Reasons for Critical Data

```ruby
class Article < ApplicationRecord
  archivable

  # ✅ Good: Require reason
  validates :archive_reason,
            presence: true,
            length: { minimum: 10 },
            if: :archived?
end
```

### 5. Be Cautious with Default Scope

```ruby
# ✅ Use for user-facing models
class User < ApplicationRecord
  archivable do
    skip_archived_by_default true
  end
end

# ❌ Don't use for admin/audit models
class AuditLog < ApplicationRecord
  archivable  # No default scope
end

# ⚠️ Watch out for associations
Article.find(1).comments  # Might break if default scope applied
```

### 6. Use Helper Methods for Readability

```ruby
# ✅ Good: Semantic and readable
Article.archived_recently(7.days)
Article.archived_today

# ⚠️ Acceptable
Article.archived_at_within(7.days)
Article.archived_at_gteq(Date.today.beginning_of_day)
```

### 7. Handle Errors Gracefully

```ruby
# ✅ Good: Explicit error handling
def archive
  @article.archive!(by: current_user, reason: params[:reason])
  redirect_to articles_path, notice: "Archived"
rescue BetterModel::Errors::Archivable::AlreadyArchivedError
  redirect_to @article, alert: "Already archived"
rescue BetterModel::Errors::Archivable::NotEnabledError
  redirect_to @article, alert: "Archiving not enabled"
end
```

### 8. Use Explicit Scopes with Default Scope

```ruby
# ✅ Good: Explicit about what you're querying
Article.not_archived.count
Article.archived_only.count

# ❌ Confusing: Implicit behavior
Article.count  # What does this return?
```

### 9. Consider Business Logic in Custom Methods

```ruby
class Product < ApplicationRecord
  archivable

  # ✅ Good: Business logic wrapper
  def discontinue!(reason:)
    transaction do
      archive!(reason: reason)
      update!(status: "discontinued", stock: 0)
      notify_customers_of_discontinuation
    end
  end
end
```

### 10. Test Archive Behavior

```ruby
# test/models/article_test.rb
class ArticleTest < ActiveSupport::TestCase
  test "archives with tracking" do
    article = articles(:one)
    user = users(:admin)

    article.archive!(by: user, reason: "Test")

    assert article.archived?
    assert_equal user.id, article.archived_by_id
    assert_equal "Test", article.archive_reason
    assert_not_nil article.archived_at
  end

  test "raises error when archiving archived record" do
    article = articles(:one)
    article.archive!

    assert_raises(BetterModel::Errors::Archivable::AlreadyArchivedError) do
      article.archive!
    end
  end

  test "restores archived record" do
    article = articles(:one)
    article.archive!(reason: "Test")
    article.restore!

    assert article.active?
    assert_nil article.archived_at
    assert_nil article.archived_by_id
    assert_nil article.archive_reason
  end
end
```

---

## Thread Safety

Archivable is designed to be thread-safe for concurrent Rails applications.

### Immutable Configuration

Configuration is frozen after model initialization:

```ruby
class Article < ApplicationRecord
  archivable do
    skip_archived_by_default true
  end
end

# Configuration is immutable - cannot be changed at runtime
```

### No Mutable Shared State

Instance methods operate on individual records with no shared state:

```ruby
# ✅ Thread-safe: Each operates on separate records
Thread.new { article_1.archive! }
Thread.new { article_2.archive! }
Thread.new { article_3.restore! }

# No race conditions, no mutex locks needed
```

### Predicate Registry

Predicates are registered once at class load time:

```ruby
# When Rails loads Article model:
# 1. `archivable` is called
# 2. Predicates for `archived_at` are registered via Predicable
# 3. Scopes are defined
# 4. Configuration is frozen

# In production with multiple threads:
# - All threads share the same pre-defined scopes
# - No runtime registration
# - No synchronization needed
```

---

## Performance Notes

### Zero Configuration Overhead

Archivable configuration happens at class load time:

```ruby
# When Rails boots:
class Article < ApplicationRecord
  archivable  # Configuration happens once
end

# In production:
article.archive!  # Direct method call, no overhead
```

### Efficient Queries

Scopes use optimized SQL:

```ruby
# Efficient index usage
Article.archived  # Uses index on archived_at
Article.not_archived  # Uses index on archived_at IS NULL

# Efficient with proper indexes
Article.archived_at_between(start_date, end_date)  # Range scan
```

### Index Recommendations

```ruby
# Essential indexes
add_index :articles, :archived_at

# For tracking columns
add_index :articles, :archived_by_id

# Composite indexes for common queries
add_index :articles, [:status, :archived_at]
add_index :articles, [:archived_at, :created_at]
```

### N+1 Query Prevention

```ruby
# ❌ Poor: N+1 queries
Article.archived.each do |article|
  puts article.author.name  # N queries
end

# ✅ Good: Eager loading
Article.archived.includes(:author).each do |article|
  puts article.author.name  # 2 queries total
end
```

---

## Key Takeaways

1. **Opt-in by design** - Explicitly enable with `archivable` in models
2. **Soft delete pattern** - Archive instead of destroy for data retention
3. **Track everything** - Use `by:` and `reason:` for audit trails
4. **Use `restore!`** - Correct method name (not `unarchive!`)
5. **Helper methods exist** - `archived_today`, `archived_this_week`, `archived_recently(duration)`
6. **Predicates auto-generated** - Get all datetime predicates via Predicable
7. **Default scope optional** - Use `skip_archived_by_default` for user-facing models
8. **Searchable integration** - Filter by archive status in unified search
9. **JSON serialization** - Use `include_archive_info: true` for APIs
10. **Index your columns** - Always index `archived_at` and `archived_by_id`
11. **No cascade** - Cascade archiving does NOT exist in the gem
12. **No callbacks** - `after_archive`/`after_unarchive` callbacks do NOT exist
13. **Validate reasons** - Require `archive_reason` for important models
14. **Test thoroughly** - Test archive, restore, and error cases
15. **Use explicit scopes** - Prefer `archived_only` over `unscoped` with default scope
