# Validatable - Declarative Validation System

## Overview

Validatable provides a declarative validation system for Rails models with enhanced features beyond standard ActiveModel validations:

- **Opt-in Activation**: Not active by default - must enable with `validatable do...end`
- **Declarative DSL**: Clean, readable syntax with `check` method
- **Conditional Validations**: Apply rules only when conditions are met (`validate_if`, `validate_unless`)
- **Cross-Field Validations**: Compare values between fields with `validate_order`
- **Business Rules**: Delegate complex logic to custom methods with `validate_business_rule`
- **Validation Groups**: Partial validation for multi-step forms and wizards
- **Statusable Integration**: Use status predicates in conditional validations
- **Full Rails Compatibility**: Works seamlessly with ActiveModel validations
- **Thread-safe**: Immutable configuration and registry

## Requirements

- Rails 8.0+
- Ruby 3.0+
- ActiveRecord model

## Installation

No migration required - Validatable works with existing models.

Simply include BetterModel and activate with the DSL:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Your validations here
  end
end
```

## Basic Configuration

### Enabling Validatable

Use the `validatable do...end` block to activate:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, presence: true
    check :content, presence: true
  end
end
```

### Without Configuration

If you don't call `validatable`, the concern is not active:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Validatable not active - use standard Rails validations
  validates :title, presence: true
end
```

### Empty Configuration

Activate Validatable without adding validations (useful for validation groups):

```ruby
validatable do
  # Empty block - Validatable active but no rules yet
end
```

## Basic Validations

Use `check` to define validations inside the `validatable` block:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Single field validation
    check :title, presence: true

    # Multiple fields with same validation
    check :title, :content, presence: true

    # Multiple validation types on one field
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

    # Numeric validations
    check :view_count, numericality: { greater_than_or_equal_to: 0 }
    check :rating, numericality: { in: 1..5 }

    # Inclusion/exclusion
    check :status, inclusion: { in: %w[draft published archived] }
    check :category, exclusion: { in: %w[forbidden restricted] }

    # Length validations
    check :title, length: { minimum: 3, maximum: 255 }
    check :slug, length: { is: 20 }

    # Uniqueness
    check :slug, uniqueness: true
    check :email, uniqueness: { case_sensitive: false }
  end
end

# Usage
article = Article.new
article.valid?  # => false
article.errors[:title]  # => ["can't be blank"]

article.title = "My Article"
article.content = "Article content here"
article.valid?  # => true
```

### Supported Validation Options

All ActiveModel validation options are supported:

- `presence: true` - Field must be present
- `format: { with: regex }` - Field must match pattern
- `numericality: { ... }` - Numeric constraints (greater_than, less_than, equal_to, etc.)
- `inclusion: { in: array }` - Value must be in list
- `exclusion: { in: array }` - Value must not be in list
- `length: { minimum:, maximum:, is:, in: }` - String length constraints
- `uniqueness: true` - Value must be unique in database

## Conditional Validations

### validate_if

Apply validations only when a condition is true:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses with Statusable
  is :published, -> { status == "published" }
  is :scheduled, -> { status == "scheduled" }
  is :featured, -> { featured? }

  validatable do
    # Always required
    check :title, :content, presence: true

    # Required only when published
    validate_if :is_published? do
      check :published_at, presence: true
      check :author_id, presence: true
      check :reviewer_id, presence: true
    end

    # Required only when scheduled
    validate_if :is_scheduled? do
      check :scheduled_for, presence: true
    end

    # Using lambda instead of method
    validate_if -> { status == "featured" } do
      check :featured_image_url, presence: true
      check :featured_excerpt, presence: true
    end
  end
end

# Usage
article = Article.new(status: "draft", title: "Test", content: "...")
article.valid?  # => true (published_at not required for drafts)

article.status = "published"
article.valid?  # => false (published_at now required)
article.errors[:published_at]  # => ["can't be blank"]

article.published_at = Time.current
article.author_id = 1
article.reviewer_id = 2
article.valid?  # => true
```

### Condition Types

**Symbol** - References a method (usually Statusable predicate):
```ruby
validate_if :is_published? do
  check :published_at, presence: true
end
```

**Proc/Lambda** - Inline condition evaluated in instance context:
```ruby
validate_if -> { status == "published" } do
  check :published_at, presence: true
end
```

### validate_unless

Apply validations only when a condition is false (negated `validate_if`):

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }

  validatable do
    # Required unless draft
    validate_unless :is_draft? do
      check :reviewer_id, presence: true
      check :reviewed_at, presence: true
    end

    # Using lambda
    validate_unless -> { internal_only? } do
      check :public_url, presence: true
      check :seo_title, presence: true
    end
  end
end

# Usage
article = Article.new(status: "draft")
article.valid?  # => true (reviewer not required for drafts)

article.status = "published"
article.valid?  # => false (reviewer now required)
article.errors[:reviewer_id]  # => ["can't be blank"]
```

## Cross-Field Validations

Use `validate_order` to compare values between two fields:

```ruby
class Event < ApplicationRecord
  include BetterModel

  validatable do
    # Date/time comparisons
    check :starts_at, :ends_at, presence: true
    validate_order :starts_at, :before, :ends_at
    validate_order :published_at, :after, :created_at

    # Numeric comparisons
    validate_order :min_price, :lteq, :max_price
    validate_order :discount, :lt, :price
    validate_order :stock, :gteq, :reserved_stock
  end
end

# Usage
event = Event.new(starts_at: 1.day.ago, ends_at: Time.current)
event.valid?  # => true

event = Event.new(starts_at: Time.current, ends_at: 1.day.ago)
event.valid?  # => false
event.errors[:starts_at]  # => ["must be before ends at"]
```

### Supported Comparators

| Comparator | Operator | Use Case | Example |
|------------|----------|----------|---------|
| `:before` | `<` | Dates/times | `starts_at` before `ends_at` |
| `:after` | `>` | Dates/times | `published_at` after `created_at` |
| `:lteq` | `<=` | Numbers | `min_price` ≤ `max_price` |
| `:gteq` | `>=` | Numbers | `stock` ≥ `reserved_stock` |
| `:lt` | `<` | Numbers | `discount` < `price` |
| `:gt` | `>` | Numbers | `total` > `subtotal` |

### With Options

```ruby
validatable do
  # Custom error message
  validate_order :starts_at, :before, :ends_at,
                 message: "must be before event end"

  # Only on create
  validate_order :discount, :lteq, :price, on: :create

  # Conditional
  validate_order :min_age, :lteq, :max_age, if: :has_age_restriction?
end
```

### Nil Handling

