# Validatable - Declarative Validation System

Simplified declarative validation for Rails models with three core features: basic validations (`check`), complex validations for cross-field logic, and validation groups for multi-step forms.

**Requirements**: Rails 8.0+, Ruby 3.0+, ActiveRecord model
**Installation**: No migration required - include BetterModel and activate with `validatable do...end`

**⚠️ Version 3.0.0 Compatible**: All error handling in this document uses standard Ruby exception patterns.

---

## Basic Validations

### Single Field Validation

**Cosa fa**: Validates presence of a single field using declarative syntax

**Quando usarlo**: For simple field validations instead of Rails' validates method

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, presence: true
  end
end

article = Article.new
article.valid?  # => false
article.errors[:title]  # => ["can't be blank"]
```

---

### Multiple Fields Same Validation

**Cosa fa**: Applies the same validation rule to multiple fields at once

**Quando usarlo**: When several fields need identical validation rules

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, :content, :author, presence: true
  end
end

article = Article.new
article.valid?  # => false
article.errors.keys  # => [:title, :content, :author]
```

---

### Multiple Validation Types

**Cosa fa**: Applies multiple validation rules to a single field

**Quando usarlo**: When a field needs several validation checks

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    check :email,
          presence: true,
          format: { with: URI::MailTo::EMAIL_REGEXP },
          uniqueness: true
  end
end

user = User.new(email: "invalid")
user.valid?  # => false
user.errors[:email]  # => ["is invalid"]
```

---

### Length Validations

**Cosa fa**: Validates string length with minimum, maximum, or exact requirements

**Quando usarlo**: To enforce character limits on text fields

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, length: { minimum: 5, maximum: 200 }
    check :slug, length: { in: 3..50 }
    check :code, length: { is: 8 }
  end
end

article = Article.new(title: "Hi")
article.valid?  # => false
article.errors[:title]  # => ["is too short (minimum is 5 characters)"]
```

---

### Numericality Validations

**Cosa fa**: Validates numeric values with comparison operators

**Quando usarlo**: For prices, counts, ratings, and numeric constraints

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  validatable do
    check :price, numericality: { greater_than: 0 }
    check :stock, numericality: { greater_than_or_equal_to: 0 }
    check :rating, numericality: { in: 1..5 }
  end
end

product = Product.new(price: -10)
product.valid?  # => false
product.errors[:price]  # => ["must be greater than 0"]
```

---

### Inclusion and Exclusion

**Cosa fa**: Validates that value is within (or outside) a specific set

**Quando usarlo**: For enum-like fields with predefined allowed values

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :status, inclusion: { in: %w[draft published archived] }
    check :content_type, exclusion: { in: %w[spam explicit] }
  end
end

article = Article.new(status: "pending")
article.valid?  # => false
article.errors[:status]  # => ["is not included in the list"]
```

---

### Conditional Validation with if/unless

**Cosa fa**: Applies validation only when a condition is true/false

**Quando usarlo**: For validations that depend on model state

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }

  validatable do
    check :title, presence: true
    check :published_at, presence: true, if: :is_published?
    check :author_id, presence: true, if: -> { status == "published" }
    check :draft_notes, presence: true, unless: :is_published?
  end
end
```

---

### Context-Specific Validations

**Cosa fa**: Validates only in specific Rails contexts (create, update, custom)

**Quando usarlo**: For validations that apply only to certain operations

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, presence: true
    check :author_id, presence: true, on: :create
    check :updated_reason, presence: true, on: :update
    check :reviewer_id, presence: true, on: :publish
  end
end

article = Article.new(title: "Test")
article.valid?(:create)  # => false (missing author_id)
article.valid?(:publish)  # => false (missing reviewer_id)
```

---

## Complex Validations

### Price Comparison Validation

**Cosa fa**: Validates that sale price is less than regular price

