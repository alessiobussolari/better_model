# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Comprehensive test suite with 272 automated tests
- 89.54% code coverage with SimpleCov
- 122 manual integration tests (100% pass rate)
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

[1.0.0]: https://github.com/alessiobussolari/better_model/releases/tag/v1.0.0