Cross-field validations are skipped if either field is `nil`. Use presence validations to ensure fields exist:

```ruby
validatable do
  check :starts_at, :ends_at, presence: true  # Ensure not nil
  validate_order :starts_at, :before, :ends_at   # Then compare
end
```

## Business Rules

Use `validate_business_rule` to delegate complex validation logic to custom methods:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Basic business rule
    validate_business_rule :valid_category

    # With options
    validate_business_rule :author_has_permission, on: :create
    validate_business_rule :can_change_status, if: :status_changed?
  end

  # Implement business rule methods
  # Add errors using errors.add if validation fails
  def valid_category
    return if category_id.blank?

    unless Category.exists?(id: category_id)
      errors.add(:category_id, "must be a valid category")
    end
  end

  def author_has_permission
    return if author.blank?

    unless author.can_create_articles?
      errors.add(:author_id, "does not have permission to create articles")
    end
  end

  def can_change_status
    return unless status_changed?

    old_status, new_status = status_change
    unless valid_status_transition?(old_status, new_status)
      errors.add(:status, "cannot transition from #{old_status} to #{new_status}")
    end
  end

  private

  def valid_status_transition?(from, to)
    allowed_transitions = {
      "draft" => %w[published archived],
      "published" => %w[archived],
      "archived" => []
    }

    allowed_transitions[from]&.include?(to)
  end
end

# Usage
article = Article.new(category_id: 999)
article.valid?  # => false
article.errors[:category_id]  # => ["must be a valid category"]
```

### Key Points

- Business rule methods must be defined in the model
- Methods should add errors using `errors.add(field, message)`
- Methods are called during validation like any other validator
- If the method doesn't exist, a `NoMethodError` is raised with helpful message

## Validation Groups

Validation groups enable partial validation for multi-step forms, wizards, or progressive data entry:

```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    # Step 1: Account creation
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    check :password, presence: true, length: { minimum: 8 }

    # Step 2: Personal details
    check :first_name, :last_name, presence: true

    # Step 3: Contact info
    check :phone, :address, :city, :zip_code, presence: true

    # Define validation groups
    validation_group :account, [:email, :password]
    validation_group :personal, [:first_name, :last_name]
    validation_group :contact, [:phone, :address, :city, :zip_code]
  end
end

# Usage
user = User.new

# Validate only account fields
user.valid?(:account)  # => false (email and password missing)

user.email = "user@example.com"
user.password = "secret123"
user.valid?(:account)  # => true

# Full validation still validates everything
user.valid?  # => false (first_name, last_name, etc. missing)
```

### Get Errors for Specific Group

```ruby
user = User.new
user.valid?  # Run full validation

# Get only errors for account group
account_errors = user.errors_for_group(:account)
account_errors[:email]  # => ["can't be blank"]
account_errors[:first_name]  # => [] (not in account group)
```

### Multi-step Form Example

```ruby
class RegistrationForm
  def initialize(user)
    @user = user
  end

  def validate_step(step_name)
    @user.valid?(step_name)
  end

  def errors_for_step(step_name)
    @user.errors_for_group(step_name)
  end
end

# In controller
def create_account_step
  @user = User.new(account_params)
  form = RegistrationForm.new(@user)

  if form.validate_step(:account)
    session[:user_data] = @user.attributes
    redirect_to registration_personal_path
  else
    @errors = form.errors_for_step(:account)
    render :account_step
  end
end
```

## Instance Methods

### valid?(context)

Override of ActiveModel's `valid?` method with support for validation groups:

```ruby
# Standard validation (all validations)
article.valid?

# Validation group
user.valid?(:account)
user.valid?(:personal)

# Rails validation context
article.valid?(:create)
article.valid?(:update)
```

### validate_group(group_name)

Validate only fields in a specific group:

```ruby
user.validate_group(:account)  # => true/false
```

**Raises:**
- `BetterModel::ValidatableNotEnabledError` if Validatable is not enabled

### errors_for_group(group_name)

Get errors filtered to a specific group's fields:

```ruby
user.valid?  # Run full validation first
errors = user.errors_for_group(:account)
errors[:email]  # => ["can't be blank"]
errors[:first_name]  # => [] (not in account group)
```

**Raises:**
- `BetterModel::ValidatableNotEnabledError` if Validatable is not enabled

## Integration with Statusable

Validatable works seamlessly with Statusable for status-based conditional validations:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses with Statusable
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :scheduled, -> { status == "scheduled" }
  is :archived, -> { status == "archived" }

  # Use statuses in conditional validations
  validatable do
    # Always required
    check :title, :content, presence: true

    # Published-specific validations
    validate_if :is_published? do
      check :published_at, presence: true
      check :author_id, presence: true
      check :reviewer_id, presence: true
    end

    # Scheduled-specific validations
    validate_if :is_scheduled? do
      check :scheduled_for, presence: true
      validate_order :scheduled_for, :after, :created_at
    end

    # Only non-drafts require category
    validate_unless :is_draft? do
      check :category_id, presence: true
    end
  end
end

# Usage
article = Article.new(status: "draft", title: "Test", content: "...")
article.valid?  # => true (no category required for drafts)

article.status = "published"
article.valid?  # => false (now requires published_at, author_id, reviewer_id, category_id)
```

**Benefits:**

- Readable, self-documenting validation logic
- Centralized status definitions in one place (Statusable)
- Conditional validations reference status predicates directly
- Easy to test status-based validation scenarios

---

## Example 1: Multi-step Registration Form

Complete user registration with progressive validation across 4 steps.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include BetterModel

  has_secure_password

  validatable do
    # Step 1: Account creation
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    check :email, uniqueness: { case_sensitive: false }
    check :password, presence: true, length: { minimum: 8 }
    check :password_confirmation, presence: true

    # Step 2: Profile information
    check :first_name, :last_name, presence: true
    check :first_name, :last_name, length: { minimum: 2, maximum: 50 }
    check :date_of_birth, presence: true

    # Date of birth must be at least 18 years ago
    validate_business_rule :minimum_age_requirement

    # Step 3: Contact details
    check :phone, presence: true, format: { with: /\A\d{10}\z/ }
    check :address, :city, :zip_code, presence: true
    check :zip_code, format: { with: /\A\d{5}\z/ }

    # Step 4: Preferences
    check :notification_preferences, presence: true
    check :timezone, presence: true

    # Define validation groups
    validation_group :account, [:email, :password, :password_confirmation]
    validation_group :profile, [:first_name, :last_name, :date_of_birth]
    validation_group :contact, [:phone, :address, :city, :zip_code]
    validation_group :preferences, [:notification_preferences, :timezone]
  end

  def minimum_age_requirement
    return if date_of_birth.blank?

    if date_of_birth > 18.years.ago.to_date
      errors.add(:date_of_birth, "you must be at least 18 years old")
    end
  end
