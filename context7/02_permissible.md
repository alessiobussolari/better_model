# BetterModel Permissible Feature Documentation

BetterModel Permissible is a flexible permission management system that provides declarative instance-level permission checking for ActiveRecord models through conditional logic evaluation. Unlike authorization libraries that focus on user-to-resource permissions (like Pundit or CanCanCan), Permissible defines permissions as properties of a model instance itself, determining what actions are currently allowed on that specific record based on its state, attributes, and relationships. When you include BetterModel in any ActiveRecord model, Permissible is automatically available alongside other core features (Statusable, Predicable, Sortable, and Searchable), requiring no additional configuration or database migrations. The system generates predicate methods for each defined permission (`permit_action?`), provides a unified method for checking any permission (`permit?(:action)`), offers helper methods for working with multiple permissions, and includes thread-safe permission registration.

Permissible excels at encoding business rules about what operations are valid for a record in its current state. For example, an Article can only be deleted if it's not published, an Order can be refunded if it's paid but not shipped, or an Event registration can be cancelled up to 24 hours before the event starts. These permissions automatically reflect the current state of your data and integrate seamlessly with controller authorization, view rendering, API responses, and business logic methods. The feature works beautifully in conjunction with Statusable, allowing permissions to reference statuses for cleaner, more maintainable code.

## Basic Concepts

Permissible usage pattern with the `permit` declaration method

Permissible uses the `permit` class method to declare named permissions with conditional logic blocks. Each permission definition consists of a symbolic action name and a Ruby lambda or proc that returns a boolean value when evaluated in the context of a model instance. The condition can reference any model attributes, associations, methods, or Statusable statuses. Once declared, each permission automatically generates a predicate method following the pattern `permit_action?` that evaluates the condition and returns true or false.

```ruby
# Basic permission declaration pattern
class Article < ApplicationRecord
  include BetterModel

  # Define permissions with the 'permit' method
  # Each permission has an action name and a condition block
  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" || status == "scheduled" }
  permit :publish, -> { status == "draft" && title.present? }
end

# The 'permit' method signature
# permit :action_name, -> { condition_that_returns_boolean }
#        ^symbolic_name  ^lambda/proc evaluated in instance context
```

```ruby
# Alternative block syntax (equivalent to lambda syntax)
class Article < ApplicationRecord
  include BetterModel

  # Using block syntax instead of lambda
  permit :delete do
    status != "published"
  end

  permit :edit do
    status == "draft" || status == "scheduled"
  end

  # Lambda and block syntax can be mixed
  permit :publish, -> { status == "draft" && title.present? }
  permit :archive do
    created_at < 1.year.ago
  end
end
```

```ruby
# Example: Setting up a basic model with permissions
class Article < ApplicationRecord
  include BetterModel

  # Simple attribute-based permissions
  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" || status == "scheduled" }

  # Permissions with multiple conditions
  permit :publish, -> { status == "draft" && title.present? && content.present? }

  # Date/time-based permissions
  permit :archive, -> { created_at < 1.year.ago }

  # Permissions referencing associations (when loaded)
  permit :add_comments, -> { comments_enabled && !archived_at.present? }
end

# Usage in application code
article = Article.create!(
  title: "Rails 8 Released",
  content: "Rails 8 brings amazing features...",
  status: "draft"
)

# All permission conditions are evaluated on-demand
article.permit_delete?    # => true (status != "published")
article.permit_edit?      # => true (status == "draft")
article.permit_publish?   # => true (draft with title and content)
article.permit_archive?   # => false (not old enough)

# Permissions update automatically when state changes
article.update!(status: "published")
article.permit_delete?    # => false (can't delete published articles)
article.permit_edit?      # => false (can't edit published articles)
```

## Checking Permissions

Dynamic permission evaluation with predicate methods and the unified `permit?` method

Permissible provides two ways to check if a permission is granted: generated predicate methods that follow the `permit_action?` pattern, and a unified `permit?(:action)` method that accepts a symbolic action name. Both approaches evaluate the permission condition in real-time against the current state of the model instance. The predicate methods provide convenient, IDE-friendly method calls with autocomplete support, while the `permit?` method enables dynamic permission checking when the action name is determined at runtime or stored in a variable.

```ruby
# Example model with various permissions
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" || status == "scheduled" }
  permit :publish, -> { status == "draft" && title.present? }
  permit :archive, -> { created_at < 1.year.ago }
end

article = Article.find(1)

# Method 1: Using generated predicate methods
# These methods are created automatically for each defined permission
article.permit_delete?    # => true/false
article.permit_edit?      # => true/false
article.permit_publish?   # => true/false
article.permit_archive?   # => true/false

# Method 2: Using the unified permit? method with a symbol
# Useful when action name is dynamic or stored in a variable
article.permit?(:delete)  # => true/false
article.permit?(:edit)    # => true/false
article.permit?(:publish) # => true/false

# Dynamic permission checking (runtime action name)
action_to_check = :delete
article.permit?(action_to_check)  # => true/false

# Checking permissions in conditionals
if article.permit_publish?
  article.update!(status: "published", published_at: Time.current)
  puts "Article published!"
elsif article.permit_edit?
  puts "Article can be edited"
else
  puts "No actions available"
end

# Using permissions in controller authorization
class ArticlesController < ApplicationController
  def destroy
    @article = Article.find(params[:id])

    unless @article.permit_delete?
      redirect_to @article, alert: "This article cannot be deleted"
      return
    end

    @article.destroy
    redirect_to articles_path, notice: "Article deleted"
  end

  def update
    @article = Article.find(params[:id])

    unless @article.permit_edit?
      redirect_to @article, alert: "This article cannot be edited"
      return
    end

    if @article.update(article_params)
      redirect_to @article, notice: "Article updated"
    else
      render :edit
    end
  end
end

# Using permissions in model methods for business logic
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :publish, -> { status == "draft" && valid?(:publication) }

  def destroy_if_allowed!
    raise "Cannot delete this article" unless permit_delete?
    destroy!
  end

  def publish_if_ready!
    raise "Article not ready for publication" unless permit_publish?
    update!(status: "published", published_at: Time.current)
  end
end
```

## Getting All Permissions

Retrieving permission snapshots with the `permissions` method

The `permissions` instance method returns a hash containing all defined permissions as keys with their current boolean values. This provides a complete snapshot of all permission conditions evaluated at a specific moment in time. The returned hash uses symbolic keys matching the permission action names and boolean values indicating whether each permission is currently granted. This method is particularly useful for debugging, logging, API responses, or when you need to check multiple permission conditions simultaneously without making individual method calls.

```ruby
# Example model with multiple permissions
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" || status == "scheduled" }
  permit :publish, -> { status == "draft" && title.present? }
  permit :archive, -> { created_at < 1.year.ago }
end

article = Article.find(1)

# Get a hash of all permissions with their current values
article.permissions
# Returns a hash like:
# {
#   delete: true,
#   edit: false,
#   publish: false,
#   archive: false
# }

# Useful for debugging and logging
Rails.logger.info "Article permissions: #{article.permissions.inspect}"

# Useful for conditional logic based on multiple permissions
perms = article.permissions
if perms[:publish] && perms[:edit]
  puts "Article is ready and editable"
elsif perms[:delete]
  puts "Article can be deleted"
end

# Example: Building an actions menu based on permissions
def available_actions(article)
  article.permissions.select { |action, granted| granted }.keys
end

available_actions(article)  # => [:delete, :edit] (only granted ones)
```

## Helper Methods

Utility methods for working with multiple permissions simultaneously

Permissible provides three helper methods that simplify common operations when working with multiple permissions: `has_any_permission?` checks if at least one defined permission is granted, `has_all_permissions?([:action1, :action2])` verifies that all specified permissions are granted, and `granted_permissions([:action1, :action2, :action3])` filters a list of permission names and returns only those that are currently granted. These methods eliminate the need for verbose boolean logic and make code more readable when dealing with multiple permission conditions.

