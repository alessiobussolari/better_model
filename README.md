# BetterModel

BetterModel is a Rails engine gem (Rails 8.1+) that provides powerful extensions for ActiveRecord models, including declarative status management, permissions, archiving, sorting, filtering, and unified search capabilities.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "better_model"
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install better_model
```

## Quick Start

Simply include `BetterModel` in your model to get all features:

```ruby
class Article < ApplicationRecord
  include BetterModel  # Includes all BetterModel concerns

  # 1. STATUSABLE - Define statuses with lambdas
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :popular, -> { view_count >= 100 }
  is :active, -> { is?(:published) && !is?(:expired) }

  # 2. PERMISSIBLE - Define permissions based on statuses
  permit :edit, -> { is?(:draft) || (is?(:published) && !is?(:expired)) }
  permit :delete, -> { is?(:draft) }
  permit :publish, -> { is?(:draft) }
  permit :unpublish, -> { is?(:published) }

  # 3. SORTABLE - Define sortable fields
  sort :title, :view_count, :published_at, :created_at

  # 4. PREDICABLE - Define searchable/filterable fields
  predicates :title, :status, :view_count, :published_at, :created_at, :featured

  # 5. ARCHIVABLE - Soft delete with tracking (opt-in)
  archivable do
    skip_archived_by_default true  # Hide archived records by default
  end

  # 6. SEARCHABLE - Configure unified search interface
  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc]
    security :status_required, [:status_eq]
  end
end
```

Now you can use all the features:

```ruby
# Check statuses
article.is?(:draft)          # => true/false
article.is_published?        # => true/false
article.statuses             # => { draft: true, published: false, ... }

# Check permissions
article.permit?(:edit)       # => true/false
article.permit_delete?       # => true/false
article.permissions          # => { edit: true, delete: true, ... }

# Sort
Article.sort_title_asc
Article.sort_view_count_desc
Article.sort_published_at_desc

# Filter with predicates
Article.status_eq("published")
Article.title_cont("Rails")
Article.view_count_gteq(100)
Article.published_at_present

# Archive records
article.archive!(by: current_user, reason: "Outdated")
article.archived?  # => true
article.restore!

# Query archived records
Article.archived
Article.not_archived
Article.archived_recently(7.days)

# Unified search with filters, sorting, and pagination
Article.search(
  { status_eq: "published", view_count_gteq: 50 },
  orders: [:sort_published_at_desc],
  pagination: { page: 1, per_page: 25 }
)
```

### Including Individual Concerns (Advanced)

If you only need specific features, you can include individual concerns:

```ruby
class Article < ApplicationRecord
  include BetterModel::Statusable    # Only status management
  include BetterModel::Permissible   # Only permissions
  include BetterModel::Archivable    # Only archiving
  include BetterModel::Sortable      # Only sorting
  include BetterModel::Predicable    # Only filtering
  include BetterModel::Searchable    # Only search (requires Predicable & Sortable)

  # Define your features...
end
```

## Requirements

- **Ruby:** 3.0 or higher
- **Rails:** 8.1 or higher
- **ActiveRecord:** Included with Rails

## Database Compatibility

BetterModel works with all databases supported by ActiveRecord:

| Database | Status | Notes |
|----------|--------|-------|
| **PostgreSQL** | ✅ Full support | Recommended. Includes array and JSONB predicates |
| **MySQL/MariaDB** | ✅ Full support | NULLS emulation for sorting |
| **SQLite** | ✅ Full support | Great for development and testing |
| **SQL Server** | ✅ Full support | Standard features work |
| **Oracle** | ✅ Full support | Standard features work |

**PostgreSQL-Specific Features:**
- Array predicates: `overlaps`, `contains`, `contained_by`
- JSONB predicates: `has_key`, `has_any_key`, `has_all_keys`, `jsonb_contains`

## Features

BetterModel provides six powerful concerns that work together seamlessly:

### 📋 Statusable - Declarative Status Management

Define derived statuses dynamically based on model attributes - no database columns needed!

**Key Benefits:**
- Declarative DSL with clear, readable conditions
- Statuses calculated in real-time from model attributes
- Reference other statuses in conditions
- Automatic method generation (`is_draft?`, `is_published?`)
- Thread-safe with immutable registry

**[📖 Full Documentation →](docs/statusable.md)**

---

### 🔐 Permissible - Declarative Permission Management

Define permissions dynamically based on model state and statuses - perfect for authorization logic!

**Key Benefits:**
- Declarative DSL following Statusable pattern
- Permissions calculated from model state
- Reference statuses in permission logic
- Automatic method generation (`permit_edit?`, `permit_delete?`)
- Thread-safe with immutable registry

**[📖 Full Documentation →](docs/permissible.md)**

---

### 🗄️ Archivable - Soft Delete with Archive Management

Soft-delete records with archive tracking, audit trails, and restoration capabilities.

**Key Benefits:**
- Opt-in activation: only enabled when explicitly configured
- Archive and restore methods with optional tracking
- Status methods: `archived?` and `active?`
- Semantic scopes: `archived`, `not_archived`, `archived_only`
- Helper predicates: `archived_today`, `archived_this_week`, `archived_recently`
- Optional default scope to hide archived records
- Migration generator with flexible options
- Thread-safe with immutable configuration

**[📖 Full Documentation →](docs/archivable.md)**

---

### ⬆️ Sortable - Type-Aware Sorting Scopes

Generate intelligent sorting scopes automatically with database-specific optimizations and NULL handling.

**Key Benefits:**
- Type-aware scope generation (string, numeric, datetime, boolean)
- Case-insensitive sorting for strings
- Database-specific NULLS FIRST/LAST support
- Sort by multiple fields with chaining
- Optimized queries with proper indexing support

**[📖 Full Documentation →](docs/sortable.md)**

---

### 🔍 Predicable - Advanced Query Scopes

Generate comprehensive predicate scopes for filtering and searching with support for all data types.

**Key Benefits:**
- Complete coverage: string, numeric, datetime, boolean, null predicates
- Type-safe predicates based on column type
- Case-insensitive string matching
- Range queries (between) for numerics and dates
- PostgreSQL array and JSONB support
- Chainable with standard ActiveRecord queries

**[📖 Full Documentation →](docs/predicable.md)**

---

### 🔎 Searchable - Unified Search Interface

Orchestrate Predicable and Sortable into a powerful, secure search interface with pagination and security.

**Key Benefits:**
- Unified API: single `search()` method for all operations
- OR conditions for complex logic
- Built-in pagination with DoS protection (max_per_page)
- Security enforcement with required predicates
- Default ordering configuration
- Strong parameters integration
- Type-safe validation of all parameters

**[📖 Full Documentation →](docs/searchable.md)**

---

### 📜 Traceable - Audit Trail & Change Tracking

Track all changes to your records with comprehensive audit trail functionality, time-travel queries, and rollback capabilities.

**Key Benefits:**
- Opt-in activation: only enabled when explicitly configured
- Automatic change tracking on create/update/destroy
- Time-travel: reconstruct record state at any point in time
- Rollback: restore to previous versions
- Audit trail with who/why tracking
- Query changes by user, date range, or field transitions
- Flexible table naming: per-model tables (default), shared table, or custom names

**[📖 Full Documentation →](docs/traceable.md)**

#### Quick Setup

**Step 1: Create the versions table**

By default, each model gets its own versions table (`{model}_versions`):

```bash
# Creates migration for article_versions table
rails g better_model:traceable Article --create-table
rails db:migrate
```

Or use a custom table name:

```bash
# Creates migration for custom table name
rails g better_model:traceable Article --create-table --table-name=audit_log
rails db:migrate
```

**Step 2: Enable in your model**

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Activate traceable (opt-in)
  traceable do
    track :status, :title, :published_at  # Fields to track
    # versions_table 'audit_log'  # Optional: custom table (default: article_versions)
  end
end
```

