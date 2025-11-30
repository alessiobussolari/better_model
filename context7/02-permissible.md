# 2. Permissible - Instance-Level Permission Management

**BetterModel v3.0.0+**: Define permissions as properties of model instances based on their state.

## Overview

Permissible provides instance-level permission management where permissions are computed on-demand based on record state, rather than user-to-resource mappings.

**Key features**:
- Define permissions with lambda conditions
- Auto-generated predicate methods (`permit_action?`)
- Unified permission checking (`permit?(:action)`)
- Works alongside Statusable for powerful combinations
- No database migrations required

## Requirements

- Rails 8.0+
- Ruby 3.3+
- ActiveRecord 8.0+
- BetterModel ~> 3.0.0

## Installation

No migration required. Permissible is automatically available when you include BetterModel:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define permissions with the 'permit' method
  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" }
end
```

---

## Core Features

### Basic Permission Declaration

**Cosa fa**: Define a named permission with a boolean condition

**Quando usarlo**: To encode business rules about what actions are allowed on a record

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Simple attribute check
  permit :delete, -> { status != "published" }

  # Multiple conditions
  permit :edit, -> { status == "draft" || status == "scheduled" }

  # Date/time based
  permit :archive, -> { created_at < 1.year.ago }

  # Complex condition
  permit :publish, -> {
    status == "draft" &&
    title.present? &&
    content.present?
  }
end

article = Article.create(status: "draft", title: "Test", content: "...")

article.permit_delete?   # => true
article.permit_publish?  # => true

article.update!(status: "published")
article.permit_delete?   # => false (can't delete published)
```

---

### Block Syntax Alternative

**Cosa fa**: Use Ruby block syntax instead of lambda for permission definitions

**Quando usarlo**: When you prefer block syntax or have multi-line conditions

**Esempio**:

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Lambda syntax
  permit :cancel, -> { status == "pending" }

  # Block syntax (equivalent)
  permit :refund do
    payment_status == "paid" &&
    shipped_at.nil? &&
    created_at >= 30.days.ago
  end

  # Can mix both styles
  permit :ship, -> { payment_status == "paid" }
  permit :track do
    shipped_at.present? && tracking_number.present?
  end
end

order = Order.find(1)
order.permit_refund?  # => true/false
order.permit_track?   # => true/false
```

---

### Predicate Methods

**Cosa fa**: Auto-generated methods for each permission following `permit_action?` pattern

**Quando usarlo**: For readable, IDE-friendly permission checks

**Esempio**:

```ruby
class Document < ApplicationRecord
  include BetterModel

  permit :download, -> { status == "approved" }
  permit :share, -> { public_access == true }
  permit :delete, -> { created_by_id == Current.user&.id }
end

document = Document.find(1)

# Auto-generated predicate methods
document.permit_download?  # => true
document.permit_share?     # => false
document.permit_delete?    # => true

# Use in conditionals
if document.permit_download?
  send_file document.file_path
else
  render plain: "Access denied", status: :forbidden
end
```

---

### Unified Permission Check

**Cosa fa**: Check any permission using `permit?(:action)` method

**Quando usarlo**: When action name is dynamic or comes from user input

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  permit :edit, -> { status == "draft" }
  permit :delete, -> { status != "published" }
  permit :publish, -> { status == "draft" }
end

article = Article.find(1)

# Static check (same as predicate method)
article.permit?(:edit)  # => true

# Dynamic check (action name from parameter)
action = params[:action].to_sym
if article.permit?(action)
  perform_action(article, action)
else
  flash[:error] = "Action not permitted"
end

# Loop through actions
[:edit, :delete, :publish].each do |action|
  puts "#{action}: #{article.permit?(action)}"
end
```

---

### Get All Permissions

**Cosa fa**: Return hash of all permissions with their current boolean values

**Quando usarlo**: For debugging, API responses, or permission matrices

**Esempio**:

