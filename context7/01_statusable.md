# BetterModel Statusable Feature Documentation

BetterModel Statusable is a powerful Rails engine feature that provides dynamic boolean status management for ActiveRecord models through conditional logic evaluation. Unlike traditional Rails enums or state machines, Statusable allows you to define statuses as named conditions that are evaluated on-demand based on the current state of your model attributes, associations, and custom methods. When you include BetterModel in any ActiveRecord model, Statusable is automatically available alongside other core features (Permissible, Predicable, Sortable, and Searchable), requiring no additional configuration or database migrations. The system generates predicate methods for each defined status (`is_status_name?`), provides a unified method for checking any status (`is?(:status_name)`), offers helper methods for working with multiple statuses simultaneously, and includes thread-safe status registration with frozen definitions and an immutable registry.

Statusable excels at representing derived or computed states that depend on your model's current data rather than being stored as discrete values in the database. For example, an Order can be "cancellable" if it's paid but not yet shipped, a Post can be "trending" if it has many recent views, or a User can be "premium" if their subscription is active and not expired. These statuses automatically reflect the current reality of your data without requiring manual updates or state synchronization. The feature integrates seamlessly with Rails validations, callbacks, serialization, and supports complex compound conditions that reference other statuses or model methods.

## Basic Concepts

Statusable usage pattern with the `is` declaration method

Statusable uses the `is` class method to declare named statuses with conditional logic blocks. Each status definition consists of a symbolic name and a Ruby lambda or proc that returns a boolean value when evaluated in the context of a model instance. The condition can reference any model attributes, associations, methods, or even other previously-defined statuses. Once declared, each status automatically generates a predicate method following the pattern `is_status_name?` that evaluates the condition and returns true or false.

```ruby
# Basic status declaration pattern
class Article < ApplicationRecord
  include BetterModel

  # Define statuses with the 'is' method
  # Each status has a name and a condition block
  is :published, -> { status == "published" && published_at <= Time.current }
  is :draft, -> { status == "draft" }
  is :scheduled, -> { status == "published" && published_at > Time.current }
  is :archived, -> { archived_at.present? }
end

# The 'is' method signature
# is :status_name, -> { condition_that_returns_boolean }
#    ^symbolic_name  ^lambda/proc evaluated in instance context
```

```ruby
# Example: Setting up a basic model with statuses
class Article < ApplicationRecord
  include BetterModel

  # Simple attribute-based statuses
  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }

  # Date/time-based statuses
  is :recent, -> { created_at >= 7.days.ago }
  is :archived, -> { archived_at.present? }

  # Numeric threshold statuses
  is :popular, -> { views_count >= 1000 }
  is :trending, -> { views_count >= 500 && created_at >= 24.hours.ago }
end

# Usage in application code
article = Article.create!(
  title: "Rails 8 Released",
  status: "published",
  views_count: 1250,
  created_at: 2.hours.ago
)

# All status conditions are evaluated on-demand
article.is_published?  # => true (status == "published")
article.is_draft?      # => false (status != "draft")
article.is_recent?     # => true (created less than 7 days ago)
article.is_popular?    # => true (views >= 1000)
article.is_trending?   # => true (popular AND recent)
```

## Checking Statuses

Dynamic status evaluation with predicate methods and the unified `is?` method

Statusable provides two ways to check if a status condition is true: generated predicate methods that follow the `is_status_name?` pattern, and a unified `is?(:status_name)` method that accepts a symbolic status name. Both approaches evaluate the status condition in real-time against the current state of the model instance. The predicate methods provide convenient, IDE-friendly method calls with autocomplete support, while the `is?` method enables dynamic status checking when the status name is determined at runtime or stored in a variable.

```ruby
# Example model with various statuses
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at <= Time.current }
  is :scheduled, -> { status == "published" && published_at > Time.current }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
end

article = Article.find(1)

# Method 1: Using generated predicate methods
# These methods are created automatically for each defined status
article.is_published?    # => true/false
article.is_draft?        # => true/false
article.is_scheduled?    # => true/false
article.is_expired?      # => true/false

# Method 2: Using the unified is? method with a symbol
# Useful when status name is dynamic or stored in a variable
article.is?(:published)  # => true/false
article.is?(:draft)      # => true/false
article.is?(:expired)    # => true/false

# Dynamic status checking (runtime status name)
status_to_check = :published
article.is?(status_to_check)  # => true/false

# Checking statuses in conditionals
if article.is_published?
  puts "Article is live!"
elsif article.is_scheduled?
  puts "Article will be published at #{article.published_at}"
elsif article.is_draft?
  puts "Article is still being written"
end

# Using statuses in model methods
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  def viewable_by_public?
    is_published? && !is_expired?
  end
end
```

## Getting All Statuses

Retrieving status snapshots with the `statuses` method

The `statuses` instance method returns a hash containing all defined statuses as keys with their current boolean values. This provides a complete snapshot of all status conditions evaluated at a specific moment in time. The returned hash uses symbolic keys matching the status names and boolean values indicating whether each status condition is currently true or false. This method is particularly useful for debugging, logging, API responses, or when you need to check multiple status conditions simultaneously without making individual method calls.

```ruby
# Example model with multiple statuses
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at <= Time.current }
  is :scheduled, -> { status == "published" && published_at > Time.current }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :popular, -> { views_count >= 1000 }
  is :active, -> { !archived_at.present? }
end

article = Article.find(1)

# Get a hash of all statuses with their current values
article.statuses
# Returns a hash like:
# {
#   draft: false,
#   published: true,
#   scheduled: false,
#   expired: false,
#   popular: true,
#   active: true
# }

# Useful for debugging and logging
Rails.logger.info "Article statuses: #{article.statuses.inspect}"

# Useful for conditional logic based on multiple statuses
statuses = article.statuses
if statuses[:published] && statuses[:popular] && !statuses[:expired]
  puts "This is a live, popular article!"
end

# Example: Building a status dashboard
def article_summary(article)
  {
    id: article.id,
    title: article.title,
    all_statuses: article.statuses
  }
end
```

## Helper Methods

Utility methods for working with multiple statuses simultaneously

Statusable provides three helper methods that simplify common operations when working with multiple statuses: `has_any_status?` checks if at least one defined status is true, `has_all_statuses?([:status1, :status2])` verifies that all specified statuses are true, and `active_statuses([:status1, :status2, :status3])` filters a list of status names and returns only those that are currently true. These methods eliminate the need for verbose boolean logic and make code more readable when dealing with multiple status conditions.

```ruby
# Example model with multiple statuses
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :scheduled, -> { scheduled_at.present? && scheduled_at > Time.current }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :popular, -> { views_count >= 1000 }
  is :featured, -> { featured_at.present? }
end

article = Article.find(1)

# Check if ANY status is active
article.has_any_status?
# Returns true if at least one status condition evaluates to true
# Returns false only if ALL statuses are false or no statuses are defined
# => true

# Check if ALL specified statuses are active
article.has_all_statuses?([:published, :popular])
# Returns true only if BOTH published? AND popular? are true
# Returns false if any of the specified statuses is false
# => true

# Alternative: checking a single required status
article.has_all_statuses?([:published])
# => true (if published)

# Get only the active statuses from a list
article.active_statuses([:published, :draft, :popular, :expired])
# Filters the provided list and returns only statuses that are true
# Example return value: [:published, :popular]
# Note: This does NOT return statuses that weren't in the input list

# Practical example: Feature availability based on multiple statuses
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :premium, -> { premium_content == true }

  def accessible_by_free_users?
    # Must be published, not expired, and not premium
    has_all_statuses?([:published]) &&
      !is_expired? &&
      !is_premium?
  end

  def has_content_issues?
    # Any of these statuses indicate a problem
    active_issues = active_statuses([:expired, :flagged, :reported])
    active_issues.any?
  end
end

# Example: Building a status summary
def status_summary(article)
  all_checks = [:published, :draft, :popular, :featured, :expired]
  active = article.active_statuses(all_checks)

  {
    has_any: article.has_any_status?,
    active_list: active,
    active_count: active.size
  }
end
```

