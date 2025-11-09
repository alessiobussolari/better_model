# Validatable - Declarative Validation System

## Overview

Validatable provides a simplified declarative validation system for Rails models with three core features:

- **Opt-in Activation**: Not active by default - must enable with `validatable do...end`
- **Declarative DSL**: Clean, readable syntax with `check` method
- **Complex Validations**: Reusable validation blocks for any complex logic including cross-field comparisons
- **Validation Groups**: Partial validation for multi-step forms and wizards
- **Full Rails Compatibility**: Works seamlessly with ActiveModel validations and contexts
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

## Core Features

Validatable offers exactly **3 core features**:

1. **Basic Validations** (`check`) - Standard Rails validations with declarative syntax
2. **Complex Validations** (`register_complex_validation` + `check_complex`) - Reusable validation blocks
3. **Validation Groups** (`validation_group`) - Partial validation for multi-step forms

---

## 1. Basic Validations

### API Reference: check

**Method Signature:**
```ruby
check(*fields, **options)
```

**Parameters:**
- `fields` (Array<Symbol>): One or more field names
- `options` (Hash): Standard Rails validation options (presence, format, length, etc.)

**Behavior:**
- Delegates directly to Rails' `validates` method
- Supports all ActiveModel validation options
- Supports Rails conditional options (`if`, `unless`, `on`)

### Usage Examples

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Single field
    check :title, presence: true

    # Multiple fields with same validation
    check :title, :content, presence: true

    # Multiple validation types
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

    # Length validations
    check :title, length: { minimum: 5, maximum: 200 }

    # Numericality
    check :view_count, numericality: { greater_than_or_equal_to: 0 }

    # Inclusion
    check :status, inclusion: { in: %w[draft published archived] }

    # Conditional using Rails options
    check :published_at, presence: true, if: :published?
    check :author_id, presence: true, if: -> { status == "published" }

    # Context-specific
    check :reviewer_id, presence: true, on: :publish
  end
end
```

### Supported Rails Options

All standard ActiveModel validation options are supported:
- `presence`, `absence`
- `format` (with regex)
- `length` (minimum, maximum, in, is)
- `numericality` (greater_than, less_than, equal_to, etc.)
- `inclusion`, `exclusion`
- `uniqueness`
- `acceptance`
- `confirmation`

Plus Rails conditional/context options:
- `if`, `unless` (method name or lambda)
- `on` (:create, :update, or custom context)
- `message` (custom error message)
- `allow_nil`, `allow_blank`

---

## 2. Complex Validations

Complex validations allow you to register reusable validation logic that can:
- Combine multiple fields
- Implement cross-field comparisons (date/number ranges)
- Execute custom business logic
- Add multiple errors to different fields

They follow the same pattern as `complex_predicates` and `complex_sorts`.

### API Reference: register_complex_validation

**Method Signature:**
```ruby
register_complex_validation(name, &block)
```

**Parameters:**
- `name` (Symbol): The name of the validation (required)
- `block` (Proc): Validation logic that runs in the instance context (required)

**Returns:** Registers the validation in `complex_validations_registry` (frozen Hash)

**Thread Safety:** Registry is frozen, validations defined at class load time

**Behavior:**
- Block executes in the instance context (access to all attributes and methods)
- Can add multiple errors to different fields
- Can access associations and other model methods
- Registry is inherited by subclasses
- Must use `check_complex` in `validatable` block to activate

### API Reference: check_complex

**Method Signature:**
```ruby
check_complex(name)
```

**Parameters:**
- `name` (Symbol): Name of registered complex validation

**Behavior:**
- Validates that the complex validation exists (raises ArgumentError if not)
- Adds the validation to the model's validation chain
- Runs during normal validation (`valid?` call)

### Helper Method: complex_validation?

```ruby
Model.complex_validation?(:name)  # => true/false
```

Checks if a complex validation is registered.

### Basic Usage

```ruby
class Product < ApplicationRecord
  include BetterModel

  # Register complex validation
  register_complex_validation :valid_pricing do
    return if sale_price.blank?  # Nil handling

    if sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end
  end

  validatable do
    check :name, :price, presence: true
    check_complex :valid_pricing
  end
end

