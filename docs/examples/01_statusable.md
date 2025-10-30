# Statusable Examples

Statusable allows you to define declarative status checks using lambdas, eliminating the need for multiple boolean columns or verbose instance methods.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Simple Status Checks](#example-1-simple-status-checks)
- [Example 2: Composite Status](#example-2-composite-status)
- [Example 3: Time-based Status](#example-3-time-based-status)
- [Example 4: Numeric Threshold Status](#example-4-numeric-threshold-status)
- [Example 5: Negation and Complex Logic](#example-5-negation-and-complex-logic)
- [Example 6: Multiple Statuses](#example-6-multiple-statuses)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Migration
class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :status, default: "draft"
      t.datetime :published_at
      t.datetime :expires_at
      t.integer :view_count, default: 0
      t.timestamps
    end
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel

  # Define statuses with lambdas
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
end
```

## Example 1: Simple Status Checks

```ruby
# Create articles with different statuses
draft = Article.create!(title: "Draft Article", status: "draft")
published = Article.create!(title: "Published Article", status: "published")

# Check status using is? method
draft.is?(:draft)
# => true

draft.is?(:published)
# => false

published.is?(:published)
# => true

# Negation
draft.is_not?(:published)
# => true
```

**Output Explanation**: The `is?` method evaluates the lambda defined for each status, providing a clean, readable way to check conditions.

## Example 2: Composite Status

Combine multiple conditions for complex business logic:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :scheduled, -> { status == "scheduled" && published_at.present? && published_at > Time.current }
  is :active, -> { is?(:published) && !is?(:expired) }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
end

# Usage
article = Article.create!(
  title: "Future Article",
  status: "published",
  published_at: Time.current,
  expires_at: 3.days.from_now
)

article.is?(:published)
# => true

article.is?(:active)
# => true (published and not expired)

# Fast forward 4 days
article.update!(expires_at: 1.day.ago)
article.is?(:active)
# => false (now expired)

article.is?(:expired)
# => true
```

**Output Explanation**: Composite statuses can reference other statuses using `is?(:other_status)`, creating reusable logic.

## Example 3: Time-based Status

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? && published_at <= Time.current }
  is :scheduled, -> { status == "published" && published_at.present? && published_at > Time.current }
  is :recent, -> { published_at.present? && published_at >= 7.days.ago }
  is :fresh, -> { created_at >= 24.hours.ago }
end

# Create scheduled article
future = Article.create!(
  title: "Future Post",
  status: "published",
  published_at: 2.days.from_now
)

future.is?(:scheduled)
# => true

future.is?(:published)
# => false (published_at is in the future)

future.is?(:fresh)
# => true (created less than 24 hours ago)

# After 2 days
# future.is?(:scheduled) => false
# future.is?(:published) => true
# future.is?(:recent) => true
```

**Output Explanation**: Time-based statuses are evaluated dynamically, so the same article can transition between statuses without updates.

## Example 4: Numeric Threshold Status

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :popular, -> { view_count >= 100 }
  is :viral, -> { view_count >= 1000 }
  is :trending, -> { view_count >= 50 && created_at >= 24.hours.ago }
end

article = Article.create!(
  title: "Trending Post",
  status: "published",
  view_count: 75
)

article.is?(:popular)
# => false (view_count < 100)

article.is?(:trending)
# => true (view_count >= 50 and recent)

# After more views
article.update!(view_count: 150)

article.is?(:popular)
# => true

article.is?(:viral)
# => false (view_count < 1000)
```

**Output Explanation**: Numeric thresholds provide dynamic categorization without additional database columns.

## Example 5: Negation and Complex Logic

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :featured, -> { featured == true }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  # Complex combinations
  is :visible, -> { is?(:published) && is_not?(:expired) }
  is :featured_and_visible, -> { is?(:featured) && is?(:visible) }
  is :needs_review, -> { is?(:draft) && updated_at < 30.days.ago }
end

article = Article.create!(
  title: "Complex Article",
  status: "published",
  featured: true,
  expires_at: 7.days.from_now
)

article.is?(:visible)
# => true

article.is?(:featured_and_visible)
# => true

article.is?(:needs_review)
# => false (not a draft)

# Create old draft
old_draft = Article.create!(
  title: "Old Draft",
  status: "draft",
  created_at: 60.days.ago,
  updated_at: 60.days.ago
)

old_draft.is?(:needs_review)
# => true (draft and not updated in 30 days)
```

**Output Explanation**: Use `is_not?` for negation and combine multiple status checks for complex business rules.

## Example 6: Multiple Statuses

Check multiple statuses at once:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :archived, -> { status == "archived" }
  is :featured, -> { featured == true }
end

article = Article.create!(
  title: "Featured Draft",
  status: "draft",
  featured: true
)

# Check multiple statuses
article.is?(:draft, :featured)
# => true (both conditions are true)

article.is?(:draft, :published)
# => false (one condition is false)

# Using array
statuses_to_check = [:draft, :featured]
article.is?(*statuses_to_check)
# => true
```

**Output Explanation**: Pass multiple symbols to `is?` to check if ALL statuses are true (AND logic).

## Tips & Best Practices

### 1. Keep Lambdas Simple
```ruby
# Good: Simple and readable
is :published, -> { status == "published" }

# Avoid: Complex logic in lambda
is :complex, -> {
  (status == "published" && view_count > 100) ||
  (status == "featured" && created_at > 7.days.ago)
}

# Better: Break into smaller statuses
is :popular_published, -> { status == "published" && view_count > 100 }
is :recent_featured, -> { status == "featured" && created_at > 7.days.ago }
is :complex, -> { is?(:popular_published) || is?(:recent_featured) }
```

### 2. Use Database Columns Efficiently
Statusable doesn't replace database columns—it enhances them:

```ruby
# Store the base status in database
# status: "draft" | "published" | "archived"

# Use Statusable for derived/computed statuses
is :draft, -> { status == "draft" }
is :published_recently, -> { status == "published" && published_at >= 7.days.ago }
is :needs_attention, -> { is?(:draft) && updated_at < 30.days.ago }
```

### 3. Avoid N+1 Queries in Lambdas
```ruby
# Bad: Will cause N+1 if article has many comments
is :has_comments, -> { comments.any? }

# Good: Use counter cache
is :has_comments, -> { comments_count > 0 }

# Also Good: Use database column
is :has_comments, -> { has_comments == true }
```

### 4. Combine with Scopes
```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :featured, -> { featured == true }

  # Create scopes that use statuses
  scope :visible, -> {
    all.select { |article| article.is?(:published) }
  }

  # Better: Use database-level scopes
  scope :visible, -> { where(status: "published") }
end
```

### 5. Document Complex Statuses
```ruby
class Article < ApplicationRecord
  include BetterModel

  # Simple statuses don't need comments
  is :draft, -> { status == "draft" }

  # Document complex business logic
  # An article is "actionable" if it's a draft that hasn't been
  # updated in 30 days OR if it's published but expires soon
  is :actionable, -> {
    (is?(:draft) && updated_at < 30.days.ago) ||
    (is?(:published) && expires_at.present? && expires_at < 7.days.from_now)
  }
end
```

## Related Documentation

- [Main README](../../README.md#statusable) - Full Statusable documentation
- [Permissible Examples](02_permissible.md) - Use statuses for permissions
- [Stateable Examples](08_stateable.md) - Combine with state machines
- [Test File](../../test/better_model/statusable_test.rb) - Complete test coverage

---

[← Back to Examples Index](README.md) | [Next: Permissible Examples →](02_permissible.md)