## Class Methods

Model-level status introspection and validation

Statusable provides class-level methods for introspecting defined statuses on a model: `defined_statuses` returns an array of all status names registered on the model class, and `status_defined?(:status_name)` checks if a specific status has been declared. These methods are useful for metaprogramming, runtime validation of status names, building dynamic interfaces that adapt to available statuses, or writing generic code that works with any Statusable model.

```ruby
# Example model with defined statuses
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :scheduled, -> { scheduled_at.present? }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :popular, -> { views_count >= 1000 }
  is :active, -> { !archived_at.present? }
end

# Get all defined status names
Article.defined_statuses
# Returns an array of symbolic status names
# => [:draft, :published, :scheduled, :expired, :popular, :active]

# Check if a specific status is defined
Article.status_defined?(:published)
# => true

Article.status_defined?(:nonexistent)
# => false

# Practical example: Dynamic status filtering in a controller
class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Validate status filter parameter
    if params[:status].present?
      status_sym = params[:status].to_sym

      if Article.status_defined?(status_sym)
        @articles = @articles.select { |article| article.is?(status_sym) }
      else
        flash[:error] = "Invalid status filter: #{params[:status]}"
      end
    end

    # Make available statuses available to the view
    @available_statuses = Article.defined_statuses
  end
end

# Example: Building a generic status checker
class StatusChecker
  def self.check_model(model_class, status_name)
    unless model_class.respond_to?(:status_defined?)
      return { error: "Model does not include Statusable" }
    end

    unless model_class.status_defined?(status_name)
      return {
        error: "Status '#{status_name}' not defined",
        available_statuses: model_class.defined_statuses
      }
    end

    {
      valid: true,
      status: status_name,
      defined_on: model_class.name
    }
  end
end

# Example: Metaprogramming with defined statuses
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }
  is :archived, -> { archived_at.present? }

  # Dynamically create scope for each defined status
  defined_statuses.each do |status_name|
    scope status_name, -> { all.select { |record| record.is?(status_name) } }
  end
end

# Now you can use: Article.published, Article.draft, Article.archived
```

## JSON Serialization

Including status information in JSON API responses

Statusable models support an optional `include_statuses` parameter in the `as_json` method that, when set to true, adds a `statuses` key to the JSON output containing a hash of all status names and their current boolean values. By default, statuses are not included in JSON serialization to avoid bloating API responses with computed values. This feature is particularly useful for API clients that need to make decisions based on multiple status conditions or for debugging and development tools.

```ruby
# Example model with statuses
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :scheduled, -> { scheduled_at.present? && scheduled_at > Time.current }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :popular, -> { views_count >= 1000 }
  is :active, -> { !archived_at.present? }
end

article = Article.find(1)

# Default JSON serialization (without statuses)
article.as_json
# Returns standard attributes only:
# {
#   "id" => 1,
#   "title" => "Rails 8 Released",
#   "status" => "published",
#   "views_count" => 1250,
#   "created_at" => "2025-01-05T10:30:00.000Z",
#   ...
# }

# JSON serialization WITH statuses
article.as_json(include_statuses: true)
# Returns attributes plus computed statuses:
# {
#   "id" => 1,
#   "title" => "Rails 8 Released",
#   "status" => "published",
#   "views_count" => 1250,
#   "created_at" => "2025-01-05T10:30:00.000Z",
#   "statuses" => {
#     "draft" => false,
#     "published" => true,
#     "scheduled" => false,
#     "expired" => false,
#     "popular" => true,
#     "active" => true
#   }
# }

# Practical example: API controller with conditional status inclusion
class Api::V1::ArticlesController < ApplicationController
  def show
    article = Article.find(params[:id])

    # Include statuses for admin users
    include_statuses = current_user&.admin?

    render json: article.as_json(include_statuses: include_statuses)
  end

  def index
    articles = Article.published.limit(20)

    # Always include statuses in list endpoints for client-side filtering
    render json: articles.map { |article|
      article.as_json(include_statuses: true)
    }
  end
end

# Example: Custom serializer with status flags
class ArticleSerializer
  def initialize(article)
    @article = article
  end

  def as_json
    {
      id: @article.id,
      title: @article.title,
      content: @article.content,
      # Include specific status flags
      is_live: @article.is_published? && !@article.is_expired?,
      is_editable: @article.is_draft? || @article.is_scheduled?,
      visibility: determine_visibility,
      # Optionally include all statuses
      all_statuses: @article.statuses
    }
  end

  private

  def determine_visibility
    return "public" if @article.is_published?
    return "scheduled" if @article.is_scheduled?
    return "private" if @article.is_draft?
    "unknown"
  end
end
```

## Complex Status Conditions

Building sophisticated statuses with compound logic, date comparisons, and status references

Statusable condition blocks can contain any Ruby logic and have full access to model attributes, associations (when loaded), and previously defined statuses. Complex conditions commonly involve multiple attribute checks combined with boolean operators, date and time comparisons using ActiveSupport helpers, numerical thresholds and ranges, pattern matching with regular expressions, and references to other statuses using the `is?` method. Compound conditions that reference other statuses enable building hierarchical or dependent status relationships where higher-level statuses are composed of lower-level status checks.

```ruby
# Example: Comprehensive status conditions
class Consultation < ApplicationRecord
  include BetterModel

  # Simple attribute check
  is :pending, -> { status == "initialized" }

  # Date/time comparisons using ActiveSupport helpers
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :scheduled, -> { scheduled_at.present? }
  is :immediate, -> { scheduled_at.blank? }
  is :upcoming, -> { scheduled_at.present? && scheduled_at > Time.current }

  # Multiple conditions with boolean operators
  is :active_session, -> {
    status == "active" && !is?(:expired) && started_at.present?
  }

  # Compound conditions referencing other statuses
  is :ready_to_start, -> {
    is?(:scheduled) && scheduled_at <= Time.current && !is?(:expired)
  }

  # Numerical thresholds and ranges
  is :long_running, -> {
    duration_minutes.present? && duration_minutes > 60
  }

  is :standard_length, -> {
    duration_minutes.present? && duration_minutes.between?(30, 60)
  }

  # Using associations (when loaded)
  is :has_participants, -> { participants.loaded? && participants.any? }

  # Using custom methods
  is :overdue, -> { is?(:scheduled) && past_due_date? }

  # Complex business logic
  is :billable, -> {
    status == "completed" &&
    duration_minutes.present? &&
    duration_minutes >= 15 &&
    !is?(:cancelled) &&
    billed_at.nil?
  }

  # Pattern matching
  is :premium_tier, -> {
    tier_code.present? && tier_code.match?(/^(PREMIUM|ENTERPRISE)/)
  }

  private

  def past_due_date?
    scheduled_at.present? && scheduled_at < 1.hour.ago
  end
end

# Usage examples
consultation = Consultation.find(1)

# Simple status checks
consultation.is_pending?  # => true/false

# Complex computed statuses
consultation.is_ready_to_start?
# Evaluates: is_scheduled? AND scheduled_at <= now AND NOT expired?

consultation.is_billable?
# Evaluates multiple conditions for billing eligibility

# Using statuses in business logic
class Consultation < ApplicationRecord
  include BetterModel

  is :scheduled, -> { scheduled_at.present? }
  is :expired, -> { expires_at <= Time.current }
  is :ready_to_start, -> { is?(:scheduled) && scheduled_at <= Time.current }

  def start!
    raise "Cannot start consultation" unless is_ready_to_start?

    update!(
      status: "active",
      started_at: Time.current
    )
  end
end
```

