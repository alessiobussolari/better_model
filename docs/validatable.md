# Validatable

Validatable provides a declarative validation system for Rails models with support for conditional validations, cross-field comparisons, business rules, and validation groups. It extends ActiveModel validations with a cleaner, more expressive syntax while maintaining full compatibility with Rails' built-in validation framework.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Basic Validations](#basic-validations)
- [Conditional Validations](#conditional-validations)
  - [validate_if](#validate_if)
  - [validate_unless](#validate_unless)
- [Cross-Field Validations](#cross-field-validations)
- [Business Rules](#business-rules)
- [Validation Groups](#validation-groups)
- [Instance Methods](#instance-methods)
- [Integration with Statusable](#integration-with-statusable)
- [Real-world Examples](#real-world-examples)
- [Best Practices](#best-practices)

## Overview

**Key Features:**

- **Opt-in Activation**: Validatable is not active by default. You must explicitly enable it with `validatable do...end`.
- **Declarative DSL**: Clean, readable syntax for all validation types.
- **Conditional Validations**: Apply validations only when certain conditions are met.
- **Cross-Field Validations**: Compare values between fields (dates, numbers).
- **Business Rules**: Delegate complex validation logic to custom methods.
- **Validation Groups**: Partial validation for multi-step forms and wizards.
- **Full Rails Compatibility**: Works seamlessly with ActiveModel validations.
- **Thread-safe**: Immutable configuration and registry.

## Configuration

Enable Validatable in your model using the `validatable do...end` block:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Your validations here
  end
end
```

**Without Configuration:**

If you don't call `validatable`, the concern is not active and won't interfere with your model.

**Empty Configuration:**

```ruby
validatable do
  # Empty block - activates Validatable but adds no validations
end
```

This activates Validatable (useful for validation groups) but doesn't add any validation rules.

## Basic Validations

Use the `validate` method inside the `validatable` block to define standard ActiveModel validations:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Single field with presence
    check :title, presence: true

    # Multiple fields with same validation
    check :title, :content, presence: true

    # Multiple validation types
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    check :view_count, numericality: { greater_than_or_equal_to: 0 }
    check :status, inclusion: { in: %w[draft published archived] }

    # Length validations
    check :title, length: { minimum: 3, maximum: 255 }
    check :slug, uniqueness: true
  end
end
```

**Key Points:**

- Supports all ActiveModel validation options: `presence`, `format`, `numericality`, `inclusion`, `exclusion`, `length`, `uniqueness`, etc.
- Multiple fields can share the same validation options.
- Validations are applied immediately when the model class is loaded.

## Conditional Validations

### validate_if

Apply validations only when a condition is true:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :scheduled, -> { status == "scheduled" }

  validatable do
    # Always required
    check :title, :status, presence: true

    # Required only when published
    validate_if :is_published? do
      check :published_at, presence: true
      check :author_id, presence: true
    end

    # Required only when scheduled
    validate_if :is_scheduled? do
      check :scheduled_for, presence: true
    end

    # Using lambda instead of method
    validate_if -> { status == "featured" } do
      check :featured_image_url, presence: true
    end
  end
end
```

**Usage:**

```ruby
# Draft article - doesn't require published_at
article = Article.new(status: "draft", title: "Test")
article.valid?  # => true

# Published article - requires published_at
article = Article.new(status: "published", title: "Test")
article.valid?  # => false
article.errors[:published_at]  # => ["can't be blank"]

article.published_at = Time.current
article.valid?  # => true
```

**Condition Types:**

- **Symbol**: References a method (usually a Statusable predicate): `validate_if :is_published?`
- **Proc/Lambda**: Inline condition evaluated in the instance context: `validate_if -> { status == "published" }`

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
    end
  end
end
```

**Usage:**

```ruby
# Draft article - doesn't require reviewer
article = Article.new(status: "draft")
article.valid?  # => true

# Published article - requires reviewer
article = Article.new(status: "published")
article.valid?  # => false
article.errors[:reviewer_id]  # => ["can't be blank"]
```

## Cross-Field Validations

Use `validate_order` to compare values between two fields:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Date/time comparisons
    validate_order :starts_at, :before, :ends_at
    validate_order :published_at, :after, :created_at

    # Numeric comparisons
    validate_order :min_price, :lteq, :max_price
    validate_order :view_count, :lteq, :max_views
    validate_order :discount, :lt, :price
  end
end
```

**Supported Comparators:**

| Comparator | Operator | Use Case | Example |
|------------|----------|----------|---------|
| `:before` | `<` | Dates/times | `starts_at` before `ends_at` |
| `:after` | `>` | Dates/times | `published_at` after `created_at` |
| `:lteq` | `<=` | Numbers | `min_price` ≤ `max_price` |
| `:gteq` | `>=` | Numbers | `stock` ≥ `reserved_stock` |
| `:lt` | `<` | Numbers | `discount` < `price` |
| `:gt` | `>` | Numbers | `total` > `subtotal` |

**Usage:**

```ruby
# Valid: starts_at before ends_at
event = Event.new(starts_at: 1.day.ago, ends_at: Time.current)
event.valid?  # => true

# Invalid: starts_at after ends_at
event = Event.new(starts_at: Time.current, ends_at: 1.day.ago)
event.valid?  # => false
event.errors[:starts_at]  # => ["must be before ends at"]
```

**With Options:**

```ruby
validatable do
  # Custom error message
  validate_order :starts_at, :before, :ends_at, message: "must be before event end"

  # Only on create
  validate_order :discount, :lteq, :price, on: :create

  # Conditional
  validate_order :min_age, :lteq, :max_age, if: :has_age_restriction?
end
```

**Nil Handling:**

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

  # Implement the business rule method
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
```

**Key Points:**

- Business rule methods must be defined in the model.
- Methods should add errors using `errors.add(field, message)`.
- Methods are called during validation like any other validator.
- If the method doesn't exist, a `NoMethodError` is raised with a helpful message.

**Usage:**

```ruby
article = Article.new(category_id: 999)
article.valid?  # => false
article.errors[:category_id]  # => ["must be a valid category"]
```

## Validation Groups

Validation groups enable partial validation for multi-step forms, wizards, or progressive data entry:

```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    # Step 1: Basic info
    check :email, :password, presence: true
    check :email, format: { with: URI::MailTo::EMAIL_REGEXP }

    # Step 2: Personal details
    check :first_name, :last_name, presence: true

    # Step 3: Address
    check :address, :city, :zip_code, presence: true

    # Define validation groups
    validation_group :step1, [:email, :password]
    validation_group :step2, [:first_name, :last_name]
    validation_group :step3, [:address, :city, :zip_code]
  end
end
```

**Usage:**

```ruby
user = User.new

# Validate only step1 fields
user.valid?(:step1)  # => false (email and password missing)

user.email = "user@example.com"
user.password = "secret"
user.valid?(:step1)  # => true

# Full validation still validates everything
user.valid?  # => false (first_name, last_name, etc. missing)
```

**Get Errors for Specific Group:**

```ruby
user = User.new
user.valid?  # Run full validation

# Get only errors for step1 fields
step1_errors = user.errors_for_group(:step1)
step1_errors[:email]  # => ["can't be blank"]
step1_errors[:first_name]  # => [] (not in step1 group)
```

**Real-world Multi-step Form Example:**

```ruby
class RegistrationForm
  def initialize(user)
    @user = user
  end

  def validate_step(step_number)
    group = "step#{step_number}".to_sym
    @user.valid?(group)
  end

  def errors_for_step(step_number)
    group = "step#{step_number}".to_sym
    @user.errors_for_group(group)
  end
end

# In controller
def create_step1
  @user = User.new(step1_params)
  form = RegistrationForm.new(@user)

  if form.validate_step(1)
    session[:user_data] = @user.attributes
    redirect_to registration_step2_path
  else
    @errors = form.errors_for_step(1)
    render :step1
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
article.valid?(:step1)

# Rails validation context
article.valid?(:create)
```

### validate_group(group_name)

Validate only fields in a specific group:

```ruby
user.validate_group(:step1)  # => true/false
```

**Raises:**
- `BetterModel::ValidatableNotEnabledError` if Validatable is not enabled.

### errors_for_group(group_name)

Get errors filtered to a specific group's fields:

```ruby
user.valid?  # Run full validation first
errors = user.errors_for_group(:step1)
errors[:email]  # => ["can't be blank"]
errors[:first_name]  # => [] (not in step1)
```

**Raises:**
- `BetterModel::ValidatableNotEnabledError` if Validatable is not enabled.

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

    # Only drafts can have no category
    validate_unless :is_draft? do
      check :category_id, presence: true
    end
  end
end
```

**Benefits:**

- Readable, self-documenting validation logic.
- Centralized status definitions in one place (Statusable).
- Conditional validations reference status predicates directly.

## Real-world Examples

### Multi-step Registration Form

```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    # Step 1: Account creation
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    check :password, presence: true, length: { minimum: 8 }
    check :password_confirmation, presence: true

    # Step 2: Profile
    check :first_name, :last_name, presence: true
    check :date_of_birth, presence: true
    validate_order :date_of_birth, :before, -> { 18.years.ago }

    # Step 3: Contact
    check :phone, :address, :city, :zip_code, presence: true
    check :phone, format: { with: /\A\d{10}\z/ }

    # Step 4: Preferences
    check :notification_preferences, presence: true

    # Define validation groups
    validation_group :account, [:email, :password, :password_confirmation]
    validation_group :profile, [:first_name, :last_name, :date_of_birth]
    validation_group :contact, [:phone, :address, :city, :zip_code]
    validation_group :preferences, [:notification_preferences]
  end
end
```

### Event Management System

```ruby
class Event < ApplicationRecord
  include BetterModel

  is :upcoming, -> { starts_at > Time.current }
  is :ongoing, -> { starts_at <= Time.current && ends_at >= Time.current }
  is :past, -> { ends_at < Time.current }
  is :published, -> { published? }

  validatable do
    # Basic validations
    check :title, :description, presence: true
    check :title, length: { minimum: 5, maximum: 255 }

    # Date validations
    check :starts_at, :ends_at, presence: true
    validate_order :starts_at, :before, :ends_at
    validate_order :starts_at, :after, :created_at

    # Capacity validations
    check :max_attendees, numericality: { greater_than: 0 }
    validate_order :registered_count, :lteq, :max_attendees

    # Published events require more fields
    validate_if :is_published? do
      check :venue, :address, :city, presence: true
      check :ticket_price, numericality: { greater_than_or_equal_to: 0 }
    end

    # Business rules
    validate_business_rule :valid_venue
    validate_business_rule :can_modify_event, on: :update
  end

  def valid_venue
    return if venue_id.blank?

    unless Venue.exists?(id: venue_id)
      errors.add(:venue_id, "must be a valid venue")
    end
  end

  def can_modify_event
    return unless persisted?

    if is_past?
      errors.add(:base, "cannot modify past events")
    elsif registered_count > 0 && starts_at_changed?
      errors.add(:starts_at, "cannot be changed after registrations exist")
    end
  end
end
```

### E-commerce Product

```ruby
class Product < ApplicationRecord
  include BetterModel

  is :active, -> { active? && stock > 0 }
  is :on_sale, -> { sale_price.present? && sale_price < price }
  is :low_stock, -> { stock > 0 && stock <= low_stock_threshold }

  validatable do
    # Basic validations
    check :name, :sku, presence: true
    check :sku, uniqueness: true

    # Price validations
    check :price, numericality: { greater_than: 0 }
    validate_if :is_on_sale? do
      check :sale_price, presence: true
      validate_order :sale_price, :lt, :price
    end

    # Stock validations
    check :stock, numericality: { greater_than_or_equal_to: 0 }
    validate_order :reserved_stock, :lteq, :stock

    # Shipping validations
    check :weight, :dimensions, presence: true
    check :weight, numericality: { greater_than: 0 }

    # Business rules
    validate_business_rule :valid_category
    validate_business_rule :valid_variants
  end

  def valid_category
    return if category_id.blank?

    unless Category.active.exists?(id: category_id)
      errors.add(:category_id, "must be an active category")
    end
  end

  def valid_variants
    return if variants.empty?

    if variants.any? { |v| v.price > price }
      errors.add(:base, "variant prices cannot exceed base price")
    end
  end
end
```

## Best Practices

### 1. Enable Validatable Explicitly

Always use the `validatable do...end` block to activate the concern:

```ruby
# Good
validatable do
  check :title, presence: true
end

# Bad - Validatable not active
check :title, presence: true  # Standard Rails validation, not Validatable
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
# Good
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
# Good
validate_order :starts_at, :before, :ends_at

# Avoid - custom validator for simple comparison
check :starts_before_ends

def starts_before_ends
  return if starts_at.blank? || ends_at.blank?
  errors.add(:starts_at, "must be before ends_at") if starts_at >= ends_at
end
```

### 6. Handle Nil Values Explicitly

Use presence validations before order validations:

```ruby
# Good
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
test "step1 validation requires email and password" do
  user = User.new
  assert_not user.valid?(:step1)
  assert user.errors_for_group(:step1)[:email].any?
  assert user.errors_for_group(:step1)[:password].any?
end

test "step1 validation passes with email and password" do
  user = User.new(email: "test@example.com", password: "secret123")
  assert user.valid?(:step1)
end
```

### 9. Document Complex Business Rules

Add comments explaining complex validation logic:

```ruby
validatable do
  # Users must be 18+ to register
  # Date of birth is validated against current date minus 18 years
  validate_business_rule :minimum_age_requirement

  # Account status transitions follow: draft → active → suspended → deleted
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
check :title_present_and_long_enough
check :starts_before_ends

def title_present_and_long_enough
  errors.add(:title, "can't be blank") if title.blank?
  errors.add(:title, "too short") if title && title.length < 5
end

def starts_before_ends
  errors.add(:starts_at, "must be before ends_at") if starts_at >= ends_at
end
```

---

**[← Back to Main Documentation](../README.md)**
