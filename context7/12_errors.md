# 12. Errors - Comprehensive Error Handling System

Structured error handling with built-in Sentry integration for all BetterModel modules.

## Overview

- **36+ specialized error classes** across 10 modules
- **Automatic Sentry tagging** with error category, module, and context
- **Three-tier hierarchy** for flexible rescue patterns
- **Rich error attributes** for debugging and user feedback
- **Production-ready** with comprehensive error data structures

## Requirements

- Rails 8.0+
- Ruby 3.3+
- ActiveRecord 8.0+
- Sentry SDK (optional, for error monitoring)

---

## Error Hierarchy

### Structure

```
StandardError / ArgumentError
    └── BetterModel::Errors::BetterModelError (root)
        ├── Archivable::ArchivableError
        ├── Searchable::SearchableError
        ├── Stateable::StateableError
        └── ... (other modules)
            ├── ConfigurationError (ArgumentError)
            ├── NotEnabledError
            └── Module-specific errors
```

### Rescue Patterns

```ruby
# All BetterModel errors
rescue BetterModel::Errors::BetterModelError => e

# Module-specific errors
rescue BetterModel::Errors::Archivable::ArchivableError => e

# Specific error type
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
```

---

## Core Data Structures

Every BetterModel error provides three Sentry-compatible attributes:

### 1. Tags (Filterable Metadata)

```ruby
error.tags
# => {
#   error_category: "string",
#   module: "string",
#   # ... custom tags
# }
```

### 2. Context (High-Level Metadata)

```ruby
error.context
# => {
#   model_class: "ClassName",
#   # ... additional context
# }
```

### 3. Extra (Detailed Debug Data)

```ruby
error.extra
# => {
#   # All error-specific attributes
# }
```

---

## Common Error Types

### 1. ConfigurationError

**Modules**: All 10 modules
**Inheritance**: `ArgumentError`
**Use Case**: Configuration validation failures

#### Parameters

- `reason` (String, required): Description of configuration problem
- `model_class` (Class, optional): Model where error occurred
- `expected` (Object, optional): Expected value or type
- `provided` (Object, optional): Provided value or type

#### Example

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicable do
    predicates :nonexistent_field  # Field doesn't exist
  end
end

# Raises: BetterModel::Errors::Predicable::ConfigurationError
# Message: "Field 'nonexistent_field' does not exist on Article"
```

#### Handling

```ruby
rescue BetterModel::Errors::Predicable::ConfigurationError => e
  Rails.logger.error("Configuration error: #{e.reason}")
  Rails.logger.error("  Expected: #{e.expected}")
  Rails.logger.error("  Provided: #{e.provided}")

  render json: {
    error: "Invalid configuration",
    details: e.reason
  }, status: :bad_request
end
```

---

### 2. NotEnabledError

**Modules**: Archivable, Traceable, Validatable, Stateable
**Use Case**: Module methods called before module is enabled

#### Parameters

- `module_name` (String, required): Name of the module
- `method_called` (String/Symbol, optional): Method that was called
- `model_class` (Class, optional): Model where error occurred

#### Example

```ruby
class Article < ApplicationRecord
  include BetterModel
  # archivable NOT enabled
end

article = Article.first
article.archive!

# Raises: BetterModel::Errors::Archivable::NotEnabledError
# Message: "Archivable is not enabled. Add 'archivable do...end' to your model."
```

#### Handling

```ruby
rescue BetterModel::Errors::Archivable::NotEnabledError => e
  render json: {
    error: "Feature not available",
    module: e.module_name,
    enable_instructions: "Add '#{e.module_name.downcase} do...end' to your model"
  }, status: :not_implemented
end
```

---

## Module-Specific Errors

### Archivable Errors

#### AlreadyArchivedError

**Parameters**:
- `archived_at` (Time): When record was archived
- `model_class` (Class, optional)
- `model_id` (Integer, optional)

**Example**:
```ruby
article.archive!  # First time - OK
article.archive!  # Second time - raises error

rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
  # Return success for idempotent operation
  render json: { status: "already_archived", archived_at: e.archived_at }
end
```

#### NotArchivedError

**Parameters**:
- `method_called` (String/Symbol): Method that was called
- `model_class` (Class, optional)
- `model_id` (Integer, optional)

**Example**:
```ruby
article.unarchive!  # Article is not archived

