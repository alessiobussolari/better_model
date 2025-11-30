# BetterModel Configuration

Global configuration system for BetterModel defaults.

## Basic Setup

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  # Searchable
  config.searchable_max_per_page = 100
  config.searchable_default_per_page = 25
  config.searchable_strict_predicates = false

  # Traceable
  config.traceable_default_table_name = nil

  # Stateable
  config.stateable_default_table_name = "state_transitions"

  # Archivable
  config.archivable_skip_archived_by_default = false

  # Global
  config.strict_mode = Rails.env.development?
  config.logger = Rails.logger
end
```

## Configuration Options

### Searchable

| Option | Default | Description |
|--------|---------|-------------|
| `searchable_max_per_page` | 100 | Max records per page |
| `searchable_default_per_page` | 25 | Default per page |
| `searchable_strict_predicates` | false | Error on unknown predicates |

### Module Tables

| Option | Default | Description |
|--------|---------|-------------|
| `traceable_default_table_name` | nil | Versions table (model-specific if nil) |
| `stateable_default_table_name` | "state_transitions" | Transitions table |

### Archivable

| Option | Default | Description |
|--------|---------|-------------|
| `archivable_skip_archived_by_default` | false | Auto-exclude archived |

### Global

| Option | Default | Description |
|--------|---------|-------------|
| `strict_mode` | false | Raise errors vs log warnings |
| `logger` | nil | Logger (Rails.logger if available) |

## Strict Mode

```ruby
# Development: raise errors immediately
config.strict_mode = true

# Production: log warnings
config.strict_mode = false
```

## Environment-Specific

```ruby
BetterModel.configure do |config|
  config.strict_mode = !Rails.env.production?
  config.logger = Rails.logger if Rails.env.development?
end
```

## Access & Reset

```ruby
# Access current config
BetterModel.configuration.searchable_max_per_page  # => 100

# Reset to defaults
BetterModel.reset_configuration!

# Export as hash
BetterModel.configuration.to_h
```

## Rails Integration

```ruby
# Via Rails config (config/application.rb)
config.better_model.strict_mode = true

# Via initializer (recommended)
BetterModel.configure do |config|
  config.strict_mode = true
end
```
