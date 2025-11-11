# Stateable - State Machine with Guards and History

State machine implementation with explicit states, typed transitions, guards, validations, callbacks, and optional transition history tracking.

**Requirements**: Rails 8.0+, Ruby 3.0+, `state` string column
**Installation**: `rails generate better_model:stateable Model`

**⚠️ Version 3.0.0 Compatible**: All error handling in this document uses standard Ruby exception patterns.

---

## Database Setup

### Basic State Column

**Cosa fa**: Adds state column to model

**Quando usarlo**: For state machine functionality

**Esempio**:
```bash
rails generate better_model:stateable Order
rails db:migrate
```

```ruby
# Generated migration
class AddStateToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :state, :string, null: false, default: 'pending'
    add_index :orders, :state
  end
end
```

---

### With Transition History

**Cosa fa**: Adds table to track state transitions

**Quando usarlo**: For audit trail of state changes

**Esempio**:
```bash
rails generate better_model:stateable_history Order
rails db:migrate
```

```ruby
# Generated migration
class CreateOrderStateTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :order_state_transitions do |t|
      t.references :order, null: false, foreign_key: true
      t.string :from_state, null: false
      t.string :to_state, null: false
      t.string :event, null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :order_state_transitions, [:order_id, :created_at]
  end
end
```

---

## Basic State Machine

### Simple States and Transitions

**Cosa fa**: Defines states and transitions between them

**Quando usarlo**: For workflow management

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed
    state :shipped
    state :delivered
    state :cancelled

    event :confirm do
      transition from: :pending, to: :confirmed
    end

    event :ship do
      transition from: :confirmed, to: :shipped
    end

    event :deliver do
      transition from: :shipped, to: :delivered
    end

    event :cancel do
      transition from: [:pending, :confirmed], to: :cancelled
    end
  end
end

# Usage
order = Order.create!  # state: "pending"
order.confirm!         # state: "confirmed"
order.ship!            # state: "shipped"
order.deliver!         # state: "delivered"
```

---

## State Predicates

### Checking Current State

**Cosa fa**: Boolean methods to check current state

**Quando usarlo**: For conditional logic based on state

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed
    state :shipped
  end
end

order = Order.create!

# Auto-generated predicate methods
order.pending?    # => true
order.confirmed?  # => false
order.shipped?    # => false

# Useful in conditionals
if order.pending?
  puts "Waiting for confirmation"
elsif order.shipped?
  puts "On its way!"
end
```

---

## Guards

### Preventing Invalid Transitions

**Cosa fa**: Conditional checks that block transitions

**Quando usarlo**: To enforce business rules

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel
  belongs_to :user

  stateable do
    state :pending, initial: true
    state :confirmed
    state :shipped

    event :confirm do
      transition from: :pending, to: :confirmed

      # Guard: blocks transition if condition fails
      check -> { payment_received? }, "Payment not received"
      check -> { stock_available? }, "Items out of stock"
    end

    event :ship do
      transition from: :confirmed, to: :shipped
      check -> { shipping_address.present? }, "Shipping address required"
    end
  end

  def payment_received?
    payment_status == 'paid'
  end

  def stock_available?
    order_items.all? { |item| item.product.stock > 0 }
  end
end

# Usage
order = Order.create!(payment_status: 'pending')
order.confirm!  # Raises error: "Payment not received"

order.update!(payment_status: 'paid')
order.confirm!  # OK if stock available
```

---

### Multiple Guards

**Cosa fa**: Chains multiple guard conditions

**Quando usarlo**: For complex validation logic

**Esempio**:
```ruby
class Document < ApplicationRecord
  include BetterModel

  stateable do
    state :draft, initial: true
    state :review
    state :published

    event :submit_for_review do
      transition from: :draft, to: :review

      # All guards must pass
      check -> { title.present? }, "Title is required"
      check -> { content.present? }, "Content is required"
      check -> { content.length >= 100 }, "Content too short (min 100 chars)"
      check -> { author_id.present? }, "Author is required"
    end

    event :publish do
      transition from: :review, to: :published
      check -> { reviewer_approved? }, "Awaiting reviewer approval"
      check -> { no_pending_changes? }, "Pending changes must be resolved"
    end
  end