## Real-World Examples

Production-ready status implementations for common use cases

Real-world Statusable implementations demonstrate patterns for e-commerce orders tracking payment and fulfillment states, blog posts managing publication workflows, user accounts with subscription and verification statuses, project management with progress tracking, and event systems with time-based availability. These examples show how to combine simple attribute checks with date comparisons, reference other statuses for compound conditions, and integrate statuses with business logic methods and validations.

### E-commerce Order Status Management

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Payment statuses
  is :pending_payment, -> {
    status == "pending" && payment_status == "unpaid"
  }

  is :paid, -> { payment_status == "paid" }

  is :payment_failed, -> {
    payment_status == "failed" && payment_attempts >= 3
  }

  # Fulfillment statuses
  is :processing, -> {
    status == "processing" && is?(:paid)
  }

  is :shipped, -> {
    status == "shipped" && shipped_at.present?
  }

  is :delivered, -> {
    status == "delivered" && delivered_at.present?
  }

  # Business rule statuses
  is :cancellable, -> {
    is?(:pending_payment) || (is?(:paid) && !is?(:shipped))
  }

  is :refundable, -> {
    is?(:paid) && !is?(:shipped) && created_at >= 30.days.ago
  }

  is :tracking_available, -> {
    is?(:shipped) && tracking_number.present?
  }

  # Using statuses in business logic
  def cancel!
    raise "Order cannot be cancelled" unless is_cancellable?

    transaction do
      update!(status: "cancelled", cancelled_at: Time.current)
      refund_payment if is?(:paid)
    end
  end

  def request_refund!
    raise "Order is not refundable" unless is_refundable?

    update!(refund_requested_at: Time.current)
    RefundProcessor.process(self)
  end
end

# Usage
order = Order.find(1)
order.is_cancellable?  # => true
order.is_refundable?   # => false
order.cancel! if order.is_cancellable?
```

### Blog Post Publication Workflow

```ruby
class Post < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: "User"

  # Publication statuses
  is :draft, -> { status == "draft" }

  is :published, -> {
    status == "published" && published_at.present? && published_at <= Time.current
  }

  is :scheduled, -> {
    status == "published" && published_at.present? && published_at > Time.current
  }

  is :archived, -> { archived_at.present? }

  # Engagement statuses
  is :trending, -> {
    views_count >= 1000 && created_at >= 24.hours.ago
  }

  is :popular, -> {
    views_count >= 5000 || comments_count >= 50
  }

  # Editorial statuses
  is :needs_review, -> {
    is?(:draft) && updated_at < 7.days.ago && word_count > 0
  }

  is :stale, -> {
    is?(:published) && updated_at < 180.days.ago
  }

  is :featured_eligible, -> {
    is?(:published) && is?(:popular) && featured_at.nil?
  }

  # Visibility checks
  def visible_to_public?
    is_published? && !is_archived?
  end

  def editable_by?(user)
    return true if user.admin?
    return true if author_id == user.id && (is_draft? || is_scheduled?)
    false
  end
end

# Usage in controller
class PostsController < ApplicationController
  def index
    @posts = Post.all
    @posts = @posts.select { |p| p.visible_to_public? }
    @trending = @posts.select { |p| p.is_trending? }
    @popular = @posts.select { |p| p.is_popular? }
  end

  def editorial_dashboard
    @needs_review = Post.all.select { |p| p.is_needs_review? }
    @stale_posts = Post.all.select { |p| p.is_stale? }
    @featured_candidates = Post.all.select { |p| p.is_featured_eligible? }
  end
end
```

### User Account Management

```ruby
class User < ApplicationRecord
  include BetterModel

  # Account statuses
  is :active, -> {
    suspended_at.nil? && email_verified_at.present?
  }

  is :suspended, -> { suspended_at.present? }

  is :email_verified, -> { email_verified_at.present? }

  is :email_pending, -> { email_verified_at.nil? }

  # Subscription statuses
  is :premium, -> {
    subscription_tier == "premium" &&
    subscription_expires_at.present? &&
    subscription_expires_at > Time.current
  }

  is :trial, -> {
    subscription_tier == "trial" && created_at >= 14.days.ago
  }

  is :free_tier, -> {
    subscription_tier == "free" || (!is?(:premium) && !is?(:trial))
  }

  is :subscription_expired, -> {
    subscription_expires_at.present? &&
    subscription_expires_at <= Time.current
  }

  # Security statuses
  is :requires_password_change, -> {
    is?(:active) &&
    password_changed_at.present? &&
    password_changed_at < 90.days.ago
  }

  is :requires_2fa_setup, -> {
    is?(:active) &&
    is?(:premium) &&
    two_factor_enabled_at.nil?
  }

  is :locked_out, -> {
    failed_login_attempts >= 5 &&
    last_failed_login_at.present? &&
    last_failed_login_at >= 15.minutes.ago
  }

  # Feature access helpers
  def can_access_premium_features?
    is_premium? && is_active?
  end

  def can_login?
    is_active? && !is_locked_out?
  end

  def requires_action?
    is_requires_password_change? ||
    is_requires_2fa_setup? ||
    is_email_pending?
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

    unless user.can_login?
      if user.is_locked_out?
        redirect_to login_path, alert: "Account temporarily locked"
      elsif user.is_suspended?
        redirect_to login_path, alert: "Account suspended"
      else
        redirect_to login_path, alert: "Cannot access account"
      end
      return
    end

    session[:user_id] = user.id

    if user.requires_action?
      redirect_to account_setup_path
    else
      redirect_to dashboard_path
    end
  end
end
```

### Project Management

```ruby
class Project < ApplicationRecord
  include BetterModel
  has_many :tasks
  belongs_to :owner, class_name: "User"

  # Progress statuses
  is :not_started, -> {
    started_at.nil? && tasks_count == 0
  }

  is :in_progress, -> {
    started_at.present? && completed_at.nil?
  }

  is :completed, -> { completed_at.present? }

  is :on_hold, -> {
    hold_until.present? && hold_until > Time.current
  }

  # Schedule statuses
  is :overdue, -> {
    due_date.present? &&
    due_date < Time.current &&
    !is?(:completed)
  }

  is :due_soon, -> {
    due_date.present? &&
    due_date.between?(Time.current, 7.days.from_now) &&
    !is?(:completed)
  }

  # Health statuses (using loaded associations)
  is :at_risk, -> {
    tasks.loaded? &&
    is?(:in_progress) &&
    completed_tasks_percentage < 50 &&
    is?(:due_soon)
  }

  is :healthy, -> {
    is?(:in_progress) &&
    !is?(:overdue) &&
    completed_tasks_percentage >= 70
  }

  # Helper methods
  def completed_tasks_percentage
    return 0 if tasks_count == 0
    (completed_tasks_count.to_f / tasks_count * 100).round
  end

  def status_summary
    return "Not Started" if is_not_started?
    return "Completed" if is_completed?
    return "On Hold" if is_on_hold?
    return "Overdue" if is_overdue?
    return "Due Soon" if is_due_soon?
    "In Progress"
  end