end

# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  def new_account
    @user = User.new
  end

  def create_account
    @user = User.new(account_params)

    if @user.valid?(:account)
      session[:registration] = @user.attributes.except("id")
      redirect_to new_profile_registration_path
    else
      @errors = @user.errors_for_group(:account)
      render :new_account
    end
  end

  def new_profile
    @user = User.new(session[:registration])
  end

  def create_profile
    @user = User.new(session[:registration].merge(profile_params))

    if @user.valid?(:profile)
      session[:registration] = @user.attributes.except("id")
      redirect_to new_contact_registration_path
    else
      @errors = @user.errors_for_group(:profile)
      render :new_profile
    end
  end

  def new_contact
    @user = User.new(session[:registration])
  end

  def create_contact
    @user = User.new(session[:registration].merge(contact_params))

    if @user.valid?(:contact)
      session[:registration] = @user.attributes.except("id")
      redirect_to new_preferences_registration_path
    else
      @errors = @user.errors_for_group(:contact)
      render :new_contact
    end
  end

  def new_preferences
    @user = User.new(session[:registration])
  end

  def create_preferences
    @user = User.new(session[:registration].merge(preferences_params))

    if @user.valid?(:preferences) && @user.save
      session.delete(:registration)
      redirect_to dashboard_path, notice: "Registration complete!"
    else
      @errors = @user.errors_for_group(:preferences)
      render :new_preferences
    end
  end

  private

  def account_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :date_of_birth)
  end

  def contact_params
    params.require(:user).permit(:phone, :address, :city, :zip_code)
  end

  def preferences_params
    params.require(:user).permit(:notification_preferences, :timezone)
  end
end

# Usage in views
# app/views/registrations/new_account.html.erb
<%= form_with model: @user, url: create_account_registration_path do |f| %>
  <%= f.label :email %>
  <%= f.email_field :email %>
  <%= @errors&.dig(:email)&.join(", ") %>

  <%= f.label :password %>
  <%= f.password_field :password %>
  <%= @errors&.dig(:password)&.join(", ") %>

  <%= f.label :password_confirmation %>
  <%= f.password_field :password_confirmation %>
  <%= @errors&.dig(:password_confirmation)&.join(", ") %>

  <%= f.submit "Next: Profile Info" %>
<% end %>
```

---

## Example 2: Event Management System

Event validation with date comparisons, capacity limits, and status-based rules.

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  include BetterModel

  belongs_to :organizer, class_name: 'User'
  belongs_to :venue, optional: true
  has_many :registrations, dependent: :destroy

  # Statusable integration
  is :upcoming, -> { starts_at > Time.current }
  is :ongoing, -> { starts_at <= Time.current && ends_at >= Time.current }
  is :past, -> { ends_at < Time.current }
  is :published, -> { published? }
  is :full, -> { registrations.count >= max_attendees }

  validatable do
    # Basic validations
    check :title, :description, presence: true
    check :title, length: { minimum: 5, maximum: 255 }
    check :description, length: { minimum: 20 }

    # Date validations
    check :starts_at, :ends_at, presence: true
    validate_order :starts_at, :before, :ends_at
    validate_order :starts_at, :after, :created_at

    # Capacity validations
    check :max_attendees, numericality: { greater_than: 0 }
    validate_order :registered_count, :lteq, :max_attendees

    # Published events require more fields
    validate_if :is_published? do
      check :venue_id, presence: true
      check :ticket_price, presence: true
      check :ticket_price, numericality: { greater_than_or_equal_to: 0 }
      check :category, presence: true
    end

    # Business rules
    validate_business_rule :valid_venue
    validate_business_rule :can_modify_event, on: :update
    validate_business_rule :registration_deadline_before_start
  end

  def valid_venue
    return if venue_id.blank?

    unless Venue.active.exists?(id: venue_id)
      errors.add(:venue_id, "must be an active venue")
    end

    # Check venue capacity
    if venue && max_attendees > venue.capacity
      errors.add(:max_attendees, "exceeds venue capacity of #{venue.capacity}")
    end
  end

  def can_modify_event
    return unless persisted?

    # Cannot modify past events
    if is_past?
      errors.add(:base, "cannot modify past events")
      return
    end

    # Cannot change start time if registrations exist
    if starts_at_changed? && registrations.any?
      errors.add(:starts_at, "cannot be changed after registrations exist")
    end

    # Cannot reduce capacity below current registration count
    if max_attendees_changed? && max_attendees < registrations.count
      errors.add(:max_attendees, "cannot be less than current registrations (#{registrations.count})")
    end
  end

  def registration_deadline_before_start
    return if registration_deadline.blank? || starts_at.blank?

    if registration_deadline >= starts_at
      errors.add(:registration_deadline, "must be before event start time")
    end
  end

  def registered_count
    registrations.count
  end
end

# Usage Examples

# 1. Create draft event
event = Event.new(
  title: "Ruby Conference 2025",
  description: "Annual Ruby developers conference with workshops and talks",
  starts_at: 3.months.from_now,
  ends_at: 3.months.from_now + 2.days,
  max_attendees: 500,
  organizer: current_user
)
event.valid?  # => true (venue not required for drafts)

# 2. Publish event (requires venue)
event.published = true
event.valid?  # => false
event.errors[:venue_id]  # => ["can't be blank"]
event.errors[:ticket_price]  # => ["can't be blank"]

event.venue = Venue.first
event.ticket_price = 299.00
event.category = "Technology"
event.valid?  # => true

# 3. Try to set invalid dates
event.ends_at = event.starts_at - 1.day
event.valid?  # => false
event.errors[:starts_at]  # => ["must be before ends at"]

# 4. Try to exceed venue capacity
event.venue = Venue.find_by(capacity: 200)
event.max_attendees = 500
event.valid?  # => false
event.errors[:max_attendees]  # => ["exceeds venue capacity of 200"]

# 5. Try to modify event with registrations
event.save!
50.times { event.registrations.create!(attendee: User.create!(...)) }

event.starts_at = 2.months.from_now
event.valid?  # => false
event.errors[:starts_at]  # => ["cannot be changed after registrations exist"]

event.max_attendees = 30
event.valid?  # => false
event.errors[:max_attendees]  # => ["cannot be less than current registrations (50)"]
```

---

## Example 3: E-commerce Product Validation

