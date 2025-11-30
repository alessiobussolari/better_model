# 12. Errors - Simple, Idiomatic Error Handling

**BetterModel v3.0.0+**: Standard Ruby exceptions with descriptive messages across all modules.

## Overview

- **28+ specialized error classes** across 10 modules
- **Standard Ruby exceptions** - simple and idiomatic
- **Three-tier hierarchy** for flexible rescue patterns
- **Descriptive error messages** with contextual information
- **Production-ready** with standard monitoring tool integration

## Requirements

- Rails 8.0+
- Ruby 3.3+
- ActiveRecord 8.0+
- BetterModel ~> 3.0.0

---

## Error Hierarchy

### Structure

```
StandardError / ArgumentError
    └── BetterModel::Errors::BetterModelError (root)
        ├── Archivable::ArchivableError
        ├── Searchable::SearchableError
        ├── Stateable::StateableError
        ├── Validatable::ValidatableError
        ├── Traceable::TraceableError
        ├── Statusable::StatusableError
        ├── Permissible::PermissibleError
        ├── Predicable::PredicableError
        ├── Sortable::SortableError
        └── Taggable::TaggableError
            ├── ConfigurationError (ArgumentError)
            ├── NotEnabledError
            └── Module-specific errors
```

### Rescue Patterns

```ruby
# All BetterModel errors
rescue BetterModel::Errors::BetterModelError => e
  logger.error("BetterModel error: #{e.message}")
end

# Module-specific errors
rescue BetterModel::Errors::Searchable::SearchableError => e
  render json: { error: e.message }, status: :bad_request
end

# Specific error type
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  flash[:error] = "Invalid search parameter: #{e.message}"
  redirect_back fallback_location: root_path
end
```

---

## Common Error Types

### 1. ConfigurationError

**Purpose**: Programmer errors - wrong configuration or usage

**Modules**: All 10 modules

**Inheritance**: `ArgumentError` (not `BetterModelError`)

**When raised**: Invalid DSL options, missing required columns, incompatible configurations

#### Basic Example

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Missing required column 'archived_at'
  archivable
end

# Raises:
# BetterModel::Errors::Archivable::ConfigurationError:
# Field 'archived_at' not found in table
```

#### Rescue Example

```ruby
class ApplicationRecord < ActiveRecord::Base
  def self.inherited(subclass)
    super
    subclass.include BetterModel
  rescue BetterModel::Errors::BetterModelError => e
    Rails.logger.error("Configuration error in #{subclass}: #{e.message}")
    raise # Re-raise to prevent invalid model from loading
  end
end
```

---

### 2. NotEnabledError

**Purpose**: Module not configured but methods called

**Modules**: Validatable, Stateable, Archivable, Statusable

**When raised**: Calling module methods without configuring the module

#### Basic Example

```ruby
class Article < ApplicationRecord
  include BetterModel
  # Validatable not configured
end

# Attempt to use validation groups
Article.validate_group(:publication)

# Raises:
# BetterModel::Errors::Validatable::NotEnabledError:
# Module is not enabled
```

#### Rescue Example

```ruby
def validate_form_section(section_name)
  @article.validate_group(section_name)
rescue BetterModel::Errors::Validatable::NotEnabledError
  # Fallback to standard validation
  @article.valid?
end
```

---

## Searchable Errors

### InvalidPredicateError

**When raised**: Using unknown predicate scope in search

**Example**:

```ruby
# Unknown predicate 'title_xxx'
Article.search(title_xxx: "Rails")

# Raises:
# BetterModel::Errors::Searchable::InvalidPredicateError:
# Invalid predicate scope: title_xxx. Available: title_eq, title_cont, title_matches, ...
```

**Rescue**:

```ruby
def search_articles(params)
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  render json: {
    error: "Invalid search parameter",
    details: e.message
  }, status: :bad_request
end
```

---

### InvalidOrderError

**When raised**: Using unknown order scope

**Example**:

```ruby
# Unknown order scope
Article.search(order: :unknown_field_desc)