```ruby
# Example model with multiple permissions
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" }
  permit :publish, -> { status == "draft" && valid? }
  permit :archive, -> { created_at < 1.year.ago }
end

article = Article.find(1)

# Check if ANY permission is granted
article.has_any_permission?
# Returns true if at least one permission condition evaluates to true
# Returns false only if ALL permissions are denied or no permissions are defined
# => true

# Check if ALL specified permissions are granted
article.has_all_permissions?([:edit, :delete])
# Returns true only if BOTH permit_edit? AND permit_delete? are true
# Returns false if any of the specified permissions is denied
# => true (if article is draft and not published)

# Alternative: checking a single required permission
article.has_all_permissions?([:publish])
# => true (if article is draft and valid)

# Get only the granted permissions from a list
article.granted_permissions([:delete, :edit, :publish, :archive])
# Filters the provided list and returns only permissions that are granted
# Example return value: [:delete, :edit]
# Note: This does NOT return permissions that weren't in the input list

# Practical example: Building an actions menu
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" }
  permit :publish, -> { status == "draft" && valid? }
  permit :archive, -> { created_at < 1.year.ago }

  def available_action_list
    all_possible_actions = [:delete, :edit, :publish, :archive]
    granted_permissions(all_possible_actions)
  end

  def can_perform_destructive_actions?
    has_any_permission?
  end

  def fully_accessible?
    # Check if all management actions are available
    has_all_permissions?([:delete, :edit, :publish])
  end
end

article = Article.create!(status: "draft", title: "Test", created_at: Time.current)
article.available_action_list          # => [:delete, :edit, :publish]
article.can_perform_destructive_actions?  # => true
article.fully_accessible?              # => true

# Example: Controller authorization with multiple permissions
class ArticlesController < ApplicationController
  def batch_actions
    @article = Article.find(params[:id])
    requested_actions = params[:actions] # [:delete, :archive]

    granted = @article.granted_permissions(requested_actions)

    if granted.size == requested_actions.size
      # All requested actions are permitted
      requested_actions.each { |action| perform_action(@article, action) }
    else
      denied = requested_actions - granted
      flash[:error] = "Actions denied: #{denied.join(', ')}"
    end
  end
end
```

## Class Methods

Model-level permission introspection and validation

Permissible provides class-level methods for introspecting defined permissions on a model: `defined_permissions` returns an array of all permission action names registered on the model class, and `permission_defined?(:action)` checks if a specific permission has been declared. These methods are useful for metaprogramming, runtime validation of permission names, building dynamic interfaces that adapt to available permissions, or writing generic code that works with any Permissible model.

```ruby
# Example model with defined permissions
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" }
  permit :publish, -> { status == "draft" && valid? }
  permit :archive, -> { created_at < 1.year.ago }
end

# Get all defined permission names
Article.defined_permissions
# Returns an array of symbolic permission names
# => [:delete, :edit, :publish, :archive]

# Check if a specific permission is defined
Article.permission_defined?(:delete)
# => true

Article.permission_defined?(:nonexistent)
# => false

# Practical example: Dynamic permission checking in a controller
class ArticlesController < ApplicationController
  def perform_action
    @article = Article.find(params[:id])
    action_name = params[:action_name].to_sym

    # Validate action exists
    unless Article.permission_defined?(action_name)
      render json: {
        error: "Unknown action: #{action_name}",
        available_actions: Article.defined_permissions
      }, status: :bad_request
      return
    end

    # Check if action is permitted
    if @article.permit?(action_name)
      execute_action(@article, action_name)
      render json: { success: true }
    else
      render json: { error: "Action not permitted" }, status: :forbidden
    end
  end
end

# Example: Building a generic permission checker utility
class PermissionChecker
  def self.check_model(model_class, action_name)
    unless model_class.respond_to?(:permission_defined?)
      return { error: "Model does not include Permissible" }
    end

    unless model_class.permission_defined?(action_name)
      return {
        error: "Permission '#{action_name}' not defined",
        available_permissions: model_class.defined_permissions
      }
    end

    {
      valid: true,
      action: action_name,
      defined_on: model_class.name
    }
  end
end

# Example: Metaprogramming with defined permissions
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" }
  permit :publish, -> { status == "draft" && valid? }

  # Dynamically create bang methods for each permission
  defined_permissions.each do |action|
    define_method("#{action}!") do
      raise "#{action} not permitted" unless permit?(action)
      # Perform the action...
      public_send("perform_#{action}")
    end
  end
end

# Now you can use: article.delete!, article.edit!, article.publish!
# Each will raise an error if the permission is not granted
```

## JSON Serialization

Including permission information in JSON API responses

Permissible models support an optional `include_permissions` parameter in the `as_json` method that, when set to true, adds a `permissions` key to the JSON output containing a hash of all permission names and their current boolean values. By default, permissions are not included in JSON serialization to avoid bloating API responses with computed values. This feature is particularly useful for API clients that need to render UI elements based on available actions, for debugging and development tools, or for admin interfaces that display comprehensive record state.

```ruby
# Example model with permissions
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" || status == "scheduled" }
  permit :publish, -> { status == "draft" && title.present? }
  permit :archive, -> { created_at < 1.year.ago }
end

article = Article.find(1)

# Default JSON serialization (without permissions)
article.as_json
# Returns standard attributes only:
# {
#   "id" => 1,
#   "title" => "Rails 8 Released",
#   "status" => "draft",
#   "created_at" => "2025-01-05T10:30:00.000Z",
#   ...
# }

# JSON serialization WITH permissions
article.as_json(include_permissions: true)
# Returns attributes plus computed permissions:
# {
#   "id" => 1,
#   "title" => "Rails 8 Released",
#   "status" => "draft",
#   "created_at" => "2025-01-05T10:30:00.000Z",
#   "permissions" => {
#     "delete" => true,
#     "edit" => true,
#     "publish" => true,
#     "archive" => false
#   }
# }

# Combining with Statusable serialization
# If your model also uses Statusable, you can include both
article.as_json(include_statuses: true, include_permissions: true)
# {
#   "id" => 1,
#   "title" => "Rails 8 Released",
#   "status" => "draft",
#   "statuses" => {
#     "draft" => true,
#     "published" => false,
#     "archived" => false
#   },
#   "permissions" => {
#     "delete" => true,
#     "edit" => true,
#     "publish" => true,
#     "archive" => false
#   }
# }

# Practical example: API controller with conditional permission inclusion
class Api::V1::ArticlesController < ApplicationController
  def show
    article = Article.find(params[:id])

    # Always include permissions for authenticated API clients
    render json: article.as_json(include_permissions: true)
  end

  def index
    articles = Article.published.limit(20)

    # Include permissions for UI rendering decisions
    render json: articles.map { |article|
      article.as_json(
        include_permissions: true,
        only: [:id, :title, :status, :created_at]
      )
    }
  end
end

# Example: Custom serializer with permission flags
class ArticleSerializer
  def initialize(article)
    @article = article
  end

  def as_json
    {
      id: @article.id,
      title: @article.title,
      content: @article.content,
      # Include specific permission flags for UI
      can_edit: @article.permit_edit?,
      can_delete: @article.permit_delete?,
      can_publish: @article.permit_publish?,
      # Optionally include all permissions
      all_permissions: @article.permissions
    }
  end
end

# Frontend can use permissions to show/hide UI elements
# JavaScript example:
# if (article.permissions.delete) {
#   showDeleteButton();
# }
# if (article.permissions.edit) {
#   enableEditMode();
# }
```

## Integration with Statusable

Combining permissions with statuses for powerful business logic

Permissible integrates seamlessly with Statusable, allowing permission conditions to reference statuses using the `is?(:status_name)` method. This integration enables clean separation of concerns: Statusable defines what states exist based on model data, while Permissible defines what actions are allowed in those states. By referencing statuses in permission conditions, you create more maintainable and readable code where business rules are clearly expressed and centralized.

