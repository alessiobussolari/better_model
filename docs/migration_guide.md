# 🚀 Migration Guide

This guide walks you through adding BetterModel concerns to existing Rails applications and models. Learn how to migrate safely, handle data backfilling, and maintain backwards compatibility.

## Table of Contents

- [Overview](#overview)
- [Before You Start](#before-you-start)
- [Installing BetterModel](#installing-bettermodel)
- [Migrating Existing Models](#migrating-existing-models)
  - [Adding Archivable](#adding-archivable)
  - [Adding Traceable](#adding-traceable)
  - [Adding Stateable](#adding-stateable)
  - [Adding Statusable](#adding-statusable)
  - [Adding Predicable/Sortable/Searchable](#adding-predicablesortablesearchable)
  - [Adding Permissible](#adding-permissible)
  - [Adding Validatable](#adding-validatable)
- [Data Migration Strategies](#data-migration-strategies)
- [Backwards Compatibility](#backwards-compatibility)
- [Testing Strategy](#testing-strategy)
- [Rollback Plans](#rollback-plans)
- [Common Migration Scenarios](#common-migration-scenarios)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

Adding BetterModel to an existing application requires careful planning:

**Migration Phases:**
1. **Planning** - Understand current code and plan changes
2. **Database Setup** - Add required columns/tables
3. **Code Changes** - Add concerns and configure
4. **Data Backfill** - Populate new fields with existing data
5. **Testing** - Verify functionality
6. **Deployment** - Roll out with monitoring
7. **Cleanup** - Remove old code once stable

## Before You Start

### Checklist

- [ ] **Backup database** - Full backup before any changes
- [ ] **Review current code** - Understand existing implementations
- [ ] **Plan concern usage** - Which concerns do you need?
- [ ] **Check database version** - Ensure compatibility (Rails 8.1+)
- [ ] **Test environment ready** - CI/CD pipeline for testing
- [ ] **Rollback plan** - Know how to revert changes
- [ ] **Monitor setup** - APM tools for performance tracking

### Compatibility Check

```ruby
# Check Rails version
Rails.version  # Should be >= 8.1.0

# Check Ruby version
RUBY_VERSION  # Should be >= 3.0.0

# Check database
ActiveRecord::Base.connection.adapter_name
# PostgreSQL, MySQL, or SQLite
```

## Installing BetterModel

### 1. Add to Gemfile

```ruby
# Gemfile
gem 'better_model', '~> 1.1'
```

### 2. Install

```bash
bundle install
```

### 3. Basic Setup

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Option 1: Include in base class (all models get BetterModel)
  include BetterModel

  # Option 2: Include per-model (more control)
  # Don't include here, include in individual models
end
```

## Migrating Existing Models

### Adding Archivable

**Scenario:** You have manual soft-delete with `deleted_at`.

#### Current Code

```ruby
class Article < ApplicationRecord
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end
end
```

#### Step 1: Database Migration

```ruby
# db/migrate/XXXXXX_migrate_to_archivable.rb
class MigrateToArchivable < ActiveRecord::Migration[8.1]
  def up
    # Rename deleted_at to archived_at
    rename_column :articles, :deleted_at, :archived_at

    # Add optional tracking columns
    add_column :articles, :archive_by_id, :bigint
    add_column :articles, :archive_reason, :string

    # Update index
    remove_index :articles, :deleted_at if index_exists?(:articles, :deleted_at)
    add_index :articles, :archived_at
    add_index :articles, :archive_by_id
  end

  def down
    remove_index :articles, :archive_by_id
    remove_index :articles, :archived_at
    remove_column :articles, :archive_reason
    remove_column :articles, :archive_by_id
    rename_column :articles, :archived_at, :deleted_at
    add_index :articles, :deleted_at
  end
end
```

```bash
rails db:migrate
```

#### Step 2: Update Model

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Add Archivable
  archivable do
    with_by
    with_reason
    default_scope_exclude_archived  # Optional: replaces default_scope
  end

  # Keep old methods for backwards compatibility (temporary)
  alias_method :soft_delete, :archive!
  alias_method :deleted?, :archived?
  alias_method :deleted_at, :archived_at
end
```

#### Step 3: Update Code Usage

```ruby
# Old code
article.soft_delete
article.restore
Article.active
Article.deleted

# New code (update gradually)
article.archive!(by: current_user.id, reason: "Outdated")
article.unarchive!
Article.not_archived
Article.archived_only
```

#### Step 4: Remove Compatibility Layer

Once all code is updated:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    with_by
    with_reason
    default_scope_exclude_archived
  end

  # Remove aliases when all code is migrated
end
```

### Adding Traceable

**Scenario:** You want audit trail for existing model.

#### Step 1: Database Migration

```ruby
# Option 1: Use generator
rails g better_model:traceable Article --with-reason

# Option 2: Manual migration
# db/migrate/XXXXXX_add_traceable_to_articles.rb
class AddTraceableToArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :article_versions do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :event
      t.jsonb :object_changes  # Use jsonb on PostgreSQL
      t.bigint :updated_by_id
      t.string :updated_reason
      t.timestamps
    end

    add_index :article_versions, [:item_type, :item_id]
    add_index :article_versions, :updated_by_id
    add_index :article_versions, :created_at
    add_index :article_versions, :object_changes, using: :gin  # PostgreSQL
  end
end
```

```bash
rails db:migrate
```

#### Step 2: Update Model

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Add Traceable
  traceable do
    track :title, :content, :status, :published_at
    versions_table :article_versions  # Optional custom name
  end
end
```

#### Step 3: Backfill Initial Versions (Optional)

```ruby
# db/migrate/XXXXXX_backfill_article_versions.rb
class BackfillArticleVersions < ActiveRecord::Migration[8.1]
  def up
    Article.find_each do |article|
      # Create initial "created" version with current state
      article.versions.create!(
        event: "created",
        object_changes: article.attributes.slice("title", "content", "status", "published_at")
                              .transform_values { |v| [nil, v] },
        created_at: article.created_at,
        updated_at: article.created_at
      )
    end
  end

  def down
    ArticleVersion.where(event: "created").delete_all
  end
end
```

#### Step 4: Update Controllers

```ruby
# Add tracking metadata
class ArticlesController < ApplicationController
  def update
    @article = Article.find(params[:id])

    if @article.update(article_params.merge(
      updated_by_id: current_user.id,
      updated_reason: params[:change_reason]
    ))
      redirect_to @article, notice: "Article updated"
    else
      render :edit
    end
  end

  private

  def article_params
    params.require(:article).permit(:title, :content, :status)
  end
end
```

### Adding Stateable

**Scenario:** You have manual state management with status column.

#### Current Code

```ruby
class Order < ApplicationRecord
  VALID_STATUSES = %w[pending confirmed paid shipped delivered cancelled]

  validates :status, inclusion: { in: VALID_STATUSES }

  def confirm!
    return false unless status == "pending"
    update(status: "confirmed")
  end

  def pay!
    return false unless status == "confirmed"
    update(status: "paid")
  end

  def pending?
    status == "pending"
  end

  def confirmed?
    status == "confirmed"
  end
end
```

#### Step 1: Database Migration

```ruby
# db/migrate/XXXXXX_migrate_to_stateable.rb
class MigrateToStateable < ActiveRecord::Migration[8.1]
  def change
    # Rename status to state (if needed)
    rename_column :orders, :status, :state if column_exists?(:orders, :status)

    # Create state transitions table
    create_table :state_transitions do |t|
      t.string :transitionable_type, null: false
      t.bigint :transitionable_id, null: false
      t.string :event, null: false
      t.string :from_state, null: false
      t.string :to_state, null: false
      t.jsonb :metadata
      t.timestamps
    end

    add_index :state_transitions, [:transitionable_type, :transitionable_id]
    add_index :state_transitions, :event
    add_index :state_transitions, :created_at
  end
end
```

```bash
rails db:migrate
```

#### Step 2: Update Model

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Add Stateable
  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid
    state :shipped
    state :delivered
    state :cancelled

    transition :confirm, from: :pending, to: :confirmed do
      guard { items.any? }
      before :calculate_total
      after :send_confirmation_email
    end

    transition :pay, from: :confirmed, to: :paid do
      guard { payment_method.present? }
      before :charge_payment
      after :send_receipt
    end

    transition :ship, from: :paid, to: :shipped do
      before { self.shipped_at = Time.current }
    end

    transition :deliver, from: :shipped, to: :delivered

    transition :cancel, from: [:pending, :confirmed], to: :cancelled
  end

  # Keep old constant for backwards compatibility (temporary)
  VALID_STATUSES = stateable_states.map(&:to_s)

  # Old methods still work via Stateable
  # pending?, confirmed?, etc. are auto-generated
end
```

#### Step 3: Update Code Usage

```ruby
# Old code
order.confirm!
order.status == "confirmed"

# New code (same interface!)
order.confirm!         # Stateable method
order.confirmed?       # Auto-generated
order.state            # "confirmed"

# New capabilities
order.can_confirm?     # Check if transition allowed
order.transition_history  # Full state history
```

### Adding Statusable

**Scenario:** You have manual boolean methods for derived statuses.

#### Current Code

```ruby
class Article < ApplicationRecord
  def publishable?
    title.present? && content.present? && !archived?
  end

  def editable?
    draft? && !archived?
  end

  def draft?
    status == "draft"
  end

  def published?
    status == "published"
  end
end
```

#### Migration (No Database Changes Needed)

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Add Statusable
  statusable do
    status :publishable do
      title.present? && content.present? && !archived?
    end

    status :editable do
      draft? && !archived?
    end

    status :draft do
      status == "draft"
    end

    status :published do
      status == "published"
    end
  end

  # Old methods still work via Statusable
  # publishable?, editable?, etc. now use Statusable
end
```

### Adding Predicable/Sortable/Searchable

**Scenario:** You have manual scopes for filtering and sorting.

#### Current Code

```ruby
class Article < ApplicationRecord
  scope :by_status, ->(status) { where(status: status) }
  scope :by_author, ->(author_id) { where(author_id: author_id) }
  scope :published_after, ->(date) { where("published_at > ?", date) }
  scope :title_contains, ->(term) { where("title LIKE ?", "%#{term}%") }
  scope :recent_first, -> { order(created_at: :desc) }
end
```

#### Migration (No Database Changes Needed)

```ruby
class Article < ApplicationRecord
  include BetterModel  # Includes Predicable, Sortable, Searchable

  # Old scopes can coexist temporarily
  scope :by_status, ->(status) { where(status: status) }
  # ...

  # Configure Searchable (optional)
  searchable do
    max_per_page 100
    default_order :created_at, :desc
  end
end

# New usage (Predicable)
Article.status_eq("published")
Article.author_id_eq(123)
Article.published_at_gt(1.week.ago)
Article.title_cont("Rails")

# New usage (Sortable)
Article.order_by_created_at_desc

# New usage (Searchable)
Article.search(
  status_eq: "published",
  author_id_eq: 123,
  order_by: :created_at,
  order_dir: :desc
)
```

#### Gradual Migration

```ruby
# Phase 1: Add BetterModel, keep old scopes
# Phase 2: Update code to use new predicates
# Phase 3: Remove old scopes when all code migrated

# Remove old scopes once migrated
# scope :by_status, ->(status) { where(status: status) }  # REMOVED
```

### Adding Permissible

**Scenario:** You have manual authorization methods.

#### Current Code

```ruby
class Article < ApplicationRecord
  def can_edit_by?(user)
    draft? && (user.admin? || author_id == user.id)
  end

  def can_publish_by?(user)
    draft? && user.admin?
  end

  def can_delete_by?(user)
    user.admin?
  end
end
```

#### Migration (No Database Changes Needed)

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Add Permissible
  permissible do
    permission :edit, if: -> { draft? }
    permission :publish, if: -> { draft? }
    permission :delete, if: -> { true }
  end

  # Keep user-specific checks in controller/policy
  def can_edit_by?(user)
    can_edit? && (user.admin? || author_id == user.id)
  end
end
```

### Adding Validatable

**Scenario:** You have standard Rails validations you want to organize.

#### Current Code

```ruby
class Article < ApplicationRecord
  validates :title, presence: true
  validates :content, presence: true, if: :published?
  validates :published_at, presence: true, if: :published?

  def published?
    status == "published"
  end
end
```

#### Migration (No Database Changes Needed)

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Add Statusable for conditions
  statusable do
    status :published do
      status == "published"
    end
  end

  # Add Validatable
  validatable do
    validate :title, presence: true

    validate_if :is_published? do
      validate :content, presence: true
      validate :published_at, presence: true
    end
  end
end
```

## Data Migration Strategies

### Backfilling Archivable Data

```ruby
# Migrate from deleted_at to archived_at with tracking
class BackfillArchivableData < ActiveRecord::Migration[8.1]
  def up
    # Already renamed deleted_at to archived_at in schema migration
    # Now backfill tracking fields from audit logs or defaults

    Article.where.not(archived_at: nil).find_each do |article|
      # Try to find who archived it from logs/audits
      audit_entry = find_audit_entry_for(article)

      article.update_columns(
        archive_by_id: audit_entry&.user_id || 1,  # Default admin user
        archive_reason: audit_entry&.reason || "Migrated from old system"
      )
    end
  end

  private

  def find_audit_entry_for(article)
    # Query your existing audit system
    AuditLog.find_by(
      auditable_type: "Article",
      auditable_id: article.id,
      action: "deleted"
    )
  end
end
```

### Backfilling Stateable History

```ruby
# Create initial state transitions from existing data
class BackfillStateTransitions < ActiveRecord::Migration[8.1]
  def up
    Order.find_each do |order|
      # Create initial transition
      order.state_transitions.create!(
        event: "created",
        from_state: "new",
        to_state: order.state,
        created_at: order.created_at,
        updated_at: order.created_at
      )

      # If you have audit logs, create transitions for historical state changes
      backfill_from_audit_logs(order)
    end
  end

  private

  def backfill_from_audit_logs(order)
    AuditLog.where(auditable_type: "Order", auditable_id: order.id)
            .where("changes->>'status' IS NOT NULL")
            .order(:created_at).each do |log|
      changes = log.changes["status"]
      from_state = changes[0]
      to_state = changes[1]

      order.state_transitions.create!(
        event: derive_event_name(from_state, to_state),
        from_state: from_state,
        to_state: to_state,
        metadata: { migrated_from_audit: true },
        created_at: log.created_at,
        updated_at: log.created_at
      )
    end
  end

  def derive_event_name(from, to)
    case [from, to]
    when ["pending", "confirmed"] then "confirm"
    when ["confirmed", "paid"] then "pay"
    else "transition"
    end
  end
end
```

## Backwards Compatibility

### Alias Methods

Keep old method names during transition:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    with_by
  end

  # Backwards compatibility aliases
  alias_method :soft_delete, :archive!
  alias_method :deleted_at, :archived_at
  alias_method :deleted?, :archived?
  alias_method :restore, :unarchive!

  # Deprecation warnings
  def soft_delete(*args)
    ActiveSupport::Deprecation.warn("soft_delete is deprecated, use archive! instead")
    archive!(*args)
  end
end
```

### Dual Scope Support

Support both old and new scope names:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # New BetterModel scopes available automatically
  # status_eq, title_cont, etc.

  # Keep old scopes temporarily
  scope :by_status, ->(status) { status_eq(status) }
  scope :by_author, ->(author_id) { author_id_eq(author_id) }
  scope :recent, -> { order_by_created_at_desc }

  # Mark as deprecated
  def self.by_status(status)
    ActiveSupport::Deprecation.warn("by_status is deprecated, use status_eq instead")
    status_eq(status)
  end
end
```

## Testing Strategy

### Test Old and New Interfaces

```ruby
# test/models/article_test.rb
class ArticleTest < ActiveSupport::TestCase
  test "archivable works" do
    article = articles(:one)

    # New interface
    assert_not article.archived?
    article.archive!(by: users(:admin).id, reason: "Test")
    assert article.archived?

    # Old interface (backwards compatibility)
    assert article.deleted?  # Alias
    assert_equal article.archived_at, article.deleted_at
  end

  test "stateable transitions work" do
    order = orders(:pending)

    # New interface
    assert order.can_confirm?
    assert order.confirm!
    assert order.confirmed?

    # Check transition created
    assert_equal 1, order.state_transitions.count
    assert_equal "confirm", order.state_transitions.last.event
  end
end
```

### Integration Tests

```ruby
# test/integration/article_workflow_test.rb
class ArticleWorkflowTest < ActionDispatch::IntegrationTest
  test "complete article lifecycle" do
    sign_in users(:author)

    # Create
    post articles_path, params: { article: { title: "Test", content: "Content" } }
    article = Article.last

    # Should be trackable
    assert_equal 1, article.versions.count

    # Should be searchable
    results = Article.search(title_cont: "Test")
    assert_includes results, article

    # Should be archivable
    delete article_path(article)
    assert article.reload.archived?
  end
end
```

## Rollback Plans

### Database Rollback

```ruby
# Each migration has a down method
class MigrateToArchivable < ActiveRecord::Migration[8.1]
  def up
    rename_column :articles, :deleted_at, :archived_at
    # ...
  end

  def down
    # Reverse changes
    rename_column :articles, :archived_at, :deleted_at
    # ...
  end
end

# Rollback
rails db:rollback
```

### Code Rollback

```ruby
# Use feature flags for gradual rollout
class Article < ApplicationRecord
  if ENV['USE_BETTER_MODEL'] == 'true'
    include BetterModel

    archivable do
      with_by
    end
  else
    # Old implementation
    scope :active, -> { where(deleted_at: nil) }

    def soft_delete
      update(deleted_at: Time.current)
    end
  end
end
```

### Gradual Rollout

```ruby
# Enable for specific models first
class Article < ApplicationRecord
  include BetterModel if ENV['BETTER_MODEL_ARTICLES'] == 'true'
end

class Order < ApplicationRecord
  include BetterModel if ENV['BETTER_MODEL_ORDERS'] == 'true'
end

# Enable gradually
# Week 1: BETTER_MODEL_ARTICLES=true
# Week 2: BETTER_MODEL_ORDERS=true
```

## Common Migration Scenarios

### Scenario 1: Large Production Database

**Challenge:** Million+ records, can't run backfill in single migration.

**Solution:**

```ruby
# Migration: Just schema changes
class AddTraceableSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :article_versions do |t|
      # ... schema ...
    end
  end
end

# Background job: Backfill in batches
class BackfillVersionsJob < ApplicationJob
  def perform(batch_size: 1000)
    Article.where(versions_backfilled: false)
           .find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |article|
        backfill_versions_for(article)
        article.update_column(:versions_backfilled, true)
      end

      # Pause between batches to avoid overload
      sleep 1
    end
  end

  private

  def backfill_versions_for(article)
    article.versions.create!(
      event: "created",
      object_changes: build_initial_changes(article),
      created_at: article.created_at
    )
  end
end

# Run gradually
BackfillVersionsJob.perform_later
```

### Scenario 2: Zero-Downtime Deployment

**Strategy:**

1. **Deploy 1: Add columns/tables only**
   ```ruby
   # Migration: Add archived_at column (nullable)
   add_column :articles, :archived_at, :datetime
   # No code changes yet
   ```

2. **Deploy 2: Dual-write to old and new columns**
   ```ruby
   # Write to both deleted_at and archived_at
   article.update(deleted_at: Time.current, archived_at: Time.current)
   ```

3. **Deploy 3: Backfill data**
   ```ruby
   # Background job: Copy deleted_at to archived_at
   Article.where.not(deleted_at: nil).where(archived_at: nil)
          .update_all("archived_at = deleted_at")
   ```

4. **Deploy 4: Switch reads to new column**
   ```ruby
   # Read from archived_at, still write to both
   def archived?
     archived_at.present?
   end
   ```

5. **Deploy 5: Stop writing to old column**
   ```ruby
   # Only write to archived_at
   include BetterModel
   archivable do; end
   ```

6. **Deploy 6: Remove old column**
   ```ruby
   remove_column :articles, :deleted_at
   ```

### Scenario 3: Multi-Tenant Application

**Challenge:** Different tenants may have different states.

**Solution:**

```ruby
# Migration: Add tenant-specific state handling
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true

    # Tenant-specific states
    if Tenant.current.feature_enabled?(:advanced_workflow)
      state :pre_confirmed
      state :confirmed
      transition :pre_confirm, from: :pending, to: :pre_confirmed
      transition :confirm, from: :pre_confirmed, to: :confirmed
    else
      state :confirmed
      transition :confirm, from: :pending, to: :confirmed
    end
  end
end
```

## Troubleshooting

### Issue: Existing records have nil state

```ruby
# Problem
order = Order.first
order.state  # => nil
order.confirm!  # => Error: invalid transition

# Solution: Set initial state in migration
class SetInitialState < ActiveRecord::Migration[8.1]
  def up
    Order.where(state: nil).update_all(state: "pending")
  end
end
```

### Issue: Validation failures after adding Validatable

```ruby
# Problem
article.save  # => false
article.errors  # => New validations failing

# Solution: Fix data first, then add validations
class FixArticleData < ActiveRecord::Migration[8.1]
  def up
    # Fix invalid data before adding Validatable
    Article.where(title: nil).update_all(title: "Untitled")
    Article.where("published_at IS NOT NULL AND content IS NULL")
           .update_all(published_at: nil)
  end
end

# Then add Validatable
```

### Issue: N+1 queries after adding Traceable

```ruby
# Problem
articles = Article.limit(10)
articles.each { |a| a.audit_trail }  # N+1 queries

# Solution: Eager load
articles = Article.includes(:versions).limit(10)
articles.each { |a| a.audit_trail }  # 2 queries
```

## Best Practices

### ✅ Do

- **Backup before migration** - Full database backup
- **Test on staging first** - Never migrate production first
- **Migrate incrementally** - One concern at a time
- **Keep backwards compatibility** - Use aliases during transition
- **Monitor performance** - Watch query times, N+1 queries
- **Use feature flags** - Gradual rollout and easy rollback
- **Backfill in batches** - For large datasets
- **Add indexes first** - Before enabling features
- **Update tests** - Cover both old and new interfaces
- **Document changes** - Update README, changelog

### ❌ Don't

- **Don't migrate everything at once** - Too risky
- **Don't skip testing** - Test thoroughly before production
- **Don't forget indexes** - Performance will suffer
- **Don't remove old code immediately** - Keep for transition period
- **Don't ignore errors** - Fix data issues before adding concerns
- **Don't skip backfill** - Historical data is important
- **Don't forget rollback plan** - Know how to revert
- **Don't deploy on Friday** - Give time for monitoring

### Migration Checklist

- [ ] Database backed up
- [ ] Migrations written and tested
- [ ] Indexes added
- [ ] Model code updated
- [ ] Backwards compatibility maintained
- [ ] Tests updated and passing
- [ ] Controllers/services updated
- [ ] Views updated if needed
- [ ] Staging tested
- [ ] Performance monitored
- [ ] Rollback plan ready
- [ ] Team notified
- [ ] Documentation updated

---

**Related Documentation:**
- [Integration Guide](integration_guide.md) - Combining multiple concerns
- [Performance Guide](performance_guide.md) - Optimization after migration
- Individual concern docs for specific features

**Need Help?**

- Start with one concern on one model
- Test thoroughly on staging
- Use feature flags for gradual rollout
- Monitor performance closely
- Keep rollback plan ready