# Raises:
# BetterModel::Errors::Searchable::InvalidOrderError:
# Invalid order scope: unknown_field_desc. Available: title_asc, title_desc, created_at_asc, ...
```

**Rescue**:

```ruby
def search_with_fallback(params)
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidOrderError
  # Fallback to default ordering
  Article.search(params.except(:order))
end
```

---

### InvalidPaginationError

**When raised**: Page number exceeds maximum, invalid per_page value

**Example**:

```ruby
# Page exceeds maximum
Article.search(page: 10001, per_page: 20)

# Raises:
# BetterModel::Errors::Searchable::InvalidPaginationError:
# Page number exceeds maximum allowed (10000)
```

**Rescue**:

```ruby
def paginated_search(params)
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
  render json: {
    error: "Pagination error",
    message: e.message,
    max_page: 10000
  }, status: :bad_request
end
```

---

### InvalidSecurityError

**When raised**: Required security predicates missing from search

**Example**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  searchable do
    predicates :title, :status

    security do
      required_predicates :user_id
    end
  end
end

# Missing required security predicate
Article.search(title_eq: "Rails")

# Raises:
# BetterModel::Errors::Searchable::InvalidSecurityError:
# Required security predicates missing
```

**Rescue**:

```ruby
def search_articles(params, current_user)
  # Enforce security
  Article.search(params.merge(user_id_eq: current_user.id))
rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  render json: { error: "Unauthorized search" }, status: :forbidden
end
```

---

## Stateable Errors

### InvalidTransitionError

**When raised**: Attempting invalid state transition

**Example**:

```ruby
article = Article.create(state: "draft")

# Invalid transition (no event defined for draft -> archived)
article.transition_to!(:archived)

# Raises:
# BetterModel::Errors::Stateable::InvalidTransitionError:
# Cannot transition from 'draft' to 'archived' via 'archive'
```

**Rescue**:

```ruby
def publish_article(article)
  article.transition_to!(:published)
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  flash[:error] = "Cannot publish article: #{e.message}"
  redirect_to article_path(article)
end
```

---

### CheckFailedError

**When raised**: Guard condition prevents transition

**Example**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    state :draft
    state :published

    transition :publish, from: :draft, to: :published do
      check { user.can_publish? }
    end
  end
end

# Guard check fails
article.publish!

# Raises:
# BetterModel::Errors::Stateable::CheckFailedError:
# Guard condition failed
```

**Rescue**:

```ruby
def trigger_transition(article, event)
  article.send("#{event}!")
rescue BetterModel::Errors::Stateable::CheckFailedError => e
  Rails.logger.warn("Transition blocked: #{e.message}")
  flash[:error] = "You don't have permission for this action"
  redirect_back fallback_location: root_path
end
```

---

### ValidationFailedError

**When raised**: Model validation prevents transition

**Example**:

```ruby
article = Article.new(title: nil) # Invalid
article.publish!

# Raises:
# BetterModel::Errors::Stateable::ValidationFailedError:
# Validation failed for transition
```

**Rescue**:

```ruby
def save_and_publish(article, params)
  article.attributes = params
  article.publish!
rescue BetterModel::Errors::Stateable::ValidationFailedError
  render :edit, locals: { article: article }
end
```

---

### InvalidStateError

**When raised**: Unknown state name used

**Example**:

```ruby
# Unknown state
article.transition_to!(:unknown_state)

# Raises:
# BetterModel::Errors::Stateable::InvalidStateError:
# Invalid state: 'unknown_state'. Available states: draft, published, archived
```

---

## Archivable Errors

### AlreadyArchivedError

**When raised**: Attempting to archive already-archived record

**Example**:

```ruby
article = Article.create(archived_at: Time.current)
article.archive!

# Raises:
# BetterModel::Errors::Archivable::AlreadyArchivedError:
# Record already archived at 2025-01-11T10:30:00Z
```

**Rescue**:

```ruby
def archive_article(article)
  article.archive!
rescue BetterModel::Errors::Archivable::AlreadyArchivedError
  flash[:notice] = "Article is already archived"
  redirect_to articles_path
end
```

---

### NotArchivedError

**When raised**: Attempting to restore non-archived record

**Example**:

```ruby
article = Article.create # Not archived
article.restore!

