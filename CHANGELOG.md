# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-10-30

### Added

#### Validatable - Declarative Validation System
- **Opt-in activation**: Enable with `validatable do...end` block
- **Basic validations**: Clean DSL for all ActiveModel validation types
- **Conditional validations**: `validate_if` and `validate_unless` with symbol or lambda conditions
- **Cross-field validations**: `validate_order` with 6 comparators (before, after, lteq, gteq, lt, gt)
- **Business rules**: `validate_business_rule` delegates complex logic to custom methods
- **Validation groups**: Partial validation for multi-step forms with `validation_group`
- **Instance methods**: `valid?(group)`, `validate_group(group)`, `errors_for_group(group)`
- **Seamless integration** with Statusable for status-based conditional validations
- **Thread-safe** with frozen immutable configuration

### Changed

#### Traceable - Enhanced Table Customization
- **Flexible table naming**: Per-model tables (default), custom names, or shared tables
- **Generator option**: `--table-name` parameter for custom table names
- **Default behavior**: Automatic `{model}_versions` table naming (e.g., `article_versions`)
- **DSL configuration**: `versions_table 'custom_name'` in `traceable do...end` block
- **Dynamic Version classes**: Automatic subclass creation per table with proper namespacing

#### Documentation
- Updated README with Validatable quick start examples and usage
- Added comprehensive `docs/validatable.md` (22KB) with API reference, real-world examples, best practices
- Updated feature count: 7 powerful concerns (was 6)
- Enhanced Traceable documentation with table naming options and examples

#### Testing & Coverage
- **Total tests**: 424 (was 358, +66 tests)
- **Code coverage**: 85.07% (maintained above 80% threshold)
- **New test suite**: `validatable_test.rb` with 20 comprehensive tests
- **All tests passing**: 0 failures, 0 errors, 11 skips

## [1.0.0] - 2025-10-29

### Added

#### Core Concerns
- **Statusable**: Declarative status management with runtime evaluation
  - Dynamic status definitions with lambda/block syntax
  - Status checking with `is?(:status)` and `is_status?` helper methods
  - Get all statuses with `statuses` method
  - Thread-safe immutable registry

- **Permissible**: Permission management based on model state
  - Dynamic permission definitions with lambda/block syntax
  - Permission checking with `permit?(:action)` and `permit_action?` helper methods
  - Get all permissions with `permissions` method
  - Integration with Statusable for status-based permissions
  - Thread-safe immutable registry

- **Archivable**: Soft-delete with archive management
  - Soft delete with `archive!` and `restore!` methods
  - Archive tracking with `archived_by_id` and `archive_reason`
  - Status methods: `archived?` and `active?`
  - Scopes: `archived`, `not_archived`, `archived_only`
  - Helper predicates: `archived_today`, `archived_this_week`, `archived_recently`
  - Migration generator with flexible options (`--with-tracking`, `--with-by`, `--with-reason`)
  - Optional default scope to hide archived records
  - Seamless integration with Predicable, Sortable, and Searchable
  - Thread-safe immutable configuration

- **Traceable**: Change tracking with audit trail and time-travel
  - Automatic change tracking on create/update/destroy
  - Time-travel: `as_of(timestamp)` reconstructs record state at any point
  - Rollback: `rollback_to(version)` restores to previous versions
  - Audit trail with `versions`, `changes_for(field)`, `audit_trail`
  - Query changes: `changed_by(user_id)`, `changed_between(start, end)`
  - Field-specific queries: `Article.status_changed_from("draft").to("published")`
  - Per-model versioning tables (e.g., `article_versions`)
  - Optional tracking: `updated_by_id`, `updated_reason`
  - Migration generator with `--create-table` option
  - Thread-safe immutable configuration

- **Sortable**: Type-aware sorting scopes with NULL handling
  - Automatic scope generation based on column type (string, numeric, datetime, boolean)
  - Case-insensitive sorting for strings (`_asc_i`, `_desc_i`)
  - Database-specific NULLS FIRST/LAST support (PostgreSQL, MySQL, SQLite)
  - Multiple field sorting with chainable scopes
  - Optimized queries with proper indexing support

- **Predicable**: Advanced query scopes for filtering
  - Comprehensive predicate coverage: string, numeric, datetime, boolean, null
  - Type-safe predicates generated based on column type
  - Case-insensitive string matching (`_i_cont`)
  - Range queries with `_between` predicate
  - PostgreSQL-specific: array predicates (`_overlaps`, `_contains`, `_contained_by`)
  - PostgreSQL-specific: JSONB predicates (`_has_key`, `_has_any_key`, `_has_all_keys`, `_jsonb_contains`)
  - Chainable with standard ActiveRecord queries

- **Searchable**: Unified search interface orchestrating Predicable and Sortable
  - Single `search()` method for filtering, sorting, and pagination
  - OR conditions support alongside AND predicates
  - Built-in pagination with DoS protection (`max_per_page`)
  - Security enforcement with required predicates
  - Default ordering configuration at model level
  - Strong parameters integration
  - Type-safe validation of all parameters
  - Comprehensive error handling with custom error classes

#### Testing & Quality
- Comprehensive test suite with 358 automated tests
- 84.98% code coverage with SimpleCov
- RuboCop Omakase code style enforcement (0 offenses)
- bundler-audit for dependency vulnerability scanning

#### Documentation
- Complete README with quick start and examples
- Detailed documentation for each concern in `docs/` directory
- Real-world usage examples
- Database compatibility matrix
- Best practices and performance tips

#### Framework Support
- Rails 8.1+ support
- Ruby 3.0+ support
- Full ActiveRecord integration
- Support for PostgreSQL, MySQL/MariaDB, SQLite, SQL Server, Oracle

### Technical Details

- Thread-safe implementations with immutable registries
- Zero runtime overhead with compile-time scope generation
- Efficient SQL generation using Arel
- Database-specific optimizations
- Strong parameters compatible
- Chainable with standard ActiveRecord methods

[1.1.0]: https://github.com/alessiobussolari/better_model/releases/tag/v1.1.0
[1.0.0]: https://github.com/alessiobussolari/better_model/releases/tag/v1.0.0
