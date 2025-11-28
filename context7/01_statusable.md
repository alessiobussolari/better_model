# 1. Statusable - Dynamic Boolean Status Management

**BetterModel v3.0.0+**: Define computed boolean statuses with conditional logic.

## Overview

Statusable provides dynamic status management where statuses are computed on-demand based on model state, rather than stored as database values.

**Key features**:
- Define statuses with lambda conditions
- Auto-generated predicate methods (`is_status?`)
- Unified status checking (`is?(:status)`)
- No database migrations required
- Thread-safe with frozen definitions

## Requirements

- Rails 8.0+
- Ruby 3.3+
- ActiveRecord 8.0+
- BetterModel ~> 3.0.0

---

## Complete User Model Example

### User with Active Status Based on last_login_at

**Cosa fa**: User model with active status determined by last_login_at timestamp

**Quando usarlo**: User management, activity tracking, session management

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  # Active status: logged in within the last 30 days
  is :active, -> { last_login_at && last_login_at >= 30.days.ago }

  # Inactive: no login for 30+ days
  is :inactive, -> { last_login_at.nil? || last_login_at < 30.days.ago }

  # Recently active: logged in within 24 hours
  is :recently_active, -> { last_login_at && last_login_at >= 24.hours.ago }

  # Dormant: no login for 90+ days
  is :dormant, -> { last_login_at.nil? || last_login_at < 90.days.ago }

  # At risk of churn: active but engagement declining
  is :at_risk, -> {
    last_login_at &&
    last_login_at.between?(14.days.ago, 30.days.ago)
  }

  # Never logged in (new account)
  is :never_logged_in, -> { last_login_at.nil? }

  # VIP: premium tier AND active
  is :vip, -> { tier == "premium" && is?(:active) }
end

# Usage examples
user = User.find(1)

# Check activity status
user.is_active?            # => true (if logged in within 30 days)
user.is_inactive?          # => false
user.is_recently_active?   # => true (if logged in within 24h)
user.is_dormant?           # => false
user.is_at_risk?           # => false
user.is_never_logged_in?   # => false

# Get all statuses
user.statuses
# => {
#   active: true,
#   inactive: false,
#   recently_active: true,
#   dormant: false,
#   at_risk: false,
#   never_logged_in: false,
#   vip: false
# }

# Use in conditional logic
if user.is_dormant?
  UserMailer.reengagement_email(user).deliver_later
elsif user.is_at_risk?
  UserMailer.retention_offer(user).deliver_later
end

# Filter users by status
all_users = User.all
active_users = all_users.select(&:is_active?)
dormant_users = all_users.select(&:is_dormant?)
```

---

### Activity-Based User Segmentation

**Cosa fa**: Segment users based on activity patterns for marketing/analytics

**Quando usarlo**: User analytics, marketing automation, engagement tracking

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  # Activity tiers based on last_login_at
  is :active, -> { last_login_at && last_login_at >= 30.days.ago }
  is :churned, -> { last_login_at && last_login_at < 90.days.ago }
  is :new_user, -> { created_at >= 7.days.ago }

  # Engagement levels
  is :power_user, -> {
    is?(:active) && login_count >= 20 && last_login_at >= 3.days.ago
  }

  is :regular_user, -> {
    is?(:active) && login_count.between?(5, 19)
  }

  is :casual_user, -> {
    is?(:active) && login_count < 5
  }

  # Lifecycle stages
  is :onboarding, -> {
    is?(:new_user) && !profile_completed?
  }

  is :activated, -> {
    is?(:new_user) && profile_completed? && first_action_at.present?
  }

  # Segment for re-engagement campaigns
  def self.segment_for_reengagement
    all.select do |user|
      user.is?(:churned) ||
      (user.is?(:active) && user.is?(:casual_user))
    end
  end

  # Get user engagement tier
  def engagement_tier
    case
    when is_power_user? then :power
    when is_regular_user? then :regular
    when is_casual_user? then :casual
    when is_churned? then :churned
    else :unknown
    end
  end
end

# Usage
user = User.find(1)
user.engagement_tier           # => :regular
user.is_power_user?            # => false
user.is_regular_user?          # => true

# Batch operations
User.all.group_by(&:engagement_tier)
# => {
#   power: [<User>, <User>],
#   regular: [<User>, <User>, <User>],
#   casual: [<User>],
#   churned: [<User>, <User>]
# }
```