```ruby
# Example: Combining Statusable and Permissible
class Article < ApplicationRecord
  include BetterModel

  # Define statuses (from Statusable)
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :scheduled, -> { status == "published" && published_at > Time.current }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :archived, -> { archived_at.present? }

  # Define permissions that reference statuses
  permit :delete, -> { is?(:draft) }  # Can only delete drafts
  permit :edit, -> { is?(:draft) || is?(:scheduled) }  # Can edit drafts and scheduled
  permit :publish, -> { is?(:draft) && title.present? && content.present? }
  permit :unpublish, -> { is?(:published) && !is?(:expired) }
  permit :archive, -> { is?(:published) && created_at < 1.year.ago }
  permit :restore, -> { is?(:archived) }
end

article = Article.find(1)

# Statuses and permissions work together
article.is_draft?         # => true (status check)
article.permit_delete?    # => true (uses status check internally)
article.permit_edit?      # => true (uses status check internally)

# Complex example with multiple statuses
class Order < ApplicationRecord
  include BetterModel

  # Define statuses
  is :pending_payment, -> { status == "pending" && payment_status == "unpaid" }
  is :paid, -> { payment_status == "paid" }
  is :processing, -> { status == "processing" && is?(:paid) }
  is :shipped, -> { status == "shipped" && shipped_at.present? }
  is :delivered, -> { status == "delivered" }
  is :cancelled, -> { cancelled_at.present? }

  # Define permissions based on statuses
  permit :cancel, -> {
    (is?(:pending_payment) || is?(:paid)) && !is?(:shipped) && !is?(:cancelled)
  }

  permit :refund, -> {
    is?(:paid) && !is?(:shipped) && !is?(:cancelled)
  }

  permit :ship, -> {
    is?(:paid) && !is?(:shipped) && !is?(:cancelled)
  }

  permit :mark_delivered, -> {
    is?(:shipped) && !is?(:delivered)
  }

  permit :reopen, -> {
    is?(:cancelled) && cancelled_at >= 24.hours.ago
  }

  # Business logic methods use both statuses and permissions
  def cancel_if_allowed!
    raise "Order cannot be cancelled" unless permit_cancel?

    transaction do
      update!(cancelled_at: Time.current)
      refund_payment if is?(:paid)
      notify_customer(:cancelled)
    end
  end

  def process_refund!
    raise "Refund not permitted" unless permit_refund?

    transaction do
      process_payment_refund
      update!(refund_processed_at: Time.current)
      notify_customer(:refunded)
    end
  end
end

# Real-world usage
order = Order.find(1)

# Check status
order.is_paid?           # => true

# Check permission (which internally uses status)
order.permit_cancel?     # => true (paid but not shipped)
order.permit_refund?     # => true (paid but not shipped)

# Execute action with permission check
order.cancel_if_allowed!  # Succeeds because permit_cancel? is true

# After cancellation
order.is_cancelled?      # => true
order.permit_cancel?     # => false (already cancelled)
order.permit_reopen?     # => true (recently cancelled)
```

## Real-World Examples

Production-ready permission implementations for common use cases

Real-world Permissible implementations demonstrate patterns for content management systems with publication workflows, e-commerce orders with state-based action restrictions, user account management with security policies, project management with lifecycle-based permissions, and event systems with time-based availability. These examples show how to combine simple attribute checks with Statusable integration, date comparisons, validation dependencies, and business rule enforcement.

### Content Management System

```ruby
class Post < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: "User"

  # Statuses
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :scheduled, -> { status == "scheduled" && publish_at > Time.current }
  is :archived, -> { archived_at.present? }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  # Permissions
  permit :edit, -> { is?(:draft) || is?(:scheduled) }
  permit :delete, -> { is?(:draft) && comments_count == 0 }
  permit :publish, -> { is?(:draft) && valid?(:publication) }
  permit :schedule, -> { is?(:draft) && publish_at.present? && publish_at > Time.current }
  permit :unpublish, -> { is?(:published) && !is?(:expired) }
  permit :archive, -> { is?(:published) && created_at < 6.months.ago }
  permit :restore, -> { is?(:archived) }
  permit :feature, -> { is?(:published) && !is?(:expired) && !featured? }

  # Business logic
  def publish_now!
    raise "Cannot publish" unless permit_publish?

    update!(
      status: "published",
      published_at: Time.current
    )
  end

  def schedule_publication!(publish_time)
    raise "Cannot schedule" unless permit_schedule?

    update!(
      status: "scheduled",
      publish_at: publish_time
    )
  end
end

# Usage in controller
class PostsController < ApplicationController
  def publish
    @post = Post.find(params[:id])

    unless @post.permit_publish?
      redirect_to @post, alert: "This post cannot be published"
      return
    end

    @post.publish_now!
    redirect_to @post, notice: "Post published successfully"
  end

  def destroy
    @post = Post.find(params[:id])

    unless @post.permit_delete?
      if @post.comments_count > 0
        redirect_to @post, alert: "Cannot delete posts with comments"
      else
        redirect_to @post, alert: "This post cannot be deleted"
      end
      return
    end

    @post.destroy
    redirect_to posts_path, notice: "Post deleted"
  end
end
```

### E-commerce Order Management

```ruby
class Order < ApplicationRecord
  include BetterModel
  belongs_to :customer, class_name: "User"
  has_many :line_items

  # Statuses
  is :pending, -> { status == "pending" && payment_status == "unpaid" }
  is :paid, -> { payment_status == "paid" }
  is :processing, -> { status == "processing" && is?(:paid) }
  is :shipped, -> { status == "shipped" && shipped_at.present? }
  is :delivered, -> { status == "delivered" && delivered_at.present? }
  is :cancelled, -> { cancelled_at.present? }
  is :refunded, -> { refunded_at.present? }

  # Permissions based on order lifecycle
  permit :cancel, -> {
    !is?(:cancelled) &&
    !is?(:shipped) &&
    !is?(:delivered) &&
    created_at >= 1.hour.ago
  }

  permit :refund, -> {
    is?(:paid) &&
    !is?(:refunded) &&
    !is?(:shipped) &&
    created_at >= 30.days.ago
  }

  permit :ship, -> {
    is?(:paid) &&
    !is?(:shipped) &&
    !is?(:cancelled) &&
    shipping_address.present?
  }

  permit :mark_delivered, -> {
    is?(:shipped) &&
    !is?(:delivered) &&
    tracking_number.present?
  }

  permit :modify_items, -> {
    is?(:pending) ||
    (is?(:paid) && !is?(:processing))
  }

  permit :change_shipping_address, -> {
    !is?(:shipped) &&
    !is?(:delivered) &&
    !is?(:cancelled)
  }

  permit :request_support, -> { !is?(:cancelled) }

  # Business methods
  def cancel_order!
    raise "Order cannot be cancelled" unless permit_cancel?

    transaction do
      update!(cancelled_at: Time.current, cancellation_reason: "customer_request")
      refund_payment if is?(:paid)
      release_inventory
      notify_customer(:order_cancelled)
    end
  end

  def process_refund!(reason:)
    raise "Refund not permitted" unless permit_refund?

    transaction do
      RefundProcessor.process(self, reason: reason)
      update!(refunded_at: Time.current, refund_reason: reason)
      notify_customer(:refund_processed)
    end
  end
end

# Usage in API controller
class Api::V1::OrdersController < ApplicationController
  def cancel
    order = current_user.orders.find(params[:id])

    unless order.permit_cancel?
      render json: {
        error: "This order cannot be cancelled",
        reason: determine_cancellation_restriction(order)
      }, status: :forbidden
      return
    end

    order.cancel_order!
    render json: order.as_json(include_permissions: true)
  end

  private

  def determine_cancellation_restriction(order)
    return "already_shipped" if order.is_shipped?
    return "already_delivered" if order.is_delivered?
    return "too_old" if order.created_at < 1.hour.ago
    "unknown"
  end
end
```

### User Account Management

```ruby
class User < ApplicationRecord
  include BetterModel

  # Statuses
  is :active, -> { !suspended_at && email_verified_at.present? }
  is :suspended, -> { suspended_at.present? }
  is :email_verified, -> { email_verified_at.present? }
  is :premium, -> {
    subscription_tier == "premium" &&
    subscription_expires_at.present? &&
    subscription_expires_at > Time.current
  }
  is :trial, -> { subscription_tier == "trial" && created_at >= 14.days.ago }
  is :deactivated, -> { deactivated_at.present? }

  # Account management permissions
  permit :login, -> {
    is?(:active) &&
    is?(:email_verified) &&
    !is?(:deactivated) &&
    !login_locked?
  }

  permit :change_email, -> {
    is?(:active) &&
    email_change_allowed_at.nil? ||
    email_change_allowed_at <= Time.current
  }

  permit :change_password, -> {
    is?(:active) &&
    !is?(:suspended)
  }

  permit :delete_account, -> {
    is?(:active) &&
    !is?(:premium) &&
    created_at >= 7.days.ago
  }

  permit :upgrade_subscription, -> {
    is?(:active) &&
    (is?(:trial) || subscription_tier == "free")
  }

  permit :downgrade_subscription, -> {
    is?(:active) &&
    is?(:premium) &&
    subscription_expires_at >= 30.days.from_now
  }

  permit :export_data, -> {
    is?(:active) &&
    last_export_at.nil? ||
    last_export_at <= 30.days.ago
  }

  permit :reactivate, -> {
    is?(:deactivated) &&
    deactivated_at >= 90.days.ago
  }

  # Security permissions
  permit :enable_2fa, -> {
    is?(:active) &&
    is?(:email_verified) &&
    two_factor_enabled_at.nil?
  }

  permit :disable_2fa, -> {
    is?(:active) &&
    two_factor_enabled_at.present? &&
    two_factor_backup_codes_count > 0
  }

  def login_locked?
    failed_login_attempts >= 5 &&
    last_failed_login_at.present? &&
    last_failed_login_at >= 15.minutes.ago
  end

  # Business methods
  def delete_account_if_allowed!
    raise "Account deletion not permitted" unless permit_delete_account?

    transaction do
      anonymize_data
      update!(
        deactivated_at: Time.current,
        deactivation_reason: "user_requested"
      )
      cancel_subscriptions
      notify_account_deleted
    end
  end
end

# Usage in authentication
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])

    if user.nil? || !user.authenticate(params[:password])
      redirect_to login_path, alert: "Invalid credentials"
      return
    end

    unless user.permit_login?
      if user.login_locked?
        redirect_to login_path, alert: "Account temporarily locked due to failed login attempts"
      elsif user.is_suspended?
        redirect_to login_path, alert: "Account suspended"
      elsif !user.is_email_verified?
        redirect_to verify_email_path, alert: "Please verify your email first"
      else
        redirect_to login_path, alert: "Cannot login at this time"
      end
      return
    end

    session[:user_id] = user.id
    redirect_to dashboard_path
  end
end
```

