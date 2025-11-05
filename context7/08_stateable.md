# Stateable - State Machine with Guards, Validations, and History

## Overview

Stateable provides a powerful state machine implementation for ActiveRecord models with:

- **Explicit State Definitions**: Define allowed states with one marked as initial
- **Typed Transitions**: Named events that move between states with validation
- **Guards**: Conditional checks that prevent invalid transitions (`check`)
- **Custom Validations**: Transition-specific validations with error messages
- **Callbacks**: `before_transition`, `after_transition`, `around` hooks
- **State History**: Optional tracking of all state changes with metadata
- **Dynamic Methods**: Auto-generated predicate and event methods
- **Error Handling**: Comprehensive validation and guard failures
- **Integration**: Works with Statusable for conditional guards

## Requirements

- Rails 8.0+
- Ruby 3.0+
- ActiveRecord model

## Installation

Generate the migration for the model with state fields:

```bash
rails generate better_model:stateable Order
rails db:migrate
```

This adds to your model:
```ruby
# Migration adds:
t.string :state, null: false, default: 'pending'
```

For transition history tracking, generate the history table:

```bash
rails generate better_model:stateable_history Order
rails db:migrate
```

This creates:
```ruby
create_table :order_state_transitions do |t|
  t.references :order, null: false, foreign_key: true
  t.string :from_state, null: false
  t.string :to_state, null: false
  t.string :event, null: false
  t.bigint :triggered_by_id
  t.jsonb :metadata
  t.timestamps
end
```

## Basic Configuration

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    # Define states - exactly one must be initial: true
    state :pending, initial: true
    state :confirmed
    state :paid
    state :shipped
    state :delivered
    state :cancelled

    # Define transitions with events
    transition :confirm, from: :pending, to: :confirmed
    transition :pay, from: :confirmed, to: :paid
    transition :ship, from: :paid, to: :shipped
    transition :deliver, from: :shipped, to: :delivered
    transition :cancel, from: [:pending, :confirmed], to: :cancelled
  end
end

# Usage
order = Order.create!(total: 100.00)
order.pending?           # => true
order.state              # => "pending"

order.confirm!           # Execute transition
order.confirmed?         # => true

order.can_pay?          # => true (check if transition allowed)
order.pay!
order.paid?             # => true

# Invalid transitions raise errors
order.confirm!          # => BetterModel::Stateable::InvalidTransition
```

## Generated Methods

For each state defined:
- `state?` - Predicate method (e.g., `pending?`, `confirmed?`)

For each transition defined:
- `event!` - Execute transition (e.g., `confirm!`, `pay!`, `cancel!`)
- `can_event?` - Check if transition is allowed (e.g., `can_confirm?`, `can_pay?`)

```ruby
stateable do
  state :draft, initial: true
  state :published

  transition :publish, from: :draft, to: :published
end

# Generated methods:
article.draft?           # State predicate
article.published?       # State predicate
article.publish!         # Execute transition
article.can_publish?     # Check if allowed
```

## Guards (Conditional Checks)

Guards prevent transitions unless conditions are met. They're evaluated before validations.

### Block Guards

```ruby
stateable do
  state :pending, initial: true
  state :confirmed

  transition :confirm, from: :pending, to: :confirmed do
    check { total >= 10.00 }
    check { items.any? }
    check { customer.verified? }
  end
end

order = Order.create!(total: 5.00)
order.can_confirm?       # => false (total < 10)
order.confirm!           # => raises InvalidTransition

order.update!(total: 15.00)
order.can_confirm?       # => true
order.confirm!           # => success
```

### Method Guards

```ruby
stateable do
  transition :ship, from: :paid, to: :shipped do
    check :has_shipping_address
    check :inventory_available
  end
end

private

def has_shipping_address
  shipping_address.present?
end

def inventory_available
  items.all? { |item| item.stock > 0 }
end
```

### Predicate Guards (Statusable Integration)

```ruby
class Order < ApplicationRecord
  include BetterModel

  is :verified, -> { verification_status == "verified" }
  is :fraudulent, -> { fraud_score > 80 }

  stateable do
    state :pending, initial: true
    state :processing

    transition :process, from: :pending, to: :processing do
      check if: :verified?          # Uses Statusable predicate
      check unless: :fraudulent?    # Negative check
    end
  end
end

order = Order.create!
order.can_process?       # => false (not verified)

order.mark_as_verified!
order.can_process?       # => true
```

### Multiple Guard Types

```ruby
transition :approve, from: :submitted, to: :approved do
  # Block guards
  check { amount <= 10_000 }
  check { approver.present? }

  # Method guards
  check :valid_budget_code
  check :department_approved

  # Predicate guards
  check if: :compliant?
  check unless: :expired?
end
```

## Validations

Custom validations run after guards pass and add errors to the model.

```ruby
stateable do
  state :draft, initial: true
  state :published

  transition :publish, from: :draft, to: :published do
    # Guards run first
    check { author.present? }

    # Validations run after guards pass
    validate do
      errors.add(:title, "must be present") if title.blank?
      errors.add(:content, "must be at least 100 characters") if content.length < 100
      errors.add(:category, "must be selected") if category.blank?
    end

    validate do
      if images.none?
        errors.add(:images, "must include at least one image")
      end
    end
  end
end

article = Article.create!(author: User.first)
result = article.publish!
# => false (validation failed)

article.errors.full_messages
# => ["Title must be present", "Content must be at least 100 characters", ...]

article.update!(title: "My Article", content: "..." * 50, category: "Tech")
article.publish!
# => true
```

### Difference: Guards vs Validations

**Guards** (`check`):
- Run first, before validations
- Boolean checks that prevent transition
- Don't add errors to the model
- Use for business logic conditions
- Failure raises `InvalidTransition`

**Validations** (`validate`):
- Run after guards pass
- Add detailed error messages
- Allow checking validity without raising
- Use for data validation
- Failure makes event method return `false`

```ruby
transition :submit, from: :draft, to: :pending_review do
  # Guard: Business rule
  check { user.can_submit? }

  # Validation: Data requirements
  validate do
    errors.add(:base, "Must have content") if content.blank?
  end
end

# Guard failure - raises immediately
document.submit!  # => InvalidTransition (if user.can_submit? is false)

# Validation failure - returns false, sets errors
document.submit!  # => false (if content blank)
document.errors.full_messages  # => ["Must have content"]
```

## Callbacks

Execute code before, after, or around transitions.

### Before Transition

```ruby
stateable do
  state :pending, initial: true
  state :confirmed

  transition :confirm, from: :pending, to: :confirmed do
    before_transition do
      self.confirmed_at = Time.current
      self.confirmation_number = SecureRandom.hex(8)
    end

    before_transition do
      OrderMailer.confirmation_email(self).deliver_later
    end
  end
end
```

### After Transition

```ruby
stateable do
  transition :ship, from: :paid, to: :shipped do
    after_transition do
      TrackingService.create_shipment(self)
      NotificationService.notify_customer(self, :shipped)
    end

    after_transition do
      InventoryService.reserve_items(self.items)
    end
  end