---

### Admin Dashboard with User Activity Stats

**Cosa fa**: Dashboard controller using activity statuses

**Quando usarlo**: Admin panels, user management interfaces

**Esempio**:
```ruby
class Admin::DashboardController < Admin::BaseController
  def user_activity_stats
    users = User.all

    @stats = {
      total: users.count,
      active: users.count(&:is_active?),
      inactive: users.count(&:is_inactive?),
      recently_active: users.count(&:is_recently_active?),
      dormant: users.count(&:is_dormant?),
      never_logged_in: users.count(&:is_never_logged_in?),
      at_risk: users.count(&:is_at_risk?)
    }

    # Calculate percentages
    @stats[:active_rate] = (@stats[:active].to_f / @stats[:total] * 100).round(1)
    @stats[:churn_risk_rate] = (@stats[:at_risk].to_f / @stats[:active] * 100).round(1)

    render json: @stats
  end

  def users_needing_attention
    @at_risk = User.all.select(&:is_at_risk?).first(50)
    @dormant = User.all.select(&:is_dormant?).first(50)
    @never_logged_in = User.all.select(&:is_never_logged_in?).first(50)

    render json: {
      at_risk: @at_risk.map { |u| user_summary(u) },
      dormant: @dormant.map { |u| user_summary(u) },
      never_logged_in: @never_logged_in.map { |u| user_summary(u) }
    }
  end

  private

  def user_summary(user)
    {
      id: user.id,
      email: user.email,
      last_login_at: user.last_login_at,
      days_since_login: user.last_login_at ? ((Time.current - user.last_login_at) / 1.day).to_i : nil,
      statuses: user.statuses
    }
  end
end
```

---

## Installation

No migration required. Statusable is automatically available when you include BetterModel:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses with the 'is' method
  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }
end
```

---

## Core Features

### Basic Status Declaration

**Cosa fa**: Define a named status with a boolean condition

**Quando usarlo**: For any computed state that depends on model attributes

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Simple attribute check
  is :published, -> { status == "published" }

  # Date/time comparison
  is :recent, -> { created_at >= 7.days.ago }

  # Numeric threshold
  is :popular, -> { views_count >= 1000 }

  # Null/presence check
  is :archived, -> { archived_at.present? }
end

article = Article.create(status: "published", views_count: 1500)
article.is_published?  # => true
article.is_popular?    # => true
```

---

### Multiple Condition Types

**Cosa fa**: Combine different types of conditions in status definitions

**Quando usarlo**: When status depends on multiple attributes or complex logic

**Esempio**:

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Compound condition with AND
  is :cancellable, -> {
    status == "pending" && created_at >= 1.hour.ago
  }

  # Multiple attribute checks
  is :ready_to_ship, -> {
    payment_status == "paid" &&
    items_packed == true &&
    shipping_label_generated?
  }

  # Range check
  is :high_value, -> { total_amount.between?(1000, 10000) }
end
```

---

### Predicate Methods

**Cosa fa**: Auto-generated methods for each status following `is_status_name?` pattern

**Quando usarlo**: For readable, IDE-friendly status checks

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :expired, -> { expires_at && expires_at <= Time.current }
end

article = Article.find(1)

# Auto-generated predicate methods
article.is_draft?      # => false
article.is_published?  # => true
article.is_expired?    # => false

# Use in conditionals
if article.is_published? && !article.is_expired?
  puts "Article is live!"
end
```

---

### Unified Status Check

**Cosa fa**: Check any status using `is?(:status_name)` method

**Quando usarlo**: When status name is dynamic or stored in a variable

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }
  is :archived, -> { archived_at.present? }
end

article = Article.find(1)

# Static check (same as predicate method)
article.is?(:published)  # => true

# Dynamic check (useful when status name varies)
status_to_check = params[:status]&.to_sym
if article.is?(status_to_check)
  puts "Article has status: #{status_to_check}"
end

# Loop through statuses
[:published, :draft, :archived].each do |status|
  puts "#{status}: #{article.is?(status)}"