end

# Usage in dashboard
class DashboardController < ApplicationController
  def index
    @projects = current_user.projects.includes(:tasks)

    @overdue = @projects.select { |p| p.is_overdue? }
    @at_risk = @projects.select { |p| p.is_at_risk? }
    @healthy = @projects.select { |p| p.is_healthy? }

    @status_counts = {
      in_progress: @projects.count { |p| p.is_in_progress? },
      completed: @projects.count { |p| p.is_completed? },
      overdue: @overdue.count,
      at_risk: @at_risk.count
    }
  end
end
```

### Multi-Tenant SaaS Application

```ruby
class Account < ApplicationRecord
  include BetterModel
  has_many :users
  has_many :subscriptions
  belongs_to :organization

  # Subscription and billing statuses
  is :trial_active, -> {
    subscription_tier == "trial" &&
    trial_ends_at.present? &&
    trial_ends_at > Time.current
  }

  is :trial_expired, -> {
    subscription_tier == "trial" &&
    trial_ends_at.present? &&
    trial_ends_at <= Time.current
  }

  is :subscribed, -> {
    ["starter", "professional", "enterprise"].include?(subscription_tier) &&
    subscription_status == "active"
  }

  is :payment_overdue, -> {
    is?(:subscribed) &&
    last_payment_failed_at.present? &&
    last_payment_failed_at >= 7.days.ago &&
    grace_period_ends_at > Time.current
  }

  is :suspended, -> {
    suspension_reason.present? &&
    suspended_at.present?
  }

  # Feature access statuses
  is :api_access_enabled, -> {
    (is?(:subscribed) || is?(:trial_active)) &&
    !is?(:suspended) &&
    !is?(:payment_overdue)
  }

  is :advanced_features_enabled, -> {
    ["professional", "enterprise"].include?(subscription_tier) &&
    is?(:subscribed)
  }

  is :white_label_enabled, -> {
    subscription_tier == "enterprise" &&
    is?(:subscribed) &&
    white_label_approved_at.present?
  }

  # Usage and limits statuses
  is :storage_limit_exceeded, -> {
    storage_used_mb >= storage_limit_mb
  }

  is :api_rate_limit_exceeded, -> {
    api_calls_this_month >= api_calls_monthly_limit
  }

  is :user_limit_reached, -> {
    users_count >= user_limit_for_tier
  }

  # Health and compliance statuses
  is :requires_payment_update, -> {
    (is?(:subscribed) || is?(:trial_expired)) &&
    payment_method_expires_at.present? &&
    payment_method_expires_at <= 30.days.from_now
  }

  is :data_export_requested, -> {
    data_export_requested_at.present? &&
    data_export_completed_at.nil?
  }

  is :deletion_scheduled, -> {
    deletion_scheduled_at.present? &&
    deletion_scheduled_at > Time.current
  }

  # Business logic using statuses
  def can_create_project?
    is?(:api_access_enabled) &&
    !is?(:user_limit_reached) &&
    !is?(:storage_limit_exceeded)
  end

  def requires_immediate_action?
    is?(:payment_overdue) ||
    is?(:trial_expired) ||
    is?(:storage_limit_exceeded)
  end

  def accessible_features
    features = [:basic_dashboard, :user_management]
    features << :api_access if is?(:api_access_enabled)
    features << :advanced_analytics if is?(:advanced_features_enabled)
    features << :white_label if is?(:white_label_enabled)
    features
  end

  private

  def user_limit_for_tier
    case subscription_tier
    when "trial", "starter" then 5
    when "professional" then 25
    when "enterprise" then 999
    else 1
    end
  end
end

# Usage in multi-tenant middleware
class TenantAccessMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    account = find_account_from_request(request)

    # Check access based on statuses
    if account.is_suspended?
      return [403, {}, ["Account suspended. Contact support."]]
    end

    if account.is_deletion_scheduled?
      return [410, {}, ["Account scheduled for deletion."]]
    end

    if request.path.start_with?("/api") && !account.is_api_access_enabled?
      return [402, {}, ["API access requires active subscription."]]
    end

    # Add account context to request
    env["current_account"] = account
    env["available_features"] = account.accessible_features

    @app.call(env)
  end

  private

  def find_account_from_request(request)
    # Extract account from subdomain, API key, etc.
  end
end

# Usage in controllers with role-based access
class DashboardController < ApplicationController
  before_action :check_account_status

  def index
    @account = current_account
    @warnings = []

    # Show contextual warnings based on statuses
    if @account.is_trial_active?
      days_left = ((@account.trial_ends_at - Time.current) / 1.day).ceil
      @warnings << "Trial expires in #{days_left} days"
    end

    if @account.is_payment_overdue?
      @warnings << "Payment overdue - update payment method"
    end

    if @account.is_storage_limit_exceeded?
      @warnings << "Storage limit exceeded - upgrade your plan"
    end

    if @account.is_requires_payment_update?
      @warnings << "Payment method expires soon - please update"
    end

    # Filter features based on status
    @available_features = @account.accessible_features
    @feature_counts = {
      users: @account.users_count,
      storage_used: "#{@account.storage_used_mb}MB / #{@account.storage_limit_mb}MB",
      api_calls: "#{@account.api_calls_this_month} / #{@account.api_calls_monthly_limit}"
    }
  end

  private

  def check_account_status
    if current_account.is_suspended?
      redirect_to suspended_path, alert: "Your account has been suspended"
    elsif current_account.is_deletion_scheduled?
      redirect_to deletion_notice_path
    elsif current_account.requires_immediate_action?
      redirect_to account_issues_path unless controller_name == "billing"
    end
  end
