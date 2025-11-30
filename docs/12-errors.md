# Error System 🚨

Comprehensive guide to BetterModel's simplified error handling system (v3.0+).

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
- [Error Handling Patterns](#error-handling-patterns)
  - [Controller Error Handling](#controller-error-handling)
  - [Service Object Patterns](#service-object-patterns)
  - [API Error Responses](#api-error-responses)
  - [Background Job Handling](#background-job-handling)
- [Integration with Monitoring Tools](#integration-with-monitoring-tools)
- [Testing Errors](#testing-errors)
- [Best Practices](#best-practices)
- [Migration from v2.x](#migration-from-v2x)

---

## Overview

BetterModel v3.0+ uses **standard Ruby exception patterns** for simplicity and idiomatic Ruby code.

### Design Goals

- 🎯 **Simple**: Standard Ruby exceptions with clear inheritance
- 📝 **Descriptive**: Clear error messages with helpful context
- 🔍 **Specific**: Dedicated error class for each failure scenario
- 🏗️ **Hierarchical**: Three-tier structure for flexible rescue patterns
- ✅ **Compatible**: Works with all monitoring tools (Sentry, Rollbar, etc.)

### Key Features

- **36+ specialized error classes** across 10 modules
- **Standard Ruby patterns** - no magic attributes or initialization
- **Thread-safe** error handling
- **Production-ready** with descriptive messages
- **Testing-friendly** with standard rescue patterns

---

## Error Hierarchy

BetterModel uses a three-tier error hierarchy:

```
StandardError / ArgumentError
    │
    └── BetterModel::Errors::BetterModelError (root)
        │
        ├── Archivable::ArchivableError
        │   ├── ConfigurationError (ArgumentError)
        │   ├── NotEnabledError
        │   ├── AlreadyArchivedError
        │   └── NotArchivedError
        │
        ├── Searchable::SearchableError
        │   ├── ConfigurationError (ArgumentError)
        │   ├── InvalidPredicateError
        │   ├── InvalidOrderError
        │   ├── InvalidPaginationError
        │   └── InvalidSecurityError
        │
        ├── Stateable::StateableError
        │   ├── ConfigurationError (ArgumentError)
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
  Rails.logger.error("BetterModel error: #{e.message}")
  render_error(e)
end

# Rescue all errors from a specific module
begin
  article.archive!
rescue BetterModel::Errors::Archivable::ArchivableError => e
  handle_archive_error(e)
end

# Rescue a specific error type
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  render json: { error: e.message }, status: :bad_request
end
```

---

## Common Error Types

### ConfigurationError

**Type**: `ArgumentError` (programmer errors)

**When**: Invalid DSL configuration or module setup

**Modules**: All 10 modules

**Examples**:

```ruby
# Missing required column
class Article < ApplicationRecord
  include BetterModel
  archivable  # but no 'archived_at' column
end
# => ConfigurationError: "Invalid configuration"

# Invalid DSL option
class Article < ApplicationRecord
  include BetterModel
  searchable do
    max_per_page "not_a_number"
  end
end
# => ConfigurationError: "Invalid configuration"

# Including in non-ActiveRecord class
class PlainRuby
  include BetterModel::Sortable
end
# => ConfigurationError: "Sortable can only be included in ActiveRecord models"
```

**Handling**:

```ruby
# These are programmer errors - fix the code, don't rescue
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::ConfigurationError => e
  # Log for investigation
  Rails.logger.fatal("Configuration error: #{e.message}")
  raise  # Re-raise - this needs to be fixed in code
end
```

---

### NotEnabledError

**When**: Calling methods on a module that hasn't been configured

**Modules**: Validatable, Stateable, Archivable, Statusable

**Examples**:

```ruby
# Stateable not configured
class Article < ApplicationRecord
  include BetterModel
  # No stateable configuration
end

article.transition_to!(:published)
# => NotEnabledError: "Module is not enabled"

# Archivable not configured
article.archive!
# => NotEnabledError: "Module is not enabled"
```

**Handling**:

```ruby
begin
  article.transition_to!(:published)
rescue BetterModel::Errors::Stateable::NotEnabledError
  # Graceful fallback
  article.update(status: "published")
end
```

---

## Module-Specific Errors

### Archivable Errors

#### ConfigurationError
**When**: Invalid archivable configuration

```ruby
class Article < ApplicationRecord
  include BetterModel
  archivable  # but table has no 'archived_at' column
end
# => ConfigurationError
```

#### NotEnabledError
**When**: Archivable not configured

```ruby
article.archive!  # archivable not configured
# => NotEnabledError: "Module is not enabled"
```

#### AlreadyArchivedError
**When**: Trying to archive an already-archived record

```ruby
article.archive!
article.archive!  # already archived
# => AlreadyArchivedError: "Record already archived at 2025-11-11T10:30:00Z"
```

#### NotArchivedError
**When**: Trying to unarchive a non-archived record

```ruby
article.unarchive!  # not archived
# => NotArchivedError: "Record is not archived"
```

---

### Searchable Errors

#### InvalidPredicateError
**When**: Using an unknown predicate in search

```ruby
Article.search(title_xxx: "Rails")
# => InvalidPredicateError: "Invalid predicate scope: title_xxx. Available: title_eq, title_cont, ..."
```

#### InvalidOrderError
**When**: Using an unknown sort scope

```ruby
Article.search({}, orders: [:unknown_sort])
# => InvalidOrderError: "Invalid order scope: unknown_sort. Available: sort_title_asc, sort_created_at_desc"
```

#### InvalidPaginationError
**When**: Invalid pagination parameters

```ruby
# Exceeds max_page
Article.search({}, pagination: { page: 10_001, per_page: 10 })
# => InvalidPaginationError: "Page number exceeds maximum allowed (10000)"

# Exceeds max_per_page
Article.search({}, pagination: { page: 1, per_page: 200 })
# => InvalidPaginationError: "per_page must be <= 100"
```

#### InvalidSecurityError
**When**: Security policy violations

```ruby
# Missing required predicates
Article.search({}, security: :admin_filter)
# => InvalidSecurityError: "Required security predicates missing"

# Unknown security policy
Article.search({}, security: :nonexistent)
# => InvalidSecurityError: "Unknown security policy"
```

---

### Stateable Errors

#### InvalidTransitionError
**When**: Attempting an invalid state transition

```ruby
article = Article.create(state: "draft")
article.transition_to!(:archived)  # not allowed from draft
# => InvalidTransitionError: "Cannot transition from 'draft' to 'archived' via 'archive'"
```

#### CheckFailedError
**When**: Guard/check condition fails

```ruby
stateable do
  state :draft
  state :published

  event :publish do
    from :draft, to: :published
    check :content_present?, "Content must be present"
  end
end

article.transition_to!(:published)  # content blank
# => CheckFailedError: "Guard condition failed: Content must be present"
```

#### ValidationFailedError
**When**: Validations fail during transition

```ruby
stateable do
  event :publish do
    from :draft, to: :published
    validate true
  end
end

article.title = nil  # invalid
article.transition_to!(:published)
# => ValidationFailedError: "Validation failed"
```

#### InvalidStateError
**When**: Invalid state value

```ruby
article.state = "invalid_state"
article.save!
# => InvalidStateError: "Invalid state: 'invalid_state'. Available: draft, published, archived"
```

---

### Other Module Errors

Each module has its own error classes. See module-specific documentation:

- **Predicable**: ConfigurationError, InvalidPredicateError
- **Sortable**: ConfigurationError, InvalidOrderError
- **Taggable**: ConfigurationError
- **Traceable**: ConfigurationError
- **Validatable**: ConfigurationError, NotEnabledError
- **Statusable**: ConfigurationError, NotEnabledError
- **Permissible**: ConfigurationError

---

## Error Handling Patterns

### Controller Error Handling

#### Basic Pattern

```ruby
class ArticlesController < ApplicationController
  def search
    @articles = Article.search(search_params)
    render json: @articles
  rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
    render json: { error: e.message }, status: :bad_request
  rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
    render json: { error: e.message }, status: :forbidden
  rescue BetterModel::Errors::BetterModelError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
```

#### With concern Pattern

```ruby
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from BetterModel::Errors::Searchable::InvalidPredicateError,
                with: :render_bad_request
    rescue_from BetterModel::Errors::Searchable::InvalidSecurityError,
                with: :render_forbidden
    rescue_from BetterModel::Errors::Stateable::InvalidTransitionError,
                with: :render_transition_error
  end

  private

  def render_bad_request(error)
    render json: { error: error.message }, status: :bad_request
  end

  def render_forbidden(error)
    render json: { error: error.message }, status: :forbidden
  end

  def render_transition_error(error)
    render json: {
      error: error.message,
      type: "transition_error"
    }, status: :unprocessable_entity
  end
end

class ArticlesController < ApplicationController
  include ErrorHandling

  def search
    @articles = Article.search(search_params)
    render json: @articles
  end
end
```

---

### Service Object Patterns

```ruby
class ArticlePublisher
  def initialize(article)
    @article = article
  end

  def call
    publish_article
    Success.new(@article)
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    Failure.new(error: e.message, type: :transition)
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    Failure.new(error: e.message, type: :check)
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    Failure.new(error: e.message, type: :validation)
  end

  private

  def publish_article
    @article.transition_to!(:published)
  end

  class Success
    attr_reader :article
    def initialize(article) = @article = article
    def success? = true
    def failure? = false
  end

  class Failure
    attr_reader :error, :type
    def initialize(error:, type:)
      @error = error
      @type = type
    end
    def success? = false
    def failure? = true
  end
end

# Usage
result = ArticlePublisher.new(article).call
if result.success?
  redirect_to article_path(result.article)
else
  flash[:error] = result.error
  redirect_to edit_article_path(article)
end
```

---

### API Error Responses

#### JSON:API Format

```ruby
def render_better_model_error(error)
  status = case error
           when BetterModel::Errors::Searchable::InvalidPredicateError,
                BetterModel::Errors::Searchable::InvalidOrderError
             :bad_request
           when BetterModel::Errors::Searchable::InvalidSecurityError
             :forbidden
           else
             :unprocessable_entity
           end

  render json: {
    errors: [{
      status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status].to_s,
      title: error.class.name.demodulize,
      detail: error.message,
      code: error.class.name.demodulize.underscore
    }]
  }, status: status
end
```

#### Simple Format

```ruby
def render_error(error)
  render json: {
    error: {
      message: error.message,
      type: error.class.name
    }
  }, status: error_status(error)
end

def error_status(error)
  case error
  when BetterModel::Errors::Searchable::InvalidPredicateError
    :bad_request
  when BetterModel::Errors::Searchable::InvalidSecurityError
    :forbidden
  else
    :unprocessable_entity
  end
end
```

---

### Background Job Handling

```ruby
class ArticlePublishJob < ApplicationJob
  retry_on StandardError, wait: 5.minutes, attempts: 3
  discard_on BetterModel::Errors::Stateable::InvalidTransitionError

  def perform(article_id)
    article = Article.find(article_id)
    article.transition_to!(:published)
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    # Retry later - might be temporary
    Rails.logger.warn("Check failed for article #{article_id}: #{e.message}")
    raise  # Will retry
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    # Don't retry - permanent error
    Rails.logger.error("Validation failed for article #{article_id}: #{e.message}")
    ArticlePublishNotifier.failure(article, e.message)
  end
end
```

---

## Integration with Monitoring Tools

### Sentry Integration

BetterModel errors work with **standard Sentry patterns**:

```ruby
# Basic capture
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  Sentry.capture_exception(e)
  render_error(e)
end

# With custom context
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  Sentry.capture_exception(e) do |scope|
    scope.set_context("search", {
      params: params,
      user_id: current_user&.id
    })
    scope.set_tag("error_category", "search")
    scope.set_tag("module", "searchable")
  end
  render_error(e)
end

# Global error handler
Sentry.init do |config|
  config.before_send = lambda do |event, hint|
    if hint[:exception].is_a?(BetterModel::Errors::BetterModelError)
      event.tags[:better_model_module] = extract_module(hint[:exception])
    end
    event
  end
end

def extract_module(exception)
  exception.class.name.split("::")[2]  # e.g., "Searchable"
end
```

### Rollbar/Bugsnag

```ruby
# Works with standard exception capture
Rollbar.error(exception)
Bugsnag.notify(exception)
```

---

## Testing Errors

### Testing Error Raising

```ruby
require "test_helper"

class SearchableTest < ActiveSupport::TestCase
  test "raises InvalidPredicateError for unknown predicate" do
    error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
      Article.search(unknown_predicate: "value")
    end

    assert_match(/Invalid predicate scope/, error.message)
    assert_match(/unknown_predicate/, error.message)
  end

  test "raises InvalidPaginationError when page exceeds maximum" do
    error = assert_raises(BetterModel::Errors::Searchable::InvalidPaginationError) do
      Article.search({}, pagination: { page: 10_001, per_page: 10 })
    end

    assert_match(/Page number exceeds maximum allowed/, error.message)
  end
end
```

### Testing Error Handling

```ruby
class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "handles InvalidPredicateError gracefully" do
    get search_articles_path, params: { unknown_predicate: "value" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_includes json["error"], "Invalid predicate"
  end

  test "handles InvalidSecurityError with 403" do
    get search_articles_path, params: { security: :admin }, headers: user_headers

    assert_response :forbidden
    assert_includes response.body, "security"
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
  render_bad_request(e)
rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  render_forbidden(e)
end
```

**Bad**:
```ruby
begin
  Article.search(params)
rescue StandardError => e  # Too broad
  render_error(e)
end
```

### 2. Don't Rescue ConfigurationError

```ruby
# BAD - ConfigurationErrors should crash in development
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::ConfigurationError
  # Silently handling programmer errors
end

# GOOD - Let it raise, fix the configuration
Article.search(params)
```

### 3. Log Before Re-raising

```ruby
begin
  article.transition_to!(:published)
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  Rails.logger.error("Transition failed for article #{article.id}: #{e.message}")
  raise  # Re-raise for upstream handling
end
```

### 4. Use Module-Level Rescue for Related Errors

```ruby
# When you want to handle all searchable errors similarly
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::SearchableError => e
  render json: { error: e.message }, status: :bad_request
end
```

### 5. Test Error Scenarios

```ruby
# Always test both success and error paths
test "successful search" do
  results = Article.search(title_eq: "Rails")
  assert_not_empty results
end

test "invalid predicate raises error" do
  assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
    Article.search(title_xxx: "Rails")
  end
end
```

---

## Migration from v2.x

If you're migrating from BetterModel v2.x with Sentry-compatible errors:

### What Changed

**Removed**:
- `tags`, `context`, `extra` error attributes
- Domain-specific attributes (`.predicate_scope`, `.event`, `.state`, etc.)
- Named parameter initialization
- `SentryCompatible` concern

**Kept**:
- Error class names and hierarchy
- Error messages (enhanced)
- Standard rescue patterns

### Update Pattern

#### Before (v2.x)
```ruby
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  Rails.logger.error("Invalid predicate: #{e.predicate_scope}")
  Sentry.capture_exception(e) do |scope|
    scope.set_tags(e.tags)
    scope.set_context("error_details", e.context)
    scope.set_extras(e.extra)
  end
  render json: {
    error: e.message,
    predicate: e.predicate_scope,
    available: e.available_predicates
  }, status: :bad_request
end
```

#### After (v3.0+)
```ruby
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  Rails.logger.error("Search error: #{e.message}")
  Sentry.capture_exception(e)  # Standard Sentry capture
  render json: { error: e.message }, status: :bad_request
end
```

### Benefits

1. **Simpler code**: Less boilerplate in error handling
2. **Standard patterns**: Idiomatic Ruby exception handling
3. **Better compatibility**: Works with all monitoring tools
4. **Easier testing**: Standard assert_raises patterns
5. **Clearer intent**: Error messages contain all needed info

---

## Summary

### Quick Reference

```ruby
# Raising errors (happens automatically in BetterModel)
raise InvalidPredicateError, "Invalid predicate: title_xxx"

# Rescue specific error
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  render_error(e)
end

# Rescue module errors
rescue BetterModel::Errors::Searchable::SearchableError => e
  render_search_error(e)
end

# Rescue all BetterModel errors
rescue BetterModel::Errors::BetterModelError => e
  log_and_render_error(e)
end

# Testing
test "raises error" do
  assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
    Article.search(unknown: "value")
  end
end

# Sentry integration
Sentry.capture_exception(error)
```

---

**Last Updated**: 2025-11-11 (v3.0.0)
**See Also**: [ERROR_SYSTEM_GUIDELINES.md](../ERROR_SYSTEM_GUIDELINES.md) for developer documentation
