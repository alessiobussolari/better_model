# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BetterModel is a Rails engine gem (Rails 8.1+) that extends ActiveRecord model functionality. The gem is currently at version 1.3.0 and follows the standard Rails engine architecture.

## Architecture

### Gem Structure

- **lib/better_model.rb**: Main entry point that loads version and railtie
- **lib/better_model/railtie.rb**: Rails integration via Railtie (currently minimal)
- **lib/better_model/version.rb**: Version constant (1.3.0)
- **test/dummy/**: Rails application for testing the engine in isolation

### Rails Engine Pattern

This gem follows the Rails engine pattern where:
- The engine integrates with Rails applications via the Railtie
- The dummy app in test/dummy/ provides a sandbox Rails environment for testing
- The engine's lib/ directory contains the core functionality that will be loaded into host Rails apps

## Development Commands

### Docker Development (Recommended)

The project includes Docker support for consistent development environments. This is the recommended approach to avoid dependency issues.

#### Initial Setup

First-time setup:
```bash
bin/docker-setup
```

This will:
- Build the Docker image with Ruby 3.3 and all dependencies
- Install gems
- Prepare the test database

#### Running Tests

Run all tests:
```bash
bin/docker-test
```

Run a specific test file:
```bash
bin/docker-test test/better_model_test.rb
```

#### Running RuboCop

Check code style:
```bash
bin/docker-rubocop
```

Auto-fix style issues:
```bash
docker compose run --rm app bundle exec rubocop -a
```

#### Interactive Shell

Open a shell in the Docker container for debugging or exploring:
```bash
docker compose run --rm app sh
```

#### Manual Commands

Run any command in the container:
```bash
docker compose run --rm app bundle exec [command]
```

### Local Development (Without Docker)

The gemspec currently has invalid placeholder URLs that prevent bundle commands from working. Before running tests, the gemspec metadata URLs need to be fixed (homepage, homepage_uri, source_code_uri, changelog_uri, allowed_push_host).

Once fixed, run tests with:
```bash
bundle exec rake test
```

To run a specific test file:
```bash
bundle exec ruby -Itest test/better_model_test.rb
```

### Code Style

The project uses rubocop-rails-omakase for Ruby styling:
```bash
bundle exec rubocop
```

Auto-fix style issues:
```bash
bundle exec rubocop -a
```

### Dependencies

Install dependencies:
```bash
bundle install
```

## Important Notes

- The gemspec (better_model.gemspec:8-19) contains TODO placeholders that must be replaced with actual values before the gem can be properly bundled or published
- Test fixtures are loaded from test/fixtures/ if present
- The dummy app uses SQLite3 for testing

## Error Handling in BetterModel

### Error Hierarchy

All BetterModel errors follow a consistent hierarchy for predictable error handling:

```
StandardError
└── BetterModel::Errors::BetterModelError (root for all BetterModel errors)
    ├── BetterModel::Errors::Validatable::ValidatableError
    │   └── BetterModel::Errors::Validatable::NotEnabledError
    ├── BetterModel::Errors::Stateable::StateableError
    │   ├── BetterModel::Errors::Stateable::NotEnabledError
    │   ├── BetterModel::Errors::Stateable::InvalidTransitionError
    │   ├── BetterModel::Errors::Stateable::CheckFailedError
    │   └── BetterModel::Errors::Stateable::ValidationFailedError
    ├── BetterModel::Errors::Searchable::SearchableError
    │   ├── BetterModel::Errors::Searchable::InvalidPredicateError
    │   ├── BetterModel::Errors::Searchable::InvalidOrderError
    │   ├── BetterModel::Errors::Searchable::InvalidPaginationError
    │   └── BetterModel::Errors::Searchable::InvalidSecurityError
    └── (other module errors...)

ArgumentError (for backward compatibility)
├── BetterModel::Errors::Validatable::ConfigurationError
├── BetterModel::Errors::Stateable::ConfigurationError
├── BetterModel::Errors::Searchable::ConfigurationError
└── (other configuration errors...)
```

### Configuration Errors and Backward Compatibility

**Important:** All `ConfigurationError` classes inherit from `ArgumentError` rather than their module's base error class. This design decision ensures backward compatibility with existing rescue clauses that expect `ArgumentError`.

**Implication for error handling:**

```ruby
# Catch specific configuration error
rescue BetterModel::Errors::Validatable::ConfigurationError => e
  # Specific to Validatable configuration issues

# Catch all configuration errors and standard ArgumentError
rescue ArgumentError => e
  # Catches ConfigurationError from all modules + standard ArgumentError
  # Check error message to distinguish between them
```

### Module-Specific Error Handling

#### Validatable Errors

**NotEnabledError**
- **When:** Calling `validate_group` or `errors_for_group` without enabling Validatable
- **Solution:** Add `validatable do...end` block to model

**ConfigurationError**
- **When:** Including Validatable in non-ActiveRecord class or calling `register_complex_validation` without block
- **Solution:** Only use in ActiveRecord models, always provide blocks

**ArgumentError** (from Configurator)
- **When:** Using unknown complex validation in `check_complex`, invalid validation group parameters
- **Solution:** Register validations before use, use correct parameter types

See `docs/validatable.md#error-handling` for detailed examples.

#### Stateable Errors

**NotEnabledError**
- **When:** Stateable methods called but module not enabled
- **Solution:** Add `stateable do...end` block to model

**InvalidTransitionError**
- **When:** Attempting invalid state transition
- **Metadata:** Access `e.event`, `e.from_state`, `e.to_state` for details

**CheckFailedError**
- **When:** Transition check condition returns false
- **Metadata:** Access `e.event`, `e.from_state`, `e.to_state`, `e.failed_checks`

**ValidationFailedError**
- **When:** Validation fails during transition
- **Metadata:** Access `e.errors` for validation errors

See `docs/stateable.md#error-handling` for detailed examples.

#### Searchable Errors

**InvalidPredicateError**
- **When:** Using unknown predicate scope
- **Metadata:** Access `e.predicate`, `e.available_predicates`

**InvalidOrderError**
- **When:** Using unknown sort scope
- **Metadata:** Access `e.order`, `e.available_orders`

**InvalidPaginationError**
- **When:** Invalid pagination parameters (negative page, per_page exceeds max)
- **Metadata:** Access `e.page`, `e.per_page`, `e.max_per_page`

**InvalidSecurityError**
- **When:** Security violation (unknown security, missing required predicate)
- **Metadata:** Access `e.security_name`, `e.required_predicates`

See `docs/searchable.md#error-handling` for detailed examples.

### Best Practices for Error Handling

1. **Catch specific errors first, then fall back to base errors:**
   ```ruby
   begin
     article.validate_group(:step1)
   rescue BetterModel::Errors::Validatable::NotEnabledError => e
     # Handle Validatable not enabled
   rescue BetterModel::Errors::BetterModelError => e
     # Handle any other BetterModel error
   rescue StandardError => e
     # Handle any other error
   end
   ```

2. **Use module-specific errors when possible:**
   ```ruby
   # Good - specific
   rescue BetterModel::Errors::Validatable::NotEnabledError

   # Less specific but still useful
   rescue BetterModel::Errors::Validatable::ValidatableError

   # Too broad
   rescue BetterModel::Errors::BetterModelError
   ```

3. **Expect ArgumentError for configuration issues during class definition:**
   ```ruby
   begin
     Class.new(ApplicationRecord) do
       include BetterModel
       validatable { check_complex :unknown }
     end
   rescue ArgumentError => e
     # Will catch ConfigurationError and invalid parameters
     puts "Configuration error: #{e.message}"
   end
   ```

4. **Check error messages when rescuing ArgumentError:**
   ```ruby
   rescue ArgumentError => e
     if e.is_a?(BetterModel::Errors::Validatable::ConfigurationError)
       # BetterModel configuration issue
     elsif e.message.include?("Unknown complex validation")
       # Configurator parameter issue
     else
       # Standard ArgumentError from elsewhere
       raise
     end
   end
   ```

5. **Log errors appropriately:**
   ```ruby
   rescue BetterModel::Errors::Validatable::ConfigurationError => e
     # Configuration errors are developer mistakes - warn level
     Rails.logger.warn "Configuration error: #{e.message}"

   rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
     # Runtime errors are expected in normal operation - info level
     Rails.logger.info "Invalid transition attempt: #{e.event} from #{e.from_state}"

   rescue BetterModel::Errors::BetterModelError => e
     # Unexpected errors should be logged at error level
     Rails.logger.error "Unexpected BetterModel error: #{e.class} - #{e.message}"
   end
   ```

6. **Provide user-friendly messages in controllers:**
   ```ruby
   rescue BetterModel::Errors::Stateable::CheckFailedError => e
     # Technical error message
     Rails.logger.info "Transition check failed: #{e.failed_checks.join(', ')}"

     # User-friendly message
     flash[:error] = "Cannot perform this action: requirements not met"
     redirect_to article_path(@article)
   end
   ```

### Testing Error Scenarios

When writing tests for BetterModel features, always test error scenarios to ensure robust error handling:

**Minitest Examples:**

```ruby
class ValidatableTest < ActiveSupport::TestCase
  test "raises NotEnabledError when validatable not enabled" do
    article = Article.new

    error = assert_raises(BetterModel::Errors::Validatable::NotEnabledError) do
      article.validate_group(:step1)
    end

    assert_match /not enabled/i, error.message
  end

  test "raises ConfigurationError when including in non-AR class" do
    assert_raises(BetterModel::Errors::Validatable::ConfigurationError) do
      Class.new { include BetterModel::Validatable }
    end
  end

  test "raises ArgumentError for unknown complex validation" do
    error = assert_raises(ArgumentError) do
      Class.new(ApplicationRecord) do
        include BetterModel
        validatable { check_complex :nonexistent }
      end
    end

    assert_match /unknown complex validation/i, error.message
  end
end
```

**RSpec Examples:**

```ruby
RSpec.describe Article, type: :model do
  describe "error handling" do
    context "when validatable not enabled" do
      it "raises NotEnabledError" do
        expect { article.validate_group(:step1) }.to raise_error(
          BetterModel::Errors::Validatable::NotEnabledError,
          /not enabled/i
        )
      end
    end

    context "when configuration is invalid" do
      it "raises ConfigurationError for non-AR class" do
        expect {
          Class.new { include BetterModel::Validatable }
        }.to raise_error(BetterModel::Errors::Validatable::ConfigurationError)
      end
    end

    context "when using unknown validation" do
      it "raises ArgumentError with helpful message" do
        expect {
          Class.new(ApplicationRecord) do
            include BetterModel
            validatable { check_complex :nonexistent }
          end
        }.to raise_error(ArgumentError, /unknown complex validation/i)
      end
    end
  end
end
```

### Error Metadata

Many BetterModel errors provide additional metadata for debugging and error handling. Starting with v3.0, errors use named parameters and include Sentry-compatible attributes:

```ruby
# v3.0+ format with named parameters
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  # Direct attributes
  puts "Event: #{e.event}"           # => :publish
  puts "From: #{e.from_state}"       # => "draft"
  puts "To: #{e.to_state}"           # => "published"

  # Sentry-compatible attributes
  puts "Tags: #{e.tags}"             # => {error_category: "transition", module: "stateable", ...}
  puts "Context: #{e.context}"       # => {model_class: "Article"}
  puts "Extra: #{e.extra}"           # => {event: :publish, from_state: :draft, to_state: :published}

rescue BetterModel::Errors::Stateable::CheckFailedError => e
  puts "Check description: #{e.check_description}"  # => "Article must be complete"
  puts "Check type: #{e.check_type}"                # => "predicate"
  puts "Tags: #{e.tags}"                            # => {error_category: "check_failed", ...}

rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  puts "Invalid predicate: #{e.predicate_scope}"               # => :title_xxx
  puts "Available: #{e.available_predicates.join(', ')}"       # => "title_eq, title_cont"
  puts "Tags: #{e.tags}"                                       # => {error_category: "invalid_predicate", ...}

rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  puts "Policy name: #{e.policy_name}"              # => "max_page"
  puts "Violations: #{e.violations.join('; ')}"     # => "page exceeds maximum allowed"
  puts "Tags: #{e.tags}"                            # => {error_category: "security", ...}
```

### Debugging Tips

1. **Enable detailed error logging in development:**
   ```ruby
   # config/initializers/better_model.rb
   if Rails.env.development?
     Rails.logger.level = :debug

     # Log all BetterModel errors
     ActiveSupport::Notifications.subscribe("better_model.error") do |*args|
       event = ActiveSupport::Notifications::Event.new(*args)
       Rails.logger.debug "BetterModel Error: #{event.payload.inspect}"
     end
   end
   ```

2. **Use error metadata in error pages:**
   ```ruby
   # app/controllers/application_controller.rb
   rescue_from BetterModel::Errors::Stateable::InvalidTransitionError do |e|
     if Rails.env.development?
       render plain: "Invalid transition: #{e.event} from #{e.from_state} to #{e.to_state}", status: :unprocessable_entity
     else
       render :error, status: :unprocessable_entity
     end
   end
   ```

3. **Add error context to exception tracking (v3.0+):**
   ```ruby
   rescue BetterModel::Errors::BetterModelError => e
     # v3.0+ uses built-in Sentry-compatible attributes
     Sentry.capture_exception(e) do |scope|
       scope.set_context("error_details", e.context)
       scope.set_tags(e.tags)
       scope.set_extras(e.extra)

       # Add application-specific context
       scope.set_context("model_info", {
         id: @model.id,
         created_at: @model.created_at,
         updated_at: @model.updated_at
       })
     end
   end
   ```

### Sentry Integration (v3.0+)

Starting with version 3.0, all BetterModel errors include Sentry-compatible data structures for rich error reporting and monitoring. Each error provides three types of structured metadata:

#### Error Data Structure

All errors include three attributes for comprehensive error tracking:

1. **tags**: Filterable metadata for grouping and searching errors in Sentry
   - Always includes `error_category` (e.g., "invalid_predicate", "transition", "not_enabled")
   - Always includes `module` (e.g., "searchable", "stateable", "validatable")
   - May include error-specific tags (e.g., `predicate`, `event`, `from_state`)

2. **context**: High-level structured metadata about the error context
   - Typically includes `model_class` (e.g., "Article", "User")
   - May include module-specific context (e.g., `current_state`, `module_name`)

3. **extra**: Detailed debug data with all error-specific parameters
   - Contains all parameters passed to the error constructor
   - Useful for debugging and understanding the exact error conditions

#### Creating Errors with v3.0 Format

All errors now use named parameters for clarity and consistency:

```ruby
# Searchable errors
raise BetterModel::Errors::Searchable::InvalidPredicateError.new(
  predicate_scope: :title_xxx,
  value: "Rails",
  available_predicates: [:title_eq, :title_cont, :title_start],
  model_class: Article
)

# Stateable errors
raise BetterModel::Errors::Stateable::InvalidTransitionError.new(
  event: :publish,
  from_state: :draft,
  to_state: :published,
  model_class: Article
)

# Validatable errors
raise BetterModel::Errors::Validatable::NotEnabledError.new(
  module_name: "Validatable",
  method_called: "validate_group",
  model_class: Article
)
```

#### Accessing Error Attributes

All error attributes are accessible through reader methods:

```ruby
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  # Direct attribute access
  e.predicate_scope         # => :title_xxx
  e.value                   # => "Rails"
  e.available_predicates    # => [:title_eq, :title_cont, :title_start]
  e.model_class             # => Article

  # Sentry-compatible data
  e.tags
  # => {
  #   error_category: "invalid_predicate",
  #   module: "searchable",
  #   predicate: "title_xxx"
  # }

  e.context
  # => {
  #   model_class: "Article"
  # }

  e.extra
  # => {
  #   predicate_scope: :title_xxx,
  #   value: "Rails",
  #   available_predicates: [:title_eq, :title_cont, :title_start]
  # }
end
```

#### Direct Sentry Integration

BetterModel errors are designed to work seamlessly with Sentry's error tracking:

```ruby
# Basic Sentry integration
rescue BetterModel::Errors::BetterModelError => e
  Sentry.capture_exception(e) do |scope|
    scope.set_context("error_details", e.context)
    scope.set_tags(e.tags)
    scope.set_extras(e.extra)
  end
end

# Advanced: Add custom context
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  Sentry.capture_exception(e) do |scope|
    # BetterModel error data
    scope.set_context("error_details", e.context)
    scope.set_tags(e.tags)
    scope.set_extras(e.extra)

    # Additional application context
    scope.set_context("user", {
      id: current_user.id,
      role: current_user.role
    })
    scope.set_tags({
      controller: controller_name,
      action: action_name
    })
  end

  # Re-raise or handle appropriately
  flash[:error] = "Invalid action attempted"
  redirect_to root_path
end
```

#### Structured Logging

Use error attributes for comprehensive structured logging:

```ruby
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  Rails.logger.error({
    message: e.message,
    error_class: e.class.name,
    error_category: e.tags[:error_category],
    module: e.tags[:module],
    model: e.context[:model_class],
    details: e.extra,
    backtrace: e.backtrace.first(10)
  }.to_json)
end

# Output:
# {
#   "message": "Invalid predicate scope: :title_xxx. Available predicable scopes: title_eq, title_cont",
#   "error_class": "BetterModel::Errors::Searchable::InvalidPredicateError",
#   "error_category": "invalid_predicate",
#   "module": "searchable",
#   "model": "Article",
#   "details": {
#     "predicate_scope": "title_xxx",
#     "value": "Rails",
#     "available_predicates": ["title_eq", "title_cont", "title_start"]
#   },
#   "backtrace": [...]
# }
```

#### Building API Error Responses

Create rich API error responses using error attributes:

```ruby
# In a Rails controller
rescue_from BetterModel::Errors::BetterModelError do |e|
  render json: {
    error: {
      type: e.class.name.demodulize.underscore,
      message: e.message,
      category: e.tags[:error_category],
      module: e.tags[:module],
      context: e.context,
      details: e.extra
    }
  }, status: :unprocessable_entity
end

# Response for InvalidPredicateError:
# {
#   "error": {
#     "type": "invalid_predicate_error",
#     "message": "Invalid predicate scope: :title_xxx. Available predicable scopes: title_eq, title_cont",
#     "category": "invalid_predicate",
#     "module": "searchable",
#     "context": {
#       "model_class": "Article"
#     },
#     "details": {
#       "predicate_scope": "title_xxx",
#       "value": "Rails",
#       "available_predicates": ["title_eq", "title_cont", "title_start"]
#     }
#   }
# }
```

#### Error Enrichment Examples by Module

**Searchable Module:**

```ruby
# InvalidPredicateError
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  e.tags          # => {error_category: "invalid_predicate", module: "searchable", predicate: "title_xxx"}
  e.context       # => {model_class: "Article"}
  e.extra         # => {predicate_scope: :title_xxx, value: "Rails", available_predicates: [...]}

# InvalidSecurityError
rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  e.tags          # => {error_category: "security", module: "searchable", policy: "max_page"}
  e.context       # => {model_class: "Article"}
  e.extra         # => {policy_name: "max_page", violations: [...], requested_value: 10000}
```

**Stateable Module:**

```ruby
# InvalidTransitionError
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  e.tags          # => {error_category: "transition", module: "stateable", event: "publish", from_state: "draft", to_state: "published"}
  e.context       # => {model_class: "Article"}
  e.extra         # => {event: :publish, from_state: :draft, to_state: :published}

# CheckFailedError
rescue BetterModel::Errors::Stateable::CheckFailedError => e
  e.tags          # => {error_category: "check_failed", module: "stateable", event: "publish", check_type: "predicate"}
  e.context       # => {model_class: "Article", current_state: :draft}
  e.extra         # => {event: :publish, check_description: "Article must be complete", check_type: "predicate", current_state: :draft}
```

**Validatable Module:**

```ruby
# NotEnabledError
rescue BetterModel::Errors::Validatable::NotEnabledError => e
  e.tags          # => {error_category: "not_enabled", module: "validatable"}
  e.context       # => {model_class: "Article", module_name: "Validatable"}
  e.extra         # => {method_called: "validate_group"}
```

#### Best Practices for Error Enrichment

1. **Always capture to Sentry in production:**
   ```ruby
   rescue BetterModel::Errors::BetterModelError => e
     Sentry.capture_exception(e) do |scope|
       scope.set_context("error_details", e.context)
       scope.set_tags(e.tags)
       scope.set_extras(e.extra)
     end

     # Handle error appropriately
     render_error_response(e)
   end
   ```

2. **Use tags for filtering in Sentry:**
   - Filter by module: `module:searchable`
   - Filter by category: `error_category:invalid_predicate`
   - Filter by specific attributes: `event:publish`, `from_state:draft`

3. **Use context for high-level grouping:**
   - Group errors by model: `context.model_class:Article`
   - Understand error context at a glance

4. **Use extra for debugging:**
   - Access detailed parameters that led to the error
   - Reproduce issues locally with exact conditions

5. **Combine with application context:**
   ```ruby
   rescue BetterModel::Errors::BetterModelError => e
     Sentry.capture_exception(e) do |scope|
       # BetterModel context
       scope.set_context("error_details", e.context)
       scope.set_tags(e.tags)
       scope.set_extras(e.extra)

       # Application context
       scope.set_user(id: current_user.id, email: current_user.email)
       scope.set_tags(
         request_id: request.uuid,
         endpoint: "#{controller_name}##{action_name}"
       )
       scope.set_context("request", {
         url: request.url,
         method: request.method,
         params: request.params.except(:password)
       })
     end
   end
   ```

6. **Create reusable error handlers:**
   ```ruby
   # app/controllers/concerns/better_model_error_handler.rb
   module BetterModelErrorHandler
     extend ActiveSupport::Concern

     included do
       rescue_from BetterModel::Errors::BetterModelError, with: :handle_better_model_error
     end

     private

     def handle_better_model_error(error)
       # Log to Sentry with enriched context
       Sentry.capture_exception(error) do |scope|
         scope.set_context("error_details", error.context)
         scope.set_tags(error.tags)
         scope.set_extras(error.extra)
         scope.set_user(id: current_user&.id)
         scope.set_tags(controller: controller_name, action: action_name)
       end

       # Return appropriate response
       respond_to do |format|
         format.html do
           flash[:error] = user_friendly_message(error)
           redirect_back(fallback_location: root_path)
         end
         format.json do
           render json: api_error_response(error), status: :unprocessable_entity
         end
       end
     end

     def user_friendly_message(error)
       case error
       when BetterModel::Errors::Stateable::InvalidTransitionError
         "This action is not available in the current state"
       when BetterModel::Errors::Searchable::InvalidPredicateError
         "Invalid search parameters provided"
       when BetterModel::Errors::Validatable::NotEnabledError
         "Configuration error - please contact support"
       else
         "An error occurred while processing your request"
       end
     end

     def api_error_response(error)
       {
         error: {
           type: error.class.name.demodulize.underscore,
           message: error.message,
           category: error.tags[:error_category],
           details: error.extra
         }
       }
     end
   end
   ```

### Summary

- All BetterModel errors inherit from `BetterModel::Errors::BetterModelError`
- Configuration errors inherit from `ArgumentError` for backward compatibility
- Each module has a base error class (e.g., `ValidatableError`, `StateableError`)
- Many errors provide metadata for debugging (e.g., `e.event`, `e.failed_checks`)
- **v3.0+:** All errors include Sentry-compatible `tags`, `context`, and `extra` attributes
- **v3.0+:** All errors use named parameters for consistency and clarity
- Always test error scenarios in your test suite
- Use specific error classes for precise error handling
- Provide user-friendly messages while logging technical details
- Integrate with Sentry for production error monitoring
- Use structured error data for logging and API responses