end
```

### Around Transition

```ruby
stateable do
  transition :pay, from: :confirmed, to: :paid do
    around do |transition|
      PaymentService.start_transaction(self)

      begin
        transition.call  # Execute the state change
        PaymentService.commit_transaction(self)
      rescue => e
        PaymentService.rollback_transaction(self)
        raise
      end
    end
  end
end
```

### Multiple Callbacks

```ruby
transition :complete, from: :in_progress, to: :completed do
  before_transition do
    self.completed_at = Time.current
  end

  before_transition do
    validate_all_tasks_done
  end

  after_transition do
    send_completion_notifications
  end

  after_transition do
    update_statistics
  end

  around do |t|
    ActiveRecord::Base.transaction do
      t.call
      finalize_billing
    end
  end
end
```

## Transition History

Track all state changes with metadata.

### Basic History

```ruby
class Order < ApplicationRecord
  include BetterModel

  # Association is auto-created if history table exists
  # has_many :state_transitions, class_name: 'OrderStateTransition'

  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid

    transition :confirm, from: :pending, to: :confirmed
    transition :pay, from: :confirmed, to: :paid
  end
end

order = Order.create!
order.confirm!
order.pay!

# Access history
order.state_transitions.count  # => 2
order.state_transitions.last
# => #<OrderStateTransition
#      from_state: "confirmed",
#      to_state: "paid",
#      event: "pay",
#      created_at: ...>

# Formatted history
order.transition_history
# => [
#   {
#     from_state: "pending",
#     to_state: "confirmed",
#     event: "confirm",
#     triggered_by: nil,
#     metadata: {},
#     transitioned_at: 2025-01-15 10:30:00 UTC
#   },
#   {
#     from_state: "confirmed",
#     to_state: "paid",
#     event: "pay",
#     triggered_by: nil,
#     metadata: {},
#     transitioned_at: 2025-01-15 10:35:00 UTC
#   }
# ]
```

### With Metadata and User Tracking

```ruby
# Track who triggered the transition
order.ship!(triggered_by: current_user.id)

# Add metadata
order.cancel!(
  triggered_by: admin.id,
  metadata: {
    reason: "Customer request",
    refund_amount: 99.99,
    notes: "Processed via support ticket #12345"
  }
)

# Query history
last_transition = order.state_transitions.last
last_transition.triggered_by_id  # => admin.id
last_transition.metadata
# => {
#   "reason" => "Customer request",
#   "refund_amount" => 99.99,
#   "notes" => "Processed via support ticket #12345"
# }
```

### Include in JSON Responses

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    # ... states and transitions
  end

  def as_json(options = {})
    super(options).tap do |json|
      if options[:include_transition_history]
        json['transition_history'] = transition_history
      end
    end
  end
end

# API response
order.as_json(include_transition_history: true)
# => {
#   "id" => 1,
#   "state" => "shipped",
#   "total" => 99.99,
#   "transition_history" => [
#     { "from_state" => "pending", "to_state" => "confirmed", ... },
#     { "from_state" => "confirmed", "to_state" => "paid", ... },
#     { "from_state" => "paid", "to_state" => "shipped", ... }
#   ]
# }
```

## Error Handling

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed

    transition :confirm, from: :pending, to: :confirmed do
      check { total >= 10.00 }

      validate do
        errors.add(:customer, "must be verified") unless customer.verified?
      end
    end
  end
end

order = Order.create!(total: 5.00)

# Guard failure - raises exception
begin
  order.confirm!
rescue BetterModel::Stateable::InvalidTransition => e
  puts e.message  # => "Cannot transition from pending to confirmed"
end

# Check before attempting
if order.can_confirm?
  order.confirm!
else
  # Handle inability to transition
  Rails.logger.warn "Order #{order.id} cannot be confirmed"
end

# Validation failure - returns false
order.update!(total: 15.00)
result = order.confirm!  # => false (customer not verified)

if result
  redirect_to order, notice: "Order confirmed"
else
  flash.now[:alert] = order.errors.full_messages.join(", ")
  render :show