### Project Management

```ruby
class Project < ApplicationRecord
  include BetterModel
  belongs_to :owner, class_name: "User"
  has_many :tasks
  has_many :members, through: :project_memberships, source: :user

  # Statuses
  is :planning, -> { status == "planning" && started_at.nil? }
  is :active, -> { status == "active" && started_at.present? && completed_at.nil? }
  is :completed, -> { completed_at.present? }
  is :on_hold, -> { hold_until.present? && hold_until > Time.current }
  is :archived, -> { archived_at.present? }
  is :overdue, -> { due_date.present? && due_date < Time.current && !is?(:completed) }

  # Project lifecycle permissions
  permit :start, -> {
    is?(:planning) &&
    members.any? &&
    tasks.any?
  }

  permit :complete, -> {
    is?(:active) &&
    tasks_completion_percentage >= 100
  }

  permit :reopen, -> {
    is?(:completed) &&
    completed_at >= 30.days.ago
  }

  permit :archive, -> {
    (is?(:completed) || is?(:on_hold)) &&
    updated_at < 90.days.ago
  }

  permit :delete, -> {
    is?(:planning) &&
    tasks.empty? &&
    created_at >= 24.hours.ago
  }

  # Task management permissions
  permit :add_tasks, -> {
    (is?(:planning) || is?(:active)) &&
    !is?(:on_hold)
  }

  permit :modify_tasks, -> {
    is?(:active) &&
    !is?(:on_hold)
  }

  permit :delete_tasks, -> {
    (is?(:planning) || is?(:active)) &&
    !is?(:overdue)
  }

  # Team management permissions
  permit :add_members, -> {
    !is?(:completed) &&
    !is?(:archived) &&
    members.count < max_members
  }

  permit :remove_members, -> {
    is?(:planning) ||
    (is?(:active) && members.count > 1)
  }

  # Settings permissions
  permit :change_settings, -> {
    !is?(:completed) &&
    !is?(:archived)
  }

  permit :extend_deadline, -> {
    is?(:active) &&
    is?(:overdue) &&
    extensions_count < 3
  }

  def tasks_completion_percentage
    return 0 if tasks_count == 0
    (completed_tasks_count.to_f / tasks_count * 100).round
  end

  # Business methods
  def start_project!
    raise "Cannot start project" unless permit_start?

    update!(
      status: "active",
      started_at: Time.current
    )
  end

  def mark_complete!
    raise "Cannot complete project" unless permit_complete?

    update!(
      status: "completed",
      completed_at: Time.current
    )
  end
end

# Usage in controller
class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
    @available_actions = @project.granted_permissions([
      :start, :complete, :reopen, :archive, :delete,
      :add_tasks, :add_members, :extend_deadline
    ])
  end

  def start
    @project = Project.find(params[:id])

    unless @project.permit_start?
      reasons = []
      reasons << "Project must be in planning phase" unless @project.is_planning?
      reasons << "Project must have team members" unless @project.members.any?
      reasons << "Project must have tasks" unless @project.tasks.any?

      redirect_to @project, alert: "Cannot start project: #{reasons.join(', ')}"
      return
    end

    @project.start_project!
    redirect_to @project, notice: "Project started successfully"
  end
end
```

### API Rate Limiting and Throttling System

```ruby
class ApiKey < ApplicationRecord
  include BetterModel
  belongs_to :account
  has_many :api_requests

  # Rate limit permissions based on subscription tier
  permit :make_request, -> {
    !is?(:suspended) &&
    !is?(:expired) &&
    !is?(:rate_limited) &&
    account.is?(:active)
  }

  permit :make_premium_request, -> {
    permit?(:make_request) &&
    account.subscription_tier.in?(["professional", "enterprise"])
  }

  permit :make_bulk_request, -> {
    permit?(:make_premium_request) &&
    account.subscription_tier == "enterprise"
  }

  permit :bypass_throttle, -> {
    account.subscription_tier == "enterprise" &&
    priority_access_enabled == true
  }

  permit :increase_rate_limit, -> {
    account.is?(:subscribed) &&
    rate_limit_increase_count < max_increases_per_month
  }

  # Statuses for rate limiting
  is :suspended, -> { suspended_at.present? && suspension_ends_at > Time.current }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  is :rate_limited, -> {
    current_hourly_requests >= hourly_rate_limit ||
    current_daily_requests >= daily_rate_limit
  }

  is :approaching_limit, -> {
    !is?(:rate_limited) &&
    (current_hourly_requests >= hourly_rate_limit * 0.8 ||
     current_daily_requests >= daily_rate_limit * 0.8)
  }

  is :quota_exceeded, -> {
    monthly_requests >= monthly_quota
  }

  # Business logic using permissions
  def execute_request!(endpoint:, params: {})
    raise RateLimitError, "Request not permitted" unless permit_make_request?

    if is_approaching_limit?
      Rails.logger.warn("API Key #{id} approaching rate limit")
    end

    transaction do
      increment_request_counters!
      log_api_request(endpoint, params)
      yield if block_given?
    end
  end

  def request_rate_limit_increase!(amount:)
    raise PermissionError, "Cannot increase rate limit" unless permit_increase_rate_limit?

    transaction do
      update!(
        hourly_rate_limit: hourly_rate_limit + amount,
        daily_rate_limit: daily_rate_limit + (amount * 24),
        rate_limit_increase_count: rate_limit_increase_count + 1
      )
    end
  end

  # Helper methods for rate limit calculations
  def hourly_rate_limit
    return super if priority_access_enabled?

    base = case account.subscription_tier
           when "free" then 100
           when "starter" then 1000
           when "professional" then 10000
           when "enterprise" then 100000
           else 10
           end

    base + (rate_limit_increase_count * 100)
  end

  def daily_rate_limit
    hourly_rate_limit * 24
  end

  def monthly_quota
    case account.subscription_tier
    when "free" then 10000
    when "starter" then 100000
    when "professional" then 1000000
    when "enterprise" then Float::INFINITY
    else 100
    end
  end

  def remaining_requests_today
    return Float::INFINITY if permit_bypass_throttle?
    [daily_rate_limit - current_daily_requests, 0].max
  end

  def reset_time
    Time.current.beginning_of_hour + 1.hour
  end

  private

  def increment_request_counters!
    now = Time.current
    hour_key = now.beginning_of_hour.to_i
    day_key = now.beginning_of_day.to_i

    # Use Redis or database counters
    Rails.cache.increment("api_key:#{id}:hour:#{hour_key}", 1, expires_in: 2.hours)
    Rails.cache.increment("api_key:#{id}:day:#{day_key}", 1, expires_in: 48.hours)

    increment!(:monthly_requests)
  end

  def current_hourly_requests
    hour_key = Time.current.beginning_of_hour.to_i
    Rails.cache.read("api_key:#{id}:hour:#{hour_key}").to_i
  end

  def current_daily_requests
    day_key = Time.current.beginning_of_day.to_i
    Rails.cache.read("api_key:#{id}:day:#{day_key}").to_i
  end

  def log_api_request(endpoint, params)
    api_requests.create!(
      endpoint: endpoint,
      params: params,
      timestamp: Time.current
    )
  end

  def max_increases_per_month
    case account.subscription_tier
    when "starter" then 1
    when "professional" then 5
    when "enterprise" then 999
    else 0
    end
  end

  class RateLimitError < StandardError; end
  class PermissionError < StandardError; end
end

# Middleware for API rate limiting
class ApiRateLimitMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Extract API key from request
    api_key_token = request.env["HTTP_X_API_KEY"]
    return unauthorized_response unless api_key_token

    api_key = ApiKey.find_by(token: api_key_token)
    return unauthorized_response unless api_key

    # Check if request is permitted
    unless api_key.permit_make_request?
      return rate_limit_response(api_key)
    end

    # Check for premium endpoints
    if premium_endpoint?(request.path) && !api_key.permit_make_premium_request?
      return upgrade_required_response
    end

    # Execute request with tracking
    begin
      api_key.execute_request!(endpoint: request.path, params: request.params) do
        env["api_key"] = api_key
        @app.call(env)
      end
    rescue ApiKey::RateLimitError => e
      rate_limit_response(api_key)
    end
  end

  private

  def unauthorized_response
    [401, {"Content-Type" => "application/json"}, [{ error: "Invalid API key" }.to_json]]
  end

  def rate_limit_response(api_key)
    [429, {
      "Content-Type" => "application/json",
      "X-RateLimit-Limit" => api_key.hourly_rate_limit.to_s,
      "X-RateLimit-Remaining" => api_key.remaining_requests_today.to_s,
      "X-RateLimit-Reset" => api_key.reset_time.to_i.to_s
    }, [{
      error: "Rate limit exceeded",
      message: "You have exceeded your rate limit. Please try again later.",
      reset_time: api_key.reset_time.iso8601
    }.to_json]]
  end

  def upgrade_required_response
    [402, {"Content-Type" => "application/json"}, [{
      error: "Upgrade required",
      message: "This endpoint requires a premium subscription"
    }.to_json]]
  end

  def premium_endpoint?(path)
    path.start_with?("/api/v1/analytics") ||
    path.start_with?("/api/v1/exports")
  end
end

# Controller integration
class Api::V1::DataController < ApplicationController
  before_action :check_api_permissions

  def index
    # Different response based on permissions
    data = fetch_data

    if current_api_key.permit_make_bulk_request?
      render json: { data: data, meta: detailed_meta }
    elsif current_api_key.permit_make_premium_request?
      render json: { data: data, meta: basic_meta }
    else
      render json: { data: data.first(100) } # Limit free tier
    end
  end

  def bulk_export
    unless current_api_key.permit_make_bulk_request?
      render json: {
        error: "Bulk export requires enterprise subscription"
      }, status: 402
      return
    end

    # Process bulk export
    job = BulkExportJob.perform_later(current_api_key.account_id, export_params)
    render json: { job_id: job.job_id, status: "processing" }
  end

  private

  def check_api_permissions
    unless current_api_key.permit_make_request?
      render json: { error: "API access denied" }, status: 403
    end
  end

  def current_api_key
    @current_api_key ||= ApiKey.find_by(token: request.headers["X-API-KEY"])
  end
end
```