Product validation with price comparisons, stock management, and conditional requirements.

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  include BetterModel

  belongs_to :category
  has_many :variants, dependent: :destroy
  has_many :images, dependent: :destroy

  # Statusable integration
  is :active, -> { active? && stock > 0 }
  is :on_sale, -> { sale_price.present? && sale_price < price }
  is :low_stock, -> { stock > 0 && stock <= low_stock_threshold }
  is :out_of_stock, -> { stock <= 0 }
  is :requires_shipping, -> { physical? }

  validatable do
    # Basic validations
    check :name, :sku, presence: true
    check :sku, uniqueness: { case_sensitive: false }
    check :name, length: { minimum: 3, maximum: 255 }

    # Price validations
    check :price, presence: true
    check :price, numericality: { greater_than: 0 }

    # Sale price validations (only if on sale)
    validate_if :is_on_sale? do
      check :sale_price, presence: true
      validate_order :sale_price, :lt, :price
      check :sale_starts_at, :sale_ends_at, presence: true
      validate_order :sale_starts_at, :before, :sale_ends_at
    end

    # Stock validations
    check :stock, presence: true
    check :stock, numericality: { greater_than_or_equal_to: 0 }
    validate_order :reserved_stock, :lteq, :stock

    # Shipping validations (only if physical product)
    validate_if :is_requires_shipping? do
      check :weight, :dimensions, presence: true
      check :weight, numericality: { greater_than: 0 }
      check :shipping_cost, numericality: { greater_than_or_equal_to: 0 }
    end

    # Published products require more info
    validate_if -> { published? } do
      check :description, presence: true
      check :description, length: { minimum: 50 }
      validate_business_rule :has_at_least_one_image
    end

    # Business rules
    validate_business_rule :valid_category
    validate_business_rule :valid_variants
    validate_business_rule :valid_stock_levels
  end

  def valid_category
    return if category_id.blank?

    unless Category.active.exists?(id: category_id)
      errors.add(:category_id, "must be an active category")
    end

    # Check category allows this product type
    if category && category.product_type != self.product_type
      errors.add(:category_id, "does not accept #{product_type} products")
    end
  end

  def valid_variants
    return if variants.empty?

    # All variants must have valid SKUs
    if variants.any? { |v| v.sku.blank? }
      errors.add(:variants, "must all have SKUs")
    end

    # Variant prices cannot exceed base price
    if variants.any? { |v| v.price > price }
      errors.add(:variants, "prices cannot exceed base price of #{price}")
    end

    # Variants must have unique combinations
    combinations = variants.map { |v| [v.size, v.color].compact }
    if combinations.uniq.length != combinations.length
      errors.add(:variants, "must have unique size/color combinations")
    end
  end

  def valid_stock_levels
    # Low stock threshold must be reasonable
    if low_stock_threshold && low_stock_threshold > stock
      errors.add(:low_stock_threshold, "cannot be greater than current stock")
    end

    # Reserved stock must be tracked
    if reserved_stock > 0 && !track_inventory?
      errors.add(:reserved_stock, "cannot be set when inventory tracking is disabled")
    end
  end

  def has_at_least_one_image
    if images.none?
      errors.add(:images, "must include at least one product image")
    end
  end
end

# Usage Examples

# 1. Create basic product
product = Product.new(
  name: "Wireless Headphones",
  sku: "WH-1000XM4",
  price: 349.99,
  stock: 50,
  category: electronics_category
)
product.valid?  # => true

# 2. Create sale product
product.sale_price = 299.99
product.sale_starts_at = Date.today
product.sale_ends_at = 1.week.from_now
product.valid?  # => true (sale_price < price)

# Try invalid sale price
product.sale_price = 400.00
product.valid?  # => false
product.errors[:sale_price]  # => ["must be less than price"]

# 3. Physical product validations
product.physical = true
product.valid?  # => false
product.errors[:weight]  # => ["can't be blank"]
product.errors[:dimensions]  # => ["can't be blank"]

product.weight = 0.25  # kg
product.dimensions = "20x15x8"  # cm
product.shipping_cost = 9.99
product.valid?  # => true

# 4. Publishing validations
product.published = true
product.valid?  # => false
product.errors[:description]  # => ["can't be blank"]
product.errors[:images]  # => ["must include at least one product image"]

product.description = "Premium wireless headphones with active noise cancellation..." * 3
product.images.create!(url: "https://example.com/image1.jpg")
product.valid?  # => true

# 5. Stock management
product.stock = 5
product.reserved_stock = 10
product.valid?  # => false
product.errors[:reserved_stock]  # => ["must be less than or equal to stock"]

product.reserved_stock = 3
product.valid?  # => true
```

---

## Example 4: Invoice with Complex Business Rules

Invoice validation demonstrating business rules, cross-field validations, and validation groups.

```ruby
# app/models/invoice.rb
class Invoice < ApplicationRecord
  include BetterModel

  belongs_to :customer
  belongs_to :issued_by, class_name: 'User'
  has_many :line_items, dependent: :destroy

  # Statusable
  is :draft, -> { status == "draft" }
  is :sent, -> { status == "sent" }
  is :paid, -> { status == "paid" }
  is :overdue, -> { due_date.present? && due_date < Date.current && status == "sent" }
  is :tax_exempt, -> { customer.tax_exempt? }

  validatable do
    # Basic info
    check :invoice_number, presence: true, uniqueness: true
    check :invoice_date, presence: true
    check :customer_id, presence: true

    # Line items required
    validate_business_rule :has_line_items

    # Amount validations
    check :subtotal, :total, presence: true
    check :subtotal, :total, numericality: { greater_than: 0 }
    validate_order :subtotal, :lteq, :total

    # Tax validations (unless tax exempt)
    validate_unless :is_tax_exempt? do
      check :tax_rate, presence: true
      check :tax_amount, presence: true
      check :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
      validate_business_rule :correct_tax_calculation
    end

    # Sent invoices require more info
    validate_unless :is_draft? do
      check :due_date, presence: true
      validate_order :due_date, :after, :invoice_date
      check :payment_terms, presence: true
    end

    # Paid invoices
    validate_if :is_paid? do
      check :paid_date, presence: true
      check :payment_method, presence: true
      validate_order :paid_date, :gteq, :invoice_date
    end

    # Business rules
    validate_business_rule :valid_customer
    validate_business_rule :within_customer_credit_limit
    validate_business_rule :line_items_match_subtotal

    # Validation groups
    validation_group :basic_info, [:invoice_number, :invoice_date, :customer_id]
    validation_group :amounts, [:subtotal, :tax_rate, :tax_amount, :total]
    validation_group :payment, [:due_date, :payment_terms]
  end

  def has_line_items
    if line_items.empty?
      errors.add(:line_items, "invoice must have at least one line item")
    end
  end

  def correct_tax_calculation
    return if tax_rate.blank? || subtotal.blank?

    expected_tax = (subtotal * tax_rate).round(2)
    actual_tax = tax_amount || 0

    if (expected_tax - actual_tax).abs > 0.01  # Allow 1 cent rounding
      errors.add(:tax_amount, "should be #{expected_tax} (#{tax_rate * 100}% of #{subtotal})")
    end
  end

  def valid_customer
    return if customer_id.blank?

    unless Customer.active.exists?(id: customer_id)
      errors.add(:customer_id, "must be an active customer")
    end

    if customer && customer.blocked?
      errors.add(:customer_id, "is currently blocked from new invoices")
    end
  end

  def within_customer_credit_limit
    return if customer.blank? || total.blank?
    return if is_paid?  # Already paid invoices don't count

    outstanding = customer.invoices.where(status: %w[sent overdue]).sum(:total)
    new_total = outstanding + total

    if new_total > customer.credit_limit
      errors.add(:total, "would exceed customer credit limit (outstanding: #{outstanding}, limit: #{customer.credit_limit})")
    end
  end

  def line_items_match_subtotal
    return if line_items.empty?

    calculated_subtotal = line_items.sum { |item| item.quantity * item.unit_price }

    if (calculated_subtotal - subtotal.to_f).abs > 0.01
      errors.add(:subtotal, "should match sum of line items (#{calculated_subtotal})")
    end
  end