end
```

---

### Get All Statuses

**Cosa fa**: Return hash of all statuses with their current boolean values

**Quando usarlo**: For debugging, logging, API responses, or bulk status checks

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :popular, -> { views_count >= 1000 }
  is :recent, -> { created_at >= 7.days.ago }
end

article = Article.create(
  status: "published",
  views_count: 1500,
  created_at: 2.days.ago
)

# Get all statuses as hash
article.statuses
# => {
#   draft: false,
#   published: true,
#   popular: true,
#   recent: true
# }

# Useful for API responses
def show
  render json: {
    article: @article,
    statuses: @article.statuses
  }
end

# Useful for logging
Rails.logger.info("Article #{article.id} statuses: #{article.statuses.inspect}")
```

---

### Check Any Status Active

**Cosa fa**: Check if at least one defined status is true

**Quando usarlo**: To verify a model has any active status

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }
  is :archived, -> { archived_at.present? }
end

article = Article.new(status: "unknown")

# Check if ANY status is true
article.has_any_status?  # => false (all statuses are false)

article.status = "published"
article.has_any_status?  # => true (at least one status is true)

# Practical use
unless article.has_any_status?
  errors.add(:base, "Article must have at least one active status")
end
```

---

### Check Multiple Statuses

**Cosa fa**: Verify that all specified statuses are true

**Quando usarlo**: When multiple conditions must be met simultaneously

**Esempio**:

```ruby
class Order < ApplicationRecord
  include BetterModel

  is :paid, -> { payment_status == "paid" }
  is :packed, -> { packing_status == "complete" }
  is :label_printed, -> { shipping_label.present? }
end

order = Order.find(1)

# Check if ALL specified statuses are true
order.has_all_statuses?([:paid, :packed, :label_printed])  # => true/false

# Practical use in business logic
def ready_to_ship?
  has_all_statuses?([:paid, :packed, :label_printed])
end

def ship!
  raise "Order not ready" unless ready_to_ship?

  update!(status: "shipped", shipped_at: Time.current)
end
```

---

### Filter Active Statuses

**Cosa fa**: Return only the statuses that are currently true from a given list

**Quando usarlo**: To see which specific statuses are active

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :popular, -> { views_count >= 1000 }
  is :trending, -> { views_count >= 500 && created_at >= 24.hours.ago }
  is :featured, -> { featured_at.present? }
  is :expired, -> { expires_at && expires_at <= Time.current }
end

article = Article.find(1)

# Get only active statuses from the list
checks = [:published, :popular, :trending, :featured, :expired]
active = article.active_statuses(checks)
# => [:published, :popular, :trending]  (only the true ones)

# Practical use in UI
def badge_labels
  checks = [:popular, :trending, :featured]
  active_statuses(checks).map { |s| s.to_s.titleize }
  # => ["Popular", "Trending"]
end
```

---

### Class-Level Status Introspection

**Cosa fa**: Query which statuses are defined on a model class

**Quando usarlo**: For metaprogramming, validation, or building dynamic interfaces

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }
  is :archived, -> { archived_at.present? }
end

# Get all defined status names
Article.defined_statuses
# => [:published, :draft, :archived]

# Check if specific status is defined
Article.status_defined?(:published)  # => true
Article.status_defined?(:unknown)    # => false

# Practical use: validate status parameter
def filter_by_status(status_name)
  unless Article.status_defined?(status_name.to_sym)
    raise "Invalid status: #{status_name}. " \
          "Available: #{Article.defined_statuses.join(', ')}"
  end

  Article.all.select { |article| article.is?(status_name.to_sym) }
end

# Metaprogramming example
Article.defined_statuses.each do |status_name|
  define_method("count_#{status_name}") do
    Article.all.count { |a| a.is?(status_name) }
  end
