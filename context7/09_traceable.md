# Traceable - Comprehensive Audit Trail and Change Tracking

## Overview

**Traceable** is an opt-in audit trail and change tracking system for Rails models that provides complete visibility into your data's history. It automatically records all changes to configured model attributes with full context including what changed, when, who made the change, and why.

**Key Features**:
- **Automatic Change Tracking**: Records create, update, and destroy operations
- **Sensitive Data Protection**: Three-level redaction system (full, partial, hash)
- **Time Travel**: Reconstruct object state at any point in history
- **Rollback Support**: Restore records to previous versions
- **User Attribution**: Track who made each change (`updated_by_id`)
- **Change Context**: Optional reason field for change explanations (`updated_reason`)
- **Rich Query API**: Find records by user changes, time ranges, or field transitions
- **Flexible Storage**: Per-model tables, shared tables, or custom table names
- **Database Optimized**: PostgreSQL JSONB, MySQL JSON, SQLite text support
- **Thread-Safe**: Immutable configuration and safe for concurrent requests

**When to Use Traceable**:
- Content management systems requiring revision history
- Compliance and regulatory requirements (HIPAA, GDPR, SOX)
- Financial systems tracking transaction changes
- Document approval workflows
- Multi-tenant applications with audit requirements
- E-commerce order status tracking
- HR systems managing employee record changes
- Feature flag management with change history
- Any system requiring "who changed what and when"

## Basic Concepts

### Opt-In Activation

Traceable is **not active by default**. You must explicitly enable it:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable Traceable
  traceable do
    track :status, :title, :content, :published_at
  end
end
```

### What Gets Tracked

Only explicitly specified fields are tracked:
- Changes to tracked fields create version records
- Untracked fields don't create versions
- `id`, `created_at`, `updated_at` are automatically excluded
- Foreign keys can be tracked if explicitly specified

### Version Record Anatomy

Each change creates a version record containing:

```ruby
version.item_type        # Polymorphic type ("Article")
version.item_id          # Record ID (123)
version.event            # "created", "updated", or "destroyed"
version.object_changes   # JSON hash of field changes
version.updated_by_id    # User who made the change
version.updated_reason   # Why the change was made
version.created_at       # When the version was created
```

### Database Schema

Versions are stored in dedicated tables with this structure:

```ruby
create_table :article_versions do |t|
  t.string :item_type, null: false      # Polymorphic type
  t.bigint :item_id, null: false        # Polymorphic ID
  t.string :event                        # created/updated/destroyed
  t.json :object_changes                 # Field changes (use jsonb for PostgreSQL)
  t.bigint :updated_by_id               # User attribution
  t.string :updated_reason              # Change context
  t.timestamps                           # Version timestamps
end

add_index :article_versions, [:item_type, :item_id]
add_index :article_versions, :updated_by_id
add_index :article_versions, :created_at
```

**Important**: Use `item_type` and `item_id` (NOT `trackable_type`/`trackable_id` or `whodunnit`)

## Configuration

### Basic Configuration

Enable Traceable and specify tracked fields:

```ruby
class Article < ApplicationRecord
  include BetterModel

  traceable do
    track :status, :title, :content, :published_at, :featured
  end
end
```

### Sensitive Data Protection

Protect sensitive information in version history using three redaction levels:

#### Level 1: Full Redaction (`:full`)

Complete redaction - all values replaced with `"[REDACTED]"`:

```ruby
class User < ApplicationRecord
  traceable do
    track :email, :name
    track :password_digest, sensitive: :full
    track :two_factor_secret, sensitive: :full
  end
end

# Stored as: {"password_digest" => ["[REDACTED]", "[REDACTED]"]}
```

**Use for**: Passwords, encryption keys, security secrets

#### Level 2: Partial Redaction (`:partial`)

Pattern-based masking showing partial data:

```ruby
class User < ApplicationRecord
  traceable do
    track :credit_card, sensitive: :partial   # "4532123456789012" → "****9012"
    track :ssn, sensitive: :partial           # "123456789" → "***-**-6789"
    track :email, sensitive: :partial         # "user@example.com" → "u***@example.com"
    track :phone, sensitive: :partial         # "5551234567" → "***-***-4567"
  end
end
```

**Supported patterns**:
- Credit cards: Shows last 4 digits
- SSN: Shows last 4 digits with formatting
- Email: Shows first character + domain
- Phone: Shows last 4 digits with formatting
- Unknown: Shows character count

**Use for**: Credit cards, SSN, phone numbers, partial PII

#### Level 3: Hash Redaction (`:hash`)

SHA256 cryptographic hashing:

```ruby
class User < ApplicationRecord
  traceable do
    track :api_token, sensitive: :hash
    track :session_id, sensitive: :hash
  end
end

# Stored as: "sha256:a1b2c3d4..."
```

**Benefits**:
- Verify if value changed without seeing actual value
- Deterministic (same input = same hash)
- One-way (cannot recover original)

**Use for**: API tokens, session IDs, verification codes

### Custom Table Names

Override the default table naming:

```ruby
class Article < ApplicationRecord
  traceable do
    versions_table :article_audit_trail  # Custom name
    track :status, :title
  end
end

# Or use a shared table across models
class BlogPost < ApplicationRecord
  traceable do
    versions_table :better_model_versions  # Shared table
    track :content, :published
  end
end
```

### Configuration Introspection

Check sensitive field configuration:

```ruby
User.traceable_sensitive_fields
# => {password_digest: :full, ssn: :partial, api_token: :hash}

User.traceable_enabled?
# => true
```

## Instance Methods

### versions

Returns all versions for the record (newest first):

```ruby
article = Article.find(1)
article.versions
# => [#<ArticleVersion>, #<ArticleVersion>, ...]

article.versions.count
# => 5

# Access specific version
version = article.versions.first
version.event          # => "updated"
version.created_at     # => 2025-01-15 14:30:00
version.updated_by_id  # => 123
version.updated_reason # => "Fixed typo"
version.object_changes # => {"title" => ["Old", "New"]}
```

### changes_for(field)

Get change history for a specific field:

```ruby
article.changes_for(:status)
# => [
#   {
#     before: "draft",
#     after: "published",
#     at: 2025-01-15 14:30:00,
#     by: 123,
#     reason: "Ready for publication"
#   },
#   {
#     before: nil,
#     after: "draft",
#     at: 2025-01-15 10:00:00,
#     by: 123,
#     reason: "Initial draft"
#   }
# ]

# Check if field was ever changed
article.changes_for(:featured).any?
# => true
```

### audit_trail

Get formatted complete history:

```ruby
article.audit_trail
# => [
#   {
#     event: "updated",
#     changes: {"status" => ["draft", "published"], "title" => ["Old", "New"]},
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

# Group by date for timeline view
article.audit_trail.group_by { |entry| entry[:at].to_date }
```

### as_of(timestamp)

Time travel - reconstruct object state at any point in history:

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
puts "Status changed from '#{past_article.status}' to '#{article.status}'"
```

**How it works**:
1. Finds all versions created before the timestamp
2. Starts with blank object
3. Applies changes chronologically
4. Returns readonly object

**Limitations**:
- Only tracked fields are reconstructed
- Associations not loaded (only foreign keys)
- Object is readonly (use `rollback_to` to restore)

### rollback_to(version, **options)

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

# Rollback by version ID
article.rollback_to(
  42,  # version ID
  updated_by_id: current_user.id,
  updated_reason: "Restored previous state"
)

