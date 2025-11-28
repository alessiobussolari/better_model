# Archivable - Declarative Soft Delete System

Soft delete pattern that archives records instead of permanently deleting them. Track who archived, when, why, and restore with one method call.

**Requirements**: Rails 8.0+, Ruby 3.0+, `archived_at` datetime column
**Installation**: `rails generate better_model:archivable Model`

**⚠️ Version 3.0.0 Compatible**: All error handling in this document uses standard Ruby exception patterns.

---

## Database Setup

### Basic Migration

**Cosa fa**: Adds archived_at column for soft delete

**Quando usarlo**: For basic soft delete without tracking

**Esempio**:
```bash
rails generate better_model:archivable Article
rails db:migrate
```

```ruby
# Generated migration
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :archived_at, :datetime
    add_index :articles, :archived_at
  end
end
```

---

### With Full Tracking

**Cosa fa**: Adds columns to track who archived and why

**Quando usarlo**: For audit trails and compliance

**Esempio**:
```bash
rails generate better_model:archivable Article --with-tracking
rails db:migrate
```

```ruby
# Generated migration
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

---

## Basic Configuration

### Simple Activation

**Cosa fa**: Enables archivable on model

**Quando usarlo**: For opt-in soft delete

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable archivable (opt-in)
  archivable
end

# Automatically adds:
# - Instance methods: archive!, restore!, archived?, active?
# - Scopes: archived, not_archived, archived_only
# - Predicates for archived_at via Predicable
```

---

### Hide Archived by Default

**Cosa fa**: Applies default scope to hide archived records

**Quando usarlo**: When most queries should only show active records

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end
end

# Queries
User.all           # => Only active users (archived hidden)
User.count         # => Count active users only
User.archived_only # => Shows archived users (bypasses default scope)
User.unscoped.all  # => All users (active + archived)
```

---

## Archiving Records

### Basic Archive

**Cosa fa**: Archives a record

**Quando usarlo**: For soft delete instead of destroy

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

article = Article.find(1)
article.archive!
# => archived_at: 2025-11-11 10:30:00

# Check status
article.archived?  # => true
article.active?    # => false
```

---

### Archive with User Tracking

**Cosa fa**: Tracks who archived the record

**Quando usarlo**: For audit trails

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

# With User object
article.archive!(by: current_user)
# => archived_at: 2025-11-11 10:30:00
#    archived_by_id: 123

# With User ID
article.archive!(by: 123)
# => archived_at: 2025-11-11 10:30:00
#    archived_by_id: 123
```

---

### Archive with Reason

**Cosa fa**: Records why the record was archived

**Quando usarlo**: For documentation and compliance

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

# With reason only
article.archive!(reason: "Content is outdated")
# => archived_at: 2025-11-11 10:30:00
#    archive_reason: "Content is outdated"

# With both user and reason
article.archive!(
  by: current_user,
  reason: "Policy violation - inappropriate content"
)
# => archived_at: 2025-11-11 10:30:00
#    archived_by_id: 123
#    archive_reason: "Policy violation - inappropriate content"
```

---

## Restoring Records

### Basic Restore

**Cosa fa**: Restores an archived record

**Quando usarlo**: To recover accidentally archived records

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

article = Article.archived_only.find(1)
article.restore!
# => archived_at: nil
#    archived_by_id: nil (cleared)
#    archive_reason: nil (cleared)

# Check status
article.archived?  # => false
article.active?    # => true
```

---

## Querying Records

### Basic Scopes

**Cosa fa**: Queries archived, active, or all records

**Quando usarlo**: For filtering by archive status

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

# Active records only (not archived)
Article.not_archived
Article.active  # Alias

# Archived records only
Article.archived

# All records (bypasses any default scope)
Article.archived_only
```

---

### Time-Based Queries

**Cosa fa**: Queries by archive date using Predicable predicates

**Quando usarlo**: For time-based archive analysis

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable

  # Predicates automatically registered for archived_at
  predicates :archived_at