end
```

---

### JSON Serialization with Statuses

**Cosa fa**: Include status hash in JSON output

**Quando usarlo**: For API clients that need status information

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :popular, -> { views_count >= 1000 }
  is :recent, -> { created_at >= 7.days.ago }
end

article = Article.find(1)

# Default: statuses NOT included
article.as_json
# => { "id" => 1, "title" => "Rails 8", "status" => "published", ... }

# Include statuses with option
article.as_json(include_statuses: true)
# => {
#   "id" => 1,
#   "title" => "Rails 8",
#   "status" => "published",
#   "statuses" => {
#     "published" => true,
#     "popular" => true,
#     "recent" => false
#   }
# }

# In controller
def show
  render json: @article.as_json(
    include_statuses: current_user.admin?
  )
end
```

---

### Referencing Other Statuses

**Cosa fa**: Build compound statuses by referencing previously defined statuses

**Quando usarlo**: To create hierarchical or dependent status relationships

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Base statuses
  is :published, -> { status == "published" }
  is :not_expired, -> { expires_at.nil? || expires_at > Time.current }
  is :premium, -> { premium_content == true }

  # Compound status using other statuses
  is :publicly_visible, -> {
    is?(:published) && is?(:not_expired) && !is?(:premium)
  }

  is :requires_subscription, -> {
    is?(:published) && is?(:premium)
  }
end

article = Article.create(
  status: "published",
  expires_at: 1.week.from_now,
  premium_content: false
)

article.is_publicly_visible?      # => true
article.is_requires_subscription? # => false
```

---

## Advanced Usage

### Complex Business Logic

**Cosa fa**: Use statuses in validations, callbacks, and business methods

**Quando usarlo**: To enforce business rules based on computed statuses

**Esempio**:

```ruby
class Order < ApplicationRecord
  include BetterModel

  is :paid, -> { payment_status == "paid" }
  is :shipped, -> { shipped_at.present? }
  is :cancellable, -> { is?(:paid) && !is?(:shipped) }
  is :refundable, -> {
    is?(:paid) && !is?(:shipped) && created_at >= 30.days.ago
  }

  # Use in validation
  validate :cannot_ship_unpaid_order

  # Use in business logic
  def cancel!
    raise "Order not cancellable" unless is_cancellable?

    transaction do
      update!(status: "cancelled", cancelled_at: Time.current)
      refund_payment if is?(:paid)
    end
  end

  def request_refund!
    raise "Order not refundable" unless is_refundable?

    update!(refund_requested_at: Time.current)
    RefundProcessor.process(self)
  end

  private

  def cannot_ship_unpaid_order
    if status == "shipped" && !is_paid?
      errors.add(:base, "Cannot ship unpaid order")
    end
  end
end
```

---

### Time-Based Statuses

**Cosa fa**: Define statuses based on date/time comparisons

**Quando usarlo**: For scheduling, expiration, recency checks

**Esempio**:

```ruby
class Event < ApplicationRecord
  include BetterModel

  # Scheduling statuses
  is :upcoming, -> { starts_at > Time.current }
  is :ongoing, -> {
    starts_at <= Time.current && ends_at >= Time.current
  }
  is :finished, -> { ends_at < Time.current }

  # Registration period
  is :registration_open, -> {
    registration_opens_at <= Time.current &&
    registration_closes_at > Time.current
  }

  is :registration_closed, -> {
    registration_closes_at <= Time.current
  }

  # Time ranges
  is :starts_soon, -> {
    is?(:upcoming) &&
    starts_at <= 24.hours.from_now
  }

  is :needs_reminder, -> {
    is?(:upcoming) &&
    starts_at <= 1.hour.from_now &&
    reminder_sent_at.nil?
  }
end

event = Event.find(1)

# Check scheduling
event.is_ongoing?   # => true

# Send reminders
Event.all.each do |event|
  if event.is_needs_reminder?
    EventMailer.reminder(event).deliver_later
    event.update!(reminder_sent_at: Time.current)
  end
end
```

---

### Association-Based Statuses

**Cosa fa**: Use loaded associations or cached counters in status conditions

**Quando usarlo**: When status depends on related records (avoid N+1 queries)

**Esempio**:

```ruby
class Project < ApplicationRecord
  include BetterModel
  has_many :tasks

  # Use counter cache (efficient)
  is :has_tasks, -> { tasks_count > 0 }

  # Use loaded associations (when already loaded)
  is :all_tasks_complete, -> {
    tasks.loaded? && tasks.all? { |t| t.status == "complete" }
  }

  is :has_overdue_tasks, -> {
    tasks.loaded? &&
    tasks.any? { |t| t.due_date && t.due_date < Time.current }
  }

  # Use cached calculation
  is :at_risk, -> {
    completion_percentage < 50 &&
    due_date &&
    due_date <= 7.days.from_now
  }