# Rollback with validation (skipped by default)
article.rollback_to(
  version,
  updated_by_id: current_user.id,
  validate: true  # Run validations
)
```

**Options**:
- `updated_by_id` (required if field exists): User performing rollback
- `updated_reason` (optional): Why rolling back
- `allow_sensitive` (default: false): Include sensitive fields (not recommended)
- `validate` (default: false): Run validations before save

**Behavior**:
- Applies "before" values from specified version
- Creates new version to record rollback
- Skips validations by default
- Callbacks still triggered
- Sensitive fields skipped by default (safety)

**Rollback with Sensitive Fields**:

```ruby
user = User.create!(
  email: "user@example.com",
  password_digest: "secret123"  # tracked with sensitive: :full
)

user.update!(email: "new@example.com", password_digest: "newsecret")

# Default behavior: sensitive fields NOT rolled back
user.rollback_to(user.versions.first, updated_by_id: admin.id)
user.email          # => "user@example.com" (rolled back)
user.password_digest # => "newsecret" (NOT rolled back - sensitive)

# With allow_sensitive: will set to redacted value
user.rollback_to(user.versions.first,
  updated_by_id: admin.id,
  allow_sensitive: true
)
user.password_digest # => "[REDACTED]" (from stored version)
```

**Security Note**: Since sensitive fields are redacted in storage, rolling back with `allow_sensitive: true` will set the field to the redacted value (e.g., `"[REDACTED]"`), not the original value.

### as_json(include_audit_trail: true)

Include audit trail in JSON responses:

```ruby
article.as_json(include_audit_trail: true)
# => {
#   "id" => 1,
#   "title" => "Hello World",
#   "status" => "published",
#   "audit_trail" => [
#     {
#       "event" => "updated",
#       "changes" => {"status" => ["draft", "published"]},
#       "at" => "2025-01-15T14:30:00Z",
#       "by" => 123,
#       "reason" => "Ready for publication"
#     },
#     {
#       "event" => "created",
#       "changes" => {"title" => [nil, "Hello World"]},
#       "at" => "2025-01-15T10:00:00Z",
#       "by" => 123,
#       "reason" => "Initial draft"
#     }
#   ]
# }
```

## Class Methods & Query Scopes

### changed_by(user_id)

Find all records modified by a specific user:

```ruby
# Articles changed by user 123
Article.changed_by(123)

# With additional filters
Article.changed_by(current_user.id).where(status: "published")

# Count changes by user
Article.changed_by(current_user.id).count

# Find articles modified by admin team
admin_ids = User.where(role: "admin").pluck(:id)
Article.changed_by(admin_ids)
```

### changed_between(start_time, end_time)

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

# Changed today
Article.changed_between(Time.current.beginning_of_day, Time.current)
```

### field_changed(field)

Query builder for field-specific changes:

```ruby
# Find all articles where title changed
Article.field_changed(:title)

# Find articles where status changed to published
Article.field_changed(:status).where("object_changes->>'status' LIKE '%published%'")
```

### {field}_changed_from(value).to(value)

Dynamic methods for field transitions:

```ruby
# For each tracked field, Traceable generates dynamic methods:
traceable do
  track :status, :title, :priority
end

# Generated methods:
Article.status_changed_from("draft").to("published")
Article.title_changed_from(nil).to("Hello World")
Article.priority_changed_from(1).to(5)

# Find status transitions
Article.status_changed_from("draft").to("published")
# => [#<Article id: 1>, #<Article id: 5>, ...]

# Find any title changes from nil (initial creation)
Article.title_changed_from(nil).to("Hello")

# Combine with other scopes
Article.status_changed_from("draft").to("published")
       .changed_by(current_user.id)
       .changed_between(1.week.ago, Time.current)
```

## Table Naming Strategies

### Per-Model Tables (Default)

Each model gets its own versions table:

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

**Pros**:
- Clear separation per model
- Easier to partition/archive
- Independent schema evolution

**Cons**:
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

**Pros**:
- Single audit trail across models
- Centralized change history
- Cross-model queries easier

**Cons**:
- Large table growth
- Requires good indexing strategy

### Custom Table Names

Domain-specific naming:

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

## Real-World Examples

### Example 1: Content Management System - Article Versioning

Track article changes with full editorial history:

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  belongs_to :author, class_name: "User"

  traceable do
    track :title, :content, :status, :published_at, :featured, :excerpt
  end

  # Automatically set updated_by_id from current user
  before_save :set_updated_by

  private

  def set_updated_by
    self.updated_by_id = Current.user&.id if Current.user
  end
end

# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  def update
    if @article.update(article_params.merge(
      updated_by_id: current_user.id,
      updated_reason: params[:change_reason] || "Updated article"
    ))
      redirect_to @article, notice: "Article updated successfully"
    else
      render :edit
    end
  end

  def audit_log
    @changes = @article.audit_trail.group_by { |change| change[:at].to_date }
  end

  def revert
    version = @article.versions.find(params[:version_id])

    if @article.rollback_to(version,
      updated_by_id: current_user.id,
      updated_reason: "Reverted to version from #{version.created_at}"
    )
      redirect_to @article, notice: "Article reverted successfully"
    else
      redirect_to article_audit_log_path(@article), alert: "Revert failed"
    end
  end
end

# app/views/articles/audit_log.html.erb
<h2>Audit Log for "<%= @article.title %>"</h2>

<% @changes.each do |date, day_changes| %>
  <div class="audit-day">
    <h3><%= date.strftime("%B %d, %Y") %></h3>

    <% day_changes.each do |change| %>
      <div class="audit-entry">
        <div class="audit-header">
          <%= change[:event].titleize %> by <%= User.find(change[:by]).name %>
          at <%= change[:at].strftime("%I:%M %p") %>
        </div>

        <% if change[:reason].present? %>
          <div class="audit-reason"><%= change[:reason] %></div>
        <% end %>

        <div class="audit-changes">
          <% change[:changes].each do |field, (old_val, new_val)| %>
            <div class="field-change">
              <strong><%= field.titleize %>:</strong>
              <span class="old-value"><%= old_val || "(empty)" %></span>
              →
              <span class="new-value"><%= new_val %></span>
            </div>
          <% end %>
        </div>

        <%= link_to "Revert to this version",
                    revert_article_path(@article, version_id: change[:version_id]),
                    method: :post,
                    data: { confirm: "Revert to this version?" },
                    class: "btn btn-secondary" %>
      </div>
    <% end %>
  </div>
<% end %>

# Usage Example:
article = Article.create!(
  title: "Introduction to Rails",
  content: "Rails is a web framework...",
  status: "draft",
  author: current_user,
  updated_by_id: current_user.id,
  updated_reason: "Initial draft"
)

article.update!(
  status: "published",
  published_at: Time.current,
  updated_by_id: current_user.id,
  updated_reason: "Ready for publication"
)

