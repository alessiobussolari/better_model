# Error System 🚨

Comprehensive guide to BetterModel's error handling system with Sentry integration.

## Table of Contents

- [Overview](#overview)
- [Error Hierarchy](#error-hierarchy)
- [Common Error Types](#common-error-types)
  - [ConfigurationError](#configurationerror)
  - [NotEnabledError](#notenablederror)
- [Module-Specific Errors](#module-specific-errors)
  - [Archivable Errors](#archivable-errors)
  - [Searchable Errors](#searchable-errors)
  - [Stateable Errors](#stateable-errors)
  - [Other Module Errors](#other-module-errors)
- [Sentry Integration](#sentry-integration)
  - [Basic Setup](#basic-setup)
  - [Error Data Structures](#error-data-structures)
  - [Production Error Handling](#production-error-handling)
  - [Error Grouping Strategies](#error-grouping-strategies)
- [Error Handling Patterns](#error-handling-patterns)
  - [Controller Error Handling](#controller-error-handling)
  - [Service Object Patterns](#service-object-patterns)
  - [API Error Responses](#api-error-responses)
  - [Background Job Handling](#background-job-handling)
- [Testing Errors](#testing-errors)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

BetterModel includes a sophisticated error system designed for:

- 🎯 **Precise Error Identification**: Specific error classes for each failure scenario
- 📊 **Built-in Sentry Integration**: Structured error data ready for monitoring
- 🔍 **Rich Context**: Every error includes model class, parameters, and debug info
- 🏗️ **Hierarchical Organization**: Three-tier structure for easy rescue patterns
- 📝 **Self-Documenting**: Descriptive messages with helpful suggestions

### Key Features

- **36+ specialized error classes** across 10 modules
- **Automatic Sentry tagging** with error category, module, and context
- **Thread-safe** error handling throughout
- **Production-ready** with comprehensive error data structures
- **Testing-friendly** with accessible error attributes

---

## Error Hierarchy

BetterModel uses a three-tier error hierarchy:

```
StandardError / ArgumentError
    │
    └── BetterModel::Errors::BetterModelError (root)
        │
        ├── Archivable::ArchivableError
        │   ├── ConfigurationError
        │   ├── NotEnabledError
        │   ├── AlreadyArchivedError
        │   └── NotArchivedError
        │
        ├── Searchable::SearchableError
        │   ├── ConfigurationError
        │   ├── InvalidPredicateError
        │   ├── InvalidOrderError
        │   ├── InvalidPaginationError
        │   └── InvalidSecurityError
        │
        ├── Stateable::StateableError
        │   ├── ConfigurationError
        │   ├── NotEnabledError
        │   ├── InvalidTransitionError
        │   ├── CheckFailedError
        │   ├── ValidationFailedError
        │   └── InvalidStateError
        │
        └── ... (other modules)
```

### Rescue Strategies

The hierarchy allows flexible rescue patterns:

```ruby
# Rescue all BetterModel errors
begin
  article.publish!
rescue BetterModel::Errors::BetterModelError => e
  handle_better_model_error(e)
end

# Rescue all errors from a specific module
begin
  article.archive!
rescue BetterModel::Errors::Archivable::ArchivableError => e
  handle_archivable_error(e)
end

# Rescue specific error type
begin
  Article.search(title_unknown: "test")
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  render json: { error: e.message }, status: :bad_request
end
```

---

## Common Error Types

### ConfigurationError

Raised when module configuration is invalid. Present in **all 10 modules**.

**Inheritance**: `ArgumentError` (not `BetterModelError`)

#### Parameters

- `reason` (String, required): Description of the configuration problem
- `model_class` (Class, optional): Model where error occurred
- `expected` (Object, optional): Expected value or type
- `provided` (Object, optional): Provided value or type

#### Example

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Invalid configuration - field doesn't exist
  predicable do
    predicates :nonexistent_field
  end
end

# Raises:
# BetterModel::Errors::Predicable::ConfigurationError:
#   Field 'nonexistent_field' does not exist on Article
#   (expected: existing column) (provided: :nonexistent_field)
```

#### Handling

```ruby
begin
  Article.search(title_eq: "Test")
rescue BetterModel::Errors::Predicable::ConfigurationError => e
  Rails.logger.error("Configuration error: #{e.reason}")
  Rails.logger.error("  Expected: #{e.expected}")
  Rails.logger.error("  Provided: #{e.provided}")

  # Sentry integration
  Sentry.capture_exception(e) do |scope|
    scope.set_context("configuration", e.context)
    scope.set_tags(e.tags)
  end
end
```

#### Sentry Data

```ruby
error.tags
# => {
#   error_category: "configuration",
#   module: "predicable"
# }

error.context
# => {
#   model_class: "Article"
# }

error.extra
# => {
#   reason: "Field 'nonexistent_field' does not exist",
#   expected: "existing column",
#   provided: :nonexistent_field
# }
```

---

### NotEnabledError

Raised when module methods are called but the module is not enabled on the model.

**Modules**: Archivable, Traceable, Validatable, Stateable

#### Parameters

- `module_name` (String, required): Name of the module
- `method_called` (String/Symbol, optional): Method that was called
- `model_class` (Class, optional): Model where error occurred

#### Example

```ruby
class Article < ApplicationRecord
  include BetterModel
  # Note: archivable NOT enabled
end

article = Article.first
article.archive!

# Raises:
# BetterModel::Errors::Archivable::NotEnabledError:
#   Archivable is not enabled. Add 'archivable do...end' to your model.
#   (called from: archive!)
```

#### Handling

```ruby
begin
  article.archive!
rescue BetterModel::Errors::Archivable::NotEnabledError => e
  Rails.logger.warn("Module not enabled: #{e.module_name}")
  Rails.logger.warn("  Method: #{e.method_called}")
  Rails.logger.warn("  Model: #{e.model_class}")

  # Provide helpful response
  render json: {
    error: "Feature not available",
    message: "The archiving feature is not enabled for #{e.model_class}",
    enable_instructions: "Add 'archivable do...end' to your #{e.model_class} model"
  }, status: :not_implemented
end
```

#### Prevention

Enable the module before calling its methods:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    # Configuration...
  end
end
```

---

## Module-Specific Errors

### Archivable Errors

#### AlreadyArchivedError

Raised when attempting to archive a record that is already archived.

**Parameters**:
- `archived_at` (Time, required): When the record was archived
- `model_class` (Class, optional): Model class
- `model_id` (Integer, optional): Record ID

**Example**:

```ruby
article = Article.find(1)
article.archive!  # First time - OK
article.archive!  # Second time - raises error

# Raises:
# BetterModel::Errors::Archivable::AlreadyArchivedError:
#   Record is already archived (archived at: 2024-01-15 10:30:00 UTC)
```

**Handling**:

```ruby
begin
  article.archive!
rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
  Rails.logger.info("Record already archived at #{e.archived_at}")

  # Return success anyway (idempotent operation)
  render json: {
    status: "already_archived",
    archived_at: e.archived_at
  }, status: :ok
end
```

#### NotArchivedError

Raised when attempting an operation that requires an archived record on a non-archived record.

**Parameters**:
- `method_called` (String/Symbol, required): Method that was called
- `model_class` (Class, optional): Model class
- `model_id` (Integer, optional): Record ID

**Example**:

```ruby
article = Article.find(1)
article.unarchive!  # Article is not archived

# Raises:
# BetterModel::Errors::Archivable::NotArchivedError:
#   Record is not archived (called from: unarchive!)
```

---

### Searchable Errors

#### InvalidPredicateError

Raised when an invalid search predicate is used.

**Parameters**:
- `predicate_scope` (Symbol, required): Invalid predicate that was used
- `value` (Object, optional): Value that was provided
- `available_predicates` (Array<Symbol>, optional): List of valid predicates
- `model_class` (Class, optional): Model class

**Example**:

```ruby
# Article has predicable field :title
Article.search(title_unknown: "Test")

# Raises:
# BetterModel::Errors::Searchable::InvalidPredicateError:
#   Invalid predicate scope: :title_unknown.
#   Available predicable scopes: title_eq, title_not_eq, title_matches, ...
```

**Handling**:

```ruby
def search
  results = Article.search(search_params)
  render json: results
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  render json: {
    error: "Invalid search parameter",
    invalid_predicate: e.predicate_scope,
    valid_predicates: e.available_predicates,
    hint: "Use one of the available predicates for searching"
  }, status: :bad_request
end
```

#### InvalidOrderError

Raised when an invalid sort scope is requested.

**Parameters**:
- `order_scope` (Symbol/String, required): Invalid order scope
- `available_sorts` (Array<Symbol>, optional): List of valid sort scopes
- `model_class` (Class, optional): Model class

**Example**:

```ruby
Article.search({}, orders: [:unknown_field_asc])

# Raises:
# BetterModel::Errors::Searchable::InvalidOrderError:
#   Invalid order scope: :unknown_field_asc.
#   Available sortable scopes: created_at_asc, created_at_desc, title_asc, ...
```

#### InvalidPaginationError

Raised when invalid pagination parameters are provided.

**Parameters**:
- `parameter_name` (String, required): Name of invalid parameter (e.g., "page", "per_page")
- `value` (Object, optional): Invalid value provided
- `valid_range` (Hash, optional): Valid range (`:min` and `:max` keys)
- `reason` (String, optional): Custom error reason

**Example**:

```ruby
Article.search({}, pagination: { page: -1 })

# Raises:
# BetterModel::Errors::Searchable::InvalidPaginationError:
#   Invalid pagination parameter 'page': -1 (valid range: 1..1000)
```

#### InvalidSecurityError

Raised when a security policy is violated in a search query.

**Parameters**:
- `policy_name` (String, required): Name of violated policy
- `violations` (Array<String>, optional): List of violation descriptions
- `requested_value` (Object, optional): Value that caused violation
- `model_class` (Class, optional): Model class

**Example**:

```ruby
# Security policy: max 100 results per page
Article.search({}, pagination: { per_page: 1000 })

# Raises:
# BetterModel::Errors::Searchable::InvalidSecurityError:
#   Security policy violation: max_per_page.
#   Requested per_page exceeds maximum allowed (1000 > 100)
```

**Handling**:

```ruby
begin
  results = Article.search(params[:filters], pagination: params[:pagination])
rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  Sentry.capture_exception(e) do |scope|
    scope.set_level(:warning)
    scope.set_tags(
      policy_violated: e.policy_name,
      user_id: current_user&.id
    )
  end

  render json: {
    error: "Security policy violation",
    policy: e.policy_name,
    violations: e.violations
  }, status: :forbidden
end
```

---

### Stateable Errors

The most complex error set due to state machine operations.

#### InvalidTransitionError

Raised when an invalid state transition is attempted.

**Parameters**:
- `event` (Symbol, required): Transition event attempted
- `from_state` (Symbol, required): Current state
- `to_state` (Symbol, required): Target state
- `model_class` (Class, optional): Model class

**Example**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    state :draft, initial: true
    state :published
    state :archived

    # Only draft -> published transition defined
    transition :publish, from: :draft, to: :published
  end
end

article = Article.create  # state: draft
article.publish!          # OK: draft -> published
article.publish!          # ERROR: already published

# Raises:
# BetterModel::Errors::Stateable::InvalidTransitionError:
#   Cannot transition from :published to :published via :publish
```

**Handling**:

```ruby
begin
  article.publish!
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  Rails.logger.warn("Invalid transition: #{e.event}")
  Rails.logger.warn("  From: #{e.from_state}")
  Rails.logger.warn("  To: #{e.to_state}")

  render json: {
    error: "Invalid state transition",
    current_state: e.from_state,
    attempted_event: e.event,
    message: "Cannot publish article in #{e.from_state} state"
  }, status: :unprocessable_entity
end
```

#### CheckFailedError

Raised when a transition check (guard) fails.

**Parameters**:
- `event` (Symbol, required): Transition event
- `check_description` (String, optional): Description of failed check
- `check_type` (String, optional): Type of check ("predicate", "method", "block")
- `current_state` (Symbol, optional): Current state
- `model_class` (Class, optional): Model class

**Example**:

```ruby
class Order < ApplicationRecord
  stateable do
    state :pending, initial: true
    state :confirmed

    transition :confirm, from: :pending, to: :confirmed do
      check { items.any? }  # Check fails if no items
      check :payment_valid?
    end
  end

  def payment_valid?
    payment_method.present? && payment_authorized?
  end
end

order = Order.create  # No items
order.confirm!

# Raises:
# BetterModel::Errors::Stateable::CheckFailedError:
#   Check failed for transition :confirm: block check
```

**Handling**:

```ruby
begin
  order.confirm!
rescue BetterModel::Errors::Stateable::CheckFailedError => e
  Rails.logger.info("Transition check failed")
  Rails.logger.info("  Event: #{e.event}")
  Rails.logger.info("  Check: #{e.check_description}")
  Rails.logger.info("  Type: #{e.check_type}")

  # Provide user-friendly message
  render json: {
    error: "Cannot confirm order",
    reason: case e.check_description
            when /items/
              "Order must have at least one item"
            when /payment/
              "Payment information is invalid"
            else
              "Order requirements not met"
            end,
    current_state: e.current_state
  }, status: :unprocessable_entity
end
```

#### ValidationFailedError

Raised when ActiveModel validation fails during a state transition.

**Parameters**:
- `event` (Symbol, required): Transition event
- `errors_object` (ActiveModel::Errors, required): Errors from validation
- `current_state` (Symbol, optional): Current state before transition
- `target_state` (Symbol, optional): Target state for transition
- `model_class` (Class, optional): Model class

**Example**:

```ruby
class Article < ApplicationRecord
  stateable do
    state :draft, initial: true
    state :published

    transition :publish, from: :draft, to: :published do
      validate do
        errors.add(:base, "Title required") if title.blank?
        errors.add(:base, "Content required") if content.blank?
      end
    end
  end
end

article = Article.create(title: "", content: "")
article.publish!

# Raises:
# BetterModel::Errors::Stateable::ValidationFailedError:
#   Validation failed for transition :publish: Title required, Content required
```

**Handling**:

```ruby
begin
  article.publish!
rescue BetterModel::Errors::Stateable::ValidationFailedError => e
  # Access full ActiveModel errors object
  error_messages = e.errors_object.full_messages
  error_details = e.errors_object.details

  render json: {
    error: "Validation failed",
    transition: e.event,
    from_state: e.current_state,
    to_state: e.target_state,
    errors: error_messages,
    error_details: error_details
  }, status: :unprocessable_entity
end
```

#### InvalidStateError

Raised when an invalid state is referenced.

**Parameters**:
- `state` (Symbol, required): Invalid state
- `available_states` (Array<Symbol>, optional): List of valid states
- `model_class` (Class, optional): Model class

**Example**:

```ruby
article = Article.new
article.state = :unknown_state
article.save!

# Raises:
# BetterModel::Errors::Stateable::InvalidStateError:
#   Invalid state: :unknown_state.
#   Available states: draft, published, archived
```

---

### Other Module Errors

Most other modules have simpler error sets:

#### Permissible
- `ConfigurationError`

#### Predicable
- `ConfigurationError`

#### Sortable
- `ConfigurationError`

#### Statusable
- `ConfigurationError`

#### Taggable
- `ConfigurationError`

#### Traceable
- `ConfigurationError`
- `NotEnabledError`

#### Validatable
- `ConfigurationError`
- `NotEnabledError`

---

## Sentry Integration

All BetterModel errors include comprehensive Sentry-compatible data structures.

### Basic Setup

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
end

# application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from BetterModel::Errors::BetterModelError do |exception|
    capture_better_model_error(exception)
    render_error_response(exception)
  end

  private

  def capture_better_model_error(exception)
    Sentry.capture_exception(exception) do |scope|
      # Add error-specific context
      scope.set_context("error_details", exception.context)

      # Add tags for filtering/grouping
      scope.set_tags(exception.tags)

      # Add detailed debug data
      scope.set_extras(exception.extra)

      # Add user context
      scope.set_user(
        id: current_user&.id,
        email: current_user&.email
      ) if current_user

      # Add request context
      scope.set_context("request", {
        url: request.url,
        method: request.method,
        params: request.params.except(:password, :password_confirmation)
      })
    end
  end
end
```

### Error Data Structures

Every BetterModel error provides three Sentry-compatible data structures:

#### 1. Tags (Filterable Metadata)

Used for filtering and grouping errors in Sentry.

```ruby
error.tags
# => {
#   error_category: "invalid_predicate",
#   module: "searchable",
#   predicate: "title_unknown"
# }
```

**Common Tag Keys**:
- `error_category`: Type of error (always present)
- `module`: Module name (auto-extracted)
- `event`: For state transitions
- `from_state`, `to_state`: For transitions
- `predicate`: For predicate errors
- `policy`: For security errors

#### 2. Context (High-Level Metadata)

Structured contextual information.

```ruby
error.context
# => {
#   model_class: "Article",
#   current_state: :draft
# }
```

#### 3. Extra (Detailed Debug Data)

All error-specific detailed information.

```ruby
error.extra
# => {
#   predicate_scope: :title_unknown,
#   value: "Test",
#   available_predicates: [:title_eq, :title_not_eq, ...]
# }
```

### Production Error Handling

```ruby
class ArticlesController < ApplicationController
  def search
    @articles = Article.search(search_params, **search_options)
    render json: @articles
  rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
    handle_invalid_predicate(e)
  rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
    handle_security_violation(e)
  rescue BetterModel::Errors::BetterModelError => e
    handle_generic_error(e)
  end

  private

  def handle_invalid_predicate(error)
    # Log for debugging
    Rails.logger.warn("Invalid predicate: #{error.predicate_scope}")

    # Capture in Sentry with warning level
    Sentry.capture_exception(error) do |scope|
      scope.set_level(:warning)
      scope.set_context("search_params", search_params.to_h)
      scope.set_tags(error.tags.merge(
        user_id: current_user&.id,
        source: "search_endpoint"
      ))
    end

    # Return user-friendly error
    render json: {
      error: "Invalid search parameter",
      message: error.message,
      available_predicates: error.available_predicates
    }, status: :bad_request
  end

  def handle_security_violation(error)
    # Log security violation
    Rails.logger.error("Security violation: #{error.policy_name}")

    # Capture in Sentry with high priority
    Sentry.capture_exception(error) do |scope|
      scope.set_level(:error)
      scope.set_fingerprint([
        "security-violation",
        error.policy_name,
        current_user&.id
      ])
      scope.set_tags(error.tags.merge(
        user_id: current_user&.id,
        ip_address: request.remote_ip
      ))
    end

    # Return error without exposing details
    render json: {
      error: "Request not allowed"
    }, status: :forbidden
  end

  def handle_generic_error(error)
    Rails.logger.error("BetterModel error: #{error.class}")

    Sentry.capture_exception(error) do |scope|
      scope.set_context("error_details", error.context)
      scope.set_tags(error.tags)
      scope.set_extras(error.extra)
    end

    render json: {
      error: "An error occurred",
      message: error.message
    }, status: :unprocessable_entity
  end
end
```

### Error Grouping Strategies

#### By Error Category

```ruby
# Sentry will group by error_category tag
Sentry.capture_exception(error) do |scope|
  scope.set_fingerprint([
    error.tags[:error_category],
    error.tags[:module]
  ])
end
```

#### By Model and Error Type

```ruby
Sentry.capture_exception(error) do |scope|
  scope.set_fingerprint([
    error.context[:model_class],
    error.class.name
  ])
end
```

#### By User Action

```ruby
Sentry.capture_exception(error) do |scope|
  scope.set_fingerprint([
    controller_name,
    action_name,
    error.tags[:error_category]
  ])
end
```

---

## Error Handling Patterns

### Controller Error Handling

#### Global Error Handler

```ruby
class ApplicationController < ActionController::Base
  rescue_from BetterModel::Errors::BetterModelError, with: :handle_better_model_error
  rescue_from BetterModel::Errors::Searchable::InvalidSecurityError, with: :handle_security_error

  private

  def handle_better_model_error(error)
    log_error(error)
    capture_error(error)

    render json: {
      error: error.class.name.demodulize,
      message: error.message,
      details: error_details(error)
    }, status: error_status_code(error)
  end

  def handle_security_error(error)
    log_security_violation(error)
    capture_error(error, level: :error)

    render json: { error: "Access denied" }, status: :forbidden
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
    when ArgumentError
      :bad_request
    else
      :internal_server_error
    end
  end

  def error_details(error)
    {
      category: error.tags[:error_category],
      module: error.tags[:module],
      context: error.context
    }
  end
end
```

#### Specific Controller Actions

```ruby
class OrdersController < ApplicationController
  def confirm
    @order = Order.find(params[:id])
    @order.confirm!

    render json: @order, status: :ok
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    render json: {
      error: "Cannot confirm order",
      reason: friendly_check_message(e),
      current_state: e.current_state
    }, status: :unprocessable_entity
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    render json: {
      error: "Validation failed",
      errors: e.errors_object.full_messages
    }, status: :unprocessable_entity
  end

  private

  def friendly_check_message(error)
    case error.check_description
    when /items/
      "Order must contain at least one item"
    when /payment/
      "Valid payment method required"
    when /address/
      "Shipping address required"
    else
      "Order requirements not met"
    end
  end
end
```

### Service Object Patterns

```ruby
class ArticlePublishService
  def initialize(article, published_by:)
    @article = article
    @published_by = published_by
  end

  def call
    validate_can_publish!
    publish_article
    notify_subscribers

    Success.new(article: @article)
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    Failure.new(error: :check_failed, message: e.message, details: error_details(e))
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    Failure.new(error: :validation_failed, errors: e.errors_object, details: error_details(e))
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    Failure.new(error: :invalid_state, message: e.message, details: error_details(e))
  end

  private

  def validate_can_publish!
    unless @published_by.can_publish?(@article)
      raise BetterModel::Errors::Stateable::CheckFailedError.new(
        event: :publish,
        check_description: "User does not have publish permissions",
        current_state: @article.state,
        model_class: @article.class
      )
    end
  end

  def publish_article
    @article.publish!(by: @published_by)
  end

  def notify_subscribers
    ArticlePublishedNotifier.notify(@article)
  end

  def error_details(error)
    {
      category: error.tags[:error_category],
      context: error.context,
      extra: error.extra
    }
  end

  class Success
    attr_reader :article

    def initialize(article:)
      @article = article
    end

    def success?
      true
    end
  end

  class Failure
    attr_reader :error, :message, :errors, :details

    def initialize(error:, message: nil, errors: nil, details: {})
      @error = error
      @message = message
      @errors = errors
      @details = details
    end

    def success?
      false
    end
  end
end

# Usage
result = ArticlePublishService.new(article, published_by: current_user).call

if result.success?
  render json: result.article, status: :ok
else
  render json: {
    error: result.error,
    message: result.message,
    errors: result.errors&.full_messages,
    details: result.details
  }, status: :unprocessable_entity
end
```

### API Error Responses

#### JSON:API Format

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
          source: {
            pointer: request.path
          },
          meta: {
            module: error.tags[:module],
            context: error.context,
            extra: error.extra
          }
        }
      ]
    }, status: error_status_code(error)
  end
end
```

#### Custom Format

```ruby
def render_better_model_error(error)
  render json: {
    success: false,
    error: {
      type: error.class.name,
      category: error.tags[:error_category],
      module: error.tags[:module],
      message: error.message,
      context: error.context,
      timestamp: Time.current.iso8601
    }
  }, status: error_status_code(error)
end
```

### Background Job Handling

```ruby
class ProcessArticleJob < ApplicationJob
  queue_as :default
  retry_on BetterModel::Errors::Stateable::CheckFailedError, wait: 5.minutes, attempts: 3

  def perform(article_id)
    article = Article.find(article_id)
    article.publish!

    NotifySubscribersJob.perform_later(article_id)
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    # Don't retry - article is in wrong state
    Rails.logger.error("Cannot publish article #{article_id}: #{e.message}")

    Sentry.capture_exception(e) do |scope|
      scope.set_context("job", {
        job_class: self.class.name,
        article_id: article_id,
        article_state: article.state
      })
    end

    # Notify admin
    AdminMailer.article_publish_failed(article, e).deliver_later
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    # Retry - checks might pass later
    Rails.logger.warn("Article #{article_id} checks failed: #{e.check_description}")
    raise  # Will retry automatically
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    # Don't retry - validation error needs manual fix
    Rails.logger.error("Article #{article_id} validation failed: #{e.errors_object.full_messages}")

    Sentry.capture_exception(e)

    # Create admin notification
    AdminNotification.create!(
      notification_type: :article_validation_failed,
      article_id: article_id,
      details: e.errors_object.full_messages
    )
  end
end
```

---

## Testing Errors

### RSpec Examples

#### Testing Error Raising

```ruby
RSpec.describe Article, type: :model do
  describe "#publish!" do
    it "raises InvalidTransitionError when already published" do
      article = create(:article, :published)

      expect {
        article.publish!
      }.to raise_error(
        BetterModel::Errors::Stateable::InvalidTransitionError,
        /Cannot transition from :published/
      )
    end

    it "raises CheckFailedError when content is empty" do
      article = create(:article, content: nil)

      expect {
        article.publish!
      }.to raise_error(BetterModel::Errors::Stateable::CheckFailedError) do |error|
        expect(error.event).to eq(:publish)
        expect(error.check_description).to include("content")
        expect(error.current_state).to eq(:draft)
      end
    end
  end
end
```

#### Testing Error Handling

```ruby
RSpec.describe ArticlesController, type: :controller do
  describe "POST #publish" do
    context "when transition fails" do
      it "returns unprocessable_entity with error details" do
        article = create(:article, :published)

        post :publish, params: { id: article.id }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response["error"]).to eq("Invalid state transition")
        expect(json_response["current_state"]).to eq("published")
      end
    end

    context "when checks fail" do
      it "returns meaningful error message" do
        article = create(:article, content: nil)

        post :publish, params: { id: article.id }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response["reason"]).to include("content")
      end
    end
  end
end
```

#### Testing Sentry Integration

```ruby
RSpec.describe "Sentry error capture", type: :request do
  before do
    allow(Sentry).to receive(:capture_exception)
  end

  it "captures InvalidPredicateError with proper tags" do
    get "/api/articles/search", params: { title_unknown: "test" }

    expect(Sentry).to have_received(:capture_exception)
      .with(instance_of(BetterModel::Errors::Searchable::InvalidPredicateError))

    expect(Sentry).to have_received(:capture_exception) do |&block|
      scope = double("scope")
      expect(scope).to receive(:set_tags).with(hash_including(
        error_category: "invalid_predicate",
        module: "searchable"
      ))
      block.call(scope)
    end
  end
end
```

### Minitest Examples

```ruby
class ArticleTest < ActiveSupport::TestCase
  test "publish raises InvalidTransitionError when already published" do
    article = articles(:published)

    error = assert_raises(BetterModel::Errors::Stateable::InvalidTransitionError) do
      article.publish!
    end

    assert_equal :publish, error.event
    assert_equal :published, error.from_state
  end

  test "publish raises CheckFailedError with content requirement" do
    article = Article.new(title: "Test", content: nil)

    error = assert_raises(BetterModel::Errors::Stateable::CheckFailedError) do
      article.publish!
    end

    assert_includes error.check_description, "content"
    assert_equal :publish, error.event
  end
end
```

---

## Best Practices

### ✅ DO: Rescue Specific Errors

```ruby
# Good: Specific rescue for expected errors
begin
  article.publish!
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  handle_invalid_transition(e)
rescue BetterModel::Errors::Stateable::CheckFailedError => e
  handle_failed_checks(e)
end
```

```ruby
# Bad: Generic rescue masks errors
begin
  article.publish!
rescue StandardError => e
  handle_error(e)  # Too generic
end
```

### ✅ DO: Use Error Attributes

```ruby
# Good: Use error attributes for conditional logic
rescue BetterModel::Errors::Stateable::CheckFailedError => e
  message = case e.check_description
            when /content/
              "Article needs content"
            when /images/
              "Article needs at least one image"
            else
              "Requirements not met"
            end
end
```

### ✅ DO: Log Error Context

```ruby
# Good: Log rich context
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  Rails.logger.warn(
    "Invalid predicate: #{e.predicate_scope}",
    {
      model: e.model_class,
      available: e.available_predicates,
      value: e.value,
      user_id: current_user&.id
    }
  )
end
```

### ✅ DO: Capture in Sentry with Context

```ruby
# Good: Full Sentry context
rescue BetterModel::Errors::BetterModelError => e
  Sentry.capture_exception(e) do |scope|
    scope.set_context("error_details", e.context)
    scope.set_tags(e.tags.merge(user_id: current_user&.id))
    scope.set_extras(e.extra)
  end
end
```

### ✅ DO: Provide User-Friendly Messages

```ruby
# Good: Transform technical errors to user-friendly messages
rescue BetterModel::Errors::Stateable::CheckFailedError => e
  render json: {
    error: user_friendly_message(e),
    help: "Please check your order and try again"
  }
end
```

### ❌ DON'T: Swallow Errors Silently

```ruby
# Bad: Silent failure
begin
  article.archive!
rescue BetterModel::Errors::Archivable::AlreadyArchivedError
  # Nothing - error ignored
end

# Good: Log or handle appropriately
begin
  article.archive!
rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
  Rails.logger.info("Article already archived: #{e.archived_at}")
  # Return success for idempotent operation
end
```

### ❌ DON'T: Expose Sensitive Data

```ruby
# Bad: Exposing internal details
rescue BetterModel::Errors::BetterModelError => e
  render json: {
    error: e.message,
    backtrace: e.backtrace,  # Never expose backtrace
    extra: e.extra           # May contain sensitive data
  }
end

# Good: Filter sensitive data
rescue BetterModel::Errors::BetterModelError => e
  render json: {
    error: e.message,
    category: e.tags[:error_category]
  }
end
```

### ❌ DON'T: Retry Validation Errors

```ruby
# Bad: Retrying validation errors
rescue BetterModel::Errors::Stateable::ValidationFailedError => e
  retry  # Will fail again with same validation errors
end

# Good: Handle validation errors properly
rescue BetterModel::Errors::Stateable::ValidationFailedError => e
  render json: { errors: e.errors_object.full_messages }
end
```

---

## Troubleshooting

### "Module is not enabled" Error

**Problem**: `NotEnabledError` when calling module methods

**Solution**: Enable the module in your model:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Add this:
  archivable do
    # Configuration...
  end
end
```

### "Invalid predicate scope" Error

**Problem**: Using undefined predicate in search

**Solution**: Add field to predicates list:

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicable do
    predicates :title, :content, :status  # Add all searchable fields
  end
end
```

### "Invalid transition" Error

**Problem**: State transition not allowed from current state

**Solution**: Check transition definition and current state:

```ruby
# 1. Check current state
article.state  # => :published

# 2. Verify transition is defined for current state
stateable do
  transition :unpublish, from: :published, to: :draft  # Add missing transition
end
```

### Sentry Not Capturing Errors

**Problem**: Errors not appearing in Sentry

**Solution**: Verify error capturing code:

```ruby
# Ensure you're capturing with proper context
Sentry.capture_exception(error) do |scope|
  scope.set_context("error_details", error.context)
  scope.set_tags(error.tags)
  scope.set_extras(error.extra)
end

# Check Sentry is properly initialized
Sentry.initialized?  # => true
```

---

## Related Documentation

- [Archivable](archivable.md) - Record archiving with error handling
- [Searchable](searchable.md) - Search with predicate and security errors
- [Stateable](stateable.md) - State machines with transition errors
- [Validatable](validatable.md) - Validation with error handling
- [ERROR_SYSTEM_GUIDELINES.md](../ERROR_SYSTEM_GUIDELINES.md) - Developer guidelines for creating errors

---

**Next Steps:**
- Review [Error Handling Examples](examples/15_error_handling.md) for complete code samples
- Check [Context7 Error Reference](../context7/12_errors.md) for quick API lookup
- Read module-specific documentation for detailed error scenarios