end

# Efficient usage
projects = Project.includes(:tasks).all

projects.each do |project|
  # Tasks are already loaded, no N+1
  if project.is_has_overdue_tasks?
    puts "Project #{project.name} has overdue tasks"
  end
end
```

---

### Thread-Safe Status Evaluation

**Cosa fa**: Ensure statuses evaluate correctly in concurrent requests

**Quando usarlo**: Always (built-in behavior, just be aware)

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  # Status definition is frozen at class load time
  # Registry is immutable - thread-safe
end

# Thread 1
Thread.new do
  article = Article.find(1)
  article.is_published?  # Evaluates against article 1's attributes
end

# Thread 2 (concurrent)
Thread.new do
  article = Article.find(2)
  article.is_published?  # Evaluates against article 2's attributes
  # No interference with Thread 1
end

# Each instance evaluates independently
# No shared mutable state
# Fully thread-safe
```

---

## Best Practices

### Keep Conditions Simple

**Cosa fa**: Extract complex logic into private methods

**Quando usarlo**: When status condition has multiple steps or complex logic

**Esempio**:

```ruby
# ❌ BAD: Complex inline logic
class Order < ApplicationRecord
  include BetterModel

  is :eligible_for_discount, -> {
    (payment_status == "paid" || payment_status == "authorized") &&
    (items.sum(&:price) >= 100 || coupon_applied?) &&
    created_at >= promotion_start_date &&
    created_at <= promotion_end_date &&
    !discount_already_applied?
  }
end

# ✅ GOOD: Extract to private method
class Order < ApplicationRecord
  include BetterModel

  is :eligible_for_discount, -> { meets_discount_criteria? }

  private

  def meets_discount_criteria?
    payment_completed? &&
    subtotal_qualifies? &&
    within_promotion_period? &&
    !discount_already_applied?
  end

  def payment_completed?
    ["paid", "authorized"].include?(payment_status)
  end

  def subtotal_qualifies?
    items.sum(&:price) >= 100 || coupon_applied?
  end

  def within_promotion_period?
    created_at.between?(promotion_start_date, promotion_end_date)
  end
end
```

---

### Avoid Database Queries

**Cosa fa**: Use cached counters or timestamps instead of queries

**Quando usarlo**: Always (to prevent N+1 queries and performance issues)

**Esempio**:

```ruby
# ❌ BAD: Triggers database query every time
class User < ApplicationRecord
  include BetterModel

  is :has_orders, -> { orders.exists? }
  is :active_last_week, -> {
    activities.where("created_at > ?", 7.days.ago).any?
  }
end

# ✅ GOOD: Use counter cache
class User < ApplicationRecord
  include BetterModel
  has_many :orders

  is :has_orders, -> { orders_count > 0 }
  is :recently_active, -> {
    last_activity_at && last_activity_at >= 7.days.ago
  }
end

# ✅ ACCEPTABLE: When associations are already loaded
class User < ApplicationRecord
  include BetterModel

  is :has_pending_orders, -> {
    orders.loaded? && orders.any? { |o| o.status == "pending" }
  }
end

# Usage with preloading
users = User.includes(:orders).all
users.each do |user|
  # No N+1 because orders are preloaded
  puts "Has pending orders" if user.is_has_pending_orders?
end
```

---

### Use Descriptive Names

**Cosa fa**: Choose clear, intention-revealing status names

**Quando usarlo**: Always

**Esempio**:

```ruby
# ✅ GOOD: Clear intent
is :publicly_accessible, -> { ... }
is :eligible_for_refund, -> { ... }
is :requires_admin_approval, -> { ... }
is :can_be_deleted, -> { ... }

# ❌ BAD: Vague or unclear
is :status1, -> { ... }
is :check, -> { ... }
is :ok, -> { ... }
is :x, -> { ... }

# ✅ GOOD: Matches domain language
class Subscription < ApplicationRecord
  include BetterModel

  is :active, -> { ends_at > Time.current }
  is :expired, -> { ends_at <= Time.current }
  is :trial, -> { tier == "trial" && created_at >= 14.days.ago }
  is :paying_customer, -> { tier != "trial" && tier != "free" }
end

# ❌ BAD: Generic names that don't convey meaning
class Subscription < ApplicationRecord
  include BetterModel

  is :check1, -> { ends_at > Time.current }
  is :check2, -> { ends_at <= Time.current }
  is :type_a, -> { tier == "trial" }
end
```

---

### Build on Other Statuses

**Cosa fa**: Create hierarchical relationships using `is?()` references

**Quando usarlo**: When higher-level statuses depend on lower-level ones

**Esempio**:

```ruby
# ✅ GOOD: Compose statuses
class Article < ApplicationRecord
  include BetterModel

  # Base statuses
  is :published, -> { status == "published" }
  is :not_expired, -> { expires_at.nil? || expires_at > Time.current }
  is :not_flagged, -> { flagged_at.nil? }

  # Composed statuses
  is :live, -> { is?(:published) && is?(:not_expired) }
  is :publicly_visible, -> {
    is?(:live) && is?(:not_flagged)
  }
end

# ❌ BAD: Duplicate logic
class Article < ApplicationRecord
  include BetterModel

  is :live, -> {
    status == "published" &&
    (expires_at.nil? || expires_at > Time.current)
  }

  is :publicly_visible, -> {
    status == "published" &&
    (expires_at.nil? || expires_at > Time.current) &&
    flagged_at.nil?
  }
end
```

---

### Test Thoroughly

**Cosa fa**: Test status conditions under different model states

**Quando usarlo**: Always

**Esempio**:

```ruby
# RSpec example
RSpec.describe Order, type: :model do
  describe "#is_refundable?" do
    it "returns true when paid and not shipped" do
      order = create(:order, payment_status: "paid", shipped_at: nil)
      expect(order.is_refundable?).to be true
    end

    it "returns false when not paid" do
      order = create(:order, payment_status: "pending")
      expect(order.is_refundable?).to be false
    end

    it "returns false when already shipped" do
      order = create(:order, payment_status: "paid", shipped_at: Time.current)
      expect(order.is_refundable?).to be false
    end

    it "handles edge case at boundary" do
      order = create(:order, payment_status: "paid", created_at: 30.days.ago)
      expect(order.is_refundable?).to be true
    end
  end
end

# Minitest example
class OrderTest < ActiveSupport::TestCase
  test "cancellable when paid but not shipped" do
    order = orders(:paid_order)
    order.update!(shipped_at: nil)

    assert order.is_cancellable?
  end

  test "not cancellable when already shipped" do
    order = orders(:shipped_order)

    refute order.is_cancellable?
  end
end
```

---

### Document Complex Logic

**Cosa fa**: Add comments explaining non-obvious business rules

**Quando usarlo**: When status involves domain-specific rules or edge cases

**Esempio**:

```ruby
class Consultation < ApplicationRecord
  include BetterModel

  # Status indicates the consultation can be billed to the client.
  # Requirements:
  # - Must be in "completed" state
  # - Duration must meet minimum billing threshold (15 minutes)
  # - Cannot have been cancelled at any point
  # - Must not have already been invoiced
  is :billable, -> {
    status == "completed" &&
    duration_minutes >= 15 &&
    !is?(:cancelled) &&
    invoiced_at.nil?
  }

  # User can reschedule if:
  # - Consultation is scheduled (not started/completed)
  # - Start time is more than 24 hours away (cancellation policy)
  # - User has not exceeded their monthly reschedule limit (3 times)
  is :can_reschedule, -> {
    is?(:scheduled) &&
    starts_at > 24.hours.from_now &&
    reschedules_this_month < 3
  }
end
```

---

## Integration Examples

### Controller Usage

**Cosa fa**: Use statuses for authorization and filtering in controllers

**Quando usarlo**: When handling user requests based on model state