end
```

## Edge Cases and Advanced Usage

Advanced patterns for complex status scenarios

This section explores sophisticated Statusable patterns including status transitions with validations and guards, handling race conditions, performance optimization for status-heavy models, and integrating statuses with Rails state machines and callbacks.

### Status Transitions with Validations and Guards

```ruby
class Proposal < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: "User"
  belongs_to :reviewer, class_name: "User", optional: true

  # Workflow statuses
  is :draft, -> { workflow_state == "draft" }
  is :submitted, -> { workflow_state == "submitted" && submitted_at.present? }
  is :under_review, -> { workflow_state == "under_review" && reviewer_id.present? }
  is :approved, -> { workflow_state == "approved" && approved_at.present? }
  is :rejected, -> { workflow_state == "rejected" && rejected_at.present? }
  is :published, -> { workflow_state == "published" && published_at.present? }

  # Transition guard statuses
  is :ready_for_submission, -> {
    is?(:draft) &&
    title.present? &&
    content.present? &&
    word_count >= 100 &&
    author_id.present?
  }

  is :ready_for_review, -> {
    is?(:submitted) &&
    submitted_at >= 1.hour.ago && # Cooling-off period
    !is?(:has_blocking_issues)
  }

  is :ready_for_approval, -> {
    is?(:under_review) &&
    review_started_at.present? &&
    review_notes.present?
  }

  is :ready_for_publication, -> {
    is?(:approved) &&
    publication_date.present? &&
    publication_date >= Date.current
  }

  # Quality and validation statuses
  is :has_blocking_issues, -> {
    plagiarism_detected == true ||
    copyright_violations.present? ||
    is?(:missing_required_sections)
  }

  is :missing_required_sections, -> {
    required_sections = ["abstract", "methodology", "conclusion"]
    is?(:submitted) &&
    required_sections.any? { |section| !content_sections.include?(section) }
  }

  is :review_overdue, -> {
    is?(:under_review) &&
    review_due_at.present? &&
    review_due_at < Time.current
  }

  # State transition methods with guards
  def submit!
    raise TransitionError, "Proposal not ready for submission" unless is_ready_for_submission?

    transaction do
      update!(
        workflow_state: "submitted",
        submitted_at: Time.current,
        submission_version: submission_version + 1
      )

      notify_reviewers
      create_audit_log("submitted")
    end
  end

  def assign_reviewer!(reviewer)
    raise TransitionError, "Cannot assign reviewer" unless is_submitted?
    raise TransitionError, "Proposal has blocking issues" if is_has_blocking_issues?

    transaction do
      update!(
        workflow_state: "under_review",
        reviewer: reviewer,
        review_started_at: Time.current,
        review_due_at: 7.days.from_now
      )

      ProposalMailer.assigned_to_reviewer(self, reviewer).deliver_later
      create_audit_log("review_assigned", reviewer_id: reviewer.id)
    end
  end

  def approve!(notes:)
    raise TransitionError, "Not ready for approval" unless is_ready_for_approval?
    raise TransitionError, "Approval notes required" if notes.blank?

    transaction do
      update!(
        workflow_state: "approved",
        approved_at: Time.current,
        approval_notes: notes
      )

      ProposalMailer.approved(self).deliver_later
      create_audit_log("approved", notes: notes)
    end
  end

  def reject!(reason:)
    raise TransitionError, "Can only reject submitted or under_review proposals" unless is?(:submitted) || is?(:under_review)
    raise TransitionError, "Rejection reason required" if reason.blank?

    transaction do
      update!(
        workflow_state: "rejected",
        rejected_at: Time.current,
        rejection_reason: reason
      )

      ProposalMailer.rejected(self, reason).deliver_later
      create_audit_log("rejected", reason: reason)
    end
  end

  def publish!
    raise TransitionError, "Not ready for publication" unless is_ready_for_publication?

    transaction do
      update!(
        workflow_state: "published",
        published_at: Time.current,
        publication_url: generate_publication_url
      )

      index_for_search
      notify_subscribers
      create_audit_log("published")
    end
  end

  # Validation callbacks using statuses
  validate :validate_workflow_requirements
  validate :validate_transition_permissions, on: :update

  private

  def validate_workflow_requirements
    if is?(:submitted) && !is?(:ready_for_submission)
      errors.add(:base, "Proposal does not meet submission requirements")
    end

    if is?(:has_blocking_issues)
      errors.add(:base, "Proposal has blocking issues that must be resolved")
    end
  end

  def validate_transition_permissions
    # Only certain users can move to certain states
    if workflow_state_changed?
      case workflow_state
      when "under_review"
        unless Current.user&.reviewer?
          errors.add(:workflow_state, "Only reviewers can assign for review")
        end
      when "approved", "rejected"
        unless Current.user&.id == reviewer_id
          errors.add(:workflow_state, "Only assigned reviewer can approve/reject")
        end
      when "published"
        unless Current.user&.admin?
          errors.add(:workflow_state, "Only admins can publish")
        end
      end
    end
  end

  def create_audit_log(action, metadata = {})
    ProposalAuditLog.create!(
      proposal: self,
      user: Current.user,
      action: action,
      metadata: metadata,
      statuses_snapshot: statuses
    )
  end

  class TransitionError < StandardError; end
end

# Usage in controller with status-based authorization
class ProposalsController < ApplicationController
  def submit
    @proposal = current_user.proposals.find(params[:id])

    if @proposal.is_ready_for_submission?
      @proposal.submit!
      redirect_to @proposal, notice: "Proposal submitted successfully"
    else
      # Provide specific feedback based on statuses
      errors = []
      errors << "Title is required" if @proposal.title.blank?
      errors << "Content is required" if @proposal.content.blank?
      errors << "Minimum 100 words required" if @proposal.word_count < 100

      redirect_to edit_proposal_path(@proposal),
                  alert: "Cannot submit: #{errors.join(', ')}"
    end
  end

  def review_dashboard
    @proposals = Proposal.includes(:author, :reviewer)

    # Filter by status
    @submitted = @proposals.select { |p| p.is_ready_for_review? }
    @under_review = @proposals.select { |p| p.is_under_review? }
    @overdue = @proposals.select { |p| p.is_review_overdue? }
    @has_issues = @proposals.select { |p| p.is_has_blocking_issues? }
  end
end
```

### Handling Race Conditions and Performance Optimization

```ruby
class LimitedResource < ApplicationRecord
  include BetterModel

  # Status with database-level consistency check
  is :available, -> {
    !is?(:reserved) &&
    !is?(:locked) &&
    remaining_capacity > 0
  }

  is :reserved, -> {
    reserved_until.present? &&
    reserved_until > Time.current
  }

  is :locked, -> {
    locked_at.present? &&
    (locked_by_process_id == current_process_id || lock_expired?)
  }

  is :at_capacity, -> {
    remaining_capacity <= 0
  }

  # Cached status to avoid repeated calculations
  is :hot_resource, -> {
    # Use cached counter instead of counting associations
    requests_count >= 100 &&
    last_request_at >= 1.hour.ago
  }

  # Thread-safe reservation with pessimistic locking
  def reserve_with_lock!(duration: 1.hour)
    transaction do
      # Lock the row to prevent concurrent reservations
      lock!

      unless is_available?
        raise ReservationError, "Resource not available: #{unavailability_reason}"
      end

      update!(
        reserved_until: duration.from_now,
        reserved_by_user_id: Current.user.id,
        reserved_at: Time.current
      )

      # Refresh statuses after update
      reload
    end
  end

  # Optimistic locking approach for high-concurrency scenarios
  def try_reserve!(duration: 1.hour)
    # Check status without locking first (fast path)
    return false unless is_available?

    # Attempt update with version check
    updated = self.class.where(
      id: id,
      lock_version: lock_version
    ).where("remaining_capacity > 0").update_all(
      reserved_until: duration.from_now,
      reserved_by_user_id: Current.user.id,
      reserved_at: Time.current,
      lock_version: lock_version + 1
    )

    if updated > 0
      reload
      true
    else
      false # Lost race, someone else reserved it
    end
  end

  # Batch status checking for collections (performance optimization)
  def self.with_status_flags
    # Precompute commonly-checked statuses in a single query
    select(
      "#{table_name}.*",
      "CASE WHEN reserved_until IS NOT NULL AND reserved_until > NOW() THEN true ELSE false END as reserved_flag",
      "CASE WHEN remaining_capacity > 0 THEN true ELSE false END as available_flag",
      "CASE WHEN requests_count >= 100 AND last_request_at >= NOW() - INTERVAL '1 hour' THEN true ELSE false END as hot_flag"
    )
  end

  def self.available_resources
    # Optimized query that filters using database-level conditions
    # instead of loading all records and checking statuses
    where("reserved_until IS NULL OR reserved_until <= ?", Time.current)
      .where("remaining_capacity > 0")
      .where("locked_at IS NULL OR locked_at < ?", 1.hour.ago)
  end

  private

  def unavailability_reason
    return "Reserved until #{reserved_until}" if is_reserved?
    return "Locked by another process" if is_locked?
    return "At capacity" if is_at_capacity?
    "Unknown"
  end

  def lock_expired?
    locked_at < 5.minutes.ago
  end

  def current_process_id
    Process.pid.to_s
  end

  class ReservationError < StandardError; end