rescue BetterModel::Errors::Archivable::NotArchivedError => e
  render json: { error: "Record is not archived" }, status: :bad_request
end
```

---

### Searchable Errors

#### InvalidPredicateError

**Parameters**:
- `predicate_scope` (Symbol): Invalid predicate used
- `value` (Object, optional): Value provided
- `available_predicates` (Array<Symbol>, optional): Valid predicates
- `model_class` (Class, optional)

**Example**:
```ruby
Article.search(title_unknown: "Test")

rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  render json: {
    error: "Invalid search parameter",
    invalid: e.predicate_scope,
    available: e.available_predicates
  }, status: :bad_request
end
```

#### InvalidOrderError

**Parameters**:
- `order_scope` (Symbol/String): Invalid order scope
- `available_sorts` (Array<Symbol>, optional): Valid sort scopes
- `model_class` (Class, optional)

**Example**:
```ruby
Article.search({}, orders: [:unknown_field_asc])

rescue BetterModel::Errors::Searchable::InvalidOrderError => e
  render json: {
    error: "Invalid sort parameter",
    available_sorts: e.available_sorts
  }, status: :bad_request
end
```

#### InvalidPaginationError

**Parameters**:
- `parameter_name` (String): Invalid parameter name
- `value` (Object, optional): Invalid value
- `valid_range` (Hash, optional): Valid range (`:min`, `:max`)
- `reason` (String, optional): Custom error reason

**Example**:
```ruby
Article.search({}, pagination: { page: -1 })

rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
  render json: {
    error: "Invalid pagination",
    parameter: e.parameter_name,
    value: e.value,
    valid_range: e.valid_range
  }, status: :bad_request
end
```

#### InvalidSecurityError

**Parameters**:
- `policy_name` (String): Violated policy name
- `violations` (Array<String>, optional): Violation descriptions
- `requested_value` (Object, optional): Value that caused violation
- `model_class` (Class, optional)

**Example**:
```ruby
Article.search({}, pagination: { per_page: 1000 })  # Max is 100

rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  Sentry.capture_exception(e)
  render json: { error: "Access denied" }, status: :forbidden
end
```

---

### Stateable Errors

#### InvalidTransitionError

**Parameters**:
- `event` (Symbol): Transition event attempted
- `from_state` (Symbol): Current state
- `to_state` (Symbol): Target state
- `model_class` (Class, optional)

**Example**:
```ruby
article = Article.create  # state: draft
article.publish!          # OK: draft -> published
article.publish!          # ERROR: already published

rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  render json: {
    error: "Invalid state transition",
    current_state: e.from_state,
    attempted_event: e.event
  }, status: :unprocessable_entity
end
```

#### CheckFailedError

**Parameters**:
- `event` (Symbol): Transition event
- `check_description` (String, optional): Description of failed check
- `check_type` (String, optional): Check type ("predicate", "method", "block")
- `current_state` (Symbol, optional): Current state
- `model_class` (Class, optional)

**Example**:
```ruby
class Order < ApplicationRecord
  stateable do
    transition :confirm, from: :pending, to: :confirmed do
      check { items.any? }  # Check fails if no items
    end
  end
end

order = Order.create  # No items
order.confirm!

rescue BetterModel::Errors::Stateable::CheckFailedError => e
  render json: {
    error: "Cannot confirm order",
    reason: "Order must have at least one item"
  }, status: :unprocessable_entity
end
```

#### ValidationFailedError

**Parameters**:
- `event` (Symbol): Transition event
- `errors_object` (ActiveModel::Errors): Errors from validation
- `current_state` (Symbol, optional): Current state
- `target_state` (Symbol, optional): Target state
- `model_class` (Class, optional)

**Example**:
```ruby
class Article < ApplicationRecord
  stateable do
    transition :publish, from: :draft, to: :published do
      validate do
        errors.add(:base, "Title required") if title.blank?
      end
    end
  end
end

article = Article.create(title: "")
article.publish!

rescue BetterModel::Errors::Stateable::ValidationFailedError => e
  render json: {
    error: "Validation failed",
    errors: e.errors_object.full_messages
  }, status: :unprocessable_entity