```ruby
class Order < ApplicationRecord
  include BetterModel

  permit :cancel, -> { status == "pending" }
  permit :ship, -> { payment_status == "paid" }
  permit :refund, -> { shipped_at.nil? }
  permit :track, -> { tracking_number.present? }
end

order = Order.find(1)

# Get all permissions as hash
order.permissions
# => {
#   cancel: true,
#   ship: true,
#   refund: true,
#   track: false
# }

# Use in API responses
def show
  render json: {
    order: @order,
    permissions: @order.permissions
  }
end

# Use for debugging
Rails.logger.info("Order #{order.id} permissions: #{order.permissions.inspect}")
```

---

### Check Any Permission Active

**Cosa fa**: Check if at least one defined permission is granted

**Quando usarlo**: To verify a record has any available actions

**Esempio**:

```ruby
class Document < ApplicationRecord
  include BetterModel

  permit :read, -> { public_access || owner_id == Current.user&.id }
  permit :edit, -> { owner_id == Current.user&.id }
  permit :delete, -> { owner_id == Current.user&.id }
end

document = Document.find(1)

# Check if ANY permission is granted
document.has_any_permission?  # => true/false

# Practical use
unless document.has_any_permission?
  render plain: "No actions available", status: :forbidden
end

# Show "no actions" message
def show
  @document = Document.find(params[:id])
  @has_actions = @document.has_any_permission?
end
```

---

### Check Multiple Permissions

**Cosa fa**: Verify that all specified permissions are granted

**Quando usarlo**: When multiple permissions must be satisfied simultaneously

**Esempio**:

```ruby
class Project < ApplicationRecord
  include BetterModel

  permit :read, -> { visibility == "public" || team_member?(Current.user) }
  permit :edit, -> { team_member?(Current.user) }
  permit :delete, -> { owner_id == Current.user&.id }
end

project = Project.find(1)

# Check if ALL specified permissions are granted
project.has_all_permissions?([:read, :edit])  # => true/false

# Practical use in controller
def update
  @project = Project.find(params[:id])

  unless @project.has_all_permissions?([:read, :edit])
    redirect_to root_path, alert: "Insufficient permissions"
    return
  end

  # Proceed with update...
end
```

---

### Filter Granted Permissions

**Cosa fa**: Return only the permissions that are currently granted from a list

**Quando usarlo**: To build action menus or permission matrices

**Esempio**:

```ruby
class Document < ApplicationRecord
  include BetterModel

  permit :read, -> { true }
  permit :edit, -> { owner_id == Current.user&.id }
  permit :delete, -> { owner_id == Current.user&.id && !archived? }
  permit :share, -> { can_share? }
  permit :archive, -> { owner_id == Current.user&.id }
end

document = Document.find(1)

# Get only granted permissions from list
actions = [:read, :edit, :delete, :share, :archive]
granted = document.granted_permissions(actions)
# => [:read, :edit, :archive]

# Build action menu in view
def action_menu
  all_actions = [:read, :edit, :delete, :share, :archive]
  available = @document.granted_permissions(all_actions)

  available.map { |action| link_to action.to_s.titleize, action_path(action) }
end
```

---

### Class-Level Permission Introspection

**Cosa fa**: Query which permissions are defined on a model class

**Quando usarlo**: For metaprogramming, validation, or building dynamic UIs

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  permit :edit, -> { status == "draft" }
  permit :delete, -> { status != "published" }
  permit :publish, -> { status == "draft" }
end

# Get all defined permission names
Article.defined_permissions
# => [:edit, :delete, :publish]

# Check if specific permission is defined
Article.permission_defined?(:edit)     # => true
Article.permission_defined?(:unknown)  # => false

# Validate action parameter
def perform_action(action_name)
  unless Article.permission_defined?(action_name.to_sym)
    raise "Invalid action: #{action_name}. " \
          "Available: #{Article.defined_permissions.join(', ')}"
  end

  # Proceed with action...
