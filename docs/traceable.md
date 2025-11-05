# 📋 Traceable

Traceable provides automatic change tracking with full audit trail for Rails models. It records every change to your records, including who made the change, when, and why. With time-travel capabilities and rollback support, Traceable gives you complete visibility into your data's history.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
  - [Quick Start with Generator](#quick-start-with-generator)
  - [Manual Setup](#manual-setup)
  - [Table Naming Strategies](#table-naming-strategies)
- [Configuration](#configuration)
  - [Basic Configuration](#basic-configuration)
  - [Sensitive Fields](#sensitive-fields)
  - [Custom Table Names](#custom-table-names)
- [Basic Usage](#basic-usage)
  - [Automatic Tracking](#automatic-tracking)
  - [Querying Versions](#querying-versions)
  - [Audit Trail](#audit-trail)
- [Time Travel](#time-travel)
- [Rollback](#rollback)
- [Query Scopes](#query-scopes)
  - [Changed By User](#changed-by-user)
  - [Changed Between Dates](#changed-between-dates)
  - [Field-Specific Changes](#field-specific-changes)
- [Instance Methods](#instance-methods)
- [Table Naming Options](#table-naming-options)
  - [Per-Model Tables](#per-model-tables)
  - [Shared Versions Table](#shared-versions-table)
  - [Custom Table Names](#custom-table-names-1)
- [Database Schema](#database-schema)
- [Integration with Other Concerns](#integration-with-other-concerns)
- [Real-world Examples](#real-world-examples)
- [Performance Considerations](#performance-considerations)
- [Best Practices](#best-practices)

## Overview

**Key Features:**

- **🎯 Opt-in Activation**: Traceable is not active by default. You must explicitly enable it with `traceable do...end`.
- **📝 Automatic Tracking**: Records changes on create, update, and destroy operations.
- **🔐 Sensitive Data Protection**: Three-level redaction system (full, partial, hash) for passwords, PII, and tokens.
- **👤 User Attribution**: Track who made each change (requires `updated_by_id` attribute).
- **💬 Change Reasons**: Optional reason field for change context.
- **⏰ Time Travel**: Reconstruct object state at any point in history.
- **↩️ Rollback Support**: Restore records to previous versions.
- **🔍 Rich Query API**: Find records by changes, users, time ranges, or field-specific transitions.
- **📊 Flexible Table Naming**: Per-model, shared, or custom table names.
- **🔗 Polymorphic Association**: Efficient storage with polymorphic `item_id`/`item_type`.
- **🛡️ Thread-safe**: Immutable configuration and registry.

## Setup

### Quick Start with Generator

The fastest way to set up Traceable is using the built-in generator:

```bash
# Basic setup - creates article_versions table
rails g better_model:traceable Article
rails db:migrate

# With tracking metadata (recommended)
rails g better_model:traceable Article --with-reason
rails db:migrate

# Custom table name
rails g better_model:traceable Article --table-name audit_trail
rails db:migrate

# Shared versions table for all models
rails g better_model:traceable Article --table-name better_model_versions
rails db:migrate
```

**Generator Options:**

- `--with-reason` - Adds `updated_reason` column for change context
- `--with-by` - Adds `updated_by_id` column for user attribution (included by default)
- `--table-name NAME` - Custom table name (default: `{model}_versions`)
- `--skip-indexes` - Skip index creation (not recommended)

### Manual Setup

Create a migration manually if you need custom schema:

```ruby
# db/migrate/XXXXXX_create_article_versions.rb
class CreateArticleVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :article_versions do |t|
      t.string :item_type, null: false      # Polymorphic type
      t.bigint :item_id, null: false        # Polymorphic ID
      t.string :event                        # created/updated/destroyed
      t.json :object_changes                 # Field changes (PostgreSQL: jsonb)
      t.bigint :updated_by_id               # User who made the change
      t.string :updated_reason              # Why the change was made

      t.timestamps                           # created_at, updated_at
    end

    add_index :article_versions, [:item_type, :item_id]
    add_index :article_versions, :updated_by_id
    add_index :article_versions, :created_at
  end
end
```

**Database Compatibility:**

| Database | JSON Storage | Performance | Notes |
|----------|-------------|-------------|-------|
| PostgreSQL | `jsonb` | ⭐⭐⭐⭐⭐ | Best performance, indexable |
| MySQL 5.7+ | `json` | ⭐⭐⭐⭐ | Good performance |
| SQLite 3.9+ | `text` (JSON) | ⭐⭐⭐ | Limited query support |

### Table Naming Strategies

Choose the right strategy for your needs:

| Strategy | Use Case | Example |
|----------|----------|---------|
| **Per-Model** | Separate audit trails per model | `articles_versions`, `users_versions` |
| **Shared** | Single audit trail table for all models | `better_model_versions` |
| **Custom** | Specific naming for domain context | `article_audit_trail` |

## Configuration

### Basic Configuration

Enable Traceable and specify which fields to track:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable Traceable (opt-in)
  traceable do
    track :status, :title, :content, :published_at
  end
end
```

**Important:**

- Only specified fields are tracked. Untracked fields don't create versions.
- `id`, `created_at`, `updated_at` are automatically excluded.
- Foreign keys and associations can be tracked if explicitly specified.

### Sensitive Fields

Protect sensitive data in version history with three redaction levels:

```ruby
class User < ApplicationRecord
  include BetterModel

  traceable do
    track :email, :name
    track :password_hash, sensitive: :full     # Completely redacted
    track :ssn, sensitive: :partial            # Partially masked
    track :api_token, sensitive: :hash         # SHA256 hash
  end
end
```

#### Redaction Levels

**`:full` - Complete Redaction**

All values are replaced with `"[REDACTED]"`:

```ruby
track :password_hash, sensitive: :full
# Stored as: {"password_hash" => ["[REDACTED]", "[REDACTED]"]}
```

Use for: Passwords, security tokens, encryption keys

**`:partial` - Pattern-based Masking**

Shows partial data based on detected patterns:

```ruby
track :credit_card, sensitive: :partial
# "4532123456789012" → "****9012"

track :email, sensitive: :partial
# "user@example.com" → "u***@example.com"

track :ssn, sensitive: :partial
# "123456789" → "***-**-6789"

track :phone, sensitive: :partial
# "5551234567" → "***-***-4567"

track :unknown_data, sensitive: :partial
# "random_text_123" → "[REDACTED:15chars]"
```

Supported patterns:
- Credit cards (shows last 4 digits)
- Emails (shows first char + domain)
- SSN (shows last 4 digits)
- Phone numbers (shows last 4 digits)
- Unknown patterns (shows character count)

Use for: Credit cards, emails, phone numbers, SSN

**`:hash` - SHA256 Hashing**

Stores cryptographic hash instead of actual value:

```ruby
track :api_token, sensitive: :hash
# Stored as: "sha256:a1b2c3d4..."
```

Benefits:
- Verify if value changed without storing actual value
- Same values produce same hash (deterministic)
- One-way transformation (cannot recover original)

Use for: API tokens, session IDs, verification codes

#### Rollback Behavior with Sensitive Fields

By default, rollback skips sensitive fields to prevent accidental exposure:

```ruby
user = User.create!(email: "user@example.com", password_hash: "secret123")
user.update!(email: "new@example.com", password_hash: "newsecret")

first_version = user.versions.first
user.rollback_to(first_version)

# Result:
user.email         # => "user@example.com" (rolled back)
user.password_hash # => "newsecret" (NOT rolled back - sensitive)
```

To include sensitive fields in rollback (not recommended):

```ruby
user.rollback_to(first_version, allow_sensitive: true)
# WARNING: Will set password_hash to "[REDACTED]" since that's what was stored
```

**Security Note:** Since sensitive fields are redacted in storage, rolling back with `allow_sensitive: true` will set the field to the redacted value (e.g., `"[REDACTED]"`), not the original value.

#### Configuration Introspection

Check which fields have sensitivity configured:

```ruby
User.traceable_sensitive_fields
# => {password_hash: :full, ssn: :partial, api_token: :hash}
```

### Custom Table Names

Override the default table name:

```ruby
class Article < ApplicationRecord
  include BetterModel

  traceable do
    versions_table :article_audit_trail  # Custom name
    track :status, :title
  end
end

class BlogPost < ApplicationRecord
  include BetterModel

  traceable do
    versions_table :better_model_versions  # Shared table
    track :content, :published
  end
end
```

## Basic Usage

### Automatic Tracking

Once enabled, Traceable automatically records changes:

```ruby
article = Article.create!(
  title: "Hello World",
  status: "draft",
  updated_by_id: current_user.id,
  updated_reason: "Initial draft"
)
# Creates version with event: "created"

article.update!(
  status: "published",
  updated_by_id: current_user.id,
  updated_reason: "Ready for publication"
)
# Creates version with event: "updated"

article.destroy
# Creates version with event: "destroyed"
```

**Tracking Metadata:**

Add these attributes to your model for richer audit trails:

- `updated_by_id` (integer) - User who made the change
- `updated_reason` (string) - Why the change was made

These are optional but highly recommended.

### Querying Versions

Access version history:

```ruby
# All versions (newest first)
article.versions
# => [#<ArticleVersion>, #<ArticleVersion>, ...]

# Version count
article.versions.count
# => 5

# Specific version
version = article.versions.first
version.event          # => "updated"
version.created_at     # => 2025-01-15 14:30:00
version.updated_by_id  # => 123
version.updated_reason # => "Fixed typo"

# Changes in this version
version.object_changes
# => {"title" => ["Old Title", "New Title"], "status" => ["draft", "published"]}
```

### Audit Trail

Get a formatted history:

```ruby
article.audit_trail
# => [
#   {
#     event: "updated",
#     changes: {"status" => ["draft", "published"]},
#     at: 2025-01-15 14:30:00,
#     by: 123,
#     reason: "Ready for publication"
#   },
#   {
#     event: "created",
#     changes: {"title" => [nil, "Hello World"], "status" => [nil, "draft"]},
#     at: 2025-01-15 10:00:00,
#     by: 123,
#     reason: "Initial draft"
#   }
# ]
```

Include in JSON responses:

```ruby
article.as_json(include_audit_trail: true)
# => {
#   "id" => 1,
#   "title" => "Hello World",
#   "audit_trail" => [...]
# }
```

## Time Travel

Reconstruct object state at any point in history:

```ruby
# View article as it was 3 days ago
past_article = article.as_of(3.days.ago)
past_article.title        # => "Old Title"
past_article.status       # => "draft"
past_article.readonly?    # => true (can't save)

# View at specific timestamp
past_article = article.as_of(Time.new(2025, 1, 10, 14, 30, 0))

# Compare past and present
puts "Title changed from '#{past_article.title}' to '#{article.title}'"
```

**How it works:**

1. Finds all versions created before the specified timestamp
2. Starts with a blank object
3. Applies changes chronologically to reconstruct state
4. Returns readonly object (can't be saved)

**Limitations:**

- Only tracked fields are reconstructed
- Associations are not loaded (only foreign keys)
- Object is readonly (use `rollback_to` to restore)

## Rollback

Restore record to a previous version:

```ruby
# Find version to restore
version = article.versions.find_by(event: "published")

# Rollback
article.rollback_to(
  version,
  updated_by_id: current_user.id,
  updated_reason: "Reverted accidental change"
)
# Article is saved with previous values, and a new version is created

# Rollback by version ID
article.rollback_to(
  42,  # version ID
  updated_by_id: current_user.id
)
```

**Important:**

- Rollback applies the "before" values from the specified version
- A new version is created to record the rollback
- Validations are skipped (use `validate: true` if needed)
- Callbacks are still triggered

## Query Scopes

### Changed By User

Find all records modified by a specific user:

```ruby
# Articles changed by user 123
Article.changed_by(123)

# With additional filters
Article.changed_by(current_user.id).where(status: "published")

# Count changes
Article.changed_by(current_user.id).count
```

### Changed Between Dates

Find records modified in a time range:

```ruby
# Articles changed this week
Article.changed_between(1.week.ago, Time.current)

# Articles changed in January 2025
Article.changed_between(
  Time.new(2025, 1, 1),
  Time.new(2025, 1, 31).end_of_day
)

# Combine with user filter
Article.changed_by(current_user.id)
       .changed_between(1.month.ago, Time.current)
```

### Field-Specific Changes

Track specific field transitions:

```ruby
# Articles where status changed from draft to published
Article.status_changed_from("draft").to("published")

# Title changes (any value)
Article.title_changed_from(nil).to("Hello World")

# Find any title changes
Article.field_changed(:title)

# Changes for a specific field on an instance
article.changes_for(:status)
# => [
#   {before: "draft", after: "published", at: ..., by: 123, reason: "..."},
#   {before: nil, after: "draft", at: ..., by: 123, reason: "..."}
# ]
```

**Method Generation:**

For each tracked field, Traceable generates a `{field}_changed_from` method:

```ruby
traceable do
  track :status, :title, :priority
end

# Generated methods:
Article.status_changed_from("draft").to("published")
Article.title_changed_from(nil).to("Hello")
Article.priority_changed_from(1).to(5)
```

## Instance Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `versions` | All versions for this record | `ActiveRecord::Relation` |
| `changes_for(field)` | Change history for a specific field | `Array<Hash>` |
| `audit_trail` | Full formatted history | `Array<Hash>` |
| `as_of(timestamp)` | Reconstruct state at timestamp | `Model` (readonly) |
| `rollback_to(version, **opts)` | Restore to previous version | `self` |
| `as_json(include_audit_trail: true)` | JSON with audit trail | `Hash` |

## Table Naming Options

### Per-Model Tables

Default behavior - each model gets its own versions table:

```ruby
class Article < ApplicationRecord
  traceable do
    track :status, :title
  end
end
# Uses table: article_versions

class BlogPost < ApplicationRecord
  traceable do
    track :content
  end
end
# Uses table: blog_post_versions
```

**Pros:**
- Clear separation per model
- Easier to partition/archive
- Independent schema evolution

**Cons:**
- More tables to manage
- Potential duplication

### Shared Versions Table

Use a single table for all models:

```ruby
class Article < ApplicationRecord
  traceable do
    versions_table :better_model_versions
    track :status, :title
  end
end

class BlogPost < ApplicationRecord
  traceable do
    versions_table :better_model_versions
    track :content
  end
end
```

**Pros:**
- Single audit trail across all models
- Centralized change history
- Easier to query cross-model changes

**Cons:**
- Large table over time
- Requires good indexing strategy

### Custom Table Names

Use domain-specific naming:

```ruby
class Article < ApplicationRecord
  traceable do
    versions_table :content_audit_trail
    track :status, :title
  end
end

class Document < ApplicationRecord
  traceable do
    versions_table :document_history
    track :version, :approved
  end
end
```

## Database Schema

### Versions Table Structure

```ruby
create_table :article_versions do |t|
  # Polymorphic association (required)
  t.string :item_type, null: false
  t.bigint :item_id, null: false

  # Event tracking (required)
  t.string :event  # "created", "updated", "destroyed"

  # Change data (required)
  # PostgreSQL: use jsonb for better performance
  t.json :object_changes  # or t.jsonb :object_changes

  # User attribution (optional but recommended)
  t.bigint :updated_by_id

  # Change context (optional but recommended)
  t.string :updated_reason

  # Timestamps (required)
  t.timestamps
end

# Indexes (required for performance)
add_index :article_versions, [:item_type, :item_id]
add_index :article_versions, :updated_by_id
add_index :article_versions, :created_at
```

### Recommended Indexes

```ruby
# Core indexes (required)
add_index :article_versions, [:item_type, :item_id]
add_index :article_versions, :created_at

# User tracking (if using updated_by_id)
add_index :article_versions, :updated_by_id

# PostgreSQL: GIN index for JSONB queries
add_index :article_versions, :object_changes, using: :gin  # PostgreSQL only
```

## Integration with Other Concerns

### With Archivable

Track archival events:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    with_by     # archive_by_id
    with_reason # archive_reason
  end

  traceable do
    track :status, :archived_at, :archive_reason
  end
end

article.archive!(by: current_user.id, reason: "Outdated content")
# Creates version with archived_at change
```

### With Stateable

Track state transitions:

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    initial_state :draft

    state :draft
    state :published

    transition from: :draft, to: :published do
      guard :is_complete?
    end
  end

  traceable do
    track :state, :published_at
  end
end

article.publish!(updated_by_id: current_user.id, updated_reason: "Approved")
# Version records state: "draft" => "published"
```

### With Statusable

Track status changes:

```ruby
class Article < ApplicationRecord
  include BetterModel

  statusable do
    status :published do
      published_at.present? && !archived_at.present?
    end
  end

  traceable do
    track :published_at, :archived_at
  end
end

# Changes to published_at are tracked
# Status changes are derived, not stored
```

## Real-world Examples

### Content Management System

```ruby
class Article < ApplicationRecord
  belongs_to :author, class_name: "User"

  traceable do
    track :title, :content, :status, :published_at, :featured
  end

  # Track who edited
  before_save do
    self.updated_by_id = Current.user&.id
  end
end

# Usage in controller
def update
  if @article.update(article_params.merge(
    updated_by_id: current_user.id,
    updated_reason: params[:change_reason]
  ))
    redirect_to @article, notice: "Article updated"
  end
end

# Audit view
def audit_log
  @changes = @article.audit_trail.group_by { |c| c[:at].to_date }
end
```

### Document Approval Workflow

```ruby
class Document < ApplicationRecord
  traceable do
    track :status, :approved_at, :rejected_at, :approval_notes
  end

  def approve!(by:, notes: nil)
    update!(
      status: "approved",
      approved_at: Time.current,
      updated_by_id: by,
      updated_reason: notes || "Approved"
    )
  end

  def reject!(by:, notes:)
    update!(
      status: "rejected",
      rejected_at: Time.current,
      updated_by_id: by,
      updated_reason: notes
    )
  end

  # View approval history
  def approval_history
    versions.where("object_changes->>'status' IS NOT NULL")
            .order(created_at: :desc)
  end
end
```

### E-commerce Order Tracking

```ruby
class Order < ApplicationRecord
  traceable do
    versions_table :order_audit_trail
    track :status, :shipping_address, :total_amount, :payment_status
  end

  # Track status changes
  def self.shipped_today
    changed_between(Time.current.beginning_of_day, Time.current.end_of_day)
      .where(status: "shipped")
  end

  # Find orders modified by admin
  def self.admin_modifications
    joins(:versions)
      .joins("INNER JOIN users ON users.id = order_audit_trail.updated_by_id")
      .where(users: { role: "admin" })
      .distinct
  end
end
```

### Compliance & Regulatory

```ruby
class MedicalRecord < ApplicationRecord
  traceable do
    versions_table :medical_audit_trail
    track :diagnosis, :treatment_plan, :medications, :notes
  end

  # Required: who and why for compliance
  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update

  # Export for compliance
  def compliance_report
    {
      record_id: id,
      patient_id: patient_id,
      changes: versions.map do |v|
        {
          timestamp: v.created_at.iso8601,
          user_id: v.updated_by_id,
          reason: v.updated_reason,
          changes: v.object_changes
        }
      end
    }
  end
end
```

## Performance Considerations

### Indexing Strategy

```ruby
# Essential indexes
add_index :versions, [:item_type, :item_id]  # Fast lookups
add_index :versions, :created_at             # Time-based queries
add_index :versions, :updated_by_id          # User queries

# PostgreSQL: JSONB indexes
add_index :versions, :object_changes, using: :gin

# Composite indexes for common queries
add_index :versions, [:item_type, :item_id, :created_at]
add_index :versions, [:updated_by_id, :created_at]
```

### Query Optimization

```ruby
# Eager load versions
@articles = Article.includes(:versions).limit(10)

# Limit version queries
article.versions.limit(10).order(created_at: :desc)

# Use select to load only needed fields
article.versions.select(:id, :event, :created_at, :updated_by_id)
```

### Data Volume Management

```ruby
# Archive old versions
class ArchiveOldVersions
  def call
    cutoff = 2.years.ago

    ArticleVersion.where("created_at < ?", cutoff)
                  .find_in_batches(batch_size: 1000) do |batch|
      # Move to archive table or S3
      archive_versions(batch)
      batch.each(&:destroy)
    end
  end
end

# Periodic cleanup job
class CleanupOldVersions < ApplicationJob
  def perform
    Version.where("created_at < ?", 1.year.ago)
           .where(event: "updated")
           .where("object_changes = '{}'::jsonb")  # Empty changes
           .delete_all
  end
end
```

### Database-Specific Tips

**PostgreSQL:**
- Use `jsonb` instead of `json` for better query performance
- Add GIN indexes for JSONB queries
- Use partitioning for very large tables

**MySQL:**
- Use `json` column type (5.7+)
- Consider separate archive table strategy
- Use appropriate `max_allowed_packet` for large changes

**SQLite:**
- Stores JSON as text
- Limited query capabilities on JSON fields
- Consider periodic archival

## Best Practices

### ✅ Do

- **Track meaningful fields only** - Don't track everything, focus on business-critical data
- **Always include user attribution** - Add `updated_by_id` for accountability
- **Provide change reasons** - Use `updated_reason` for context
- **Index properly** - Essential for query performance
- **Plan for data volume** - Archive old versions periodically
- **Test time-travel queries** - Ensure reconstructed state is accurate
- **Use transactions** - Especially when rolling back
- **Document tracked fields** - Make it clear what's audited

### ❌ Don't

- **Track sensitive data without protection** - Use `sensitive:` option for passwords, tokens, PII
- **Track computed fields** - Only track source data, not derived values
- **Version large binary data** - Store files elsewhere, track references only
- **Ignore performance** - Monitor version table growth
- **Skip indexes** - Will cause slow queries on large tables
- **Forget foreign keys** - Version records should have referential integrity
- **Mix concerns** - Use appropriate table strategy (shared vs per-model)

### Sensitive Data Protection

```ruby
# Example: Healthcare application
class PatientRecord < ApplicationRecord
  traceable do
    track :diagnosis, :treatment_plan  # Normal tracking
    track :ssn, sensitive: :partial    # Shows last 4 digits
    track :insurance_id, sensitive: :hash  # Hashed for verification
    track :notes  # No sensitivity (already encrypted at rest)
  end
end

# Example: E-commerce application
class Order < ApplicationRecord
  traceable do
    track :status, :total_amount  # Normal tracking
    track :credit_card, sensitive: :partial  # Shows last 4 digits
    track :billing_address, sensitive: :hash  # Can verify changes
  end
end

# Example: Authentication system
class User < ApplicationRecord
  traceable do
    track :email, :name, :role  # Normal tracking
    track :password_digest, sensitive: :full  # Completely redacted
    track :api_token, sensitive: :hash  # Hash for token rotation tracking
    track :two_factor_secret, sensitive: :full  # Completely redacted
  end
end
```

**Choosing the Right Sensitivity Level:**

| Data Type | Recommended Level | Reason |
|-----------|------------------|---------|
| Passwords, encryption keys | `:full` | No value in storing any form |
| Credit cards, SSN | `:partial` | Pattern helps identify which card/ID |
| API tokens, session IDs | `:hash` | Track rotation without exposing value |
| Email addresses | None or `:partial` | Depends on privacy requirements |
| Phone numbers | `:partial` | Last 4 digits help identify |

### Version Retention Policies

```ruby
# Keep last N versions per record
class PruneOldVersions
  MAX_VERSIONS_PER_RECORD = 100

  def call(model_class)
    model_class.find_each do |record|
      versions = record.versions.order(created_at: :desc).offset(MAX_VERSIONS_PER_RECORD)
      versions.destroy_all
    end
  end
end

# Time-based retention
class TimeBasedRetention
  RETENTION_PERIOD = 2.years

  def call
    cutoff = RETENTION_PERIOD.ago
    Version.where("created_at < ?", cutoff).delete_all
  end
end
```

### Handling Large Changes

```ruby
# For models with large text fields
class Article < ApplicationRecord
  traceable do
    track :title, :summary  # Track only metadata
    # Don't track :content (large text)
  end

  # Track content separately if needed
  has_many :content_versions, dependent: :destroy

  after_update :create_content_version, if: :content_changed?

  private

  def create_content_version
    content_versions.create!(
      body: content,
      updated_by_id: updated_by_id
    )
  end
end
```

---

**Related Documentation:**
- [Archivable](archivable.md) - Soft delete with tracking
- [Stateable](stateable.md) - State machines with history
- [Statusable](statusable.md) - Declarative status management
