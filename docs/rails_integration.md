# Rails Integration

BetterModel integrates seamlessly with Rails applications through a Railtie, providing automatic configuration, rake tasks, and console helpers.

## Table of Contents

1. [Installation](#installation)
2. [Railtie Features](#railtie-features)
3. [Rake Tasks](#rake-tasks)
4. [Generators](#generators)
5. [Console Helpers](#console-helpers)
6. [Configuration via Rails](#configuration-via-rails)

---

## Installation

Add BetterModel to your Gemfile:

```ruby
gem 'better_model', '~> 3.0'
```

Run bundle install:

```bash
bundle install
```

The Railtie automatically loads when Rails starts. No additional setup required.

---

## Railtie Features

The BetterModel Railtie provides:

1. **Automatic Configuration** - Syncs Rails config to BetterModel
2. **Logger Integration** - Uses Rails.logger by default
3. **Rake Tasks** - Introspection and maintenance commands
4. **Console Helpers** - Development conveniences

### Initialization Order

1. Rails initializes the application
2. BetterModel Railtie runs `better_model.configure` initializer
3. Configuration from `config.better_model` is applied
4. Logger is set to `Rails.logger` if not configured

---

## Rake Tasks

BetterModel provides several rake tasks for introspection and maintenance.

### Configuration Tasks

```bash
# Show current configuration
rake better_model:config
```

Output:
```
=== BetterModel Configuration ===

Searchable:
  max_per_page:        100
  default_per_page:    25
  strict_predicates:   false

Traceable:
  default_table_name:  (model-specific)

Stateable:
  default_table_name:  state_transitions

Archivable:
  skip_archived_by_default: false

Global:
  strict_mode:         false
  logger:              ActiveSupport::Logger
```

```bash
# Reset configuration to defaults
rake better_model:reset_config
```

### Module Tasks

```bash
# List all available modules
rake better_model:modules
```

Output:
```
=== BetterModel Modules ===

  ✓ Archivable
  ✓ Permissible
  ✓ Predicable
  ✓ Repositable
  ✓ Searchable
  ✓ Sortable
  ✓ Stateable
  ✓ Statusable
  ✓ Taggable
  ✓ Traceable
  ✓ Validatable

Total: 11 modules
```

### Model Introspection

```bash
# Show all models using BetterModel
rake better_model:models
```

Output:
```
=== BetterModel Module Usage ===

Article:
  - Searchable
      predicates: 5
  - Sortable
      sortable fields: 3
  - Stateable
      states: 3
      events: 2
  - Traceable
      enabled: true

Order:
  - Archivable
  - Stateable
      states: 5
      events: 4

Total: 2 models using BetterModel
```

```bash
# Show detailed info for a specific model
rake better_model:model_info MODEL=Article
```

Output:
```
=== Article BetterModel Info ===

Searchable Predicates:
  - title_eq
  - title_cont
  - status_eq
  - published_at_gt
  - published_at_lt

Sortable Fields:
  - title
  - created_at
  - published_at

Sortable Scopes:
  - sort_title_asc
  - sort_title_desc
  - sort_created_at_newest
  - sort_published_at_desc

State Machine:
  Column: status
  Initial: draft

  States:
    - draft
    - published
    - archived

  Events:
    - publish: [:draft] -> published
    - archive: [:draft, :published] -> archived

Traceable:
  Enabled: true
  Tracked fields: title, body, status
  Ignored fields: updated_at
```

### Health Check

```bash
# Check BetterModel health
rake better_model:health
```

Output:
```
=== BetterModel Health Check ===

✓ Strict mode is enabled
✓ Logger is configured
✓ State transitions table 'state_transitions' exists
✓ Versions table 'article_versions' exists for Article

✓ All health checks passed
```

Or with issues:
```
=== BetterModel Health Check ===

Warnings:
  ⚠ Strict mode is disabled (errors will be logged as warnings)

Errors:
  ✗ State transitions table 'state_transitions' does not exist (run migrations)
  ✗ Versions table 'article_versions' does not exist for Article
```

### Statistics Tasks

```bash
# Show tag statistics
rake better_model:stats:tags
```

Output:
```
=== BetterModel Tag Statistics ===

Article:
  Total unique tags: 45
  Top 5 tags:
    - ruby: 23
    - rails: 18
    - tutorial: 12
    - beginner: 8
    - advanced: 5
```

```bash
# Show state distribution
rake better_model:stats:states
```

Output:
```
=== BetterModel State Distribution ===

Article (status):
  draft               12 (24.0%) ████
  published           35 (70.0%) ██████████████
  archived             3 ( 6.0%) █

Order (state):
  pending             45 (30.0%) ██████
  processing          15 (10.0%) ██
  shipped             75 (50.0%) ██████████
  delivered           15 (10.0%) ██
```

```bash
# Show archive statistics
rake better_model:stats:archives
```

Output:
```
=== BetterModel Archive Statistics ===

Article:
  Total:    150
  Active:   147
  Archived: 3
  Archive rate: 2.0%
```

---

## Generators

BetterModel provides generators for opt-in features that require database migrations.

### Archivable Generator

```bash
rails generate better_model:archivable Product
```

Creates migration adding:
- `archived_at` (datetime)
- `archived_by_id` (integer, optional)
- `archive_reason` (string, optional)
- `status_before_archive` (string, optional)

### Stateable Generator

```bash
rails generate better_model:stateable Order
```

Creates migration for:
- State column on model
- `state_transitions` table for history

### Traceable Generator

```bash
rails generate better_model:traceable User
```

Creates migration for:
- `user_versions` table (or custom table name)

### Taggable Generator

```bash
rails generate better_model:taggable Article
```

Creates migration adding:
- `tags` column (PostgreSQL array or JSON)

### Repository Generator

```bash
rails generate better_model:repository Article
```

Creates:
- `app/repositories/article_repository.rb`

### Running Migrations

After generating, run migrations:

```bash
rails db:migrate
```

---

## Console Helpers

In development and test environments, BetterModel provides console helpers:

```ruby
# Rails console
rails console

# Access configuration
BetterModel.configuration
# => #<BetterModel::Configuration:0x...>

# View configuration hash
BetterModel.configuration.to_h

# Check if module is enabled on a model
Article.respond_to?(:searchable_predicates)  # => true
Article.stateable_enabled?                    # => true

# Inspect model capabilities
Article.sortable_fields
Article.searchable_predicates
Article.state_machine_config
```

---

## Configuration via Rails

### Option 1: Rails Config (application.rb)

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    config.better_model.searchable_max_per_page = 100
    config.better_model.strict_mode = true
  end
end
```

### Option 2: Initializer (Recommended)

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  config.searchable_max_per_page = 100
  config.strict_mode = Rails.env.development?
  config.logger = Rails.logger
end
```

### Option 3: Environment Files

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.better_model.strict_mode = true
end

# config/environments/production.rb
Rails.application.configure do
  config.better_model.strict_mode = false
end
```

---

## Task Reference

| Task | Description |
|------|-------------|
| `better_model:config` | Show current configuration |
| `better_model:reset_config` | Reset to defaults |
| `better_model:modules` | List available modules |
| `better_model:models` | Show models using BetterModel |
| `better_model:model_info MODEL=X` | Detailed model info |
| `better_model:health` | Health check |
| `better_model:stats:tags` | Tag statistics |
| `better_model:stats:states` | State distribution |
| `better_model:stats:archives` | Archive statistics |

---

## Troubleshooting

### Rake Tasks Not Found

Ensure BetterModel is properly loaded:

```ruby
# Check in Rails console
defined?(BetterModel::Railtie)  # Should return "constant"
```

### Configuration Not Applied

Check initialization order:

```ruby
# config/initializers/better_model.rb
Rails.application.config.after_initialize do
  puts BetterModel.configuration.to_h
end
```

### Logger Not Working

Ensure logger is configured:

```ruby
BetterModel.configure do |config|
  config.logger = Rails.logger
end

# Or check effective logger
BetterModel.configuration.effective_logger
```