end

# Build UI dynamically
Article.defined_permissions.each do |permission|
  button_tag permission.to_s.titleize, disabled: !@article.permit?(permission)
end
```

---

### Referencing Statusable Statuses

**Cosa fa**: Use Statusable statuses in permission conditions

**Quando usarlo**: To combine state checking with permission logic (powerful pattern!)

**Esempio**:

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Define statuses
  is :paid, -> { payment_status == "paid" }
  is :shipped, -> { shipped_at.present? }
  is :delivered, -> { delivered_at.present? }

  # Define permissions using statuses
  permit :cancel, -> { !is?(:shipped) }
  permit :ship, -> { is?(:paid) && !is?(:shipped) }
  permit :refund, -> { is?(:paid) && !is?(:shipped) }
  permit :track, -> { is?(:shipped) && !is?(:delivered) }
  permit :review, -> { is?(:delivered) }
end

order = Order.find(1)

# Permissions automatically respect statuses
order.permit_cancel?  # => depends on shipped status
order.permit_review?  # => depends on delivered status

# Clean, readable permission logic
def can_user_cancel?(order)
  order.permit_cancel?  # Simple and clear!
end
```

---

## Advanced Usage

### Complex Business Logic

**Cosa fa**: Use permissions in controller authorization and business methods

**Quando usarlo**: To centralize business rules and keep controllers clean

**Esempio**:

```ruby
class Document < ApplicationRecord
  include BetterModel

  permit :edit, -> { owner_id == Current.user&.id || admin?(Current.user) }
  permit :delete, -> {
    owner_id == Current.user&.id &&
    created_at >= 24.hours.ago &&
    !has_dependencies?
  }
  permit :share, -> {
    (public_access || owner_id == Current.user&.id) &&
    !archived?
  }

  # Use permissions in instance methods
  def editable_by?(user)
    Current.user = user
    permit_edit?
  end

  def deletable?
    permit_delete?
  end

  private

  def admin?(user)
    user&.role == "admin"
  end

  def has_dependencies?
    comments_count > 0 || attachments_count > 0
  end
end

# Controller usage
class DocumentsController < ApplicationController
  def edit
    @document = Document.find(params[:id])

    unless @document.permit_edit?
      redirect_to @document, alert: "You cannot edit this document"
    end
  end

  def destroy
    @document = Document.find(params[:id])

    unless @document.permit_delete?
      redirect_to @document, alert: "Cannot delete this document"
      return
    end

    @document.destroy
    redirect_to documents_path, notice: "Document deleted"
  end
end
```

---

### User-Specific Permissions

**Cosa fa**: Define permissions that depend on current user context

**Quando usarlo**: When permissions vary by user role or ownership

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: "User"

  # Permissions referencing current user
  permit :edit, -> {
    author_id == Current.user&.id ||
    Current.user&.admin?
  }

  permit :delete, -> {
    (author_id == Current.user&.id && status == "draft") ||
    Current.user&.admin?
  }

  permit :publish, -> {
    author_id == Current.user&.id &&
    status == "draft" &&
    meets_publication_criteria?
  }

  permit :feature, -> {
    Current.user&.editor? || Current.user&.admin?
  }

  private

  def meets_publication_criteria?
    title.present? &&
    content.present? &&
    word_count >= 300
  end
end

# Set current user in controller
class ApplicationController < ActionController::Base
  before_action :set_current_user

  private

  def set_current_user
    Current.user = current_user
  end
end

# Permissions automatically respect current user
@article.permit_edit?     # true if owner or admin
@article.permit_feature?  # true if editor or admin
```

---

### Time-Based Permissions

**Cosa fa**: Define permissions that expire or activate based on time

**Quando usarlo**: For deadlines, event registrations, limited-time actions

**Esempio**:

```ruby
class EventRegistration < ApplicationRecord
  include BetterModel
  belongs_to :event

  # Time-based permissions
  permit :cancel, -> {
    event.starts_at > 24.hours.from_now
  }

  permit :modify, -> {
    event.starts_at > 48.hours.from_now &&
    !cancelled?
  }

  permit :check_in, -> {
    Time.current.between?(
      event.starts_at - 1.hour,
      event.ends_at
    )
  }

  permit :leave_review, -> {
    event.ends_at < Time.current &&
    event.ends_at >= 30.days.ago &&
    !review_submitted?
  }