end
```

---

## Transition Validations

### Custom Validation Logic

**Cosa fa**: Validates state transitions with custom rules

**Quando usarlo**: For complex business validations

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel
  has_many :order_items

  stateable do
    state :pending, initial: true
    state :confirmed

    event :confirm do
      transition from: :pending, to: :confirmed

      validate_transition do
        if order_items.empty?
          errors.add(:base, "Cannot confirm empty order")
        end

        if total_amount < 10.00
          errors.add(:base, "Minimum order amount is $10.00")
        end

        order_items.each do |item|
          if item.quantity > item.product.stock
            errors.add(:base, "Insufficient stock for #{item.product.name}")
          end
        end
      end
    end
  end
end

# Usage
order = Order.create!
order.confirm!  # Raises error with validation messages
```

---

## Callbacks

### Before/After Transition

**Cosa fa**: Executes logic before/after state changes

**Quando usarlo**: For side effects of state changes

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed
    state :shipped
    state :delivered

    event :confirm do
      transition from: :pending, to: :confirmed

      before_transition do
        # Reserve stock
        order_items.each { |item| item.product.reserve_stock(item.quantity) }
      end

      after_transition do
        # Send confirmation email
        OrderMailer.confirmation(self).deliver_later
        # Log event
        Rails.logger.info "Order ##{id} confirmed at #{Time.current}"
      end
    end

    event :ship do
      transition from: :confirmed, to: :shipped

      after_transition do
        # Send shipping notification
        OrderMailer.shipped(self).deliver_later
        # Update inventory
        order_items.each { |item| item.product.decrement_stock!(item.quantity) }
      end
    end
  end
end
```

---

### Around Callbacks

**Cosa fa**: Wraps transition with custom logic

**Quando usarlo**: For transaction-like behavior

**Esempio**:
```ruby
class Payment < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :processing
    state :completed
    state :failed

    event :process do
      transition from: :pending, to: :processing

      around_transition do |transition_proc|
        Rails.logger.info "Starting payment processing..."
        start_time = Time.current

        begin
          transition_proc.call  # Execute the transition
          duration = Time.current - start_time
          Rails.logger.info "Payment processed in #{duration}s"
        rescue => e
          Rails.logger.error "Payment failed: #{e.message}"
          raise
        end
      end
    end
  end
end
```

---

## Transition History

### Enabling History Tracking

**Cosa fa**: Tracks all state transitions

**Quando usarlo**: For audit trails

**Esempio**:
```ruby
# After running: rails g better_model:stateable_history Order

class Order < ApplicationRecord
  include BetterModel
  has_many :state_transitions, class_name: 'OrderStateTransition', dependent: :destroy

  stateable do
    track_transitions true  # Enable history

    state :pending, initial: true
    state :confirmed
    state :shipped
    state :delivered

    event :confirm do
      transition from: :pending, to: :confirmed
    end

    event :ship do
      transition from: :confirmed, to: :shipped
    end
  end
end

# Usage
order = Order.create!
order.confirm!
order.ship!

# View history
order.state_transitions
# => [
#   { from_state: "pending", to_state: "confirmed", event: "confirm", created_at: ... },
#   { from_state: "confirmed", to_state: "shipped", event: "ship", created_at: ... }
# ]
```

---

### Transition Metadata

**Cosa fa**: Stores additional data with transitions

**Quando usarlo**: For detailed audit information

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    track_transitions true

    state :pending, initial: true
    state :confirmed

    event :confirm do
      transition from: :pending, to: :confirmed

      after_transition do |transition|
        # Store metadata
        transition.update(metadata: {
          user_id: Current.user&.id,
          ip_address: Current.ip,
          confirmed_at: Time.current,
          payment_method: payment_method
        })
      end
    end
  end
end

# Query history with metadata
order.state_transitions.find_by(event: 'confirm').metadata
# => { user_id: 123, ip_address: "192.168.1.1", confirmed_at: "2025-11-11 10:30:00", ... }
```

---

## Integration with Statusable

### Using Statusable Guards

**Cosa fa**: Uses Statusable predicates in guards

**Quando usarlo**: For cross-feature conditions

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  # Statusable predicates
  is :ready_for_publish, -> { title.present? && content.present? && author_id.present? }
  is :reviewed, -> { reviewer_id.present? && review_notes.present? }

  stateable do
    state :draft, initial: true
    state :published

    event :publish do
      transition from: :draft, to: :published

      # Use Statusable predicates as guards
      check :is_ready_for_publish?, "Article not ready for publication"
      check :is_reviewed?, "Article must be reviewed first"
    end
  end