end
```

---

## Example 1: E-commerce Order Management

Complete order lifecycle with payment processing, inventory management, and shipping.

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_stateable_to_orders.rb
class AddStateableToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :state, :string, null: false, default: 'cart'
    add_column :orders, :confirmed_at, :datetime
    add_column :orders, :paid_at, :datetime
    add_column :orders, :shipped_at, :datetime
    add_column :orders, :delivered_at, :datetime
    add_column :orders, :cancelled_at, :datetime
    add_column :orders, :cancellation_reason, :text

    add_index :orders, :state
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_order_state_transitions.rb
class CreateOrderStateTransitions < ActiveRecord::Migration[8.0]
  def change
    create_table :order_state_transitions do |t|
      t.references :order, null: false, foreign_key: true
      t.string :from_state, null: false
      t.string :to_state, null: false
      t.string :event, null: false
      t.bigint :triggered_by_id
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :order_state_transitions, [:order_id, :created_at]
    add_index :order_state_transitions, :triggered_by_id
  end
end

# app/models/order.rb
class Order < ApplicationRecord
  include BetterModel

  belongs_to :customer, class_name: 'User'
  has_many :line_items, dependent: :destroy
  has_many :products, through: :line_items
  belongs_to :shipping_address, class_name: 'Address', optional: true

  is :payment_verified, -> { payment_verification_code.present? }
  is :fraud_check_passed, -> { fraud_check_status == "passed" }
  is :inventory_reserved, -> { inventory_reservation_id.present? }

  stateable do
    # States
    state :cart, initial: true
    state :pending_payment
    state :payment_processing
    state :paid
    state :preparing
    state :shipped
    state :delivered
    state :cancelled
    state :refunded

    # Checkout: Cart -> Pending Payment
    transition :checkout, from: :cart, to: :pending_payment do
      check { line_items.any? }
      check { shipping_address.present? }
      check { customer.email.present? }

      validate do
        errors.add(:base, "Cart is empty") if line_items.empty?
        errors.add(:shipping_address, "is required") if shipping_address.blank?
        errors.add(:customer, "email is required") if customer.email.blank?
      end

      before_transition do
        self.confirmed_at = Time.current
        calculate_totals
      end

      after_transition do
        OrderMailer.checkout_confirmation(self).deliver_later
      end
    end

    # Process Payment: Pending -> Processing
    transition :process_payment, from: :pending_payment, to: :payment_processing do
      check { total > 0 }

      before_transition do
        # Initiate payment processing
        self.payment_started_at = Time.current
      end

      around do |t|
        PaymentGateway.start_transaction(self) do
          t.call
        end
      end
    end

    # Payment Success: Processing -> Paid
    transition :confirm_payment, from: :payment_processing, to: :paid do
      check if: :payment_verified?
      check unless: :fraud_check_failed?

      validate do
        unless payment_verification_code.present?
          errors.add(:payment, "verification code missing")
        end
      end

      before_transition do
        self.paid_at = Time.current
      end

      after_transition do
        mark_as_payment_verified!
        mark_as_fraud_check_passed!
        OrderMailer.payment_received(self).deliver_later
        reserve_inventory
      end
    end

    # Start Preparation: Paid -> Preparing
    transition :start_preparation, from: :paid, to: :preparing do
      check if: :inventory_reserved?
      check { warehouse_assigned? }

      after_transition do
        WarehouseService.create_pick_list(self)
        update_estimated_ship_date
      end
    end

    # Ship Order: Preparing -> Shipped
    transition :ship, from: :preparing, to: :shipped do
      check { tracking_number.present? }
      check { all_items_packed? }

      validate do
        errors.add(:tracking_number, "is required") if tracking_number.blank?

        unpacked = line_items.reject(&:packed?)
        if unpacked.any?
          errors.add(:base, "Items not packed: #{unpacked.map(&:product_name).join(', ')}")
        end
      end

      before_transition do
        self.shipped_at = Time.current
      end

      after_transition do
        deduct_inventory
        ShippingService.notify_carrier(self)
        OrderMailer.shipment_notification(self).deliver_later
        TrackingUpdateJob.perform_later(self.id)
      end
    end

    # Deliver: Shipped -> Delivered
    transition :deliver, from: :shipped, to: :delivered do
      before_transition do
        self.delivered_at = Time.current
      end

      after_transition do
        OrderMailer.delivery_confirmation(self).deliver_later
        ReviewRequestJob.set(wait: 2.days).perform_later(self.id)
      end
    end

    # Cancel: Multiple states -> Cancelled
    transition :cancel, from: [:cart, :pending_payment, :payment_processing, :paid, :preparing], to: :cancelled do
      validate do
        if cancellation_reason.blank?
          errors.add(:cancellation_reason, "must be provided")
        end
      end

      before_transition do
        self.cancelled_at = Time.current
      end

      after_transition do
        release_inventory if inventory_reserved?

        if paid?
          RefundService.process_refund(self)
        end

        OrderMailer.cancellation_notice(self).deliver_later
      end
    end

    # Refund: Paid/Delivered -> Refunded
    transition :refund, from: [:paid, :preparing, :shipped, :delivered], to: :refunded do
      check { refundable? }

      validate do
        if refund_reason.blank?
          errors.add(:refund_reason, "is required")
        end

        if delivered_at && delivered_at < 30.days.ago
          errors.add(:base, "Refund period expired (30 days)")
        end
      end

      around do |t|
        RefundService.start_refund(self) do
          t.call
          RefundService.process_payment_refund(self)
        end
      end

      after_transition do
        release_inventory if inventory_reserved?
        OrderMailer.refund_processed(self).deliver_later
      end
    end
  end

  # Helper methods
  def calculate_totals
    self.subtotal = line_items.sum(&:total)
    self.tax = subtotal * 0.08
    self.shipping_cost = calculate_shipping
    self.total = subtotal + tax + shipping_cost
  end

  def warehouse_assigned?
    warehouse_id.present?
  end

  def all_items_packed?
    line_items.all?(&:packed?)
  end

  def refundable?
    paid? || preparing? || shipped? || delivered?
  end

  def reserve_inventory
    line_items.each do |item|
      InventoryService.reserve(item.product, item.quantity)
    end
    mark_as_inventory_reserved!
  end

  def release_inventory
    line_items.each do |item|
      InventoryService.release(item.product, item.quantity)
    end
    unmark_as_inventory_reserved!
  end

  def deduct_inventory
    line_items.each do |item|
      InventoryService.deduct(item.product, item.quantity)
    end
  end
end

# Usage Examples

# 1. Normal order flow
order = Order.create!(customer: customer, shipping_address: address)
order.line_items.create!(product: product, quantity: 2, price: 29.99)

order.cart?  # => true

# Checkout
order.checkout!
order.pending_payment?  # => true
# Email sent, totals calculated

# Process payment
order.process_payment!
order.payment_processing?  # => true

# Payment confirmed by gateway webhook
order.confirm_payment!(
  triggered_by: system_user.id,
  metadata: {
    payment_id: "ch_abc123",
    payment_method: "credit_card",
    last4: "4242"
  }
)
order.paid?  # => true
# Inventory reserved, email sent

# Start preparing
order.start_preparation!
order.preparing?  # => true
# Pick list created

# Ship
order.update!(tracking_number: "1Z999AA10123456784")
order.line_items.each { |item| item.update!(packed: true) }
order.ship!(
  triggered_by: warehouse_user.id,
  metadata: {
    carrier: "UPS",
    service: "Ground",
    weight: "2.5 lbs"
  }
)
order.shipped?  # => true
# Inventory deducted, tracking started

# Deliver
order.deliver!(
  triggered_by: system_user.id,
  metadata: {
    signature: "J. Doe",
    delivered_to: "Front porch"
  }
)
order.delivered?  # => true

# 2. Cancellation scenarios
order = Order.create!(customer: customer)
order.line_items.create!(product: product, quantity: 1)
order.checkout!

# Customer cancels before payment
order.cancellation_reason = "Changed mind"
order.cancel!(triggered_by: customer.id)
order.cancelled?  # => true

# Cancel after payment (refund processed)
paid_order = Order.find(123)
paid_order.paid?  # => true
paid_order.cancellation_reason = "Out of stock"
paid_order.cancel!(triggered_by: admin.id)
# Inventory released, refund initiated

# 3. Refund after delivery
delivered_order = Order.find(456)
delivered_order.delivered?  # => true
delivered_order.refund_reason = "Damaged on arrival"
delivered_order.refund!(
  triggered_by: support_user.id,
  metadata: {
    damage_photos: ["photo1.jpg", "photo2.jpg"],
    support_ticket: "#SUP-789"
  }
)
delivered_order.refunded?  # => true

# 4. Check transition history
order.transition_history
# => [
#   { from_state: "cart", to_state: "pending_payment", event: "checkout", ... },
#   { from_state: "pending_payment", to_state: "payment_processing", ... },
#   { from_state: "payment_processing", to_state: "paid", ... },
#   { from_state: "paid", to_state: "preparing", ... },
#   { from_state: "preparing", to_state: "shipped", ... },
#   { from_state: "shipped", to_state: "delivered", ... }
# ]

# 5. Error handling
order = Order.create!(customer: customer)
# No line items, no address

order.can_checkout?  # => false (guards fail)

begin
  order.checkout!
rescue BetterModel::Stateable::InvalidTransition => e
  puts e.message  # => "Cannot transition from cart to pending_payment"
end

# Add items and address
order.line_items.create!(product: product, quantity: 1)
order.shipping_address = address
order.save!

order.can_checkout?  # => true
order.checkout!  # => success
```

---

## Example 2: Document Approval Workflow