end

registration = EventRegistration.find(1)

# Permissions automatically respect time windows
registration.permit_cancel?        # true if >24h before event
registration.permit_check_in?      # true during event window
registration.permit_leave_review?  # true for 30 days after event
```

---

### Permission Chains

**Cosa fa**: Build hierarchical permissions where one implies others

**Quando usarlo**: To model permission inheritance (e.g., delete implies edit)

**Esempio**:

```ruby
class Document < ApplicationRecord
  include BetterModel

  # Base permissions
  permit :read, -> { public_access || owner_id == Current.user&.id }

  # Edit implies read
  permit :edit, -> {
    permit?(:read) && owner_id == Current.user&.id
  }

  # Delete implies edit
  permit :delete, -> {
    permit?(:edit) && created_at >= 24.hours.ago
  }

  # Admin override
  permit :admin_delete, -> {
    permit?(:delete) || Current.user&.admin?
  }
end

# Clear permission hierarchy
document.permit_read?          # Most permissive
document.permit_edit?          # Requires read + ownership
document.permit_delete?        # Requires edit + time constraint
document.permit_admin_delete?  # Delete OR admin
```

---

## Best Practices

### Keep Conditions Simple

**Cosa fa**: Extract complex logic into private methods

**Quando usarlo**: When permission condition has multiple steps

**Esempio**:

```ruby
# ❌ BAD: Complex inline logic
class Document < ApplicationRecord
  include BetterModel

  permit :edit, -> {
    (owner_id == Current.user&.id || team_members.include?(Current.user)) &&
    !archived? &&
    (status == "draft" || status == "review") &&
    created_at >= 90.days.ago
  }
end

# ✅ GOOD: Extract to methods
class Document < ApplicationRecord
  include BetterModel

  permit :edit, -> { editable_by_user? }

  private

  def editable_by_user?
    has_edit_access? &&
    in_editable_state? &&
    within_edit_window?
  end

  def has_edit_access?
    owner_id == Current.user&.id ||
    team_members.include?(Current.user)
  end

  def in_editable_state?
    !archived? && ["draft", "review"].include?(status)
  end

  def within_edit_window?
    created_at >= 90.days.ago
  end
end
```

---

### Use Descriptive Names

**Cosa fa**: Choose clear, action-oriented permission names

**Quando usarlo**: Always

**Esempio**:

```ruby
# ✅ GOOD: Clear action names
permit :delete, -> { ... }
permit :publish, -> { ... }
permit :archive, -> { ... }
permit :share_publicly, -> { ... }
permit :assign_to_user, -> { ... }

# ❌ BAD: Vague or unclear
permit :action1, -> { ... }
permit :check, -> { ... }
permit :allowed, -> { ... }

# ✅ GOOD: Matches user intent
class Subscription < ApplicationRecord
  include BetterModel

  permit :cancel, -> { ... }
  permit :upgrade, -> { ... }
  permit :downgrade, -> { ... }
  permit :pause, -> { ... }
  permit :resume, -> { ... }
end

# ❌ BAD: Doesn't convey meaning
class Subscription < ApplicationRecord
  include BetterModel

  permit :action_a, -> { ... }
  permit :modify, -> { ... }
  permit :change, -> { ... }