# Raises:
# BetterModel::Errors::Archivable::NotArchivedError:
# Record is not archived
```

**Rescue**:

```ruby
def restore_article(article)
  article.restore!
rescue BetterModel::Errors::Archivable::NotArchivedError
  flash[:notice] = "Article is not archived"
  redirect_to article_path(article)
end
```

---

## Validatable Errors

### InvalidGroupError

**When raised**: Unknown validation group name

**Example**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  validatable do
    validation_group :publication do
      check :title, presence: true
    end
  end
end

# Unknown group
Article.new.validate_group(:unknown_group)

# Raises:
# BetterModel::Errors::Validatable::InvalidGroupError:
# Invalid validation group: unknown_group. Available: publication
```

---

## Traceable Errors

### VersionNotFoundError

**When raised**: Requested version doesn't exist

**Example**:

```ruby
article = Article.create(title: "First")

# Attempt rollback to non-existent version
article.rollback_to(999)

# Raises:
# BetterModel::Errors::Traceable::VersionNotFoundError:
# Version 999 not found
```

**Rescue**:

```ruby
def rollback_article(article, version_id)
  article.rollback_to(version_id)
rescue BetterModel::Errors::Traceable::VersionNotFoundError => e
  flash[:error] = "Invalid version: #{e.message}"
  redirect_to article_versions_path(article)
end
```

---

## Predicable/Sortable/Taggable Errors

### InvalidPredicateError (Predicable)

**When raised**: Unknown predicate scope called directly

**Example**:

```ruby
Article.title_unknown_predicate("Rails")

# Raises:
# NoMethodError or BetterModel::Errors::Predicable::InvalidPredicateError
```

### InvalidOrderError (Sortable)

**When raised**: Unknown sort scope called

**Example**:

```ruby
Article.unknown_field_asc

# Raises:
# NoMethodError or BetterModel::Errors::Sortable::InvalidOrderError
```

### InvalidTagError (Taggable)

**When raised**: Tag validation fails (length, whitelist, blacklist)

**Example**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  taggable do
    min_length 3
    max_length 20
    forbidden_tags %w[spam nsfw]
  end
end

article = Article.new
article.tag_with("a") # Too short

# Raises:
# BetterModel::Errors::Taggable::InvalidTagError:
# Tag 'a' is too short (minimum: 3 characters)
```

---

## Sentry Integration

### Standard Pattern

BetterModel v3.0.0+ uses standard Ruby exceptions, so Sentry integration is straightforward:

```ruby
# Simple capture
begin
  Article.search(params)
rescue BetterModel::Errors::BetterModelError => e
  Sentry.capture_exception(e)
  render json: { error: "Search failed" }, status: :internal_server_error
end
```

### With Custom Context

```ruby
begin
  article.transition_to!(:published)
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  Sentry.capture_exception(e) do |scope|
    scope.set_context("article", {
      id: article.id,
      current_state: article.state,
      user_id: current_user.id
    })
    scope.set_tag("error_category", "state_transition")
    scope.set_tag("module", "stateable")
  end

  flash[:error] = "Cannot publish article"
  redirect_to article_path(article)
end
```

### Global Error Handler

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.before_send = lambda do |event, hint|
    if hint[:exception].is_a?(BetterModel::Errors::BetterModelError)
      # Extract module name from error class
      # BetterModel::Errors::Searchable::InvalidPredicateError -> "Searchable"
      module_name = hint[:exception].class.name.split("::")[2]

      event.tags[:better_model_module] = module_name if module_name
      event.tags[:error_type] = hint[:exception].class.name.demodulize.underscore
    end

    event
  end
end
```

---

## Complete Examples

### Controller Error Handling

