# BetterModel Configuration

BetterModel provides a centralized configuration system to customize default behaviors across all modules.

## Table of Contents

1. [Basic Configuration](#basic-configuration)
2. [Configuration Options](#configuration-options)
3. [Rails Integration](#rails-integration)
4. [Strict Mode](#strict-mode)
5. [Logging](#logging)
6. [Resetting Configuration](#resetting-configuration)

---

## Basic Configuration

Configure BetterModel in an initializer:

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  # Searchable defaults
  config.searchable_max_per_page = 100
  config.searchable_default_per_page = 25
  config.searchable_strict_predicates = false

  # Traceable defaults
  config.traceable_default_table_name = nil  # Uses model-specific default

  # Stateable defaults
  config.stateable_default_table_name = "state_transitions"

  # Archivable defaults
  config.archivable_skip_archived_by_default = false

  # Global settings
  config.strict_mode = Rails.env.development?
  config.logger = Rails.logger
end
```

---

## Configuration Options

### Searchable Options

| Option | Default | Description |
|--------|---------|-------------|
| `searchable_max_per_page` | `100` | Maximum records per page for pagination |
| `searchable_default_per_page` | `25` | Default records per page when not specified |
| `searchable_strict_predicates` | `false` | Raise error on unknown predicates |

```ruby
BetterModel.configure do |config|
  config.searchable_max_per_page = 50      # Limit to 50 records per page
  config.searchable_default_per_page = 10  # Default to 10 records
  config.searchable_strict_predicates = true  # Fail fast on typos
end
```

### Traceable Options

| Option | Default | Description |
|--------|---------|-------------|
| `traceable_default_table_name` | `nil` | Default table for version records (nil = model-specific) |

```ruby
BetterModel.configure do |config|
  # Use a shared versions table for all models
  config.traceable_default_table_name = "audit_logs"
end
```

### Stateable Options

| Option | Default | Description |
|--------|---------|-------------|
| `stateable_default_table_name` | `"state_transitions"` | Table name for state transition history |

```ruby
BetterModel.configure do |config|
  config.stateable_default_table_name = "workflow_transitions"
end
```

### Archivable Options

| Option | Default | Description |
|--------|---------|-------------|
| `archivable_skip_archived_by_default` | `false` | Exclude archived records by default |

```ruby
BetterModel.configure do |config|
  # All queries automatically exclude archived records
  config.archivable_skip_archived_by_default = true
end
```

### Global Options

| Option | Default | Description |
|--------|---------|-------------|
| `strict_mode` | `false` | Raise errors instead of logging warnings |
| `logger` | `nil` | Logger instance (defaults to Rails.logger if available) |

---

## Rails Integration

BetterModel integrates with Rails via a Railtie. You can configure it through Rails config:

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    # Configure BetterModel via Rails config
    config.better_model.searchable_max_per_page = 100
    config.better_model.strict_mode = true
  end
end
```

Or through an initializer (recommended):

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  config.searchable_max_per_page = 100
  config.strict_mode = Rails.env.development?
end
```

The Railtie automatically:
- Syncs `config.better_model` settings to `BetterModel.configuration`
- Sets the logger to `Rails.logger` if not explicitly set
- Loads rake tasks
- Provides console helpers

---

## Strict Mode

Strict mode changes how BetterModel handles warnings:

```ruby
BetterModel.configure do |config|
  config.strict_mode = true  # Raises errors
  # vs
  config.strict_mode = false # Logs warnings (default)
end
```

### When Strict Mode is Enabled

Errors are raised for:
- Configuration issues
- Invalid predicate usage
- Module misuse

### When Strict Mode is Disabled

Warnings are logged instead:

```ruby
# With strict_mode = false
[BetterModel] Warning: Unknown predicate 'title_xyz' ignored
```

### Recommended Setup

```ruby
BetterModel.configure do |config|
  # Strict in development/test, lenient in production
  config.strict_mode = !Rails.env.production?
end
```

---

## Logging

BetterModel uses a configurable logger for warnings and debug information:

```ruby
BetterModel.configure do |config|
  # Use Rails logger
  config.logger = Rails.logger

  # Or use a custom logger
  config.logger = Logger.new(STDOUT)

  # Or disable logging
  config.logger = nil
end
```

### Log Methods

The configuration provides helper methods:

```ruby
# Access through configuration
BetterModel.configuration.warn("Something might be wrong")
BetterModel.configuration.info("Operation completed")
BetterModel.configuration.debug("Detailed information")
```

### Log Levels

- **warn**: Warnings (or errors in strict mode)
- **info**: Informational messages
- **debug**: Detailed debug output

---

## Resetting Configuration

Reset to default values:

```ruby
# Reset all configuration
BetterModel.reset_configuration!

# Access current configuration
config = BetterModel.configuration
puts config.searchable_max_per_page  # => 100 (default)
```

### Viewing Configuration

Use rake tasks to view current configuration:

```bash
# Show all configuration
rake better_model:config

# Output:
# === BetterModel Configuration ===
#
# Searchable:
#   max_per_page:        100
#   default_per_page:    25
#   strict_predicates:   false
#
# Traceable:
#   default_table_name:  (model-specific)
#
# Stateable:
#   default_table_name:  state_transitions
#
# Archivable:
#   skip_archived_by_default: false
#
# Global:
#   strict_mode:         false
#   logger:              ActiveSupport::Logger
```

---

## Configuration as Hash

Export configuration for inspection:

```ruby
BetterModel.configuration.to_h
# => {
#   searchable: {
#     max_per_page: 100,
#     default_per_page: 25,
#     strict_predicates: false
#   },
#   traceable: {
#     default_table_name: nil
#   },
#   stateable: {
#     default_table_name: "state_transitions"
#   },
#   archivable: {
#     skip_archived_by_default: false
#   },
#   global: {
#     strict_mode: false,
#     logger: "ActiveSupport::Logger"
#   }
# }
```

---

## Environment-Specific Configuration

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  # Common settings
  config.searchable_max_per_page = 100
  config.stateable_default_table_name = "state_transitions"

  # Environment-specific
  case Rails.env
  when "development"
    config.strict_mode = true
    config.logger = Rails.logger
  when "test"
    config.strict_mode = true
    config.logger = nil  # Quiet during tests
  when "production"
    config.strict_mode = false
    config.logger = Rails.logger
  end
end
```

---

## Best Practices

1. **Always configure in an initializer** - Ensures settings are loaded before models

2. **Use strict mode in development** - Catches issues early

3. **Set appropriate pagination limits** - Prevent excessive queries

4. **Configure logging** - Helps with debugging

5. **Document your configuration** - Future developers will thank you

```ruby
# config/initializers/better_model.rb

# BetterModel Configuration
# =========================
# This file configures BetterModel defaults for our application.
# See https://github.com/alessiobussolari/better_model for documentation.

BetterModel.configure do |config|
  # Pagination: limit to 50 per page to keep responses fast
  config.searchable_max_per_page = 50
  config.searchable_default_per_page = 20

  # Archivable: always exclude archived by default
  config.archivable_skip_archived_by_default = true

  # Strict mode for development
  config.strict_mode = Rails.env.development? || Rails.env.test?

  # Use Rails logger
  config.logger = Rails.logger
end
```