## Edge Cases and Advanced Usage

Advanced permission patterns for complex scenarios

This section explores sophisticated Permissible patterns including permission inheritance in Single Table Inheritance (STI) hierarchies, context-dependent permissions, permission delegation across associations, and integrating permissions with complex authorization requirements.

### Permission Inheritance in STI Hierarchies

```ruby
# Base class with common permissions
class Document < ApplicationRecord
  include BetterModel

  # Common permissions available to all document types
  permit :view, -> {
    !is?(:deleted) &&
    (is?(:public) || is?(:published))
  }

  permit :edit, -> {
    !is?(:deleted) &&
    !is?(:locked) &&
    edited_within_time_limit?
  }

  permit :delete, -> {
    !is?(:published) &&
    !is?(:locked) &&
    created_at >= 24.hours.ago
  }

  permit :lock, -> {
    is?(:published) &&
    !is?(:locked)
  }

  permit :unlock, -> {
    is?(:locked) &&
    lock_expires_soon?
  }

  # Common statuses
  is :public, -> { visibility == "public" }
  is :published, -> { published_at.present? && published_at <= Time.current }
  is :deleted, -> { deleted_at.present? }
  is :locked, -> { locked_at.present? && locked_until > Time.current }

  private

  def edited_within_time_limit?
    updated_at >= 7.days.ago
  end

  def lock_expires_soon?
    locked_until.present? && locked_until <= 1.hour.from_now
  end
end

# Article with extended permissions
class Article < Document
  # Inherits all Document permissions plus adds article-specific ones

  # Override base permission with stricter conditions
  permit :delete, -> {
    super() && # Call parent condition
    comment_count == 0 &&
    view_count < 100
  }

  # Article-specific permissions
  permit :feature, -> {
    is?(:published) &&
    is?(:high_quality) &&
    !is?(:featured)
  }

  permit :unfeature, -> {
    is?(:featured)
  }

  permit :schedule_publication, -> {
    is?(:draft) &&
    title.present? &&
    content.present? &&
    scheduled_at.nil?
  }

  permit :translate, -> {
    is?(:published) &&
    word_count >= 100 &&
    !has_translations?
  }

  permit :add_to_series, -> {
    is?(:published) &&
    series_id.nil? &&
    tags.any?
  }

  # Article-specific statuses
  is :draft, -> { status == "draft" }
  is :high_quality, -> { word_count >= 1000 && has_images? && seo_score >= 80 }
  is :featured, -> { featured_at.present? && featured_until > Time.current }
  is :evergreen, -> { is?(:published) && view_count >= 10000 }

  private

  def has_translations?
    translations_count > 0
  end

  def has_images?
    images_count > 0
  end
end

# Report with different permission rules
class Report < Document
  # Inherits base permissions and adds report-specific ones

  # Override edit permission with report-specific logic
  permit :edit, -> {
    super() && # Call parent condition
    !is?(:finalized) &&
    review_status != "approved"
  }

  # Override delete with stricter conditions
  permit :delete, -> {
    false # Reports can never be deleted, only archived
  }

  # Report-specific permissions
  permit :finalize, -> {
    is?(:draft) &&
    all_sections_complete? &&
    approved_by_reviewer?
  }

  permit :generate_pdf, -> {
    is?(:finalized) &&
    pdf_generation_enabled?
  }

  permit :share_externally, -> {
    is?(:finalized) &&
    sensitivity_level.in?(["public", "low"]) &&
    !is?(:expired)
  }

  permit :revise, -> {
    is?(:finalized) &&
    revision_count < max_revisions &&
    last_revision_at.nil? || last_revision_at < 30.days.ago
  }

  # Report-specific statuses
  is :draft, -> { status == "draft" }
  is :finalized, -> { finalized_at.present? }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  def max_revisions
    case sensitivity_level
    when "high" then 1
    when "medium" then 3
    else 5
    end
  end

  private

  def all_sections_complete?
    required_sections.all? { |section| send("#{section}_complete?") }
  end

  def approved_by_reviewer?
    reviewer_id.present? && reviewed_at.present?
  end

  def pdf_generation_enabled?
    account.feature_enabled?(:pdf_reports)
  end

  def required_sections
    ["executive_summary", "analysis", "recommendations"]
  end
end

# Contract with legal-specific permissions
class Contract < Document
  # Override edit with legal requirements
  permit :edit, -> {
    super() &&
    !is?(:signed) &&
    !is?(:under_legal_review)
  }

  permit :delete, -> {
    false # Contracts can never be deleted for compliance
  }

  # Contract-specific permissions
  permit :send_for_signature, -> {
    is?(:draft) &&
    all_parties_added? &&
    legal_review_status == "approved"
  }

  permit :sign, -> {
    is?(:pending_signature) &&
    !is?(:expired) &&
    can_sign_as_party?
  }

  permit :countersign, -> {
    is?(:partially_signed) &&
    !is?(:expired) &&
    can_countersign?
  }

  permit :void, -> {
    is?(:signed) &&
    void_reason.present? &&
    authorized_to_void?
  }

  permit :amend, -> {
    is?(:signed) &&
    !is?(:voided) &&
    amendment_allowed_in_terms?
  }

  # Contract statuses
  is :signed, -> { all_signatures_complete? }
  is :partially_signed, -> { signatures.any? && !all_signatures_complete? }
  is :pending_signature, -> { sent_for_signature_at.present? && signatures.none? }
  is :under_legal_review, -> { legal_review_started_at.present? && legal_review_status == "in_progress" }
  is :voided, -> { voided_at.present? }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  private

  def all_parties_added?
    parties.count >= minimum_parties
  end

  def all_signatures_complete?
    parties.all? { |party| party.signed? }
  end

  def can_sign_as_party?
    Current.user&.id.in?(parties.pluck(:user_id))
  end

  def can_countersign?
    is_countersigning_party?(Current.user)
  end

  def is_countersigning_party?(user)
    parties.where(role: "countersigner", user_id: user.id).exists?
  end

  def authorized_to_void?
    Current.user&.admin? || Current.user&.id == owner_id
  end

  def amendment_allowed_in_terms?
    contract_terms.include?("amendable")
  end

  def minimum_parties
    2
  end
end

# Usage: Polymorphic behavior based on document type
class DocumentsController < ApplicationController
  def show
    @document = Document.find(params[:id])

    unless @document.permit_view?
      render plain: "Access denied", status: 403
      return
    end

    # Actions vary by document type
    @available_actions = []

    @available_actions << :edit if @document.permit_edit?
    @available_actions << :delete if @document.permit_delete?
    @available_actions << :lock if @document.permit_lock?

    # Type-specific actions
    case @document
    when Article
      @available_actions << :feature if @document.permit_feature?
      @available_actions << :translate if @document.permit_translate?
    when Report
      @available_actions << :finalize if @document.permit_finalize?
      @available_actions << :generate_pdf if @document.permit_generate_pdf?
    when Contract
      @available_actions << :send_for_signature if @document.permit_send_for_signature?
      @available_actions << :sign if @document.permit_sign?
    end

    render :show
  end

  def destroy
    @document = Document.find(params[:id])

    unless @document.permit_delete?
      flash[:error] = case @document
                      when Report
                        "Reports cannot be deleted. Use archive instead."
                      when Contract
                        "Contracts cannot be deleted for compliance reasons."
                      when Article
                        "This article cannot be deleted: #{deletion_blocked_reason(@document)}"
                      else
                        "This document cannot be deleted."
                      end
      redirect_to @document
      return
    end

    @document.destroy
    redirect_to documents_path, notice: "Document deleted"
  end

  private

  def deletion_blocked_reason(article)
    reasons = []
    reasons << "has comments" if article.comment_count > 0
    reasons << "too many views" if article.view_count >= 100
    reasons << "published" if article.is_published?
    reasons << "locked" if article.is_locked?
    reasons.join(", ")
  end
end
```