**Quando usarlo**: For cross-field comparisons that Rails validations can't express

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  register_complex_validation :valid_pricing do
    return if sale_price.blank?

    if sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end
  end

  validatable do
    check :name, :price, presence: true
    check_complex :valid_pricing
  end
end

product = Product.new(price: 100, sale_price: 120)
product.valid?  # => false
product.errors[:sale_price]  # => ["must be less than regular price"]
```

---

### Date Range Validation

**Cosa fa**: Validates that start date is before end date

**Quando usarlo**: For events, bookings, date ranges

**Esempio**:
```ruby
class Event < ApplicationRecord
  include BetterModel

  register_complex_validation :valid_date_range do
    return if starts_at.blank? || ends_at.blank?

    if starts_at >= ends_at
      errors.add(:starts_at, "must be before end date")
    end
  end

  validatable do
    check :title, :starts_at, :ends_at, presence: true
    check_complex :valid_date_range
  end
end

event = Event.new(starts_at: 2.days.from_now, ends_at: 1.day.from_now)
event.valid?  # => false
```

---

### Multiple Field Validation

**Cosa fa**: Validates consistency across multiple related fields

**Quando usarlo**: For capacity checks, quantity limits, and related constraints

**Esempio**:
```ruby
class Event < ApplicationRecord
  include BetterModel

  register_complex_validation :capacity_check do
    return if registered_count.blank? || max_attendees.blank?

    if registered_count > max_attendees
      errors.add(:registered_count, "exceeds capacity (#{max_attendees})")
    end
  end

  validatable do
    check :max_attendees, numericality: { greater_than: 0 }
    check_complex :capacity_check
  end
end
```

---

### Multiple Errors in One Validation

**Cosa fa**: Adds multiple errors to different fields in a single validation

**Quando usarlo**: For complex business rules checking multiple conditions

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel

  register_complex_validation :order_totals do
    items_total = order_items.sum(&:total)

    if discount_amount.present? && discount_amount > items_total
      errors.add(:discount_amount, "cannot exceed items total")
    end

    if items_total < 10.00
      errors.add(:base, "Order must be at least $10.00")
    end
  end

  validatable do
    check_complex :order_totals
  end
end
```

---

### Integration with Statusable

**Cosa fa**: Uses Statusable predicates in complex validation logic

**Quando usarlo**: To validate based on model status/state

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }

  register_complex_validation :publication_requirements do
    return unless is_published?

    errors.add(:published_at, "required") if published_at.blank?
    errors.add(:author_id, "required") if author_id.blank?
    errors.add(:content, "must be at least 100 chars") if content.length < 100
  end

  validatable do
    check :title, presence: true
    check_complex :publication_requirements
  end
end
```

---

### Association Validation

**Cosa fa**: Validates presence and state of associated records

**Quando usarlo**: For orders with items, documents with attachments, etc.

**Esempio**:
```ruby
class Order < ApplicationRecord
  include BetterModel
  has_many :order_items

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

  validatable do
    check_complex :valid_order_items
  end
end
```

---

### Calculated Field Validation

**Cosa fa**: Validates derived values like profit margin or percentage

**Quando usarlo**: For business rules based on calculations

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  register_complex_validation :profit_margin do
    return if cost.blank? || price.blank?

    margin = ((price - cost) / price.to_f) * 100

    if margin < 10
      errors.add(:price, "profit margin (#{margin.round(1)}%) must be at least 10%")
    elsif margin > 80
      errors.add(:price, "profit margin (#{margin.round(1)}%) seems unrealistic")
    end
  end

  validatable do
    check :cost, :price, presence: true
    check_complex :profit_margin
  end
end
```

---

### Conditional Logic in Complex Validation

**Cosa fa**: Different validation rules based on product type or category

**Quando usarlo**: For polymorphic or type-specific validation rules

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  register_complex_validation :type_specific_rules do
    case product_type
    when "physical"
      errors.add(:weight, "required") if weight.blank?
      errors.add(:shipping_cost, "required") if shipping_cost.blank?
    when "digital"
      errors.add(:download_url, "required") if download_url.blank?
    when "service"
      errors.add(:duration, "required") if duration.blank?
    end
  end

  validatable do
    check :name, :product_type, presence: true
    check_complex :type_specific_rules
  end