# Usage
product = Product.new(price: 100, sale_price: 120)
product.valid?  # => false
product.errors[:sale_price]  # => ["must be less than regular price"]
```

### Cross-Field Validations

Complex validations are perfect for comparing fields:

```ruby
class Event < ApplicationRecord
  include BetterModel

  # Date comparison
  register_complex_validation :valid_date_range do
    return if starts_at.blank? || ends_at.blank?

    if starts_at >= ends_at
      errors.add(:starts_at, "must be before end date")
    end
  end

  # Numeric comparison
  register_complex_validation :capacity_check do
    return if registered_count.blank? || max_attendees.blank?

    if registered_count > max_attendees
      errors.add(:registered_count, "exceeds capacity (#{max_attendees})")
    end
  end

  # Price range
  register_complex_validation :valid_price_range do
    return if min_price.blank? || max_price.blank?

    if min_price > max_price
      errors.add(:min_price, "must be less than or equal to max price")
    end
  end

  validatable do
    check_complex :valid_date_range
    check_complex :capacity_check
    check_complex :valid_price_range
  end
end
```

### Multiple Errors

Complex validations can add multiple errors:

```ruby
register_complex_validation :order_totals do
  # Calculate totals
  items_total = order_items.sum(&:total)
  calculated_total = items_total + shipping_cost - discount_amount

  # Multiple validation checks
  if total.present? && (calculated_total - total).abs > 0.01
    errors.add(:total, "does not match calculated total (#{calculated_total})")
  end

  if discount_amount.present? && discount_amount > items_total
    errors.add(:discount_amount, "cannot exceed items total")
  end

  if items_total < 10.00
    errors.add(:base, "Order must be at least $10.00")
  end
end
```

### Integration with Statusable

Complex validations can use Statusable predicates:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }

  register_complex_validation :publication_requirements do
    return unless is_published?

    errors.add(:published_at, "required for published articles") if published_at.blank?
    errors.add(:author_id, "required for published articles") if author_id.blank?
    errors.add(:content, "must be at least 100 chars") if content && content.length < 100
  end

  validatable do
    check :title, presence: true
    check_complex :publication_requirements
  end
end
```

### Advanced Patterns

**Pattern 1: Conditional Logic Within Validation**
```ruby
register_complex_validation :pricing_rules do
  # Different rules based on product type
  case product_type
  when "physical"
    errors.add(:weight, "required for physical products") if weight.blank?
    errors.add(:shipping_cost, "required") if shipping_cost.blank?
  when "digital"
    errors.add(:download_url, "required for digital products") if download_url.blank?
  when "service"
    errors.add(:duration, "required for services") if duration.blank?
  end
end
```

**Pattern 2: Association Validation**
```ruby
register_complex_validation :valid_order_items do
  if order_items.empty?
    errors.add(:base, "Order must have at least one item")
  end

  order_items.each_with_index do |item, index|
    if item.quantity <= 0
      errors.add(:base, "Item #{index + 1} must have positive quantity")
    end
  end
end
```

**Pattern 3: Calculated Field Validation**
```ruby
register_complex_validation :profit_margin do
  return if cost.blank? || price.blank?

  margin = ((price - cost) / price.to_f) * 100

  if margin < 10
    errors.add(:price, "profit margin (#{margin.round(1)}%) must be at least 10%")
  elsif margin > 80
    errors.add(:price, "profit margin (#{margin.round(1)}%) seems too high")
  end
end
```

### Class Methods

```ruby
# Check if validation is registered
Product.complex_validation?(:valid_pricing)  # => true

# Get all registered validations
Product.complex_validations_registry
# => {:valid_pricing => #<Proc>, :valid_stock => #<Proc>}
```

### Best Practices

1. **Always handle nil values** - Use early returns
   ```ruby
   register_complex_validation :date_range do
     return if starts_at.blank? || ends_at.blank?
     # validation logic
   end
   ```

2. **Keep validations focused** - One validation per concern
   ```ruby
   # Good - separate concerns
   register_complex_validation :valid_dates do ... end
   register_complex_validation :capacity_check do ... end

   # Avoid - mixing concerns
   register_complex_validation :validate_everything do ... end
   ```

3. **Use descriptive names**
   ```ruby
   # Good
   register_complex_validation :publication_requirements
   register_complex_validation :profit_margin_check

   # Avoid
   register_complex_validation :check1
   register_complex_validation :validation
   ```

4. **Provide clear error messages**
   ```ruby
   errors.add(:field, "specific reason why it failed")
   # Not just: errors.add(:field, "invalid")
   ```

---

## 3. Validation Groups

Validation groups enable partial validation of specific fields, perfect for:
- Multi-step forms
- Wizard-style flows
- Progressive data entry
- Step-by-step validation