end
```

---

### Combine with Statusable

**Cosa fa**: Use statuses in permission conditions for cleaner code

**Quando usarlo**: When permissions depend on computed states

**Esempio**:

```ruby
# ✅ GOOD: Leverage statuses
class Order < ApplicationRecord
  include BetterModel

  # Define statuses
  is :paid, -> { payment_status == "paid" }
  is :shipped, -> { shipped_at.present? }
  is :cancellable_window, -> { created_at >= 1.hour.ago }

  # Simple permissions using statuses
  permit :cancel, -> { is?(:cancellable_window) && !is?(:shipped) }
  permit :ship, -> { is?(:paid) && !is?(:shipped) }
  permit :refund, -> { is?(:paid) && !is?(:shipped) }
end

# ❌ BAD: Duplicate logic
class Order < ApplicationRecord
  include BetterModel

  permit :cancel, -> {
    created_at >= 1.hour.ago && shipped_at.nil?
  }

  permit :ship, -> {
    payment_status == "paid" && shipped_at.nil?
  }

  permit :refund, -> {
    payment_status == "paid" && shipped_at.nil?
  }
end
```

---

### Test Thoroughly

**Cosa fa**: Test permissions under different model states and users

**Quando usarlo**: Always

**Esempio**:

```ruby
# RSpec example
RSpec.describe Document, type: :model do
  describe "#permit_edit?" do
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    it "allows owner to edit" do
      Current.user = owner
      document = create(:document, owner: owner)

      expect(document.permit_edit?).to be true
    end

    it "denies non-owner" do
      Current.user = other_user
      document = create(:document, owner: owner)

      expect(document.permit_edit?).to be false
    end

    it "allows admin to edit any document" do
      admin = create(:user, role: "admin")
      Current.user = admin
      document = create(:document, owner: owner)

      expect(document.permit_edit?).to be true
    end
  end
end

# Minitest example
class DocumentTest < ActiveSupport::TestCase
  test "owner can delete draft within 24 hours" do
    user = users(:john)
    Current.user = user

    document = documents(:recent_draft)
    document.update!(owner: user, status: "draft")

    assert document.permit_delete?
  end

  test "cannot delete after 24 hours" do
    user = users(:john)
    Current.user = user

    document = documents(:old_draft)
    document.update!(owner: user, created_at: 25.hours.ago)

    refute document.permit_delete?
  end
end
```

---

### Document User Context Requirements

**Cosa fa**: Document which permissions require Current.user

**Quando usarlo**: When permissions reference Current.user

**Esempio**:

```ruby
class Document < ApplicationRecord
  include BetterModel

  # Permissions requiring Current.user to be set:
  # - edit: checks ownership against Current.user
  # - delete: checks ownership and admin role
  # - share: checks ownership
  #
  # Set Current.user in controller before_action:
  # before_action :set_current_user
  permit :edit, -> { owner_id == Current.user&.id }
  permit :delete, -> {
    owner_id == Current.user&.id || Current.user&.admin?
  }
  permit :share, -> {
    owner_id == Current.user&.id && !archived?
  }

  # Permissions NOT requiring Current.user:
  permit :view_public, -> { public_access == true }
  permit :search, -> { searchable == true }
end
```

---

## Integration Examples

### Controller Authorization

**Cosa fa**: Use permissions for request authorization in controllers

**Quando usarlo**: To protect controller actions based on record state

**Esempio**:

```ruby
class ArticlesController < ApplicationController
  def edit
    @article = Article.find(params[:id])

    unless @article.permit_edit?
      redirect_to @article, alert: "Cannot edit this article"
      return
    end

    # Render edit form
  end

  def destroy
    @article = Article.find(params[:id])

    unless @article.permit_delete?
      redirect_to @article, alert: "Cannot delete this article"
      return
    end

    @article.destroy
    redirect_to articles_path, notice: "Article deleted"
  end

  # Generic action handler
  def perform_action
    @article = Article.find(params[:id])
    action = params[:action_name].to_sym

    unless @article.permit?(action)
      render json: { error: "Action not permitted" }, status: :forbidden
      return
    end

    # Perform action...
  end
