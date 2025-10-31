# BetterModel 🚀

BetterModel is a Rails engine gem (Rails 8.1+) that provides powerful extensions for ActiveRecord models, including declarative status management, permissions, state machines, validations, archiving, change tracking, sorting, filtering, and unified search capabilities.

## 📦 Installation

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

## ⚡ Quick Start

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

  # 6. VALIDATABLE - Declarative validation system (opt-in)
  validatable do
    # Basic validations
    validate :title, :content, presence: true

    # Conditional validations
    validate_if :is_published? do
      validate :published_at, presence: true
    end

    # Cross-field validations
    validate_order :starts_at, :before, :ends_at

    # Business rules
    validate_business_rule :valid_category

    # Validation groups (multi-step forms)
    validation_group :step1, [:title, :content]
    validation_group :step2, [:published_at]
  end

  # 7. STATEABLE - Declarative state machine (opt-in)
  stateable do
    # Define states
    state :draft, initial: true
    state :published
    state :archived

    # Define transitions with guards and callbacks
    transition :publish, from: :draft, to: :published do
      guard { valid? }
      guard if: :is_ready_for_publishing?  # Statusable integration
      before { set_published_at }
      after { notify_subscribers }
    end

    transition :archive, from: [:draft, :published], to: :archived
  end

  # 8. TRACEABLE - Audit trail with time-travel (opt-in)
  traceable do
    track :title, :content, :status, :published_at
    track :password_hash, sensitive: :full    # Complete redaction
    track :credit_card, sensitive: :partial   # Pattern-based masking
    track :api_token, sensitive: :hash        # SHA256 hashing
    versions_table :article_versions  # Optional: custom table
  end

  # 9. SEARCHABLE - Configure unified search interface
  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc]
    security :status_required, [:status_eq]
  end

  # 10. TAGGABLE - Tag management with statistics (opt-in)
  taggable do
    tag_field :tags
    normalize true         # Automatic lowercase
    strip true             # Remove whitespace
    min_length 2           # Minimum tag length
    max_length 30          # Maximum tag length
    delimiter ","          # CSV delimiter
    validates_tags minimum: 1, maximum: 10
  end
end
```

💡 **Now you can use all the features:**

```ruby
# ✅ Check statuses
article.is?(:draft)          # => true/false
article.is_published?        # => true/false
article.statuses             # => { draft: true, published: false, ... }

# 🔐 Check permissions
article.permit?(:edit)       # => true/false
article.permit_delete?       # => true/false
article.permissions          # => { edit: true, delete: true, ... }

# ⬆️ Sort
Article.sort_title_asc
Article.sort_view_count_desc
Article.sort_published_at_desc

# 🔍 Filter with predicates
Article.status_eq("published")
Article.title_cont("Rails")
Article.view_count_gteq(100)
Article.published_at_present

# 🗄️ Archive records
article.archive!(by: current_user, reason: "Outdated")
article.archived?  # => true
article.restore!

# 📂 Query archived records
Article.archived
Article.not_archived
Article.archived_recently(7.days)

# ✅ Validate with groups (multi-step forms)
article.valid?(:step1)  # Validate only step1 fields
article.valid?(:step2)  # Validate only step2 fields
article.errors_for_group(:step1)  # Get errors for step1 only

# 🔄 State machine transitions
article.state            # => "draft"
article.draft?           # => true
article.can_publish?     # => true (checks guards)
article.publish!         # Executes transition with guards & callbacks
article.published?       # => true
article.state_transitions  # History of all transitions
article.transition_history # Formatted history array

# ⏰ Time travel & rollback (Traceable)
article.audit_trail              # Full change history
article.as_of(3.days.ago)        # Reconstruct past state
article.rollback_to(version)     # Restore to previous version
article.changes_for(:status)     # Changes for specific field

# 🔍 Query changes
Article.changed_by(user.id)
Article.changed_between(1.week.ago, Time.current)
Article.status_changed_from("draft").to("published")

# 🔎 Unified search with filters, sorting, and pagination
Article.search(
  { status_eq: "published", view_count_gteq: 50 },
  orders: [:sort_published_at_desc],
  pagination: { page: 1, per_page: 25 }
)

# 🏷️ Manage tags
article.tag_with("ruby", "rails", "tutorial")
article.untag("tutorial")
article.tagged_with?("ruby")  # => true
article.tag_list = "ruby, rails, api"

# 📊 Query with tags (via Predicable)
Article.tags_contains("ruby")
Article.tags_overlaps(["ruby", "python"])
Article.tags_contains_all(["ruby", "rails"])