```ruby
class ArticlesController < ApplicationController
  def search
    @articles = Article.search(search_params)
    render json: @articles
  rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
    render json: {
      error: "Invalid search parameter",
      message: e.message
    }, status: :bad_request

  rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
    render json: {
      error: "Unauthorized search"
    }, status: :forbidden

  rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
    render json: {
      error: "Pagination error",
      message: e.message
    }, status: :bad_request

  rescue BetterModel::Errors::BetterModelError => e
    Sentry.capture_exception(e)
    render json: {
      error: "Search failed"
    }, status: :internal_server_error
  end

  def publish
    @article = Article.find(params[:id])
    @article.transition_to!(:published)

    redirect_to @article, notice: "Article published successfully"
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    flash.now[:error] = "Cannot publish: #{e.message}"
    render :show
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    flash.now[:error] = "Permission denied"
    render :show
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    flash.now[:error] = "Please fix validation errors"
    render :edit
  end

  def archive
    @article = Article.find(params[:id])
    @article.archive!(reason: params[:reason], by: current_user)

    redirect_to articles_path, notice: "Article archived"
  rescue BetterModel::Errors::Archivable::AlreadyArchivedError
    redirect_to @article, notice: "Article is already archived"
  end

  private

  def search_params
    params.permit(:title_eq, :title_cont, :status_eq, :page, :per_page, :order)
  end
end
```

---

### Service Object Pattern

```ruby
class ArticlePublisher
  class Result
    attr_reader :success, :article, :error

    def initialize(success:, article:, error: nil)
      @success = success
      @article = article
      @error = error
    end

    def success? = success
    def failure? = !success
  end

  def self.call(article, user)
    new(article, user).call
  end

  def initialize(article, user)
    @article = article
    @user = user
  end

  def call
    @article.transition_to!(:published)
    notify_subscribers

    Result.new(success: true, article: @article)

  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    Rails.logger.warn("Transition failed: #{e.message}")
    Result.new(success: false, article: @article, error: e.message)

  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    Rails.logger.warn("Permission check failed: #{e.message}")
    Result.new(success: false, article: @article, error: "Permission denied")

  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    Rails.logger.warn("Validation failed: #{e.message}")
    Result.new(success: false, article: @article, error: "Invalid article state")
  end

  private

  def notify_subscribers
    ArticleMailer.published_notification(@article).deliver_later
  end
end

# Usage
result = ArticlePublisher.call(article, current_user)
if result.success?
  redirect_to result.article, notice: "Published successfully"
else
  flash.now[:error] = result.error
  render :show
end
```

---

### Background Job Error Handling

```ruby
class ArticleArchiveJob < ApplicationJob
  queue_as :default

  retry_on BetterModel::Errors::BetterModelError,
           wait: :exponentially_longer,
           attempts: 3

  discard_on BetterModel::Errors::Archivable::AlreadyArchivedError
  discard_on BetterModel::Errors::Archivable::ConfigurationError

  def perform(article_id, user_id, reason)
    article = Article.find(article_id)
    user = User.find(user_id)

    article.archive!(by: user, reason: reason)

    Rails.logger.info("Article #{article_id} archived by user #{user_id}")

  rescue BetterModel::Errors::Archivable::AlreadyArchivedError
    Rails.logger.info("Article #{article_id} already archived, skipping")

  rescue BetterModel::Errors::BetterModelError => e
    Rails.logger.error("Archive failed for article #{article_id}: #{e.message}")
    Sentry.capture_exception(e, extra: {
      article_id: article_id,
      user_id: user_id
    })
    raise # Retry via retry_on
  end
end
```

---

## Best Practices

### 1. Rescue Specific Errors

**Good**:
```ruby
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  render json: { error: "Invalid parameter: #{e.message}" }, status: :bad_request
rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  render json: { error: "Unauthorized" }, status: :forbidden
end
```

**Bad**:
```ruby
begin
  Article.search(params)
rescue => e
  render json: { error: "Error" }, status: :internal_server_error
end
```

---

### 2. Log Error Context

```ruby
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  Rails.logger.error("Transition failed: #{e.message}")
  Rails.logger.error("  Article: #{article.id}")
  Rails.logger.error("  Current state: #{article.state}")
  Rails.logger.error("  User: #{current_user.id}")

  Sentry.capture_exception(e)
end
```

---

### 3. Provide User-Friendly Messages

```ruby
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  # Don't expose technical details
  flash[:error] = "Invalid search parameter. Please check your filters."

  # Log technical details
  Rails.logger.warn("Search error: #{e.message}")
end
```

---

### 4. Use Rescue Blocks Appropriately