Multi-level approval system with role-based transitions and rejection handling.

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_stateable_to_documents.rb
class AddStateableToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :state, :string, null: false, default: 'draft'
    add_column :documents, :submitted_at, :datetime
    add_column :documents, :manager_approved_at, :datetime
    add_column :documents, :director_approved_at, :datetime
    add_column :documents, :published_at, :datetime
    add_column :documents, :rejected_at, :datetime
    add_column :documents, :rejection_reason, :text
    add_column :documents, :current_approver_id, :bigint

    add_index :documents, :state
    add_index :documents, :current_approver_id
  end
end

# app/models/document.rb
class Document < ApplicationRecord
  include BetterModel

  belongs_to :author, class_name: 'User'
  belongs_to :current_approver, class_name: 'User', optional: true
  has_many :approvals, dependent: :destroy

  is :legal_reviewed, -> { legal_reviewed_at.present? }
  is :compliance_checked, -> { compliance_checked_at.present? }
  is :final_review_required, -> { document_value > 100_000 || sensitive_category? }

  stateable do
    # States
    state :draft, initial: true
    state :submitted
    state :manager_review
    state :director_review
    state :final_review
    state :approved
    state :published
    state :rejected
    state :archived

    # Submit: Draft -> Submitted
    transition :submit, from: :draft, to: :submitted do
      check { content.present? }
      check { title.present? }

      validate do
        errors.add(:title, "must be at least 10 characters") if title.length < 10
        errors.add(:content, "must be at least 100 characters") if content.length < 100
        errors.add(:category, "must be selected") if category.blank?
      end

      before_transition do
        self.submitted_at = Time.current
        self.current_approver = find_manager_approver
      end

      after_transition do
        NotificationService.notify_approver(current_approver, self)
        create_approval_record(current_approver, 'manager')
      end
    end

    # Manager Review: Submitted -> Manager Review
    transition :start_manager_review, from: :submitted, to: :manager_review do
      check { current_approver.present? }
      check { current_approver.has_role?(:manager) }

      after_transition do
        update_approval_status(current_approver, 'in_review')
      end
    end

    # Manager Approval: Manager Review -> Director Review
    transition :approve_by_manager, from: :manager_review, to: :director_review do
      check { can_be_approved_by?(current_user) }
      check { current_user.has_role?(:manager) }

      validate do
        if approval_comments.blank?
          errors.add(:approval_comments, "are required")
        end
      end

      before_transition do
        self.manager_approved_at = Time.current
        self.current_approver = find_director_approver
      end

      after_transition do
        complete_approval_record(current_user, 'approved')
        create_approval_record(current_approver, 'director')
        NotificationService.notify_approver(current_approver, self)
        NotificationService.notify_author(author, :manager_approved)
      end
    end

    # Director Approval: Director Review -> Final Review or Approved
    transition :approve_by_director, from: :director_review, to: :final_review do
      check { current_user.has_role?(:director) }
      check if: :final_review_required?

      before_transition do
        self.director_approved_at = Time.current
        self.current_approver = find_executive_approver
      end

      after_transition do
        complete_approval_record(current_user, 'approved')
        create_approval_record(current_approver, 'executive')
        NotificationService.notify_approver(current_approver, self)
      end
    end

    transition :approve_by_director_final, from: :director_review, to: :approved do
      check { current_user.has_role?(:director) }
      check unless: :final_review_required?

      before_transition do
        self.director_approved_at = Time.current
      end

      after_transition do
        complete_approval_record(current_user, 'approved')
        NotificationService.notify_author(author, :fully_approved)
        prepare_for_publication
      end
    end

    # Final Approval: Final Review -> Approved
    transition :approve_final, from: :final_review, to: :approved do
      check { current_user.has_role?(:executive) }
      check if: :legal_reviewed?
      check if: :compliance_checked?

      validate do
        errors.add(:base, "Legal review incomplete") unless legal_reviewed?
        errors.add(:base, "Compliance check incomplete") unless compliance_checked?
      end

      after_transition do
        complete_approval_record(current_user, 'approved')
        NotificationService.notify_all_stakeholders(self, :approved)
        prepare_for_publication
      end
    end

    # Publish: Approved -> Published
    transition :publish, from: :approved, to: :published do
      check { can_be_published? }
      check { publication_date.present? }

      before_transition do
        self.published_at = Time.current
      end

      after_transition do
        DocumentPublisher.publish(self)
        SearchIndex.index_document(self)
        NotificationService.broadcast_publication(self)
      end
    end

    # Rejection: Any review state -> Rejected
    transition :reject, from: [:submitted, :manager_review, :director_review, :final_review], to: :rejected do
      validate do
        errors.add(:rejection_reason, "must be provided") if rejection_reason.blank?
      end

      before_transition do
        self.rejected_at = Time.current
        self.current_approver = nil
      end

      after_transition do
        complete_approval_record(current_user, 'rejected', rejection_reason)
        NotificationService.notify_author(author, :rejected)
      end
    end

    # Resubmit: Rejected -> Submitted
    transition :resubmit, from: :rejected, to: :submitted do
      check { author == current_user }
      check { content_modified_since_rejection? }

      validate do
        errors.add(:base, "Must address rejection feedback") unless addressed_feedback?
      end

      before_transition do
        self.submitted_at = Time.current
        self.rejected_at = nil
        self.rejection_reason = nil
        self.current_approver = find_manager_approver
      end

      after_transition do
        create_approval_record(current_approver, 'manager')
        NotificationService.notify_approver(current_approver, self)
      end
    end

    # Archive: Published -> Archived
    transition :archive, from: :published, to: :archived do
      check { current_user.has_role?(:admin, :manager) }

      validate do
        if archive_reason.blank?
          errors.add(:archive_reason, "must be provided")
        end
      end

      after_transition do
        SearchIndex.remove_document(self)
        NotificationService.notify_subscribers(self, :archived)
      end
    end
  end

  # Helper methods
  def find_manager_approver
    User.where(role: 'manager', department: author.department).first
  end

  def find_director_approver
    User.where(role: 'director', department: author.department).first
  end

  def find_executive_approver
    User.where(role: 'executive').first
  end

  def can_be_approved_by?(user)
    current_approver == user
  end

  def can_be_published?
    approved? && all_approvals_complete?
  end

  def content_modified_since_rejection?
    updated_at > rejected_at
  end

  def addressed_feedback?
    # Custom logic to check if author addressed feedback
    rejection_feedback_addressed == true
  end

  def all_approvals_complete?
    required_approvals = ['manager', 'director']
    required_approvals << 'executive' if final_review_required?

    required_approvals.all? do |level|
      approvals.exists?(level: level, status: 'approved')
    end
  end

  def create_approval_record(approver, level)
    approvals.create!(
      approver: approver,
      level: level,
      status: 'pending'
    )
  end

  def update_approval_status(approver, status)
    approvals.find_by(approver: approver)&.update!(status: status)
  end

  def complete_approval_record(approver, status, comments = nil)
    approval = approvals.find_by(approver: approver)
    approval&.update!(
      status: status,
      comments: comments,
      approved_at: Time.current
    )
  end

  def prepare_for_publication
    # Set publication date if not set
    self.publication_date ||= Time.current + 1.day
    save!
  end