**Usage:**

```ruby
# Automatic tracking on changes
article.update!(status: "published", updated_by_id: user.id, updated_reason: "Approved")

# Query version history
article.versions                              # All versions (ordered desc)
article.changes_for(:status)                  # Changes for specific field
article.audit_trail                           # Full formatted history

# Time-travel: reconstruct state at specific time
past_article = article.as_of(3.days.ago)
past_article.status                           # => "draft" (what it was 3 days ago)

# Rollback to previous version
version = article.versions.where(event: "updated").first
article.rollback_to(version, updated_by_id: user.id, updated_reason: "Mistake")

# Class-level queries
Article.changed_by(user.id)                   # Records changed by user
Article.changed_between(1.week.ago, Time.current)  # Changes in period
Article.status_changed_from("draft").to("published")  # Specific transitions (PostgreSQL)

# Integration with as_json
article.as_json(include_audit_trail: true)    # Include full history in JSON
```

**Database Schema:**

By default, each model gets its own versions table (e.g., `article_versions` for Article model).
You can also use a shared table across multiple models or a custom table name.

| Column | Type | Description |
|--------|------|-------------|
| `item_type` | string | Polymorphic model name |
| `item_id` | integer | Polymorphic record ID |
| `event` | string | Event type: created/updated/destroyed |
| `object_changes` | json | Before/after values for tracked fields |
| `updated_by_id` | integer | Optional: user who made the change |
| `updated_reason` | string | Optional: reason for the change |
| `created_at` | datetime | When the change occurred |

**Table Naming Options:**

```ruby
# Option 1: Per-model table (default)
class Article < ApplicationRecord
  traceable do
    track :status
    # Uses article_versions table automatically
  end
end

# Option 2: Custom table name
class Article < ApplicationRecord
  traceable do
    track :status
    versions_table 'audit_log'  # Uses audit_log table
  end
end

# Option 3: Shared table across models
class Article < ApplicationRecord
  traceable do
    track :status
    versions_table 'versions'  # Shared table
  end
end

class User < ApplicationRecord
  traceable do
    track :email
    versions_table 'versions'  # Same shared table
  end
end
```

**Optional Tracking:**

To track who made changes and why, simply set attributes before saving:

```ruby
article.updated_by_id = current_user.id
article.updated_reason = "Fixed typo"
article.update!(title: "Corrected Title")

# The version will automatically include updated_by_id and updated_reason
```

---

## Version & Changelog

**Current Version:** 1.0.0

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Support & Community

- **Issues & Bugs:** [GitHub Issues](https://github.com/alessiobussolari/better_model/issues)
- **Source Code:** [GitHub Repository](https://github.com/alessiobussolari/better_model)
- **Documentation:** This README and detailed docs in `docs/` directory

## Contributing

We welcome contributions! Here's how you can help:

### Reporting Bugs

1. Check if the issue already exists in [GitHub Issues](https://github.com/alessiobussolari/better_model/issues)
2. Create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Ruby/Rails versions
   - Database adapter

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Run the test suite (`bundle exec rake test`)
5. Ensure RuboCop passes (`bundle exec rubocop`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/better_model.git
cd better_model

# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Run SimpleCov for coverage
bundle exec rake test  # Coverage report in coverage/index.html

# Run RuboCop
bundle exec rubocop
```

### Code Guidelines

- Follow the existing code style (enforced by RuboCop Omakase)
- Write tests for new features
- Update documentation (README) for user-facing changes
- Keep pull requests focused (one feature/fix per PR)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