# View complete history
article.audit_trail
# View title changes only
article.changes_for(:title)
```

### Example 2: E-commerce Order Tracking

Track order status and modifications with admin oversight:

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  belongs_to :customer, class_name: "User"

  traceable do
    versions_table :order_audit_trail
    track :status, :shipping_address, :total_amount, :payment_status, :notes
  end

  # Track status transitions
  def self.shipped_today
    changed_between(Time.current.beginning_of_day, Time.current.end_of_day)
      .status_changed_from("processing").to("shipped")
  end

  # Find orders modified by admin team
  def self.admin_modifications
    admin_ids = User.where(role: "admin").pluck(:id)
    changed_by(admin_ids)
  end

  # Find suspicious price changes
  def self.price_changes_over(amount)
    field_changed(:total_amount)
      .joins(:versions)
      .where("(object_changes->>'total_amount')::jsonb->1 > ?", amount)
  end
end

# app/services/order_processor.rb
class OrderProcessor
  def ship_order(order, tracking_number:, user:)
    order.update!(
      status: "shipped",
      tracking_number: tracking_number,
      shipped_at: Time.current,
      updated_by_id: user.id,
      updated_reason: "Order shipped with tracking #{tracking_number}"
    )

    # Send notification
    OrderMailer.shipped(order).deliver_later
  end

  def cancel_order(order, reason:, user:)
    order.update!(
      status: "cancelled",
      cancelled_at: Time.current,
      updated_by_id: user.id,
      updated_reason: reason
    )

    # Log for audit
    Rails.logger.info "[AUDIT] Order ##{order.id} cancelled by #{user.email}: #{reason}"
  end
end

# app/controllers/admin/orders_controller.rb
class Admin::OrdersController < AdminController
  def modify
    @order = Order.find(params[:id])

    if @order.update(order_params.merge(
      updated_by_id: current_admin.id,
      updated_reason: params[:modification_reason]
    ))
      flash[:notice] = "Order modified. Change logged to audit trail."
      redirect_to admin_order_path(@order)
    else
      render :edit
    end
  end

  def audit_report
    @orders = Order.admin_modifications
                   .changed_between(params[:start_date], params[:end_date])
                   .includes(:customer, :versions)
  end
end

# Usage:
order = Order.create!(
  customer: user,
  total_amount: 99.99,
  status: "pending",
  updated_by_id: user.id,
  updated_reason: "Order placed"
)

# Find all orders shipped today
Order.shipped_today.each do |order|
  puts "Order ##{order.id} shipped at #{order.shipped_at}"
end

# Audit admin changes
Order.admin_modifications.each do |order|
  puts "Order ##{order.id} modified by admin"
  order.audit_trail.each do |change|
    puts "  #{change[:at]}: #{change[:reason]}"
  end
end
```

### Example 3: Document Approval Workflow

Track document lifecycle with approval/rejection history:

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  belongs_to :author, class_name: "User"

  traceable do
    track :status, :approved_at, :rejected_at, :approval_notes, :content_hash
  end

  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update

  def approve!(by:, notes: nil)
    update!(
      status: "approved",
      approved_at: Time.current,
      rejection_reason: nil,
      updated_by_id: by.id,
      updated_reason: notes || "Document approved"
    )
  end

  def reject!(by:, reason:)
    raise ArgumentError, "Rejection reason required" if reason.blank?

    update!(
      status: "rejected",
      rejected_at: Time.current,
      updated_by_id: by.id,
      updated_reason: reason
    )
  end

  def resubmit!(by:, changes_summary:)
    update!(
      status: "pending_review",
      rejected_at: nil,
      updated_by_id: by.id,
      updated_reason: "Resubmitted: #{changes_summary}"
    )
  end

  # View approval/rejection history
  def approval_history
    changes_for(:status).select do |change|
      ["approved", "rejected"].include?(change[:after])
    end
  end

  # Check if ever approved
  def was_ever_approved?
    versions.exists?("object_changes->>'status' LIKE '%approved%'")
  end

  # Get approval timeline
  def approval_timeline
    audit_trail.select { |entry| entry[:changes].key?("status") }
  end
end

# app/services/document_approval_service.rb
class DocumentApprovalService
  def initialize(document)
    @document = document
  end

  def approve(approver:, notes: nil)
    ActiveRecord::Base.transaction do
      @document.approve!(by: approver, notes: notes)

      # Notify author
      DocumentMailer.approved(@document, approver).deliver_later

      # Log for compliance
      AuditLog.create!(
        action: "document_approved",
        document_id: @document.id,
        user_id: approver.id,
        details: { notes: notes }
      )
    end
  end

  def reject(rejector:, reason:)
    ActiveRecord::Base.transaction do
      @document.reject!(by: rejector, reason: reason)

      # Notify author
      DocumentMailer.rejected(@document, rejector, reason).deliver_later
    end
  end
end

# app/views/documents/audit.html.erb
<h2>Approval History</h2>

<div class="timeline">
  <% @document.approval_timeline.each do |entry| %>
    <div class="timeline-entry <%= entry[:changes]['status']&.last %>">
      <div class="timestamp"><%= entry[:at].strftime("%B %d, %Y at %I:%M %p") %></div>
      <div class="user">by <%= User.find(entry[:by]).name %></div>
      <div class="status-change">
        Status: <%= entry[:changes]['status'].first %> →
        <strong><%= entry[:changes]['status'].last %></strong>
      </div>
      <% if entry[:reason].present? %>
        <div class="reason"><%= entry[:reason] %></div>
      <% end %>
    </div>
  <% end %>
</div>

# Usage:
document = Document.create!(
  title: "Q4 Financial Report",
  content: "...",
  author: employee,
  status: "pending_review",
  updated_by_id: employee.id,
  updated_reason: "Submitted for approval"
)

# Approve
service = DocumentApprovalService.new(document)
service.approve(
  approver: manager,
  notes: "All figures verified. Approved for publication."
)

# Later reject revision
document.reject!(
  by: manager,
  reason: "Contains outdated Q3 comparisons. Please update."
)

# Author resubmits
document.resubmit!(
  by: employee,
  changes_summary: "Updated Q3 comparison data as requested"
)

# View full approval history
document.approval_history.each do |change|
  puts "#{change[:at]}: #{change[:before]} → #{change[:after]}"
  puts "By: #{User.find(change[:by]).name}"
  puts "Reason: #{change[:reason]}"