### Context-Dependent and Delegated Permissions

```ruby
class Task < ApplicationRecord
  include BetterModel
  belongs_to :project
  belongs_to :assigned_to, class_name: "User", optional: true

  # Basic task permissions
  permit :edit, -> {
    !is?(:completed) &&
    !is?(:locked) &&
    project.permit?(:edit_tasks)  # Delegate to project
  }

  permit :delete, -> {
    is?(:unstarted) &&
    project.permit?(:delete_tasks)  # Delegate to project
  }

  permit :assign, -> {
    project.permit?(:assign_tasks) &&  # Delegate to project
    assigned_to.nil?
  }

  permit :reassign, -> {
    project.permit?(:assign_tasks) &&
    assigned_to.present? &&
    !is?(:completed)
  }

  permit :complete, -> {
    is?(:in_progress) &&
    assigned_to_id == Current.user&.id  # Context: current user
  }

  permit :reopen, -> {
    is?(:completed) &&
    completed_at >= 24.hours.ago &&
    (assigned_to_id == Current.user&.id || project.owner_id == Current.user&.id)
  }

  # Context-dependent: permissions based on user role
  permit :force_complete, -> {
    !is?(:completed) &&
    (project.owner_id == Current.user&.id || Current.user&.admin?)
  }

  permit :change_priority, -> {
    project.permit?(:manage_priorities) ||
    (assigned_to_id == Current.user&.id && priority_changes_this_week < 3)
  }

  # Statuses
  is :unstarted, -> { status == "unstarted" }
  is :in_progress, -> { status == "in_progress" }
  is :completed, -> { status == "completed" }
  is :locked, -> { locked_at.present? }
  is :overdue, -> { due_date.present? && due_date < Time.current && !is?(:completed) }
end

class Project < ApplicationRecord
  include BetterModel
  belongs_to :owner, class_name: "User"
  has_many :tasks
  has_many :members, class_name: "ProjectMember"

  # Project-level permissions that tasks can delegate to
  permit :edit_tasks, -> {
    is?(:active) &&
    (owner_id == Current.user&.id || member_with_role?("editor"))
  }

  permit :delete_tasks, -> {
    is?(:active) &&
    owner_id == Current.user&.id
  }

  permit :assign_tasks, -> {
    is?(:active) &&
    (owner_id == Current.user&.id || member_with_role?("manager"))
  }

  permit :manage_priorities, -> {
    owner_id == Current.user&.id || member_with_role?("manager")
  }

  # Statuses
  is :active, -> { status == "active" }
  is :completed, -> { status == "completed" }

  private

  def member_with_role?(role)
    members.exists?(user_id: Current.user&.id, role: role)
  end
end
```

## Testing Permissible Models

Comprehensive testing strategies for permission conditions

Testing Permissible models requires verifying permission conditions under different states, testing permission-based authorization, ensuring permissions correctly reference statuses, and validating permission delegation. This section provides Minitest and RSpec examples covering various testing scenarios.

### Minitest Examples for Permission Logic