end
```

---

## Validation Groups

### Basic Validation Group

**Cosa fa**: Defines a group of fields to validate together

**Quando usarlo**: For multi-step forms and wizard flows

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    check :email, :password, presence: true
    check :first_name, :last_name, presence: true
    check :address, :city, :zip_code, presence: true

    validation_group :step1, [:email, :password]
    validation_group :step2, [:first_name, :last_name]
    validation_group :step3, [:address, :city, :zip_code]
  end
end

user = User.new(email: "user@example.com", password: "secret123")
user.valid?(:step1)  # => true (only validates step1 fields)
user.valid?  # => false (full validation)
```

---

### Multi-step Form Controller

**Cosa fa**: Validates different groups in different controller actions

**Quando usarlo**: For wizard-style registration or checkout flows

**Esempio**:
```ruby
class RegistrationController < ApplicationController
  def create_step1
    @user = User.new(step1_params)

    if @user.valid?(:step1)
      session[:user_data] = @user.attributes
      redirect_to registration_step2_path
    else
      render :step1
    end
  end

  def create_step2
    @user = User.new(session[:user_data].merge(step2_params))

    if @user.valid?(:step2)
      session[:user_data] = @user.attributes
      redirect_to registration_step3_path
    else
      render :step2
    end
  end
end
```

---

### Validate Group Method

**Cosa fa**: Explicitly validates only fields in a specific group

**Quando usarlo**: When you need programmatic group validation

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    check :email, :password, presence: true
    check :first_name, :last_name, presence: true

    validation_group :account, [:email, :password]
    validation_group :profile, [:first_name, :last_name]
  end
end

user = User.new(email: "test@example.com", password: "secret")
user.validate_group(:account)  # => true
user.validate_group(:profile)  # => false
```

---

### Errors for Group

**Cosa fa**: Returns errors filtered to fields in a specific group

**Quando usarlo**: To display only relevant errors for current step

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    check :email, :password, :first_name, :last_name, presence: true

    validation_group :step1, [:email, :password]
    validation_group :step2, [:first_name, :last_name]
  end
end

user = User.new
user.valid?  # Run full validation

step1_errors = user.errors_for_group(:step1)
step1_errors[:email]  # => ["can't be blank"]
step1_errors[:first_name]  # => [] (not in step1)
```

---

### Semantic Group Names

**Cosa fa**: Uses descriptive group names that reflect purpose

**Quando usarlo**: Always - makes code self-documenting

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  validatable do
    check :email, :password, presence: true
    check :first_name, :last_name, :date_of_birth, presence: true
    check :phone, :address, :city, presence: true

    # Good - semantic names
    validation_group :account_setup, [:email, :password]
    validation_group :personal_info, [:first_name, :last_name, :date_of_birth]
    validation_group :contact_details, [:phone, :address, :city]
  end
end

user.valid?(:account_setup)  # Clear what's being validated
```

---

## Rails Integration

### With Conditional Options

**Cosa fa**: Combines Validatable with Rails if/unless options

**Quando usarlo**: For state-dependent validation rules

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }
  is :draft, -> { status == "draft" }

  validatable do
    check :title, :content, presence: true
    check :published_at, presence: true, if: :is_published?
    check :author_id, presence: true, if: :is_published?
    check :category_id, presence: true, unless: :is_draft?
  end
end
```

---

### With Validation Contexts

**Cosa fa**: Uses Rails validation contexts (create, update, custom)

**Quando usarlo**: For operation-specific validations

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, presence: true
    check :author_id, presence: true, on: :create
    check :updated_reason, presence: true, on: :update
    check :published_at, presence: true, on: :publish
    check :reviewer_id, presence: true, on: :publish
  end