end

# Caching strategy for expensive status calculations
class Report < ApplicationRecord
  include BetterModel

  # Expensive status that queries large dataset
  is :processing_complete, -> {
    # Cache the result to avoid repeated queries
    Rails.cache.fetch("report_#{id}_processing_complete", expires_in: 5.minutes) do
      calculate_processing_complete
    end
  }

  # Invalidate cache when relevant data changes
  after_update :invalidate_status_caches, if: :saved_change_to_processed_rows?

  private

  def calculate_processing_complete
    processed_rows >= total_rows && errors_count == 0
  end

  def invalidate_status_caches
    Rails.cache.delete("report_#{id}_processing_complete")
  end
end
```

## Testing Statusable Models

Comprehensive testing strategies for status conditions and transitions

Testing Statusable models requires verifying status conditions under different states, testing status-based business logic, ensuring thread safety, and validating status transitions with guards. This section provides RSpec and Minitest examples covering unit tests, integration tests, and edge cases.

### RSpec Examples for Status Predicates

```ruby
# spec/models/article_spec.rb
require "rails_helper"

RSpec.describe Article, type: :model do
  describe "Statusable" do
    describe "status definitions" do
      it "defines all expected statuses" do
        expect(Article.defined_statuses).to include(
          :draft, :published, :scheduled, :archived,
          :popular, :trending, :recent
        )
      end

      it "checks if status is defined" do
        expect(Article.status_defined?(:published)).to be true
        expect(Article.status_defined?(:nonexistent)).to be false
      end
    end

    describe "#is_published?" do
      it "returns true when status is published and published_at is in the past" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago
        )

        expect(article.is_published?).to be true
        expect(article.is?(:published)).to be true
      end

      it "returns false when status is published but published_at is in the future" do
        article = create(:article,
          status: "published",
          published_at: 1.day.from_now
        )

        expect(article.is_published?).to be false
      end

      it "returns false when status is not published" do
        article = create(:article,
          status: "draft",
          published_at: 1.day.ago
        )

        expect(article.is_published?).to be false
      end

      it "returns false when published_at is nil" do
        article = create(:article,
          status: "published",
          published_at: nil
        )

        expect(article.is_published?).to be false
      end
    end

    describe "#is_scheduled?" do
      it "returns true when scheduled for future publication" do
        article = create(:article,
          status: "published",
          published_at: 2.days.from_now
        )

        expect(article.is_scheduled?).to be true
      end

      it "returns false when already published" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago
        )

        expect(article.is_scheduled?).to be false
      end
    end

    describe "#is_draft?" do
      it "returns true when status is draft" do
        article = create(:article, status: "draft")
        expect(article.is_draft?).to be true
      end

      it "returns false when status is not draft" do
        article = create(:article, status: "published")
        expect(article.is_draft?).to be false
      end
    end

    describe "#is_popular?" do
      it "returns true when views exceed threshold" do
        article = create(:article, views_count: 5001)
        expect(article.is_popular?).to be true
      end

      it "returns false when views are below threshold" do
        article = create(:article, views_count: 100)
        expect(article.is_popular?).to be false
      end

      it "handles edge case at exact threshold" do
        article = create(:article, views_count: 5000)
        expect(article.is_popular?).to be false # >= 5000, not >
      end
    end

    describe "#is_trending?" do
      it "returns true when popular and recent" do
        article = create(:article,
          views_count: 5001,
          created_at: 12.hours.ago
        )

        expect(article.is_trending?).to be true
      end

      it "returns false when popular but not recent" do
        article = create(:article,
          views_count: 5001,
          created_at: 2.days.ago
        )

        expect(article.is_trending?).to be false
      end

      it "returns false when recent but not popular" do
        article = create(:article,
          views_count: 100,
          created_at: 12.hours.ago
        )

        expect(article.is_trending?).to be false
      end
    end

    describe "#statuses" do
      it "returns hash of all statuses with boolean values" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago,
          views_count: 5001,
          created_at: 12.hours.ago
        )

        statuses = article.statuses

        expect(statuses).to be_a(Hash)
        expect(statuses[:published]).to be true
        expect(statuses[:draft]).to be false
        expect(statuses[:popular]).to be true
        expect(statuses[:trending]).to be true
      end

      it "reflects current state after attribute changes" do
        article = create(:article, status: "draft")

        expect(article.statuses[:draft]).to be true
        expect(article.statuses[:published]).to be false

        article.status = "published"
        article.published_at = 1.day.ago

        expect(article.statuses[:draft]).to be false
        expect(article.statuses[:published]).to be true
      end
    end

    describe "#has_any_status?" do
      it "returns true when at least one status is active" do
        article = create(:article, status: "draft")
        expect(article.has_any_status?).to be true
      end

      it "returns false when no statuses are active" do
        article = create(:article,
          status: "unknown",
          views_count: 0,
          archived_at: nil
        )
        # Assuming all statuses evaluate to false
        expect(article.has_any_status?).to be false
      end
    end

    describe "#has_all_statuses?" do
      it "returns true when all specified statuses are active" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago,
          views_count: 5001
        )

        expect(article.has_all_statuses?([:published, :popular])).to be true
      end

      it "returns false when any specified status is inactive" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago,
          views_count: 100
        )

        expect(article.has_all_statuses?([:published, :popular])).to be false
      end
    end

    describe "#active_statuses" do
      it "returns only active statuses from the provided list" do
        article = create(:article,
          status: "published",
          published_at: 1.day.ago,
          views_count: 5001
        )

        active = article.active_statuses([:draft, :published, :popular, :archived])

        expect(active).to include(:published, :popular)
        expect(active).not_to include(:draft, :archived)
      end

      it "returns empty array when no statuses are active" do
        article = create(:article, status: "draft")

        active = article.active_statuses([:published, :popular])

        expect(active).to be_empty
      end
    end
  end

  describe "JSON serialization" do
    let(:article) do
      create(:article,
        status: "published",
        published_at: 1.day.ago,
        views_count: 5001
      )
    end

    it "excludes statuses by default" do
      json = article.as_json

      expect(json).to have_key("id")
      expect(json).to have_key("status")
      expect(json).not_to have_key("statuses")
    end

    it "includes statuses when requested" do
      json = article.as_json(include_statuses: true)

      expect(json).to have_key("statuses")
      expect(json["statuses"]).to be_a(Hash)
      expect(json["statuses"]["published"]).to be true
      expect(json["statuses"]["draft"]).to be false
    end

    it "includes all defined statuses in JSON output" do
      json = article.as_json(include_statuses: true)
      statuses_keys = json["statuses"].keys.map(&:to_sym)

      Article.defined_statuses.each do |status|
        expect(statuses_keys).to include(status)
      end
    end
  end

  describe "compound status conditions" do
    describe "statuses referencing other statuses" do
      before do
        stub_const("CompoundArticle", Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel

          is :published, -> { status == "published" }
          is :not_expired, -> { expires_at.nil? || expires_at > Time.current }
          is :publicly_visible, -> { is?(:published) && is?(:not_expired) }
        end)
      end

      it "evaluates compound status correctly" do
        article = CompoundArticle.create!(
          title: "Test",
          status: "published",
          expires_at: 1.day.from_now
        )

        expect(article.is_published?).to be true
        expect(article.is_not_expired?).to be true
        expect(article.is_publicly_visible?).to be true
      end

      it "returns false when any referenced status is false" do
        article = CompoundArticle.create!(
          title: "Test",
          status: "published",
          expires_at: 1.day.ago
        )

        expect(article.is_published?).to be true
        expect(article.is_not_expired?).to be false
        expect(article.is_publicly_visible?).to be false
      end
    end
  end

  describe "thread safety" do
    it "evaluates statuses independently across instances" do
      article1 = create(:article, status: "published")
      article2 = create(:article, status: "draft")

      threads = []

      threads << Thread.new do
        100.times { expect(article1.is_published?).to be true }
      end

      threads << Thread.new do
        100.times { expect(article2.is_draft?).to be true }
      end

      threads.each(&:join)
    end
  end

  describe "error handling" do
    it "returns false for undefined status checks with is?" do
      article = create(:article)
      expect(article.is?(:nonexistent_status)).to be false
    end

    it "raises NoMethodError for undefined predicate methods" do
      article = create(:article)
      expect { article.is_nonexistent_status? }.to raise_error(NoMethodError)
    end
  end