end

# Archived today
Article.archived_at_gteq(Date.today.beginning_of_day)

# Archived this week
Article.archived_at_gteq(Date.today.beginning_of_week)

# Archived in date range
Article.archived_at_between(1.month.ago, Date.today)

# Archived recently (last 7 days)
Article.archived_at_within(7.days)
```

---

### Combining with Other Predicates

**Cosa fa**: Combines archive status with other filters

**Quando usarlo**: For complex archive queries

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable

  predicates :status, :author_id, :archived_at
end

# Archived articles by specific author
Article.archived
       .author_id_eq(123)

# Published articles archived this month
Article.archived
       .status_eq("published")
       .archived_at_gteq(Date.today.beginning_of_month)

# Active articles (not archived)
Article.not_archived
       .status_in(["draft", "published"])
```

---

## Status Predicates

### Checking Archive Status

**Cosa fa**: Boolean methods to check if record is archived

**Quando usarlo**: For conditional logic based on archive state

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

article = Article.find(1)

# Check if archived
article.archived?  # => true/false

# Check if active (opposite of archived)
article.active?    # => true/false
article.not_archived?  # Alias for active?

# Conditional logic
if article.archived?
  puts "This article was archived on #{article.archived_at}"
else
  puts "This article is currently active"
end
```

---

## Integration with Searchable

### Using in Search

**Cosa fa**: Uses archive predicates in unified search

**Quando usarlo**: For API filtering with archive status

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable
  predicates :title, :status, :archived_at
  sort :title, :published_at

  searchable do
    per_page 25
    default_order [:sort_published_at_newest]
  end
end

# Controller
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      {
        status_eq: params[:status],
        archived_at_null: params[:include_archived] ? false : true
      },
      pagination: { page: params[:page], per_page: 25 }
    )

    render json: @articles
  end

  def archived
    @articles = Article.search(
      { archived_at_null: false },  # Only archived
      pagination: { page: params[:page], per_page: 25 }
    )

    render json: @articles
  end
end
```

---

## Real-World Use Cases

### Content Management System

**Cosa fa**: Archive outdated or inappropriate content

**Quando usarlo**: Blogs, news sites, documentation

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: 'User'

  archivable
  predicates :title, :status, :archived_at

  def self.archive_outdated(older_than: 2.years)
    where('published_at < ?', older_than.ago)
      .where(archived_at: nil)
      .find_each do |article|
        article.archive!(reason: "Outdated content (> #{older_than.inspect})")
      end
  end
end

# Admin controller
class Admin::ArticlesController < Admin::BaseController
  def archive
    @article = Article.find(params[:id])
    @article.archive!(
      by: current_user,
      reason: params[:reason] || "Archived by administrator"
    )

    redirect_to admin_articles_path, notice: "Article archived"
  end

  def restore
    @article = Article.archived_only.find(params[:id])
    @article.restore!

    redirect_to admin_article_path(@article), notice: "Article restored"
  end

  def archived_index
    @articles = Article.archived
                       .order(archived_at: :desc)
                       .page(params[:page])
  end
end
```

---

### User Account Management

**Cosa fa**: Soft delete user accounts with compliance tracking

**Quando usarlo**: User management, GDPR compliance

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true  # Hide archived users
  end

  predicates :email, :status, :archived_at

  def self.archive_inactive(days: 365)
    where('last_sign_in_at < ?', days.days.ago)
      .not_archived
      .find_each do |user|
        user.archive!(reason: "Inactive for #{days} days")
      end
  end
end

# Controller
class UsersController < ApplicationController
  def destroy
    @user = User.find(params[:id])

    # Soft delete instead of hard delete
    @user.archive!(
      by: current_user,
      reason: "Account deleted by user request"
    )

    sign_out(@user) if @user == current_user

    redirect_to root_path, notice: "Account has been deactivated"
  end

  def reactivate
    @user = User.archived_only.find(params[:id])

    if @user.restore!
      UserMailer.account_reactivated(@user).deliver_later
      redirect_to @user, notice: "Account reactivated"
    else
      redirect_to @user, alert: "Could not reactivate account"
    end
  end
end
```