end

article = Article.new(title: "Test")
article.valid?(:create)  # Validates :create context
article.valid?(:publish)  # Validates :publish context
```

---

### Combining Groups and Contexts

**Cosa fa**: Uses both validation groups and Rails contexts together

**Quando usarlo**: For complex validation scenarios

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, presence: true
    check :author_id, presence: true, on: :create
    check :published_at, presence: true, if: :published?

    validation_group :basic_info, [:title]
    validation_group :publishing_info, [:published_at, :author_id]
  end
end

# Groups ignore contexts
article.valid?(:basic_info)  # Only validates :title

# Contexts ignore groups
article.valid?(:create)  # Validates :title and :author_id
```

---

## Complex Examples

### E-commerce Product

**Cosa fa**: Complete product validation with pricing and stock rules

**Quando usarlo**: For real-world e-commerce applications

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  is :on_sale, -> { sale_price.present? && sale_price < price }

  register_complex_validation :pricing_rules do
    return if price.blank?

    if sale_price.present? && sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end

    if sale_price.present? && cost.present?
      margin = ((sale_price - cost) / sale_price.to_f) * 100
      if margin < 10
        errors.add(:sale_price, "profit margin must be at least 10%")
      end
    end
  end

  register_complex_validation :stock_validation do
    if reserved_stock.present? && stock.present? && reserved_stock > stock
      errors.add(:reserved_stock, "cannot exceed total stock")
    end
  end

  validatable do
    check :name, :sku, presence: true
    check :sku, uniqueness: true
    check :price, numericality: { greater_than: 0 }
    check :stock, numericality: { greater_than_or_equal_to: 0 }
    check_complex :pricing_rules
    check_complex :stock_validation
  end
end
```

---

### Multi-step Registration

**Cosa fa**: User registration with password strength and multi-step validation

**Quando usarlo**: For complex registration flows

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel

  register_complex_validation :password_strength do
    return if password.blank?

    errors.add(:password, "must include number") unless password.match?(/\d/)
    errors.add(:password, "must include uppercase") unless password.match?(/[A-Z]/)
    errors.add(:password, "must include special char") unless password.match?(/[!@#$%^&*]/)
  end

  validatable do
    # Step 1: Account
    check :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    check :password, presence: true, length: { minimum: 8 }
    check_complex :password_strength

    # Step 2: Profile
    check :first_name, :last_name, :date_of_birth, presence: true

    # Step 3: Contact
    check :phone, presence: true, format: { with: /\A\d{10}\z/ }
    check :address, :city, :zip_code, presence: true

    validation_group :account, [:email, :password]
    validation_group :profile, [:first_name, :last_name, :date_of_birth]
    validation_group :contact, [:phone, :address, :city, :zip_code]
  end
end
```

---

### Event Management

**Cosa fa**: Event validation with date consistency and capacity limits

**Quando usarlo**: For booking systems and event platforms

**Esempio**:
```ruby
class Event < ApplicationRecord
  include BetterModel
  belongs_to :venue

  is :upcoming, -> { starts_at > Time.current }

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
      errors.add(:registered_count, "exceeds capacity")
    end

    if venue && max_attendees > venue.capacity
      errors.add(:max_attendees, "exceeds venue capacity")
    end
  end

  validatable do
    check :title, :description, presence: true
    check :title, length: { minimum: 5, maximum: 255 }
    check :starts_at, :ends_at, presence: true
    check :max_attendees, numericality: { greater_than: 0 }
    check_complex :date_consistency
    check_complex :capacity_limits
    check :venue_id, :address, presence: true, if: :published?
  end
end
```

---

## Best Practices

### Always Handle Nil Values

**Cosa fa**: Prevents NoMethodError on nil in complex validations

**Quando usarlo**: In every complex validation with field access