```ruby
# test/models/article_test.rb
require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "defines all expected permissions" do
    expected_permissions = [:delete, :edit, :publish, :archive, :feature]
    assert_equal expected_permissions.sort, Article.defined_permissions.sort
  end

  test "checks if permission is defined" do
    assert Article.permission_defined?(:delete)
    assert Article.permission_defined?(:edit)
    refute Article.permission_defined?(:nonexistent)
  end

  # Testing basic permissions
  test "permit_delete? returns true for unpublished articles" do
    article = articles(:draft_article)
    assert article.permit_delete?
    assert article.permit?(:delete)
  end

  test "permit_delete? returns false for published articles" do
    article = articles(:published_article)
    refute article.permit_delete?
    refute article.permit?(:delete)
  end

  test "permit_edit? returns true for draft articles" do
    article = articles(:draft_article)
    assert article.permit_edit?
  end

  test "permit_edit? returns true for scheduled articles" do
    article = articles(:scheduled_article)
    assert article.permit_edit?
  end

  test "permit_edit? returns false for published articles" do
    article = articles(:published_article)
    refute article.permit_edit?
  end

  test "permit_publish? requires title and content" do
    article = Article.new(status: "draft", title: "Test", content: "Content")
    assert article.permit_publish?

    article_no_title = Article.new(status: "draft", content: "Content")
    refute article_no_title.permit_publish?

    article_no_content = Article.new(status: "draft", title: "Test")
    refute article_no_content.permit_publish?
  end

  test "permit_archive? requires article to be old enough" do
    old_article = articles(:old_article)
    old_article.update!(created_at: 2.years.ago)
    assert old_article.permit_archive?

    new_article = articles(:draft_article)
    new_article.update!(created_at: 1.day.ago)
    refute new_article.permit_archive?
  end

  # Testing permissions with status references
  test "permit_feature? requires published and high quality status" do
    article = articles(:published_article)
    article.update!(
      views_count: 5000,
      word_count: 1500,
      seo_score: 85
    )

    assert article.is_high_quality?
    assert article.is_published?
    assert article.permit_feature?
  end

  test "permit_feature? returns false for non-high-quality articles" do
    article = articles(:published_article)
    article.update!(word_count: 100, seo_score: 30)

    assert article.is_published?
    refute article.is_high_quality?
    refute article.permit_feature?
  end

  # Testing permission state changes
  test "permissions update when model state changes" do
    article = articles(:draft_article)
    assert article.permit_edit?
    assert article.permit_delete?

    article.update!(status: "published", published_at: Time.current)
    refute article.permit_edit?
    refute article.permit_delete?
  end

  # Testing helper methods
  test "permissions returns hash of all permissions with boolean values" do
    article = articles(:draft_article)
    perms = article.permissions

    assert_kind_of Hash, perms
    assert_equal true, perms[:edit]
    assert_equal true, perms[:delete]
    assert_equal false, perms[:feature]
  end

  test "granted_permissions returns only permitted actions" do
    article = articles(:draft_article)
    granted = article.granted_permissions([:edit, :delete, :publish, :feature])

    assert_includes granted, :edit
    assert_includes granted, :delete
    refute_includes granted, :feature
  end

  test "any_granted? returns true if any permission is granted" do
    article = articles(:draft_article)
    assert article.any_granted?([:edit, :delete, :feature])
  end

  test "any_granted? returns false if no permissions are granted" do
    article = articles(:published_article)
    refute article.any_granted?([:delete, :edit])
  end

  test "all_granted? returns true when all permissions are granted" do
    article = articles(:draft_article)
    assert article.all_granted?([:edit, :delete])
  end

  test "all_granted? returns false when any permission is denied" do
    article = articles(:draft_article)
    refute article.all_granted?([:edit, :delete, :feature])
  end

  # Testing JSON serialization
  test "as_json excludes permissions by default" do
    article = articles(:draft_article)
    json = article.as_json

    assert json.key?("id")
    assert json.key?("title")
    refute json.key?("permissions")
  end

  test "as_json includes permissions when requested" do
    article = articles(:draft_article)
    json = article.as_json(include_permissions: true)

    assert json.key?("permissions")
    assert_kind_of Hash, json["permissions"]
    assert_equal true, json["permissions"]["edit"]
    assert_equal true, json["permissions"]["delete"]
  end

  # Testing edge cases
  test "returns false for undefined permission checks with permit?" do
    article = articles(:draft_article)
    refute article.permit?(:nonexistent_permission)
  end

  test "raises NoMethodError for undefined permission predicate methods" do
    article = articles(:draft_article)
    assert_raises(NoMethodError) do
      article.permit_nonexistent_permission?
    end
  end

  # Testing complex permission conditions
  test "permits with multiple conditions" do
    article = articles(:draft_article)
    article.update!(
      title: "Complete Article",
      content: "A" * 1000,
      word_count: 1000
    )

    assert article.title.present?
    assert article.content.present?
    assert article.permit_publish?
  end
end

# test/models/api_key_test.rb
require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  setup do
    @api_key = api_keys(:active_key)
    @account = @api_key.account
  end

  test "permit_make_request? requires active account and no rate limiting" do
    assert @api_key.permit_make_request?
  end

  test "permit_make_request? returns false when suspended" do
    @api_key.update!(suspended_at: Time.current, suspension_ends_at: 1.day.from_now)
    refute @api_key.permit_make_request?
  end

  test "permit_make_request? returns false when rate limited" do
    # Simulate rate limit by setting high request counts
    hour_key = Time.current.beginning_of_hour.to_i
    Rails.cache.write("api_key:#{@api_key.id}:hour:#{hour_key}", @api_key.hourly_rate_limit + 1)

    refute @api_key.permit_make_request?
  end

  test "permit_make_premium_request? requires professional or enterprise tier" do
    @account.update!(subscription_tier: "free")
    refute @api_key.permit_make_premium_request?

    @account.update!(subscription_tier: "professional")
    assert @api_key.permit_make_premium_request?

    @account.update!(subscription_tier: "enterprise")
    assert @api_key.permit_make_premium_request?
  end

  test "permit_make_bulk_request? requires enterprise tier" do
    @account.update!(subscription_tier: "professional")
    refute @api_key.permit_make_bulk_request?

    @account.update!(subscription_tier: "enterprise")
    assert @api_key.permit_make_bulk_request?
  end

  test "permit_bypass_throttle? requires enterprise with priority access" do
    @account.update!(subscription_tier: "enterprise")
    @api_key.update!(priority_access_enabled: false)
    refute @api_key.permit_bypass_throttle?

    @api_key.update!(priority_access_enabled: true)
    assert @api_key.permit_bypass_throttle?
  end

  test "execute_request! increments counters when permitted" do
    initial_count = @api_key.monthly_requests

    @api_key.execute_request!(endpoint: "/api/v1/test", params: {})

    assert_equal initial_count + 1, @api_key.reload.monthly_requests
  end

  test "execute_request! raises error when not permitted" do
    @api_key.update!(suspended_at: Time.current, suspension_ends_at: 1.day.from_now)

    assert_raises(ApiKey::RateLimitError) do
      @api_key.execute_request!(endpoint: "/api/v1/test", params: {})
    end
  end

  test "request_rate_limit_increase! updates limits when permitted" do
    @account.update!(subscription_tier: "professional")
    initial_limit = @api_key.hourly_rate_limit

    @api_key.request_rate_limit_increase!(amount: 1000)

    assert_equal initial_limit + 1000, @api_key.reload.hourly_rate_limit
  end
end
```

### RSpec Examples for Permission Authorization

```ruby
# spec/models/document_spec.rb
require "rails_helper"

RSpec.describe Document, type: :model do
  describe "Permissible" do
    describe "permission definitions" do
      it "defines all expected base permissions" do
        expect(Document.defined_permissions).to include(
          :view, :edit, :delete, :lock, :unlock
        )
      end

      it "checks if permission is defined" do
        expect(Document.permission_defined?(:edit)).to be true
        expect(Document.permission_defined?(:nonexistent)).to be false
      end
    end

    describe "#permit_view?" do
      it "returns true for public documents" do
        document = create(:document, visibility: "public")
        expect(document.permit_view?).to be true
      end

      it "returns true for published documents" do
        document = create(:document,
          visibility: "private",
          published_at: 1.day.ago
        )
        expect(document.permit_view?).to be true
      end

      it "returns false for deleted documents" do
        document = create(:document,
          visibility: "public",
          deleted_at: 1.day.ago
        )
        expect(document.permit_view?).to be false
      end
    end

    describe "#permit_edit?" do
      it "returns true for recent unlocked documents" do
        document = create(:document,
          updated_at: 1.day.ago,
          locked_at: nil
        )
        expect(document.permit_edit?).to be true
      end

      it "returns false for locked documents" do
        document = create(:document,
          locked_at: Time.current,
          locked_until: 1.day.from_now
        )
        expect(document.permit_edit?).to be false
      end

      it "returns false for old documents" do
        document = create(:document, updated_at: 10.days.ago)
        expect(document.permit_edit?).to be false
      end
    end

    describe "#permit_delete?" do
      it "returns true for unpublished recent documents" do
        document = create(:document,
          published_at: nil,
          created_at: 1.hour.ago,
          locked_at: nil
        )
        expect(document.permit_delete?).to be true
      end

      it "returns false for published documents" do
        document = create(:document, published_at: 1.day.ago)
        expect(document.permit_delete?).to be false
      end

      it "returns false for locked documents" do
        document = create(:document,
          locked_at: Time.current,
          locked_until: 1.hour.from_now
        )
        expect(document.permit_delete?).to be false
      end

      it "returns false for old documents" do
        document = create(:document, created_at: 2.days.ago)
        expect(document.permit_delete?).to be false
      end
    end
  end
end

# spec/models/article_spec.rb
RSpec.describe Article, type: :model do
  describe "inherited permissions" do
    it "inherits base Document permissions" do
      expect(Article.defined_permissions).to include(
        :view, :edit, :delete, :lock, :unlock
      )
    end

    it "adds article-specific permissions" do
      expect(Article.defined_permissions).to include(
        :feature, :unfeature, :schedule_publication, :translate, :add_to_series
      )
    end

    describe "overridden #permit_delete?" do
      it "applies stricter conditions than parent" do
        article = create(:article,
          status: "draft",
          created_at: 1.hour.ago,
          comment_count: 0,
          view_count: 50
        )

        expect(article.permit_delete?).to be true
      end

      it "returns false when article has comments" do
        article = create(:article,
          status: "draft",
          created_at: 1.hour.ago,
          comment_count: 5,
          view_count: 50
        )

        expect(article.permit_delete?).to be false
      end

      it "returns false when article has many views" do
        article = create(:article,
          status: "draft",
          created_at: 1.hour.ago,
          comment_count: 0,
          view_count: 150
        )

        expect(article.permit_delete?).to be false
      end
    end

    describe "#permit_feature?" do
      it "requires published and high quality status" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago,
          word_count: 1500,
          seo_score: 90,
          featured_at: nil
        )

        expect(article.is_published?).to be true
        expect(article.is_high_quality?).to be true
        expect(article.permit_feature?).to be true
      end

      it "returns false for low quality articles" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago,
          word_count: 100,
          seo_score: 50
        )

        expect(article.permit_feature?).to be false
      end
    end
  end
end

# spec/models/contract_spec.rb
RSpec.describe Contract, type: :model do
  describe "contract-specific permissions" do
    it "never permits deletion" do
      contract = create(:contract, status: "draft")
      expect(contract.permit_delete?).to be false

      contract.update!(status: "signed")
      expect(contract.permit_delete?).to be false
    end

    describe "#permit_send_for_signature?" do
      it "requires draft with legal approval" do
        contract = create(:contract,
          status: "draft",
          legal_review_status: "approved"
        )
        allow(contract).to receive(:all_parties_added?).and_return(true)

        expect(contract.permit_send_for_signature?).to be true
      end

      it "returns false without legal approval" do
        contract = create(:contract,
          status: "draft",
          legal_review_status: "pending"
        )

        expect(contract.permit_send_for_signature?).to be false
      end
    end
  end
end
```