end
```

### Example 4: User Account Management with Sensitive Data

Track user changes while protecting sensitive information:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  traceable do
    track :email, :name, :role, :status
    track :password_digest, sensitive: :full       # Completely redacted
    track :ssn, sensitive: :partial                # Shows last 4 digits
    track :api_token, sensitive: :hash             # SHA256 hash
    track :two_factor_secret, sensitive: :full     # Completely redacted
  end

  # Audit security-related changes
  def security_change_log
    changes_for(:password_digest)
      .concat(changes_for(:two_factor_secret))
      .sort_by { |change| change[:at] }
      .reverse
  end

  # Check if password was changed recently
  def password_changed_recently?(days = 90)
    changes_for(:password_digest)
      .any? { |change| change[:at] > days.days.ago }
  end

  # Detect role escalations
  def role_escalations
    changes_for(:role).select do |change|
      escalation?(change[:before], change[:after])
    end
  end

  private

  def escalation?(old_role, new_role)
    role_hierarchy = { "user" => 0, "moderator" => 1, "admin" => 2 }
    role_hierarchy[new_role] > role_hierarchy[old_role]
  end
end

# app/services/user_management_service.rb
class UserManagementService
  def change_role(user, new_role:, changed_by:, reason:)
    old_role = user.role

    user.update!(
      role: new_role,
      updated_by_id: changed_by.id,
      updated_reason: "Role changed: #{reason}"
    )

    # Alert if privilege escalation
    if escalation?(old_role, new_role)
      SecurityMailer.privilege_escalation(
        user: user,
        changed_by: changed_by,
        reason: reason
      ).deliver_later
    end
  end

  def reset_password(user, new_password:, reset_by:)
    user.update!(
      password: new_password,
      updated_by_id: reset_by.id,
      updated_reason: "Password reset by admin"
    )

    # Log security event
    SecurityLog.create!(
      event: "password_reset",
      user_id: user.id,
      admin_id: reset_by.id
    )
  end

  private

  def escalation?(old_role, new_role)
    role_hierarchy = { "user" => 0, "moderator" => 1, "admin" => 2 }
    role_hierarchy[new_role] > role_hierarchy[old_role]
  end
end

# app/controllers/admin/users_controller.rb
class Admin::UsersController < AdminController
  def audit
    @user = User.find(params[:id])
    @audit_trail = @user.audit_trail
    @security_changes = @user.security_change_log
  end

  def role_escalation_report
    @escalations = User.all.flat_map(&:role_escalations)
                       .sort_by { |e| e[:at] }
                       .reverse
  end
end

# Usage:
user = User.create!(
  email: "john@example.com",
  name: "John Doe",
  password: "secure_password",
  ssn: "123456789",
  role: "user",
  updated_by_id: admin.id,
  updated_reason: "Account created"
)

# Change role (tracked)
service = UserManagementService.new
service.change_role(
  user,
  new_role: "admin",
  changed_by: super_admin,
  reason: "Promoted to admin role for project management"
)

# Reset password (tracked but redacted)
service.reset_password(
  user,
  new_password: "new_secure_password",
  reset_by: admin
)

# Check version storage (sensitive fields protected)
version = user.versions.last
version.object_changes
# => {
#   "password_digest" => ["[REDACTED]", "[REDACTED]"],
#   "role" => ["user", "admin"]
# }

# View role escalations
user.role_escalations.each do |escalation|
  puts "#{escalation[:at]}: #{escalation[:before]} → #{escalation[:after]}"
  puts "By: #{User.find(escalation[:by]).name}"
  puts "Reason: #{escalation[:reason]}"
end

# Check if password changed recently (security audit)
user.password_changed_recently?(90)  # => true/false
```

### Example 5: Compliance & Regulatory (Healthcare/Finance)

Mandatory audit trails for regulated industries:

```ruby
# app/models/medical_record.rb
class MedicalRecord < ApplicationRecord
  belongs_to :patient
  belongs_to :provider, class_name: "User"

  traceable do
    versions_table :medical_audit_trail
    track :diagnosis, :treatment_plan, :medications, :notes, :status
  end

  # Required for compliance: all changes must have user and reason
  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update

  # Export audit trail for compliance reporting
  def compliance_report
    {
      record_id: id,
      patient_id: patient_id,
      patient_name: patient.full_name,
      provider_id: provider_id,
      created_at: created_at.iso8601,
      changes: versions.map do |v|
        {
          timestamp: v.created_at.iso8601,
          user_id: v.updated_by_id,
          user_name: User.find(v.updated_by_id).full_name,
          event: v.event,
          reason: v.updated_reason,
          changes: v.object_changes
        }
      end
    }
  end

  # HIPAA audit log format
  def hipaa_audit_log
    versions.map do |v|
      {
        date_time: v.created_at.iso8601,
        user_id: v.updated_by_id,
        action: v.event.upcase,
        resource: "MedicalRecord##{id}",
        patient_id: patient_id,
        reason: v.updated_reason,
        changes: v.object_changes.keys.join(", ")
      }
    end
  end
end

# app/services/compliance_reporter.rb
class ComplianceReporter
  def generate_audit_report(start_date:, end_date:)
    records = MedicalRecord.changed_between(start_date, end_date)

    {
      report_generated_at: Time.current.iso8601,
      period: {
        start: start_date.iso8601,
        end: end_date.iso8601
      },
      total_records_modified: records.count,
      records: records.map(&:compliance_report)
    }
  end

  def user_access_log(user_id:, start_date:, end_date:)
    MedicalRecord.changed_by(user_id)
                 .changed_between(start_date, end_date)
                 .includes(:patient, :versions)
                 .flat_map(&:hipaa_audit_log)
  end
end

# app/controllers/medical_records_controller.rb
class MedicalRecordsController < ApplicationController
  before_action :require_compliance_approval, only: [:update, :destroy]

  def update
    @record = MedicalRecord.find(params[:id])

    # Compliance: reason is mandatory
    unless params[:update_reason].present?
      return render json: { error: "Update reason required for compliance" },
                    status: :unprocessable_entity
    end

    if @record.update(
      medical_record_params.merge(
        updated_by_id: current_user.id,
        updated_reason: params[:update_reason]
      )
    )
      # Log to compliance system
      ComplianceLog.log_change(@record, current_user)

      render json: @record
    else
      render json: { errors: @record.errors }, status: :unprocessable_entity
    end
  end

  def audit_trail
    @record = MedicalRecord.find(params[:id])
    authorize_audit_access!(@record)

    render json: @record.compliance_report
  end
end

# Scheduled compliance job
# app/jobs/weekly_compliance_report_job.rb
class WeeklyComplianceReportJob < ApplicationJob
  queue_as :compliance

  def perform
    reporter = ComplianceReporter.new
    report = reporter.generate_audit_report(
      start_date: 1.week.ago,
      end_date: Time.current
    )

    # Send to compliance officer
    ComplianceMailer.weekly_report(report).deliver_now

    # Archive report
    ComplianceArchive.create!(
      period_start: 1.week.ago,
      period_end: Time.current,
      data: report.to_json
    )
  end
end

# Usage:
record = MedicalRecord.create!(
  patient: patient,
  provider: doctor,
  diagnosis: "Type 2 Diabetes",
  treatment_plan: "Metformin 500mg twice daily",
  updated_by_id: doctor.id,
  updated_reason: "Initial diagnosis"
)

record.update!(
  treatment_plan: "Metformin 1000mg twice daily",
  updated_by_id: doctor.id,
  updated_reason: "Increased dosage due to elevated A1C levels"
)

# Generate compliance report
report = record.compliance_report
# => {
#   record_id: 123,
#   patient_id: 456,
#   changes: [
#     {
#       timestamp: "2025-01-15T10:30:00Z",
#       user_id: 789,
#       user_name: "Dr. Smith",
#       reason: "Increased dosage due to elevated A1C levels",
#       changes: {"treatment_plan" => ["Metformin 500mg...", "Metformin 1000mg..."]}
#     }
#   ]
# }

# Generate user activity log (HIPAA compliance)
reporter = ComplianceReporter.new
activity_log = reporter.user_access_log(
  user_id: doctor.id,
  start_date: 1.month.ago,
  end_date: Time.current
)
```

### Example 6: Multi-Tenant SaaS Configuration Management

Track configuration changes across tenants:

```ruby
# app/models/tenant_config.rb
class TenantConfig < ApplicationRecord
  belongs_to :tenant

  traceable do
    versions_table :config_audit_trail
    track :api_enabled, :webhook_url, :rate_limit, :features, :subscription_tier
  end

  # Find config changes by admin
  def self.admin_changes_for_tenant(tenant_id)
    admin_ids = User.where(tenant_id: tenant_id, role: "admin").pluck(:id)
    where(tenant_id: tenant_id).changed_by(admin_ids)
  end

  # Detect feature toggle changes
  def self.feature_toggles_changed(feature_name)
    field_changed(:features)
      .joins(:versions)
      .where("object_changes->'features' IS NOT NULL")
  end
end

# app/services/config_rollback_service.rb
class ConfigRollbackService
  def initialize(config)
    @config = config
  end

  def rollback_to_previous
    previous_version = @config.versions.where(event: "updated").second

    return false unless previous_version

    @config.rollback_to(
      previous_version,
      updated_by_id: Current.user.id,
      updated_reason: "Rolled back due to reported issues"
    )

    # Notify admins
    AdminMailer.config_rolled_back(@config, previous_version).deliver_later

    true
  end

  def compare_versions(version_id_1, version_id_2)
    v1 = @config.versions.find(version_id_1)
    v2 = @config.versions.find(version_id_2)

    {
      version_1: { timestamp: v1.created_at, changes: v1.object_changes },
      version_2: { timestamp: v2.created_at, changes: v2.object_changes },
      diff: calculate_diff(v1, v2)
    }
  end

  private

  def calculate_diff(v1, v2)
    # Implementation to show differences between versions
  end
end

# app/controllers/admin/tenant_configs_controller.rb
class Admin::TenantConfigsController < AdminController
  def update
    @config = TenantConfig.find(params[:id])

    if @config.update(
      config_params.merge(
        updated_by_id: current_admin.id,
        updated_reason: params[:change_reason] || "Configuration updated"
      )
    )
      flash[:notice] = "Configuration updated. Change logged."
      redirect_to admin_tenant_config_path(@config)
    else
      render :edit
    end
  end

  def history
    @config = TenantConfig.find(params[:id])
    @changes = @config.audit_trail.group_by { |c| c[:at].to_date }
  end

  def rollback
    @config = TenantConfig.find(params[:id])
    service = ConfigRollbackService.new(@config)

    if service.rollback_to_previous
      flash[:notice] = "Configuration rolled back successfully"
    else
      flash[:alert] = "No previous version to rollback to"
    end

    redirect_to admin_tenant_config_path(@config)
  end
end

# Usage:
config = TenantConfig.find_by(tenant: current_tenant)

config.update!(
  api_enabled: true,
  webhook_url: "https://app.example.com/webhooks",
  rate_limit: 1000,
  updated_by_id: admin.id,
  updated_reason: "Enabled API access for integration"
)

# Later, toggle feature
config.update!(
  features: config.features.merge(advanced_reporting: true),
  updated_by_id: admin.id,
  updated_reason: "Enabled advanced reporting for premium tier"
)

# Problem occurs, rollback
service = ConfigRollbackService.new(config)
service.rollback_to_previous

# View all admin changes for this tenant
TenantConfig.admin_changes_for_tenant(current_tenant.id).each do |config|
  puts "Config #{config.id} changed:"
  config.audit_trail.each do |change|
    puts "  #{change[:at]}: #{change[:reason]}"
  end
end
```

### Example 7: Inventory Management

Track product changes and inventory adjustments:

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  traceable do
    track :price, :quantity, :location, :status, :supplier_id
  end

  # Find products with price changes over threshold
  def self.significant_price_changes(threshold_percent)
    field_changed(:price)
      .joins(:versions)
      .select do |product|
        product.changes_for(:price).any? do |change|
          old_price = change[:before].to_f
          new_price = change[:after].to_f
          percent_change = ((new_price - old_price) / old_price * 100).abs
          percent_change > threshold_percent
        end
      end
  end

  # Track inventory adjustments
  def inventory_adjustments
    changes_for(:quantity).map do |change|
      diff = change[:after].to_i - change[:before].to_i
      {
        date: change[:at],
        adjusted_by: change[:by],
        reason: change[:reason],
        change: diff,
        direction: diff > 0 ? "increase" : "decrease"
      }
    end
  end
end

# app/services/inventory_adjuster.rb
class InventoryAdjuster
  def adjust(product:, new_quantity:, adjusted_by:, reason:)
    old_quantity = product.quantity

    product.update!(
      quantity: new_quantity,
      updated_by_id: adjusted_by.id,
      updated_reason: "#{reason} (#{old_quantity} → #{new_quantity})"
    )

    # Alert if significant decrease
    decrease = old_quantity - new_quantity
    if decrease > 50
      InventoryMailer.significant_decrease(product, decrease, adjusted_by).deliver_later
    end
  end

  def bulk_adjust(adjustments, adjusted_by:)
    ActiveRecord::Base.transaction do
      adjustments.each do |adj|
        adjust(
          product: adj[:product],
          new_quantity: adj[:new_quantity],
          adjusted_by: adjusted_by,
          reason: adj[:reason]
        )
      end
    end
  end
end

# app/controllers/inventory_controller.rb
class InventoryController < ApplicationController
  def adjust
    @product = Product.find(params[:id])
    adjuster = InventoryAdjuster.new

    adjuster.adjust(
      product: @product,
      new_quantity: params[:new_quantity].to_i,
      adjusted_by: current_user,
      reason: params[:adjustment_reason]
    )

    redirect_to product_path(@product), notice: "Inventory adjusted"
  end

  def audit_report
    @date_range = params[:start_date]..params[:end_date]
    @products = Product.changed_between(@date_range.begin, @date_range.end)
    @adjustments = @products.flat_map(&:inventory_adjustments)
                            .select { |adj| @date_range.cover?(adj[:date]) }
                            .sort_by { |adj| adj[:date] }
                            .reverse
  end
end

# Usage:
product = Product.find(123)

adjuster = InventoryAdjuster.new
adjuster.adjust(
  product: product,
  new_quantity: 75,
  adjusted_by: warehouse_manager,
  reason: "Stock count adjustment after physical audit"
)

# View adjustment history
product.inventory_adjustments.each do |adj|
  puts "#{adj[:date]}: #{adj[:direction]} of #{adj[:change].abs} units"
  puts "Reason: #{adj[:reason]}"
  puts "By: #{User.find(adj[:adjusted_by]).name}"
end

# Find products with significant price changes
Product.significant_price_changes(10).each do |product|
  puts "#{product.name}: Price changed significantly"
  product.changes_for(:price).each do |change|
    puts "  #{change[:before]} → #{change[:after]}"
  end
end
```

### Example 8: Financial Transaction Auditing

Track financial transactions with mandatory audit trail:

```ruby
# app/models/transaction.rb
class Transaction < ApplicationRecord
  belongs_to :account

  traceable do
    versions_table :financial_audit_trail
    track :amount, :status, :approval_status, :notes, :processed_at
    track :account_number, sensitive: :hash  # Hash for verification
  end

  # Compliance: all changes require user and reason
  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update

  # Find transactions modified after processing
  def self.post_processing_modifications
    field_changed(:amount)
      .where("processed_at IS NOT NULL")
      .joins(:versions)
      .where("financial_audit_trail.created_at > transactions.processed_at")
  end

  # Approval history
  def approval_history
    changes_for(:approval_status).map do |change|
      {
        timestamp: change[:at],
        approver: User.find(change[:by]),
        from_status: change[:before],
        to_status: change[:after],
        reason: change[:reason]
      }
    end
  end
end