---

### Product Catalog

**Cosa fa**: Archive discontinued products

**Quando usarlo**: E-commerce, inventory management

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel
  has_many :orders

  archivable
  predicates :name, :sku, :category, :archived_at
  sort :name, :created_at

  def self.archive_discontinued
    where(status: 'discontinued')
      .where(archived_at: nil)
      .find_each do |product|
        product.archive!(reason: "Product discontinued")
      end
  end

  def can_archive?
    orders.where('created_at > ?', 30.days.ago).empty?
  end
end

# Admin controller
class Admin::ProductsController < Admin::BaseController
  def archive
    @product = Product.find(params[:id])

    unless @product.can_archive?
      redirect_to admin_product_path(@product),
                  alert: "Cannot archive: recent orders exist"
      return
    end

    @product.archive!(
      by: current_user,
      reason: params[:reason] || "Discontinued"
    )

    redirect_to admin_products_path, notice: "Product archived"
  end

  def restore
    @product = Product.archived_only.find(params[:id])
    @product.restore!
    @product.update!(status: 'active')

    redirect_to admin_product_path(@product), notice: "Product restored"
  end
end
```

---

### Task Management

**Cosa fa**: Archive completed or cancelled tasks

**Quando usarlo**: Project management, issue tracking

**Esempio**:
```ruby
class Task < ApplicationRecord
  include BetterModel
  belongs_to :project
  belongs_to :assignee, class_name: 'User'

  archivable
  predicates :title, :status, :priority, :archived_at
  sort :priority, :due_date

  def self.archive_completed(older_than: 90.days)
    where(status: 'completed')
      .where('updated_at < ?', older_than.ago)
      .not_archived
      .find_each do |task|
        task.archive!(reason: "Completed > #{older_than.inspect} ago")
      end
  end
end

# Controller
class TasksController < ApplicationController
  def complete
    @task = Task.find(params[:id])
    @task.update!(status: 'completed', completed_at: Time.current)

    # Auto-archive after completion
    @task.archive!(
      by: current_user,
      reason: "Task completed"
    )

    redirect_to project_tasks_path(@task.project),
                notice: "Task completed and archived"
  end

  def archived
    @tasks = Task.archived
                 .where(project_id: params[:project_id])
                 .order(archived_at: :desc)
                 .page(params[:page])
  end
end
```

---

### Audit Trail Example

**Cosa fa**: Complete audit trail for archived records

**Quando usarlo**: Compliance, legal requirements

**Esempio**:
```ruby
class Document < ApplicationRecord
  include BetterModel
  belongs_to :archived_by, class_name: 'User', optional: true

  archivable
  predicates :title, :status, :archived_at

  # Custom audit methods
  def archive_history
    {
      archived: archived?,
      archived_at: archived_at,
      archived_by: archived_by&.name,
      archived_by_id: archived_by_id,
      reason: archive_reason,
      days_since_archive: archived? ? (Time.current - archived_at) / 1.day : nil
    }
  end

  def self.archive_report(start_date, end_date)
    archived
      .where(archived_at: start_date..end_date)
      .includes(:archived_by)
      .map(&:archive_history)
  end
end

# Admin dashboard
class Admin::DashboardController < Admin::BaseController
  def archive_stats
    @stats = {
      total_archived: Document.archived.count,
      archived_today: Document.archived_at_gteq(Date.today.beginning_of_day).count,
      archived_this_week: Document.archived_at_gteq(Date.today.beginning_of_week).count,
      archived_this_month: Document.archived_at_gteq(Date.today.beginning_of_month).count,
      by_reason: Document.archived.group(:archive_reason).count,
      top_archivers: Document.archived.group(:archived_by_id).count.sort_by { |_, count| -count }.first(10)
    }
  end