## Best Practices

Guidelines for effective Permissible usage

When implementing Permissible in production applications, follow these best practices: Use action verb names for permissions (delete, edit, publish) rather than adjectives (deletable, editable); reference Statusable statuses using `is?(:status)` for cleaner and more maintainable code; keep permission condition blocks simple and extract complex logic into private methods; avoid database queries within permission conditions and use cached counters or loaded associations instead; document complex permissions with comments explaining business rules; combine permissions with controller before_action filters for authorization; use permissions in views to conditionally render UI elements; include permissions in API responses for client-side decision making; test permission conditions thoroughly with different model states.

```ruby
# GOOD: Use action verbs for permission names
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" }
  permit :publish, -> { status == "draft" && valid? }
end

# AVOID: Adjective or can_ prefixes (redundant)
class Article < ApplicationRecord
  include BetterModel

  permit :deletable, -> { status != "published" }    # Verbose
  permit :can_edit, -> { status == "draft" }         # Redundant
  permit :is_publishable, -> { status == "draft" }   # Confusing
end

# GOOD: Reference Statusable for clean code
class Order < ApplicationRecord
  include BetterModel

  is :paid, -> { payment_status == "paid" }
  is :shipped, -> { shipped_at.present? }

  permit :refund, -> { is?(:paid) && !is?(:shipped) }
  permit :cancel, -> { !is?(:shipped) }
end

# AVOID: Repeating status logic in permissions
class Order < ApplicationRecord
  include BetterModel

  permit :refund, -> {
    payment_status == "paid" && shipped_at.nil?  # Duplicates status logic
  }
end

# GOOD: Extract complex logic to private methods
class Consultation < ApplicationRecord
  include BetterModel

  permit :schedule, -> { scheduling_allowed? }
  permit :cancel, -> { cancellation_allowed? }

  private

  def scheduling_allowed?
    !scheduled_at.present? &&
    consultant.available? &&
    client.active? &&
    credits_remaining > 0
  end

  def cancellation_allowed?
    scheduled_at.present? &&
    scheduled_at > 24.hours.from_now &&
    !cancelled_at.present?
  end
end

# AVOID: Complex inline logic
class Consultation < ApplicationRecord
  include BetterModel

  permit :schedule, -> {
    !scheduled_at.present? && consultant.available? &&
    client.active? && credits_remaining > 0
  }
end

# AVOID: Database queries in permission conditions
class User < ApplicationRecord
  include BetterModel

  # Bad: N+1 queries
  permit :create_post, -> { posts.count < 100 }
  permit :send_message, -> { messages.where("created_at > ?", 1.hour.ago).count < 10 }
end

# BETTER: Use counter caches or time stamps
class User < ApplicationRecord
  include BetterModel

  # Good: Uses counter cache
  permit :create_post, -> { posts_count < 100 }

  # Good: Uses timestamp column
  permit :send_message, -> {
    last_message_sent_at.nil? ||
    last_message_sent_at < 1.hour.ago
  }
end

# GOOD: Document complex business rules
class Event < ApplicationRecord
  include BetterModel

  # Registrations can be cancelled up to 24 hours before the event starts.
  # This policy ensures venue and catering numbers can be finalized.
  # Cancellations within 24 hours require contacting support.
  permit :cancel_registration, -> {
    registered? &&
    starts_at > 24.hours.from_now &&
    !refund_processed?
  }
end

# GOOD: Use in controllers for authorization
class ArticlesController < ApplicationController
  before_action :check_edit_permission, only: [:edit, :update]

  def edit
    # Permission already checked in before_action
  end

  def update
    if @article.update(article_params)
      redirect_to @article, notice: "Article updated"
    else
      render :edit
    end
  end

  private

  def check_edit_permission
    @article = Article.find(params[:id])
    unless @article.permit_edit?
      redirect_to @article, alert: "Cannot edit this article"
    end
  end
end

# GOOD: Use in views for conditional rendering
# app/views/articles/show.html.erb
# <% if @article.permit_edit? %>
#   <%= link_to "Edit", edit_article_path(@article), class: "btn btn-primary" %>
# <% end %>
#
# <% if @article.permit_delete? %>
#   <%= link_to "Delete", article_path(@article),
#       method: :delete,
#       data: { confirm: "Are you sure?" },
#       class: "btn btn-danger" %>
# <% end %>

# GOOD: Test thoroughly
# spec/models/order_spec.rb
RSpec.describe Order, type: :model do
  describe "permissions" do
    describe "#permit_refund?" do
      it "returns true when paid and not shipped" do
        order = create(:order, payment_status: "paid", shipped_at: nil)
        expect(order.permit_refund?).to be true
      end

      it "returns false when not paid" do
        order = create(:order, payment_status: "pending")
        expect(order.permit_refund?).to be false
      end

      it "returns false when already shipped" do
        order = create(:order, payment_status: "paid", shipped_at: 1.day.ago)
        expect(order.permit_refund?).to be false
      end

      it "returns false when already refunded" do
        order = create(:order, payment_status: "paid", refunded_at: 1.day.ago)
        expect(order.permit_refund?).to be false
      end
    end
  end
end
```

## Thread Safety and Error Handling

Concurrent access guarantees and validation behavior

Permissible is designed to be thread-safe for concurrent request handling in Rails applications. Permission definitions are frozen immediately after registration, the internal permission registry is implemented as an immutable frozen hash, and no shared mutable state exists between model instances. Each permission evaluation occurs in the context of a specific model instance using its current attribute values, ensuring that concurrent requests operating on different instances cannot interfere with each other.

The system validates permission definitions at class load time and raises ArgumentError for invalid configurations. Common errors include missing condition blocks, blank permission names, and non-callable condition objects. When checking undefined permissions at runtime, Permissible follows a secure-by-default approach and returns false rather than raising an error, allowing code to gracefully handle permission names that may not be defined on all model classes.

```ruby
# Thread Safety: Permission definitions are frozen
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
  # The permission definition is immediately frozen
  # The registry is frozen and immutable
  # Safe for concurrent access
end

# Thread Safety: Instance evaluation is isolated
# Thread 1
article1 = Article.find(1)
article1.permit_delete?  # Evaluates against article1's attributes

# Thread 2 (running concurrently)
article2 = Article.find(2)
article2.permit_delete?  # Evaluates against article2's attributes
# No interference between threads

# Error Handling: Validation at definition time
class Article < ApplicationRecord
  include BetterModel

  # ERROR: Missing condition
  permit :delete
  # => ArgumentError: Condition proc or block is required

  # ERROR: Blank permission name
  permit "", -> { true }
  # => ArgumentError: Permission name cannot be blank

  # ERROR: Non-callable condition
  permit :delete, "not a proc"
  # => ArgumentError: Condition must respond to call
end

# Error Handling: Undefined permission checks (secure by default)
class Article < ApplicationRecord
  include BetterModel

  permit :delete, -> { status != "published" }
end

article = Article.new

# Checking a defined permission
article.permit?(:delete)  # => true or false (evaluates condition)

# Checking an undefined permission returns false (does not raise error)
article.permit?(:nonexistent)  # => false (secure by default)
article.permit_nonexistent?    # => NoMethodError (method doesn't exist)

# Use permission_defined? to check before evaluating
if Article.permission_defined?(:delete)
  result = article.permit?(:delete)
else
  # Handle undefined permission
end

# Practical example: Safe permission checking with fallback
class PermissionChecker
  def self.safe_check(model, action_name)
    return false unless model.class.respond_to?(:permission_defined?)
    return false unless model.class.permission_defined?(action_name)

    model.permit?(action_name)
  end
end

# Usage
PermissionChecker.safe_check(article, :delete)        # => true/false
PermissionChecker.safe_check(article, :nonexistent)   # => false (safe)
PermissionChecker.safe_check("not a model", :test)    # => false (safe)
```