end

# Usage Examples

# 1. Create draft invoice (minimal validation)
invoice = Invoice.new(
  invoice_number: "INV-2025-001",
  invoice_date: Date.current,
  customer: customer,
  status: "draft"
)
invoice.line_items.build(description: "Consulting", quantity: 10, unit_price: 150.00)
invoice.subtotal = 1500.00
invoice.total = 1500.00
invoice.valid?  # => true (draft doesn't require due_date, payment_terms)

# 2. Validate specific groups
invoice.valid?(:basic_info)  # => true
invoice.valid?(:amounts)  # => true
invoice.valid?(:payment)  # => false (due_date missing)

# 3. Send invoice (requires more fields)
invoice.status = "sent"
invoice.valid?  # => false
invoice.errors[:due_date]  # => ["can't be blank"]
invoice.errors[:payment_terms]  # => ["can't be blank"]

invoice.due_date = 30.days.from_now
invoice.payment_terms = "Net 30"
invoice.valid?  # => true

# 4. Tax calculations
invoice.tax_rate = 0.08
invoice.tax_amount = 120.00
invoice.total = 1620.00
invoice.valid?  # => true

invoice.tax_amount = 100.00  # Wrong amount
invoice.valid?  # => false
invoice.errors[:tax_amount]  # => ["should be 120.0 (8.0% of 1500.0)"]

# 5. Mark as paid
invoice.status = "paid"
invoice.valid?  # => false
invoice.errors[:paid_date]  # => ["can't be blank"]
invoice.errors[:payment_method]  # => ["can't be blank"]

invoice.paid_date = Date.current
invoice.payment_method = "credit_card"
invoice.valid?  # => true

# 6. Credit limit check
high_value_invoice = Invoice.new(
  customer: small_customer,  # credit_limit: 5000
  total: 6000.00,
  # ... other fields
)
high_value_invoice.valid?  # => false
high_value_invoice.errors[:total]  # => ["would exceed customer credit limit..."]
```

## Example 5: Loan Application with Stepped Validation

Financial loan application with progressive validation, credit checks, and approval rules.

```ruby
class LoanApplication < ApplicationRecord
  include BetterModel

  belongs_to :applicant, class_name: 'User'
  belongs_to :co_applicant, class_name: 'User', optional: true

  # Statusable integration
  is :draft, -> { status == "draft" }
  is :submitted, -> { status == "submitted" }
  is :under_review, -> { status == "under_review" }
  is :approved, -> { status == "approved" }
  is :rejected, -> { status == "rejected" }
  is :requires_co_applicant, -> { loan_amount > 100_000 && employment_years < 3 }
  is :high_risk, -> { credit_score.present? && credit_score < 620 }

  validatable do
    # Step 1: Personal Information
    check :first_name, :last_name, :date_of_birth, :ssn, presence: true
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    check :phone, presence: true, format: { with: /\A\d{10}\z/ }

    # Age requirement
    validate_business_rule :minimum_age_requirement

    # Step 2: Employment & Income
    check :employer_name, :job_title, :employment_years, presence: true
    check :annual_income, presence: true, numericality: { greater_than: 0 }
    check :employment_years, numericality: { greater_than_or_equal_to: 0 }

    # Income validation
    validate_business_rule :sufficient_income_for_loan

    # Step 3: Loan Details
    check :loan_amount, :loan_purpose, :loan_term_months, presence: true
    check :loan_amount, numericality: { greater_than: 1000, less_than_or_equal_to: 500_000 }
    check :loan_term_months, numericality: { in: [12, 24, 36, 48, 60, 84, 120] }

    # Step 4: Credit Information
    check :credit_score, presence: true, numericality: { in: 300..850 }
    check :bankruptcy_history, inclusion: { in: [true, false] }

    # Conditional: Co-applicant required for large loans with short employment
    validate_if :is_requires_co_applicant? do
      check :co_applicant_id, presence: true
    end

    # Conditional: Additional documentation for high-risk applicants
    validate_if :is_high_risk? do
      check :additional_income_proof, presence: true
      check :employer_verification_letter, presence: true
    end

    # Conditional: Bankruptcy disclosures
    validate_if -> { bankruptcy_history == true } do
      check :bankruptcy_discharge_date, presence: true
      check :bankruptcy_type, presence: true
      validate_order :bankruptcy_discharge_date, :before, -> { Date.current }
    end

    # Submitted applications must have complete info
    validate_unless :is_draft? do
      check :property_address, :property_value, presence: true
      check :property_value, numericality: { greater_than: 0 }
      validate_order :loan_amount, :lteq, -> { property_value * 0.95 }
    end

    # Under review applications need credit check
    validate_if :is_under_review? do
      check :credit_check_completed_at, presence: true
      check :debt_to_income_ratio, presence: true
      validate_business_rule :acceptable_debt_to_income
    end

    # Business rules
    validate_business_rule :loan_to_value_ratio, unless: :is_draft?
    validate_business_rule :no_recent_bankruptcy
    validate_business_rule :employment_stability, on: :submit

    # Validation groups for multi-step form
    validation_group :personal_info, [:first_name, :last_name, :date_of_birth, :email, :phone, :ssn]
    validation_group :employment, [:employer_name, :job_title, :employment_years, :annual_income]
    validation_group :loan_details, [:loan_amount, :loan_purpose, :loan_term_months]
    validation_group :credit_info, [:credit_score, :bankruptcy_history]
    validation_group :property_info, [:property_address, :property_value]
  end

  # Business rule implementations
  def minimum_age_requirement
    return if date_of_birth.blank?

    age = ((Date.current - date_of_birth) / 365.25).floor
    if age < 18
      errors.add(:date_of_birth, "applicant must be at least 18 years old")
    end
  end

  def sufficient_income_for_loan
    return if loan_amount.blank? || annual_income.blank?

    monthly_income = annual_income / 12.0
    estimated_monthly_payment = calculate_monthly_payment

    if estimated_monthly_payment > monthly_income * 0.43
      errors.add(:annual_income, "insufficient for requested loan amount (max 43% DTI)")
    end
  end

  def acceptable_debt_to_income
    return if debt_to_income_ratio.blank?

    if debt_to_income_ratio > 0.50
      errors.add(:debt_to_income_ratio, "too high (maximum 50%)")
    end
  end

  def loan_to_value_ratio
    return if loan_amount.blank? || property_value.blank?

    ltv = (loan_amount.to_f / property_value * 100).round(2)

    if ltv > 95
      errors.add(:loan_amount, "exceeds 95% of property value (LTV: #{ltv}%)")
    end
  end

  def no_recent_bankruptcy
    return unless bankruptcy_history?
    return if bankruptcy_discharge_date.blank?

    years_since = ((Date.current - bankruptcy_discharge_date) / 365.25).floor

    min_years = bankruptcy_type == "Chapter 7" ? 4 : 2

    if years_since < min_years
      errors.add(:base, "bankruptcy must be discharged at least #{min_years} years ago")
    end
  end

  def employment_stability
    return if employment_years.blank?

    if employment_years < 2 && loan_amount > 200_000
      errors.add(:employment_years, "minimum 2 years required for loans over $200k")
    end
  end

  def calculate_monthly_payment
    return 0 if loan_amount.blank? || loan_term_months.blank?

    # Simple interest calculation (real-world would use amortization)
    interest_rate = 0.05  # 5% APR
    monthly_rate = interest_rate / 12
    ((loan_amount * monthly_rate) / (1 - (1 + monthly_rate)**-loan_term_months)).round(2)
  end
