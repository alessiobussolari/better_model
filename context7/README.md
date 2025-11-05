# BetterModel Context7 Examples

This folder contains curated, practical code examples for each BetterModel feature, specifically designed for AI assistants and developers using Context7.

## Structure

Each file demonstrates a complete, working implementation of a specific feature:

### Core Features (Always Available)

1. **01_statusable.md** - Dynamic boolean statuses with conditional logic
2. **02_permissible.md** - Instance-level permission management with action checks
3. **03_predicable.md** - Type-aware filtering with query scopes and predicates
4. **04_sortable.md** - Type-aware sorting with auto-generated scopes

### Opt-in Features (Require Activation)

5. **05_searchable.md** - Unified search orchestrating Predicable, Sortable with pagination and security
6. **06_archivable.md** - Soft delete system with archive tracking and restoration
7. **07_validatable.md** - Declarative validation with conditional rules, cross-field comparisons, business rules, and validation groups
8. **08_stateable.md** - State machines with guards, validations, callbacks, and transition history
9. **09_traceable.md** - Comprehensive audit trail with time travel, sensitive data protection, and version history
10. **10_taggable.md** - Flexible tag management with normalization, validation, statistics, and array storage

## Quick Start

```ruby
# Basic setup - include BetterModel to get core features
class Product < ApplicationRecord
  include BetterModel

  # Now you have access to core features:
  # - Statusable (status declarations)
  # - Permissible (permission declarations)
  # - Predicable (dynamic predicates)
  # - Sortable (flexible sorting)

  # Opt-in features require explicit activation:
  # predicates :name, :price, :stock  # Configure first
  # sort :name, :price                # Configure sorting
  # searchable do                     # Then activate search
  #   per_page 25
  #   max_per_page 100
  # end
end
```

## Installation

Add to your Gemfile:

```ruby
gem 'better_model', '~> 2.1.0'
```

Run:

```bash
bundle install
```

## Requirements

- Rails 8.1+
- Ruby 3.0+
- PostgreSQL (recommended for advanced features) or SQLite/MySQL

## Generators

For opt-in features that require database columns:

```bash
# Archivable - adds archived_at column
rails generate better_model:archivable Product

# Stateable - adds state and transitions columns
rails generate better_model:stateable Order

# Traceable - creates version_records table
rails generate better_model:traceable User

# Taggable - adds tags JSONB column
rails generate better_model:taggable Article

# Run migrations
rails db:migrate
```

## Examples Overview

Each example file is:
- **Self-contained**: Can be copied and adapted directly
- **Commented**: Explains what each part does
- **Practical**: Shows real-world use cases
- **Complete**: Includes model setup, usage, and queries

## Support

- GitHub: https://github.com/alessiobussolari/better_model
- Issues: https://github.com/alessiobussolari/better_model/issues
