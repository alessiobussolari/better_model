# 🔗 Integration Guide

This guide explains how to effectively combine multiple BetterModel concerns in your Rails models. Learn about concern compatibility, inclusion order, method conflicts, and best practices for building sophisticated model behaviors.

## Table of Contents

- [Overview](#overview)
- [Concern Compatibility Matrix](#concern-compatibility-matrix)
- [Inclusion Order](#inclusion-order)
- [Common Integration Patterns](#common-integration-patterns)
  - [Statusable + Permissible](#statusable--permissible)
  - [Statusable + Stateable](#statusable--stateable)
  - [Archivable + Traceable](#archivable--traceable)
  - [Stateable + Traceable](#stateable--traceable)
  - [Searchable + Predicable + Sortable](#searchable--predicable--sortable)
  - [Validatable + Statusable](#validatable--statusable)
  - [Full Stack Integration](#full-stack-integration)
- [Method Conflicts](#method-conflicts)
- [as_json Integration](#as_json-integration)
- [Database Considerations](#database-considerations)
- [Performance Implications](#performance-implications)
- [Real-world Examples](#real-world-examples)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

BetterModel concerns are designed to work together seamlessly. Each concern focuses on a specific aspect of model behavior:

| Concern | Purpose | Works Best With |
|---------|---------|-----------------|
| **Statusable** | Derived boolean statuses | Permissible, Stateable, Validatable |
| **Permissible** | State-based permissions | Statusable |
| **Archivable** | Soft delete with tracking | Traceable, Predicable |
| **Traceable** | Change tracking & audit trail | Archivable, Stateable |
| **Sortable** | Type-aware sorting scopes | Predicable, Searchable |
| **Predicable** | Advanced filtering scopes | Sortable, Searchable, Archivable |
| **Searchable** | Unified search interface | Predicable, Sortable |
| **Validatable** | Declarative validations | Statusable, Stateable |
| **Stateable** | State machine | Statusable, Traceable, Validatable |

## Concern Compatibility Matrix

| | Statusable | Permissible | Archivable | Traceable | Sortable | Predicable | Searchable | Validatable | Stateable |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Statusable** | - | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Permissible** | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Archivable** | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Traceable** | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Sortable** | ✅ | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ |
| **Predicable** | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ |
| **Searchable** | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | - | ✅ | ✅ |
| **Validatable** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ |
| **Stateable** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - |

**Legend:**
- ✅ Fully compatible - designed to work together
- ⚠️ Compatible with caveats - see specific section
- ❌ Not compatible - avoid combining

**Note:** Searchable requires Predicable and Sortable - they must be included when using Searchable.

## Inclusion Order

The order of concern inclusion generally doesn't matter due to Ruby's module resolution, but for clarity and convention:

### Recommended Order

```ruby
class Article < ApplicationRecord
  include BetterModel

  # 1. Core behavior (Statusable, Archivable)
  statusable do
    # ...
  end

  archivable do
    # ...
  end

  # 2. Filtering & Search (Predicable, Sortable, Searchable)
  # No explicit configuration needed - included via BetterModel

  # 3. State management (Stateable)
  stateable do
    # ...
  end

  # 4. Permissions (Permissible)
  permissible do
    # ...
  end

  # 5. Validation (Validatable)
  validatable do
    # ...
  end

  # 6. Audit trail (Traceable) - should be last
  traceable do
    # ...
  end
end
```

**Why this order?**
1. **Statusable first** - Provides predicates used by other concerns
2. **Archivable early** - Affects query scopes for other concerns
3. **Searchable middle** - Depends on Predicable/Sortable
4. **Stateable before Permissible** - States used in permissions
5. **Validatable before Stateable** - Validations may reference states
6. **Traceable last** - Tracks changes from all other concerns

## Common Integration Patterns

### Statusable + Permissible

**Use Case:** Define permissions based on derived statuses.

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses
  statusable do
    status :editable do
      draft? && !archived_at.present?
    end

    status :publishable do
      draft? && content.present? && title.present?
    end

    status :deletable do
      draft? || archived?
    end
  end

  # Define permissions based on statuses
  permissible do
    permission :edit, if: :is_editable?
    permission :publish, if: :is_publishable?
    permission :delete, if: :is_deletable?
  end
end

# Usage
article.can_edit?       # => true/false
article.can_publish?    # => true/false
article.permissions     # => [:edit, :publish]
```

**Key Points:**
- Permissible uses `is_*` methods from Statusable
- Keeps permission logic DRY
- Statuses are reusable across multiple permissions

### Statusable + Stateable

**Use Case:** Use derived statuses as guards for state transitions.

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Define derived statuses
  statusable do
    status :ready_to_confirm do
      items.any? && customer.present?
    end

    status :ready_to_ship do
      paid? && shipping_address.present?
    end
  end

  # Use statuses in state machine guards
  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid
    state :shipped

    transition :confirm, from: :pending, to: :confirmed do
      guard if: :is_ready_to_confirm?  # Uses Statusable
    end

    transition :ship, from: :paid, to: :shipped do
      guard if: :is_ready_to_ship?
    end
  end
end

# Usage
order.is_ready_to_confirm?  # => true
order.can_confirm?          # => true (guard passes)
order.confirm!              # State transition
```

**Key Points:**
- Statusable predicates can be used as Stateable guards
- Use `guard if: :status_predicate` syntax
- Keeps complex business logic in Statusable
- State machine focuses on transitions

### Archivable + Traceable

**Use Case:** Track archival events in audit trail.

```ruby
class Document < ApplicationRecord
  include BetterModel

  # Soft delete with tracking
  archivable do
    with_by
    with_reason
  end

  # Track all changes including archival
  traceable do
    track :status, :archived_at, :archive_reason, :archive_by_id
  end
end

# Usage
document.archive!(
  by: current_user.id,
  reason: "Outdated content"
)

# Traceable records the archival
document.versions.last
# => #<Version event: "updated", object_changes: {
#   "archived_at" => [nil, 2025-01-15...],
#   "archive_reason" => [nil, "Outdated content"]
# }>

document.audit_trail
# Full history including archival events
```

**Key Points:**
- Traceable captures archival fields automatically
- Track `archived_at`, `archive_by_id`, `archive_reason`
- Provides full audit trail including soft deletes
- Can reconstruct pre-archival state with `as_of`

### Stateable + Traceable

**Use Case:** Track state transitions in audit trail.

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid

    transition :confirm, from: :pending, to: :confirmed
    transition :pay, from: :confirmed, to: :paid
  end

  traceable do
    track :state  # Track state changes
  end
end

# Usage
order.confirm!

# Stateable creates StateTransition record
order.state_transitions.last
# => #<StateTransition event: "confirm", from_state: "pending", to_state: "confirmed">

# Traceable creates Version record
order.versions.last
# => #<Version event: "updated", object_changes: {"state" => ["pending", "confirmed"]}>

# Two complementary systems:
# - Stateable: state-specific history with metadata
# - Traceable: general change tracking
```

**Key Points:**
- Both systems track state changes independently
- Stateable: state-specific with transition metadata
- Traceable: general audit trail
- Use both for complete history
- Stateable tracks transitions, Traceable tracks all changes

### Searchable + Predicable + Sortable

**Use Case:** Unified search interface with filtering and sorting.

**Note:** Searchable automatically includes Predicable and Sortable when you include BetterModel.

```ruby
class Article < ApplicationRecord
  include BetterModel  # Includes Predicable, Sortable, Searchable

  # Predicable provides filtering scopes automatically
  # Sortable provides sorting scopes automatically

  # Configure Searchable
  searchable do
    max_per_page 100
    default_order :created_at, :desc

    # Security: require at least one filter
    require_predicates :status_eq, :author_id_eq
  end
end

# Usage
Article.search(
  # Predicable filters
  status_eq: "published",
  title_cont: "Rails",

  # Sortable ordering
  order_by: :created_at,
  order_dir: :desc,

  # Pagination
  page: 1,
  per_page: 20
)
```

**Key Points:**
- Searchable orchestrates Predicable + Sortable
- Single unified search interface
- Built-in pagination and security
- OR conditions support

### Validatable + Statusable

**Use Case:** Conditional validations based on derived statuses.

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses
  statusable do
    status :published do
      published_at.present? && !archived_at.present?
    end
  end

  # Conditional validations using statuses
  validatable do
    # Always required
    validate :title, presence: true

    # Only when published
    validate_if :is_published? do
      validate :content, presence: true, length: { minimum: 100 }
      validate :featured_image, presence: true
      validate :meta_description, presence: true
    end

    # Not when published
    validate_unless :is_published? do
      validate :draft_notes, presence: true
    end
  end
end

# Usage
article = Article.new(title: "Hello")
article.valid?  # => true (not published, draft_notes not required)

article.published_at = Time.current
article.valid?  # => false (is_published?, content required)
```

**Key Points:**
- Use Statusable predicates in `validate_if`/`validate_unless`
- Keeps validation logic clean and readable
- Status predicates are reusable
- Validations respect derived statuses

### Full Stack Integration

**Use Case:** Complete model with all concerns working together.

```ruby
class Order < ApplicationRecord
  include BetterModel

  belongs_to :customer
  has_many :items

  # 1. Statusable - Derived statuses
  statusable do
    status :ready_to_confirm do
      items.any? && customer.present? && !cancelled?
    end

    status :paid do
      payment_status == "completed"
    end

    status :shippable do
      is_paid? && shipping_address.present?
    end
  end

  # 2. Archivable - Soft delete
  archivable do
    with_by
    with_reason
    default_scope_exclude_archived
  end

  # 3. Stateable - State machine
  stateable do
    state :pending, initial: true
    state :confirmed
    state :shipped
    state :delivered
    state :cancelled

    transition :confirm, from: :pending, to: :confirmed do
      guard if: :is_ready_to_confirm?
      validate { errors.add(:base, "Invalid") unless valid_for_confirmation? }
      before :calculate_total
      after :send_confirmation_email
    end

    transition :ship, from: :confirmed, to: :shipped do
      guard if: :is_shippable?
      before { self.shipped_at = Time.current }
      after :send_tracking_email
    end

    transition :cancel, from: [:pending, :confirmed], to: :cancelled do
      before { self.cancelled_at = Time.current }
    end
  end

  # 4. Permissible - Permissions
  permissible do
    permission :edit, if: -> { pending? && !archived? }
    permission :cancel, if: -> { !shipped? && !delivered? }
    permission :view_full_details, if: :is_paid?
  end

  # 5. Validatable - Validations
  validatable do
    validate :customer_id, presence: true

    validate_if :is_paid? do
      validate :payment_method, presence: true
      validate :payment_status, inclusion: { in: %w[completed] }
    end
  end

  # 6. Traceable - Audit trail (last)
  traceable do
    track :state, :status, :total_amount, :shipped_at, :cancelled_at
  end

  # Predicable, Sortable, Searchable included automatically via BetterModel
end

# Usage - All concerns work together
order = Order.create!(customer: customer)

# Statusable
order.is_ready_to_confirm?  # => false (no items)

# Add items
order.items << Item.new(product: product)
order.is_ready_to_confirm?  # => true

# Stateable with Statusable guards
order.can_confirm?   # => true (guard passes)
order.confirm!       # State transition

# Permissible
order.can_edit?      # => false (no longer pending)
order.can_cancel?    # => true (not shipped)

# Searchable (Predicable + Sortable)
Order.search(
  state_eq: "confirmed",
  customer_id_eq: customer.id,
  order_by: :created_at
)

# Traceable
order.audit_trail    # Full history including state changes

# Archivable
order.archive!(by: admin.id, reason: "Duplicate")
Order.all            # Excludes archived (default scope)
Order.archived_only  # Only archived orders
```

**Key Integration Points:**
1. Statusable provides `is_ready_to_confirm?` for Stateable guards
2. Stateable transitions tracked by Traceable
3. Permissible uses Stateable states (`pending?`, `shipped?`)
4. Validatable uses Statusable predicates (`is_paid?`)
5. Archivable scopes work with Predicable queries
6. Searchable combines Predicable filters with Sortable ordering

## Method Conflicts

### Potential Conflicts

Some concerns may define methods that could conflict:

| Concern A | Concern B | Conflicting Methods | Resolution |
|-----------|-----------|---------------------|------------|
| Archivable | Predicable | Scopes (`archived`, etc.) | ✅ No conflict - Archivable uses `archived_only` |
| Statusable | Custom methods | `is_*` predicates | ⚠️ Use unique status names |
| Stateable | Custom methods | `state` attribute | ⚠️ Avoid defining `state` method |
| Permissible | Custom methods | `can_*` methods | ⚠️ Use unique permission names |

### Avoiding Conflicts

```ruby
# ❌ Bad: Status name conflicts with existing method
class User < ApplicationRecord
  statusable do
    status :valid do  # Conflicts with ActiveRecord#valid?
      email.present?
    end
  end
end

# ✅ Good: Use unique status name
class User < ApplicationRecord
  statusable do
    status :email_valid do
      email.present?
    end
  end
end

# ❌ Bad: Permission conflicts with existing method
class Article < ApplicationRecord
  permissible do
    permission :new, if: :draft?  # Conflicts with ActiveRecord::Base.new
  end
end

# ✅ Good: Use unique permission name
class Article < ApplicationRecord
  permissible do
    permission :create_draft, if: :draft?
  end
end
```

## as_json Integration

Multiple concerns override `as_json` to add their data. They are designed to chain properly:

```ruby
class Order < ApplicationRecord
  include BetterModel

  statusable do
    status :paid do
      payment_status == "completed"
    end
  end

  permissible do
    permission :edit, if: -> { pending? }
  end

  traceable do
    track :state, :total
  end

  stateable do
    state :pending, initial: true
    state :confirmed
  end
end

# Default JSON
order.as_json
# => {"id" => 1, "state" => "pending", "total" => 100.0, ...}

# Include statuses
order.as_json(include_statuses: true)
# => {..., "statuses" => {"paid" => false}}

# Include permissions
order.as_json(include_permissions: true)
# => {..., "permissions" => ["edit"]}

# Include audit trail
order.as_json(include_audit_trail: true)
# => {..., "audit_trail" => [{event: "created", ...}]}

# Include transition history
order.as_json(include_transition_history: true)
# => {..., "transition_history" => [{event: "confirm", ...}]}

# Combine multiple
order.as_json(
  include_statuses: true,
  include_permissions: true,
  include_audit_trail: true,
  include_transition_history: true
)
# All data included
```

### Custom as_json with Concerns

```ruby
class Order < ApplicationRecord
  include BetterModel

  # ... concern configurations ...

  # Override as_json to add custom data
  def as_json(options = {})
    result = super(options)  # Calls concern as_json methods via super chain

    # Add custom data
    result["customer_name"] = customer.name if options[:include_customer]
    result["items_count"] = items.count if options[:include_counts]

    result
  end
end
```

## Database Considerations

### Indexing Strategy

When combining multiple concerns, index strategically:

```ruby
# Migration for Order model using multiple concerns
class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      # Stateable
      t.string :state, null: false, default: "pending"

      # Archivable
      t.datetime :archived_at
      t.bigint :archive_by_id
      t.string :archive_reason

      # Traceable (uses separate table)

      # Other fields
      t.bigint :customer_id
      t.decimal :total_amount
      t.datetime :shipped_at

      t.timestamps
    end

    # Essential indexes for concerns
    add_index :orders, :state                    # Stateable queries
    add_index :orders, :archived_at              # Archivable scope
    add_index :orders, :customer_id              # Predicable filters
    add_index :orders, [:state, :archived_at]    # Compound queries
    add_index :orders, :created_at               # Sortable, time-based queries
  end
end
```

### Separate Tables for Concern Data

Some concerns use separate tables:

```ruby
# Traceable
create_table :order_versions do |t|
  t.string :item_type
  t.bigint :item_id
  t.string :event
  t.json :object_changes
  t.timestamps
end

# Stateable
create_table :state_transitions do |t|
  t.string :transitionable_type
  t.bigint :transitionable_id
  t.string :event
  t.string :from_state
  t.string :to_state
  t.json :metadata
  t.timestamps
end
```

## Performance Implications

### Query Performance

```ruby
# Combining scopes from multiple concerns
Order.not_archived              # Archivable
     .state_eq("confirmed")     # Predicable
     .customer_id_eq(123)       # Predicable
     .order_by_created_at_desc  # Sortable
     .limit(20)

# Generated SQL:
# SELECT * FROM orders
# WHERE archived_at IS NULL           (Archivable)
#   AND state = 'confirmed'           (Predicable)
#   AND customer_id = 123             (Predicable)
# ORDER BY created_at DESC            (Sortable)
# LIMIT 20

# Ensure indexes exist:
# - (archived_at)
# - (state)
# - (customer_id)
# - (created_at)
```

### N+1 Prevention

```ruby
# Include associations when querying with concerns
orders = Order.includes(:versions, :state_transitions)
              .not_archived
              .state_eq("confirmed")
              .limit(10)

orders.each do |order|
  order.audit_trail             # No N+1 (versions preloaded)
  order.transition_history      # No N+1 (state_transitions preloaded)
end
```

## Real-world Examples

See the [Real-world Examples](#real-world-examples) section in individual concern documentation:
- [Traceable Real-world Examples](traceable.md#real-world-examples)
- [Stateable Real-world Examples](stateable.md#real-world-examples)
- [Searchable Real-world Examples](searchable.md#real-world-examples)

## Troubleshooting

### "Method not found" Errors

```ruby
# Error: undefined method `is_ready?'
order.confirm!
# => Guard failed: predicate guard: is_ready?

# Solution: Ensure Statusable is configured
stateable do
  transition :confirm do
    guard if: :is_ready?  # Requires Statusable
  end
end

# Add Statusable
statusable do
  status :ready do
    items.any?
  end
end
```

### Scope Conflicts

```ruby
# Error: Relation cannot be merged (scopes conflict)
Order.not_archived.archived_only
# => Can't merge conflicting scopes

# Solution: Don't combine conflicting scopes
Order.not_archived  # OR
Order.archived_only  # OR
Order.with_archived # (all records)
```

### as_json Not Including Data

```ruby
# Issue: Statuses not in JSON
order.as_json
# => {"id" => 1, ...}  # No "statuses" key

# Solution: Pass include option
order.as_json(include_statuses: true)
# => {"id" => 1, ..., "statuses" => {...}}
```

## Best Practices

### ✅ Do

- **Include concerns in recommended order** - Statusable first, Traceable last
- **Use Statusable for complex guards** - DRY guard logic in Stateable
- **Index concern columns** - state, archived_at, etc.
- **Leverage concern synergies** - Statusable + Permissible, Stateable + Traceable
- **Use Searchable for complex queries** - Combines Predicable + Sortable
- **Track state changes** - Use Traceable with Stateable
- **Test concern interactions** - Ensure concerns work together
- **Document concern usage** - Make integration clear for other developers

### ❌ Don't

- **Don't skip Predicable/Sortable with Searchable** - They're required
- **Don't create circular dependencies** - Status depends on state depends on status
- **Don't bypass concern methods** - Use `transition!` not `update(state: ...)`
- **Don't ignore performance** - Index combined queries
- **Don't mix state and status** - State is persistent (Stateable), status is derived (Statusable)
- **Don't over-complicate** - Only use concerns you need
- **Don't forget migrations** - Concerns may need database columns/tables

---

**Related Documentation:**
- [Performance Guide](performance_guide.md) - Optimization tips for combined concerns
- [Migration Guide](migration_guide.md) - Adding concerns to existing models
- Individual concern docs for detailed features

**Need Help?**

- Check individual concern documentation for feature-specific guidance
- Review the [Best Practices](#best-practices) section
- See [Real-world Examples](#real-world-examples) for complete implementations