# app/services/transaction_processor.rb
class TransactionProcessor
  def approve(transaction, approved_by:, notes: nil)
    raise "Already processed" if transaction.processed_at.present?

    ActiveRecord::Base.transaction do
      transaction.update!(
        approval_status: "approved",
        status: "processing",
        updated_by_id: approved_by.id,
        updated_reason: notes || "Transaction approved"
      )

      # Process transaction
      process_transaction(transaction)

      transaction.update!(
        status: "completed",
        processed_at: Time.current,
        updated_by_id: approved_by.id,
        updated_reason: "Transaction processed successfully"
      )
    end

    # Log for audit
    FinancialAuditLog.create!(
      event: "transaction_approved_and_processed",
      transaction_id: transaction.id,
      user_id: approved_by.id,
      details: { notes: notes }
    )
  end

  def reverse(transaction, reversed_by:, reason:)
    raise ArgumentError, "Reversal reason required" if reason.blank?
    raise "Cannot reverse unapproved transaction" unless transaction.approval_status == "approved"

    ActiveRecord::Base.transaction do
      # Create reversal transaction
      reversal = Transaction.create!(
        account: transaction.account,
        amount: -transaction.amount,
        status: "completed",
        approval_status: "approved",
        processed_at: Time.current,
        updated_by_id: reversed_by.id,
        updated_reason: "Reversal of transaction ##{transaction.id}: #{reason}"
      )

      # Update original transaction
      transaction.update!(
        status: "reversed",
        reversed_at: Time.current,
        reversal_transaction_id: reversal.id,
        updated_by_id: reversed_by.id,
        updated_reason: reason
      )
    end
  end

  private

  def process_transaction(transaction)
    # Implementation for transaction processing
  end
end

# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  def approve
    @transaction = Transaction.find(params[:id])
    authorize_approval!(@transaction)

    processor = TransactionProcessor.new
    processor.approve(
      @transaction,
      approved_by: current_user,
      notes: params[:approval_notes]
    )

    redirect_to transaction_path(@transaction), notice: "Transaction approved and processed"
  rescue => e
    redirect_to transaction_path(@transaction), alert: "Failed to approve: #{e.message}"
  end

  def audit_log
    @transaction = Transaction.find(params[:id])
    authorize_audit_access!(@transaction)

    render json: {
      transaction_id: @transaction.id,
      account_id: @transaction.account_id,
      amount: @transaction.amount,
      audit_trail: @transaction.audit_trail
    }
  end
end

# Compliance reporting
# app/services/financial_audit_reporter.rb
class FinancialAuditReporter
  def generate_report(start_date:, end_date:)
    {
      report_date: Time.current.iso8601,
      period: { start: start_date.iso8601, end: end_date.iso8601 },
      post_processing_modifications: post_processing_report(start_date, end_date),
      all_modifications: all_modifications_report(start_date, end_date)
    }
  end

  private

  def post_processing_report(start_date, end_date)
    Transaction.post_processing_modifications
               .changed_between(start_date, end_date)
               .map do |txn|
      {
        transaction_id: txn.id,
        modified_at: txn.versions.last.created_at,
        modified_by: txn.versions.last.updated_by_id,
        reason: txn.versions.last.updated_reason,
        changes: txn.versions.last.object_changes
      }
    end
  end

  def all_modifications_report(start_date, end_date)
    Transaction.changed_between(start_date, end_date)
               .flat_map(&:audit_trail)
  end
end

# Usage:
transaction = Transaction.create!(
  account: account,
  amount: 1000.00,
  status: "pending",
  approval_status: "pending",
  updated_by_id: system_user.id,
  updated_reason: "Transaction initiated"
)

# Approve and process
processor = TransactionProcessor.new
processor.approve(
  transaction,
  approved_by: approver,
  notes: "Verified and approved for processing"
)

# View approval history
transaction.approval_history.each do |approval|
  puts "#{approval[:timestamp]}: #{approval[:from_status]} → #{approval[:to_status]}"
  puts "Approved by: #{approval[:approver].name}"
  puts "Reason: #{approval[:reason]}"
end

# Generate audit report
reporter = FinancialAuditReporter.new
report = reporter.generate_report(
  start_date: 1.month.ago,
  end_date: Time.current
)
```

### Example 9: HR Employee Records

Track employee data changes with sensitive field protection:

```ruby
# app/models/employee.rb
class Employee < ApplicationRecord
  traceable do
    track :name, :email, :department, :position, :status
    track :salary, sensitive: :hash          # Verify changes without exposing amount
    track :ssn, sensitive: :partial          # Show last 4 digits
    track :bank_account, sensitive: :full    # Completely redacted
  end

  # Compliance: all changes need approval
  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update

  # Find salary adjustments
  def salary_history
    changes_for(:salary).map do |change|
      {
        date: change[:at],
        adjusted_by: User.find(change[:by]),
        reason: change[:reason],
        # Note: actual values are hashed
        hash_before: change[:before],
        hash_after: change[:after]
      }
    end
  end

  # Department transfer history
  def transfer_history
    changes_for(:department).map do |change|
      {
        date: change[:at],
        from_dept: change[:before],
        to_dept: change[:after],
        authorized_by: User.find(change[:by]),
        reason: change[:reason]
      }
    end
  end

  # Promotion history
  def promotion_history
    changes_for(:position).select do |change|
      is_promotion?(change[:before], change[:after])
    end
  end

  private

  def is_promotion?(old_pos, new_pos)
    # Implementation to detect promotions
  end
end

# app/services/hr_change_service.rb
class HrChangeService
  def adjust_salary(employee:, new_salary:, adjusted_by:, reason:)
    raise ArgumentError, "Reason required for salary adjustment" if reason.blank?
    raise "Unauthorized" unless adjusted_by.has_role?(:hr_manager)

    employee.update!(
      salary: new_salary,
      updated_by_id: adjusted_by.id,
      updated_reason: "Salary adjustment: #{reason}"
    )

    # Notify payroll
    PayrollMailer.salary_changed(employee, adjusted_by).deliver_later

    # Log for audit
    HrAuditLog.create!(
      event: "salary_adjustment",
      employee_id: employee.id,
      hr_user_id: adjusted_by.id,
      reason: reason
    )
  end

  def transfer_department(employee:, new_department:, transferred_by:, effective_date:, reason:)
    employee.update!(
      department: new_department,
      transfer_effective_date: effective_date,
      updated_by_id: transferred_by.id,
      updated_reason: "Department transfer: #{reason}"
    )

    # Notify relevant parties
    DepartmentMailer.transfer_notification(employee, new_department).deliver_later
  end

  def promote(employee:, new_position:, promoted_by:, effective_date:, salary_increase: nil)
    ActiveRecord::Base.transaction do
      updates = {
        position: new_position,
        promotion_date: effective_date,
        updated_by_id: promoted_by.id,
        updated_reason: "Promotion to #{new_position}"
      }

      if salary_increase
        updates[:salary] = employee.salary + salary_increase
      end

      employee.update!(updates)

      # Create promotion record
      Promotion.create!(
        employee: employee,
        from_position: employee.position_was,
        to_position: new_position,
        promoted_by: promoted_by,
        effective_date: effective_date
      )
    end
  end
end

# app/controllers/hr/employees_controller.rb
class Hr::EmployeesController < HrController
  def update
    @employee = Employee.find(params[:id])

    if @employee.update(
      employee_params.merge(
        updated_by_id: current_hr_user.id,
        updated_reason: params[:change_reason]
      )
    )
      redirect_to hr_employee_path(@employee), notice: "Employee record updated"
    else
      render :edit
    end
  end

  def history
    @employee = Employee.find(params[:id])
    authorize_hr_access!(@employee)

    @audit_trail = @employee.audit_trail
    @salary_history = @employee.salary_history
    @transfer_history = @employee.transfer_history
  end
end

# Usage:
employee = Employee.create!(
  name: "Jane Doe",
  email: "jane@company.com",
  department: "Engineering",
  position: "Senior Developer",
  salary: 95000,
  ssn: "123456789",
  updated_by_id: hr_admin.id,
  updated_reason: "New hire"
)