end

# Usage
article = Article.create!(title: "Test", content: "...")
article.is_ready_for_publish?  # => false (no author)
article.publish!  # Raises error

article.update!(author_id: 1, reviewer_id: 2, review_notes: "LGTM")
article.publish!  # OK
```

---

## Real-World Use Cases

### E-commerce Order Workflow

**Cosa fa**: Complete order processing state machine

**Quando usarlo**: Online stores

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel
  belongs_to :user
  has_many :order_items

  stateable do
    track_transitions true

    state :cart, initial: true
    state :pending_payment
    state :paid
    state :processing
    state :shipped
    state :delivered
    state :returned
    state :refunded
    state :cancelled

    event :checkout do
      transition from: :cart, to: :pending_payment
      check -> { order_items.any? }, "Cart is empty"
      check -> { shipping_address.present? }, "Shipping address required"
    end

    event :pay do
      transition from: :pending_payment, to: :paid

      validate_transition do
        if payment_token.blank?
          errors.add(:base, "Payment information required")
        end
      end

      after_transition do
        ProcessPaymentJob.perform_later(id)
        OrderMailer.payment_received(self).deliver_later
      end
    end

    event :process do
      transition from: :paid, to: :processing
      check -> { all_items_in_stock? }, "Some items out of stock"

      after_transition do
        reserve_inventory
      end
    end

    event :ship do
      transition from: :processing, to: :shipped

      validate_transition do
        if tracking_number.blank?
          errors.add(:base, "Tracking number required")
        end
      end

      after_transition do
        OrderMailer.shipped(self).deliver_later
      end
    end

    event :deliver do
      transition from: :shipped, to: :delivered
      after_transition do
        OrderMailer.delivered(self).deliver_later
      end
    end

    event :request_return do
      transition from: :delivered, to: :returned
      check -> { within_return_window? }, "Return window expired"
    end

    event :refund do
      transition from: :returned, to: :refunded
      after_transition do
        process_refund
        OrderMailer.refunded(self).deliver_later
      end
    end

    event :cancel do
      transition from: [:cart, :pending_payment, :paid], to: :cancelled

      after_transition do
        if paid?
          process_refund
        end
        release_inventory if processing?
      end
    end
  end

  private

  def all_items_in_stock?
    order_items.all? { |item| item.product.stock >= item.quantity }
  end

  def within_return_window?
    delivered_at.present? && delivered_at >= 30.days.ago
  end
end
```

---

### Document Approval Workflow

**Cosa fa**: Multi-step document approval

**Quando usarlo**: Content management, document systems

**Esempio**:
```ruby
class Document < ApplicationRecord
  include BetterModel
  belongs_to :author, class_name: 'User'
  belongs_to :reviewer, class_name: 'User', optional: true
  belongs_to :approver, class_name: 'User', optional: true

  stateable do
    track_transitions true

    state :draft, initial: true
    state :in_review
    state :approved
    state :published
    state :archived

    event :submit_for_review do
      transition from: :draft, to: :in_review

      validate_transition do
        errors.add(:title, "required") if title.blank?
        errors.add(:content, "required") if content.blank?
        errors.add(:content, "too short") if content.length < 100
      end

      after_transition do
        assign_reviewer
        DocumentMailer.review_requested(self).deliver_later
      end
    end

    event :approve do
      transition from: :in_review, to: :approved
      check -> { reviewer_id.present? }, "Reviewer required"

      after_transition do
        self.reviewed_at = Time.current
        save!
        DocumentMailer.approved(self).deliver_later
      end
    end

    event :reject do
      transition from: :in_review, to: :draft

      after_transition do |transition|
        transition.update(metadata: {
          rejection_reason: rejection_reason,
          reviewer_id: reviewer_id
        })
        DocumentMailer.rejected(self, rejection_reason).deliver_later
      end
    end

    event :publish do
      transition from: :approved, to: :published
      check -> { approver_id.present? }, "Final approval required"

      after_transition do
        self.published_at = Time.current
        save!
        DocumentMailer.published(self).deliver_later
      end
    end

    event :archive do
      transition from: :published, to: :archived

      after_transition do
        self.archived_at = Time.current
        save!
      end
    end
  end

  private

  def assign_reviewer
    self.reviewer = User.reviewers.where.not(id: author_id).sample
    save!
  end
end
```