### API Reference: validation_group

**Method Signature:**
```ruby
validation_group(group_name, fields)
```

**Parameters:**
- `group_name` (Symbol): Unique name for the group (required)
- `fields` (Array<Symbol>): Array of field names to validate in this group (required)

**Raises:**
- `ArgumentError` if group_name is not a Symbol
- `ArgumentError` if fields is not an Array
- `ArgumentError` if group is already defined

**Behavior:**
- Groups are stored in `validatable_groups` (frozen Hash)
- Groups define which fields to validate, not which validations to run
- All validations defined in `validatable` block apply, but only errors for grouped fields are checked

### Basic Usage

```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    # Define validations for all fields
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    check :password, presence: true, length: { minimum: 8 }
    check :first_name, :last_name, presence: true
    check :address, :city, :zip_code, presence: true

    # Define validation groups
    validation_group :step1, [:email, :password]
    validation_group :step2, [:first_name, :last_name]
    validation_group :step3, [:address, :city, :zip_code]
  end
end

# Validate specific group
user = User.new(email: "user@example.com")
user.valid?(:step1)  # => false (missing password)

user.password = "secure123"
user.valid?(:step1)  # => true

# Full validation validates all fields
user.valid?  # => false (missing step2 and step3 fields)
```

### Instance Methods

**valid?(context_or_group)**

Override of ActiveModel's `valid?` with group support:

```ruby
user.valid?            # Full validation (all fields)
user.valid?(:step1)    # Only validates fields in :step1 group
user.valid?(:create)   # Rails context validation
```

**validate_group(group_name)**

Explicitly validate only a specific group:

```ruby
user.validate_group(:step1)  # => true/false
```

Raises `BetterModel::ValidatableNotEnabledError` if Validatable not enabled.

**errors_for_group(group_name)**

Get errors filtered to a specific group:

```ruby
user.valid?  # Run full validation first
errors = user.errors_for_group(:step1)
errors[:email]      # => errors for email (in step1)
errors[:first_name] # => [] (not in step1)
```

Raises `BetterModel::ValidatableNotEnabledError` if Validatable not enabled.

### Multi-step Form Example

```ruby
class RegistrationController < ApplicationController
  def create_step1
    @user = User.new(step1_params)

    if @user.valid?(:step1)
      session[:user_data] = @user.attributes
      redirect_to registration_step2_path
    else
      @errors = @user.errors_for_group(:step1)
      render :step1
    end
  end

  def create_step2
    @user = User.new(session[:user_data].merge(step2_params))

    if @user.valid?(:step2)
      session[:user_data] = @user.attributes
      redirect_to registration_step3_path
    else
      @errors = @user.errors_for_group(:step2)
      render :step2
    end
  end

  def create_step3
    @user = User.new(session[:user_data].merge(step3_params))

    if @user.valid?  # Full validation on final step
      @user.save!
      session.delete(:user_data)
      redirect_to dashboard_path
    else
      @errors = @user.errors_for_group(:step3)
      render :step3
    end
  end
end
```

### Semantic Group Names

Use descriptive names that reflect the purpose:

```ruby
# Good - semantic names
validation_group :account_setup, [:email, :password]
validation_group :personal_info, [:first_name, :last_name, :date_of_birth]
validation_group :contact_details, [:phone, :address, :city]

# Avoid - generic names
validation_group :step1, [:email, :password]
validation_group :step2, [:first_name, :last_name]
```

### Groups with Different Contexts

You can combine groups with Rails validation contexts:

```ruby
validatable do
  # Basic fields
  check :email, presence: true
  check :password, presence: true

  # Create-only validation
  check :terms_accepted, acceptance: true, on: :create

  # Publish-specific validation
  check :reviewed_by_id, presence: true, on: :publish

  # Groups for multi-step
  validation_group :basics, [:email, :password]
  validation_group :publishing, [:reviewed_by_id]
end

# Use contexts
user.valid?(:create)   # Validates with :create context
user.valid?(:publish)  # Validates with :publish context

# Use groups
user.valid?(:basics)     # Validates :basics group
user.valid?(:publishing) # Validates :publishing group
```

---

## Integration with Rails

### Using Rails Conditional Options