end

# Usage Examples

# 1. Normal approval flow
doc = Document.create!(
  title: "New Marketing Strategy 2025",
  content: "..." * 100,
  category: "Marketing",
  author: employee
)

doc.draft?  # => true

# Submit for review
doc.submit!(triggered_by: employee.id)
doc.submitted?  # => true
doc.current_approver  # => manager

# Manager reviews
doc.start_manager_review!(triggered_by: manager.id)
doc.approval_comments = "Looks good, minor typo on page 3"
doc.approve_by_manager!(
  triggered_by: manager.id,
  metadata: { reviewed_pages: "all", rating: "excellent" }
)
doc.director_review?  # => true

# Director approves (no final review needed)
doc.approve_by_director_final!(triggered_by: director.id)
doc.approved?  # => true

# Publish
doc.publication_date = 1.week.from_now
doc.publish!(triggered_by: admin.id)
doc.published?  # => true

# 2. Rejection and resubmit
doc = Document.create!(title: "Proposal", content: "...", author: employee)
doc.submit!
doc.start_manager_review!(triggered_by: manager.id)

# Manager rejects
doc.rejection_reason = "Insufficient data analysis in section 3"
doc.reject!(
  triggered_by: manager.id,
  metadata: { sections_needing_work: [3, 5] }
)
doc.rejected?  # => true

# Author revises and resubmits
doc.update!(content: "... revised content ...")
doc.rejection_feedback_addressed = true
doc.resubmit!(triggered_by: employee.id)
doc.submitted?  # => true

# 3. Final review path (high-value doc)
doc = Document.create!(
  title: "Company Restructuring Plan",
  content: "...",
  author: director,
  value: 1_000_000
)
doc.mark_as_final_review_required!
doc.submit!
doc.start_manager_review!(triggered_by: manager.id)
doc.approve_by_manager!(triggered_by: manager.id)
doc.approve_by_director!(triggered_by: director.id)
doc.final_review?  # => true

# Executive reviews
doc.mark_as_legal_reviewed!
doc.mark_as_compliance_checked!
doc.approve_final!(triggered_by: ceo.id)
doc.approved?  # => true

# 4. Archive published document
published_doc = Document.find(123)
published_doc.published?  # => true
published_doc.archive_reason = "Outdated information"
published_doc.archive!(triggered_by: manager.id)
published_doc.archived?  # => true

# 5. View approval history
doc.transition_history
# => [
#   {
#     from_state: "draft",
#     to_state: "submitted",
#     event: "submit",
#     triggered_by: employee.id,
#     transitioned_at: ...
#   },
#   {
#     from_state: "submitted",
#     to_state: "manager_review",
#     event: "start_manager_review",
#     ...
#   },
#   ...
# ]