---

### Task Management

**Cosa fa**: Task lifecycle with assignments

**Quando usarlo**: Project management, issue tracking

**Esempio**:
```ruby
class Task < ApplicationRecord
  include BetterModel
  belongs_to :assignee, class_name: 'User', optional: true

  stateable do
    track_transitions true

    state :todo, initial: true
    state :in_progress
    state :blocked
    state :in_review
    state :done
    state :closed

    event :start do
      transition from: :todo, to: :in_progress
      check -> { assignee_id.present? }, "Task must be assigned"

      after_transition do
        self.started_at = Time.current
        save!
      end
    end

    event :block do
      transition from: :in_progress, to: :blocked

      validate_transition do
        if blocker_reason.blank?
          errors.add(:base, "Blocker reason required")
        end
      end
    end

    event :unblock do
      transition from: :blocked, to: :in_progress

      after_transition do
        self.blocker_reason = nil
        save!
      end
    end

    event :submit_for_review do
      transition from: :in_progress, to: :in_review

      after_transition do
        TaskMailer.review_requested(self).deliver_later
      end
    end

    event :complete do
      transition from: :in_review, to: :done

      after_transition do
        self.completed_at = Time.current
        save!
        TaskMailer.completed(self).deliver_later
      end
    end

    event :reopen do
      transition from: [:done, :closed], to: :todo

      after_transition do
        self.completed_at = nil
        self.closed_at = nil
        save!
      end
    end

    event :close do
      transition from: :done, to: :closed

      after_transition do
        self.closed_at = Time.current
        save!
      end
    end
  end
end
```

---

### Subscription Management

**Cosa fa**: Subscription lifecycle management

**Quando usarlo**: SaaS applications

**Esempio**:
```ruby
class Subscription < ApplicationRecord
  include BetterModel
  belongs_to :user

  stateable do
    track_transitions true

    state :trial, initial: true
    state :active
    state :past_due
    state :suspended
    state :cancelled

    event :activate do
      transition from: :trial, to: :active
      check -> { payment_method_valid? }, "Valid payment method required"

      after_transition do
        self.activated_at = Time.current
        self.next_billing_date = 1.month.from_now
        save!
        SubscriptionMailer.activated(self).deliver_later
      end
    end

    event :payment_failed do
      transition from: :active, to: :past_due

      after_transition do
        self.past_due_since = Time.current
        save!
        SubscriptionMailer.payment_failed(self).deliver_later
      end
    end

    event :payment_received do
      transition from: :past_due, to: :active

      after_transition do
        self.past_due_since = nil
        self.next_billing_date = 1.month.from_now
        save!
      end
    end

    event :suspend do
      transition from: [:active, :past_due], to: :suspended

      after_transition do
        self.suspended_at = Time.current
        save!
        revoke_access
      end
    end

    event :resume do
      transition from: :suspended, to: :active
      check -> { payment_method_valid? }, "Valid payment method required"

      after_transition do
        self.suspended_at = nil
        save!
        restore_access
      end
    end

    event :cancel do
      transition from: [:trial, :active, :past_due, :suspended], to: :cancelled

      after_transition do
        self.cancelled_at = Time.current
        save!
        revoke_access
        SubscriptionMailer.cancelled(self).deliver_later
      end
    end
  end

  private

  def payment_method_valid?
    payment_method.present? && !payment_method.expired?
  end

  def revoke_access
    user.update!(premium: false)
  end

  def restore_access
    user.update!(premium: true)
  end
end
```

---

## Error Handling

### InvalidTransitionError

**Cosa fa**: Raised when transition not allowed

**Quando usarlo**: Catches invalid state changes

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :shipped

    event :ship do
      transition from: :confirmed, to: :shipped
    end
  end
end

order = Order.create!  # state: pending
order.ship!  # No transition from pending to shipped
# Raises: BetterModel::Errors::Stateable::InvalidTransitionError
# Message: "Cannot transition from 'pending' to 'shipped' via 'ship' event"

rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  Rails.logger.error "Invalid transition: #{e.message}"
end
```

---

### GuardFailedError

**Cosa fa**: Raised when guard condition fails

**Quando usarlo**: Business rule violations

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed

    event :confirm do
      transition from: :pending, to: :confirmed
      check -> { payment_received? }, "Payment not received"
    end
  end
end

order = Order.create!(payment_status: 'pending')
order.confirm!
# Raises: BetterModel::Errors::Stateable::GuardFailedError
# Message: "Payment not received"

rescue BetterModel::Errors::Stateable::GuardFailedError => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

---

## Best Practices

### Use Descriptive State Names

**Cosa fa**: Clear, domain-specific state names

**Quando usarlo**: Always

**Esempio**:
```ruby
# Good - clear business meaning
stateable do
  state :pending_review
  state :approved_by_manager
  state :in_production
  state :delivered_to_customer
end

# Bad - ambiguous
stateable do
  state :state1
  state :state2
  state :processing
end
```

---

### Guard Complex Business Rules

**Cosa fa**: Uses guards for business validation

**Quando usarlo**: To prevent invalid state changes

**Esempio**:
```ruby
# Good - enforces business rules
event :publish do
  transition from: :draft, to: :published
  check -> { content_approved? }, "Content not approved"
  check -> { seo_optimized? }, "SEO optimization required"
  check -> { images_uploaded? }, "Featured image required"
end

# Bad - allows invalid transitions
event :publish do
  transition from: :draft, to: :published
  # No guards - can publish incomplete content
end
```

---

### Use Callbacks for Side Effects

**Cosa fa**: Executes related operations in callbacks

**Quando usarlo**: For actions triggered by state changes

**Esempio**:
```ruby
# Good - side effects in callbacks
event :ship do
  transition from: :confirmed, to: :shipped

  after_transition do
    send_shipping_notification
    update_inventory
    log_shipment
  end
end

# Bad - manual side effects
order.ship!
send_shipping_notification(order)
update_inventory(order)
log_shipment(order)
```

---

### Track History for Audit Trails

**Cosa fa**: Enables transition tracking

**Quando usarlo**: For compliance and debugging

**Esempio**:
```ruby
# Good - track important state changes
stateable do
  track_transitions true

  state :pending, initial: true
  state :approved
  state :rejected

  event :approve do
    transition from: :pending, to: :approved

    after_transition do |transition|
      transition.update(metadata: {
        approver_id: Current.user.id,
        approval_notes: approval_notes,
        approved_at: Time.current
      })
    end
  end
end

# Query history
document.state_transitions.where(event: 'approve').last
```

---

### Use validate_transition for Complex Checks

**Cosa fa**: Groups related validations

**Quando usarlo**: For multi-field validations

**Esempio**:
```ruby
# Good - grouped validations
event :submit do
  transition from: :draft, to: :submitted

  validate_transition do
    errors.add(:title, "required") if title.blank?
    errors.add(:content, "too short") if content.length < 100
    errors.add(:category, "required") if category_id.blank?

    if contains_profanity?(content)
      errors.add(:content, "contains inappropriate language")
    end
  end
end

# Bad - scattered checks
event :submit do
  transition from: :draft, to: :submitted
  check -> { title.present? }, "Title required"
  check -> { content.length >= 100 }, "Content too short"
  check -> { category_id.present? }, "Category required"
  # Profanity check missing
end
```

---

## Summary

**Core Features**:
- **State Definitions**: Explicit state declarations with initial state
- **Events**: Named transitions between states
- **Guards**: Conditional checks (`check`) that prevent transitions
- **Validations**: Custom transition validation logic
- **Callbacks**: before_transition, after_transition, around_transition
- **History**: Optional transition tracking with metadata
- **Predicates**: Auto-generated state checking methods
- **Integration**: Works with Statusable for conditional guards

**Key Methods**:
- `Model.stateable do...end` - Configure state machine
- `state :name, initial: true` - Define states
- `event :name do...end` - Define transitions
- `transition from:, to:` - Specify state changes
- `check condition, message` - Add guards
- `validate_transition do...end` - Custom validations
- `before_transition / after_transition` - Callbacks
- `instance.state_name?` - Check current state
- `instance.event_name!` - Trigger transition

**Configuration**:
- `track_transitions true` - Enable history tracking

**Database Columns**:
- `state` (string) - Required, stores current state
- Separate transitions table for history (optional)

**Thread-safe**, **opt-in**, **integrated with Statusable**.