end
```

### Minitest Examples for Status Transitions

```ruby
# test/models/proposal_test.rb
require "test_helper"

class ProposalTest < ActiveSupport::TestCase
  test "defines all workflow statuses" do
    expected_statuses = [:draft, :submitted, :under_review, :approved, :rejected, :published]
    assert_equal expected_statuses.sort, Proposal.defined_statuses.sort
  end

  # Testing status predicates
  test "draft status is true for new proposals" do
    proposal = proposals(:draft_proposal)
    assert proposal.is_draft?
    assert proposal.is?(:draft)
  end

  test "submitted status requires workflow_state and timestamp" do
    proposal = proposals(:submitted_proposal)
    proposal.update!(workflow_state: "submitted", submitted_at: Time.current)

    assert proposal.is_submitted?
    refute proposal.is_draft?
  end

  test "approved status requires workflow_state and approved_at" do
    proposal = proposals(:approved_proposal)

    assert proposal.is_approved?
    assert proposal.approved_at.present?
  end

  # Testing guard statuses
  test "ready_for_submission requires minimum content" do
    proposal = Proposal.new(
      title: "Test Proposal",
      content: "A" * 150, # 150 words
      word_count: 150,
      workflow_state: "draft"
    )

    assert proposal.is_ready_for_submission?
  end

  test "not ready_for_submission with insufficient content" do
    proposal = Proposal.new(
      title: "Test",
      content: "Too short",
      word_count: 2,
      workflow_state: "draft"
    )

    refute proposal.is_ready_for_submission?
  end

  test "ready_for_review requires cooling-off period" do
    recent_submission = proposals(:just_submitted)
    recent_submission.update!(submitted_at: 30.minutes.ago)

    refute recent_submission.is_ready_for_review?

    old_submission = proposals(:old_submission)
    old_submission.update!(submitted_at: 2.hours.ago)

    assert old_submission.is_ready_for_review?
  end

  # Testing state transitions
  test "submit! transitions from draft to submitted" do
    proposal = proposals(:draft_proposal)
    proposal.update!(
      title: "Complete Proposal",
      content: "A" * 150,
      word_count: 150
    )

    assert proposal.is_ready_for_submission?

    proposal.submit!

    assert proposal.is_submitted?
    assert_equal "submitted", proposal.workflow_state
    assert_not_nil proposal.submitted_at
    assert_equal 1, proposal.submission_version
  end

  test "submit! raises error when not ready" do
    proposal = proposals(:draft_proposal)
    proposal.update!(content: "Too short", word_count: 5)

    error = assert_raises(Proposal::TransitionError) do
      proposal.submit!
    end

    assert_match /not ready for submission/i, error.message
  end

  test "assign_reviewer! transitions to under_review" do
    proposal = proposals(:submitted_proposal)
    reviewer = users(:reviewer_user)

    proposal.assign_reviewer!(reviewer)

    assert proposal.is_under_review?
    assert_equal reviewer, proposal.reviewer
    assert_not_nil proposal.review_started_at
    assert_not_nil proposal.review_due_at
  end

  test "assign_reviewer! raises error for non-submitted proposals" do
    proposal = proposals(:draft_proposal)
    reviewer = users(:reviewer_user)

    assert_raises(Proposal::TransitionError) do
      proposal.assign_reviewer!(reviewer)
    end
  end

  test "approve! transitions to approved with notes" do
    proposal = proposals(:under_review_proposal)
    proposal.update!(review_notes: "Looks good")

    proposal.approve!(notes: "Approved for publication")

    assert proposal.is_approved?
    assert_equal "approved", proposal.workflow_state
    assert_not_nil proposal.approved_at
    assert_equal "Approved for publication", proposal.approval_notes
  end

  test "approve! raises error without notes" do
    proposal = proposals(:under_review_proposal)

    assert_raises(Proposal::TransitionError) do
      proposal.approve!(notes: "")
    end
  end

  test "reject! transitions to rejected with reason" do
    proposal = proposals(:under_review_proposal)

    proposal.reject!(reason: "Insufficient evidence")

    assert proposal.is_rejected?
    assert_equal "rejected", proposal.workflow_state
    assert_not_nil proposal.rejected_at
    assert_equal "Insufficient evidence", proposal.rejection_reason
  end

  test "reject! can be called from submitted state" do
    proposal = proposals(:submitted_proposal)

    proposal.reject!(reason: "Does not meet guidelines")

    assert proposal.is_rejected?
  end

  test "publish! transitions to published" do
    proposal = proposals(:approved_proposal)
    proposal.update!(publication_date: Date.current)

    proposal.publish!

    assert proposal.is_published?
    assert_not_nil proposal.published_at
    assert_not_nil proposal.publication_url
  end

  # Testing status-based validations
  test "validates workflow requirements on save" do
    proposal = Proposal.new(
      title: "Test",
      content: "Short",
      word_count: 1,
      workflow_state: "submitted" # Invalid: doesn't meet requirements
    )

    refute proposal.valid?
    assert_includes proposal.errors[:base], "Proposal does not meet submission requirements"
  end

  test "has_blocking_issues prevents review assignment" do
    proposal = proposals(:submitted_proposal)
    proposal.update!(plagiarism_detected: true)

    assert proposal.is_has_blocking_issues?

    reviewer = users(:reviewer_user)

    assert_raises(Proposal::TransitionError) do
      proposal.assign_reviewer!(reviewer)
    end
  end

  # Testing helper methods
  test "statuses returns current state snapshot" do
    proposal = proposals(:approved_proposal)
    statuses = proposal.statuses

    assert_equal true, statuses[:approved]
    assert_equal false, statuses[:draft]
    assert_equal false, statuses[:rejected]
  end

  test "active_statuses filters to currently active statuses" do
    proposal = proposals(:submitted_proposal)
    proposal.update!(submitted_at: 2.hours.ago)

    active = proposal.active_statuses([:draft, :submitted, :ready_for_review, :published])

    assert_includes active, :submitted
    assert_includes active, :ready_for_review
    refute_includes active, :draft
    refute_includes active, :published
  end

  test "has_all_statuses? checks multiple status conditions" do
    proposal = proposals(:under_review_proposal)
    proposal.update!(review_notes: "In progress")

    assert proposal.has_all_statuses?([:submitted, :under_review])
    refute proposal.has_all_statuses?([:under_review, :approved])
  end

  # Testing JSON serialization
  test "as_json includes statuses when requested" do
    proposal = proposals(:approved_proposal)
    json = proposal.as_json(include_statuses: true)

    assert json.key?("statuses")
    assert_equal true, json["statuses"]["approved"]
    assert_equal false, json["statuses"]["draft"]
  end

  test "as_json excludes statuses by default" do
    proposal = proposals(:approved_proposal)
    json = proposal.as_json

    refute json.key?("statuses")
  end
