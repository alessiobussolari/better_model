# Archivable

Archivable provides a declarative soft-delete system for Rails models with archive tracking, audit trails, and restoration capabilities. Unlike traditional soft-delete gems, Archivable is opt-in, integrates seamlessly with BetterModel's Predicable and Searchable concerns, and provides powerful query capabilities.

## Table of Contents

- [Overview](#overview)
- [Database Setup](#database-setup)
  - [Option 1: Using Generator (Recommended)](#option-1-using-generator-recommended)
  - [Option 2: Manual Migration](#option-2-manual-migration)
- [Configuration](#configuration)
- [Instance Methods](#instance-methods)
- [Scopes](#scopes)
- [Predicates](#predicates)
- [Default Scope](#default-scope)
- [Integration with Searchable](#integration-with-searchable)
- [JSON Serialization](#json-serialization)
- [Real-world Examples](#real-world-examples)
- [Best Practices](#best-practices)

## Overview

**Key Features:**

- **Opt-in Activation**: Archivable is not active by default. You must explicitly enable it with `archivable do...end`.
- **Soft Delete**: Archive records instead of deleting them permanently.
- **Archive Tracking**: Track who archived a record and why (optional).
- **Restoration**: Restore archived records with a single method call.
- **Status Methods**: Check if a record is archived or active.
- **Powerful Scopes**: Query archived, active, or all records with ease.
- **Automatic Predicates**: Get datetime predicates for `archived_at` automatically.
- **Optional Default Scope**: Hide archived records by default (configurable).
- **Searchable Integration**: Use archive predicates in unified search queries.
- **Thread-safe**: Immutable configuration and registry.

## Database Setup

Archivable requires at least one database column (`archived_at`). You can optionally add tracking columns for audit trails.

### Option 1: Using Generator (Recommended)

The BetterModel gem provides a generator to create the migration automatically.

#### Basic Setup (archived_at only)

```bash
rails generate better_model:archivable Article
rails db:migrate
```

This creates:

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

#### With Full Tracking (archived_at + archived_by_id + archive_reason)

```bash
rails generate better_model:archivable Article --with-tracking
rails db:migrate
```

This creates:

```ruby
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    change_table :articles do |t|
      t.datetime :archived_at
      t.integer :archived_by_id
      t.string :archive_reason
    end

    add_index :articles, :archived_at
    add_index :articles, :archived_by_id
  end
end
```

#### Generator Options

| Option | Description |
|--------|-------------|
| `--with-tracking` | Adds both `archived_by_id` and `archive_reason` columns |
| `--with-by` | Adds only the `archived_by_id` column |
| `--with-reason` | Adds only the `archive_reason` column |
| `--skip-indexes` | Skips adding indexes on archivable columns |

**Examples:**

```bash
# Only archived_by_id tracking
rails g better_model:archivable Article --with-by
rails db:migrate

# Only archive_reason tracking
rails g better_model:archivable Article --with-reason
rails db:migrate

# Without indexes (not recommended)
rails g better_model:archivable Article --skip-indexes
rails db:migrate
```

### Option 2: Manual Migration

If you prefer not to use the generator, you can create the migration manually by copying and pasting the code below.

#### Minimal Setup (archived_at only)

```ruby
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    change_table :articles do |t|
      # Required column for archivable
      t.datetime :archived_at
    end

    # Index for performance
    add_index :articles, :archived_at
  end
end
```

#### With Full Tracking

```ruby
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    change_table :articles do |t|
      # Required column for archivable
      t.datetime :archived_at

      # Optional: track who archived the record
      t.integer :archived_by_id

      # Optional: track why the record was archived
      t.string :archive_reason
    end

    # Indexes for performance
    add_index :articles, :archived_at
    add_index :articles, :archived_by_id
  end
end
```

**Column Reference:**

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| `archived_at` | datetime | ✅ Yes | Timestamp when record was archived |
| `archived_by_id` | integer | ⚪ No | ID of user who archived the record |
| `archive_reason` | string | ⚪ No | Reason for archiving |

## Configuration

Enable Archivable in your model with the `archivable` DSL:

### Basic Activation

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable archivable (opt-in)
  archivable
end
```

### With Configuration Block

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable archivable with configuration
  archivable do
    skip_archived_by_default true  # Hide archived records by default
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `skip_archived_by_default` | Boolean | `false` | When `true`, applies a default scope to hide archived records. Use `archived_only` or `unscoped` to query archived records. |

**Important Notes:**

- Archivable is **opt-in**. You must call `archivable` to enable it.
- When you enable archivable, predicates and sort scopes for `archived_at` are automatically generated (via Predicable and Sortable).
- The model will raise `NotEnabledError` if you try to use archivable methods without enabling it first.

## Instance Methods

### `archive!(by:, reason:)`

Archive a record with optional tracking.

**Parameters:**
- `by` (optional): User ID (Integer) or User object (responds to `.id`)
- `reason` (optional): String explaining why the record was archived

**Returns:** `self`

**Raises:**
- `NotEnabledError` if archivable is not enabled
- `AlreadyArchivedError` if record is already archived

**Examples:**

```ruby
# Basic archiving
article.archive!
# => Sets archived_at to current time

# With user tracking
article.archive!(by: current_user)
# => Sets archived_at and archived_by_id

# With user ID
article.archive!(by: 123)
# => Sets archived_at and archived_by_id = 123

# With reason
article.archive!(reason: "Content is outdated")
# => Sets archived_at and archive_reason

# With both tracking options
article.archive!(by: current_user, reason: "Policy violation")
# => Sets archived_at, archived_by_id, and archive_reason
```

### `restore!`

Restore an archived record.

**Returns:** `self`

**Raises:**
- `NotEnabledError` if archivable is not enabled
- `NotArchivedError` if record is not archived

**Examples:**

```ruby
article.restore!
# => Clears archived_at, archived_by_id, and archive_reason
```

### `archived?`

Check if the record is archived.

**Returns:** `Boolean`

**Examples:**

```ruby
article.archived?
# => true if archived_at is present, false otherwise

article.archive!
article.archived?  # => true

article.restore!
article.archived?  # => false
```

### `active?`

Check if the record is NOT archived (active).

**Returns:** `Boolean`

**Examples:**

```ruby
article.active?
# => true if archived_at is nil, false otherwise

article.archive!
article.active?  # => false

article.restore!
article.active?  # => true
```

## Scopes

Archivable provides semantic scopes for querying records:

### `archived`

Find all archived records.

**Alias for:** `archived_at_present`

**Examples:**

```ruby
Article.archived
# => SELECT * FROM articles WHERE archived_at IS NOT NULL

Article.archived.count
# => 5
```

### `not_archived`

Find all active (non-archived) records.

**Alias for:** `archived_at_null`

**Examples:**

```ruby
Article.not_archived
# => SELECT * FROM articles WHERE archived_at IS NULL

Article.not_archived.count
# => 42
```

### `archived_only`

Find ONLY archived records, bypassing any default scope.

**Useful when:** `skip_archived_by_default` is enabled.

**Examples:**

```ruby
# If you have skip_archived_by_default enabled:
Article.all          # => Only active records (archived hidden by default scope)
Article.archived     # => Still works, but respects default scope
Article.archived_only # => Explicitly bypasses default scope and shows only archived
```

### Chaining Scopes

```ruby
# Archived articles from last week
Article.archived.where("archived_at >= ?", 1.week.ago)

# Active published articles
Article.not_archived.where(status: "published")

# Archived articles with specific reason
Article.archived.where(archive_reason: "Spam")
```

## Predicates

When you enable archivable, predicates for `archived_at` are automatically generated via Predicable. These provide powerful datetime querying capabilities.

### Standard Datetime Predicates

All datetime predicates from Predicable are available:

```ruby
# Equality and null checks
Article.archived_at_present       # archived_at IS NOT NULL
Article.archived_at_null          # archived_at IS NULL

# Comparisons
Article.archived_at_eq(date)      # archived_at = date
Article.archived_at_not_eq(date)  # archived_at != date
Article.archived_at_gt(date)      # archived_at > date
Article.archived_at_gteq(date)    # archived_at >= date
Article.archived_at_lt(date)      # archived_at < date
Article.archived_at_lteq(date)    # archived_at <= date

# Range queries
Article.archived_at_between(start_date, end_date)
# => archived_at BETWEEN start_date AND end_date

# Time-based helpers
Article.archived_at_today         # Archived today
Article.archived_at_this_week     # Archived this week
Article.archived_at_this_month    # Archived this month
Article.archived_at_this_year     # Archived this year

# Within duration
Article.archived_at_within(7.days)
# => Archived in last 7 days
```

### Helper Methods

Archivable provides semantic aliases for common queries:

#### `archived_today`

Alias for `archived_at_today`.

```ruby
Article.archived_today
# => Articles archived today
```

#### `archived_this_week`

Alias for `archived_at_this_week`.

```ruby
Article.archived_this_week
# => Articles archived this week
```

#### `archived_recently(duration = 7.days)`

Alias for `archived_at_within(duration)`.

```ruby
Article.archived_recently
# => Articles archived in last 7 days (default)

Article.archived_recently(30.days)
# => Articles archived in last 30 days

Article.archived_recently(1.hour)
# => Articles archived in last hour
```

## Default Scope

You can configure Archivable to hide archived records by default:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end
end
```

**Behavior:**

```ruby
# With skip_archived_by_default: true

Article.all
# => Only active records (archived_at IS NULL)

Article.count
# => 42 (only active records)

Article.archived
# => Empty (default scope filters them out)

Article.archived_only
# => 5 archived records (bypasses default scope)

Article.unscoped.archived
# => 5 archived records (bypasses default scope)
```

**When to use:**

- ✅ Use when archived records should be hidden in most queries
- ✅ Use for models where "active" is the default state
- ❌ Avoid if you frequently need to query archived records
- ❌ Be careful with associations (default scopes can cause unexpected behavior)

**Best Practice:**

If you enable `skip_archived_by_default`, always use explicit scopes:

```ruby
# Good
Article.not_archived.where(status: "published")
Article.archived_only.where("archived_at > ?", 1.month.ago)

# Risky (relies on default scope)
Article.where(status: "published")  # Might be confusing
```

## Integration with Searchable

Archivable works seamlessly with BetterModel's Searchable concern:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end

  predicates :title, :status, :archived_at
  sort :title, :archived_at

  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_created_at_desc]
  end
end
```

### Search Examples

```ruby
# Find active published articles
Article.search(
  { archived_at_null: true, status_eq: "published" },
  orders: [:sort_title_asc]
)

# Find articles archived in last 7 days
Article.search(
  { archived_at_within: 7.days },
  orders: [:sort_archived_at_desc]
)

# Find archived articles with specific reason
Article.search(
  { archived_at_present: true, archive_reason_cont: "spam" }
)

# Complex query with OR conditions
Article.search(
  { status_eq: "published" },
  or_conditions: [
    { archived_at_null: true },
    { archived_at_gt: 30.days.ago }
  ],
  orders: [:sort_archived_at_desc],
  pagination: { page: 1, per_page: 25 }
)
```

## JSON Serialization

Archivable enhances `as_json` to include archive metadata:

```ruby
article = Article.find(1)
article.archive!(by: current_user, reason: "Outdated")

# Basic JSON (default)
article.as_json
# => { "id" => 1, "title" => "...", "archived_at" => "2025-10-29..." }

# With archive info
article.as_json(include_archive_info: true)
# => {
#      "id" => 1,
#      "title" => "...",
#      "archive_info" => {
#        "archived" => true,
#        "archived_at" => "2025-10-29T10:30:00Z",
#        "archived_by_id" => 123,
#        "archive_reason" => "Outdated"
#      }
#    }
```

## Real-world Examples

### Example 1: Article Management System

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable archivable with default scope
  archivable do
    skip_archived_by_default true
  end

  predicates :title, :status, :archived_at
  sort :title, :published_at, :archived_at

  searchable do
    per_page 25
    default_order [:sort_published_at_desc]
  end
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
    @article.archive!(by: current_user, reason: params[:reason])
    redirect_to articles_path, notice: "Article archived"
  end

  def restore
    @article = Article.archived_only.find(params[:id])
    @article.restore!
    redirect_to articles_path, notice: "Article restored"
  end

  def archived
    @articles = Article.archived_only.page(params[:page])
  end
end
```

### Example 2: User Account Management

```ruby
class User < ApplicationRecord
  include BetterModel

  # Archive instead of hard delete
  archivable do
    skip_archived_by_default true
  end

  predicates :email, :archived_at
  sort :email, :created_at, :archived_at

  # Override destroy to archive instead
  def destroy
    archive!(reason: "User requested account deletion")
  end
end

# Usage
user = User.find_by(email: "user@example.com")
user.destroy  # Archives instead of deleting
# => archived_at: 2025-10-29, archive_reason: "User requested account deletion"

# Restore user
user = User.archived_only.find_by(email: "user@example.com")
user.restore!
# => archived_at: nil, archive_reason: nil

# Find users archived in last 30 days
User.archived_recently(30.days)
```

### Example 3: Task Management with Audit Trail

```ruby
class Task < ApplicationRecord
  include BetterModel
  belongs_to :user

  archivable  # No default scope - tasks can be queried freely

  predicates :title, :status, :archived_at
  sort :title, :due_date, :archived_at

  # Custom validation
  validates :archive_reason, presence: true, if: :archived?
end

# Usage in service object
class TaskArchiver
  def self.archive_completed_tasks(older_than: 30.days)
    tasks = Task.where(status: "completed")
                .where("completed_at < ?", older_than.ago)

    archived_count = 0
    tasks.find_each do |task|
      task.archive!(
        by: task.user,
        reason: "Automatically archived: completed #{older_than.inspect} ago"
      )
      archived_count += 1
    end

    archived_count
  end
end

# Run archiver
TaskArchiver.archive_completed_tasks(older_than: 90.days)
# => Archives all tasks completed more than 90 days ago
```

### Example 4: Product Catalog

```ruby
class Product < ApplicationRecord
  include BetterModel

  # Archive discontinued products
  archivable

  predicates :name, :sku, :status, :archived_at
  sort :name, :price, :archived_at

  searchable do
    per_page 50
    default_order [:sort_name_asc]
    security :active_only, [:archived_at_null]
  end

  # Business logic
  def discontinue!(reason:)
    archive!(reason: reason)
    update!(status: "discontinued")
  end

  def reintroduce!
    restore!
    update!(status: "active")
  end
end

# Usage
product = Product.find_by(sku: "ABC123")

# Discontinue product
product.discontinue!(reason: "Replaced by new model")
# => archived_at: 2025-10-29, archive_reason: "Replaced by new model"

# Search active products only (enforced by security)
Product.search({ archived_at_null: true, status_eq: "active" })

# Find discontinued products from last quarter
Product.archived_at_between(3.months.ago, Time.current)
       .where(status: "discontinued")
```

## Best Practices

### 1. Always Use Tracking Columns for Audit Trails

```ruby
# Good: Track who and why
article.archive!(by: current_user, reason: "Policy violation")

# Acceptable: Basic archiving
article.archive!

# Bad: Missing audit trail for important models
# (No way to know who archived it or why)
```

### 2. Use Semantic Scopes for Readability

```ruby
# Good: Clear intent
Article.not_archived.where(status: "published")

# Bad: Using raw predicates (less readable)
Article.archived_at_null.where(status: "published")
```

### 3. Be Careful with Default Scope

```ruby
# Good: Explicit scopes when using skip_archived_by_default
Article.not_archived.count  # Clear
Article.archived_only.count  # Clear

# Risky: Implicit queries
Article.count  # Could be confusing if default scope is applied
```

### 4. Index Archived Columns

Always add indexes to `archived_at` (and `archived_by_id` if used):

```ruby
add_index :articles, :archived_at
add_index :articles, :archived_by_id
```

### 5. Validate Archive Reasons for Important Models

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable

  validates :archive_reason, presence: true, if: :archived?
end
```

### 6. Use Helper Methods for Common Queries

```ruby
# Good: Readable and semantic
Article.archived_recently(7.days)
Article.archived_today

# Acceptable: Direct predicates
Article.archived_at_within(7.days)
Article.archived_at_today
```

### 7. Consider Associations

When using `skip_archived_by_default`, be aware of how it affects associations:

```ruby
class Article < ApplicationRecord
  include BetterModel
  has_many :comments

  archivable do
    skip_archived_by_default true
  end
end

# This might not work as expected:
article.comments  # Could be empty if default scope hides archived article

# Better:
Article.unscoped.find(id).comments
```

### 8. Use `archived_only` for Admin Interfaces

```ruby
# Admin controller
class Admin::ArticlesController < Admin::BaseController
  def archived
    @articles = Article.archived_only.page(params[:page])
  end

  def restore
    @article = Article.archived_only.find(params[:id])
    @article.restore!
    redirect_to admin_articles_path
  end
end
```