# 📈 Tag statistics
Article.tag_counts                    # => {"ruby" => 45, "rails" => 38}
Article.popular_tags(limit: 10)       # => [["ruby", 45], ["rails", 38]]
Article.related_tags("ruby", limit: 5)  # => ["rails", "gem", "tutorial"]
```

### 🎯 Including Individual Concerns (Advanced)

If you only need specific features, you can include individual concerns:

```ruby
class Article < ApplicationRecord
  include BetterModel::Statusable    # Only status management
  include BetterModel::Permissible   # Only permissions
  include BetterModel::Archivable    # Only archiving
  include BetterModel::Traceable     # Only audit trail & time-travel
  include BetterModel::Sortable      # Only sorting
  include BetterModel::Predicable    # Only filtering
  include BetterModel::Validatable   # Only validations
  include BetterModel::Stateable     # Only state machine
  include BetterModel::Searchable    # Only search (requires Predicable & Sortable)
  include BetterModel::Taggable      # Only tag management

  # Define your features...
end
```

## 🛠️ Generators

Better Model provides Rails generators to help you quickly set up migrations for features that require database tables or columns.

### Traceable Generator

Create migrations for audit trail version tables:

```bash
# Basic usage - shows setup instructions
rails g better_model:traceable Article

# Create migration for versions table
rails g better_model:traceable Article --create-table

# Custom table name
rails g better_model:traceable Article --create-table --table-name=audit_log

# Run migrations
rails db:migrate
```

**Generated migration includes:**
- Polymorphic association (`item_type`, `item_id`)
- Event tracking (`created`, `updated`, `destroyed`)
- Change tracking (`object_changes` as JSON)
- User attribution (`updated_by_id`)
- Change reason (`updated_reason`)
- Optimized indexes

### Archivable Generator

Add soft-delete columns to existing models:

```bash
# Basic usage - shows setup instructions
rails g better_model:archivable Article

# Add archivable columns to articles table
rails g better_model:archivable Article --create-columns

# Run migrations
rails db:migrate
```

**Generated migration adds:**
- `archived_at` (datetime) - when archived
- `archived_by_id` (integer) - who archived it
- `archive_reason` (string) - why archived
- Index on `archived_at`

### Stateable Generator

Create state machine with state column and transitions tracking:

```bash
# Basic usage - shows setup instructions
rails g better_model:stateable Article

# Create both state column and transitions table
rails g better_model:stateable Article --create-tables

# Custom initial state (default: draft)
rails g better_model:stateable Article --create-tables --initial-state=pending

# Custom transitions table name
rails g better_model:stateable Article --create-tables --table-name=article_state_history

# Run migrations
rails db:migrate
```

**Generated migrations include:**
1. **State column migration:**
   - `state` (string) with default value and index

2. **Transitions table migration:**
   - Polymorphic association (`transitionable_type`, `transitionable_id`)
   - Event name and state tracking
   - Optional metadata (JSON)
   - Optimized indexes

### Generator Options

All generators support these common options:

- `--pretend` - Dry run, show what would be generated
- `--skip-model` - Only generate migrations, don't show model setup instructions
- `--force` - Overwrite existing files

**Example workflow:**

```bash
# 1. Generate migrations (dry-run first to preview)
rails g better_model:traceable Article --create-table --pretend
rails g better_model:archivable Article --create-columns --pretend
rails g better_model:stateable Article --create-tables --pretend

# 2. Generate for real
rails g better_model:traceable Article --create-table
rails g better_model:archivable Article --create-columns
rails g better_model:stateable Article --create-tables

# 3. Run migrations
rails db:migrate