end

# Usage Examples

# 1. Step-by-step form validation
application = LoanApplication.new

# Step 1: Personal info
application.first_name = "John"
application.last_name = "Doe"
application.date_of_birth = 30.years.ago.to_date
application.email = "john@example.com"
application.phone = "5551234567"
application.ssn = "123-45-6789"

application.valid?(:personal_info)  # => true

# Step 2: Employment
application.employer_name = "Tech Corp"
application.job_title = "Software Engineer"
application.employment_years = 5
application.annual_income = 120_000

application.valid?(:employment)  # => true

# Step 3: Loan details
application.loan_amount = 250_000
application.loan_purpose = "home_purchase"
application.loan_term_months = 360  # 30 years

application.valid?(:loan_details)  # => true (not enough income)
application.errors[:annual_income]  # => ["insufficient for requested loan amount..."]

# Adjust loan amount
application.loan_amount = 150_000
application.valid?(:loan_details)  # => true

# Step 4: Credit info
application.credit_score = 720
application.bankruptcy_history = false

application.valid?(:credit_info)  # => true

# 2. Draft vs Submitted validation
application.status = "draft"
application.valid?  # => false (still missing property info)

# Property info not required for drafts
application.valid?  # Can save draft without property info

application.status = "submitted"
application.valid?  # => false (now property info required)

application.property_address = "123 Main St"
application.property_value = 200_000
application.valid?  # => true

# 3. Co-applicant requirement
large_loan = LoanApplication.new(
  loan_amount: 350_000,
  employment_years: 1,  # Less than 3 years
  # ... other required fields
)

large_loan.is_requires_co_applicant?  # => true
large_loan.valid?  # => false
large_loan.errors[:co_applicant_id]  # => ["can't be blank"]

large_loan.co_applicant = User.find(2)
large_loan.valid?  # => true

# 4. High-risk applicant requirements
high_risk = LoanApplication.new(
  credit_score: 580,  # Below 620 threshold
  # ... other required fields
)

high_risk.is_high_risk?  # => true
high_risk.valid?  # => false
high_risk.errors[:additional_income_proof]  # => ["can't be blank"]
high_risk.errors[:employer_verification_letter]  # => ["can't be blank"]

# 5. Bankruptcy disclosure
with_bankruptcy = LoanApplication.new(
  bankruptcy_history: true,
  # ... other required fields
)

with_bankruptcy.valid?  # => false
with_bankruptcy.errors[:bankruptcy_discharge_date]  # => ["can't be blank"]
with_bankruptcy.errors[:bankruptcy_type]  # => ["can't be blank"]

with_bankruptcy.bankruptcy_type = "Chapter 7"
with_bankruptcy.bankruptcy_discharge_date = 3.years.ago.to_date
with_bankruptcy.valid?  # => false
with_bankruptcy.errors[:base]  # => ["bankruptcy must be discharged at least 4 years ago"]

# 6. Loan-to-value validation
application = LoanApplication.new(
  loan_amount: 200_000,
  property_value: 200_000,
  status: "submitted",
  # ... other required fields
)

application.valid?  # => false
application.errors[:loan_amount]  # => ["exceeds 95% of property value (LTV: 100%)"]

application.loan_amount = 190_000  # 95% LTV
application.valid?  # => true

# 7. Review stage validation
application.status = "under_review"
application.valid?  # => false
application.errors[:credit_check_completed_at]  # => ["can't be blank"]
application.errors[:debt_to_income_ratio]  # => ["can't be blank"]

