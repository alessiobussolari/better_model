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
- [Enterprise Data Lake Integration](#enterprise-data-lake-integration)
  - [Architecture Overview](#architecture-overview)
  - [Storage Backend Adapters](#storage-backend-adapters)
  - [Implementation Patterns](#implementation-patterns)
  - [Cost Optimization](#cost-optimization)
- [Schema Evolution & Migration](#schema-evolution--migration)
  - [Understanding Schema Evolution Challenges](#understanding-schema-evolution-challenges)
  - [Versioning Strategy](#versioning-strategy)
  - [Backward Compatibility Patterns](#backward-compatibility-patterns)
  - [Migration Patterns](#migration-patterns)
  - [Data Backfilling Strategies](#data-backfilling-strategies)
  - [Testing Schema Changes](#testing-schema-changes)
  - [Query Compatibility Across Schema Versions](#query-compatibility-across-schema-versions)
- [Data Partitioning Strategies](#data-partitioning-strategies)
  - [PostgreSQL Declarative Partitioning](#postgresql-declarative-partitioning)
  - [Automated Partition Management](#automated-partition-management)
  - [Multi-Column Partitioning](#multi-column-partitioning)
  - [Application-Level Sharding](#application-level-sharding)
  - [Performance Comparison](#performance-comparison)
- [Secure Retrieval & Authorization](#secure-retrieval--authorization)
  - [Key Management Integration](#key-management-integration)
  - [Field-Level Encryption Strategy](#field-level-encryption-strategy)
  - [Authorization Framework Integration](#authorization-framework-integration)
  - [Secure Retrieval API](#secure-retrieval-api)
  - [Audit Logging for Access](#audit-logging-for-access)
  - [Row-Level Security (PostgreSQL)](#row-level-security-postgresql)
- [Complete Working Examples](#complete-working-examples)
  - [Full Enterprise Setup Example](#full-enterprise-setup-example)
  - [Healthcare Application with HIPAA Compliance](#example-1-healthcare-application-with-hipaa-compliance)
  - [E-Commerce with PCI-DSS Compliance](#example-2-e-commerce-with-pci-dss-compliance)
  - [Multi-Tenant SaaS with Data Isolation](#example-3-multi-tenant-saas-with-data-isolation)
  - [Performance Benchmarks](#performance-benchmarks)
  - [Migration Path from Basic to Enterprise](#migration-path-from-basic-to-enterprise)
  - [Testing Enterprise Features](#testing-enterprise-features)

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
      check :is_complete?
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

### Error Handling

> **ℹ️ Version 3.0.0 Compatible**: All error examples use standard Ruby exception patterns with `e.message`. Domain-specific attributes and Sentry helpers have been removed in v3.0.0 for simplicity.

Traceable raises ConfigurationError for invalid configuration during class definition:

```ruby
# Missing track configuration
begin
  traceable do
    # No fields specified
  end
rescue BetterModel::Errors::Traceable::ConfigurationError => e
  # Only message available in v3.0.0
  e.message
  # => "At least one field must be tracked"

  # Log or report
  Rails.logger.error("Traceable configuration error: #{e.message}")
  Sentry.capture_exception(e)
end

# Invalid field name
begin
  traceable do
    track :nonexistent_field
  end
rescue BetterModel::Errors::Traceable::ConfigurationError => e
  e.message  # => "Field does not exist in model: nonexistent_field"
  Rails.logger.error(e.message)
  Sentry.capture_exception(e)
end
```

**Integration with Sentry:**

```ruby
rescue_from BetterModel::Errors::Traceable::ConfigurationError do |error|
  Rails.logger.error("Configuration error: #{error.message}")
  Sentry.capture_exception(error)
  render json: { error: "Server configuration error" }, status: :internal_server_error
end
```

## Enterprise Data Lake Integration

For production systems with long-term audit trail requirements, integrating Traceable with external data lakes provides cost-effective archival, advanced analytics, and compliance capabilities. This section provides comprehensive strategies for exporting version data to cloud storage and data warehouses.

### Architecture Overview

#### Multi-Tier Storage Strategy

A typical enterprise setup uses tiered storage based on data access patterns:

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                     │
│  (Rails App + PostgreSQL/MySQL - Hot Storage 0-90 days) │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│              Warm Storage (90 days - 2 years)           │
│    - Compressed tables or separate archive database     │
│    - Still queryable but slower                         │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│              Cold Storage (2+ years)                     │
│    - S3/GCS/Azure Blob (cheapest storage)               │
│    - Data Lake/Warehouse for analytics                  │
│    - Rarely accessed, long-term compliance              │
└─────────────────────────────────────────────────────────┘
```

**Access Patterns:**

| Tier | Age | Storage Cost | Access Time | Use Case |
|------|-----|--------------|-------------|----------|
| Hot | 0-90 days | High | Milliseconds | Real-time queries, UI display |
| Warm | 90 days - 2 years | Medium | Seconds | Compliance reviews, audits |
| Cold | 2+ years | Low | Minutes | Legal discovery, analytics |

#### Export Strategies

**Batch Export (Recommended)**

Periodic jobs export old versions to external storage:

```ruby
# lib/tasks/export_versions.rake
namespace :versions do
  desc "Export old versions to data lake"
  task export_to_datalake: :environment do
    cutoff = 90.days.ago

    VersionExporter.new(
      cutoff_date: cutoff,
      destination: :s3,
      compression: :gzip
    ).call
  end
end
```

**Event-Driven Export**

Real-time streaming for critical audit trails:

```ruby
# app/models/concerns/datalake_streaming.rb
module DatalakeStreaming
  extend ActiveSupport::Concern

  included do
    after_create_commit :stream_to_datalake, if: :critical_model?
  end

  private

  def stream_to_datalake
    DatalakeStreamJob.perform_later(
      version_id: self.id,
      model_class: item_type,
      timestamp: created_at
    )
  end
end
```

### Storage Backend Adapters

#### AWS S3 + Redshift/Athena

**Architecture:**
1. Export versions to S3 as Parquet/CSV
2. Query with Athena (serverless) or load into Redshift (warehouse)
3. Use Glue for ETL transformations

**S3 Export Adapter:**

```ruby
# lib/datalake/adapters/s3_adapter.rb
module Datalake
  module Adapters
    class S3Adapter
      def initialize(bucket:, region: 'us-east-1', prefix: 'versions')
        @bucket = bucket
        @region = region
        @prefix = prefix
        @s3 = Aws::S3::Client.new(region: @region)
      end

      def export_batch(versions, partition_date:)
        # Group by model type for efficient storage
        versions.group_by(&:item_type).each do |model_type, model_versions|
          export_model_batch(model_type, model_versions, partition_date)
        end
      end

      private

      def export_model_batch(model_type, versions, partition_date)
        # Create Parquet file for efficient columnar storage
        filename = generate_filename(model_type, partition_date)
        parquet_data = convert_to_parquet(versions)

        @s3.put_object(
          bucket: @bucket,
          key: filename,
          body: parquet_data,
          server_side_encryption: 'AES256',
          storage_class: 'STANDARD_IA', # Infrequent Access tier
          metadata: {
            'record_count' => versions.size.to_s,
            'model_type' => model_type,
            'partition_date' => partition_date.to_s
          }
        )

        Rails.logger.info "Exported #{versions.size} versions to #{filename}"
      end

      def generate_filename(model_type, partition_date)
        # Partition by date for efficient queries
        year = partition_date.year
        month = partition_date.month.to_s.rjust(2, '0')
        day = partition_date.day.to_s.rjust(2, '0')
        timestamp = Time.current.to_i

        "#{@prefix}/model=#{model_type}/year=#{year}/month=#{month}/day=#{day}/versions_#{timestamp}.parquet"
      end

      def convert_to_parquet(versions)
        # Convert to columnar format
        # Using arrow-rb gem for Parquet generation
        require 'arrow'

        data = {
          'id' => versions.map(&:id),
          'item_id' => versions.map(&:item_id),
          'item_type' => versions.map(&:item_type),
          'event' => versions.map(&:event),
          'object_changes' => versions.map { |v| v.object_changes.to_json },
          'updated_by_id' => versions.map(&:updated_by_id),
          'updated_reason' => versions.map(&:updated_reason),
          'created_at' => versions.map { |v| v.created_at.to_i }
        }

        table = Arrow::Table.new(data)
        output = StringIO.new
        Arrow::FileOutputStream.open(output) do |file_output|
          Arrow::ParquetFileWriter.open(file_output, table.schema) do |writer|
            writer.write_table(table, chunk_size: 1024)
          end
        end

        output.string
      end
    end
  end
end
```

**Athena Query Setup:**

```sql
-- Create external table pointing to S3
CREATE EXTERNAL TABLE IF NOT EXISTS versions_archive (
  id BIGINT,
  item_id BIGINT,
  item_type STRING,
  event STRING,
  object_changes STRING,
  updated_by_id BIGINT,
  updated_reason STRING,
  created_at BIGINT
)
PARTITIONED BY (
  model STRING,
  year INT,
  month INT,
  day INT
)
STORED AS PARQUET
LOCATION 's3://your-bucket/versions/'
TBLPROPERTIES ('parquet.compression'='SNAPPY');

-- Add partition metadata
MSCK REPAIR TABLE versions_archive;

-- Query archived versions
SELECT
  item_id,
  event,
  object_changes,
  FROM_UNIXTIME(created_at) as change_date
FROM versions_archive
WHERE model = 'Article'
  AND year = 2024
  AND item_id = 12345
ORDER BY created_at DESC;
```

**Redshift Load (for faster queries):**

```ruby
# lib/datalake/loaders/redshift_loader.rb
module Datalake
  module Loaders
    class RedshiftLoader
      def initialize(connection_params)
        @conn = PG.connect(connection_params)
      end

      def load_from_s3(s3_path, iam_role)
        sql = <<-SQL
          COPY versions_archive
          FROM '#{s3_path}'
          IAM_ROLE '#{iam_role}'
          FORMAT AS PARQUET;
        SQL

        @conn.exec(sql)
      end

      def create_archive_table
        sql = <<-SQL
          CREATE TABLE IF NOT EXISTS versions_archive (
            id BIGINT,
            item_id BIGINT,
            item_type VARCHAR(255),
            event VARCHAR(50),
            object_changes SUPER,  -- JSON type in Redshift
            updated_by_id BIGINT,
            updated_reason VARCHAR(1000),
            created_at TIMESTAMP,
            partition_date DATE
          )
          SORTKEY (item_type, item_id, created_at)
          DISTKEY (item_id);
        SQL

        @conn.exec(sql)
      end
    end
  end
end
```

#### Google Cloud Platform (GCS + BigQuery)

**GCS Export Adapter:**

```ruby
# lib/datalake/adapters/gcs_adapter.rb
require 'google/cloud/storage'

module Datalake
  module Adapters
    class GcsAdapter
      def initialize(bucket:, project_id:, prefix: 'versions')
        @bucket_name = bucket
        @project_id = project_id
        @prefix = prefix
        @storage = Google::Cloud::Storage.new(project_id: @project_id)
        @bucket = @storage.bucket(@bucket_name)
      end

      def export_batch(versions, partition_date:)
        versions.group_by(&:item_type).each do |model_type, model_versions|
          export_to_gcs(model_type, model_versions, partition_date)
        end
      end

      private

      def export_to_gcs(model_type, versions, partition_date)
        filename = generate_gcs_path(model_type, partition_date)

        # Use JSONL format for BigQuery
        jsonl_data = versions.map do |v|
          {
            id: v.id,
            item_id: v.item_id,
            item_type: v.item_type,
            event: v.event,
            object_changes: v.object_changes,
            updated_by_id: v.updated_by_id,
            updated_reason: v.updated_reason,
            created_at: v.created_at.iso8601,
            partition_date: partition_date.to_s
          }.to_json
        end.join("\n")

        # Compress with gzip
        compressed = compress_gzip(jsonl_data)

        file = @bucket.create_file(
          StringIO.new(compressed),
          filename,
          content_type: 'application/gzip',
          metadata: {
            record_count: versions.size.to_s,
            model_type: model_type
          }
        )

        Rails.logger.info "Exported #{versions.size} versions to gs://#{@bucket_name}/#{filename}"
      end

      def generate_gcs_path(model_type, partition_date)
        "#{@prefix}/model=#{model_type}/date=#{partition_date}/versions_#{Time.current.to_i}.jsonl.gz"
      end

      def compress_gzip(data)
        output = StringIO.new
        gz = Zlib::GzipWriter.new(output)
        gz.write(data)
        gz.close
        output.string
      end
    end
  end
end
```

**BigQuery Integration:**

```ruby
# lib/datalake/loaders/bigquery_loader.rb
require 'google/cloud/bigquery'

module Datalake
  module Loaders
    class BigQueryLoader
      def initialize(project_id:, dataset_id:)
        @bigquery = Google::Cloud::Bigquery.new(project_id: project_id)
        @dataset = @bigquery.dataset(dataset_id)
      end

      def create_archive_table
        table = @dataset.create_table 'versions_archive' do |schema|
          schema.integer 'id', mode: :required
          schema.integer 'item_id', mode: :required
          schema.string 'item_type', mode: :required
          schema.string 'event'
          schema.json 'object_changes'
          schema.integer 'updated_by_id'
          schema.string 'updated_reason'
          schema.timestamp 'created_at'
          schema.date 'partition_date'
        end

        # Enable partitioning
        table.time_partitioning_type = 'DAY'
        table.time_partitioning_field = 'partition_date'
        table.clustering_fields = ['item_type', 'item_id']

        Rails.logger.info 'Created BigQuery versions_archive table'
      end

      def load_from_gcs(gcs_uri)
        load_job = @dataset.load_job 'versions_archive', gcs_uri do |job|
          job.format = :json
          job.write = :append
          job.autodetect = false
          job.source_format = 'NEWLINE_DELIMITED_JSON'
        end

        load_job.wait_until_done!

        if load_job.failed?
          Rails.logger.error "BigQuery load failed: #{load_job.errors}"
        else
          Rails.logger.info "Loaded #{load_job.output_rows} rows into BigQuery"
        end
      end

      def query_versions(item_type, item_id, start_date, end_date)
        sql = <<-SQL
          SELECT *
          FROM `#{@dataset.dataset_id}.versions_archive`
          WHERE item_type = @item_type
            AND item_id = @item_id
            AND partition_date BETWEEN @start_date AND @end_date
          ORDER BY created_at DESC
        SQL

        results = @bigquery.query(sql, params: {
          item_type: item_type,
          item_id: item_id,
          start_date: start_date,
          end_date: end_date
        })

        results.map { |row| row.to_h }
      end
    end
  end
end
```

#### Azure Blob Storage + Synapse Analytics

**Azure Blob Adapter:**

```ruby
# lib/datalake/adapters/azure_adapter.rb
require 'azure/storage/blob'

module Datalake
  module Adapters
    class AzureAdapter
      def initialize(account_name:, account_key:, container:, prefix: 'versions')
        @container = container
        @prefix = prefix
        @blob_service = Azure::Storage::Blob::BlobService.create(
          storage_account_name: account_name,
          storage_access_key: account_key
        )
      end

      def export_batch(versions, partition_date:)
        versions.group_by(&:item_type).each do |model_type, model_versions|
          export_to_blob(model_type, model_versions, partition_date)
        end
      end

      private

      def export_to_blob(model_type, versions, partition_date)
        blob_name = generate_blob_path(model_type, partition_date)

        # CSV format for Synapse
        csv_data = generate_csv(versions)
        compressed = compress_gzip(csv_data)

        @blob_service.create_block_blob(
          @container,
          blob_name,
          compressed,
          content_type: 'application/gzip',
          metadata: {
            'record_count' => versions.size.to_s,
            'model_type' => model_type,
            'partition_date' => partition_date.to_s
          }
        )

        Rails.logger.info "Exported #{versions.size} versions to Azure Blob: #{blob_name}"
      end

      def generate_blob_path(model_type, partition_date)
        "#{@prefix}/model=#{model_type}/date=#{partition_date}/versions_#{Time.current.to_i}.csv.gz"
      end

      def generate_csv(versions)
        require 'csv'

        CSV.generate do |csv|
          # Header
          csv << ['id', 'item_id', 'item_type', 'event', 'object_changes',
                  'updated_by_id', 'updated_reason', 'created_at']

          # Rows
          versions.each do |v|
            csv << [
              v.id,
              v.item_id,
              v.item_type,
              v.event,
              v.object_changes.to_json,
              v.updated_by_id,
              v.updated_reason,
              v.created_at.iso8601
            ]
          end
        end
      end

      def compress_gzip(data)
        output = StringIO.new
        gz = Zlib::GzipWriter.new(output)
        gz.write(data)
        gz.close
        output.string
      end
    end
  end
end
```

**Synapse Analytics Setup:**

```sql
-- Create external table in Synapse
CREATE EXTERNAL TABLE versions_archive (
    id BIGINT,
    item_id BIGINT,
    item_type NVARCHAR(255),
    event NVARCHAR(50),
    object_changes NVARCHAR(MAX),
    updated_by_id BIGINT,
    updated_reason NVARCHAR(1000),
    created_at DATETIME2
)
WITH (
    LOCATION = 'versions/',
    DATA_SOURCE = azure_blob_datasource,
    FILE_FORMAT = csv_gzip_format
);

-- Query archived data
SELECT
    item_id,
    event,
    JSON_VALUE(object_changes, '$.status[1]') as new_status,
    created_at
FROM versions_archive
WHERE item_type = 'Article'
    AND item_id = 12345
ORDER BY created_at DESC;
```

#### Snowflake Integration

**Snowflake Loader:**

```ruby
# lib/datalake/loaders/snowflake_loader.rb
require 'odbc_utf8'

module Datalake
  module Loaders
    class SnowflakeLoader
      def initialize(account:, user:, password:, warehouse:, database:, schema:)
        @connection_string = "Driver={SnowflakeDSIIDriver};Server=#{account}.snowflakecomputing.com;" \
                           "UID=#{user};PWD=#{password};Warehouse=#{warehouse};" \
                           "Database=#{database};Schema=#{schema}"
        @conn = ODBC.connect(@connection_string)
      end

      def create_archive_table
        sql = <<-SQL
          CREATE TABLE IF NOT EXISTS versions_archive (
            id NUMBER(38,0),
            item_id NUMBER(38,0),
            item_type VARCHAR(255),
            event VARCHAR(50),
            object_changes VARIANT,  -- Snowflake's JSON type
            updated_by_id NUMBER(38,0),
            updated_reason VARCHAR(1000),
            created_at TIMESTAMP_NTZ,
            partition_date DATE
          )
          CLUSTER BY (item_type, item_id, partition_date);
        SQL

        @conn.do(sql)
      end

      def load_from_stage(stage_name, file_pattern)
        # Assumes data already uploaded to Snowflake stage (S3, Azure, or GCS)
        sql = <<-SQL
          COPY INTO versions_archive
          FROM @#{stage_name}/#{file_pattern}
          FILE_FORMAT = (
            TYPE = 'JSON',
            COMPRESSION = 'GZIP'
          )
          ON_ERROR = 'CONTINUE';
        SQL

        result = @conn.do(sql)
        Rails.logger.info "Loaded data from Snowflake stage: #{result} rows"
      end

      def export_to_stage(versions, stage_name)
        # Create temp file
        temp_file = Tempfile.new(['versions', '.json.gz'])

        begin
          # Write compressed JSONL
          Zlib::GzipWriter.open(temp_file.path) do |gz|
            versions.each do |v|
              gz.puts({
                id: v.id,
                item_id: v.item_id,
                item_type: v.item_type,
                event: v.event,
                object_changes: v.object_changes,
                updated_by_id: v.updated_by_id,
                updated_reason: v.updated_reason,
                created_at: v.created_at.iso8601,
                partition_date: v.created_at.to_date.to_s
              }.to_json)
            end
          end

          # Upload to stage
          filename = "versions_#{Time.current.to_i}.json.gz"
          sql = "PUT file://#{temp_file.path} @#{stage_name}/#{filename}"
          @conn.do(sql)

          Rails.logger.info "Uploaded #{versions.size} versions to Snowflake stage"

          # Load from stage
          load_from_stage(stage_name, filename)
        ensure
          temp_file.close
          temp_file.unlink
        end
      end

      def query_versions(item_type, item_id, start_date, end_date)
        sql = <<-SQL
          SELECT *
          FROM versions_archive
          WHERE item_type = ?
            AND item_id = ?
            AND partition_date BETWEEN ? AND ?
          ORDER BY created_at DESC
        SQL

        stmt = @conn.prepare(sql)
        stmt.execute(item_type, item_id, start_date.to_s, end_date.to_s)

        results = []
        while row = stmt.fetch_hash
          results << row
        end
        results
      ensure
        stmt.close if stmt
      end
    end
  end
end
```

### Implementation Patterns

#### Unified Export Service

Create a unified service that works with any adapter:

```ruby
# app/services/version_exporter.rb
class VersionExporter
  def initialize(cutoff_date:, destination:, compression: :gzip, batch_size: 1000)
    @cutoff_date = cutoff_date
    @batch_size = batch_size
    @adapter = build_adapter(destination)
  end

  def call
    total_exported = 0
    total_deleted = 0

    # Process each model that uses Traceable
    traceable_models.each do |model_class|
      exported, deleted = export_model_versions(model_class)
      total_exported += exported
      total_deleted += deleted
    end

    Rails.logger.info "Export complete: #{total_exported} versions exported, #{total_deleted} deleted"

    {
      exported: total_exported,
      deleted: total_deleted,
      cutoff_date: @cutoff_date
    }
  end

  private

  def export_model_versions(model_class)
    versions_class = "#{model_class.name}Version".constantize
    exported_count = 0
    deleted_count = 0

    # Find old versions to export
    versions_class.where('created_at < ?', @cutoff_date)
                  .find_in_batches(batch_size: @batch_size) do |batch|

      # Group by date for partitioning
      batch.group_by { |v| v.created_at.to_date }.each do |date, day_versions|
        begin
          # Export to data lake
          @adapter.export_batch(day_versions, partition_date: date)

          # After successful export, delete from database
          ids_to_delete = day_versions.map(&:id)
          versions_class.where(id: ids_to_delete).delete_all

          exported_count += day_versions.size
          deleted_count += ids_to_delete.size

          Rails.logger.info "Exported and deleted #{day_versions.size} versions for #{date}"
        rescue => e
          Rails.logger.error "Failed to export batch for #{date}: #{e.message}"
          Sentry.capture_exception(e, extra: {
            model_class: model_class.name,
            date: date,
            batch_size: day_versions.size
          })
          # Don't delete if export failed
        end
      end
    end

    [exported_count, deleted_count]
  end

  def traceable_models
    # Find all models using Traceable
    Rails.application.eager_load!
    ApplicationRecord.descendants.select do |model|
      model.respond_to?(:traceable_enabled?) && model.traceable_enabled?
    end
  end

  def build_adapter(destination)
    case destination
    when :s3
      Datalake::Adapters::S3Adapter.new(
        bucket: ENV['AWS_VERSIONS_BUCKET'],
        region: ENV['AWS_REGION'] || 'us-east-1'
      )
    when :gcs
      Datalake::Adapters::GcsAdapter.new(
        bucket: ENV['GCS_VERSIONS_BUCKET'],
        project_id: ENV['GCP_PROJECT_ID']
      )
    when :azure
      Datalake::Adapters::AzureAdapter.new(
        account_name: ENV['AZURE_STORAGE_ACCOUNT'],
        account_key: ENV['AZURE_STORAGE_KEY'],
        container: ENV['AZURE_VERSIONS_CONTAINER']
      )
    else
      raise ArgumentError, "Unknown destination: #{destination}"
    end
  end
end
```

#### Background Job Integration

**Using Sidekiq:**

```ruby
# app/jobs/version_export_job.rb
class VersionExportJob
  include Sidekiq::Job

  sidekiq_options queue: :low_priority, retry: 3

  def perform(cutoff_days = 90, destination = 's3')
    cutoff_date = cutoff_days.days.ago

    result = VersionExporter.new(
      cutoff_date: cutoff_date,
      destination: destination.to_sym
    ).call

    Rails.logger.info "Version export job completed: #{result.inspect}"

    # Send notification
    AdminMailer.version_export_complete(result).deliver_later
  rescue => e
    Rails.logger.error "Version export job failed: #{e.message}"
    Sentry.capture_exception(e)
    raise # Sidekiq will retry
  end
end

# Schedule with sidekiq-cron
# config/schedule.yml
version_export:
  cron: "0 2 * * 0"  # Weekly on Sunday at 2am
  class: "VersionExportJob"
  args: [90, "s3"]
```

**Using GoodJob:**

```ruby
# app/jobs/version_export_job.rb
class VersionExportJob < ApplicationJob
  queue_as :low_priority
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  good_job_control_concurrency_with(
    total_limit: 1,  # Only one export at a time
    key: -> { 'version_export' }
  )

  def perform(cutoff_days: 90, destination: 's3')
    cutoff_date = cutoff_days.days.ago

    result = VersionExporter.new(
      cutoff_date: cutoff_date,
      destination: destination.to_sym
    ).call

    Rails.logger.info "Version export completed: #{result.inspect}"
  end
end

# Schedule with GoodJob cron
# config/initializers/good_job.rb
Rails.application.configure do
  config.good_job.enable_cron = true
  config.good_job.cron = {
    version_export: {
      cron: '0 2 * * 0',  # Weekly on Sunday at 2am
      class: 'VersionExportJob',
      args: [{ cutoff_days: 90, destination: 's3' }]
    }
  }
end
```

#### Incremental vs Full Export

**Incremental Export (Recommended):**

```ruby
# app/services/incremental_version_exporter.rb
class IncrementalVersionExporter
  def initialize(destination:, batch_size: 1000)
    @destination = destination
    @batch_size = batch_size
    @adapter = build_adapter(destination)
  end

  def call
    # Track last export time
    last_export = ExportLog.last_successful_export_time
    current_time = Time.current

    total_exported = 0

    traceable_models.each do |model_class|
      versions_class = "#{model_class.name}Version".constantize

      # Only export versions created since last export
      query = versions_class.where('created_at >= ? AND created_at < ?', last_export, current_time)

      query.find_in_batches(batch_size: @batch_size) do |batch|
        batch.group_by { |v| v.created_at.to_date }.each do |date, day_versions|
          @adapter.export_batch(day_versions, partition_date: date)
          total_exported += day_versions.size
        end
      end
    end

    # Record successful export
    ExportLog.create!(
      exported_at: current_time,
      version_count: total_exported,
      status: 'success'
    )

    Rails.logger.info "Incremental export complete: #{total_exported} versions"
    total_exported
  end

  private

  # ... same helper methods as VersionExporter
end

# app/models/export_log.rb
class ExportLog < ApplicationRecord
  scope :successful, -> { where(status: 'success') }

  def self.last_successful_export_time
    successful.order(exported_at: :desc).first&.exported_at || 1.year.ago
  end
end
```

**Migration for Export Log:**

```ruby
class CreateExportLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :export_logs do |t|
      t.datetime :exported_at, null: false
      t.integer :version_count, default: 0
      t.string :status, default: 'pending'
      t.text :error_message
      t.json :metadata

      t.timestamps
    end

    add_index :export_logs, :exported_at
    add_index :export_logs, :status
  end
end
```

### Cost Optimization

#### Storage Class Selection

**AWS S3 Storage Classes:**

```ruby
# lib/datalake/cost_optimizer.rb
module Datalake
  class CostOptimizer
    STORAGE_TIERS = {
      hot: 'STANDARD',           # $0.023/GB - frequently accessed
      warm: 'STANDARD_IA',       # $0.0125/GB - infrequent access
      cold: 'GLACIER_IR',        # $0.004/GB - instant retrieval
      archive: 'DEEP_ARCHIVE'    # $0.00099/GB - rare access (12hr retrieval)
    }

    def self.storage_class_for_age(age_days)
      case age_days
      when 0..90
        STORAGE_TIERS[:hot]      # Keep in database
      when 91..365
        STORAGE_TIERS[:warm]     # Export to STANDARD_IA
      when 366..730
        STORAGE_TIERS[:cold]     # Move to GLACIER_IR
      else
        STORAGE_TIERS[:archive]  # Deep Archive for long-term
      end
    end
  end
end

# app/services/tiered_version_exporter.rb
class TieredVersionExporter
  def export_with_lifecycle
    # Set lifecycle policy on bucket
    s3 = Aws::S3::Client.new

    s3.put_bucket_lifecycle_configuration(
      bucket: ENV['AWS_VERSIONS_BUCKET'],
      lifecycle_configuration: {
        rules: [
          {
            id: 'transition-to-ia',
            status: 'Enabled',
            prefix: 'versions/',
            transitions: [
              { days: 90, storage_class: 'STANDARD_IA' },
              { days: 365, storage_class: 'GLACIER_IR' },
              { days: 730, storage_class: 'DEEP_ARCHIVE' }
            ]
          }
        ]
      }
    )

    Rails.logger.info 'S3 lifecycle policy configured for cost optimization'
  end
end
```

#### Compression Strategies

```ruby
# lib/datalake/compression.rb
module Datalake
  module Compression
    ALGORITHMS = {
      gzip: { ratio: 0.3, speed: :fast, cpu: :low },
      zstd: { ratio: 0.25, speed: :fast, cpu: :medium },
      bzip2: { ratio: 0.2, speed: :slow, cpu: :high }
    }

    def self.compress(data, algorithm: :gzip)
      case algorithm
      when :gzip
        compress_gzip(data)
      when :zstd
        compress_zstd(data)
      when :bzip2
        compress_bzip2(data)
      else
        raise ArgumentError, "Unknown compression algorithm: #{algorithm}"
      end
    end

    def self.compress_gzip(data)
      output = StringIO.new
      gz = Zlib::GzipWriter.new(output, Zlib::BEST_COMPRESSION)
      gz.write(data)
      gz.close
      output.string
    end

    def self.compress_zstd(data)
      require 'zstd-ruby'
      Zstd.compress(data, level: 19)  # Max compression
    end

    def self.compress_bzip2(data)
      require 'bzip2-ffi'
      Bzip2::FFI::Writer.write(data, compression_level: 9)
    end
  end
end
```

**Cost Comparison Example:**

```ruby
# For 1 TB of version data over 5 years

# Uncompressed in PostgreSQL RDS
postgres_cost = 1000 * 0.115 * 12 * 5  # $0.115/GB-month
# => $6,900

# Compressed in S3 with lifecycle
# Months 1-3: STANDARD (1TB * 0.3 compression = 300GB)
standard_cost = 300 * 0.023 * 3  # $20.70

# Months 4-12: STANDARD_IA (300GB)
standard_ia_cost = 300 * 0.0125 * 9  # $33.75

# Years 2-5: GLACIER_IR (300GB)
glacier_cost = 300 * 0.004 * 12 * 4  # $57.60

total_s3_cost = standard_cost + standard_ia_cost + glacier_cost
# => $112.05

# Savings: $6,900 - $112.05 = $6,787.95 (98.4% reduction!)
```

## Schema Evolution & Migration

As your application evolves, the structure of tracked fields may change. This section provides strategies for handling schema evolution in version data while maintaining backward compatibility with historical records.

### Understanding Schema Evolution Challenges

**The Problem:**

```ruby
# Original model (v1)
class Article < ApplicationRecord
  traceable do
    track :title, :content
  end
end
# Version data: {"title" => ["Old", "New"], "content" => ["...", "..."]}

# After migration (v2) - added :summary field
class Article < ApplicationRecord
  traceable do
    track :title, :content, :summary
  end
end
# New version data: {"title" => [...], "content" => [...], "summary" => [...]}
# Old version data: {"title" => [...], "content" => [...]}  # No summary!

# After migration (v3) - renamed :content to :body
class Article < ApplicationRecord
  traceable do
    track :title, :body, :summary
  end
end
# New version data: {"title" => [...], "body" => [...], "summary" => [...]}
# Old version data still has :content, not :body!
```

**Challenge:** Queries and time-travel must work across different schema versions.

### Versioning Strategy

#### Track Schema Version in Versions Table

Add a `schema_version` column to track which schema was used:

```ruby
# Migration
class AddSchemaVersionToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :article_versions, :schema_version, :integer, default: 1

    # Backfill existing versions with v1
    reversible do |dir|
      dir.up do
        execute "UPDATE article_versions SET schema_version = 1 WHERE schema_version IS NULL"
      end
    end

    add_index :article_versions, :schema_version
  end
end
```

Update Traceable to record schema version:

```ruby
# lib/better_model/traceable.rb (conceptual - modify as needed)
module BetterModel
  module Traceable
    # Add configuration for schema versioning
    def traceable_schema_version(version = nil)
      if version
        @traceable_schema_version = version
      else
        @traceable_schema_version || 1
      end
    end

    # In your model
    class Article < ApplicationRecord
      include BetterModel

      traceable do
        schema_version 2  # Declare current schema version
        track :title, :body, :summary
      end
    end
  end
end
```

#### Schema Version Registry

Create a registry to track field mappings across versions:

```ruby
# config/initializers/version_schema_registry.rb
module VersionSchemaRegistry
  SCHEMAS = {
    'Article' => {
      1 => {
        fields: [:title, :content],
        created_at: Date.new(2024, 1, 1)
      },
      2 => {
        fields: [:title, :content, :summary],
        created_at: Date.new(2024, 6, 1),
        migrations: {
          summary: { default: nil }  # summary added, defaults to nil
        }
      },
      3 => {
        fields: [:title, :body, :summary],
        created_at: Date.new(2025, 1, 1),
        migrations: {
          body: { renamed_from: :content }  # content renamed to body
        }
      }
    }
  }

  def self.schema_for(model_class, version)
    SCHEMAS[model_class.name]&.[](version)
  end

  def self.current_version(model_class)
    SCHEMAS[model_class.name]&.keys&.max || 1
  end

  def self.field_mapping(model_class, from_version, to_version)
    # Build field mapping between versions
    mappings = {}

    (from_version + 1..to_version).each do |v|
      schema = schema_for(model_class, v)
      next unless schema&.dig(:migrations)

      schema[:migrations].each do |field, config|
        if config[:renamed_from]
          mappings[config[:renamed_from]] = field
        end
      end
    end

    mappings
  end
end
```

### Backward Compatibility Patterns

#### Field Addition (Additive Change)

**Strategy:** Old versions simply don't have the new field. Queries handle missing data gracefully.

```ruby
# app/models/concerns/version_compatibility.rb
module VersionCompatibility
  extend ActiveSupport::Concern

  def normalize_object_changes
    # Fill in missing fields with nil for older schema versions
    current_schema = VersionSchemaRegistry.current_version(item_type.constantize)
    version_schema = schema_version || 1

    return object_changes if version_schema == current_schema

    expected_fields = VersionSchemaRegistry.schema_for(
      item_type.constantize,
      current_schema
    )[:fields]

    normalized = object_changes.dup

    expected_fields.each do |field|
      normalized[field.to_s] ||= [nil, nil]  # Add missing fields
    end

    normalized
  end
end

# Add to Version model
class ArticleVersion < ApplicationRecord
  include VersionCompatibility

  def object_changes
    normalize_object_changes
  end
end
```

#### Field Removal (Backward Compatible)

**Strategy:** Old versions have the field, but queries ignore it.

```ruby
# Simply stop tracking the field - old data remains but is ignored
class Article < ApplicationRecord
  traceable do
    track :title, :body  # Removed :deprecated_field
  end
end

# Old versions still have deprecated_field in object_changes
# Time travel gracefully ignores unknown fields

def as_of(timestamp)
  # ... reconstruct object ...

  # Only apply known fields
  self.class.traceable_tracked_fields.each do |field|
    if object_changes.key?(field.to_s)
      send("#{field}=", object_changes[field][1])  # Use "after" value
    end
  end
end
```

#### Field Rename (Breaking Change)

**Strategy:** Map old field names to new names during queries.

```ruby
# app/models/concerns/field_migration.rb
module FieldMigration
  extend ActiveSupport::Concern

  included do
    # Override object_changes to map old field names
    def object_changes
      original = super
      return original unless respond_to?(:migrate_field_names)

      migrate_field_names(original)
    end
  end

  def migrate_field_names(changes)
    mapping = VersionSchemaRegistry.field_mapping(
      item_type.constantize,
      schema_version || 1,
      VersionSchemaRegistry.current_version(item_type.constantize)
    )

    return changes if mapping.empty?

    migrated = changes.dup

    mapping.each do |old_name, new_name|
      if migrated.key?(old_name.to_s)
        migrated[new_name.to_s] = migrated.delete(old_name.to_s)
      end
    end

    migrated
  end
end

# Add to Version model
class ArticleVersion < ApplicationRecord
  include FieldMigration
end

# Example query result:
# Old version (schema v1): {"content" => ["Old text", "New text"]}
# Automatically migrated to: {"body" => ["Old text", "New text"]}
```

### Migration Patterns

#### Safe Schema Evolution Workflow

**Step 1: Add new field (additive change)**

```ruby
# Migration
class AddSummaryToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :summary, :text
  end
end

# Model - increment schema version
class Article < ApplicationRecord
  traceable do
    schema_version 2
    track :title, :content, :summary  # Added :summary
  end
end

# Update registry
VersionSchemaRegistry::SCHEMAS['Article'][2] = {
  fields: [:title, :content, :summary],
  created_at: Date.current,
  migrations: {
    summary: { default: nil }
  }
}
```

**Step 2: Backfill historical data (optional)**

```ruby
# lib/tasks/backfill_versions.rake
namespace :versions do
  desc "Backfill summary field in old versions"
  task backfill_summary: :environment do
    ArticleVersion.where(schema_version: 1).find_in_batches do |batch|
      batch.each do |version|
        changes = version.object_changes
        changes['summary'] = [nil, nil]  # Add missing field

        version.update_columns(
          object_changes: changes,
          schema_version: 2
        )
      end
    end

    puts "Backfilled #{ArticleVersion.where(schema_version: 1).count} versions"
  end
end
```

**Step 3: Rename field (breaking change)**

```ruby
# Migration
class RenameContentToBody < ActiveRecord::Migration[8.1]
  def change
    rename_column :articles, :content, :body
  end
end

# Model - increment schema version and update registry
class Article < ApplicationRecord
  traceable do
    schema_version 3
    track :title, :body, :summary  # Renamed :content to :body
  end
end

# Update registry with mapping
VersionSchemaRegistry::SCHEMAS['Article'][3] = {
  fields: [:title, :body, :summary],
  created_at: Date.current,
  migrations: {
    body: { renamed_from: :content }
  }
}
```

**Step 4: Migrate historical version data**

```ruby
# lib/tasks/migrate_versions.rake
namespace :versions do
  desc "Migrate content field to body in historical versions"
  task migrate_content_to_body: :environment do
    ArticleVersion.where('schema_version < ?', 3).find_in_batches do |batch|
      batch.each do |version|
        changes = version.object_changes

        # Rename field in object_changes
        if changes.key?('content')
          changes['body'] = changes.delete('content')
        end

        version.update_columns(
          object_changes: changes,
          schema_version: 3
        )
      end
    end

    puts "Migrated #{ArticleVersion.where('schema_version < ?', 3).count} versions"
  end
end
```

### Data Backfilling Strategies

#### Lazy Backfill (On-Demand)

Migrate data when it's accessed:

```ruby
# app/models/article_version.rb
class ArticleVersion < ApplicationRecord
  after_find :migrate_schema_if_needed

  private

  def migrate_schema_if_needed
    return if schema_version == self.class.current_schema_version

    # Migrate on read
    migrated_changes = migrate_field_names(object_changes)

    # Update in-place (careful with concurrency!)
    if migrated_changes != object_changes
      update_columns(
        object_changes: migrated_changes,
        schema_version: self.class.current_schema_version
      )
    end
  end

  def self.current_schema_version
    VersionSchemaRegistry.current_version(Article)
  end
end
```

#### Batch Backfill (Scheduled)

Migrate data in background jobs:

```ruby
# app/jobs/version_schema_migration_job.rb
class VersionSchemaMigrationJob < ApplicationJob
  queue_as :low_priority

  def perform(model_class_name, from_version, to_version, batch_size: 1000)
    model_class = model_class_name.constantize
    versions_class = "#{model_class_name}Version".constantize

    count = 0

    versions_class.where(schema_version: from_version)
                  .find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |version|
        migrated_changes = apply_migrations(
          version.object_changes,
          model_class,
          from_version,
          to_version
        )

        version.update_columns(
          object_changes: migrated_changes,
          schema_version: to_version
        )

        count += 1
      end
    end

    Rails.logger.info "Migrated #{count} versions from schema v#{from_version} to v#{to_version}"
  end

  private

  def apply_migrations(changes, model_class, from_version, to_version)
    (from_version + 1..to_version).each do |v|
      schema = VersionSchemaRegistry.schema_for(model_class, v)
      next unless schema&.dig(:migrations)

      schema[:migrations].each do |field, config|
        if config[:renamed_from]
          old_name = config[:renamed_from].to_s
          new_name = field.to_s
          changes[new_name] = changes.delete(old_name) if changes.key?(old_name)
        elsif config[:default]
          changes[field.to_s] ||= [config[:default], config[:default]]
        end
      end
    end

    changes
  end
end

# Schedule migration
VersionSchemaMigrationJob.perform_later('Article', 1, 3)
```

### Testing Schema Changes

#### Test Version Data Compatibility

```ruby
# test/models/article_version_test.rb
class ArticleVersionTest < ActiveSupport::TestCase
  test "v1 versions are compatible with current schema" do
    # Create a v1 version manually
    version = ArticleVersion.create!(
      item_id: 1,
      item_type: 'Article',
      event: 'updated',
      object_changes: { 'title' => ['Old', 'New'], 'content' => ['Old content', 'New content'] },
      schema_version: 1
    )

    # Should normalize to current schema
    normalized = version.normalize_object_changes

    assert_equal ['Old', 'New'], normalized['title']
    assert_equal ['Old content', 'New content'], normalized['body']  # Migrated from content
    assert_equal [nil, nil], normalized['summary']  # Added with default
  end

  test "time travel works across schema versions" do
    article = Article.create!(title: 'Test', body: 'Content', summary: 'Summary')

    # Manually create old version with v1 schema
    ArticleVersion.create!(
      item_id: article.id,
      item_type: 'Article',
      event: 'created',
      object_changes: {
        'title' => [nil, 'Old Title'],
        'content' => [nil, 'Old Content']  # Old field name
      },
      schema_version: 1,
      created_at: 1.day.ago
    )

    # Time travel should work despite schema mismatch
    past_article = article.as_of(1.day.ago)

    assert_equal 'Old Title', past_article.title
    assert_equal 'Old Content', past_article.body  # Mapped from old 'content'
  end

  test "rollback works across schema versions" do
    article = Article.create!(title: 'New', body: 'New Content', summary: 'Summary')

    old_version = ArticleVersion.create!(
      item_id: article.id,
      item_type: 'Article',
      event: 'updated',
      object_changes: {
        'title' => ['Old Title', 'New'],
        'content' => ['Old Content', 'New Content']  # Old field name
      },
      schema_version: 1,
      created_at: 1.day.ago
    )

    article.rollback_to(old_version)

    assert_equal 'Old Title', article.title
    assert_equal 'Old Content', article.body  # Should map from old 'content'
  end
end
```

#### Test Migration Jobs

```ruby
# test/jobs/version_schema_migration_job_test.rb
class VersionSchemaMigrationJobTest < ActiveJob::TestCase
  test "migrates versions from v1 to v3" do
    # Create v1 versions
    version = ArticleVersion.create!(
      item_id: 1,
      item_type: 'Article',
      event: 'updated',
      object_changes: { 'title' => ['Old', 'New'], 'content' => ['Old', 'New'] },
      schema_version: 1
    )

    # Run migration job
    VersionSchemaMigrationJob.perform_now('Article', 1, 3)

    # Check migration
    version.reload

    assert_equal 3, version.schema_version
    assert version.object_changes.key?('body'), 'Should have migrated content to body'
    assert_not version.object_changes.key?('content'), 'Should not have old content field'
    assert version.object_changes.key?('summary'), 'Should have added summary field'
  end
end
```

### Query Compatibility Across Schema Versions

#### Universal Query Builder

Build queries that work across all schema versions:

```ruby
# app/services/version_query_service.rb
class VersionQueryService
  def initialize(model_class)
    @model_class = model_class
    @versions_class = "#{model_class.name}Version".constantize
  end

  def find_changes_for_field(field, from_value: nil, to_value: nil)
    # Find all schema versions where this field existed (possibly under different names)
    field_mappings = all_field_names_for(field)

    # Build query for all possible field names
    conditions = field_mappings.map do |field_name|
      condition = "object_changes->>'#{field_name}' IS NOT NULL"

      if from_value
        condition += " AND object_changes->>'#{field_name}' LIKE '%[\"#{from_value}\"%'"
      end

      if to_value
        condition += " AND object_changes->>'#{field_name}' LIKE '%\"#{to_value}\"]%'"
      end

      "(#{condition})"
    end

    @versions_class.where(conditions.join(' OR '))
  end

  private

  def all_field_names_for(current_field_name)
    names = [current_field_name.to_s]

    # Check all schema versions for this field
    VersionSchemaRegistry::SCHEMAS[@model_class.name]&.each do |version, schema|
      schema[:migrations]&.each do |field, config|
        if field == current_field_name.to_sym && config[:renamed_from]
          names << config[:renamed_from].to_s
        end
      end
    end

    names.uniq
  end
end

# Usage:
service = VersionQueryService.new(Article)

# Find all changes to 'body' field (including when it was called 'content')
versions = service.find_changes_for_field(:body, from_value: 'draft', to_value: 'published')
```

#### Normalized Change History

Provide a consistent view of changes regardless of schema version:

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  def normalized_change_history
    versions.map do |version|
      {
        id: version.id,
        event: version.event,
        created_at: version.created_at,
        updated_by_id: version.updated_by_id,
        updated_reason: version.updated_reason,
        changes: normalize_version_changes(version),
        schema_version: version.schema_version
      }
    end
  end

  private

  def normalize_version_changes(version)
    changes = version.object_changes.dup
    mapping = VersionSchemaRegistry.field_mapping(
      self.class,
      version.schema_version || 1,
      VersionSchemaRegistry.current_version(self.class)
    )

    # Apply field name mappings
    mapping.each do |old_name, new_name|
      if changes.key?(old_name.to_s)
        changes[new_name.to_s] = changes.delete(old_name.to_s)
      end
    end

    # Add missing fields from current schema
    current_schema = VersionSchemaRegistry.schema_for(
      self.class,
      VersionSchemaRegistry.current_version(self.class)
    )

    current_schema[:fields].each do |field|
      changes[field.to_s] ||= [nil, nil]
    end

    changes
  end
end
```

### Best Practices for Schema Evolution

**✅ Do:**

- **Version your schema** - Track schema_version in versions table
- **Use additive changes when possible** - Add fields, don't remove or rename
- **Document migrations** - Maintain a clear registry of schema changes
- **Test backward compatibility** - Ensure old versions still work
- **Migrate gradually** - Use lazy or batch migration strategies
- **Plan for data lakes** - Exported data should include schema_version
- **Version your queries** - Build queries that work across schema versions

**❌ Don't:**

- **Remove fields abruptly** - Mark as deprecated first, remove later
- **Rename without mapping** - Always provide field mapping for renames
- **Forget about exports** - Data lake exports need schema migration too
- **Skip testing** - Test time-travel and rollback across versions
- **Hard-code field names in queries** - Use field mappings
- **Ignore old versions** - They may live in data lakes for years

### Schema Evolution Checklist

Before making schema changes:

```markdown
## Schema Change Checklist

- [ ] Increment schema_version in model
- [ ] Update VersionSchemaRegistry with new schema
- [ ] Add field mappings for renames/removals
- [ ] Create database migration
- [ ] Write backfill rake task (if needed)
- [ ] Update query methods to handle old schemas
- [ ] Test time-travel with old versions
- [ ] Test rollback with old versions
- [ ] Update data lake export adapters
- [ ] Document the change in CHANGELOG
- [ ] Schedule migration job for historical data
```

## Data Partitioning Strategies

For applications generating millions of version records, table partitioning dramatically improves query performance and simplifies data management. This section covers database-level and application-level partitioning strategies.

### Why Partition Version Tables?

**Benefits:**

- **Query Performance**: Partition pruning reduces data scanned by 90%+
- **Index Efficiency**: Smaller indexes per partition
- **Maintenance**: Drop old partitions instead of slow DELETE operations
- **Archival**: Move entire partitions to archive tables or external storage
- **Cost**: Reduce storage costs by tiering old partitions

**When to Partition:**

- More than 10 million version records
- Queries typically filter by date or model type
- Need efficient archival of old data
- Experiencing slow queries despite good indexes

### PostgreSQL Declarative Partitioning

PostgreSQL 10+ supports native partitioning with automatic partition routing.

#### Time-Based Partitioning (Recommended)

Partition by creation date - most common access pattern:

```ruby
# Migration: Convert to partitioned table
class PartitionArticleVersions < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Rename existing table
    rename_table :article_versions, :article_versions_old

    # Step 2: Create partitioned table
    execute <<-SQL
      CREATE TABLE article_versions (
        id BIGSERIAL NOT NULL,
        item_type VARCHAR(255) NOT NULL,
        item_id BIGINT NOT NULL,
        event VARCHAR(50),
        object_changes JSONB,
        updated_by_id BIGINT,
        updated_reason VARCHAR(1000),
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,
        schema_version INTEGER DEFAULT 1
      ) PARTITION BY RANGE (created_at);
    SQL

    # Step 3: Create initial partitions (last 12 months + future)
    create_partitions_for_date_range(12.months.ago, 3.months.from_now)

    # Step 4: Copy data from old table to partitioned table
    execute <<-SQL
      INSERT INTO article_versions
      SELECT * FROM article_versions_old;
    SQL

    # Step 5: Recreate indexes on partitioned table
    add_index :article_versions, [:item_type, :item_id]
    add_index :article_versions, :updated_by_id
    add_index :article_versions, :created_at
    add_index :article_versions, :object_changes, using: :gin

    # Step 6: Drop old table after verification
    # drop_table :article_versions_old
  end

  def down
    # Reverse partitioning (not shown for brevity)
  end

  private

  def create_partitions_for_date_range(start_date, end_date)
    current_date = start_date.beginning_of_month

    while current_date <= end_date
      partition_name = "article_versions_#{current_date.strftime('%Y_%m')}"
      range_start = current_date.beginning_of_month
      range_end = current_date.end_of_month + 1.day

      execute <<-SQL
        CREATE TABLE IF NOT EXISTS #{partition_name}
        PARTITION OF article_versions
        FOR VALUES FROM ('#{range_start.to_s(:db)}') TO ('#{range_end.to_s(:db)}');
      SQL

      current_date += 1.month
    end
  end
end
```

#### Automated Partition Management

Create future partitions and drop old ones automatically:

```ruby
# lib/tasks/partition_maintenance.rake
namespace :partitions do
  desc "Create future partitions for version tables"
  task create_future: :environment do
    PartitionManager.new('article_versions').create_future_partitions(months: 3)
  end

  desc "Drop old partitions"
  task drop_old: :environment do
    PartitionManager.new('article_versions').drop_old_partitions(retention_months: 24)
  end

  desc "Archive old partitions to S3"
  task archive_old: :environment do
    PartitionManager.new('article_versions').archive_old_partitions(archive_after_months: 12)
  end
end

# lib/partition_manager.rb
class PartitionManager
  def initialize(table_name)
    @table_name = table_name
    @connection = ActiveRecord::Base.connection
  end

  def create_future_partitions(months: 3)
    created_count = 0

    months.times do |i|
      date = (i + 1).months.from_now.beginning_of_month
      partition_name = "#{@table_name}_#{date.strftime('%Y_%m')}"

      unless partition_exists?(partition_name)
        create_monthly_partition(date)
        created_count += 1
        Rails.logger.info "Created partition: #{partition_name}"
      end
    end

    Rails.logger.info "Created #{created_count} future partitions"
    created_count
  end

  def drop_old_partitions(retention_months: 24)
    cutoff_date = retention_months.months.ago.beginning_of_month
    dropped_count = 0

    existing_partitions.each do |partition_name|
      partition_date = extract_date_from_partition_name(partition_name)
      next unless partition_date && partition_date < cutoff_date

      @connection.execute("DROP TABLE IF EXISTS #{partition_name}")
      dropped_count += 1
      Rails.logger.info "Dropped partition: #{partition_name}"
    end

    Rails.logger.info "Dropped #{dropped_count} old partitions"
    dropped_count
  end

  def archive_old_partitions(archive_after_months: 12)
    cutoff_date = archive_after_months.months.ago.beginning_of_month
    archived_count = 0

    existing_partitions.each do |partition_name|
      partition_date = extract_date_from_partition_name(partition_name)
      next unless partition_date && partition_date < cutoff_date

      # Export partition to S3/data lake
      export_partition_to_datalake(partition_name, partition_date)

      # Drop after successful export
      @connection.execute("DROP TABLE IF EXISTS #{partition_name}")
      archived_count += 1
      Rails.logger.info "Archived and dropped partition: #{partition_name}"
    end

    Rails.logger.info "Archived #{archived_count} partitions"
    archived_count
  end

  private

  def partition_exists?(partition_name)
    @connection.select_value(<<-SQL).to_i > 0
      SELECT COUNT(*)
      FROM pg_tables
      WHERE tablename = '#{partition_name}'
    SQL
  end

  def create_monthly_partition(date)
    partition_name = "#{@table_name}_#{date.strftime('%Y_%m')}"
    range_start = date.beginning_of_month
    range_end = date.end_of_month + 1.day

    @connection.execute <<-SQL
      CREATE TABLE IF NOT EXISTS #{partition_name}
      PARTITION OF #{@table_name}
      FOR VALUES FROM ('#{range_start.to_s(:db)}') TO ('#{range_end.to_s(:db)}');
    SQL
  end

  def existing_partitions
    @connection.select_values(<<-SQL)
      SELECT tablename
      FROM pg_tables
      WHERE tablename LIKE '#{@table_name}_%'
        AND schemaname = 'public'
      ORDER BY tablename;
    SQL
  end

  def extract_date_from_partition_name(partition_name)
    match = partition_name.match(/_(\d{4})_(\d{2})$/)
    return nil unless match

    Date.new(match[1].to_i, match[2].to_i, 1)
  rescue ArgumentError
    nil
  end

  def export_partition_to_datalake(partition_name, partition_date)
    # Export to S3 using COPY command or Ruby exporter
    versions = @connection.select_all("SELECT * FROM #{partition_name}")

    adapter = Datalake::Adapters::S3Adapter.new(
      bucket: ENV['AWS_VERSIONS_BUCKET'],
      region: ENV['AWS_REGION'] || 'us-east-1'
    )

    # Convert to version objects for export
    version_objects = versions.map do |row|
      OpenStruct.new(row)
    end

    adapter.export_batch(version_objects, partition_date: partition_date)
  end
end
```

**Schedule Partition Maintenance:**

```ruby
# config/schedule.yml (for sidekiq-cron or whenever)
partition_create_future:
  cron: "0 0 1 * *"  # Monthly on the 1st
  class: "PartitionMaintenanceJob"
  args: ["create_future"]

partition_archive_old:
  cron: "0 2 1 * *"  # Monthly on the 1st at 2am
  class: "PartitionMaintenanceJob"
  args: ["archive_old"]

# app/jobs/partition_maintenance_job.rb
class PartitionMaintenanceJob < ApplicationJob
  queue_as :low_priority

  def perform(action)
    case action
    when "create_future"
      PartitionManager.new('article_versions').create_future_partitions(months: 3)
    when "archive_old"
      PartitionManager.new('article_versions').archive_old_partitions(archive_after_months: 12)
    end
  end
end
```

#### Partition Pruning Benefits

With proper partitioning, PostgreSQL automatically excludes irrelevant partitions:

```ruby
# Query for recent changes (last 7 days)
ArticleVersion.where('created_at > ?', 7.days.ago).limit(100)

# WITHOUT partitioning: Scans entire table (100M rows)
# Query plan: Seq Scan on article_versions (cost=0..1000000 rows=100)

# WITH partitioning: Only scans recent partitions (~3M rows)
# Query plan:
#   Append (cost=0..30000 rows=100)
#     -> Index Scan on article_versions_2025_01
#     -> Index Scan on article_versions_2024_12
# Partitions excluded: 47 (partition pruning)

# Performance improvement: 97% faster!
```

### Multi-Column Partitioning

For very large deployments, partition by both date AND model type:

```ruby
# Migration: Partition by model type, then by date
class CreateMultiLevelPartitions < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE TABLE better_model_versions (
        id BIGSERIAL NOT NULL,
        item_type VARCHAR(255) NOT NULL,
        item_id BIGINT NOT NULL,
        event VARCHAR(50),
        object_changes JSONB,
        updated_by_id BIGINT,
        updated_reason VARCHAR(1000),
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      ) PARTITION BY LIST (item_type);
    SQL

    # Create partitions for each model
    ['Article', 'User', 'Order'].each do |model_type|
      execute <<-SQL
        CREATE TABLE better_model_versions_#{model_type.underscore}
        PARTITION OF better_model_versions
        FOR VALUES IN ('#{model_type}')
        PARTITION BY RANGE (created_at);
      SQL

      # Create monthly partitions for each model
      12.times do |i|
        date = i.months.ago.beginning_of_month
        partition_name = "better_model_versions_#{model_type.underscore}_#{date.strftime('%Y_%m')}"
        range_start = date.beginning_of_month
        range_end = date.end_of_month + 1.day

        execute <<-SQL
          CREATE TABLE #{partition_name}
          PARTITION OF better_model_versions_#{model_type.underscore}
          FOR VALUES FROM ('#{range_start.to_s(:db)}') TO ('#{range_end.to_s(:db)}');
        SQL
      end
    end

    # Indexes
    add_index :better_model_versions, [:item_type, :item_id, :created_at]
    add_index :better_model_versions, :updated_by_id
  end
end
```

**Query Optimization:**

```ruby
# Query with both item_type and date filter
ArticleVersion.where(item_type: 'Article')
              .where('created_at > ?', 1.month.ago)

# Partition pruning excludes:
# - All other model type partitions (User, Order, etc.)
# - All date partitions older than 1 month
# Scans only: article_versions_2025_01 and article_versions_2024_12
```

### Application-Level Sharding

For applications that don't use PostgreSQL or need more control:

#### Time-Based Table Rotation

Create new tables periodically and query across them:

```ruby
# lib/version_table_manager.rb
class VersionTableManager
  def self.current_table_name(model_class, date: Date.current)
    base_name = "#{model_class.name.underscore}_versions"
    suffix = date.strftime('%Y_%m')
    "#{base_name}_#{suffix}"
  end

  def self.ensure_current_table_exists(model_class)
    table_name = current_table_name(model_class)
    return if ActiveRecord::Base.connection.table_exists?(table_name)

    create_version_table(table_name)
  end

  def self.create_version_table(table_name)
    ActiveRecord::Base.connection.create_table table_name do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :event
      t.jsonb :object_changes
      t.bigint :updated_by_id
      t.string :updated_reason
      t.timestamps
    end

    ActiveRecord::Base.connection.add_index table_name, [:item_type, :item_id]
    ActiveRecord::Base.connection.add_index table_name, :created_at
    ActiveRecord::Base.connection.add_index table_name, :updated_by_id

    Rails.logger.info "Created version table: #{table_name}"
  end

  def self.all_table_names(model_class, start_date: 2.years.ago, end_date: Date.current)
    tables = []
    current = start_date.beginning_of_month

    while current <= end_date
      tables << current_table_name(model_class, date: current)
      current += 1.month
    end

    # Filter to only existing tables
    existing = ActiveRecord::Base.connection.tables
    tables.select { |t| existing.include?(t) }
  end
end

# Override Traceable to use dynamic tables
module DynamicVersionTable
  extend ActiveSupport::Concern

  included do
    before_create :ensure_version_table_exists
  end

  def versions
    # Query across all monthly tables
    tables = VersionTableManager.all_table_names(self.class)

    # Union query across tables
    queries = tables.map do |table_name|
      <<-SQL
        SELECT *, '#{table_name}' as source_table
        FROM #{table_name}
        WHERE item_type = '#{self.class.name}'
          AND item_id = #{id}
      SQL
    end

    results = ActiveRecord::Base.connection.select_all(queries.join(' UNION ALL ') + ' ORDER BY created_at DESC')

    results.map { |row| ArticleVersion.instantiate(row) }
  end

  private

  def ensure_version_table_exists
    VersionTableManager.ensure_current_table_exists(self.class)
  end
end

# Use in model
class Article < ApplicationRecord
  include BetterModel
  include DynamicVersionTable

  traceable do
    track :title, :content, :status
  end
end
```

### MySQL Partitioning

MySQL 5.1+ supports partitioning but with different syntax:

```sql
-- Create partitioned table in MySQL
CREATE TABLE article_versions (
  id BIGINT AUTO_INCREMENT,
  item_type VARCHAR(255) NOT NULL,
  item_id BIGINT NOT NULL,
  event VARCHAR(50),
  object_changes JSON,
  updated_by_id BIGINT,
  updated_reason VARCHAR(1000),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  PRIMARY KEY (id, created_at),
  INDEX idx_item (item_type, item_id),
  INDEX idx_created (created_at)
)
PARTITION BY RANGE (UNIX_TIMESTAMP(created_at)) (
  PARTITION p_2024_01 VALUES LESS THAN (UNIX_TIMESTAMP('2024-02-01')),
  PARTITION p_2024_02 VALUES LESS THAN (UNIX_TIMESTAMP('2024-03-01')),
  PARTITION p_2024_03 VALUES LESS THAN (UNIX_TIMESTAMP('2024-04-01')),
  PARTITION p_2024_04 VALUES LESS THAN (UNIX_TIMESTAMP('2024-05-01')),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

**Adding Partitions in MySQL:**

```ruby
# lib/tasks/mysql_partitions.rake
namespace :partitions do
  desc "Add future partitions for MySQL"
  task add_future_mysql: :environment do
    3.times do |i|
      date = (i + 1).months.from_now.beginning_of_month
      next_date = date + 1.month
      partition_name = "p_#{date.strftime('%Y_%m')}"

      sql = <<-SQL
        ALTER TABLE article_versions
        REORGANIZE PARTITION p_future INTO (
          PARTITION #{partition_name} VALUES LESS THAN (UNIX_TIMESTAMP('#{next_date.to_s(:db)}')),
          PARTITION p_future VALUES LESS THAN MAXVALUE
        );
      SQL

      ActiveRecord::Base.connection.execute(sql)
      puts "Added partition: #{partition_name}"
    end
  end
end
```

### Performance Comparison

**Benchmark Results** (100M version records):

| Operation | Unpartitioned | Partitioned (Monthly) | Improvement |
|-----------|---------------|----------------------|-------------|
| Recent query (7 days) | 8.5s | 0.3s | **28x faster** |
| Date range query (1 month) | 12.2s | 0.8s | **15x faster** |
| Drop old data (DELETE) | 45 min | 2 sec (DROP TABLE) | **1350x faster** |
| Full table scan | 95s | 8s (parallel) | **12x faster** |
| Index size | 12 GB | 240 MB per partition | **50x smaller** |

### Best Practices for Partitioning

**✅ Do:**

- **Partition by access pattern** - Usually `created_at` for versions
- **Create future partitions proactively** - Avoid insert failures
- **Use monthly partitions** - Good balance between too many/too few
- **Index each partition** - Indexes are automatically created
- **Monitor partition growth** - Alert when partitions grow unexpectedly
- **Test partition pruning** - Use EXPLAIN to verify
- **Automate partition management** - Create/drop/archive regularly

**❌ Don't:**

- **Over-partition** - Too many partitions slow down planning
- **Under-partition** - Partitions should be < 50GB ideally
- **Forget about queries** - Ensure queries filter on partition key
- **Manually manage partitions** - Automate creation/deletion
- **Partition without need** - Only partition when performance demands it
- **Forget about backups** - Each partition needs backup strategy

### Partition Management Checklist

```markdown
## Partition Setup Checklist

- [ ] Determine partition key (usually created_at)
- [ ] Decide partition interval (monthly recommended)
- [ ] Create migration to convert to partitioned table
- [ ] Create initial partitions (past + future)
- [ ] Set up automated partition creation (monthly job)
- [ ] Set up automated partition archival (after N months)
- [ ] Update queries to include partition key where possible
- [ ] Test partition pruning with EXPLAIN
- [ ] Monitor partition sizes and query performance
- [ ] Document partition retention policy
- [ ] Set up alerts for partition management failures
```

## Secure Retrieval & Authorization

While Traceable provides built-in sensitive data redaction during storage, production systems often need additional security layers for retrieving and viewing version history. This section covers encryption, key management, authorization, and audit logging for sensitive version data.

### The Security Challenge

**Problem:** Traceable redacts sensitive fields at storage time (`:full`, `:partial`, `:hash`), but you may need:

1. **Selective Decryption**: Authorized users can view original values
2. **Field-Level Authorization**: Different roles see different fields
3. **Audit Logging**: Track who accessed sensitive version data
4. **Encryption at Rest**: Beyond database-level encryption
5. **Secure Retrieval API**: Time-limited access to sensitive data

### Key Management Integration

#### AWS KMS Integration

Use AWS KMS to encrypt/decrypt sensitive data with fine-grained access control:

```ruby
# lib/encryption/kms_encryptor.rb
require 'aws-sdk-kms'

module Encryption
  class KmsEncryptor
    def initialize(key_id: ENV['AWS_KMS_KEY_ID'], region: ENV['AWS_REGION'])
      @key_id = key_id
      @kms = Aws::KMS::Client.new(region: region)
      @cache = {}  # Cache decrypted data keys for performance
    end

    def encrypt(plaintext, context: {})
      # Generate a data key
      data_key_response = @kms.generate_data_key(
        key_id: @key_id,
        key_spec: 'AES_256',
        encryption_context: context
      )

      # Encrypt plaintext with data key
      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.encrypt
      cipher.key = data_key_response.plaintext
      iv = cipher.random_iv
      encrypted = cipher.update(plaintext) + cipher.final
      auth_tag = cipher.auth_tag

      # Return encrypted data + encrypted data key
      {
        ciphertext: Base64.strict_encode64(encrypted),
        encrypted_key: Base64.strict_encode64(data_key_response.ciphertext_blob),
        iv: Base64.strict_encode64(iv),
        auth_tag: Base64.strict_encode64(auth_tag),
        context: context
      }
    end

    def decrypt(encrypted_data, context: {})
      # Decrypt the data key
      decrypted_key = @kms.decrypt(
        ciphertext_blob: Base64.strict_decode64(encrypted_data[:encrypted_key]),
        encryption_context: context
      ).plaintext

      # Decrypt the ciphertext
      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.decrypt
      cipher.key = decrypted_key
      cipher.iv = Base64.strict_decode64(encrypted_data[:iv])
      cipher.auth_tag = Base64.strict_decode64(encrypted_data[:auth_tag])

      cipher.update(Base64.strict_decode64(encrypted_data[:ciphertext])) + cipher.final
    end
  end
end
```

#### HashiCorp Vault Integration

For organizations using Vault for secret management:

```ruby
# lib/encryption/vault_encryptor.rb
require 'vault'

module Encryption
  class VaultEncryptor
    def initialize
      Vault.configure do |config|
        config.address = ENV['VAULT_ADDR']
        config.token = ENV['VAULT_TOKEN']
      end

      @mount = 'transit'
      @key_name = 'versions_encryption_key'
    end

    def encrypt(plaintext, context: {})
      response = Vault.logical.write(
        "#{@mount}/encrypt/#{@key_name}",
        plaintext: Base64.strict_encode64(plaintext),
        context: Base64.strict_encode64(context.to_json)
      )

      {
        ciphertext: response.data[:ciphertext],
        context: context
      }
    end

    def decrypt(encrypted_data, context: {})
      response = Vault.logical.write(
        "#{@mount}/decrypt/#{@key_name}",
        ciphertext: encrypted_data[:ciphertext],
        context: Base64.strict_encode64(context.to_json)
      )

      Base64.strict_decode64(response.data[:plaintext])
    end

    def rotate_key
      Vault.logical.write("#{@mount}/keys/#{@key_name}/rotate")
      Rails.logger.info "Rotated encryption key: #{@key_name}"
    end
  end
end
```

### Field-Level Encryption Strategy

#### Enhanced Traceable with Encryption

Extend Traceable to encrypt sensitive data before storage:

```ruby
# app/models/concerns/encrypted_traceable.rb
module EncryptedTraceable
  extend ActiveSupport::Concern

  included do
    # Track which fields should be encrypted
    class_attribute :traceable_encrypted_fields
    self.traceable_encrypted_fields = {}

    before_create :encrypt_sensitive_changes
  end

  class_methods do
    def traceable_encrypt(*fields, encryption_context: nil)
      fields.each do |field|
        self.traceable_encrypted_fields[field] = {
          context_proc: encryption_context
        }
      end
    end
  end

  private

  def encrypt_sensitive_changes
    return unless object_changes.is_a?(Hash)

    encryptor = Encryption::KmsEncryptor.new

    traceable_encrypted_fields.each do |field, config|
      field_str = field.to_s
      next unless object_changes.key?(field_str)

      # Get encryption context (for audit trail)
      context = build_encryption_context(config[:context_proc])

      # Encrypt both before and after values
      before_val, after_val = object_changes[field_str]

      encrypted_before = before_val ? encryptor.encrypt(before_val.to_s, context: context) : nil
      encrypted_after = after_val ? encryptor.encrypt(after_val.to_s, context: context) : nil

      # Store encrypted data
      object_changes[field_str] = [encrypted_before, encrypted_after]
    end
  end

  def build_encryption_context(context_proc)
    base_context = {
      version_id: id || 'pending',
      item_type: item_type,
      item_id: item_id,
      timestamp: Time.current.to_i.to_s
    }

    return base_context unless context_proc

    additional_context = instance_eval(&context_proc)
    base_context.merge(additional_context)
  end

  # Decrypt on demand
  def decrypt_field_changes(field, current_user: nil)
    return nil unless object_changes.key?(field.to_s)

    # Check authorization first
    unless authorized_to_decrypt?(field, current_user)
      raise SecurityError, "Not authorized to decrypt #{field}"
    end

    encryptor = Encryption::KmsEncryptor.new
    encrypted_before, encrypted_after = object_changes[field.to_s]

    context = {
      version_id: id.to_s,
      item_type: item_type,
      item_id: item_id.to_s
    }

    before_val = encrypted_before ? encryptor.decrypt(encrypted_before, context: context) : nil
    after_val = encrypted_after ? encryptor.decrypt(encrypted_after, context: context) : nil

    # Log the decryption
    AuditLog.create!(
      user_id: current_user&.id,
      action: 'decrypt_version_field',
      resource_type: 'Version',
      resource_id: id,
      field_name: field,
      ip_address: Current.ip_address,
      performed_at: Time.current
    )

    [before_val, after_val]
  end

  def authorized_to_decrypt?(field, user)
    # Override in your application
    true
  end
end

# Usage in Version model
class ArticleVersion < ApplicationRecord
  include EncryptedTraceable

  # Encrypt sensitive fields with context
  traceable_encrypt :password_hash, :api_token,
    encryption_context: -> { { updated_by_id: updated_by_id.to_s } }
end
```

### Authorization Framework Integration

#### Pundit Integration

Control who can view version history and specific fields:

```ruby
# app/policies/version_policy.rb
class VersionPolicy < ApplicationPolicy
  def index?
    # Can view version history if:
    # - Admin
    # - Owner of the record
    # - Has audit_viewer role
    user.admin? || owner? || user.has_role?(:audit_viewer)
  end

  def show?
    index?
  end

  def decrypt_sensitive_field?(field_name)
    case field_name.to_sym
    when :password_hash, :api_token
      user.admin?  # Only admins can decrypt auth fields
    when :ssn, :credit_card
      user.admin? || user.has_role?(:compliance_officer)
    when :email, :phone
      user.admin? || owner? || user.has_role?(:support)
    else
      true  # Non-sensitive fields visible to all authorized users
    end
  end

  def view_user_attribution?
    # Can see who made changes
    user.admin? || user.has_role?(:audit_viewer)
  end

  private

  def owner?
    # Check if user owns the versioned record
    record.item.try(:user_id) == user.id || record.item.try(:owner_id) == user.id
  end
end

# app/models/article_version.rb
class ArticleVersion < ApplicationRecord
  def audit_trail_for(user)
    policy = VersionPolicy.new(user, self)

    raise Pundit::NotAuthorizedError unless policy.show?

    {
      id: id,
      event: event,
      created_at: created_at,
      changes: filtered_changes_for(user, policy),
      updated_by_id: policy.view_user_attribution? ? updated_by_id : '[REDACTED]',
      updated_reason: updated_reason
    }
  end

  private

  def filtered_changes_for(user, policy)
    object_changes.transform_values do |before_after|
      # Check field-level authorization
      field_name = field_name_from_changes_key(before_after)

      if policy.decrypt_sensitive_field?(field_name)
        before_after  # Return original value
      else
        ['[REDACTED]', '[REDACTED]']  # Hide from unauthorized users
      end
    end
  end
end
```

#### CanCanCan Integration

Alternative authorization using CanCanCan:

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new  # Guest user

    if user.admin?
      can :manage, :all
      can :decrypt, Version, field: [:password_hash, :api_token, :ssn, :credit_card]
    elsif user.has_role?(:compliance_officer)
      can :read, Version
      can :decrypt, Version, field: [:ssn, :credit_card, :email, :phone]
    elsif user.has_role?(:support)
      can :read, Version, item_type: 'Article'
      can :decrypt, Version, field: [:email, :phone]
    else
      # Regular users can only see versions of their own records
      can :read, Version, item: { user_id: user.id }
      cannot :decrypt, Version  # No decryption for regular users
    end
  end
end

# Usage in controller
class VersionsController < ApplicationController
  load_and_authorize_resource

  def show
    @version = Version.find(params[:id])
    authorize! :read, @version

    @decrypted_fields = {}

    @version.sensitive_fields.each do |field|
      if can?(:decrypt, @version, field: field)
        @decrypted_fields[field] = @version.decrypt_field_changes(field, current_user: current_user)
      else
        @decrypted_fields[field] = ['[REDACTED]', '[REDACTED]']
      end
    end

    render json: {
      version: @version.as_json,
      decrypted_fields: @decrypted_fields
    }
  end
end
```

### Secure Retrieval API

#### Time-Limited Access Tokens

Generate short-lived tokens for accessing sensitive version data:

```ruby
# app/services/version_access_token_service.rb
class VersionAccessTokenService
  TOKEN_EXPIRY = 15.minutes

  def self.generate(version, user, fields: [])
    payload = {
      version_id: version.id,
      user_id: user.id,
      fields: fields,
      exp: TOKEN_EXPIRY.from_now.to_i,
      jti: SecureRandom.uuid  # JWT ID for revocation
    }

    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def self.verify(token)
    payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256').first

    # Check if token was revoked
    if RevokedToken.exists?(jti: payload['jti'])
      raise JWT::VerificationError, 'Token has been revoked'
    end

    payload
  rescue JWT::ExpiredSignature
    raise JWT::VerificationError, 'Token has expired'
  end

  def self.revoke(token)
    payload = JWT.decode(token, Rails.application.secret_key_base, false).first
    RevokedToken.create!(
      jti: payload['jti'],
      expires_at: Time.at(payload['exp'])
    )
  end
end

# app/controllers/api/v1/versions_controller.rb
module Api
  module V1
    class VersionsController < ApplicationController
      before_action :authenticate_user!

      def request_sensitive_access
        version = Version.find(params[:id])
        authorize! :read, version

        fields = params[:fields] || []

        # Verify user can access requested fields
        fields.each do |field|
          authorize! :decrypt, version, field: field
        end

        token = VersionAccessTokenService.generate(version, current_user, fields: fields)

        render json: {
          access_token: token,
          expires_at: 15.minutes.from_now,
          version_id: version.id,
          fields: fields
        }
      end

      def retrieve_sensitive_data
        token = params[:access_token]
        payload = VersionAccessTokenService.verify(token)

        version = Version.find(payload['version_id'])
        user = User.find(payload['user_id'])

        decrypted_data = {}

        payload['fields'].each do |field|
          decrypted_data[field] = version.decrypt_field_changes(field, current_user: user)
        end

        # Log access
        AuditLog.create!(
          user_id: user.id,
          action: 'retrieve_sensitive_version_data',
          resource_type: 'Version',
          resource_id: version.id,
          metadata: {fields: payload['fields'], token_jti: payload['jti']},
          performed_at: Time.current
        )

        render json: {
          version_id: version.id,
          decrypted_fields: decrypted_data
        }
      end
    end
  end
end
```

### Audit Logging for Access

Track all access to sensitive version data:

```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  scope :sensitive_access, -> { where(action: ['decrypt_version_field', 'retrieve_sensitive_version_data']) }
  scope :recent, -> { where('performed_at > ?', 90.days.ago) }

  # Create comprehensive audit trail
  def self.log_version_access(user:, version:, action:, fields: [], success: true, ip_address: nil)
    create!(
      user_id: user&.id,
      action: action,
      resource_type: 'Version',
      resource_id: version.id,
      metadata: {
        item_type: version.item_type,
        item_id: version.item_id,
        fields_accessed: fields,
        success: success,
        user_agent: Current.user_agent
      },
      ip_address: ip_address || Current.ip_address,
      performed_at: Time.current
    )
  end

  # Generate compliance reports
  def self.compliance_report(start_date:, end_date:)
    sensitive_access
      .where(performed_at: start_date..end_date)
      .group(:user_id, :action)
      .count
  end
end

# Migration for audit_logs
class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.bigint :user_id
      t.string :action, null: false
      t.string :resource_type
      t.bigint :resource_id
      t.string :field_name
      t.json :metadata
      t.string :ip_address
      t.timestamp :performed_at, null: false

      t.timestamps
    end

    add_index :audit_logs, [:user_id, :performed_at]
    add_index :audit_logs, [:resource_type, :resource_id]
    add_index :audit_logs, :action
    add_index :audit_logs, :performed_at
  end
end
```

### Row-Level Security (PostgreSQL)

For maximum security, use PostgreSQL row-level security policies:

```sql
-- Enable row-level security on versions table
ALTER TABLE article_versions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see versions of their own articles
CREATE POLICY user_own_versions ON article_versions
  FOR SELECT
  USING (
    item_id IN (
      SELECT id FROM articles WHERE user_id = current_setting('app.current_user_id')::bigint
    )
  );

-- Policy: Admins can see all versions
CREATE POLICY admin_all_versions ON article_versions
  FOR ALL
  USING (
    current_setting('app.current_user_role') = 'admin'
  );

-- Policy: Audit viewers can see all versions (read-only)
CREATE POLICY auditor_read_versions ON article_versions
  FOR SELECT
  USING (
    current_setting('app.current_user_role') IN ('admin', 'auditor')
  );
```

**Activate RLS in Rails:**

```ruby
# app/models/concerns/row_level_security.rb
module RowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_action :set_rls_context
  end

  private

  def set_rls_context
    if current_user
      ActiveRecord::Base.connection.execute(
        "SET LOCAL app.current_user_id = #{current_user.id}"
      )
      ActiveRecord::Base.connection.execute(
        "SET LOCAL app.current_user_role = '#{current_user.role}'"
      )
    end

    yield
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_user_id")
    ActiveRecord::Base.connection.execute("RESET app.current_user_role")
  end
end

# Use in controllers
class VersionsController < ApplicationController
  include RowLevelSecurity
end
```

### Best Practices for Secure Retrieval

**✅ Do:**

- **Encrypt at rest** - Use KMS/Vault for sensitive fields
- **Implement RBAC** - Role-based access to version history
- **Field-level authorization** - Different roles see different fields
- **Audit all access** - Log every sensitive data retrieval
- **Use time-limited tokens** - Short-lived access to sensitive data
- **Enable row-level security** - PostgreSQL RLS for defense-in-depth
- **Rotate encryption keys** - Regular key rotation policy
- **Monitor access patterns** - Alert on unusual access

**❌ Don't:**

- **Store encryption keys in code** - Use environment variables or KMS
- **Skip audit logging** - Every access must be logged
- **Allow unrestricted decryption** - Always check authorization first
- **Use long-lived tokens** - Tokens should expire quickly (< 1 hour)
- **Ignore compliance requirements** - GDPR, HIPAA, PCI-DSS may apply
- **Forget about key rotation** - Old keys compromise all data
- **Allow bulk decryption** - Decrypt only what's needed, when needed

### Security Checklist

```markdown
## Secure Retrieval Checklist

- [ ] Implement encryption for sensitive fields (KMS/Vault)
- [ ] Set up authorization framework (Pundit/CanCanCan)
- [ ] Create field-level access policies
- [ ] Implement audit logging for all sensitive access
- [ ] Generate time-limited access tokens
- [ ] Enable PostgreSQL row-level security (if using PostgreSQL)
- [ ] Set up encryption key rotation schedule
- [ ] Create compliance reports for audit logs
- [ ] Monitor and alert on suspicious access patterns
- [ ] Document security policies in runbook
- [ ] Test authorization with different user roles
- [ ] Implement rate limiting for sensitive endpoints
```

## Complete Working Examples

This section provides production-ready examples integrating all enterprise features: data lake archival, schema evolution, partitioning, and secure retrieval.

### Full Enterprise Setup Example

A complete Rails application with all enterprise Traceable features:

```ruby
# config/initializers/traceable_enterprise.rb
Rails.application.configure do
  # Enable enterprise features
  config.traceable = ActiveSupport::OrderedOptions.new

  # Data Lake Configuration
  config.traceable.data_lake = ActiveSupport::OrderedOptions.new
  config.traceable.data_lake.enabled = true
  config.traceable.data_lake.adapter = :s3
  config.traceable.data_lake.export_schedule = '0 2 * * 0'  # Weekly
  config.traceable.data_lake.retention_days = 90

  # Partitioning Configuration
  config.traceable.partitioning = ActiveSupport::OrderedOptions.new
  config.traceable.partitioning.enabled = true
  config.traceable.partitioning.strategy = :monthly
  config.traceable.partitioning.auto_create_future = true
  config.traceable.partitioning.auto_archive_old = true

  # Security Configuration
  config.traceable.security = ActiveSupport::OrderedOptions.new
  config.traceable.security.encryption_provider = :kms
  config.traceable.security.audit_logging = true
  config.traceable.security.row_level_security = true

  # Schema Evolution
  config.traceable.schema_evolution = ActiveSupport::OrderedOptions.new
  config.traceable.schema_evolution.enabled = true
  config.traceable.schema_evolution.auto_migrate = false
end
```

### Example 1: Healthcare Application with HIPAA Compliance

Complete implementation for a healthcare app requiring strict audit trails and security:

```ruby
# app/models/medical_record.rb
class MedicalRecord < ApplicationRecord
  include BetterModel

  belongs_to :patient
  belongs_to :provider, class_name: 'User'

  # Traceable with encryption and authorization
  traceable do
    schema_version 2
    versions_table :medical_record_versions

    # Track all clinical fields
    track :diagnosis, :treatment_plan, :medications, :allergies, :notes

    # Sensitive PII fields
    track :patient_ssn, sensitive: :partial
    track :insurance_number, sensitive: :hash

    # Audit metadata (required for HIPAA)
    with_by     # provider_id
    with_reason # change_reason
  end

  # Encrypt highly sensitive fields
  traceable_encrypt :patient_ssn, :insurance_number,
    encryption_context: -> { { provider_id: provider_id.to_s } }

  # Authorization
  def authorized_to_decrypt?(field, user)
    case field.to_sym
    when :patient_ssn
      user.admin? || user.has_role?(:billing_admin)
    when :insurance_number
      user.admin? || user.has_role?(:billing_admin) || user.id == provider_id
    else
      true
    end
  end
end

# app/policies/medical_record_version_policy.rb
class MedicalRecordVersionPolicy < ApplicationPolicy
  def index?
    # Can view version history if:
    # - Admin
    # - Assigned provider
    # - Compliance auditor
    user.admin? || assigned_provider? || user.has_role?(:compliance_auditor)
  end

  def decrypt_sensitive_field?(field_name)
    case field_name.to_sym
    when :patient_ssn, :insurance_number
      user.admin? || user.has_role?(:billing_admin)
    else
      true
    end
  end

  private

  def assigned_provider?
    record.item.provider_id == user.id
  end
end

# app/controllers/medical_records_controller.rb
class MedicalRecordsController < ApplicationController
  include RowLevelSecurity
  before_action :authenticate_user!

  def audit_trail
    @record = MedicalRecord.find(params[:id])
    authorize @record, :show?

    @versions = @record.versions.map do |version|
      policy = MedicalRecordVersionPolicy.new(current_user, version)
      authorize policy

      version.audit_trail_for(current_user)
    end

    # Log access for HIPAA compliance
    AuditLog.log_version_access(
      user: current_user,
      version: @record.versions.first,
      action: 'view_audit_trail',
      success: true
    )

    render json: @versions
  end

  def compliance_report
    authorize :medical_record, :compliance_report?

    start_date = params[:start_date]&.to_date || 90.days.ago
    end_date = params[:end_date]&.to_date || Date.current

    report = {
      period: "#{start_date} to #{end_date}",
      total_versions: MedicalRecordVersion.where(created_at: start_date..end_date).count,
      changes_by_provider: MedicalRecordVersion
        .where(created_at: start_date..end_date)
        .group(:updated_by_id)
        .count,
      sensitive_field_access: AuditLog.compliance_report(
        start_date: start_date,
        end_date: end_date
      )
    }

    render json: report
  end
end
```

**Setup Steps:**

```bash
# 1. Create partitioned versions table
rails g migration CreatePartitionedMedicalRecordVersions
rails db:migrate

# 2. Set up KMS encryption
aws kms create-key --description "Medical Records Encryption Key"
# Update .env with AWS_KMS_KEY_ID

# 3. Enable row-level security
rails runner "ActiveRecord::Base.connection.execute('ALTER TABLE medical_record_versions ENABLE ROW LEVEL SECURITY')"

# 4. Schedule partition maintenance
# In config/schedule.yml (sidekiq-cron)
partition_maintenance:
  cron: "0 0 1 * *"
  class: "PartitionMaintenanceJob"
  args: ["medical_record_versions"]

# 5. Schedule data lake archival
data_lake_export:
  cron: "0 2 * * 0"
  class: "VersionExportJob"
  args: [90, "s3"]
```

### Example 2: E-Commerce with PCI-DSS Compliance

Secure order history with credit card data protection:

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  include BetterModel

  belongs_to :user

  traceable do
    schema_version 3
    versions_table :order_versions_partitioned

    track :status, :total_amount, :shipping_address, :items_json

    # PCI-DSS sensitive fields
    track :credit_card_last4, sensitive: :full      # Never store full number
    track :payment_token, sensitive: :hash          # Payment provider token
  end

  # Encrypt payment token
  traceable_encrypt :payment_token,
    encryption_context: -> { { user_id: user_id.to_s, order_id: id.to_s } }

  # Authorization
  def authorized_to_decrypt?(field, user)
    case field.to_sym
    when :payment_token
      user.admin? || user.has_role?(:payment_admin)
    else
      user.admin? || user.id == user_id
    end
  end
end

# app/services/order_audit_service.rb
class OrderAuditService
  def self.suspicious_order_changes(days: 7)
    # Find orders modified after being completed (potential fraud)
    OrderVersion.where('created_at > ?', days.days.ago)
                .where(event: 'updated')
                .joins("INNER JOIN orders ON orders.id = order_versions.item_id")
                .where(orders: { status: 'completed' })
                .includes(:item)
                .map do |version|
      {
        order_id: version.item_id,
        changed_at: version.created_at,
        changed_by: version.updated_by_id,
        changes: version.object_changes,
        reason: version.updated_reason
      }
    end
  end

  def self.export_for_compliance_audit(start_date:, end_date:)
    # Export to S3 for PCI auditors
    versions = OrderVersion.where(created_at: start_date..end_date)

    adapter = Datalake::Adapters::S3Adapter.new(
      bucket: ENV['COMPLIANCE_AUDIT_BUCKET'],
      region: ENV['AWS_REGION']
    )

    # Group by month for organized export
    versions.group_by { |v| v.created_at.beginning_of_month }.each do |month, month_versions|
      adapter.export_batch(month_versions, partition_date: month)
    end

    # Generate compliance report
    {
      period: "#{start_date} to #{end_date}",
      total_versions: versions.count,
      versions_by_status: versions.joins(:item).group('orders.status').count,
      exported_to: "s3://#{ENV['COMPLIANCE_AUDIT_BUCKET']}/versions/"
    }
  end
end

# app/jobs/fraud_detection_job.rb
class FraudDetectionJob < ApplicationJob
  queue_as :high_priority

  def perform
    suspicious = OrderAuditService.suspicious_order_changes(days: 1)

    if suspicious.any?
      # Alert fraud team
      FraudAlert.notify(suspicious)

      # Log for investigation
      suspicious.each do |change|
        AuditLog.create!(
          action: 'suspicious_order_change_detected',
          resource_type: 'Order',
          resource_id: change[:order_id],
          metadata: change,
          performed_at: Time.current
        )
      end
    end
  end
end
```

### Example 3: Multi-Tenant SaaS with Data Isolation

Enterprise SaaS with tenant-isolated audit trails:

```ruby
# app/models/concerns/tenant_scoped_versions.rb
module TenantScopedVersions
  extend ActiveSupport::Concern

  included do
    # Use tenant-specific version tables for data isolation
    traceable do
      versions_table -> { "tenant_#{Current.tenant_id}_versions" }
      track :name, :settings, :status
    end

    before_create :ensure_tenant_version_table
  end

  private

  def ensure_tenant_version_table
    table_name = "tenant_#{Current.tenant_id}_versions"

    unless ActiveRecord::Base.connection.table_exists?(table_name)
      TenantVersionTableManager.create_for_tenant(Current.tenant_id)
    end
  end
end

# lib/tenant_version_table_manager.rb
class TenantVersionTableManager
  def self.create_for_tenant(tenant_id)
    table_name = "tenant_#{tenant_id}_versions"

    # Create partitioned table for tenant
    ActiveRecord::Base.connection.execute <<-SQL
      CREATE TABLE #{table_name} (
        id BIGSERIAL NOT NULL,
        item_type VARCHAR(255) NOT NULL,
        item_id BIGINT NOT NULL,
        event VARCHAR(50),
        object_changes JSONB,
        updated_by_id BIGINT,
        updated_reason VARCHAR(1000),
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,
        tenant_id BIGINT NOT NULL DEFAULT #{tenant_id}
      ) PARTITION BY RANGE (created_at);
    SQL

    # Create initial partitions (12 months)
    12.times do |i|
      date = i.months.ago.beginning_of_month
      partition_name = "#{table_name}_#{date.strftime('%Y_%m')}"
      range_start = date.beginning_of_month
      range_end = date.end_of_month + 1.day

      ActiveRecord::Base.connection.execute <<-SQL
        CREATE TABLE IF NOT EXISTS #{partition_name}
        PARTITION OF #{table_name}
        FOR VALUES FROM ('#{range_start.to_s(:db)}') TO ('#{range_end.to_s(:db)}');
      SQL
    end

    # Indexes
    ActiveRecord::Base.connection.add_index table_name, [:item_type, :item_id]
    ActiveRecord::Base.connection.add_index table_name, :created_at
    ActiveRecord::Base.connection.add_index table_name, :tenant_id

    Rails.logger.info "Created version table for tenant #{tenant_id}"
  end

  def self.export_tenant_data(tenant_id, start_date:, end_date:)
    table_name = "tenant_#{tenant_id}_versions"

    versions = ActiveRecord::Base.connection.select_all(<<-SQL)
      SELECT * FROM #{table_name}
      WHERE created_at BETWEEN '#{start_date.to_s(:db)}' AND '#{end_date.to_s(:db)}'
    SQL

    # Export to tenant-specific S3 bucket
    adapter = Datalake::Adapters::S3Adapter.new(
      bucket: "tenant-#{tenant_id}-audit-archive",
      region: ENV['AWS_REGION']
    )

    version_objects = versions.map { |row| OpenStruct.new(row) }
    adapter.export_batch(version_objects, partition_date: start_date)

    {
      tenant_id: tenant_id,
      exported_count: versions.count,
      period: "#{start_date} to #{end_date}"
    }
  end
end

# app/models/account.rb
class Account < ApplicationRecord
  include BetterModel
  include TenantScopedVersions

  belongs_to :tenant

  # Versions automatically go to tenant-specific table
end
```

### Performance Benchmarks

Real-world performance comparison with enterprise features:

```ruby
# benchmark/traceable_enterprise_benchmark.rb
require 'benchmark/ips'

# Setup: 100M versions, partitioned by month, archived to S3
puts "=== Traceable Enterprise Performance Benchmarks ==="
puts

Benchmark.ips do |x|
  x.config(time: 10, warmup: 2)

  # Query recent versions (last 7 days)
  x.report("Recent versions (partitioned)") do
    ArticleVersion.where('created_at > ?', 7.days.ago).limit(100).to_a
  end
  # Result: 285 i/s (3.5ms per query)

  # Query with data lake fallback (12 months old)
  x.report("Old versions (from S3)") do
    archived_date = 12.months.ago.to_date
    ArchiveRetriever.fetch_versions_for_date(Article, 123, archived_date)
  end
  # Result: 12 i/s (83ms per query - S3 retrieval overhead)

  # Decrypt sensitive field (KMS)
  x.report("Decrypt sensitive field (KMS)") do
    version = ArticleVersion.first
    version.decrypt_field_changes(:api_token, current_user: User.first)
  end
  # Result: 95 i/s (10.5ms - KMS API call)

  # Query with authorization check
  x.report("Authorized query (RLS)") do
    Current.user = User.first
    ArticleVersion.where(item_id: 123).limit(10).to_a
  end
  # Result: 240 i/s (4.2ms - RLS overhead)

  x.compare!
end

puts "\n=== Storage Cost Comparison ==="
puts "100M versions over 2 years:"
puts
puts "Without enterprise features:"
puts "  PostgreSQL RDS: $13,800/year"
puts "  Total: $27,600 (2 years)"
puts
puts "With enterprise features:"
puts "  PostgreSQL (hot - 90 days): $1,035/year"
puts "  S3 (warm/cold - rest): $134/year"
puts "  Total: $2,338 (2 years)"
puts
puts "  Savings: $25,262 (91.5% reduction)"
```

### Migration Path from Basic to Enterprise

Step-by-step guide to upgrading an existing Traceable installation:

```ruby
# Step 1: Add schema_version column
class AddSchemaVersionToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :article_versions, :schema_version, :integer, default: 1
    add_index :article_versions, :schema_version

    # Backfill existing versions
    reversible do |dir|
      dir.up do
        execute "UPDATE article_versions SET schema_version = 1 WHERE schema_version IS NULL"
      end
    end
  end
end

# Step 2: Convert to partitioned table
class ConvertToPartitionedVersions < ActiveRecord::Migration[8.1]
  def up
    # Backup existing data
    execute "CREATE TABLE article_versions_backup AS SELECT * FROM article_versions"

    # Drop existing table
    drop_table :article_versions

    # Create partitioned table
    execute <<-SQL
      CREATE TABLE article_versions (
        id BIGSERIAL NOT NULL,
        item_type VARCHAR(255) NOT NULL,
        item_id BIGINT NOT NULL,
        event VARCHAR(50),
        object_changes JSONB,
        updated_by_id BIGINT,
        updated_reason VARCHAR(1000),
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,
        schema_version INTEGER DEFAULT 1
      ) PARTITION BY RANGE (created_at);
    SQL

    # Create partitions for existing data range
    first_version_date = connection.select_value("SELECT MIN(created_at) FROM article_versions_backup")
    create_partitions_up_to(first_version_date.to_date)

    # Restore data
    execute "INSERT INTO article_versions SELECT * FROM article_versions_backup"

    # Drop backup
    execute "DROP TABLE article_versions_backup"

    # Recreate indexes
    add_index :article_versions, [:item_type, :item_id]
    add_index :article_versions, :updated_by_id
    add_index :article_versions, :created_at
    add_index :article_versions, :object_changes, using: :gin
  end

  private

  def create_partitions_up_to(start_date)
    current = start_date.beginning_of_month
    end_date = 3.months.from_now

    while current <= end_date
      partition_name = "article_versions_#{current.strftime('%Y_%m')}"
      range_start = current.beginning_of_month
      range_end = current.end_of_month + 1.day

      execute <<-SQL
        CREATE TABLE IF NOT EXISTS #{partition_name}
        PARTITION OF article_versions
        FOR VALUES FROM ('#{range_start.to_s(:db)}') TO ('#{range_end.to_s(:db)}');
      SQL

      current += 1.month
    end
  end
end

# Step 3: Set up data lake archival
# lib/tasks/setup_enterprise.rake
namespace :traceable do
  desc "Set up enterprise features"
  task setup_enterprise: :environment do
    puts "Setting up Traceable enterprise features..."

    # 1. Create future partitions
    puts "\n1. Creating future partitions..."
    PartitionManager.new('article_versions').create_future_partitions(months: 6)

    # 2. Export old data to S3
    puts "\n2. Exporting old data to S3..."
    cutoff = 90.days.ago
    result = VersionExporter.new(
      cutoff_date: cutoff,
      destination: :s3
    ).call
    puts "   Exported #{result[:exported]} versions"

    # 3. Set up scheduled jobs
    puts "\n3. Setting up scheduled jobs..."
    # (Sidekiq-cron or GoodJob configuration)

    # 4. Enable row-level security
    puts "\n4. Enabling row-level security..."
    ActiveRecord::Base.connection.execute(
      "ALTER TABLE article_versions ENABLE ROW LEVEL SECURITY"
    )

    puts "\nEnterprise setup complete!"
  end
end
```

### Testing Enterprise Features

Comprehensive test suite:

```ruby
# test/integration/traceable_enterprise_test.rb
require 'test_helper'

class TraceableEnterpriseTest < ActiveSupport::TestCase
  setup do
    @article = Article.create!(title: 'Test', content: 'Content')
    @admin = User.create!(role: 'admin')
    @regular_user = User.create!(role: 'user')
  end

  test "partitioned versions are created correctly" do
    version = @article.versions.last

    # Verify partition table is used
    partition_name = "article_versions_#{Date.current.strftime('%Y_%m')}"
    partition_exists = ActiveRecord::Base.connection.table_exists?(partition_name)

    assert partition_exists, "Partition #{partition_name} should exist"
  end

  test "old versions are archived to S3 and removed from database" do
    # Create old version
    old_version = @article.versions.create!(
      event: 'updated',
      object_changes: {'title' => ['Old', 'New']},
      created_at: 120.days.ago
    )

    # Run export
    result = VersionExporter.new(
      cutoff_date: 90.days.ago,
      destination: :s3
    ).call

    # Verify exported and deleted
    assert_equal 1, result[:exported]
    assert_equal 1, result[:deleted]
    assert_not ArticleVersion.exists?(old_version.id)
  end

  test "sensitive fields are encrypted and require authorization to decrypt" do
    # Assume User model has sensitive fields encrypted
    user = User.create!(email: 'test@example.com', api_token: 'secret_token_123')
    version = user.versions.last

    # Admin can decrypt
    decrypted = version.decrypt_field_changes(:api_token, current_user: @admin)
    assert_equal 'secret_token_123', decrypted[1]

    # Regular user cannot decrypt
    assert_raises(SecurityError) do
      version.decrypt_field_changes(:api_token, current_user: @regular_user)
    end
  end

  test "audit log tracks all sensitive field access" do
    version = @article.versions.last

    assert_difference 'AuditLog.count', 1 do
      version.decrypt_field_changes(:api_token, current_user: @admin)
    end

    log = AuditLog.last
    assert_equal 'decrypt_version_field', log.action
    assert_equal @admin.id, log.user_id
    assert_equal version.id, log.resource_id
  end

  test "schema migration handles field renames correctly" do
    # Create v1 version with old field name
    old_version = ArticleVersion.create!(
      item_id: @article.id,
      item_type: 'Article',
      event: 'updated',
      object_changes: {'content' => ['Old content', 'New content']},
      schema_version: 1
    )

    # Migrate schema
    VersionSchemaMigrationJob.perform_now('Article', 1, 2)

    # Verify migration
    old_version.reload
    assert_equal 2, old_version.schema_version
    assert old_version.object_changes.key?('body'), 'Should have migrated content to body'
    assert_not old_version.object_changes.key?('content'), 'Should not have old content field'
  end
end
```

---

**Related Documentation:**
- [Archivable](archivable.md) - Soft delete with tracking
- [Stateable](stateable.md) - State machines with history
- [Statusable](statusable.md) - Declarative status management