**Esempio**:

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.all

    # Filter by status if parameter provided
    if params[:status].present?
      status_sym = params[:status].to_sym

      if Article.status_defined?(status_sym)
        @articles = @articles.select { |a| a.is?(status_sym) }
      else
        flash[:error] = "Invalid status: #{params[:status]}"
      end
    end

    # Separate into categories using statuses
    @published = @articles.select { |a| a.is_published? }
    @drafts = @articles.select { |a| a.is_draft? }
  end

  def update
    @article = Article.find(params[:id])

    # Check status before allowing update
    unless @article.is_draft?
      redirect_to @article, alert: "Cannot edit published articles"
      return
    end

    if @article.update(article_params)
      redirect_to @article, notice: "Article updated"
    else
      render :edit
    end
  end
end
```

---

### API Responses

**Cosa fa**: Include computed statuses in JSON API responses

**Quando usarlo**: When API clients need status information for UI/logic

**Esempio**:

```ruby
class Api::V1::OrdersController < ApplicationController
  def show
    order = Order.find(params[:id])

    render json: {
      order: order.as_json(
        only: [:id, :status, :total, :created_at],
        include_statuses: true
      ),
      # Additional computed fields based on statuses
      ui_state: {
        can_cancel: order.is_cancellable?,
        can_refund: order.is_refundable?,
        show_tracking: order.is_shipped? && order.tracking_number.present?
      }
    }
  end

  def bulk_status
    orders = Order.where(id: params[:order_ids])

    render json: orders.map { |order|
      {
        id: order.id,
        status: order.status,
        statuses: order.statuses
      }
    }
  end
end
```

---

### Background Jobs

**Cosa fa**: Use statuses to filter and process records in background jobs

**Quando usarlo**: For scheduled tasks, notifications, cleanup jobs

**Esempio**:

```ruby
class SendReminderJob < ApplicationJob
  def perform
    # Find events that need reminders
    events = Event.includes(:registrations).all

    events.each do |event|
      # Use status to determine if reminder needed
      next unless event.is_needs_reminder?

      # Send reminder
      event.registrations.each do |registration|
        EventMailer.reminder(registration).deliver_now
      end

      # Mark reminder as sent
      event.update!(reminder_sent_at: Time.current)
    end
  end
end

class CleanupExpiredRecordsJob < ApplicationJob
  def perform
    # Use status to find records to cleanup
    articles = Article.all

    articles.each do |article|
      if article.is_expired? && article.is_archived?
        article.destroy
      end
    end
  end
end
```

---

## Quick Reference

### Method Summary

```ruby
# Instance methods
article.is_published?                    # Generated predicate method
article.is?(:published)                  # Unified status check
article.statuses                         # Hash of all statuses
article.has_any_status?                  # At least one status true
article.has_all_statuses?([:pub, :pop])  # All specified true
article.active_statuses([:pub, :draft])  # Filter to active ones
article.as_json(include_statuses: true)  # Include in JSON

# Class methods
Article.defined_statuses                 # Array of status names
Article.status_defined?(:published)      # Check if status exists
```

### Common Patterns

```ruby
# Simple attribute check
is :published, -> { status == "published" }

# Date/time comparison
is :recent, -> { created_at >= 7.days.ago }

# Numeric threshold
is :popular, -> { views_count >= 1000 }

# Compound condition
is :live, -> { is?(:published) && !is?(:expired) }

# Custom method
is :eligible, -> { meets_criteria? }
```

---

## Error Handling

### Undefined Status Checks

**Cosa fa**: Gracefully handle checks for non-existent statuses

**Quando usarlo**: When status name comes from user input or external source

**Esempio**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
end

article = Article.new

# Defined status works normally
article.is?(:published)  # => true/false

# Undefined status returns false (safe)
article.is?(:nonexistent)  # => false (no error)

# Predicate method for undefined status raises NoMethodError
article.is_nonexistent?  # => NoMethodError

# Safe check with validation
def check_status(status_name)
  return false unless Article.status_defined?(status_name)
  article.is?(status_name)
end

# Validate before checking
if Article.status_defined?(params[:status].to_sym)
  @articles.select { |a| a.is?(params[:status].to_sym) }
else
  flash[:error] = "Invalid status: #{params[:status]}"
end
```

---

**Last Updated**: 2025-11-11 (BetterModel v3.0.0)