end
```

---

## Error Handling

### NotEnabledError

**Cosa fa**: Raised when archivable not enabled

**Quando usarlo**: Catches configuration mistakes

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  # No archivable!
end

article = Article.find(1)
article.archive!
# Raises: BetterModel::Errors::Archivable::NotEnabledError
# Message: "Archivable is not enabled for Article. Add 'archivable' to enable."

rescue BetterModel::Errors::Archivable::NotEnabledError => e
  Rails.logger.error "Configuration error: #{e.message}"
end
```

---

### AlreadyArchivedError

**Cosa fa**: Raised when trying to archive an archived record

**Quando usarlo**: Prevents double-archiving

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

article = Article.find(1)
article.archive!  # First time: OK

article.archive!  # Second time: ERROR
# Raises: BetterModel::Errors::Archivable::AlreadyArchivedError
# Message: "Record is already archived (archived at: 2025-11-11 10:30:00)"

# Check before archiving
unless article.archived?
  article.archive!(by: current_user)
end
```

---

### NotArchivedError

**Cosa fa**: Raised when trying to restore an active record

**Quando usarlo**: Prevents restoring non-archived records

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable
end

article = Article.find(1)
article.restore!  # Not archived: ERROR
# Raises: BetterModel::Errors::Archivable::NotArchivedError
# Message: "Record is not archived"

# Check before restoring
if article.archived?
  article.restore!
end
```

---

## Best Practices

### Always Use Soft Delete for User Data

**Cosa fa**: Prefer archivable over hard delete

**Quando usarlo**: For data retention and compliance

**Esempio**:
```ruby
# Good - soft delete
class User < ApplicationRecord
  include BetterModel
  archivable
end

user.archive!(by: current_admin, reason: "User requested deletion")

# Bad - hard delete (cannot recover)
user.destroy  # Gone forever!
```

---

### Track Who and Why

**Cosa fa**: Always include audit trail

**Quando usarlo**: For compliance and debugging

**Esempio**:
```ruby
# Good - full audit trail
article.archive!(
  by: current_user,
  reason: "Policy violation"
)

# OK but less informative
article.archive!(by: current_user)

# Missing audit information
article.archive!
```

---

### Use skip_archived_by_default Carefully

**Cosa fa**: Hides archived records by default

**Quando usarlo**: Only when most queries need active records

**Esempio**:
```ruby
# Good use case - user accounts
class User < ApplicationRecord
  include BetterModel
  archivable do
    skip_archived_by_default true  # Most queries need active users
  end
end

# Bad use case - frequent archive queries
class Article < ApplicationRecord
  include BetterModel
  archivable do
    skip_archived_by_default true  # If you often query archives, don't use this
  end
end
```

---

### Provide User-Friendly Archive Reasons

**Cosa fa**: Clear, actionable archive reasons

**Quando usarlo**: Always when recording reason

**Esempio**:
```ruby
# Good - specific and clear
article.archive!(reason: "Content violates community guidelines - section 3.2")
article.archive!(reason: "Outdated - last updated > 2 years ago")
article.archive!(reason: "Duplicate of article #123")

# Bad - vague
article.archive!(reason: "Bad")
article.archive!(reason: "Removed")
```

---

### Batch Archive Operations

**Cosa fa**: Archives multiple records efficiently

**Quando usarlo**: For cleanup tasks

**Esempio**:
```ruby
# Good - batch with find_each
Article.where('published_at < ?', 2.years.ago)
       .not_archived
       .find_each do |article|
         article.archive!(reason: "Outdated content (> 2 years)")
       end

# Bad - loads all at once
Article.where('published_at < ?', 2.years.ago)
       .each do |article|
         article.archive!
       end
```

---

## Permanent Deletion After Archive Period

> **Note**: This section shows **custom extension patterns** - methods you implement yourself
> using BetterModel's Archivable foundation. These are NOT built-in methods of the gem,
> but recommended patterns for common use cases like data retention and GDPR compliance.