**Esempio**:
```ruby
# Good - explicit nil handling
register_complex_validation :valid_dates do
  return if starts_at.blank? || ends_at.blank?
  errors.add(:starts_at, "must be before end date") if starts_at >= ends_at
end

# Bad - will crash on nil
register_complex_validation :valid_dates do
  errors.add(:starts_at, "invalid") if starts_at >= ends_at
end
```

---

### Keep Validations Focused

**Cosa fa**: One validation per concern for maintainability

**Quando usarlo**: Always - prefer multiple small validations over one large one

**Esempio**:
```ruby
# Good - separate concerns
register_complex_validation :valid_dates do
  # Only date logic
end

register_complex_validation :capacity_check do
  # Only capacity logic
end

# Bad - mixing concerns
register_complex_validation :validate_everything do
  # 50 lines of various checks
end
```

---

### Use Descriptive Names

**Cosa fa**: Names that clearly indicate what is being validated

**Quando usarlo**: For all validations and groups

**Esempio**:
```ruby
# Good - clear purpose
register_complex_validation :publication_requirements
register_complex_validation :profit_margin_check
validation_group :account_setup, [:email, :password]

# Bad - generic names
register_complex_validation :check1
register_complex_validation :validation
validation_group :step1, [:email, :password]
```

---

### Provide Clear Error Messages

**Cosa fa**: Specific, actionable error messages for users

**Quando usarlo**: In every error.add call

**Esempio**:
```ruby
# Good - specific and actionable
errors.add(:sale_price, "must be less than regular price ($#{price})")
errors.add(:starts_at, "must be at least 24 hours from now")

# Bad - vague messages
errors.add(:sale_price, "invalid")
errors.add(:starts_at, "wrong")
```

---

### Use Rails Options for Simple Conditionals

**Cosa fa**: Leverages Rails if/unless instead of complex validation

**Quando usarlo**: When condition is simple and applies to single field

**Esempio**:
```ruby
# Good - simple conditional
check :published_at, presence: true, if: :published?

# Overkill - too complex for simple case
register_complex_validation :published_at_check do
  return unless published?
  errors.add(:published_at, "can't be blank") if published_at.blank?
end
```

---

## Error Handling

### ValidatableNotEnabledError

**Cosa fa**: Raised when using group methods without enabling Validatable

**Quando usarlo**: Catches configuration mistakes

**Esempio**:
```ruby
class User < ApplicationRecord
  include BetterModel
  # No validatable block!
end

user = User.new
user.errors_for_group(:step1)
# Raises: BetterModel::ValidatableNotEnabledError
# Message: "Validatable is not enabled. Add 'validatable do...end' to your model."

rescue BetterModel::ValidatableNotEnabledError => e
  Rails.logger.error "Configuration error: #{e.message}"
end
```

---

### ArgumentError for Unknown Complex Validation

**Cosa fa**: Raised when referencing undefined complex validation

**Quando usarlo**: Catches typos and missing registrations

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  validatable do
    check_complex :nonexistent  # Not registered!
  end
end
# Raises: ArgumentError
# Message: "Unknown complex validation: nonexistent. Use register_complex_validation to define it first."

# Fix: register first
register_complex_validation :nonexistent do
  # validation logic
end
```

---

## Summary

**Three Core Features**:

1. **`check`** - Basic validations with declarative syntax (all Rails validation options)
2. **`register_complex_validation` + `check_complex`** - Reusable validation blocks for cross-field logic
3. **`validation_group`** - Partial validation for multi-step forms

**Works seamlessly with**:
- Rails conditional options (`if`, `unless`)
- Rails validation contexts (`on: :create`, `on: :update`, custom)
- Statusable predicates
- Standard Rails validations

**Thread-safe**, **opt-in** (requires `validatable do...end`), and **fully compatible** with ActiveModel.

**Key Methods**:
- `Model.complex_validation?(:name)` - Check if validation is registered
- `instance.valid?(group_or_context)` - Validate group or context
- `instance.validate_group(:name)` - Validate specific group
- `instance.errors_for_group(:name)` - Get errors for group