end
```

#### InvalidStateError

**Parameters**:
- `state` (Symbol): Invalid state
- `available_states` (Array<Symbol>, optional): Valid states
- `model_class` (Class, optional)

**Example**:
```ruby
article.state = :unknown_state

rescue BetterModel::Errors::Stateable::InvalidStateError => e
  render json: {
    error: "Invalid state",
    invalid_state: e.state,
    available_states: e.available_states
  }, status: :bad_request
end
```

---

## Sentry Integration

### Basic Setup

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
end

# application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from BetterModel::Errors::BetterModelError do |exception|
    Sentry.capture_exception(exception) do |scope|
      scope.set_context("error_details", exception.context)
      scope.set_tags(exception.tags)
      scope.set_extras(exception.extra)

      scope.set_user(id: current_user&.id) if current_user
    end

    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
```

### Production Error Handling

```ruby
class ArticlesController < ApplicationController
  def search
    @articles = Article.search(search_params, **search_options)
    render json: @articles
  rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
    capture_and_render_error(e, :bad_request)
  rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
    capture_and_render_security_error(e)
  end

  private

  def capture_and_render_error(error, status)
    Sentry.capture_exception(error) do |scope|
      scope.set_level(:warning)
      scope.set_tags(error.tags.merge(user_id: current_user&.id))
      scope.set_context("search", search_params.to_h)
    end

    render json: { error: error.message }, status: status
  end

  def capture_and_render_security_error(error)
    Sentry.capture_exception(error) do |scope|
      scope.set_level(:error)
      scope.set_fingerprint([
        "security-violation",
        error.policy_name,
        current_user&.id
      ])
    end

    render json: { error: "Access denied" }, status: :forbidden
  end
end
```

### Error Grouping

```ruby
# Group by error category and module
Sentry.capture_exception(error) do |scope|
  scope.set_fingerprint([
    error.tags[:error_category],
    error.tags[:module]
  ])
end

# Group by model and error type
Sentry.capture_exception(error) do |scope|
  scope.set_fingerprint([
    error.context[:model_class],
    error.class.name
  ])
end
```

---

## Complete Examples

### Example 1: Controller with Multiple Error Types

```ruby
class OrdersController < ApplicationController
  def confirm
    order = Order.find(params[:id])
    order.confirm!

    render json: order, status: :ok
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    render_transition_error(e)
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    render_check_error(e)
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    render_validation_error(e)
  end

  private

  def render_transition_error(error)
    render json: {
      error: "Cannot perform action",
      current_state: error.from_state,
      message: "Order cannot be confirmed in #{error.from_state} state"
    }, status: :unprocessable_entity
  end

  def render_check_error(error)
    render json: {
      error: "Requirements not met",
      check_failed: error.check_description,
      current_state: error.current_state
    }, status: :unprocessable_entity
  end

  def render_validation_error(error)
    render json: {
      error: "Validation failed",
      errors: error.errors_object.full_messages,
      error_details: error.errors_object.details
    }, status: :unprocessable_entity
  end
end
```

### Example 2: Service Object with Error Handling

```ruby
class ArticlePublishService
  Result = Struct.new(:success, :article, :error, :message, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(article, published_by:)
    @article = article
    @published_by = published_by
  end

  def call
    validate_permissions!
    @article.publish!(by: @published_by)
    notify_subscribers

    Result.new(success: true, article: @article)
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    Result.new(
      success: false,
      error: :check_failed,
      message: friendly_check_message(e)
    )
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    Result.new(
      success: false,
      error: :validation_failed,
      message: e.errors_object.full_messages.join(", ")
    )
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    Result.new(
      success: false,
      error: :invalid_state,
      message: "Article cannot be published in #{e.from_state} state"
    )
  end

  private

  def validate_permissions!
    return if @published_by.can_publish?(@article)

    raise BetterModel::Errors::Stateable::CheckFailedError.new(
      event: :publish,
      check_description: "User lacks publish permissions",
      current_state: @article.state
    )
  end

  def friendly_check_message(error)
    case error.check_description
    when /content/ then "Article must have content"
    when /images/ then "Article must have at least one image"
    when /permissions/ then "You don't have permission to publish"
    else "Article requirements not met"
    end
  end

  def notify_subscribers
    ArticlePublishedNotifier.notify(@article)
  end
end

# Usage
result = ArticlePublishService.new(article, published_by: current_user).call

if result.success?
  render json: result.article, status: :ok
else
  render json: { error: result.error, message: result.message }, status: :unprocessable_entity
end
```

