## Statusable - Status Management

### Checking Statuses

```ruby
article = Article.find(1)

# Using is? method
article.is?(:published)  # => true/false

# Using dynamic methods
article.is_published?    # => true/false
article.is_draft?        # => true/false
article.is_expired?      # => true/false
```

### Getting All Statuses

```ruby
# Get a hash of all statuses with their current values
article.statuses
# => { draft: false, published: true, scheduled: false, expired: false, popular: true, active: true }
```

### Helper Methods

```ruby
# Check if any status is active
article.has_any_status?
# => true

# Check if all specified statuses are active
article.has_all_statuses?([:published, :popular])
# => true

# Filter and get only active statuses from a list
article.active_statuses([:published, :draft, :popular, :expired])
# => [:published, :popular]
```

### Class Methods

```ruby
# Get all defined status names
Article.defined_statuses
# => [:draft, :published, :scheduled, :expired, :popular, :active]

# Check if a status is defined
Article.status_defined?(:published)
# => true

Article.status_defined?(:nonexistent)
# => false
```

### JSON Serialization

Include statuses in JSON output when needed:

```ruby
# Without statuses (default)
article.as_json
# => { "id" => 1, "title" => "...", "status" => "published", ... }

# With statuses
article.as_json(include_statuses: true)
# => {
#      "id" => 1,
#      "title" => "...",
#      "status" => "published",
#      "statuses" => {
#        "draft" => false,
#        "published" => true,
#        "scheduled" => false,
#        "expired" => false,
#        "popular" => true,
#        "active" => true
#      }
#    }
```

### Complex Status Conditions

Statuses can use any Ruby logic and reference model attributes:

```ruby
class Consultation < ApplicationRecord
  include BetterModel

  # Simple attribute check
  is :pending, -> { status == "initialized" }

  # Multiple conditions
  is :active_session, -> { status == "active" && !is?(:expired) }

  # Date/time comparisons
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :scheduled, -> { scheduled_at.present? }
  is :immediate, -> { scheduled_at.blank? }

  # Compound conditions with other statuses
  is :ready_to_start, -> { is?(:scheduled) && scheduled_at <= Time.current }

  # Using associations (loaded)
  is :has_participants, -> { participants.any? }

  # Using custom methods
  is :overdue, -> { scheduled? && past_due_date? }

  private

  def past_due_date?
    scheduled_at < 1.hour.ago
  end
end
```

### Real-World Examples

**E-commerce Order:**

```ruby
class Order < ApplicationRecord
  include BetterModel

  is :pending_payment, -> { status == "pending" && payment_status == "unpaid" }
  is :paid, -> { payment_status == "paid" }
  is :processing, -> { status == "processing" && is?(:paid) }
  is :shipped, -> { status == "shipped" && shipped_at.present? }
  is :delivered, -> { status == "delivered" && delivered_at.present? }
  is :cancellable, -> { is?(:pending_payment) || is?(:paid) }
  is :refundable, -> { is?(:paid) && !is?(:shipped) }
end

order = Order.find(1)
order.is_cancellable?  # => true
order.is_refundable?   # => false
```

**Blog Post:**

```ruby
class Post < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at <= Time.current }
  is :scheduled, -> { status == "published" && published_at > Time.current }
  is :archived, -> { archived_at.present? }
  is :trending, -> { views_count >= 1000 && created_at >= 24.hours.ago }
  is :needs_review, -> { is?(:draft) && updated_at < 7.days.ago }
end
```

**User Account:**

```ruby
class User < ApplicationRecord
  include BetterModel

  is :active, -> { !suspended_at && email_verified_at.present? }
  is :suspended, -> { suspended_at.present? }
  is :email_verified, -> { email_verified_at.present? }
  is :premium, -> { subscription_tier == "premium" && subscription_expires_at > Time.current }
  is :trial, -> { subscription_tier == "trial" && created_at >= 14.days.ago }
  is :requires_action, -> { is?(:active) && password_changed_at < 90.days.ago }
end
```

### Best Practices

1. **Keep conditions simple and readable** - Complex logic should be moved to private methods
2. **Avoid database queries in conditions** - Use loaded associations or cached counters
3. **Reference other statuses when appropriate** - Use `is?(:other_status)` for compound conditions
4. **Name statuses clearly** - Use descriptive names that indicate what the status represents
5. **Document complex statuses** - Add comments explaining non-obvious business logic

### Thread Safety

Statusable is thread-safe:
- Status definitions are frozen after registration
- The registry is immutable (frozen hash)
- No shared mutable state between instances

### Error Handling

> **ℹ️ Version 3.0.0 Compatible**: All error examples use standard Ruby exception patterns with `e.message`. Domain-specific attributes and Sentry helpers have been removed in v3.0.0 for simplicity.

Statusable raises ConfigurationError for invalid configuration during class definition:

```ruby
# Missing condition
begin
  is :test_status
rescue BetterModel::Errors::Statusable::ConfigurationError => e
  # Only message available in v3.0.0
  e.message
  # => "Condition proc or block is required"

  # Log or report
  Rails.logger.error("Statusable configuration error: #{e.message}")
  Sentry.capture_exception(e)
end

# Blank status name
begin
  is "", -> { true }
rescue BetterModel::Errors::Statusable::ConfigurationError => e
  e.message  # => "Status name cannot be blank"
  Rails.logger.error(e.message)
  Sentry.capture_exception(e)
end

# Non-callable condition
begin
  is :test, "not a proc"
rescue BetterModel::Errors::Statusable::ConfigurationError => e
  e.message  # => "Condition must respond to call"
  Rails.logger.error(e.message)
  Sentry.capture_exception(e)
end
```

Undefined statuses return `false` by default (secure by default):

```ruby
article.is?(:nonexistent_status)  # => false
```

**Integration with Sentry:**

```ruby
rescue_from BetterModel::Errors::Statusable::ConfigurationError do |error|
  Rails.logger.error("Configuration error: #{error.message}")
  Sentry.capture_exception(error)
  render json: { error: "Server configuration error" }, status: :internal_server_error
end
```

