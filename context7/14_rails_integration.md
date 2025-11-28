# BetterModel Rails Integration

Rails integration via Railtie: auto-config, rake tasks, and generators.

## Rake Tasks

### Configuration

```bash
# View configuration
rake better_model:config

# Reset to defaults
rake better_model:reset_config
```

### Introspection

```bash
# List modules
rake better_model:modules

# List models using BetterModel
rake better_model:models

# Detailed model info
rake better_model:model_info MODEL=Article
```

### Health & Stats

```bash
# Health check (tables, config)
rake better_model:health

# Statistics
rake better_model:stats:tags      # Tag counts
rake better_model:stats:states    # State distribution
rake better_model:stats:archives  # Archive rates
```

## Generators

```bash
# Archivable (soft delete columns)
rails generate better_model:archivable Product

# Stateable (state machine + transitions table)
rails generate better_model:stateable Order

# Traceable (versions table)
rails generate better_model:traceable User

# Taggable (tags array column)
rails generate better_model:taggable Article

# Repository (repository class)
rails generate better_model:repository Article

# Run migrations
rails db:migrate
```

## Task Output Examples

### better_model:config

```
=== BetterModel Configuration ===

Searchable:
  max_per_page:        100
  default_per_page:    25

Stateable:
  default_table_name:  state_transitions

Global:
  strict_mode:         true
  logger:              ActiveSupport::Logger
```

### better_model:models

```
=== BetterModel Module Usage ===

Article:
  - Searchable
      predicates: 5
  - Stateable
      states: 3
      events: 2
  - Traceable
      enabled: true

Total: 1 models using BetterModel
```

### better_model:health

```
=== BetterModel Health Check ===

✓ Strict mode is enabled
✓ Logger is configured
✓ State transitions table 'state_transitions' exists

✓ All health checks passed
```

### better_model:stats:states

```
=== BetterModel State Distribution ===

Article (status):
  draft               12 (24.0%) ████
  published           35 (70.0%) ██████████████
  archived             3 ( 6.0%) █
```

## Rails Configuration

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  config.searchable_max_per_page = 100
  config.strict_mode = Rails.env.development?
  config.logger = Rails.logger
end
```

## Console Usage

```ruby
# Rails console
rails c

# Check config
BetterModel.configuration.to_h

# Check model capabilities
Article.searchable_predicates
Article.sortable_fields
Article.state_machine_config
Article.traceable_enabled?
```