### Example 3: Background Job Error Handling

```ruby
class ProcessArticleJob < ApplicationJob
  queue_as :default

  # Retry checks - they might pass later
  retry_on BetterModel::Errors::Stateable::CheckFailedError,
           wait: 5.minutes,
           attempts: 3

  def perform(article_id)
    article = Article.find(article_id)
    article.publish!

    NotifySubscribersJob.perform_later(article_id)
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    # Don't retry - article in wrong state
    log_error(article_id, "Invalid state for publish", e)
    notify_admin_of_failure(article, e)
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    # Don't retry - needs manual fix
    log_error(article_id, "Validation failed", e)
    create_admin_notification(article, e)
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    # Will retry automatically
    log_warning(article_id, "Checks failed, will retry", e)
    raise
  end

  private

  def log_error(article_id, message, error)
    Rails.logger.error("Article #{article_id}: #{message}")
    Rails.logger.error("  Error: #{error.message}")

    Sentry.capture_exception(error) do |scope|
      scope.set_context("job", {
        job_class: self.class.name,
        article_id: article_id
      })
    end
  end

  def log_warning(article_id, message, error)
    Rails.logger.warn("Article #{article_id}: #{message}")
    Rails.logger.warn("  Reason: #{error.check_description}")
  end

  def notify_admin_of_failure(article, error)
    AdminMailer.article_publish_failed(article, error).deliver_later
  end

  def create_admin_notification(article, error)
    AdminNotification.create!(
      notification_type: :article_validation_failed,
      article_id: article.id,
      details: error.errors_object.full_messages
    )
  end
end
```

### Example 4: API Error Response (JSON:API Format)

```ruby
class Api::V1::BaseController < ApplicationController
  rescue_from BetterModel::Errors::BetterModelError, with: :render_better_model_error

  private

  def render_better_model_error(error)
    render json: {
      errors: [
        {
          id: SecureRandom.uuid,
          status: error_status_code(error).to_s,
          code: error.tags[:error_category],
          title: error.class.name.demodulize.titleize,
          detail: error.message,
          source: { pointer: request.path },
          meta: {
            module: error.tags[:module],
            context: error.context
          }
        }
      ]
    }, status: error_status_code(error)
  end

  def error_status_code(error)
    case error
    when BetterModel::Errors::Searchable::InvalidPredicateError,
         BetterModel::Errors::Searchable::InvalidOrderError,
         BetterModel::Errors::Searchable::InvalidPaginationError
      :bad_request
    when BetterModel::Errors::Searchable::InvalidSecurityError
      :forbidden
    when BetterModel::Errors::Stateable::InvalidTransitionError,
         BetterModel::Errors::Stateable::CheckFailedError,
         BetterModel::Errors::Stateable::ValidationFailedError
      :unprocessable_entity
    else
      :internal_server_error
    end
  end
end
```

---

## Testing Error Handling

### RSpec Example

```ruby
RSpec.describe Article, type: :model do
  describe "#publish!" do
    it "raises InvalidTransitionError when already published" do
      article = create(:article, :published)

      expect { article.publish! }.to raise_error(
        BetterModel::Errors::Stateable::InvalidTransitionError
      ) do |error|
        expect(error.event).to eq(:publish)
        expect(error.from_state).to eq(:published)
        expect(error.tags[:error_category]).to eq("transition")
      end
    end

    it "raises CheckFailedError with empty content" do
      article = create(:article, content: nil)

      expect { article.publish! }.to raise_error(
        BetterModel::Errors::Stateable::CheckFailedError
      ) do |error|
        expect(error.check_description).to include("content")
        expect(error.current_state).to eq(:draft)
      end
    end
  end
end
```

### Controller Test Example

```ruby
RSpec.describe ArticlesController, type: :controller do
  describe "POST #publish" do
    context "when transition fails" do
      it "returns unprocessable_entity with error details" do
        article = create(:article, :published)

        post :publish, params: { id: article.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid state transition")
        expect(json["current_state"]).to eq("published")
      end
    end
  end
end
```

---

## Best Practices

