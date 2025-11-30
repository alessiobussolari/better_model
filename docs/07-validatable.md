# Validatable

Validatable provides a declarative validation system for Rails models with support for cross-field comparisons, complex validations, and validation groups. It extends ActiveModel validations with a cleaner, more expressive syntax while maintaining full compatibility with Rails' built-in validation framework.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Basic Validations](#basic-validations)
- [Complex Validations](#complex-validations)
- [Validation Groups](#validation-groups)
- [Instance Methods](#instance-methods)
- [Integration with Rails Contexts](#integration-with-rails-contexts)
- [Real-world Examples](#real-world-examples)
- [Best Practices](#best-practices)

## Overview

**Key Features:**

- **Opt-in Activation**: Validatable is not active by default. You must explicitly enable it with `validatable do...end`.
- **Declarative DSL**: Clean, readable syntax for all validation types.
- **Complex Validations**: Reusable validation blocks for any validation logic including cross-field comparisons.
- **Validation Groups**: Partial validation for multi-step forms and wizards.
- **Full Rails Compatibility**: Works seamlessly with ActiveModel validations and contexts.
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

**Using Rails Conditional Options:**

For conditional validations, use Rails' built-in `if` and `unless` options:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }

  validatable do
    # Always required
    check :title, :status, presence: true

    # Conditional using Rails' if option
    check :published_at, presence: true, if: :is_published?
    check :author_id, presence: true, if: -> { status == "published" }
  end
end
```

## Complex Validations

Complex validations allow you to register reusable validation logic that can combine multiple fields or implement custom business rules. Like complex predicates and complex sorts, they follow a simple registration pattern.

### API Reference: register_complex_validation

**Method Signature:**
```ruby
register_complex_validation(name, &block)
```

**Parameters:**
- `name` (Symbol): The name of the validation (required)
- `block` (Proc): Validation logic that runs in the instance context (required)

**Returns:** Registers the validation in `complex_validations_registry`

**Thread Safety:** Registry is a frozen Hash, validations defined at class load time

### Basic Usage

```ruby
class Product < ApplicationRecord
  include BetterModel

  # Register a complex validation
  register_complex_validation :valid_pricing do
    if sale_price.present? && sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end
  end

  validatable do
    check :name, presence: true
    check_complex :valid_pricing  # Use the registered validation
  end
end

# Usage
product = Product.new(price: 100, sale_price: 120)
product.valid?  # => false
product.errors[:sale_price]  # => ["must be less than regular price"]
```

### Cross-Field Validations

Complex validations are perfect for validating relationships between fields (cross-field validations):

```ruby
class Event < ApplicationRecord
  include BetterModel

  # Date comparisons
  register_complex_validation :valid_dates do
    return if starts_at.blank? || ends_at.blank?  # Skip if nil

    if starts_at >= ends_at
      errors.add(:starts_at, "must be before end date")
    end
  end

  # Numeric comparisons
  register_complex_validation :capacity_check do
    return if registered_count.blank? || max_attendees.blank?

    if registered_count > max_attendees
      errors.add(:registered_count, "exceeds capacity")
    end
  end

  # Price range validation
  register_complex_validation :valid_price_range do
    return if min_price.blank? || max_price.blank?

    if min_price > max_price
      errors.add(:min_price, "must be less than or equal to max price")
    end
  end

  validatable do
    check :title, presence: true
    check_complex :valid_dates
    check_complex :capacity_check
    check_complex :valid_price_range
  end
end

# Usage
event = Event.new(starts_at: 1.day.from_now, ends_at: Time.current)
event.valid?  # => false
event.errors[:starts_at]  # => ["must be before end date"]
```

### Multiple Complex Validations

You can register and use multiple complex validations in the same model:

```ruby
class Product < ApplicationRecord
  include BetterModel

  register_complex_validation :valid_pricing do
    if sale_price.present? && sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end
  end

  register_complex_validation :valid_stock do
    if reserved_stock.present? && reserved_stock > stock
      errors.add(:reserved_stock, "cannot exceed total stock")
    end
  end

  validatable do
    check_complex :valid_pricing
    check_complex :valid_stock
  end
end
```

### Complex Validations with Statusable

Complex validations work seamlessly with Statusable predicates:

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" }

  register_complex_validation :publication_requirements do
    if is_published? && published_at.blank?
      errors.add(:published_at, "required for published articles")
    end
  end

  validatable do
    check_complex :publication_requirements
  end
end
```

### Class Methods

```ruby
# Check if a complex validation is registered
Product.complex_validation?(:valid_pricing)  # => true

# Get all registered complex validations
Product.complex_validations_registry
# => {:valid_pricing => #<Proc>, :valid_stock => #<Proc>}
```

**Key Points:**

- Complex validations are reusable blocks of validation logic.
- They execute in the instance context (can access all attributes and methods).
- They can add multiple errors to different fields.
- The registry is frozen for thread-safety.
- Complex validations are inherited by subclasses.

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
- `BetterModel::Errors::Validatable::NotEnabledError` if Validatable is not enabled.

### errors_for_group(group_name)

Get errors filtered to a specific group's fields:

```ruby
user.valid?  # Run full validation first
errors = user.errors_for_group(:step1)
errors[:email]  # => ["can't be blank"]
errors[:first_name]  # => [] (not in step1)
```

**Raises:**
- `BetterModel::Errors::Validatable::NotEnabledError` if Validatable is not enabled.

## Error Handling

> **ℹ️ Version 3.0.0 Compatible**: All error examples use standard Ruby exception patterns with `e.message`. Domain-specific attributes and Sentry helpers have been removed in v3.0.0 for simplicity.

Validatable raises specific errors for different failure scenarios. All errors provide helpful error messages via `.message`.

### NotEnabledError

Raised when Validatable methods are called but the module is not enabled.

**Example:**

```ruby
class Article < ApplicationRecord
  include BetterModel
  # No validatable block - module not enabled
end

article = Article.new
begin
  article.validate_group(:step1)
rescue BetterModel::Errors::Validatable::NotEnabledError => e
  # Only message available in v3.0.0
  e.message
  # => "Validatable is not enabled for Article"

  # Log or report
  Rails.logger.error("Validatable not enabled: #{e.message}")
  Sentry.capture_exception(e)
end
```

**Methods that raise this error:**
- `validate_group(group_name)`
- `errors_for_group(group_name)`

**Solution:** Enable Validatable by adding `validatable do...end` to your model:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, presence: true
  end
end
```

**Handling in controllers:**

```ruby
class RegistrationController < ApplicationController
  def create_step1
    @user = User.new(step1_params)

    begin
      if @user.valid?(:step1)
        redirect_to registration_step2_path
      else
        render :step1
      end
    rescue BetterModel::Errors::Validatable::NotEnabledError => e
      Rails.logger.error("Validatable error: #{e.message}")
      Sentry.capture_exception(e)

      # Fall back to standard validation
      if @user.valid?
        redirect_to registration_step2_path
      else
        render :step1
      end
    end
  end
end
```

### ConfigurationError

Raised when there are configuration issues during class definition.

#### Scenario 1: Non-ActiveRecord Model

```ruby
class PlainRubyClass
  include BetterModel::Validatable
end

# Raises: BetterModel::Errors::Validatable::ConfigurationError
begin
  # Configuration happens at class load time
rescue BetterModel::Errors::Validatable::ConfigurationError => e
  # Only message available in v3.0.0
  e.message
  # => "BetterModel::Validatable can only be included in ActiveRecord models"

  # Log or report
  Rails.logger.error("Configuration error: #{e.message}")
  Sentry.capture_exception(e)
end
```

**Solution:** Only include Validatable in ActiveRecord models.

#### Scenario 2: Missing Block in Complex Validation

```ruby
class Product < ApplicationRecord
  include BetterModel

  register_complex_validation :valid_pricing  # No block provided!
end

# Raises: BetterModel::Errors::Validatable::ConfigurationError
begin
  # Configuration happens at class load time
rescue BetterModel::Errors::Validatable::ConfigurationError => e
  # Only message available in v3.0.0
  e.message
  # => "Block required for complex validation: valid_pricing"

  # Log or report
  Rails.logger.error("Configuration error: #{e.message}")
  Sentry.capture_exception(e)
end
```

**Solution:** Always provide a block to `register_complex_validation`:

```ruby
class Product < ApplicationRecord
  include BetterModel

  register_complex_validation :valid_pricing do
    if sale_price.present? && sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end
  end
end
```

### ArgumentError (from Configurator)

**When raised:** Invalid parameters during validatable configuration.

#### Scenario 1: Unknown Complex Validation

```ruby
class Product < ApplicationRecord
  include BetterModel

  validatable do
    check_complex :nonexistent_validation
  end
end
# Raises: ArgumentError
#   "Unknown complex validation: nonexistent_validation.
#    Use register_complex_validation to define it first."
```

**Solution:** Register the validation before using it:

```ruby
class Product < ApplicationRecord
  include BetterModel

  register_complex_validation :my_validation do
    # validation logic here
  end

  validatable do
    check_complex :my_validation
  end
end
```

#### Scenario 2: Invalid Validation Group Parameters

```ruby
# Error: Group name must be a symbol
validatable do
  validation_group "step1", [:email]  # String not allowed
end
# Raises: ArgumentError "Group name must be a symbol"

# Error: Fields must be an array
validatable do
  validation_group :step1, :email  # Not an array
end
# Raises: ArgumentError "Fields must be an array"

# Error: Duplicate group names
validatable do
  validation_group :step1, [:email]
  validation_group :step1, [:password]  # Duplicate!
end
# Raises: ArgumentError "Group already defined: step1"
```

**Solution:** Use symbols for group names, arrays for fields, and unique group names:

```ruby
validatable do
  validation_group :step1, [:email, :password]
  validation_group :step2, [:first_name, :last_name]
end
```

### Error Hierarchy

All Validatable errors follow a consistent hierarchy:

```
StandardError
└── BetterModel::Errors::BetterModelError (root for all BetterModel errors)
    └── BetterModel::Errors::Validatable::ValidatableError (base for Validatable)
        └── BetterModel::Errors::Validatable::NotEnabledError

ArgumentError (for backward compatibility)
└── BetterModel::Errors::Validatable::ConfigurationError
```

**Note:** `ConfigurationError` inherits from `ArgumentError` rather than `ValidatableError` for backward compatibility with existing rescue clauses that expect `ArgumentError`.

### Comprehensive Controller Error Handling

Here's a complete example showing how to handle all Validatable errors in a controller:

```ruby
class ApiController < ApplicationController
  def create
    @model = Model.new(model_params)

    # Decide validation strategy based on params
    if params[:partial_validation]
      group = params[:validation_group]&.to_sym
      validate_with_group(group)
    else
      validate_fully
    end

  rescue BetterModel::Errors::Validatable::NotEnabledError => e
    # Validatable not configured - fall back to standard validation
    Rails.logger.warn("Validatable not enabled: #{e.message}")
    Sentry.capture_exception(e)
    validate_fully

  rescue ArgumentError => e
    # Configuration or parameter error
    if e.message.include?("Unknown complex validation")
      Rails.logger.error("Invalid validation configuration: #{e.message}")
      Sentry.capture_exception(e)
      render json: { error: "Server configuration error" }, status: :internal_server_error
    else
      raise  # Re-raise if not a Validatable error
    end
  end

  private

  def validate_with_group(group)
    if @model.valid?(group)
      @model.save(validate: false)
      render json: @model, status: :created
    else
      errors = @model.errors_for_group(group)
      render json: { errors: errors.full_messages }, status: :unprocessable_entity
    end
  end

  def validate_fully
    if @model.valid?
      @model.save(validate: false)
      render json: @model, status: :created
    else
      render json: { errors: @model.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
```

### Best Practices

1. **Check if enabled before using group validation:**
   ```ruby
   if model.class.validatable_enabled?
     model.valid?(:step1)
   else
     model.valid?  # Fall back to standard validation
   end
   ```

2. **Rescue specific errors in controllers:**
   ```ruby
   begin
     user.validate_group(:step1)
   rescue BetterModel::Errors::Validatable::NotEnabledError => e
     Rails.logger.warn(e.message)
     # Handle gracefully with fallback
     user.valid?
   end
   ```

3. **Test error scenarios:**
   ```ruby
   # RSpec
   RSpec.describe Article, type: :model do
     describe "validation group errors" do
       it "raises NotEnabledError when not enabled" do
         expect { article.validate_group(:step1) }.to raise_error(
           BetterModel::Errors::Validatable::NotEnabledError,
           /not enabled/
         )
       end
     end
   end

   # Minitest
   class ArticleTest < ActiveSupport::TestCase
     test "raises NotEnabledError when validatable not enabled" do
       article = Article.new
       assert_raises(BetterModel::Errors::Validatable::NotEnabledError) do
         article.validate_group(:step1)
       end
     end
   end
   ```

4. **Use descriptive messages in production:**
   ```ruby
   rescue BetterModel::Errors::Validatable::NotEnabledError => e
     # Log technical details
     Rails.logger.error("#{e.class}: #{e.message}")
     Sentry.capture_exception(e)
     # Show user-friendly message
     redirect_to root_path, alert: "Validation feature is not available"
   end
   ```

5. **Validate configuration in development:**
   ```ruby
   # config/initializers/validatable_check.rb
   if Rails.env.development?
     Rails.application.config.after_initialize do
       ApplicationRecord.descendants.each do |model|
         if model.respond_to?(:validatable_enabled?) && model.validatable_enabled?
           Rails.logger.info "✓ Validatable enabled for #{model.name}"
         end
       end
     end
   end
   ```

## Error Tracking Integration

All BetterModel errors work with standard error tracking tools like Sentry, Rollbar, etc. Simply capture the exception:

### Basic Sentry Integration

```ruby
class RegistrationController < ApplicationController
  def create_step
    @user = User.new(user_params)
    group = "step#{params[:step]}".to_sym

    begin
      if @user.valid?(group)
        save_and_continue
      else
        render_errors_for_step(group)
      end
    rescue BetterModel::Errors::Validatable::ValidatableError => e
      # Simple capture - message contains all context
      Sentry.capture_exception(e)

      # Handle gracefully
      flash[:alert] = "Validation feature temporarily unavailable"
      fallback_to_full_validation
    end
  end
end
```

### Production Error Handling

```ruby
class ApplicationController < ActionController::Base
  rescue_from BetterModel::Errors::Validatable::NotEnabledError do |e|
    Rails.logger.error("Validatable not enabled: #{e.message}")
    Sentry.capture_exception(e)
    # Fall back to standard validation
    flash[:warning] = "Using standard validation"
    retry_with_standard_validation
  end

  rescue_from BetterModel::Errors::Validatable::ConfigurationError do |e|
    Rails.logger.error("Validatable configuration error: #{e.message}")
    Sentry.capture_exception(e)
    render json: { error: "Server configuration error" }, status: :internal_server_error
  end

  private

  def retry_with_standard_validation
    # Fallback logic here
  end
end
```

## Integration with Rails Contexts

Validatable works seamlessly with Rails validation contexts and Statusable predicates:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses with Statusable
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }

  validatable do
    # Always required
    check :title, :content, presence: true

    # Use validation contexts (on: :create, on: :update, on: :publish, etc.)
    check :author_id, presence: true, on: :create

    # Combine contexts with conditional logic using if/unless
    check :published_at, presence: true, if: :is_published?
    check :reviewer_id, presence: true, if: :is_published?

    # Complex validation with Statusable predicates
    check :category_id, presence: true, unless: :is_draft?

    # Validation groups for multi-step forms
    validation_group :basic_info, [:title, :content]
    validation_group :publishing_info, [:published_at, :author_id]
  end
end

# Use with contexts
article.valid?(:create)   # Validates with :create context
article.valid?(:publish)  # Validates with :publish context
article.valid?            # Validates everything

# Use with validation groups
article.valid?(:basic_info)      # Only validates :title and :content
article.valid?(:publishing_info) # Only validates :published_at and :author_id
```

**Benefits:**

- Leverage Rails' built-in validation contexts (`on: :create`, `on: :update`, custom contexts).
- Combine validation groups with contexts for flexible validation strategies.
- Use Statusable predicates in conditional validations (`if:`, `unless:`).

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

  # Register complex validation for venue
  register_complex_validation :venue_requirements do
    return if venue_id.blank?

    unless Venue.exists?(id: venue_id)
      errors.add(:venue_id, "must be a valid venue")
    end
  end

  register_complex_validation :modification_rules do
    return unless persisted?

    if is_past?
      errors.add(:base, "cannot modify past events")
    elsif registered_count > 0 && starts_at_changed?
      errors.add(:starts_at, "cannot be changed after registrations exist")
    end
  end

  validatable do
    # Basic validations
    check :title, :description, presence: true
    check :title, length: { minimum: 5, maximum: 255 }

    # Date validations
    check :starts_at, :ends_at, presence: true

    # Capacity validations
    check :max_attendees, numericality: { greater_than: 0 }

    # Published events require more fields using Rails if option
    check :venue, :address, :city, presence: true, if: :is_published?
    check :ticket_price, numericality: { greater_than_or_equal_to: 0 }, if: :is_published?

    # Complex validations
    check_complex :venue_requirements
    check_complex :modification_rules, on: :update
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

  # Register complex validations
  register_complex_validation :category_check do
    return if category_id.blank?

    unless Category.active.exists?(id: category_id)
      errors.add(:category_id, "must be an active category")
    end
  end

  register_complex_validation :variants_check do
    return if variants.empty?

    if variants.any? { |v| v.price > price }
      errors.add(:base, "variant prices cannot exceed base price")
    end
  end

  validatable do
    # Basic validations
    check :name, :sku, presence: true
    check :sku, uniqueness: true

    # Price validations
    check :price, numericality: { greater_than: 0 }

    # Sale price validations using Rails if option
    check :sale_price, presence: true, if: :is_on_sale?

    # Stock validations
    check :stock, numericality: { greater_than_or_equal_to: 0 }

    # Shipping validations
    check :weight, :dimensions, presence: true
    check :weight, numericality: { greater_than: 0 }

    # Complex validations
    check_complex :category_check
    check_complex :variants_check
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

### 2. Use Rails Conditional Options with Statusable

Use Statusable predicates with Rails' `if` and `unless` options:

```ruby
# Good - readable, maintainable
is :published, -> { status == "published" }

validatable do
  check :published_at, presence: true, if: :is_published?
  check :author_id, presence: true, if: :is_published?
end

# Also good - inline lambda for simple conditions
validatable do
  check :published_at, presence: true, if: -> { status == "published" }
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

### 4. Keep Complex Validations Focused

Each complex validation should validate one concern:

```ruby
# Good - single responsibility
register_complex_validation :category_check do
  return if category_id.blank?
  errors.add(:category_id, "invalid") unless Category.exists?(id: category_id)
end

register_complex_validation :price_range_check do
  return if price.blank? || max_price.blank?
  errors.add(:price, "exceeds maximum") if price > max_price
end

# Avoid - multiple responsibilities
register_complex_validation :product_validation do
  errors.add(:category_id, "invalid") unless Category.exists?(id: category_id)
  errors.add(:price, "exceeds maximum") if price > max_price
  # ... many more validations
end
```

### 5. Use Complex Validations for Cross-field Comparisons

Use complex validations for comparing fields:

```ruby
# Good - reusable and clear
register_complex_validation :valid_date_range do
  return if starts_at.blank? || ends_at.blank?
  errors.add(:starts_at, "must be before end date") if starts_at >= ends_at
end

validatable do
  check :starts_at, :ends_at, presence: true
  check_complex :valid_date_range
end
```

### 6. Handle Nil Values in Complex Validations

Always check for nil values in complex validations:

```ruby
# Good - explicit nil handling
register_complex_validation :valid_dates do
  return if starts_at.blank? || ends_at.blank?  # Early return
  errors.add(:starts_at, "must be before end") if starts_at >= ends_at
end

# Avoid - no nil check (can cause errors)
register_complex_validation :valid_dates do
  errors.add(:starts_at, "must be before end") if starts_at >= ends_at
end
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

  # Conditional validations using Rails options
  check :published_at, presence: true, if: :is_published?

  # Complex validations
  check_complex :date_range_validation
  check_complex :category_validation
  check_complex :author_validation
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

### 9. Document Complex Validations

Add comments explaining complex validation logic:

```ruby
# Users must be 18+ to register
register_complex_validation :minimum_age_requirement do
  return if date_of_birth.blank?

  if date_of_birth > 18.years.ago
    errors.add(:date_of_birth, "must be at least 18 years ago")
  end
end

# Account status transitions follow: draft → active → suspended → deleted
# Transitions can only move forward, never backward
register_complex_validation :valid_status_transition do
  return unless persisted? && status_changed?

  old_status, new_status = status_change
  unless valid_transition?(old_status, new_status)
    errors.add(:status, "invalid transition from #{old_status} to #{new_status}")
  end
end

validatable do
  check_complex :minimum_age_requirement
  check_complex :valid_status_transition, on: :update
end
```

### 10. Prefer Declarative Over Procedural

Use Validatable's DSL instead of inline custom validation methods:

```ruby
# Good - declarative with complex validations
register_complex_validation :valid_date_range do
  return if starts_at.blank? || ends_at.blank?
  errors.add(:starts_at, "must be before end date") if starts_at >= ends_at
end

validatable do
  check :title, presence: true, length: { minimum: 5 }
  check_complex :valid_date_range
end

# Avoid - inline custom validation methods
validate :title_present_and_long_enough
validate :starts_before_ends

def title_present_and_long_enough
  errors.add(:title, "can't be blank") if title.blank?
  errors.add(:title, "too short") if title && title.length < 5
end

def starts_before_ends
  return if starts_at.blank? || ends_at.blank?
  errors.add(:starts_at, "must be before ends_at") if starts_at >= ends_at
end
```

---

**[← Back to Main Documentation](../README.md)**