# 4. Enable in your model (generators show you the code)
# See model setup instructions after running each generator
```

## 📋 Features Overview

BetterModel provides ten powerful concerns that work seamlessly together:

### Core Features

- **✨ Statusable** - Declarative status management with lambda-based conditions
- **🔐 Permissible** - State-based permission system
- **🗄️ Archivable** - Soft delete with tracking (by user, reason)
- **⏰ Traceable** - Complete audit trail with time-travel and rollback
- **⬆️ Sortable** - Type-aware sorting scopes
- **🔍 Predicable** - Advanced filtering with rich predicate system
- **🔎 Searchable** - Unified search interface (Predicable + Sortable)
- **✅ Validatable** - Declarative validation DSL with conditional rules
- **🔄 Stateable** - Declarative state machines with guards & callbacks
- **🏷️ Taggable** 🆕 - Tag management with normalization, validation, and statistics

[See all features in detail →](#-features)

## ⚙️ Requirements

- **Ruby:** 3.0 or higher
- **Rails:** 8.1 or higher
- **ActiveRecord:** Included with Rails

## 💾 Database Compatibility

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

## 📚 Features

BetterModel provides eight powerful concerns that work together seamlessly:

### 📋 Statusable - Declarative Status Management

Define derived statuses dynamically based on model attributes - no database columns needed!

**🎯 Key Benefits:**
- ✨ Declarative DSL with clear, readable conditions
- ⚡ Statuses calculated in real-time from model attributes
- 🔗 Reference other statuses in conditions
- 🤖 Automatic method generation (`is_draft?`, `is_published?`)
- 🔒 Thread-safe with immutable registry

**[📖 Full Documentation →](docs/statusable.md)**

---

### 🔐 Permissible - Declarative Permission Management

Define permissions dynamically based on model state and statuses - perfect for authorization logic!

**🎯 Key Benefits:**
- ✨ Declarative DSL following Statusable pattern
- ⚡ Permissions calculated from model state
- 🔗 Reference statuses in permission logic
- 🤖 Automatic method generation (`permit_edit?`, `permit_delete?`)
- 🔒 Thread-safe with immutable registry

**[📖 Full Documentation →](docs/permissible.md)**

---

### 🗄️ Archivable - Soft Delete with Archive Management

Soft-delete records with archive tracking, audit trails, and restoration capabilities.

**🎯 Key Benefits:**
- 🎛️ Opt-in activation: only enabled when explicitly configured
- 🔄 Archive and restore methods with optional tracking
- ✅ Status methods: `archived?` and `active?`
- 🔍 Semantic scopes: `archived`, `not_archived`, `archived_only`
- 🛠️ Helper predicates: `archived_today`, `archived_this_week`, `archived_recently`
- 👻 Optional default scope to hide archived records
- 🚀 Migration generator with flexible options
- 🔒 Thread-safe with immutable configuration

**[📖 Full Documentation →](docs/archivable.md)**

---

### ✅ Validatable - Declarative Validation System

Define validations declaratively with support for conditional rules, cross-field validation, business rules, and validation groups.

**🎯 Key Benefits:**
- 🎛️ Opt-in activation: only enabled when explicitly configured
- ✨ Declarative DSL for all validation types
- 🔀 Conditional validations: `validate_if` / `validate_unless`
- 🔗 Cross-field validations: `validate_order` for date/number comparisons
- 💼 Business rules: delegate complex logic to custom methods
- 📋 Validation groups: partial validation for multi-step forms
- 🔒 Thread-safe with immutable configuration

**[📖 Full Documentation →](docs/validatable.md)**

---

### 🔄 Stateable - Declarative State Machine

Define state machines declaratively with transitions, guards, validations, and callbacks for robust workflow management.

**🎯 Key Benefits:**
- 🎛️ Opt-in activation: only enabled when explicitly configured
- ✨ Declarative DSL for states and transitions
- 🛡️ Guards: preconditions with lambda, methods, or Statusable predicates
- ✅ Validations: custom validation logic per transition
- 🔗 Callbacks: before/after/around hooks for each transition
- 📜 State history tracking with customizable table names
- 🤖 Dynamic methods: `pending?`, `confirm!`, `can_confirm?`
- 🔗 Integration with Statusable for complex guard logic
- 🔒 Thread-safe with immutable configuration

**[📖 Full Documentation →](docs/stateable.md)**

---

### ⏰ Traceable - Audit Trail with Time-Travel

Track all changes to your records with complete audit trail, time-travel capabilities, and rollback support.

**🎯 Key Benefits:**
- 🎛️ Opt-in activation: only enabled when explicitly configured
- 📝 Automatic change tracking on create, update, and destroy
- 🔐 Sensitive data protection: 3-level redaction system (full, partial, hash)
- 👤 User attribution: track who made each change
- 💬 Change reasons: optional context for changes
- ⏰ Time-travel: reconstruct object state at any point in history
- ↩️ Rollback support: restore records to previous versions (with sensitive field protection)
- 🔍 Rich query API: find changes by user, time, or field transitions
- 📊 Flexible table naming: per-model, shared, or custom tables
- 🔗 Polymorphic association for efficient storage
- 💾 Database adapter safety: PostgreSQL, MySQL, SQLite support
- 🔒 Thread-safe dynamic class creation

**[📖 Full Documentation →](docs/traceable.md)**

---

### ⬆️ Sortable - Type-Aware Sorting Scopes

Generate intelligent sorting scopes automatically with database-specific optimizations and NULL handling.

**🎯 Key Benefits:**
- 🎯 Type-aware scope generation (string, numeric, datetime, boolean)
- 🔤 Case-insensitive sorting for strings
- 💾 Database-specific NULLS FIRST/LAST support
- 🔗 Sort by multiple fields with chaining
- ⚡ Optimized queries with proper indexing support

**[📖 Full Documentation →](docs/sortable.md)**

---

### 🔍 Predicable - Advanced Query Scopes

Generate comprehensive predicate scopes for filtering and searching with support for all data types.

**🎯 Key Benefits:**
- ✅ Complete coverage: string, numeric, datetime, boolean, null predicates
- 🔒 Type-safe predicates based on column type
- 🔤 Case-insensitive string matching
- 📊 Range queries (between) for numerics and dates
- 🐘 PostgreSQL array and JSONB support
- 🔗 Chainable with standard ActiveRecord queries

**[📖 Full Documentation →](docs/predicable.md)**

---

### 🔎 Searchable - Unified Search Interface

Orchestrate Predicable and Sortable into a powerful, secure search interface with pagination and security.

**🎯 Key Benefits:**
- 🎯 Unified API: single `search()` method for all operations
- 🔀 OR conditions for complex logic
- 📄 Built-in pagination with DoS protection (max_per_page)
- 🔒 Security enforcement with required predicates
- ⚙️ Default ordering configuration
- 💪 Strong parameters integration
- ✅ Type-safe validation of all parameters

**[📖 Full Documentation →](docs/searchable.md)**

---

### 🏷️ Taggable - Tag Management with Statistics

Manage tags with automatic normalization, validation, and comprehensive statistics - integrated with Predicable for powerful searches.

**🎯 Key Benefits:**
- 🎛️ Opt-in activation: only enabled when explicitly configured
- 🤖 Automatic normalization (lowercase, strip, length limits)
- ✅ Validation (min/max count, whitelist, blacklist)
- 📊 Statistics (tag counts, popularity, co-occurrence)
- 🔍 Automatic Predicable integration for searches
- 📝 CSV import/export with tag_list
- 🐘 PostgreSQL arrays or serialized JSON for SQLite
- 🎯 Thread-safe configuration

**[📖 Full Documentation →](docs/taggable.md)** | **[📚 Examples →](docs/examples/11_taggable.md)**

---

### 📜 Traceable - Audit Trail & Change Tracking

Track all changes to your records with comprehensive audit trail functionality, time-travel queries, and rollback capabilities.

**🎯 Key Benefits:**
- 🎛️ Opt-in activation: only enabled when explicitly configured
- 🤖 Automatic change tracking on create/update/destroy
- ⏰ Time-travel: reconstruct record state at any point in time
- ↩️ Rollback: restore to previous versions
- 📝 Audit trail with who/why tracking
- 🔍 Query changes by user, date range, or field transitions
- 🗂️ Flexible table naming: per-model tables (default), shared table, or custom names

**[📖 Full Documentation →](docs/traceable.md)**

#### 🚀 Quick Setup

**1️⃣ Step 1: Create the versions table**

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

**2️⃣ Step 2: Enable in your model**

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

**💡 Usage:**

```ruby
# 🤖 Automatic tracking on changes
article.update!(status: "published", updated_by_id: user.id, updated_reason: "Approved")