# Adjust salary
service = HrChangeService.new
service.adjust_salary(
  employee: employee,
  new_salary: 105000,
  adjusted_by: hr_manager,
  reason: "Annual performance review - exceeds expectations"
)

# View salary history (values are hashed)
employee.salary_history.each do |adjustment|
  puts "#{adjustment[:date]}: Salary adjusted"
  puts "By: #{adjustment[:adjusted_by].name}"
  puts "Reason: #{adjustment[:reason]}"
  # Note: actual values are hashed for privacy
  puts "Hash changed: #{adjustment[:hash_before] != adjustment[:hash_after]}"
end

# Transfer department
service.transfer_department(
  employee: employee,
  new_department: "Engineering Leadership",
  transferred_by: hr_director,
  effective_date: 1.month.from_now,
  reason: "Promoted to Engineering Manager"
)

# View transfer history
employee.transfer_history.each do |transfer|
  puts "#{transfer[:date]}: #{transfer[:from_dept]} → #{transfer[:to_dept]}"
  puts "Authorized by: #{transfer[:authorized_by].name}"
  puts "Reason: #{transfer[:reason]}"
end
```

### Example 10: Feature Flag Management

Track feature flag changes for debugging and rollback:

```ruby
# app/models/feature_flag.rb
class FeatureFlag < ApplicationRecord
  traceable do
    track :enabled, :rollout_percentage, :enabled_for_users, :enabled_for_tenants
  end

  # Find flags toggled during incident
  def self.toggled_during(time_range)
    field_changed(:enabled)
      .changed_between(time_range.begin, time_range.end)
  end

  # Rollout history
  def rollout_history
    changes_for(:rollout_percentage).map do |change|
      {
        date: change[:at],
        from_pct: change[:before],
        to_pct: change[:after],
        toggled_by: User.find(change[:by]),
        reason: change[:reason]
      }
    end
  end

  # Check if flag was enabled during time
  def enabled_at?(timestamp)
    state = as_of(timestamp)
    state.enabled
  end
end

# app/services/feature_flag_service.rb
class FeatureFlagService
  def toggle(flag, enabled:, toggled_by:, reason:)
    old_state = flag.enabled

    flag.update!(
      enabled: enabled,
      updated_by_id: toggled_by.id,
      updated_reason: reason
    )

    # Alert team if critical flag
    if flag.critical? && old_state != enabled
      SlackNotifier.feature_flag_toggled(flag, old_state, enabled, toggled_by)
    end

    # Log for debugging
    Rails.logger.info "[FEATURE_FLAG] #{flag.key}: #{old_state} → #{enabled} by #{toggled_by.email}"
  end

  def gradual_rollout(flag, target_percentage:, rolled_out_by:)
    steps = [10, 25, 50, 75, 100]
    current_pct = flag.rollout_percentage

    next_step = steps.find { |s| s > current_pct && s <= target_percentage }
    return if next_step.nil?

    flag.update!(
      rollout_percentage: next_step,
      updated_by_id: rolled_out_by.id,
      updated_reason: "Gradual rollout to #{next_step}%"
    )

    # Schedule next step if not at target
    if next_step < target_percentage
      GradualRolloutJob.set(wait: 1.hour).perform_later(flag.id, target_percentage, rolled_out_by.id)
    end
  end

  def emergency_rollback(flag, rolled_back_by:, incident_id:)
    # Find last "safe" state (before incident)
    incident = Incident.find(incident_id)
    safe_version = flag.versions.where("created_at < ?", incident.started_at).last

    return false unless safe_version

    flag.rollback_to(
      safe_version,
      updated_by_id: rolled_back_by.id,
      updated_reason: "Emergency rollback due to incident ##{incident_id}"
    )

    # Alert team
    SlackNotifier.emergency_rollback(flag, incident, rolled_back_by)

    true
  end
end

# app/controllers/admin/feature_flags_controller.rb
class Admin::FeatureFlagsController < AdminController
  def toggle
    @flag = FeatureFlag.find(params[:id])
    service = FeatureFlagService.new

    service.toggle(
      @flag,
      enabled: params[:enabled],
      toggled_by: current_admin,
      reason: params[:reason] || "Manual toggle"
    )

    redirect_to admin_feature_flag_path(@flag), notice: "Feature flag updated"
  end

  def rollback
    @flag = FeatureFlag.find(params[:id])
    version = @flag.versions.find(params[:version_id])

    @flag.rollback_to(
      version,
      updated_by_id: current_admin.id,
      updated_reason: "Manual rollback to #{version.created_at}"
    )

    redirect_to admin_feature_flag_path(@flag), notice: "Feature flag rolled back"
  end

  def incident_report
    incident = Incident.find(params[:incident_id])
    time_range = (incident.started_at - 1.hour)..(incident.ended_at + 1.hour)

    @flags_toggled = FeatureFlag.toggled_during(time_range)
    @timeline = @flags_toggled.flat_map(&:audit_trail)
                              .select { |e| time_range.cover?(e[:at]) }
                              .sort_by { |e| e[:at] }
  end
end

# Usage:
flag = FeatureFlag.create!(
  key: "new_checkout_flow",
  enabled: false,
  rollout_percentage: 0,
  updated_by_id: developer.id,
  updated_reason: "Initial flag setup"
)

# Enable for testing
service = FeatureFlagService.new
service.toggle(
  flag,
  enabled: true,
  toggled_by: developer,
  reason: "Enable for QA testing"
)

# Gradual rollout
service.gradual_rollout(
  flag,
  target_percentage: 100,
  rolled_out_by: product_manager
)

# View rollout history
flag.rollout_history.each do |step|
  puts "#{step[:date]}: #{step[:from_pct]}% → #{step[:to_pct]}%"
  puts "By: #{step[:toggled_by].name}"
  puts "Reason: #{step[:reason]}"
end

# Incident occurs - emergency rollback
service.emergency_rollback(
  flag,
  rolled_back_by: on_call_engineer,
  incident_id: incident.id
)

# Post-incident analysis
time_range = (incident.started_at - 1.hour)..(incident.ended_at + 1.hour)
flags_during_incident = FeatureFlag.toggled_during(time_range)

flags_during_incident.each do |flag|
  puts "Flag #{flag.key} was toggled during incident:"
  flag.audit_trail
      .select { |e| time_range.cover?(e[:at]) }
      .each do |change|
    puts "  #{change[:at]}: #{change[:changes]}"
    puts "  By: #{User.find(change[:by]).name}"
    puts "  Reason: #{change[:reason]}"
  end
end
```

## Controller Integration

### Using Current.user Pattern

Automatically set `updated_by_id`:

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_current_user

  private

  def set_current_user
    Current.user = current_user
  end
end

# app/models/article.rb
class Article < ApplicationRecord
  traceable do
    track :title, :content, :status
  end

  before_save :set_updated_by

  private

  def set_updated_by
    self.updated_by_id = Current.user&.id if Current.user
  end
end

# Now all updates automatically track user:
article.update!(status: "published")
# Creates version with updated_by_id = Current.user.id
```

### Strong Parameters with Metadata

```ruby
class ArticlesController < ApplicationController
  def update
    if @article.update(article_params_with_metadata)
      redirect_to @article, notice: "Article updated"
    else
      render :edit
    end
  end

  private

  def article_params_with_metadata
    params.require(:article)
          .permit(:title, :content, :status)
          .merge(
            updated_by_id: current_user.id,
            updated_reason: params[:change_reason] || "Article updated"
          )
  end
end
```