doc.approvals.map(&:summary)
# => [
#   { level: "manager", approver: "John Smith", status: "approved", approved_at: ... },
#   { level: "director", approver: "Jane Doe", status: "approved", approved_at: ... },
#   { level: "executive", approver: "Bob Johnson", status: "approved", approved_at: ... }
# ]
```

---

## Example 3: Support Ticket Lifecycle

Customer support ticket system with SLA tracking, escalation, and resolution.

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_stateable_to_tickets.rb
class AddStateableToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :state, :string, null: false, default: 'open'
    add_column :tickets, :assigned_at, :datetime
    add_column :tickets, :in_progress_at, :datetime
    add_column :tickets, :resolved_at, :datetime
    add_column :tickets, :closed_at, :datetime
    add_column :tickets, :escalated_at, :datetime
    add_column :tickets, :escalation_reason, :text
    add_column :tickets, :resolution_notes, :text
    add_column :tickets, :sla_breached, :boolean, default: false

    add_index :tickets, :state
    add_index :tickets, [:state, :priority]
  end
end

# app/models/ticket.rb
class Ticket < ApplicationRecord
  include BetterModel

  belongs_to :customer, class_name: 'User'
  belongs_to :assigned_agent, class_name: 'User', optional: true
  belongs_to :escalated_to, class_name: 'User', optional: true
  has_many :comments, dependent: :destroy

  enum priority: { low: 0, medium: 1, high: 2, critical: 3 }

  is :first_response_sent, -> { first_response_at.present? }
  is :customer_responded, -> { last_customer_response_at.present? }
  is :waiting_on_engineering, -> { state == "waiting_internal" }
  is :waiting_on_customer, -> { state == "waiting_customer" }

  stateable do
    # States
    state :open, initial: true
    state :assigned
    state :in_progress
    state :waiting_customer
    state :waiting_internal
    state :escalated
    state :resolved
    state :closed
    state :reopened

    # Assign: Open -> Assigned
    transition :assign, from: [:open, :reopened], to: :assigned do
      check { assigned_agent.present? }
      check { assigned_agent.available? }

      validate do
        if assigned_agent.current_ticket_count >= assigned_agent.max_tickets
          errors.add(:assigned_agent, "has reached maximum ticket capacity")
        end
      end

      before_transition do
        self.assigned_at = Time.current
        calculate_sla_deadline
      end

      after_transition do
        NotificationService.notify_agent(assigned_agent, self)
        update_agent_workload(assigned_agent, :increment)
      end
    end

    # Start Work: Assigned -> In Progress
    transition :start_work, from: :assigned, to: :in_progress do
      check { assigned_agent == current_user }

      before_transition do
        self.in_progress_at = Time.current
      end

      after_transition do
        check_sla_compliance
      end
    end

    # Customer Waiting: In Progress -> Waiting Customer
    transition :request_customer_info, from: :in_progress, to: :waiting_customer do
      check { assigned_agent == current_user }

      validate do
        errors.add(:base, "Must specify what information is needed") if info_request.blank?
      end

      before_transition do
        mark_as_waiting_on_customer!
      end

      after_transition do
        NotificationService.request_info_from_customer(customer, self, info_request)
        pause_sla_timer
      end
    end

    # Customer Responds: Waiting Customer -> In Progress
    transition :receive_customer_response, from: :waiting_customer, to: :in_progress do
      before_transition do
        unmark_as_waiting_on_customer!
        mark_as_customer_responded!
      end

      after_transition do
        resume_sla_timer
        NotificationService.notify_agent(assigned_agent, :customer_responded)
      end
    end

    # Internal Waiting: In Progress -> Waiting Internal
    transition :escalate_to_engineering, from: :in_progress, to: :waiting_internal do
      check { assigned_agent == current_user }

      validate do
        errors.add(:engineering_details, "must be provided") if engineering_details.blank?
      end

      before_transition do
        mark_as_waiting_on_engineering!
      end

      after_transition do
        EngineeringTicket.create_from_support(self)
        NotificationService.notify_engineering_team(self)
        pause_sla_timer
      end
    end

    # Engineering Responds: Waiting Internal -> In Progress
    transition :receive_internal_response, from: :waiting_internal, to: :in_progress do
      before_transition do
        unmark_as_waiting_on_engineering!
      end

      after_transition do
        resume_sla_timer
        NotificationService.notify_agent(assigned_agent, :engineering_responded)
      end
    end

    # Escalate: Any active state -> Escalated
    transition :escalate, from: [:assigned, :in_progress, :waiting_customer, :waiting_internal], to: :escalated do
      check { can_escalate? }

      validate do
        errors.add(:escalation_reason, "is required") if escalation_reason.blank?
        errors.add(:escalated_to, "must be a senior agent") unless escalated_to&.senior?
      end

      before_transition do
        self.escalated_at = Time.current
        self.previous_agent = assigned_agent
        self.assigned_agent = escalated_to
      end

      after_transition do
        NotificationService.notify_escalation(escalated_to, self)
        NotificationService.notify_manager(:ticket_escalated, self)
        increase_priority if can_increase_priority?
      end
    end

    # De-escalate: Escalated -> In Progress
    transition :deescalate, from: :escalated, to: :in_progress do
      check { escalated_to == current_user }

      after_transition do
        # Keeps current assigned_agent (the senior agent)
        self.escalated_to = nil
        save!
      end
    end

    # Resolve: Active states -> Resolved
    transition :resolve, from: [:in_progress, :escalated], to: :resolved do
      check { assigned_agent == current_user }

      validate do
        errors.add(:resolution_notes, "are required") if resolution_notes.blank?

        if resolution_notes.length < 20
          errors.add(:resolution_notes, "must be detailed (minimum 20 characters)")
        end
      end

      before_transition do
        self.resolved_at = Time.current
        check_sla_compliance
      end

      after_transition do
        NotificationService.notify_customer(customer, :ticket_resolved)
        update_agent_workload(assigned_agent, :decrement)
        schedule_auto_close
        mark_as_first_response_sent! unless first_response_sent?
      end
    end

    # Close: Resolved -> Closed
    transition :close, from: :resolved, to: :closed do
      before_transition do
        self.closed_at = Time.current
      end

      after_transition do
        SatisfactionSurvey.send_to_customer(customer, self)
        update_agent_metrics(assigned_agent)
      end
    end

    # Reopen: Closed -> Reopened
    transition :reopen, from: :closed, to: :reopened do
      check { can_reopen? }

      validate do
        if closed_at < 7.days.ago
          errors.add(:base, "Cannot reopen tickets closed more than 7 days ago")
        end
      end

      before_transition do
        self.reopened_at = Time.current
        self.resolved_at = nil
        self.closed_at = nil
      end

      after_transition do
        NotificationService.notify_agent(assigned_agent, :ticket_reopened)
        NotificationService.notify_manager(:ticket_reopened, self)
      end
    end
  end

  # Helper methods
  def calculate_sla_deadline
    hours = case priority
            when 'critical' then 4
            when 'high' then 24
            when 'medium' then 72
            when 'low' then 168
            end
    self.sla_deadline = Time.current + hours.hours
  end

  def check_sla_compliance
    if Time.current > sla_deadline
      self.sla_breached = true
      NotificationService.notify_manager(:sla_breach, self)
    end
  end

  def pause_sla_timer
    self.sla_paused_at = Time.current
    save!
  end

  def resume_sla_timer
    if sla_paused_at
      pause_duration = Time.current - sla_paused_at
      self.sla_deadline += pause_duration
      self.sla_paused_at = nil
      save!
    end
  end

  def can_escalate?
    critical? || high? || sla_breached? || escalation_requested_by_customer?
  end

  def can_increase_priority?
    !critical?
  end

  def increase_priority
    self.priority = (priority_before_type_cast + 1).clamp(0, 3)
    save!
  end

  def can_reopen?
    closed_at && closed_at > 7.days.ago
  end

  def schedule_auto_close
    AutoCloseTicketJob.set(wait: 48.hours).perform_later(id)
  end

  def update_agent_workload(agent, operation)
    case operation
    when :increment
      agent.increment!(:current_ticket_count)
    when :decrement
      agent.decrement!(:current_ticket_count)
    end
  end

  def update_agent_metrics(agent)
    agent_metric = agent.metrics.find_or_create_by(date: Date.current)
    agent_metric.increment!(:tickets_resolved)
    agent_metric.update!(average_resolution_time: calculate_average_resolution_time)
  end

  def calculate_average_resolution_time
    return 0 unless resolved_at && created_at

    total_time = resolved_at - created_at
    paused_time = calculate_total_paused_time
    total_time - paused_time
  end

  def calculate_total_paused_time
    # Calculate time spent in waiting_customer and waiting_internal states
    transitions = state_transitions.where(to_state: ['waiting_customer', 'waiting_internal'])
    # Implementation details...
    0
  end
end

# Usage Examples

# 1. Normal ticket flow
ticket = Ticket.create!(
  customer: customer,
  subject: "Cannot login to account",
  description: "Getting error message when trying to login",
  priority: :high
)

ticket.open?  # => true

# Assign to agent
ticket.assigned_agent = agent
ticket.assign!(triggered_by: manager.id)
ticket.assigned?  # => true
# SLA deadline calculated

# Agent starts work
ticket.start_work!(triggered_by: agent.id)
ticket.in_progress?  # => true
# First response timer checked

# Need info from customer
ticket.info_request = "Please provide your username and last successful login date"
ticket.request_customer_info!(triggered_by: agent.id)
ticket.waiting_customer?  # => true
# Email sent to customer, SLA timer paused

# Customer responds
ticket.comments.create!(author: customer, content: "Username: john.doe, last login: 2025-01-10")
ticket.receive_customer_response!(triggered_by: system_user.id)
ticket.in_progress?  # => true
# SLA timer resumed

# Resolve ticket
ticket.resolution_notes = "Reset password and verified login successful. Issue was due to account lockout after multiple failed attempts."
ticket.resolve!(
  triggered_by: agent.id,
  metadata: {
    resolution_type: "password_reset",
    time_spent: 15,
    tools_used: ["admin_panel", "password_reset_tool"]
  }
)
ticket.resolved?  # => true
# Customer notified, auto-close scheduled

# Auto-close after 48 hours
ticket.close!(triggered_by: system_user.id)
ticket.closed?  # => true
# Survey sent

# 2. Escalation scenario
ticket = Ticket.create!(
  customer: vip_customer,
  subject: "Data loss in recent sync",
  priority: :critical
)
ticket.assigned_agent = junior_agent
ticket.assign!
ticket.start_work!(triggered_by: junior_agent.id)

# Escalate to senior agent
ticket.escalation_reason = "Critical data loss requires senior engineer review"
ticket.escalated_to = senior_agent
ticket.escalate!(
  triggered_by: junior_agent.id,
  metadata: {
    data_affected: "customer_records",
    estimated_records: 1500
  }
)
ticket.escalated?  # => true
# Priority possibly increased, manager notified

# Senior agent works on it
ticket.deescalate!(triggered_by: senior_agent.id)
ticket.in_progress?  # => true

ticket.resolution_notes = "Recovered data from backup. Implemented additional safeguards."
ticket.resolve!(triggered_by: senior_agent.id)

# 3. Engineering escalation
ticket = Ticket.create!(
  customer: customer,
  subject: "Feature not working as expected",
  priority: :medium
)
ticket.assigned_agent = agent
ticket.assign!
ticket.start_work!(triggered_by: agent.id)

# Needs engineering input
ticket.engineering_details = "Customer reports export feature fails for datasets > 10,000 rows. Possible memory issue."
ticket.escalate_to_engineering!(
  triggered_by: agent.id,
  metadata: {
    feature: "data_export",
    error_logs: ["error1.log", "error2.log"]
  }
)
ticket.waiting_internal?  # => true
# Engineering ticket created, SLA paused

# Engineering responds
ticket.comments.create!(
  author: engineering_user,
  content: "Fixed memory issue in export service. Deployed to production."
)
ticket.receive_internal_response!(triggered_by: system_user.id)
ticket.in_progress?  # => true

# Agent verifies fix and resolves
ticket.resolution_notes = "Engineering fixed the export issue. Verified with customer that exports now work for large datasets."
ticket.resolve!(triggered_by: agent.id)

# 4. Reopen scenario
closed_ticket = Ticket.find(789)
closed_ticket.closed?  # => true
closed_ticket.closed_at  # => 2 days ago

# Customer reports issue persists
closed_ticket.comments.create!(
  author: customer,
  content: "The issue is happening again"
)
closed_ticket.reopen!(
  triggered_by: customer.id,
  metadata: { reason: "Issue recurred" }
)
closed_ticket.reopened?  # => true
# Agent and manager notified

# 5. SLA tracking
ticket.state_transitions.where(to_state: 'resolved').first&.created_at
# => Resolution timestamp

ticket.sla_breached?  # => true/false
ticket.calculate_total_paused_time  # => Time paused while waiting

# View complete history
ticket.transition_history
# => [
#   { from_state: "open", to_state: "assigned", event: "assign", ... },
#   { from_state: "assigned", to_state: "in_progress", event: "start_work", ... },
#   { from_state: "in_progress", to_state: "waiting_customer", ... },
#   { from_state: "waiting_customer", to_state: "in_progress", ... },
#   { from_state: "in_progress", to_state: "resolved", ... },
#   { from_state: "resolved", to_state: "closed", ... }
# ]
```