# 🔍 Query version history
article.versions                              # All versions (ordered desc)
article.changes_for(:status)                  # Changes for specific field
article.audit_trail                           # Full formatted history

# ⏰ Time-travel: reconstruct state at specific time
past_article = article.as_of(3.days.ago)
past_article.status                           # => "draft" (what it was 3 days ago)

# ↩️ Rollback to previous version
version = article.versions.where(event: "updated").first
article.rollback_to(version, updated_by_id: user.id, updated_reason: "Mistake")

# 📊 Class-level queries
Article.changed_by(user.id)                   # Records changed by user
Article.changed_between(1.week.ago, Time.current)  # Changes in period
Article.status_changed_from("draft").to("published")  # Specific transitions (PostgreSQL)

# 📦 Integration with as_json
article.as_json(include_audit_trail: true)    # Include full history in JSON
```

**💾 Database Schema:**

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

**🗂️ Table Naming Options:**

```ruby
# 1️⃣ Option 1: Per-model table (default)
class Article < ApplicationRecord
  traceable do
    track :status
    # Uses article_versions table automatically
  end
end

# 2️⃣ Option 2: Custom table name
class Article < ApplicationRecord
  traceable do
    track :status
    versions_table 'audit_log'  # Uses audit_log table
  end
end

# 3️⃣ Option 3: Shared table across models
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