### Destroy Archived Records After Period

**Cosa fa**: Permanently destroys archived records after they've been archived for a certain period

**Quando usarlo**: For GDPR compliance, storage management, data retention policies

**Pattern type**: Custom extension (implement in your model)

**Esempio**:
```ruby
class Comment < ApplicationRecord
  include BetterModel
  belongs_to :post
  belongs_to :user

  archivable

  # Permanently destroy comments archived for more than 30 days
  def self.destroy_old_archived!(days: 30)
    archived
      .where('archived_at < ?', days.days.ago)
      .find_each do |comment|
        comment.destroy!
      end
  end

  # Destroy with count return
  def self.purge_archived_older_than(period)
    destroyed_count = 0

    archived
      .where('archived_at < ?', period.ago)
      .find_each do |comment|
        comment.destroy!
        destroyed_count += 1
      end

    destroyed_count
  end

  # With safety check and logging
  def self.permanently_delete_archived!(days:, dry_run: false)
    scope = archived.where('archived_at < ?', days.days.ago)
    count = scope.count

    Rails.logger.info "[Comment] Found #{count} archived comments older than #{days} days"

    return { found: count, destroyed: 0, dry_run: true } if dry_run

    destroyed = 0
    scope.find_each do |comment|
      Rails.logger.debug "[Comment] Permanently destroying comment ##{comment.id}"
      comment.destroy!
      destroyed += 1
    end

    Rails.logger.info "[Comment] Permanently destroyed #{destroyed} archived comments"
    { found: count, destroyed: destroyed, dry_run: false }
  end
end

# Usage examples
Comment.destroy_old_archived!                    # Default: 30 days
Comment.destroy_old_archived!(days: 90)          # Custom period
Comment.purge_archived_older_than(60.days)       # Returns count
Comment.permanently_delete_archived!(days: 30, dry_run: true)  # Preview only
```

---

### Scheduled Cleanup Job

**Cosa fa**: Background job for regular cleanup of old archived records

**Quando usarlo**: Automated data retention enforcement

**Pattern type**: Custom extension (implement in your application)

**Esempio**:
```ruby
class PurgeArchivedCommentsJob < ApplicationJob
  queue_as :maintenance

  # Run daily via cron/scheduler
  def perform(retention_days: 30)
    result = Comment.permanently_delete_archived!(
      days: retention_days,
      dry_run: false
    )

    Rails.logger.info(
      "[PurgeArchivedCommentsJob] Completed: " \
      "#{result[:destroyed]}/#{result[:found]} comments destroyed"
    )

    # Optional: notify admin if many records deleted
    if result[:destroyed] > 100
      AdminNotifier.large_purge_completed(
        model: 'Comment',
        count: result[:destroyed]
      ).deliver_later
    end
  end
end

# Schedule with whenever gem or Rails scheduler
# config/schedule.rb (whenever gem)
every 1.day, at: '3:00 am' do
  runner "PurgeArchivedCommentsJob.perform_later(retention_days: 30)"
end

# Or in application.rb with solid_queue
# config.solid_queue.schedule = {
#   purge_archived_comments: {
#     class: "PurgeArchivedCommentsJob",
#     every: 1.day,
#     args: [{ retention_days: 30 }]
#   }
# }
```

---

### Multi-Model Archival Cleanup

**Cosa fa**: Unified cleanup for multiple models with different retention periods

**Quando usarlo**: Enterprise data retention policies

**Pattern type**: Custom service class (implement in your application)