application.credit_check_completed_at = Time.current
application.debt_to_income_ratio = 0.38
application.valid?  # => true
```

## Example 6: Healthcare Patient Registration

Medical patient intake with insurance verification, medical history, and consent validations.

```ruby
class PatientRegistration < ApplicationRecord
  include BetterModel

  belongs_to :patient, class_name: 'User'
  has_many :emergency_contacts, dependent: :destroy
  has_many :insurance_policies, dependent: :destroy
  has_many :medical_conditions, dependent: :destroy
  has_many :allergies, dependent: :destroy

  # Statusable
  is :incomplete, -> { completed_at.blank? }
  is :complete, -> { completed_at.present? }
  is :verified, -> { insurance_verified_at.present? }
  is :minor, -> { patient_age < 18 }
  is :requires_guardian, -> { patient_age < 18 }

  validatable do
    # Basic patient information
    check :first_name, :last_name, :date_of_birth, :gender, presence: true
    check :phone, :email, presence: true
    check :phone, format: { with: /\A\d{10}\z/ }
    check :email, format: { with: URI::MailTo::EMAIL_REGEXP }

    # Address information
    check :street_address, :city, :state, :zip_code, presence: true
    check :zip_code, format: { with: /\A\d{5}(-\d{4})?\z/ }

    # Guardian required for minors
    validate_if :is_minor? do
      check :guardian_name, :guardian_relationship, :guardian_phone, presence: true
      check :guardian_consent_signature, presence: true
      check :guardian_consent_date, presence: true
      validate_order :guardian_consent_date, :before, -> { Date.current + 1.day }
    end

    # Insurance information (optional but validated if provided)
    validate_if -> { insurance_policies.any? } do
      validate_business_rule :valid_insurance_information
    end

    # Emergency contacts (at least one required)
    validate_business_rule :has_emergency_contacts

    # Medical history
    check :primary_care_physician, presence: true
    check :pharmacy_name, :pharmacy_phone, presence: true

    # Allergies and conditions
    validate_business_rule :documented_allergies
    validate_business_rule :documented_medical_conditions

    # Consent forms
    check :hipaa_consent, :treatment_consent, inclusion: { in: [true] }
    check :hipaa_consent_date, :treatment_consent_date, presence: true
    validate_order :hipaa_consent_date, :before, -> { Date.current + 1.day }
    validate_order :treatment_consent_date, :before, -> { Date.current + 1.day }

    # Privacy preferences
    check :privacy_level, inclusion: { in: %w[full partial minimal] }

    # Medication list
    validate_if -> { taking_medications? } do
      validate_business_rule :complete_medication_list
    end

    # Complete registration requirements
    validate_if :is_complete? do
      check :completed_by, presence: true
      check :completed_at, presence: true
    end

    # Business rules
    validate_business_rule :patient_age_valid
    validate_business_rule :valid_emergency_contact_relationships
    validate_business_rule :insurance_policy_dates, if: -> { insurance_policies.any? }

    # Validation groups
    validation_group :basic_info, [:first_name, :last_name, :date_of_birth, :gender, :phone, :email]
    validation_group :address, [:street_address, :city, :state, :zip_code]
    validation_group :insurance, [:insurance_policies]
    validation_group :emergency_contacts, [:emergency_contacts]
    validation_group :medical_history, [:primary_care_physician, :pharmacy_name, :pharmacy_phone]
    validation_group :consent_forms, [:hipaa_consent, :treatment_consent, :hipaa_consent_date, :treatment_consent_date]
  end

  # Helper methods
  def patient_age
    return nil if date_of_birth.blank?
    ((Date.current - date_of_birth) / 365.25).floor
  end

  # Business rule implementations
  def patient_age_valid
    return if date_of_birth.blank?

    age = patient_age

    if age < 0
      errors.add(:date_of_birth, "cannot be in the future")
    elsif age > 120
      errors.add(:date_of_birth, "appears to be invalid (age > 120)")
    end
  end

  def has_emergency_contacts
    if emergency_contacts.empty?
      errors.add(:emergency_contacts, "must have at least one emergency contact")
    end
  end

  def valid_emergency_contact_relationships
    emergency_contacts.each_with_index do |contact, index|
      if contact.relationship.blank?
        errors.add(:emergency_contacts, "contact #{index + 1} must have a relationship specified")
      end

      if contact.phone.blank?
        errors.add(:emergency_contacts, "contact #{index + 1} must have a phone number")
      end
    end
  end

  def valid_insurance_information
    insurance_policies.each_with_index do |policy, index|
      if policy.policy_number.blank?
        errors.add(:insurance_policies, "policy #{index + 1} must have a policy number")
      end

      if policy.group_number.blank? && policy.requires_group_number?
        errors.add(:insurance_policies, "policy #{index + 1} must have a group number")
      end

      if policy.expiration_date.present? && policy.expiration_date < Date.current
        errors.add(:insurance_policies, "policy #{index + 1} has expired")
      end
    end
  end

  def insurance_policy_dates
    insurance_policies.each_with_index do |policy, index|
      if policy.effective_date.present? && policy.expiration_date.present?
        if policy.effective_date > policy.expiration_date
          errors.add(:insurance_policies, "policy #{index + 1} effective date must be before expiration date")
        end
      end
    end
  end

  def documented_allergies
    if allergies_status == "has_allergies" && allergies.empty?
      errors.add(:allergies, "must be documented when patient reports having allergies")
    end

    if allergies_status == "no_allergies" && allergies.any?
      errors.add(:allergies, "should not be present when patient reports no allergies")
    end
  end

  def documented_medical_conditions
    if has_medical_conditions? && medical_conditions.empty?
      errors.add(:medical_conditions, "must be documented when patient reports having conditions")
    end
  end

  def complete_medication_list
    if current_medications.blank?
      errors.add(:current_medications, "must be documented when patient is taking medications")
    end

    medications_list.each_with_index do |med, index|
      if med[:name].blank?
        errors.add(:current_medications, "medication #{index + 1} must have a name")
      end

      if med[:dosage].blank?
        errors.add(:current_medications, "medication #{index + 1} must have a dosage")
      end
    end
  end
end

# Usage Examples

# 1. Step-by-step registration
registration = PatientRegistration.new(patient: current_user)

# Step 1: Basic info
registration.first_name = "Jane"
registration.last_name = "Smith"
registration.date_of_birth = 25.years.ago.to_date
registration.gender = "female"
registration.phone = "5559876543"
registration.email = "jane@example.com"

registration.valid?(:basic_info)  # => true

# Step 2: Address
registration.street_address = "456 Oak Street"
registration.city = "Springfield"
registration.state = "IL"
registration.zip_code = "62701"

registration.valid?(:address)  # => true

# Step 3: Emergency contacts
registration.emergency_contacts.build(
  name: "John Smith",
  relationship: "spouse",
  phone: "5551112222"
)

registration.valid?(:emergency_contacts)  # => true

# Step 4: Medical history
registration.primary_care_physician = "Dr. Johnson"
registration.pharmacy_name = "Main Street Pharmacy"
registration.pharmacy_phone = "5553334444"

registration.valid?(:medical_history)  # => true

# Step 5: Consent forms
registration.hipaa_consent = true
registration.hipaa_consent_date = Date.current
registration.treatment_consent = true
registration.treatment_consent_date = Date.current
registration.privacy_level = "full"