---

## Example 4: Project Task Management

Agile task board with sprint workflow, dependencies, and team collaboration.

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  include BetterModel

  belongs_to :project
  belongs_to :sprint, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :creator, class_name: 'User'
  has_many :dependencies, class_name: 'TaskDependency', foreign_key: :task_id
  has_many :blocking_tasks, through: :dependencies, source: :depends_on_task

  enum task_type: { feature: 0, bug: 1, chore: 2, spike: 3 }

  is :blocked, -> { blocking_tasks.exists? }
  is :ready_for_review, -> { pull_request_url.present? && tests_passing? }
  is :approved, -> { approval_count >= required_approvals }

  stateable do
    state :backlog, initial: true
    state :todo
    state :in_progress
    state :code_review
    state :testing
    state :done
    state :archived

    # Add to Sprint: Backlog -> Todo
    transition :add_to_sprint, from: :backlog, to: :todo do
      check { sprint.present? }
      check { sprint.active? }
      check { assignee.present? }

      validate do
        errors.add(:sprint, "is full") if sprint.tasks.count >= sprint.capacity
        errors.add(:story_points, "must be estimated") if story_points.nil?
      end

      after_transition do
        NotificationService.notify_assignee(assignee, :task_assigned)
        sprint.recalculate_metrics
      end
    end

    # Start Work: Todo -> In Progress
    transition :start, from: :todo, to: :in_progress do
      check { assignee == current_user }
      check unless: :blocked?
      check { all_dependencies_complete? }

      before_transition do
        self.started_at = Time.current
      end

      after_transition do
        create_branch_if_needed
      end
    end

    # Submit for Review: In Progress -> Code Review
    transition :submit_for_review, from: :in_progress, to: :code_review do
      check { assignee == current_user }
      check { pull_request_url.present? }

      validate do
        errors.add(:pull_request, "must be open") unless pull_request_open?
        errors.add(:tests, "must pass") unless tests_passing?
      end

      before_transition do
        mark_as_ready_for_review!
      end

      after_transition do
        assign_reviewers
        NotificationService.notify_reviewers(reviewers, self)
      end
    end

    # Move to Testing: Code Review -> Testing
    transition :move_to_testing, from: :code_review, to: :testing do
      check if: :approved?
      check { pull_request_merged? }

      after_transition do
        deploy_to_staging
        NotificationService.notify_qa_team(self)
      end
    end

    # Complete: Testing -> Done
    transition :complete, from: :testing, to: :done do
      check { qa_approved? }

      before_transition do
        self.completed_at = Time.current
      end

      after_transition do
        sprint.recalculate_metrics
        update_related_tasks
        NotificationService.notify_stakeholders(self, :completed)
      end
    end

    # Block: Any active state -> remains same but marks as blocked
    # This uses Statusable instead

    # Archive: Done -> Archived
    transition :archive, from: :done, to: :archived do
      check { completed_at < 30.days.ago }

      after_transition do
        cleanup_resources
      end
    end
  end

  def all_dependencies_complete?
    blocking_tasks.all?(&:done?)
  end
end
```

---

## Example 5: Content Publishing Pipeline

Multi-stage content workflow with SEO optimization, editorial review, and scheduled publishing.

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  include BetterModel

  belongs_to :author, class_name: 'User'
  belongs_to :editor, class_name: 'User', optional: true
  belongs_to :seo_specialist, class_name: 'User', optional: true
  has_many :revisions, dependent: :destroy

  is :seo_optimized, -> { seo_score >= 80 }
  is :images_uploaded, -> { images.any? }
  is :legal_cleared, -> { legal_clearance_at.present? }
  is :featured, -> { featured_at.present? && featured_until > Time.current }

  stateable do
    state :draft, initial: true
    state :editorial_review
    state :seo_review
    state :scheduled
    state :published
    state :unpublished

    transition :submit_for_review, from: :draft, to: :editorial_review do
      check { content.present? }
      check { title.present? }
      check if: :images_uploaded?

      validate do
        errors.add(:word_count, "must be at least 300 words") if word_count < 300
        errors.add(:images, "at least one required") unless images.any?
      end

      after_transition do
        assign_editor
        NotificationService.notify_editor(editor, self)
      end
    end

    transition :approve_editorial, from: :editorial_review, to: :seo_review do
      check { editor == current_user }

      after_transition do
        assign_seo_specialist
        NotificationService.notify_seo(seo_specialist, self)
      end
    end

    transition :approve_seo, from: :seo_review, to: :scheduled do
      check if: :seo_optimized?
      check { publish_at.present? }

      after_transition do
        schedule_publication
      end
    end

    transition :publish, from: [:scheduled, :unpublished], to: :published do
      before_transition do
        self.published_at = Time.current
      end

      after_transition do
        notify_subscribers
        update_sitemap
      end
    end

    transition :unpublish, from: :published, to: :unpublished do
      after_transition do
        remove_from_sitemap
      end
    end
  end
end
```