**Esempio**:
```ruby
class ArchivalCleanupService
  RETENTION_POLICIES = {
    Comment => 30.days,      # Comments: 30 days
    Notification => 7.days,  # Notifications: 7 days
    AuditLog => 365.days,    # Audit logs: 1 year
    TempFile => 1.day        # Temp files: 1 day
  }.freeze

  def self.run_cleanup!(dry_run: false)
    results = {}

    RETENTION_POLICIES.each do |model_class, retention_period|
      next unless model_class.respond_to?(:archived)

      scope = model_class.archived
                         .where('archived_at < ?', retention_period.ago)

      count = scope.count
      destroyed = 0

      unless dry_run
        scope.find_each do |record|
          record.destroy!
          destroyed += 1
        end
      end

      results[model_class.name] = {
        retention_days: (retention_period / 1.day).to_i,
        found: count,
        destroyed: destroyed
      }
    end

    results
  end
end

# Usage
results = ArchivalCleanupService.run_cleanup!(dry_run: true)
# => {
#   "Comment" => { retention_days: 30, found: 150, destroyed: 0 },
#   "Notification" => { retention_days: 7, found: 2340, destroyed: 0 },
#   "AuditLog" => { retention_days: 365, found: 0, destroyed: 0 },
#   "TempFile" => { retention_days: 1, found: 89, destroyed: 0 }
# }

# Execute for real
ArchivalCleanupService.run_cleanup!(dry_run: false)
```

---

### GDPR-Compliant Permanent Deletion

**Cosa fa**: Destroy with compliance logging and right-to-be-forgotten support

**Quando usarlo**: GDPR Article 17 compliance, legal data deletion requests

**Pattern type**: Custom extension (implement in your model)

**Esempio**:
```ruby
class Comment < ApplicationRecord
  include BetterModel
  archivable

  # GDPR-compliant permanent deletion with audit trail
  def self.gdpr_purge!(user_id:, requester:, reason:)
    comments = where(user_id: user_id)

    # Log the deletion request
    GdprDeletionLog.create!(
      subject_type: 'Comment',
      subject_user_id: user_id,
      requester_id: requester.id,
      reason: reason,
      record_count: comments.count,
      requested_at: Time.current
    )

    destroyed_ids = []

    comments.find_each do |comment|
      destroyed_ids << comment.id

      # Create minimal audit record (no PII)
      DataDeletionAudit.create!(
        model_class: 'Comment',
        record_id: comment.id,
        deleted_at: Time.current,
        deletion_type: 'gdpr_request',
        requester_id: requester.id
      )

      comment.destroy!
    end

    {
      user_id: user_id,
      comments_destroyed: destroyed_ids.count,
      destroyed_ids: destroyed_ids,
      completed_at: Time.current
    }
  end
end

# Usage for GDPR right-to-be-forgotten request
result = Comment.gdpr_purge!(
  user_id: user.id,
  requester: admin_user,
  reason: "GDPR Article 17 - Right to erasure request"
)
```

---

## Summary

**Core Features (Built-in)**:
- **Soft Delete Pattern**: Archive instead of destroy
- **Audit Trail**: Track who, when, why
- **Restoration**: Single method to restore
- **Query Scopes**: archived, not_archived, archived_only
- **Predicable Integration**: Time-based archive queries
- **Opt-In**: Explicitly enable per model
- **Default Scope**: Optional hide archived by default

**Built-in Methods**:
- `archive!(by:, reason:)` - Archive record
- `restore!` - Restore archived record
- `archived?` / `active?` - Check status
- `Model.archived` - Archived records scope
- `Model.not_archived` - Active records scope
- `Model.archived_only` - Bypasses default scope
- `Model.archived_today` - Records archived today
- `Model.archived_this_week` - Records archived this week
- `Model.archived_recently(duration)` - Records archived within duration

**Custom Extension Patterns** (shown in "Permanent Deletion" section):
- `destroy_old_archived!` - Implement yourself for data retention
- `purge_archived_older_than` - Implement yourself for cleanup jobs
- `gdpr_purge!` - Implement yourself for GDPR compliance

**Database Columns**:
- `archived_at` (datetime) - Required
- `archived_by_id` (integer) - Optional
- `archive_reason` (string) - Optional

**Configuration**:
- `skip_archived_by_default` - Hide archived by default

**Thread-safe**, **opt-in**, **integrated with Searchable/Predicable**.