1. **Rescue Specific Errors**
   ```ruby
   # Good
   rescue BetterModel::Errors::Stateable::InvalidTransitionError => e

   # Avoid
   rescue StandardError => e
   ```

2. **Use Error Attributes**
   ```ruby
   # Access rich error data
   error.tags[:error_category]
   error.context[:model_class]
   error.extra  # All error-specific details
   ```

3. **Log Error Context**
   ```ruby
   Rails.logger.warn(
     "Invalid predicate: #{e.predicate_scope}",
     { available: e.available_predicates }
   )
   ```

4. **Capture in Sentry with Full Context**
   ```ruby
   Sentry.capture_exception(e) do |scope|
     scope.set_context("error_details", e.context)
     scope.set_tags(e.tags.merge(user_id: current_user&.id))
     scope.set_extras(e.extra)
   end
   ```

5. **Provide User-Friendly Messages**
   ```ruby
   # Transform technical errors to user-friendly messages
   case error
   when BetterModel::Errors::Stateable::CheckFailedError
     "Requirements not met. Please review your order."
   end
   ```

6. **Never Expose Sensitive Data**
   ```ruby
   # Bad: exposing backtrace and internal details
   render json: { error: e.message, backtrace: e.backtrace }

   # Good: filtered response
   render json: { error: e.message, category: e.tags[:error_category] }
   ```

7. **Handle Errors at the Right Level**
   - Configuration errors: Fail fast during initialization
   - Validation errors: Return to user with details
   - Security errors: Log extensively, return generic message
   - State transition errors: Provide state-specific feedback

8. **Don't Retry Validation Errors**
   ```ruby
   # Validation errors need manual fixes, don't retry
   rescue BetterModel::Errors::Stateable::ValidationFailedError => e
     # Handle, don't retry
   ```

9. **Make Operations Idempotent Where Possible**
   ```ruby
   rescue BetterModel::Errors::Archivable::AlreadyArchivedError
     # Return success - operation already completed
     render json: { status: "archived" }, status: :ok
   end
   ```

10. **Test Error Scenarios**
    ```ruby
    it "handles errors gracefully" do
      expect { invalid_operation }.to raise_error(ExpectedError)
    end
    ```

---

## Error Catalog Summary

| Module | Error Types | Key Use Cases |
|--------|-------------|---------------|
| **All Modules** | ConfigurationError | Invalid configuration |
| **Archivable** | AlreadyArchivedError, NotArchivedError | Archive state validation |
| **Searchable** | InvalidPredicateError, InvalidOrderError, InvalidPaginationError, InvalidSecurityError | Search validation, security |
| **Stateable** | InvalidTransitionError, CheckFailedError, ValidationFailedError, InvalidStateError | State machine operations |
| **Traceable** | NotEnabledError | Module not enabled |
| **Validatable** | NotEnabledError | Module not enabled |

---

## Integration with Other Features

### With Statusable

```ruby
class Order < ApplicationRecord
  include BetterModel

  statusable do
    is :ready_to_ship, -> { items.present? && address.present? }
  end

  stateable do
    transition :ship, from: :confirmed, to: :shipped do
      check if: :is_ready_to_ship?  # Uses Statusable predicate
    end
  end
end

# CheckFailedError will reference the Statusable predicate
rescue BetterModel::Errors::Stateable::CheckFailedError => e
  e.check_type  # => "predicate"
  e.check_description  # => "predicate check: is_ready_to_ship?"
end
```

### With Traceable

```ruby
class Article < ApplicationRecord
  include BetterModel

  traceable do
    track :title, :content
  end

  stateable do
    transition :publish, from: :draft, to: :published do
      after_transition { track_change("Published article") }
    end
  end
end

# Errors during transitions are tracked
rescue BetterModel::Errors::Stateable::ValidationFailedError => e
  # Transition failure is logged in traceable history
  article.track_change("Publish failed: #{e.message}", by: current_user)
end
```

---

## Related Documentation

- [docs/errors.md](../docs/errors.md) - Comprehensive error documentation
- [docs/examples/15_error_handling.md](../docs/examples/15_error_handling.md) - Practical examples
- [ERROR_SYSTEM_GUIDELINES.md](../ERROR_SYSTEM_GUIDELINES.md) - Developer guidelines
