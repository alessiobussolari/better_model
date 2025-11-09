# Validatable Examples

Validatable provides a declarative validation DSL that extends Rails validations with conditional groups, cross-field validation, and business rules.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Basic Validations](#example-1-basic-validations)
- [Example 2: Conditional Validations](#example-2-conditional-validations)
- [Example 3: Validation Groups](#example-3-validation-groups)
- [Example 4: Cross-field Validation](#example-4-cross-field-validation)
- [Example 5: Business Rules](#example-5-business-rules)
- [Example 6: Multi-step Forms](#example-6-multi-step-forms)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Model
class Article < ApplicationRecord
  include BetterModel

  validatable do
    check :title, presence: true
    check :content, presence: true
    check :title, length: { minimum: 5, maximum: 200 }
  end
end
```

## Example 1: Basic Validations

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Presence
    check :title, :content, presence: true

    # Length
    check :title, length: { minimum: 5, maximum: 200 }
    check :content, length: { minimum: 10 }

    # Format
    check :slug, format: { with: /\A[a-z0-9\-]+\z/ }

    # Numericality
    check :view_count, numericality: { greater_than_or_equal_to: 0 }

    # Inclusion
    check :status, inclusion: { in: %w[draft published archived] }
  end
end

# Valid article
article = Article.new(
  title: "Valid Title",
  content: "Valid content with enough characters",
  slug: "valid-title",
  view_count: 0,
  status: "draft"
)
article.valid?
# => true

# Invalid article
article = Article.new(title: "Hi")  # Too short
article.valid?
# => false

article.errors[:title]
# => ["is too short (minimum is 5 characters)"]
```

**Output Explanation**: Validatable wraps standard Rails validations in a declarative DSL.

## Example 2: Validation Groups

Perfect for multi-step forms:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Step 1: Basic info
    validation_group :basic_info, [:title, :slug]
    check :title, presence: true, length: { minimum: 5 }
    check :slug, presence: true, format: { with: /\A[a-z0-9\-]+\z/ }

    # Step 2: Content
    validation_group :content_info, [:content, :excerpt]
    check :content, presence: true, length: { minimum: 100 }
    check :excerpt, length: { maximum: 300 }

    # Step 3: Publishing
    validation_group :publishing_info, [:published_at, :status]
    check :published_at, presence: true
    check :status, inclusion: { in: %w[draft published] }
  end
end

# Validate specific group
article = Article.new(title: "My Article")
article.valid?(:basic_info)
# => false (missing slug)

article.slug = "my-article"
article.valid?(:basic_info)
# => true

# Check multiple groups (custom logic)
def valid_for_groups?(groups)
  groups.all? { |group| valid?(group) }
end

article.valid_for_groups?([:basic_info, :content_info])
# => false (missing content)

# Full validation
article.valid?
# => Validates all fields
```

**Output Explanation**: Validation groups allow step-by-step validation without triggering all validations at once.

## Example 3: Cross-field Validation with Complex Validations

Validate relationships between fields using complex validations:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Register cross-field validations
  register_complex_validation :valid_date_range do
    return if starts_at.blank? || ends_at.blank?

    if starts_at >= ends_at
      errors.add(:starts_at, "must be before ends at")
    end
  end

  register_complex_validation :valid_schedule do
    return if scheduled_at.blank? || expires_at.blank?

    if scheduled_at >= expires_at
      errors.add(:scheduled_at, "Schedule must be before expiration")
    end
  end

  register_complex_validation :valid_view_range do
    return if min_views.blank? || max_views.blank?

    if min_views >= max_views
      errors.add(:min_views, "must be less than max views")
    end
  end

  validatable do
    check_complex :valid_date_range
    check_complex :valid_schedule
    check_complex :valid_view_range
  end
end

# Valid order
article = Article.new(
  starts_at: Time.current,
  ends_at: 1.day.from_now
)
article.valid?
# => true

# Invalid order
article = Article.new(
  starts_at: 1.day.from_now,
  ends_at: Time.current
)
article.valid?
# => false

article.errors[:starts_at]
# => ["must be before ends at"]
```

**Output Explanation**: Complex validations provide flexible cross-field validation with custom logic and messages.

## Example 4: Business Logic with Complex Validations

Validate complex business logic using complex validations:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Register complex validations for business rules
  register_complex_validation :publication_requirements do
    return unless status == "published"

    errors.add(:base, "Published articles must have content") if content.blank?
    errors.add(:base, "Published articles must have published_at") if published_at.blank?
    errors.add(:base, "Published articles must be reviewed") if reviewed_by_id.blank?
  end

  register_complex_validation :featured_requirements do
    return unless featured?

    if featured_image_url.blank?
      errors.add(:featured_image_url, "is required for featured articles")
    end
  end

  register_complex_validation :archive_requirements do
    return unless archived?

    if archive_reason.blank?
      errors.add(:archive_reason, "must be provided when archiving")
    end
  end

  validatable do
    check :title, :content, presence: true

    check_complex :publication_requirements
    check_complex :featured_requirements
    check_complex :archive_requirements
  end
end

# Invalid published article
article = Article.new(
  title: "Incomplete",
  content: "",
  status: "published"
)
article.valid?
# => false

article.errors.full_messages
# => [
#   "Published articles must have content",
#   "Published articles must have published_at",
#   "Published articles must be reviewed"
# ]
```

**Output Explanation**: Complex validations check business logic with access to all model attributes and methods.

## Example 5: Multi-step Forms

Complete multi-step form example:

```ruby
class Article < ApplicationRecord
  include BetterModel

  attr_accessor :current_step

  validatable do
    # Step 1: Basic Information
    validation_group :step1, [:title, :slug, :category]
    check :title, presence: true, length: { minimum: 5, maximum: 200 }
    check :slug, presence: true, format: { with: /\A[a-z0-9\-]+\z/ }
    check :category, presence: true

    # Step 2: Content
    validation_group :step2, [:content, :excerpt]
    check :content, presence: true, length: { minimum: 100 }
    check :excerpt, length: { maximum: 300 }

    # Step 3: Media
    validation_group :step3, [:featured_image_url]
    check :featured_image_url, presence: true, if: -> { featured? }

    # Step 4: Publishing
    validation_group :step4, [:status, :published_at]
    check :published_at, presence: true, if: -> { status == "published" }
  end

  def valid_for_current_step?
    case current_step
    when 1
      valid?(:step1)
    when 2
      valid?(:step2)
    when 3
      valid?(:step3)
    when 4
      valid?(:step4)
    else
      valid?  # Final validation
    end
  end
end

# In controller
class ArticlesController < ApplicationController
  def create
    @article = Article.new(article_params)
    @article.current_step = params[:step].to_i

    if @article.valid_for_current_step?
      if params[:step].to_i == 4
        @article.save!
        redirect_to @article, notice: "Article created!"
      else
        # Save as draft and go to next step
        @article.status = "draft"
        @article.save(validate: false)
        redirect_to edit_article_path(@article, step: params[:step].to_i + 1)
      end
    else
      render :new
    end
  end
end
```

**Output Explanation**: Validation groups enable progressive validation in multi-step forms.

## Tips & Best Practices

### 1. Keep Business Rules Focused
```ruby
# Good: Focused single-purpose method
def published_article_must_have_date
  return unless published?
  errors.add(:published_at, "required") if published_at.blank?
end

# Bad: Multiple concerns in one method
def validate_everything
  # ... 50 lines of validation logic
end
```

### 2. Use Validation Groups for Complex Forms
```ruby
# Multi-step forms
validation_group :step1, [:title, :category]
validation_group :step2, [:content, :excerpt]
validation_group :step3, [:published_at, :status]

# Different contexts
validation_group :api_create, [:title, :content, :status]
validation_group :web_draft, [:title]
validation_group :web_publish, [:title, :content, :published_at]
```

### 3. Combine with Standard Rails Validations
```ruby
class Article < ApplicationRecord
  # Standard Rails validations
  validates :user, presence: true
  validates :title, uniqueness: { scope: :user_id }

  # Validatable for complex cases
  register_complex_validation :content_requirements do
    return unless published?
    errors.add(:content, "must be present for published articles") if content.blank?
  end

  validatable do
    check :content, presence: true, if: :published?
    check_complex :content_requirements
  end
end
```

### 4. Test Validations Thoroughly
```ruby
# RSpec
RSpec.describe Article, type: :model do
  describe "validations" do
    it "requires title for all articles" do
      article = Article.new
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("can't be blank")
    end

    context "when published" do
      it "requires published_at" do
        article = Article.new(status: "published")
        expect(article).not_to be_valid
        expect(article.errors[:published_at]).to include("can't be blank")
      end
    end

    describe "validation groups" do
      it "validates step1 fields" do
        article = Article.new(title: "Valid")
        expect(article.valid?(:step1)).to be false
        article.slug = "valid"
        expect(article.valid?(:step1)).to be true
      end
    end
  end
end
```

### 5. Provide Clear Error Messages
```ruby
class Event < ApplicationRecord
  register_complex_validation :valid_date_range do
    return if starts_at.blank? || ends_at.blank?

    if starts_at >= ends_at
      errors.add(:starts_at, "Event must start before it ends")
    end
  end

  register_complex_validation :sensible_duration do
    return if starts_at.blank? || ends_at.blank?

    duration = ends_at - starts_at
    if duration > 30.days
      errors.add(:ends_at, "Event cannot last more than 30 days")
    end
  end

  validatable do
    check_complex :valid_date_range
    check_complex :sensible_duration
  end
end
```

## Example 7: Complex Validations

Complex validations allow you to register reusable validation logic that can combine multiple fields or implement custom business rules:

```ruby
class Product < ApplicationRecord
  include BetterModel

  # Register complex validations
  register_complex_validation :valid_pricing do
    # Skip if both prices are nil
    return if price.nil? && sale_price.nil?

    # Ensure sale price is less than regular price
    if sale_price.present? && sale_price >= price
      errors.add(:sale_price, "must be less than regular price")
    end

    # Ensure minimum profit margin
    if sale_price.present? && price.present?
      margin = ((price - sale_price) / price.to_f) * 100
      if margin < 10
        errors.add(:sale_price, "profit margin must be at least 10%")
      end
    end
  end

  register_complex_validation :valid_stock do
    # Reserved stock validation
    if reserved_stock.present? && reserved_stock > stock
      errors.add(:reserved_stock, "cannot exceed total stock")
    end

    # Low stock warning
    if stock.present? && stock < reorder_level
      errors.add(:stock, "is below reorder level (#{reorder_level})")
    end
  end

  validatable do
    check :name, :sku, presence: true
    check :price, numericality: { greater_than: 0 }

    # Use complex validations
    check_complex :valid_pricing
    check_complex :valid_stock
  end
end

# Usage in controller
class ProductsController < ApplicationController
  def create
    @product = Product.new(product_params)

    if @product.valid?
      @product.save
      redirect_to @product, notice: "Product created successfully"
    else
      # Show specific error messages
      render :new
    end
  end

  private

  def product_params
    params.require(:product).permit(:name, :sku, :price, :sale_price, :stock, :reserved_stock, :reorder_level)
  end
end

# Example validations
product = Product.new(
  name: "Widget",
  sku: "WDG-001",
  price: 100,
  sale_price: 95,  # Only 5% margin - invalid
  stock: 10,
  reserved_stock: 5,
  reorder_level: 20
)

product.valid?  # => false
product.errors[:sale_price]  # => ["profit margin must be at least 10%"]
product.errors[:stock]  # => ["is below reorder level (20)"]

# Valid product
product = Product.new(
  name: "Widget",
  sku: "WDG-001",
  price: 100,
  sale_price: 80,  # 20% margin - valid
  stock: 30,
  reserved_stock: 5,
  reorder_level: 20
)

product.valid?  # => true
```

### Real-World Example: E-commerce Order

```ruby
class Order < ApplicationRecord
  include BetterModel

  belongs_to :customer
  has_many :order_items

  is :paid, -> { payment_status == "paid" }

  register_complex_validation :valid_order_totals do
    # Calculate totals
    items_total = order_items.sum(&:total)
    calculated_total = items_total + shipping_cost - discount_amount

    # Validate total matches
    if total.present? && (calculated_total - total).abs > 0.01
      errors.add(:total, "does not match calculated total (#{calculated_total})")
    end

    # Validate discount
    if discount_amount.present? && discount_amount > items_total
      errors.add(:discount_amount, "cannot exceed items total")
    end

    # Validate minimum order
    if items_total < 10.00
      errors.add(:base, "Order must be at least $10.00")
    end
  end

  register_complex_validation :valid_payment do
    # Skip if not paid
    return unless is_paid?

    # Ensure payment details present
    if payment_method.blank?
      errors.add(:payment_method, "required for paid orders")
    end

    if paid_at.blank?
      errors.add(:paid_at, "required for paid orders")
    end

    # Ensure payment amount matches
    if payment_amount.present? && (payment_amount - total).abs > 0.01
      errors.add(:payment_amount, "must match order total")
    end
  end

  validatable do
    check :customer_id, presence: true
    check :payment_status, inclusion: { in: %w[pending paid cancelled] }

    check_complex :valid_order_totals
    check_complex :valid_payment
  end
end
```

**Output Explanation**: Complex validations encapsulate business logic and can be reused across the model. They execute in the instance context, so they can access all attributes, associations, and methods.

## Related Documentation

- [Main README](../../README.md#validatable) - Full Validatable documentation
- [Stateable Examples](08_stateable.md) - Use validations in state guards
- [Test File](../../test/better_model/validatable_test.rb) - Complete test coverage

---

[← Archivable Examples](06_archivable.md) | [Back to Examples Index](README.md) | [Next: Stateable Examples →](08_stateable.md)