end
```

---

### View Helpers

**Cosa fa**: Conditionally render UI elements based on permissions

**Quando usarlo**: To show/hide buttons and links

**Esempio**:

```ruby
<!-- app/views/articles/show.html.erb -->
<h1><%= @article.title %></h1>

<div class="actions">
  <% if @article.permit_edit? %>
    <%= link_to "Edit", edit_article_path(@article), class: "btn" %>
  <% end %>

  <% if @article.permit_delete? %>
    <%= link_to "Delete", article_path(@article),
                method: :delete,
                data: { confirm: "Are you sure?" },
                class: "btn btn-danger" %>
  <% end %>

  <% if @article.permit_publish? %>
    <%= button_to "Publish", publish_article_path(@article), class: "btn btn-primary" %>
  <% end %>
end

<!-- Dynamic action menu -->
<div class="dropdown">
  <% available_actions = [:edit, :delete, :publish, :archive] %>
  <% granted = @article.granted_permissions(available_actions) %>

  <% granted.each do |action| %>
    <%= link_to action.to_s.titleize, send("#{action}_article_path", @article) %>
  <% end %>
</div>
```

---

### API Responses

**Cosa fa**: Include permission information in JSON API responses

**Quando usarlo**: For API clients that need to know available actions

**Esempio**:

```ruby
class Api::V1::ArticlesController < ApplicationController
  def show
    article = Article.find(params[:id])

    render json: {
      article: article.as_json(only: [:id, :title, :status]),
      permissions: article.permissions,
      # Or specific permissions
      can_edit: article.permit_edit?,
      can_delete: article.permit_delete?,
      can_publish: article.permit_publish?
    }
  end

  def bulk_permissions
    articles = Article.where(id: params[:ids])

    render json: articles.map { |article|
      {
        id: article.id,
        permissions: article.permissions
      }
    }
  end
end

# Example response:
# {
#   "article": { "id": 1, "title": "Rails 8", "status": "draft" },
#   "permissions": {
#     "edit": true,
#     "delete": true,
#     "publish": true,
#     "archive": false
#   }
# }
```

---

## Quick Reference

### Method Summary

```ruby
# Instance methods
article.permit_edit?                      # Generated predicate method
article.permit?(:edit)                    # Unified permission check
article.permissions                       # Hash of all permissions
article.has_any_permission?               # At least one granted
article.has_all_permissions?([:ed, :del]) # All specified granted
article.granted_permissions([:ed, :pub])  # Filter to granted

# Class methods
Article.defined_permissions               # Array of permission names
Article.permission_defined?(:edit)        # Check if permission exists
```

### Common Patterns

```ruby
# Simple attribute check
permit :delete, -> { status != "published" }

# User ownership
permit :edit, -> { owner_id == Current.user&.id }

# Time-based
permit :cancel, -> { starts_at > 24.hours.from_now }

# Using statuses
permit :publish, -> { is?(:draft) && is?(:complete) }

# With custom method
permit :archive, -> { archivable? }
```

---

## Error Handling

### Undefined Permission Checks

**Cosa fa**: Handle checks for non-existent permissions gracefully

**Quando usarlo**: When permission name comes from external source

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  permit :edit, -> { status == "draft" }
  permit :delete, -> { status != "published" }
end

article = Article.new

# Defined permission works
article.permit?(:edit)  # => true/false

# Undefined permission returns false (safe)
article.permit?(:unknown)  # => false (no error)

# Predicate method raises NoMethodError
article.permit_unknown?  # => NoMethodError

# Safe check with validation
def check_permission(action_name)
  return false unless Article.permission_defined?(action_name)
  article.permit?(action_name)
end

# Validate before checking
if Article.permission_defined?(params[:action].to_sym)
  allowed = @article.permit?(params[:action].to_sym)
else
  flash[:error] = "Invalid action"
end
```

---

**Last Updated**: 2025-11-11 (BetterModel v3.0.0)