registration.valid?(:consent_forms)  # => true

# 2. Minor patient registration
minor = PatientRegistration.new(
  first_name: "Tommy",
  last_name: "Lee",
  date_of_birth: 10.years.ago.to_date,
  # ... other fields
)

minor.is_minor?  # => true
minor.is_requires_guardian?  # => true

minor.valid?  # => false
minor.errors[:guardian_name]  # => ["can't be blank"]
minor.errors[:guardian_consent_signature]  # => ["can't be blank"]

minor.guardian_name = "Sarah Lee"
minor.guardian_relationship = "mother"
minor.guardian_phone = "5557778888"
minor.guardian_consent_signature = "Sarah Lee"
minor.guardian_consent_date = Date.current

minor.valid?  # => true

# 3. Insurance validation
registration.insurance_policies.build(
  policy_number: "ABC123456",
  group_number: "GRP789",
  carrier_name: "Blue Cross",
  effective_date: Date.current,
  expiration_date: 1.year.from_now
)

registration.valid?(:insurance)  # => true

# Expired insurance
registration.insurance_policies.build(
  policy_number: "XYZ789",
  expiration_date: 1.month.ago
)

registration.valid?  # => false
registration.errors[:insurance_policies]  # => ["policy 2 has expired"]

# 4. Allergy documentation
registration.allergies_status = "has_allergies"
registration.valid?  # => false
registration.errors[:allergies]  # => ["must be documented when patient reports having allergies"]

registration.allergies.build(
  allergen: "Penicillin",
  reaction: "Hives",
  severity: "moderate"
)
registration.valid?  # => true

# 5. Medication list validation
registration.taking_medications = true
registration.valid?  # => false
registration.errors[:current_medications]  # => ["must be documented when patient is taking medications"]

registration.current_medications = [
  { name: "Lisinopril", dosage: "10mg", frequency: "once daily" },
  { name: "Metformin", dosage: "500mg", frequency: "twice daily" }
]
registration.valid?  # => true

# 6. Complete registration
registration.completed_by = current_staff_member.id
registration.completed_at = Time.current
registration.valid?  # => true

registration.save!
# => Patient registration complete and saved
```

---

## Best Practices

### 1. Enable Validatable Explicitly

Always use the `validatable do...end` block to activate the concern:

```ruby
# Good - Validatable active
validatable do
  check :title, presence: true
end

# Bad - Validatable not active
check :title, presence: true  # Standard Rails validation
```

### 2. Combine with Statusable for Status-based Logic

Use Statusable predicates in conditional validations:

```ruby
# Good - readable, maintainable
is :published, -> { status == "published" }

validatable do
  validate_if :is_published? do
    check :published_at, presence: true
  end
end

# Avoid - inline conditions harder to test and reuse
validatable do
  validate_if -> { status == "published" } do
    check :published_at, presence: true
  end
end
```

### 3. Use Validation Groups for Multi-step Forms

Define clear, semantic group names:

```ruby
# Good - descriptive names
validation_group :account_setup, [:email, :password]
validation_group :personal_info, [:first_name, :last_name]
validation_group :contact_details, [:phone, :address]

# Avoid - generic names
validation_group :step1, [:email, :password]
validation_group :step2, [:first_name, :last_name]
```

### 4. Keep Business Rules Focused

Each business rule should validate one concern:

```ruby
# Good - single responsibility
def valid_category
  return if category_id.blank?
  errors.add(:category_id, "invalid") unless Category.exists?(id: category_id)
end

def valid_price_range
  return if price.blank? || max_price.blank?
  errors.add(:price, "exceeds maximum") if price > max_price
end

# Avoid - multiple responsibilities
def valid_product
  errors.add(:category_id, "invalid") unless Category.exists?(id: category_id)
  errors.add(:price, "exceeds maximum") if price > max_price
  # ... many more validations
end
```

### 5. Use Cross-field Validations for Related Fields

Prefer `validate_order` over custom validations for comparisons:

```ruby
# Good - declarative
validate_order :starts_at, :before, :ends_at

# Avoid - custom validator for simple comparison
validate_business_rule :starts_before_ends

def starts_before_ends
  return if starts_at.blank? || ends_at.blank?
  errors.add(:starts_at, "must be before ends_at") if starts_at >= ends_at
end
```

### 6. Handle Nil Values Explicitly

Use presence validations before order validations:

```ruby
# Good - ensures fields exist first
check :starts_at, :ends_at, presence: true
validate_order :starts_at, :before, :ends_at

# Avoid - order validation silently skips nil values
validate_order :starts_at, :before, :ends_at
```

### 7. Organize Validations Logically

Group related validations together:

```ruby
validatable do
  # Basic required fields
  check :title, :content, presence: true

  # Format validations
  check :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  check :slug, format: { with: /\A[a-z0-9-]+\z/ }

  # Numeric validations
  check :view_count, numericality: { greater_than_or_equal_to: 0 }

  # Conditional validations
  validate_if :is_published? do
    check :published_at, presence: true
  end

  # Cross-field validations
  validate_order :starts_at, :before, :ends_at

  # Business rules
  validate_business_rule :valid_category
  validate_business_rule :valid_author
end
```

### 8. Test Validation Groups Independently

Write tests for each validation group:

```ruby
test "account group requires email and password" do
  user = User.new
  assert_not user.valid?(:account)
  assert user.errors_for_group(:account)[:email].any?
  assert user.errors_for_group(:account)[:password].any?
end

test "account group passes with valid email and password" do
  user = User.new(email: "test@example.com", password: "secret123")
  assert user.valid?(:account)
end
```

### 9. Document Complex Business Rules

Add comments explaining complex validation logic:

```ruby
validatable do
  # Users must be 18+ to register
  # Date of birth validated against current date minus 18 years
  validate_business_rule :minimum_age_requirement

  # Account status transitions: draft → active → suspended → deleted
  # Transitions can only move forward, never backward
  validate_business_rule :valid_status_transition, on: :update
end
```

### 10. Prefer Declarative Over Procedural

Use Validatable's DSL instead of custom validation methods when possible:

```ruby
# Good - declarative
validatable do
  check :title, presence: true, length: { minimum: 5 }
  validate_order :starts_at, :before, :ends_at
end

# Avoid - procedural custom methods for simple cases
validate_business_rule :title_present_and_long_enough
validate_business_rule :starts_before_ends

def title_present_and_long_enough
  errors.add(:title, "can't be blank") if title.blank?
  errors.add(:title, "too short") if title && title.length < 5
end

def starts_before_ends
  errors.add(:starts_at, "must be before ends_at") if starts_at >= ends_at
end
```