end
```

## Best Practices

Guidelines for effective Statusable usage

When implementing Statusable in production applications, follow these best practices: Keep status condition blocks simple and readable by extracting complex logic into private methods; avoid database queries within status conditions and instead use loaded associations or cached counters; reference other statuses using `is?(:other_status)` when building compound conditions to improve maintainability; choose descriptive status names that clearly indicate what the status represents; add code comments to explain non-obvious business logic; prefer statuses over storing computed boolean columns in the database for values that can be derived from existing data; use status checks in model validations and callbacks to enforce business rules; test status conditions thoroughly with different model states to ensure correct behavior.

```ruby
# GOOD: Simple, readable conditions
class Order < ApplicationRecord
  include BetterModel

  is :paid, -> { payment_status == "paid" }
  is :shipped, -> { shipped_at.present? }
  is :refundable, -> { is?(:paid) && !is?(:shipped) }
end

# AVOID: Complex inline logic
class Order < ApplicationRecord
  include BetterModel

  is :complex_status, -> {
    (payment_status == "paid" || payment_status == "authorized") &&
    (line_items.sum(&:total) >= 100 || discount_applied?) &&
    created_at >= 30.days.ago &&
    !shipped_at.present?
  }
end

# BETTER: Extract complex logic to private methods
class Order < ApplicationRecord
  include BetterModel

  is :eligible_for_free_shipping, -> { meets_shipping_criteria? }

  private

  def meets_shipping_criteria?
    payment_completed? &&
    subtotal_qualifies? &&
    within_promotion_period? &&
    not_yet_shipped?
  end

  def payment_completed?
    ["paid", "authorized"].include?(payment_status)
  end

  def subtotal_qualifies?
    line_items.sum(&:total) >= 100 || discount_applied?
  end

  def within_promotion_period?
    created_at >= 30.days.ago
  end

  def not_yet_shipped?
    shipped_at.nil?
  end
end

# AVOID: Database queries in status conditions
class User < ApplicationRecord
  include BetterModel

  # Bad: Triggers N+1 queries
  is :has_orders, -> { orders.exists? }
  is :has_recent_activity, -> { events.where("created_at > ?", 7.days.ago).any? }
end

# BETTER: Use cached counters or loaded associations
class User < ApplicationRecord
  include BetterModel

  # Use counter cache
  is :has_orders, -> { orders_count > 0 }

  # Use timestamp column
  is :recently_active, -> {
    last_activity_at.present? && last_activity_at >= 7.days.ago
  }

  # Or use loaded associations when available
  is :has_pending_orders, -> {
    orders.loaded? && orders.any? { |o| o.status == "pending" }
  }
end

# GOOD: Reference other statuses for compound conditions
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" && published_at <= Time.current }
  is :not_expired, -> { expires_at.nil? || expires_at > Time.current }
  is :premium, -> { premium_content == true }

  # Build on existing statuses
  is :publicly_accessible, -> {
    is?(:published) && is?(:not_expired) && !is?(:premium)
  }
end

# GOOD: Descriptive status names
is :refundable, -> { ... }           # Clear intent
is :eligible_for_discount, -> { ... } # Describes what it means

# AVOID: Vague status names
is :status1, -> { ... }               # Meaningless
is :check, -> { ... }                 # Too vague

# GOOD: Document complex business logic
class Consultation < ApplicationRecord
  include BetterModel

  # Status indicates the consultation can be billed to the client.
  # Requirements:
  # - Must be completed status
  # - Duration must be at least 15 minutes (billing minimum)
  # - Must not have been cancelled
  # - Must not have already been billed
  is :billable, -> {
    status == "completed" &&
    duration_minutes >= 15 &&
    !is?(:cancelled) &&
    billed_at.nil?
  }
end

# GOOD: Use statuses in validations
class Event < ApplicationRecord
  include BetterModel

  is :registration_open, -> {
    registration_opens_at <= Time.current &&
    registration_closes_at > Time.current
  }

  validate :registration_must_be_open, on: :create

  private

  def registration_must_be_open
    unless is_registration_open?
      errors.add(:base, "Registration is not currently open")
    end
  end
end

# GOOD: Test thoroughly
# spec/models/order_spec.rb
RSpec.describe Order, type: :model do
  describe "statusable" do
    describe "#is_refundable?" do
      it "returns true when paid and not shipped" do
        order = create(:order, payment_status: "paid", shipped_at: nil)
        expect(order.is_refundable?).to be true
      end

      it "returns false when not paid" do
        order = create(:order, payment_status: "pending", shipped_at: nil)
        expect(order.is_refundable?).to be false
      end

      it "returns false when already shipped" do
        order = create(:order, payment_status: "paid", shipped_at: 1.day.ago)
        expect(order.is_refundable?).to be false
      end
    end
  end
end
```

## Thread Safety and Error Handling

Concurrent access guarantees and validation behavior

Statusable is designed to be thread-safe for concurrent request handling in Rails applications. Status definitions are frozen immediately after registration, the internal status registry is implemented as an immutable frozen hash, and no shared mutable state exists between model instances. Each status evaluation occurs in the context of a specific model instance using its current attribute values, ensuring that concurrent requests operating on different instances cannot interfere with each other.

The system validates status definitions at class load time and raises ArgumentError for invalid configurations. Common errors include missing condition blocks, blank status names, and non-callable condition objects. When checking undefined statuses at runtime, Statusable follows a secure-by-default approach and returns false rather than raising an error, allowing code to gracefully handle status names that may not be defined on all model classes.

```ruby
# Thread Safety: Status definitions are frozen
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  # The status definition is immediately frozen
  # The registry is frozen and immutable
  # Safe for concurrent access
end

# Thread Safety: Instance evaluation is isolated
# Thread 1
article1 = Article.find(1)
article1.is_published?  # Evaluates against article1's attributes

# Thread 2 (running concurrently)
article2 = Article.find(2)
article2.is_published?  # Evaluates against article2's attributes
# No interference between threads

# Error Handling: Validation at definition time
class Article < ApplicationRecord
  include BetterModel

  # ERROR: Missing condition
  is :test_status
  # => ArgumentError: Condition proc or block is required

  # ERROR: Blank status name
  is "", -> { true }
  # => ArgumentError: Status name cannot be blank

  # ERROR: Non-callable condition
  is :test, "not a proc"
  # => ArgumentError: Condition must respond to call
end

# Error Handling: Undefined status checks (secure by default)
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
end

article = Article.new

# Checking a defined status
article.is?(:published)  # => true or false (evaluates condition)

# Checking an undefined status returns false (does not raise error)
article.is?(:nonexistent_status)  # => false (secure by default)
article.is_nonexistent_status?    # => NoMethodError (method doesn't exist)

# Use status_defined? to check before evaluating
if Article.status_defined?(:published)
  result = article.is?(:published)
else
  # Handle undefined status
end

# Practical example: Safe status checking with fallback
class StatusChecker
  def self.safe_check(model, status_name)
    return false unless model.class.respond_to?(:status_defined?)
    return false unless model.class.status_defined?(status_name)

    model.is?(status_name)
  end
end

# Usage
StatusChecker.safe_check(article, :published)     # => true/false
StatusChecker.safe_check(article, :nonexistent)   # => false (safe)
StatusChecker.safe_check("not a model", :test)    # => false (safe)
```