**📝 Optional Tracking:**

To track who made changes and why, simply set attributes before saving:

```ruby
article.updated_by_id = current_user.id
article.updated_reason = "Fixed typo"
article.update!(title: "Corrected Title")

# The version will automatically include updated_by_id and updated_reason
```

---

## 📌 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## 💬 Support & Community

- 🐛 **Issues & Bugs:** [GitHub Issues](https://github.com/alessiobussolari/better_model/issues)
- 💻 **Source Code:** [GitHub Repository](https://github.com/alessiobussolari/better_model)
- 📖 **Documentation:** This README and detailed docs in `docs/` directory

## 📚 Complete Documentation

### 📖 Feature Guides

Detailed documentation for each BetterModel concern:

- [**Statusable**](docs/statusable.md) - Status management with derived conditions
- [**Permissible**](docs/permissible.md) - Permission system based on state
- [**Archivable**](docs/archivable.md) - Soft delete with comprehensive tracking
- [**Traceable**](docs/traceable.md) 🆕 - Audit trail, time-travel, and rollback
- [**Sortable**](docs/sortable.md) - Type-aware sorting system
- [**Predicable**](docs/predicable.md) - Advanced filtering and predicates
- [**Searchable**](docs/searchable.md) - Unified search interface
- [**Validatable**](docs/validatable.md) - Declarative validation system
- [**Stateable**](docs/stateable.md) 🆕 - State machine with transitions

### 🎓 Advanced Guides

Learn how to master BetterModel in production:

- [**Integration Guide**](docs/integration_guide.md) 🆕 - Combining multiple concerns effectively
- [**Performance Guide**](docs/performance_guide.md) 🆕 - Optimization strategies and indexing
- [**Migration Guide**](docs/migration_guide.md) 🆕 - Adding BetterModel to existing apps

### 💡 Quick Links

- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Features Overview](#-features-overview)
- [Requirements](#%EF%B8%8F-requirements)
- [Contributing](#-contributing)

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### 🐛 Reporting Bugs

1. ✅ Check if the issue already exists in [GitHub Issues](https://github.com/alessiobussolari/better_model/issues)
2. 📝 Create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Ruby/Rails versions
   - Database adapter

### 🚀 Submitting Pull Requests

1. 🍴 Fork the repository
2. 🌿 Create a feature branch (`git checkout -b feature/amazing-feature`)
3. ✍️ Make your changes with tests
4. 🧪 Run the test suite (`bundle exec rake test`)
5. 💅 Ensure RuboCop passes (`bundle exec rubocop`)
6. 💾 Commit your changes (`git commit -m 'Add amazing feature'`)
7. 📤 Push to the branch (`git push origin feature/amazing-feature`)
8. 🎉 Open a Pull Request

### 🔧 Development Setup

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

### 📊 Test Coverage Notes

The test suite runs on **SQLite** for performance and portability. Current coverage: **92.57%** (1507 / 1628 lines).

**Database-Specific Features Not Covered:**
- **Predicable**: PostgreSQL array predicates (`_overlaps`, `_contains`, `_contained_by`) and JSONB predicates (`_has_key`, `_has_any_key`, `_has_all_keys`, `_jsonb_contains`)
- **Traceable**: PostgreSQL JSONB queries and MySQL JSON_EXTRACT queries for field-specific change tracking
- **Sortable**: MySQL NULLS emulation with CASE statements
- **Taggable**: PostgreSQL native array operations (covered by Predicable tests)

These features are fully implemented with proper SQL sanitization but require manual testing on PostgreSQL/MySQL:

```bash
# Test on PostgreSQL
RAILS_ENV=test DATABASE_URL=postgresql://user:pass@localhost/better_model_test rails console

# Test on MySQL
RAILS_ENV=test DATABASE_URL=mysql2://user:pass@localhost/better_model_test rails console
```

All code has inline comments marking database-specific sections for maintainability.

### 📐 Code Guidelines

- ✨ Follow the existing code style (enforced by RuboCop Omakase)
- 🧪 Write tests for new features
- 📝 Update documentation (README) for user-facing changes
- 🎯 Keep pull requests focused (one feature/fix per PR)

## 📝 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

<div align="center">

**Made with ❤️ by [Alessio Bussolari](https://github.com/alessiobussolari)**

[Report Bug](https://github.com/alessiobussolari/better_model/issues) · [Request Feature](https://github.com/alessiobussolari/better_model/issues) · [Documentation](https://github.com/alessiobussolari/better_model)

</div>
