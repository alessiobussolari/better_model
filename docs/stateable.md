# 🔄 Stateable

Stateable provides a declarative state machine system for Rails models with support for explicit states, guarded transitions, validations, callbacks, and complete state history tracking. It enables you to model complex business workflows with clean, maintainable code.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
  - [Quick Start with Generator](#quick-start-with-generator)
  - [Manual Setup](#manual-setup)
- [Basic Configuration](#basic-configuration)
  - [Defining States](#defining-states)
  - [Defining Transitions](#defining-transitions)
- [Guards](#guards)
  - [Block Guards](#block-guards)
  - [Method Guards](#method-guards)
  - [Predicate Guards (Statusable Integration)](#predicate-guards-statusable-integration)
- [Validations](#validations)
- [Callbacks](#callbacks)
  - [Before Callbacks](#before-callbacks)
  - [After Callbacks](#after-callbacks)
  - [Around Callbacks](#around-callbacks)
- [State History Tracking](#state-history-tracking)
- [Generated Methods](#generated-methods)
- [Table Naming Options](#table-naming-options)
- [Database Schema](#database-schema)
- [Integration with Other Concerns](#integration-with-other-concerns)
- [Real-world Examples](#real-world-examples)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## Overview

**Key Features:**

- **🎯 Opt-in Activation**: Stateable is not active by default. You must explicitly enable it with `stateable do...end`.
- **📊 Explicit States**: Define all possible states upfront with clear initial state.
- **🔐 Guarded Transitions**: Protect state changes with guard conditions (blocks, methods, or Statusable predicates).
- **✅ Transition Validations**: Add custom validation logic to transitions.
- **🎣 Rich Callbacks**: before, after, and around callbacks for transition lifecycle.
- **📜 Complete History**: Track all state transitions with metadata and timestamps.
- **🤝 Statusable Integration**: Use Statusable predicates as guard conditions.
- **🔗 Flexible Table Naming**: Shared or per-model transition tables.
- **🛡️ Thread-safe**: Immutable configuration and registry.
- **⚡ Database Transaction**: All transitions wrapped in transactions for consistency.

## Setup

### Quick Start with Generator

Use the built-in generators to quickly set up Stateable:

```bash
# Install state transitions table (shared by all models)
rails g better_model:stateable:install
rails db:migrate

# Configure specific model (generates initializer)
rails g better_model:stateable Order
```

### Manual Setup

Create the state transitions table manually:

```ruby
# db/migrate/XXXXXX_create_state_transitions.rb
class CreateStateTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :state_transitions do |t|
      t.string :transitionable_type, null: false  # Polymorphic type
      t.bigint :transitionable_id, null: false    # Polymorphic ID
      t.string :event, null: false                 # Transition event name
      t.string :from_state, null: false            # Previous state
      t.string :to_state, null: false              # New state
      t.json :metadata                             # Optional metadata (PostgreSQL: jsonb)

      t.timestamps                                  # created_at, updated_at
    end

    add_index :state_transitions, [:transitionable_type, :transitionable_id]
    add_index :state_transitions, :event
    add_index :state_transitions, :created_at
  end
end
```

**Add state column to your model:**

```ruby
# db/migrate/XXXXXX_add_state_to_orders.rb
class AddStateToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :state, :string, null: false, default: "pending"
    add_index :orders, :state
  end
end
```

## Basic Configuration

### Defining States

Enable Stateable and define all possible states:

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    # Define states
    state :pending, initial: true  # Initial state (required)
    state :confirmed
    state :paid
    state :shipped
    state :delivered
    state :cancelled
  end
end
```

**Important:**

- At least one state must be marked with `initial: true`
- Only one initial state is allowed
- All states must be defined before transitions
- States are symbols

### Defining Transitions

Define transitions between states:

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid
    state :cancelled

    # Simple transition
    transition :confirm, from: :pending, to: :confirmed

    # Transition from multiple states
    transition :cancel, from: [:pending, :confirmed, :paid], to: :cancelled

    # Transition with block configuration
    transition :pay, from: :confirmed, to: :paid do
      guard { payment_method.present? }
      before { charge_payment }
      after { send_receipt }
    end
  end
end
```

**Transition Syntax:**

```ruby
transition :event_name, from: :source_state, to: :target_state do
  # Optional: guards, validations, callbacks
end
```

## Guards

Guards are preconditions that must be met for a transition to be allowed. There are three types of guards:

### Block Guards

Evaluate a block in the instance context:

```ruby
stateable do
  state :pending, initial: true
  state :confirmed

  transition :confirm, from: :pending, to: :confirmed do
    # Multiple guards - ALL must pass
    guard { items.any? }
    guard { customer.present? }
    guard { total_amount > 0 }
  end
end
```

**Block guards:**
- Executed in instance context (`self` is the model instance)
- Must return truthy/falsy value
- Can access any instance methods or attributes
- Multiple guards are AND-ed (all must pass)

### Method Guards

Call a method on the instance:

```ruby
class Order < ApplicationRecord
  stateable do
    state :pending, initial: true
    state :confirmed

    transition :confirm, from: :pending, to: :confirmed do
      guard :customer_valid?
      guard :stock_available?
    end
  end

  private

  def customer_valid?
    customer.present? && customer.email.present?
  end

  def stock_available?
    items.all? { |item| item.in_stock? }
  end
end
```

**Method guards:**
- Cleaner for complex logic
- Reusable across transitions
- Can be private methods
- Must return truthy/falsy value

### Predicate Guards (Statusable Integration)

Use Statusable predicates as guards:

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Define Statusable predicates
  statusable do
    status :ready_to_ship do
      paid? && address.present? && !cancelled?
    end

    status :payable do
      confirmed? && payment_method.present?
    end
  end

  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid
    state :shipped

    transition :pay, from: :confirmed, to: :paid do
      guard if: :is_payable?  # Uses Statusable predicate
    end

    transition :ship, from: :paid, to: :shipped do
      guard if: :is_ready_to_ship?
    end
  end
end
```

**Predicate guards:**
- Requires Statusable concern
- Uses `guard if: :predicate_name` syntax
- Automatically prefixes with `is_` if Statusable is enabled
- Great for complex derived conditions

## Validations

Add custom validation logic to transitions:

```ruby
class Order < ApplicationRecord
  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid

    transition :confirm, from: :pending, to: :confirmed do
      validate do
        errors.add(:base, "Must have at least one item") if items.empty?
        errors.add(:customer, "is required") if customer.blank?
        errors.add(:shipping_address, "is required") if shipping_address.blank?
      end
    end

    transition :pay, from: :confirmed, to: :paid do
      validate do
        errors.add(:payment_method, "is required") if payment_method.blank?
        errors.add(:total, "must be greater than 0") if total_amount <= 0
      end
    end
  end
end
```

**Validation behavior:**

- Runs after guards (guards must pass first)
- Should add errors to `errors` object
- If any errors exist after validation, transition fails with `ValidationFailedError`
- Can add multiple validation blocks (all will be executed)

## Callbacks

### Before Callbacks

Execute logic before the state changes:

```ruby
stateable do
  state :pending, initial: true
  state :confirmed

  transition :confirm, from: :pending, to: :confirmed do
    # Block callback
    before { calculate_total }

    # Method callback
    before :send_confirmation_email

    # Multiple callbacks (executed in order)
    before :update_inventory
    before :notify_warehouse
  end
end
```

**Before callbacks:**
- Execute before state is changed
- Execute after guards and validations pass
- Changes are not saved yet (can modify the record)
- If an exception is raised, transaction rolls back

### After Callbacks

Execute logic after the state changes:

```ruby
stateable do
  state :confirmed, initial: true
  state :paid

  transition :pay, from: :confirmed, to: :paid do
    # Block callback
    after { update_accounting }

    # Method callback
    after :send_receipt

    # Multiple callbacks
    after :update_loyalty_points
    after :schedule_shipping
  end
end
```

**After callbacks:**
- Execute after state is saved to database
- State transition record is already created
- If an exception is raised, transaction rolls back
- Great for side effects like emails, notifications

### Around Callbacks

Wrap the entire transition:

```ruby
stateable do
  state :pending, initial: true
  state :confirmed

  transition :confirm, from: :pending, to: :confirmed do
    around do |transition|
      start_time = Time.current

      # Before transition
      Rails.logger.info "Starting confirmation at #{start_time}"

      # Execute transition
      transition.call

      # After transition
      duration = Time.current - start_time
      Rails.logger.info "Confirmation completed in #{duration}s"
    end
  end
end
```

**Around callbacks:**
- Must call `transition.call` to execute the transition
- Can wrap with logging, timing, exception handling
- Executed in instance context
- Can be nested (multiple around callbacks)

**Nested around callbacks:**

```ruby
transition :confirm, from: :pending, to: :confirmed do
  around do |transition|
    Rails.logger.info "Outer start"
    transition.call
    Rails.logger.info "Outer end"
  end

  around do |transition|
    Rails.logger.info "Inner start"
    transition.call
    Rails.logger.info "Inner end"
  end
end

# Execution order:
# 1. Outer start
# 2. Inner start
# 3. [actual transition]
# 4. Inner end
# 5. Outer end
```

## State History Tracking

Stateable automatically tracks all state transitions:

```ruby
order = Order.create!(customer: customer)
# state: "pending"

order.confirm!
# Creates StateTransition record

order.pay!
# Creates another StateTransition record

# Query history
order.state_transitions
# => [
#   #<StateTransition event: "pay", from_state: "confirmed", to_state: "paid", created_at: ...>,
#   #<StateTransition event: "confirm", from_state: "pending", to_state: "confirmed", created_at: ...>
# ]

# Formatted history
order.transition_history
# => [
#   {event: "pay", from: "confirmed", to: "paid", at: 2025-01-15 14:30:00, metadata: {}},
#   {event: "confirm", from: "pending", to: "confirmed", at: 2025-01-15 10:00:00, metadata: {}}
# ]
```

### Adding Metadata to Transitions

Pass metadata when transitioning:

```ruby
order.confirm!(
  user_id: current_user.id,
  ip_address: request.remote_ip,
  notes: "Confirmed via admin panel"
)

# Retrieve metadata
order.state_transitions.first.metadata
# => {
#   "user_id" => 123,
#   "ip_address" => "192.168.1.1",
#   "notes" => "Confirmed via admin panel"
# }
```

### Include History in JSON

```ruby
order.as_json(include_transition_history: true)
# => {
#   "id" => 1,
#   "state" => "paid",
#   "transition_history" => [
#     {event: "pay", from: "confirmed", to: "paid", at: ..., metadata: {...}},
#     {event: "confirm", from: "pending", to: "confirmed", at: ..., metadata: {...}}
#   ]
# }
```

## Generated Methods

Stateable automatically generates methods for each state and transition:

### State Predicate Methods

```ruby
stateable do
  state :pending, initial: true
  state :confirmed
  state :paid
end

# Generated methods:
order.pending?    # => true
order.confirmed?  # => false
order.paid?       # => false
```

### Transition Methods

```ruby
stateable do
  state :pending, initial: true
  state :confirmed

  transition :confirm, from: :pending, to: :confirmed
end

# Generated methods:
order.confirm!       # Execute transition (raises on failure)
order.can_confirm?   # Check if transition is allowed (tests guards)

# Usage
if order.can_confirm?
  order.confirm!
else
  puts "Cannot confirm order"
end
```

### Method Naming Convention

| Declaration | Generated Methods |
|-------------|-------------------|
| `state :pending` | `pending?` |
| `state :confirmed` | `confirmed?` |
| `transition :confirm` | `confirm!`, `can_confirm?` |
| `transition :pay` | `pay!`, `can_pay?` |
| `transition :ship` | `ship!`, `can_ship?` |

## Table Naming Options

### Shared Table (Default)

Use a single table for all models:

```ruby
class Order < ApplicationRecord
  stateable do
    # Uses 'state_transitions' table (default)
    state :pending, initial: true
    state :confirmed
  end
end

class Article < ApplicationRecord
  stateable do
    # Uses same 'state_transitions' table
    state :draft, initial: true
    state :published
  end
end
```

**Pros:**
- Single audit trail across all models
- Centralized state history
- Easy cross-model queries

**Cons:**
- Large table over time
- Requires good indexing

### Per-Model Table

Use separate tables for each model:

```ruby
class Order < ApplicationRecord
  stateable do
    transitions_table 'order_state_transitions'
    state :pending, initial: true
  end
end

class Article < ApplicationRecord
  stateable do
    transitions_table 'article_state_transitions'
    state :draft, initial: true
  end
end
```

**Pros:**
- Clear separation per model
- Easier to partition/archive
- Independent evolution

**Cons:**
- More tables to manage

### Custom Shared Table

Use domain-specific naming:

```ruby
class Order < ApplicationRecord
  stateable do
    transitions_table 'commerce_state_log'
    state :pending, initial: true
  end
end

class Payment < ApplicationRecord
  stateable do
    transitions_table 'commerce_state_log'  # Same table
    state :pending, initial: true
  end
end
```

## Database Schema

### State Transitions Table

```ruby
create_table :state_transitions do |t|
  # Polymorphic association (required)
  t.string :transitionable_type, null: false
  t.bigint :transitionable_id, null: false

  # Transition data (required)
  t.string :event, null: false
  t.string :from_state, null: false
  t.string :to_state, null: false

  # Metadata (optional but recommended)
  t.json :metadata  # or t.jsonb :metadata (PostgreSQL)

  # Timestamps (required)
  t.timestamps
end

# Indexes (required for performance)
add_index :state_transitions, [:transitionable_type, :transitionable_id]
add_index :state_transitions, :event
add_index :state_transitions, :created_at
add_index :state_transitions, [:transitionable_type, :transitionable_id, :created_at], name: 'index_state_transitions_on_transitionable_and_created_at'
```

### Model State Column

```ruby
# Add state column to your model table
add_column :orders, :state, :string, null: false, default: "pending"
add_index :orders, :state
```

## Integration with Other Concerns

### With Statusable

Use Statusable for derived statuses:

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Statusable for derived statuses
  statusable do
    status :payable do
      confirmed? && payment_method.present? && !cancelled?
    end

    status :shippable do
      paid? && shipping_address.present?
    end
  end

  # Stateable for state machine
  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid
    state :shipped

    transition :pay, from: :confirmed, to: :paid do
      guard if: :is_payable?  # Uses Statusable
    end

    transition :ship, from: :paid, to: :shipped do
      guard if: :is_shippable?
    end
  end
end
```

### With Traceable

Track all state changes in audit trail:

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Track state changes
  traceable do
    track :state, :cancelled_at, :shipped_at
  end

  stateable do
    state :pending, initial: true
    state :shipped
    state :cancelled

    transition :ship, from: :pending, to: :shipped do
      before { self.shipped_at = Time.current }
    end

    transition :cancel, from: [:pending, :confirmed], to: :cancelled do
      before { self.cancelled_at = Time.current }
    end
  end
end

# State changes are tracked in both systems
order.ship!
# Creates StateTransition record
# Creates Traceable version record with state change
```

### With Archivable

Handle archival as a state:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    with_reason
  end

  stateable do
    state :draft, initial: true
    state :published
    state :archived

    transition :publish, from: :draft, to: :published
    transition :archive, from: :published, to: :archived do
      before { archive!(reason: "Moved to archived state") }
    end
  end
end
```

## Real-world Examples

### E-commerce Order Workflow

```ruby
class Order < ApplicationRecord
  belongs_to :customer
  has_many :items
  belongs_to :payment_method, optional: true

  include BetterModel

  statusable do
    status :ready_to_confirm do
      items.any? && customer.present? && shipping_address.present?
    end

    status :ready_to_pay do
      confirmed? && payment_method.present?
    end
  end

  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid
    state :processing
    state :shipped
    state :delivered
    state :cancelled
    state :refunded

    transition :confirm, from: :pending, to: :confirmed do
      guard if: :is_ready_to_confirm?

      validate do
        errors.add(:base, "Minimum order amount not met") if total_amount < 10
      end

      before :calculate_final_total
      before :reserve_inventory
      after :send_confirmation_email
    end

    transition :pay, from: :confirmed, to: :paid do
      guard if: :is_ready_to_pay?

      validate do
        errors.add(:payment_method, "declined") unless payment_method.valid?
      end

      before :charge_payment
      after :send_receipt
      after :schedule_processing
    end

    transition :process, from: :paid, to: :processing do
      before :notify_warehouse
    end

    transition :ship, from: :processing, to: :shipped do
      guard { tracking_number.present? }

      before { self.shipped_at = Time.current }
      after :send_shipping_notification
    end

    transition :deliver, from: :shipped, to: :delivered do
      before { self.delivered_at = Time.current }
      after :send_delivery_confirmation
    end

    transition :cancel, from: [:pending, :confirmed], to: :cancelled do
      before :release_inventory
      after :send_cancellation_email
    end

    transition :refund, from: [:paid, :processing, :shipped], to: :refunded do
      guard { refundable? }

      before :process_refund
      after :send_refund_notification
    end
  end

  private

  def calculate_final_total
    self.total_amount = items.sum(&:price) + shipping_cost
  end

  def reserve_inventory
    items.each(&:reserve!)
  end

  def charge_payment
    payment_method.charge!(total_amount)
  end

  def refundable?
    paid_at > 30.days.ago
  end
end
```

### Document Approval Workflow

```ruby
class Document < ApplicationRecord
  belongs_to :author, class_name: "User"
  belongs_to :reviewer, class_name: "User", optional: true

  include BetterModel

  stateable do
    state :draft, initial: true
    state :submitted
    state :under_review
    state :approved
    state :rejected
    state :published

    transition :submit, from: :draft, to: :submitted do
      guard { content.present? && title.present? }

      validate do
        errors.add(:base, "Must have at least 100 words") if word_count < 100
      end

      before { self.submitted_at = Time.current }
      after :notify_reviewers
    end

    transition :start_review, from: :submitted, to: :under_review do
      guard { reviewer.present? }

      before { self.review_started_at = Time.current }
      after :notify_author_review_started
    end

    transition :approve, from: :under_review, to: :approved do
      guard { reviewer.present? }

      validate do
        errors.add(:approval_notes, "required") if approval_notes.blank?
      end

      before { self.approved_at = Time.current }
      after :notify_author_approved
    end

    transition :reject, from: :under_review, to: :rejected do
      validate do
        errors.add(:rejection_reason, "required") if rejection_reason.blank?
      end

      before { self.rejected_at = Time.current }
      after :notify_author_rejected
    end

    transition :revise, from: :rejected, to: :draft do
      before { self.revision_count += 1 }
    end

    transition :publish, from: :approved, to: :published do
      before { self.published_at = Time.current }
      after :notify_subscribers
      after :index_for_search
    end
  end

  # Track state changes with metadata
  def submit_for_review!(user:)
    submit!(
      user_id: user.id,
      submitted_from: "web",
      timestamp: Time.current
    )
  end
end
```

### Support Ticket Workflow

```ruby
class SupportTicket < ApplicationRecord
  belongs_to :customer
  belongs_to :agent, class_name: "User", optional: true

  include BetterModel

  statusable do
    status :needs_attention do
      open? && (first_response_at.nil? || last_response_at < 1.hour.ago)
    end

    status :assignable do
      open? && agent.nil?
    end
  end

  stateable do
    transitions_table 'ticket_state_transitions'

    state :open, initial: true
    state :assigned
    state :in_progress
    state :waiting_on_customer
    state :resolved
    state :closed

    transition :assign, from: [:open, :assigned], to: :assigned do
      guard { agent.present? }

      before :notify_agent_assigned
    end

    transition :start_work, from: :assigned, to: :in_progress do
      guard { agent.present? }

      before { self.started_at = Time.current }
    end

    transition :request_info, from: :in_progress, to: :waiting_on_customer do
      validate do
        errors.add(:base, "Must specify what info is needed") if notes.blank?
      end

      after :notify_customer_info_needed
    end

    transition :resume, from: :waiting_on_customer, to: :in_progress do
      guard { customer_responded? }
    end

    transition :resolve, from: [:in_progress, :waiting_on_customer], to: :resolved do
      validate do
        errors.add(:resolution_notes, "required") if resolution_notes.blank?
      end

      before { self.resolved_at = Time.current }
      after :send_resolution_notification
    end

    transition :reopen, from: [:resolved, :closed], to: :in_progress do
      guard { reopenable? }

      before { self.reopened_count += 1 }
      after :notify_agent_reopened
    end

    transition :close, from: :resolved, to: :closed do
      guard { resolved_at < 48.hours.ago }

      before { self.closed_at = Time.current }
      after :run_satisfaction_survey
    end
  end

  private

  def customer_responded?
    last_customer_message_at > last_agent_message_at
  end

  def reopenable?
    closed_at > 7.days.ago && reopened_count < 3
  end
end
```

## Error Handling

Stateable raises specific errors for different failure scenarios:

```ruby
# NotEnabledError - Stateable not enabled
begin
  order.confirm!
rescue BetterModel::Stateable::NotEnabledError => e
  # Stateable is not enabled. Add 'stateable do...end' to your model.
end

# InvalidTransitionError - Invalid state transition
begin
  order.ship!  # But order is still "pending"
rescue BetterModel::InvalidTransitionError => e
  e.message
  # => "Cannot transition from 'pending' to 'shipped' via 'ship'"
  e.event       # => :ship
  e.from_state  # => "pending"
  e.to_state    # => "shipped"
end

# GuardFailedError - Guard condition not met
begin
  order.pay!  # But payment_method is nil
rescue BetterModel::GuardFailedError => e
  e.message
  # => "Guard failed for transition 'pay': method guard: payment_method_present?"
  e.event        # => :pay
  e.guard_description  # => "method guard: payment_method_present?"
end

# ValidationFailedError - Validation failed
begin
  order.confirm!  # But items array is empty
rescue BetterModel::ValidationFailedError => e
  e.message
  # => "Validation failed for transition 'confirm': Must have at least one item"
  e.event   # => :confirm
  e.errors  # => ActiveModel::Errors object
end
```

### Handling Errors in Controllers

```ruby
class OrdersController < ApplicationController
  def confirm
    @order = Order.find(params[:id])
    @order.confirm!(user_id: current_user.id)

    redirect_to @order, notice: "Order confirmed"
  rescue BetterModel::InvalidTransitionError
    redirect_to @order, alert: "Order cannot be confirmed in current state"
  rescue BetterModel::GuardFailedError => e
    redirect_to @order, alert: "Cannot confirm: #{e.guard_description}"
  rescue BetterModel::ValidationFailedError => e
    redirect_to @order, alert: "Validation failed: #{e.errors.full_messages.join(', ')}"
  end
end
```

### Conditional Transitions with Error Handling

```ruby
if order.can_confirm?
  begin
    order.confirm!(user_id: current_user.id, notes: params[:notes])
    flash[:notice] = "Order confirmed successfully"
  rescue BetterModel::ValidationFailedError => e
    flash[:alert] = "Validation failed: #{e.errors.full_messages.join(', ')}"
  end
else
  flash[:alert] = "Order cannot be confirmed at this time"
end
```

## Best Practices

### ✅ Do

- **Define all states explicitly** - Make the state machine complete and clear
- **Use initial state** - Always specify which state is initial
- **Keep states simple** - States should be nouns (pending, confirmed), not verbs
- **Use guards liberally** - Prevent invalid transitions with guard conditions
- **Validate business rules** - Use validations for complex business logic
- **Track metadata** - Pass context (user_id, reason, etc.) when transitioning
- **Use before callbacks for side effects** - Database updates, calculations
- **Use after callbacks for notifications** - Emails, webhooks, logging
- **Name transitions as verbs** - confirm, pay, ship (actions that cause state change)
- **Test transition paths** - Ensure all paths through state machine work
- **Use Statusable integration** - Derive complex conditions as status predicates

### ❌ Don't

- **Don't bypass the state machine** - Always use transition methods, not direct `update(state: ...)`
- **Don't make states too granular** - Too many states make the machine complex
- **Don't forget initial state** - Every state machine needs a starting point
- **Don't skip validations** - Use validations to enforce business rules
- **Don't use callbacks for business logic** - Guards and validations are better
- **Don't ignore errors** - Handle transition errors appropriately
- **Don't track non-state data** - Use Traceable for change tracking
- **Don't skip indexes** - State transitions table needs proper indexes
- **Don't mix concerns** - State is persistent, status is derived (use Statusable)

### State Machine Design

```ruby
# ✅ Good: Clear states and transitions
stateable do
  state :draft, initial: true
  state :published
  state :archived

  transition :publish, from: :draft, to: :published
  transition :archive, from: :published, to: :archived
  transition :unarchive, from: :archived, to: :draft
end

# ❌ Bad: Too granular
stateable do
  state :created
  state :validating
  state :validated
  state :processing
  state :processed
  state :finalizing
  state :finalized
  # Too many states!
end
```

### Guard vs Validation

```ruby
# ✅ Good: Use guards for preconditions
transition :pay, from: :confirmed, to: :paid do
  guard { payment_method.present? }  # Precondition

  validate do
    # Business rule validation
    errors.add(:total, "too high") if total_amount > customer.credit_limit
  end
end

# ❌ Bad: Using validation for preconditions
transition :pay, from: :confirmed, to: :paid do
  validate do
    errors.add(:payment_method, "required") if payment_method.nil?  # Should be guard
  end
end
```

### Callback Usage

```ruby
# ✅ Good: Clear separation of concerns
transition :confirm, from: :pending, to: :confirmed do
  before :calculate_total       # Modify record before state change
  before :reserve_inventory     # Update related data

  after :send_confirmation      # Side effects after state saved
  after :notify_warehouse       # External notifications
end

# ❌ Bad: Business logic in callbacks
transition :confirm, from: :pending, to: :confirmed do
  before do
    if items.empty?
      # Don't do validation in callbacks!
      raise "No items"
    end
  end
end

# Should be:
transition :confirm, from: :pending, to: :confirmed do
  guard { items.any? }  # Or use validate block
end
```

---

**Next Steps:**

- Check out [Integration Guide](integration_guide.md) for combining Stateable with other concerns
- See [Performance Guide](performance_guide.md) for optimization tips
- Read [Migration Guide](migration_guide.md) for adding Stateable to existing models

**Related Documentation:**
- [Statusable](statusable.md) - Declarative status management (great for guards)
- [Traceable](traceable.md) - Audit trail for state changes
- [Validatable](validatable.md) - Advanced validation system