---

## Integration with Other Features

### With Statusable

Use Statusable predicates in guards:

```ruby
class Order < ApplicationRecord
  include BetterModel

  statusable do
    status :verified
    status :high_risk
  end

  stateable do
    state :pending, initial: true
    state :processing

    transition :process, from: :pending, to: :processing do
      check if: :verified?           # Statusable predicate
      check unless: :high_risk?      # Statusable predicate
    end
  end
end

order = Order.create!
order.can_process?  # => false (not verified)

order.mark_as_verified!
order.can_process?  # => true

order.mark_as_high_risk!
order.can_process?  # => false (high risk)
```

### With Searchable/Predicable

Query by state:

```ruby
# Using Predicable
Order.where_state_eq('pending')
Order.where_state_in(['pending', 'confirmed'])
Order.where_state_not_eq('cancelled')

# Using Search
Order.search({ state_eq: 'pending' })
Order.search({
  state_in: ['pending', 'confirmed'],
  created_at_gteq: 1.week.ago
})
```

### With Archivable

Archive completed state machines:

```ruby
class Order < ApplicationRecord
  include BetterModel
  include BetterModel::Archivable

  stateable do
    state :pending, initial: true
    state :completed

    transition :complete, from: :pending, to: :completed do
      after_transition do
        # Auto-archive after 90 days
        ArchiveOrderJob.set(wait: 90.days).perform_later(id)
      end
    end
  end
end
```

## Best Practices

### 1. Keep State Count Manageable

```ruby
# Good: Clear, essential states
stateable do
  state :draft, initial: true
  state :review
  state :published
end

# Avoid: Too granular
stateable do
  state :draft, initial: true
  state :spell_check
  state :grammar_check
  state :seo_check
  state :image_check
  # ... use Statusable for these checks instead
end
```

### 2. Use Guards for Business Logic

```ruby
# Good: Guards for conditions
transition :approve, from: :pending, to: :approved do
  check { amount <= user.approval_limit }
  check { department_budget_available? }
end

# Avoid: Checking in controller
def approve
  if @document.amount <= current_user.approval_limit
    @document.approve!
  end
end
```

### 3. Validations for Data Requirements

```ruby
transition :submit, from: :draft, to: :submitted do
  # Guard for business rule
  check { user.can_submit? }

  # Validation for data completeness
  validate do
    errors.add(:title, "required") if title.blank?
    errors.add(:content, "too short") if content.length < 100
  end
end
```

### 4. Use Callbacks for Side Effects

```ruby
transition :publish, from: :approved, to: :published do
  before_transition do
    self.published_at = Time.current
  end

  after_transition do
    notify_subscribers
    update_search_index
    clear_caches
  end
end
```

### 5. Track Important Transitions

```ruby
# Always track critical workflows
order.ship!(
  triggered_by: warehouse_user.id,
  metadata: {
    tracking_number: "1Z999...",
    carrier: "UPS",
    weight: "2.5 lbs"
  }
)

# Review history for auditing
order.transition_history.select { |t| t[:event] == 'ship' }
```

### 6. Use Predicate Guards for Complex Logic

```ruby
class Order < ApplicationRecord
  stateable do
    transition :charge, from: :pending, to: :paid do
      check :payment_method_valid?
      check :inventory_available?
      check :not_fraudulent?
    end
  end

  private

  def payment_method_valid?
    payment_method.present? && !payment_method.expired?
  end

  def inventory_available?
    items.all? { |item| item.in_stock? }
  end

  def not_fraudulent?
    FraudService.check(self).safe?
  end
end
```

### 7. Handle Errors Gracefully

```ruby
# Controller
def transition_to_next_state
  if @order.can_process?
    if @order.process!(triggered_by: current_user.id)
      redirect_to @order, notice: "Order processed successfully"
    else
      flash.now[:alert] = @order.errors.full_messages.join(", ")
      render :show
    end
  else
    flash[:alert] = "Order cannot be processed at this time"
    redirect_to @order
  end
rescue BetterModel::Stateable::InvalidTransition => e
  flash[:alert] = "Invalid state transition: #{e.message}"
  redirect_to @order
end
```

### 8. Document Complex Workflows

```ruby
stateable do
  # Order Lifecycle:
  # 1. Customer checkout: cart -> pending
  # 2. Payment processing: pending -> processing -> paid
  # 3. Fulfillment: paid -> preparing -> shipped
  # 4. Completion: shipped -> delivered
  # 5. Exceptions: any -> cancelled/refunded

  state :cart, initial: true
  state :pending
  # ... rest of configuration
end
```

## Common Patterns

### Pattern 1: Multi-Approval Workflow

```ruby
stateable do
  state :draft, initial: true
  state :manager_review
  state :director_review
  state :approved

  transition :submit, from: :draft, to: :manager_review
  transition :manager_approve, from: :manager_review, to: :director_review
  transition :director_approve, from: :director_review, to: :approved

  # Rejection returns to previous state
  transition :manager_reject, from: :manager_review, to: :draft
  transition :director_reject, from: :director_review, to: :manager_review
end
```

### Pattern 2: Parallel States with Statusable

```ruby
# Use Stateable for primary workflow state
# Use Statusable for parallel concerns

stateable do
  state :active, initial: true
  state :completed
end

statusable do
  status :verified      # Can happen while active
  status :featured      # Can happen while active
  status :flagged       # Can happen while active
end
```

### Pattern 3: Scheduled Transitions

```ruby
transition :publish, from: :scheduled, to: :published do
  before_transition do
    self.published_at = Time.current
  end

  after_transition do
    # Schedule unpublish if expiration set
    if expires_at.present?
      UnpublishJob.set(wait_until: expires_at).perform_later(id)
    end
  end
end
```

## Troubleshooting

### "Cannot transition" Error

```ruby
# Check guards and validations
order.can_confirm?  # => false

# Inspect why
order.confirm!  # => shows specific error

# Fix and retry
order.update!(required_field: value)
order.confirm!  # => success
```

### State Not Changing

```ruby
# Ensure you're calling the event method
order.confirm!  # Correct - executes transition

order.state = 'confirmed'  # Wrong - bypasses state machine
order.save!
```

### History Not Recording

```ruby
# Ensure migration was run
rails generate better_model:stateable_history Order
rails db:migrate

# Verify table exists
OrderStateTransition.table_exists?  # => true
```

## Performance Considerations

### Eager Load History

```ruby
# Avoid N+1 queries
orders = Order.includes(:state_transitions).where(state: 'completed')

orders.each do |order|
  puts order.transition_history  # No additional queries
end
```

### Index State Column

```ruby
# Migration
add_index :orders, :state
add_index :orders, [:state, :created_at]
```

### Batch Transitions

```ruby
# When transitioning many records
Order.where(state: 'pending').find_each do |order|
  order.confirm! if order.can_confirm?
end
```