For conditional validations, use Rails' built-in `if` and `unless` options:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }

  validatable do
    # Always required
    check :title, :content, presence: true

    # Conditional using Statusable predicate
    check :published_at, presence: true, if: :is_published?
    check :author_id, presence: true, if: :is_published?

    # Conditional using lambda
    check :featured_image_url, presence: true, if: -> { featured? }

    # Unless condition
    check :category_id, presence: true, unless: :is_draft?
  end
end
```

### Using Rails Validation Contexts

Validatable works seamlessly with Rails validation contexts:

```ruby
validatable do
  # Always validated
  check :title, presence: true

  # Only on create
  check :author_id, presence: true, on: :create

  # Only on update
  check :updated_reason, presence: true, on: :update

  # Custom context
  check :published_at, presence: true, on: :publish
  check :reviewer_id, presence: true, on: :publish
end

# Use with contexts
article.valid?(:create)   # Validates with :create context
article.valid?(:update)   # Validates with :update context
article.valid?(:publish)  # Validates with :publish context
```

### Combining Groups and Contexts

You can use both validation groups and Rails contexts:

```ruby
validatable do
  check :title, presence: true
  check :author_id, presence: true, on: :create
  check :published_at, presence: true, if: :published?

  validation_group :basic_info, [:title]
  validation_group :publishing_info, [:published_at, :author_id]
end

# Groups ignore contexts
article.valid?(:basic_info)      # Only validates :title

# Contexts ignore groups
article.valid?(:create)          # Validates :title and :author_id
```

---

## Complete Examples

### Example 1: E-commerce Product

```ruby
class Product < ApplicationRecord
  include BetterModel

  is :on_sale, -> { sale_price.present? && sale_price < price }
  is :low_stock, -> { stock > 0 && stock <= low_stock_threshold }

  # Complex validations for business rules
  register_complex_validation :pricing_rules do
    return if price.blank?

    # Sale price must be less than regular price
    if sale_price.present? && sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end

    # Ensure minimum profit margin
    if sale_price.present? && cost.present?
      margin = ((sale_price - cost) / sale_price.to_f) * 100
      if margin < 10
        errors.add(:sale_price, "profit margin must be at least 10%")
      end
    end
  end

  register_complex_validation :stock_validation do
    # Reserved stock cannot exceed total
    if reserved_stock.present? && stock.present? && reserved_stock > stock
      errors.add(:reserved_stock, "cannot exceed total stock")
    end

    # Low stock warning
    if stock.present? && stock < reorder_level
      errors.add(:stock, "is below reorder level (#{reorder_level})")
    end
  end

  validatable do
    # Basic validations
    check :name, :sku, presence: true
    check :sku, uniqueness: true
    check :price, numericality: { greater_than: 0 }
    check :stock, numericality: { greater_than_or_equal_to: 0 }

    # Complex validations
    check_complex :pricing_rules
    check_complex :stock_validation

    # Conditional validations
    check :sale_price, presence: true, if: :is_on_sale?
  end