## Best Practices

### ✅ Do

1. **Track Meaningful Fields Only**
   ```ruby
   # Good - track business-critical data
   track :status, :price, :approval_status

   # Bad - don't track everything
   track :view_count, :last_viewed_at, :cached_slug
   ```

2. **Always Include User Attribution**
   ```ruby
   # Add to migration
   t.bigint :updated_by_id

   # Add to model
   before_save :set_updated_by
   ```

3. **Provide Change Reasons**
   ```ruby
   article.update!(
     status: "published",
     updated_by_id: current_user.id,
     updated_reason: "Approved after editorial review"
   )
   ```

4. **Index Properly**
   ```ruby
   add_index :article_versions, [:item_type, :item_id]
   add_index :article_versions, :updated_by_id
   add_index :article_versions, :created_at

   # PostgreSQL: GIN index for JSONB
   add_index :article_versions, :object_changes, using: :gin
   ```

5. **Plan for Data Volume**
   ```ruby
   # Archive old versions periodically
   class ArchiveOldVersionsJob < ApplicationJob
     def perform
       cutoff = 2.years.ago
       ArticleVersion.where("created_at < ?", cutoff)
                     .find_in_batches { |batch| archive(batch) }
     end
   end
   ```

6. **Test Time Travel**
   ```ruby
   test "time travel reconstructs correct state" do
     article = Article.create!(title: "V1", status: "draft")
     timestamp = Time.current
     article.update!(title: "V2", status: "published")

     past = article.as_of(timestamp)
     assert_equal "V1", past.title
     assert_equal "draft", past.status
   end
   ```

7. **Use Transactions for Rollback**
   ```ruby
   ActiveRecord::Base.transaction do
     article.rollback_to(version, updated_by_id: user.id)
     # Other related updates
   end
   ```

8. **Document Tracked Fields**
   ```ruby
   # In model or README
   # Tracked fields: status, title, content, published_at
   # Sensitive fields: None
   # Retention policy: 2 years
   ```

### ❌ Don't

1. **Don't Track Sensitive Data Without Protection**
   ```ruby
   # Bad
   track :password_digest

   # Good
   track :password_digest, sensitive: :full
   ```

2. **Don't Track Computed Fields**
   ```ruby
   # Bad - derived from other fields
   track :full_name  # computed from first_name + last_name

   # Good - track source data
   track :first_name, :last_name
   ```

3. **Don't Version Large Binary Data**
   ```ruby
   # Bad - huge version table
   track :avatar_blob

   # Good - track reference only
   track :avatar_blob_id
   ```

4. **Don't Ignore Performance**
   ```ruby
   # Bad - N+1 queries
   articles.each { |a| puts a.versions.count }

   # Good - eager load
   articles.includes(:versions).each { |a| puts a.versions.count }
   ```

5. **Don't Skip Indexes**
   ```ruby
   # Will cause slow queries on large tables
   # Always add recommended indexes
   ```

6. **Don't Forget Retention Policies**
   ```ruby
   # Versions table grows indefinitely without cleanup
   # Implement archival/deletion strategy
   ```

7. **Don't Mix Table Strategies**
   ```ruby
   # Bad - inconsistent approach
   # Some models use shared table, others use per-model

   # Good - choose one strategy project-wide
   ```

## Database-Specific Behavior

### PostgreSQL

Use `jsonb` for better performance and querying:

```ruby
create_table :article_versions do |t|
  t.jsonb :object_changes  # Use jsonb not json
end

# Add GIN index
add_index :article_versions, :object_changes, using: :gin

# Query JSON fields
Article.changed_by(123)
       .joins(:versions)
       .where("object_changes->>'status' = ?", "published")
```

**Advantages**:
- Indexable with GIN indexes
- Better query performance
- Compression support
- Binary storage

### MySQL

Use `json` type (5.7+):

```ruby
create_table :article_versions do |t|
  t.json :object_changes
end

# Query JSON fields
Article.joins(:versions)
       .where("JSON_EXTRACT(object_changes, '$.status') = ?", "published")
```

**Considerations**:
- Good performance with proper indexes
- `max_allowed_packet` setting for large changes
- Consider archive strategy

### SQLite

Stores JSON as text:

```ruby
create_table :article_versions do |t|
  t.text :object_changes  # JSON stored as text
end
```

**Limitations**:
- Limited JSON query capabilities
- Text storage (no binary compression)
- Consider periodic archival

## Thread Safety

**Guaranteed thread-safe**:
- Configuration frozen at class load time
- Immutable `traceable_config` hash
- Version class registry uses mutex
- Safe for concurrent requests

## Performance Considerations

### Indexing Strategy

```ruby
# Essential indexes (required)
add_index :versions, [:item_type, :item_id]
add_index :versions, :created_at

# User tracking (if using updated_by_id)
add_index :versions, :updated_by_id

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

# Select only needed fields
article.versions.select(:id, :event, :created_at, :updated_by_id)

# Use count cache
has_many :versions, counter_cache: true
```

### Data Volume Management

```ruby
# Archive old versions
class ArchiveOldVersions
  def call
    cutoff = 2.years.ago

    ArticleVersion.where("created_at < ?", cutoff)
                  .find_in_batches(batch_size: 1000) do |batch|
      # Move to archive or S3
      archive_versions(batch)
      batch.each(&:destroy)
    end
  end
end

# Delete empty changes
class CleanupEmptyVersions < ApplicationJob
  def perform
    Version.where("created_at < ?", 1.year.ago)
           .where(event: "updated")
           .where("object_changes = '{}'::jsonb")
           .delete_all
  end
end
```

**Recommendations**:
- Monitor version table size
- Implement retention policies
- Archive old versions to separate storage
- Consider partitioning for very large tables (PostgreSQL)

## Key Takeaways

1. **Opt-In**: Traceable is NOT active by default - must explicitly enable with `traceable do...end`

2. **Explicit Tracking**: Only specified fields are tracked - untracked fields don't create versions

3. **Correct Schema**: Use `item_type`/`item_id` (NOT `trackable_type`/`trackable_id`), `updated_by_id` (NOT `whodunnit`), `object_changes` (NOT `changes`)

4. **Sensitive Data Protection**: Three levels - `:full` (redacted), `:partial` (masked), `:hash` (SHA256)

5. **User Attribution**: Always track who made changes with `updated_by_id`

6. **Change Context**: Use `updated_reason` to explain why changes were made

7. **Time Travel**: Reconstruct object state at any point with `as_of(timestamp)`

8. **Rollback Safety**: Sensitive fields skipped by default, use `allow_sensitive: true` carefully

9. **Rich Query API**: `changed_by`, `changed_between`, `field_changed_from().to()` for powerful queries

10. **Table Strategies**: Choose per-model, shared, or custom tables based on needs

11. **Database Optimization**: Use `jsonb` for PostgreSQL, add GIN indexes, plan for growth

12. **Compliance Ready**: Perfect for HIPAA, GDPR, SOX with mandatory user/reason tracking

13. **Performance**: Index properly, eager load versions, implement retention policies

14. **Thread Safe**: Immutable configuration, safe for concurrent requests

15. **Integration**: Works seamlessly with Archivable, Stateable, Statusable

16. **Testing**: Always test time travel and rollback functionality

17. **Documentation**: Document tracked fields, sensitive settings, retention policies

18. **Monitoring**: Track version table growth, query performance, and storage usage