```ruby
# Controller-level rescue
class ApplicationController < ActionController::Base
  rescue_from BetterModel::Errors::BetterModelError do |e|
    Sentry.capture_exception(e)
    render json: { error: "An error occurred" }, status: :internal_server_error
  end

  rescue_from BetterModel::Errors::Searchable::InvalidSecurityError do |e|
    render json: { error: "Unauthorized" }, status: :forbidden
  end
end

# Specific rescue in action
def search
  @articles = Article.search(search_params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  flash.now[:error] = "Invalid search parameter"
  render :index
end
```

---

### 5. Test Error Scenarios

```ruby
# test/controllers/articles_controller_test.rb
test "search with invalid predicate returns error" do
  get search_articles_path, params: { title_xxx: "Rails" }

  assert_response :bad_request
  assert_includes response.parsed_body["error"], "Invalid search parameter"
end

test "transition with failed guard returns error" do
  article = articles(:draft)

  patch publish_article_path(article)

  assert_response :unprocessable_entity
  assert_includes flash[:error], "Permission denied"
end
```

---

## Error Summary Table

| Error Class | Module | Inherits From | When Raised |
|------------|--------|---------------|-------------|
| ConfigurationError | All | ArgumentError | Invalid configuration |
| NotEnabledError | Validatable, Stateable, Archivable, Statusable | ModuleError | Module not configured |
| InvalidPredicateError | Searchable, Predicable | ModuleError | Unknown predicate |
| InvalidOrderError | Searchable, Sortable | ModuleError | Unknown order scope |
| InvalidPaginationError | Searchable | ModuleError | Invalid page/per_page |
| InvalidSecurityError | Searchable | ModuleError | Missing security predicates |
| InvalidTransitionError | Stateable | ModuleError | Invalid state transition |
| CheckFailedError | Stateable | ModuleError | Guard condition failed |
| ValidationFailedError | Stateable | ModuleError | Model validation failed |
| InvalidStateError | Stateable | ModuleError | Unknown state name |
| AlreadyArchivedError | Archivable | ModuleError | Already archived |
| NotArchivedError | Archivable | ModuleError | Not archived |
| InvalidGroupError | Validatable | ModuleError | Unknown validation group |
| VersionNotFoundError | Traceable | ModuleError | Version doesn't exist |
| InvalidTagError | Taggable | ModuleError | Tag validation failed |

---

## Quick Reference

### Common Rescue Patterns

```ruby
# All BetterModel errors
rescue BetterModel::Errors::BetterModelError => e

# All module errors
rescue BetterModel::Errors::Searchable::SearchableError => e
rescue BetterModel::Errors::Stateable::StateableError => e
rescue BetterModel::Errors::Archivable::ArchivableError => e

# Configuration errors (ArgumentError)
rescue ArgumentError => e
rescue BetterModel::Errors::Searchable::ConfigurationError => e

# Specific errors
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
```

### Error Attributes

**Available in v3.0.0+**:
- `error.message` - Descriptive error message with context

**Removed in v3.0.0** (do not use):
- ~~`error.tags`~~ - Removed
- ~~`error.context`~~ - Removed
- ~~`error.extra`~~ - Removed
- ~~Domain-specific attributes~~ (e.g., `predicate_scope`, `event`, `state`) - Removed

---

## Migration from v2.x

If upgrading from BetterModel v2.x, error handling code needs minimal changes:

### Before (v2.x)

```ruby
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  logger.error("Invalid predicate: #{e.predicate_scope}")
  Sentry.capture_exception(e) do |scope|
    scope.set_tags(e.tags)
    scope.set_context("error_details", e.context)
  end
end
```

### After (v3.0.0+)

```ruby
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  logger.error("Search error: #{e.message}")
  Sentry.capture_exception(e)
end
```

**Key changes**:
- Only `e.message` is available
- Sentry integration uses standard patterns
- Error messages contain all necessary context

---

## Additional Resources

- **Error System Guidelines**: `/ERROR_SYSTEM_GUIDELINES.md`
- **Error Documentation**: `/docs/errors.md`
- **CHANGELOG**: `/CHANGELOG.md` (v3.0.0 section)
- **Module Documentation**: `/docs/*.md` files

---

**Last Updated**: 2025-11-11 (BetterModel v3.0.0)