end
```

### Example 2: Multi-step Registration

```ruby
class User < ApplicationRecord
  include BetterModel

  register_complex_validation :password_strength do
    return if password.blank?

    errors.add(:password, "must include at least one number") unless password.match?(/\d/)
    errors.add(:password, "must include at least one uppercase letter") unless password.match?(/[A-Z]/)
    errors.add(:password, "must include at least one special character") unless password.match?(/[!@#$%^&*]/)
  end

  validatable do
    # Step 1: Account
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
    check :password, presence: true, length: { minimum: 8 }
    check :password_confirmation, presence: true
    check_complex :password_strength

    # Step 2: Profile
    check :first_name, :last_name, presence: true
    check :date_of_birth, presence: true

    # Step 3: Contact
    check :phone, presence: true, format: { with: /\A\d{10}\z/ }
    check :address, :city, :zip_code, presence: true

    # Groups
    validation_group :account, [:email, :password, :password_confirmation]
    validation_group :profile, [:first_name, :last_name, :date_of_birth]
    validation_group :contact, [:phone, :address, :city, :zip_code]
  end
end
```

### Example 3: Event Management

```ruby
class Event < ApplicationRecord
  include BetterModel

  is :upcoming, -> { starts_at > Time.current }
  is :ongoing, -> { starts_at <= Time.current && ends_at >= Time.current }
  is :past, -> { ends_at < Time.current }

  register_complex_validation :date_consistency do
    return if starts_at.blank? || ends_at.blank?

    if starts_at >= ends_at
      errors.add(:starts_at, "must be before end date")
    end

    if starts_at < Time.current
      errors.add(:starts_at, "cannot be in the past")
    end

    duration = ends_at - starts_at
    if duration > 30.days
      errors.add(:ends_at, "event cannot last more than 30 days")
    end
  end

  register_complex_validation :capacity_limits do
    return if max_attendees.blank?

    if registered_count > max_attendees
      errors.add(:registered_count, "exceeds capacity (#{max_attendees})")
    end

    if max_attendees > venue.capacity
      errors.add(:max_attendees, "exceeds venue capacity (#{venue.capacity})")
    end
  end

  validatable do
    check :title, :description, presence: true
    check :title, length: { minimum: 5, maximum: 255 }
    check :starts_at, :ends_at, presence: true
    check :max_attendees, numericality: { greater_than: 0 }

    check_complex :date_consistency
    check_complex :capacity_limits

    # Published events need venue
    check :venue_id, :address, :city, presence: true, if: :published?
  end
end
```

---

## Best Practices

### 1. Enable Validatable Explicitly

Always use the `validatable do...end` block:

```ruby
# Good
validatable do
  check :title, presence: true
end

# Bad - Validatable not active
validates :title, presence: true
```

### 2. Use Complex Validations for Cross-field Logic

```ruby
# Good - reusable and clear
register_complex_validation :valid_date_range do
  return if starts_at.blank? || ends_at.blank?
  errors.add(:starts_at, "must be before end date") if starts_at >= ends_at
end

validatable do
  check_complex :valid_date_range
end
```

### 3. Always Handle Nil in Complex Validations

```ruby
# Good - explicit nil handling
register_complex_validation :valid_dates do
  return if starts_at.blank? || ends_at.blank?
  # validation logic
end

# Avoid - will crash on nil
register_complex_validation :valid_dates do
  errors.add(:starts_at, "invalid") if starts_at >= ends_at
end
```

### 4. Use Semantic Validation Group Names

```ruby
# Good
validation_group :account_setup, [:email, :password]
validation_group :personal_info, [:first_name, :last_name]

# Avoid
validation_group :step1, [:email, :password]
validation_group :step2, [:first_name, :last_name]
```

### 5. Keep Complex Validations Focused

```ruby
# Good - single responsibility
register_complex_validation :valid_dates do ... end
register_complex_validation :capacity_check do ... end

# Avoid - multiple responsibilities
register_complex_validation :validate_everything do
  # 50 lines of various checks
end
```

### 6. Use Rails Options for Simple Conditionals

```ruby
# Good - simple conditional
check :published_at, presence: true, if: :published?

# Avoid - overly complex for simple case
register_complex_validation :published_at_check do
  return unless published?
  errors.add(:published_at, "can't be blank") if published_at.blank?
end
```

### 7. Combine with Standard Rails Validations

```ruby
# You can mix standard Rails validations with Validatable
validates :user, presence: true
validates :title, uniqueness: { scope: :user_id }

validatable do
  check :content, presence: true, if: :published?
  check_complex :content_quality
end
```

### 8. Test Validations Thoroughly

```ruby
RSpec.describe Product, type: :model do
  describe "validations" do
    it "requires name and price" do
      product = Product.new
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
      expect(product.errors[:price]).to include("can't be blank")
    end

    describe "pricing rules" do
      it "requires sale_price < price" do
        product = Product.new(price: 100, sale_price: 120)
        expect(product).not_to be_valid
        expect(product.errors[:sale_price]).to include("must be less than regular price")
      end
    end
  end
end
```

---

## Error Handling

### ValidatableNotEnabledError

Raised when calling validation group methods without enabling Validatable:

```ruby
user.errors_for_group(:step1)
# => BetterModel::ValidatableNotEnabledError: Validatable is not enabled. Add 'validatable do...end' to your model.
```

### ArgumentError for Unknown Complex Validation

```ruby
validatable do
  check_complex :nonexistent
end
# => ArgumentError: Unknown complex validation: nonexistent. Use register_complex_validation to define it first.
```

---

## Summary

Validatable provides **3 core features**:

1. **`check`** - Basic validations with declarative syntax
2. **`register_complex_validation` + `check_complex`** - Reusable validation blocks for complex logic
3. **`validation_group`** - Partial validation for multi-step forms

All features work seamlessly with:
- Rails conditional options (`if`, `unless`)
- Rails validation contexts (`on: :create`, `on: :update`, custom contexts)
- Statusable predicates
- Standard Rails validations

**Thread-safe**, **opt-in**, and **fully compatible** with ActiveModel validations.
