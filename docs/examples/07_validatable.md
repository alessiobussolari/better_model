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
    validate :title, presence: true
    validate :content, presence: true
    validate :title, length: { minimum: 5, maximum: 200 }
  end
end
```

## Example 1: Basic Validations

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Presence
    validate :title, :content, presence: true

    # Length
    validate :title, length: { minimum: 5, maximum: 200 }
    validate :content, length: { minimum: 10 }

    # Format
    validate :slug, format: { with: /\A[a-z0-9\-]+\z/ }

    # Numericality
    validate :view_count, numericality: { greater_than_or_equal_to: 0 }

    # Inclusion
    validate :status, inclusion: { in: %w[draft published archived] }
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

## Example 2: Conditional Validations

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Always required
    validate :title, presence: true

    # Conditional based on method
    validate_if :published? do
      validate :published_at, presence: true
      validate :content, presence: true, length: { minimum: 100 }
    end

    # Conditional based on status
    validate_if -> { status == "featured" } do
      validate :featured_image_url, presence: true
    end

    # Unless condition
    validate_unless :draft? do
      validate :reviewed_by_id, presence: true
    end
  end

  def published?
    status == "published"
  end

  def draft?
    status == "draft"
  end
end

# Draft article - minimal validation
draft = Article.new(title: "Draft", status: "draft")
draft.valid?
# => true (published_at not required for drafts)

# Published article - strict validation
published = Article.new(title: "Published", status: "published")
published.valid?
# => false (needs published_at and longer content)

published.published_at = Time.current
published.content = "A" * 100
published.valid?
# => true
```

**Output Explanation**: Conditional validations run only when conditions are met.

## Example 3: Validation Groups

Perfect for multi-step forms:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Step 1: Basic info
    validation_group :basic_info, [:title, :slug]
    validate :title, presence: true, length: { minimum: 5 }
    validate :slug, presence: true, format: { with: /\A[a-z0-9\-]+\z/ }

    # Step 2: Content
    validation_group :content_info, [:content, :excerpt]
    validate :content, presence: true, length: { minimum: 100 }
    validate :excerpt, length: { maximum: 300 }

    # Step 3: Publishing
    validation_group :publishing_info, [:published_at, :status]
    validate :published_at, presence: true
    validate :status, inclusion: { in: %w[draft published] }
  end
end

# Validate specific group
article = Article.new(title: "My Article")
article.valid_for_group?(:basic_info)
# => false (missing slug)

article.slug = "my-article"
article.valid_for_group?(:basic_info)
# => true

# Check multiple groups
article.valid_for_groups?([:basic_info, :content_info])
# => false (missing content)

# Full validation
article.valid?
# => Validates all fields
```

**Output Explanation**: Validation groups allow step-by-step validation without triggering all validations at once.

## Example 4: Cross-field Validation

Validate relationships between fields:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    # Ensure starts_at is before ends_at
    validate_order :starts_at, :before, :ends_at

    # With custom message
    validate_order :scheduled_at, :before, :expires_at,
      message: "Schedule must be before expiration"

    # Other comparators
    validate_order :min_views, :lt, :max_views
    validate_order :created_at, :lteq, :published_at
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

# Available comparators:
# :before, :after  - for dates/times
# :lt, :gt, :lteq, :gteq  - for numbers and dates
```

**Output Explanation**: `validate_order` ensures one field's value is ordered correctly relative to another.

## Example 5: Business Rules

Validate complex business logic:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    validate :title, :content, presence: true

    # Custom business rule validation
    validate_business_rule :published_article_must_be_complete
    validate_business_rule :featured_requires_image
    validate_business_rule :archived_must_have_reason
  end

  private

  def published_article_must_be_complete
    return unless status == "published"

    errors.add(:base, "Published articles must have content") if content.blank?
    errors.add(:base, "Published articles must have published_at") if published_at.blank?
    errors.add(:base, "Published articles must be reviewed") if reviewed_by_id.blank?
  end

  def featured_requires_image
    return unless featured?

    if featured_image_url.blank?
      errors.add(:featured_image_url, "is required for featured articles")
    end
  end

  def archived_must_have_reason
    return unless archived?

    if archive_reason.blank?
      errors.add(:archive_reason, "must be provided when archiving")
    end
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

**Output Explanation**: Business rule validations check complex logic that doesn't fit standard validators.

## Example 6: Multi-step Forms

Complete multi-step form example:

```ruby
class Article < ApplicationRecord
  include BetterModel

  attr_accessor :current_step

  validatable do
    # Step 1: Basic Information
    validation_group :step1, [:title, :slug, :category]
    validate :title, presence: true, length: { minimum: 5, maximum: 200 }
    validate :slug, presence: true, format: { with: /\A[a-z0-9\-]+\z/ }
    validate :category, presence: true

    # Step 2: Content
    validation_group :step2, [:content, :excerpt]
    validate :content, presence: true, length: { minimum: 100 }
    validate :excerpt, length: { maximum: 300 }

    # Step 3: Media
    validation_group :step3, [:featured_image_url]
    validate_if -> { featured? } do
      validate :featured_image_url, presence: true
    end

    # Step 4: Publishing
    validation_group :step4, [:status, :published_at]
    validate_if -> { status == "published" } do
      validate :published_at, presence: true
    end
  end

  def valid_for_current_step?
    case current_step
    when 1
      valid_for_group?(:step1)
    when 2
      valid_for_group?(:step2)
    when 3
      valid_for_group?(:step3)
    when 4
      valid_for_group?(:step4)
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
  validatable do
    validate_if :published? do
      validate :content, presence: true
    end

    validate_business_rule :content_quality
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
        expect(article.valid_for_group?(:step1)).to be false
        article.slug = "valid"
        expect(article.valid_for_group?(:step1)).to be true
      end
    end
  end
end
```

### 5. Provide Clear Error Messages
```ruby
validatable do
  validate_order :starts_at, :before, :ends_at,
    message: "Event must start before it ends"

  validate_business_rule :sensible_duration

  private

  def sensible_duration
    return if starts_at.blank? || ends_at.blank?

    duration = ends_at - starts_at
    if duration > 30.days
      errors.add(:ends_at, "Event cannot last more than 30 days")
    end
  end
end
```

## Related Documentation

- [Main README](../../README.md#validatable) - Full Validatable documentation
- [Stateable Examples](08_stateable.md) - Use validations in state guards
- [Test File](../../test/better_model/validatable_test.rb) - Complete test coverage

---

[← Archivable Examples](06_archivable.md) | [Back to Examples Index](README.md) | [Next: Stateable Examples →](08_stateable.md)
