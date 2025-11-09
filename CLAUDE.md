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

Many BetterModel errors provide additional metadata for debugging and error handling:

```ruby
rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
  puts "Event: #{e.event}"           # => :publish
  puts "From: #{e.from_state}"       # => "draft"
  puts "To: #{e.to_state}"           # => "published"

rescue BetterModel::Errors::Stateable::CheckFailedError => e
  puts "Failed checks: #{e.failed_checks}"  # => ["valid?", "can_publish?"]

rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  puts "Invalid predicate: #{e.predicate}"          # => "unknown_scope"
  puts "Available: #{e.available_predicates.join(', ')}"

rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  puts "Security name: #{e.security_name}"           # => :status_required
  puts "Required: #{e.required_predicates.join(', ')}"  # => ["status_eq"]
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

3. **Add error context to exception tracking:**
   ```ruby
   rescue BetterModel::Errors::BetterModelError => e
     # Send to error tracking service with context
     Sentry.capture_exception(e, extra: {
       error_class: e.class.name,
       model: @model.class.name,
       model_id: @model.id,
       metadata: e.respond_to?(:metadata) ? e.metadata : {}
     })
   end
   ```

### Summary

- All BetterModel errors inherit from `BetterModel::Errors::BetterModelError`
- Configuration errors inherit from `ArgumentError` for backward compatibility
- Each module has a base error class (e.g., `ValidatableError`, `StateableError`)
- Many errors provide metadata for debugging (e.g., `e.event`, `e.failed_checks`)
- Always test error scenarios in your test suite
- Use specific error classes for precise error handling
- Provide user-friendly messages while logging technical details
