# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.1] - 2025-11-09

### Fixed
- **Validatable**: Corrected error class names in documentation
  - Fixed `BetterModel::ValidatableNotEnabledError` → `BetterModel::Errors::Validatable::NotEnabledError`
  - Affected methods: `validate_group(group_name)`, `errors_for_group(group_name)`

### Added
- **Validatable**: Comprehensive error handling documentation
  - New "Error Handling" section in `docs/validatable.md`
  - Examples for all error scenarios (NotEnabledError, ConfigurationError, ArgumentError)
  - Controller error handling patterns with rescue examples
  - Best practices for testing error scenarios
  - Error hierarchy diagram
- **CLAUDE.md**: Complete error handling guide for contributors
  - Full error hierarchy for all BetterModel modules
  - Module-specific error handling guidelines
  - Best practices for error handling and testing
  - Error metadata usage examples
  - Debugging tips and integration patterns

### Documentation
- Aligned Validatable error documentation with Stateable and Searchable patterns
- Added comprehensive examples of error handling in controllers
- Added testing examples (Minitest and RSpec) for all error scenarios

## [2.1.0] - 2025-11-05

### ⚠️ BREAKING CHANGES

#### Predicable - Presence Predicate API Changes

**`_present` predicate now requires boolean parameter for non-string fields:**

- **Before (v1.x):** `Article.view_count_present` (no parameter)
- **After (v2.0):** `Article.view_count_present(true)` (boolean parameter required)
- **Rationale:** Explicit parameters make intent clear and enable both presence/absence checks
- **Affected field types:** integer, decimal, float, bigint, boolean, date, datetime, time, timestamp
- **Not affected:** string/text fields retain parameterless `_present`, `_blank`, `_null`

**Boolean field predicates simplified:**
- Removed redundant `_present` predicate for boolean fields
- Use `_eq(true)/_eq(false)` or convenience methods `_true/_false` for boolean checks
- Base predicates (_eq, _not_eq) now inherited from base predicate definitions

**Date field predicates streamlined:**
- `_present` now requires boolean parameter: `published_at_present(true)`
- Base predicates (_eq, _not_eq) inherited from base predicate definitions
- All other date-specific predicates unchanged (_lt, _lteq, _within, etc.)

**Migration Guide:**

| Old API (v1.x) | New API (v2.0) | Notes |
|----------------|----------------|-------|
| `view_count_present` | `view_count_present(true)` | Boolean parameter required |
| `view_count_present` | `view_count_present(false)` | Check for absence/nil |
| `published_at_present` | `published_at_present(true)` | Boolean parameter required |
| `featured_present` | `featured_eq(true)` or `featured_true` | Use explicit true/false checks |
| `title_present` | `title_present` | ✅ Unchanged (string field) |
| `title_blank` | `title_blank` | ✅ Unchanged (string field) |
| `title_null` | `title_null` | ✅ Unchanged (string field) |

**Why this change?**
- Makes predicate behavior explicit and consistent across field types
- Enables absence checks: `field_present(false)` equivalent to `field_null`
- Reduces API surface by removing redundant method definitions
- Follows principle of explicit over implicit
- Improves code maintainability by centralizing base predicate logic

### Added

#### Context7 - AI-Optimized Documentation

- **New folder**: `context7/` with 11 curated example files specifically designed for AI assistants
- **Purpose**: Practical, copy-paste ready code examples for developers and AI tools like Context7
- **Contents**:
  - Complete, working implementations for all 10 BetterModel features
  - Self-contained examples with model setup, configuration, and usage
  - Real-world use cases with progressive complexity
  - Comprehensive inline comments and explanations
  - Structured for optimal Context7 AI assistant integration
- **Files included**:
  - `01_statusable.md` - Dynamic boolean statuses
  - `02_permissible.md` - Permission management
  - `03_predicable.md` - Type-aware filtering
  - `04_sortable.md` - Type-aware sorting
  - `05_searchable.md` - Unified search interface
  - `06_archivable.md` - Soft delete with tracking
  - `07_validatable.md` - Declarative validation
  - `08_stateable.md` - State machines
  - `09_traceable.md` - Audit trail and versioning
  - `10_taggable.md` - Tag management system
  - `README.md` - Overview and navigation guide
- **Format**: Each file includes setup, configuration examples, common usage patterns, advanced queries, and best practices

#### Traceable - Sensitive Fields Protection

- **Three-level redaction system** for protecting sensitive data in version history:
  - **`:full`**: Complete redaction - all values replaced with `"[REDACTED]"`
  - **`:partial`**: Pattern-based masking with smart pattern detection
  - **`:hash`**: SHA256 hashing for value verification without exposure
- **Pattern detection for partial masking**:
  - Credit cards: Shows last 4 digits (e.g., `"4532123456789012"` → `"****9012"`)
  - Emails: Shows first char + domain (e.g., `"user@example.com"` → `"u***@example.com"`)
  - SSN: Shows last 4 digits (e.g., `"123456789"` → `"***-**-6789"`)
  - Phone numbers: Shows last 4 digits (e.g., `"5551234567"` → `"***-***-4567"`)
  - Unknown patterns: Shows character count (e.g., `"random_text_123"` → `"[REDACTED:15chars]"`)
- **Rollback protection**: Sensitive fields excluded from rollback by default
  - Override with `allow_sensitive: true` option (not recommended)
  - Warning: Rolling back sensitive fields will set them to redacted values
- **Configuration introspection**: `traceable_sensitive_fields` class method
- **Thread-safe implementation** with frozen configuration

### Changed

#### Predicable - Internal Refactoring

- **Refactored predicate generation** to reduce code duplication:
  - Base predicates (_eq, _not_eq, _present, _blank, _null) defined once and inherited by all field types
  - String-specific presence checks override base definition for empty string handling
  - Date/numeric/boolean predicates inherit base predicates automatically
- **Improved code maintainability**:
  - Single source of truth for base predicate logic
  - Reduced repetition across field type modules
  - Clearer separation between base predicates and type-specific predicates
- **Enhanced consistency**: All field types now share identical base predicate behavior

#### Documentation

- **Context7 integration**: Added new context7/ folder optimized for AI assistants and developers
- **README updates**: Added references to context7 documentation
- **Predicate documentation**: Updated to reflect new presence predicate API requirements
- **Traceable guide** updated with comprehensive sensitive fields section:
  - Added "Sensitive Fields" subsection to Configuration
  - Added redaction levels with practical examples
  - Added rollback behavior with sensitive fields
  - Added configuration introspection documentation
  - Updated Overview with sensitive data protection feature
  - Updated Table of Contents
  - Added "Sensitive Data Protection" to Best Practices section
  - Added guidance table for choosing redaction levels
  - Updated "Don't track sensitive data" best practice to reference the `sensitive:` option
- Examples of protecting passwords, PII, tokens, credit cards, and API keys
- Healthcare, e-commerce, and authentication system examples

### Testing & Quality

#### Test Suite

- **Total tests**: 751 (+0 from v1.3.0)
  - Added 14 comprehensive sensitive fields tests
  - Removed ~150 unused variable assignments from test files
- **Total assertions**: 2392 (+26 from v1.3.0)
- **Code coverage**: 92.51% (1506/1628 lines)
- **Pass rate**: 100%
  - 0 failures
  - 0 errors
  - 0 skips
  - 0 warnings from project code
- **Test execution time**: ~7.5s for full test suite

#### Sensitive Fields Test Coverage

- **Full redaction**: Complete value redaction and nil handling (2 tests)
- **Hash redaction**: SHA256 hashing with deterministic output (3 tests)
- **Partial masking**: Pattern detection for credit cards, emails, SSN, phone, unknown (4 tests)
- **Rollback behavior**: Default skipping and allow_sensitive option (2 tests)
- **Integration**: Mixed sensitive/normal fields, configuration introspection (2 tests)
- **Edge cases**: Nil values, empty strings, special characters (1 test)

#### Code Quality

- **RuboCop**: 100% compliant (0 offenses)
- Removed 151 unused variable assignments from test files
- All sensitive field code follows Rails Omakase style guide
- Thread-safe configuration with frozen objects
- Comprehensive error handling

### Technical Details

- Predicates refactored with single inheritance chain for base predicates
- Base predicate definitions centralized in `define_base_predicates` method
- String predicates override `_present` to handle empty string semantics
- All configurations remain frozen and thread-safe
- Zero runtime performance impact from refactoring

## [1.3.0] - 2025-10-31

### Added

#### Taggable - Tag Management System
- **Three-level redaction system** for protecting sensitive data in version history:
  - **`:full`**: Complete redaction - all values replaced with `"[REDACTED]"`
  - **`:partial`**: Pattern-based masking with smart pattern detection
  - **`:hash`**: SHA256 hashing for value verification without exposure
- **Pattern detection for partial masking**:
  - Credit cards: Shows last 4 digits (e.g., `"4532123456789012"` → `"****9012"`)
  - Emails: Shows first char + domain (e.g., `"user@example.com"` → `"u***@example.com"`)
  - SSN: Shows last 4 digits (e.g., `"123456789"` → `"***-**-6789"`)
  - Phone numbers: Shows last 4 digits (e.g., `"5551234567"` → `"***-***-4567"`)
  - Unknown patterns: Shows character count (e.g., `"random_text_123"` → `"[REDACTED:15chars]"`)
- **Rollback protection**: Sensitive fields excluded from rollback by default
  - Override with `allow_sensitive: true` option (not recommended)
  - Warning: Rolling back sensitive fields will set them to redacted values
- **Configuration introspection**: `traceable_sensitive_fields` class method
- **Thread-safe implementation** with frozen configuration

### Changed

#### Documentation
- **Traceable guide** updated with comprehensive sensitive fields section:
  - Added "Sensitive Fields" subsection to Configuration
  - Added redaction levels with practical examples
  - Added rollback behavior with sensitive fields
  - Added configuration introspection documentation
  - Updated Overview with sensitive data protection feature
  - Updated Table of Contents
  - Added "Sensitive Data Protection" to Best Practices section
  - Added guidance table for choosing redaction levels
  - Updated "Don't track sensitive data" best practice to reference the `sensitive:` option
- Examples of protecting passwords, PII, tokens, credit cards, and API keys
- Healthcare, e-commerce, and authentication system examples

### Testing & Quality

#### Test Suite
- **Total tests**: 751 (+0 from v1.3.0)
  - Added 14 comprehensive sensitive fields tests
  - Removed ~150 unused variable assignments from test files
- **Total assertions**: 2392 (+26 from v1.3.0)
- **Code coverage**: 92.51% (1506/1628 lines)
- **Pass rate**: 100%
  - 0 failures
  - 0 errors
  - 0 skips
  - 0 warnings from project code
- **Test execution time**: ~7.5s for full test suite

#### Sensitive Fields Test Coverage
- **Full redaction**: Complete value redaction and nil handling (2 tests)
- **Hash redaction**: SHA256 hashing with deterministic output (3 tests)
- **Partial masking**: Pattern detection for credit cards, emails, SSN, phone, unknown (4 tests)
- **Rollback behavior**: Default skipping and allow_sensitive option (2 tests)
- **Integration**: Mixed sensitive/normal fields, configuration introspection (2 tests)
- **Edge cases**: Nil values, empty strings, special characters (1 test)

#### Code Quality
- **RuboCop**: 100% compliant (0 offenses)
- Removed 151 unused variable assignments from test files
- All sensitive field code follows Rails Omakase style guide
- Thread-safe configuration with frozen objects
- Comprehensive error handling

## [1.3.0] - 2025-10-31

### Added

#### Taggable - Tag Management System
- **New concern**: `BetterModel::Taggable` for managing tags with normalization, validation, and statistics
- **Tag management methods**:
  - `tag_with(*tags)`: Add tags with automatic deduplication
  - `untag(*tags)`: Remove specific tags
  - `retag(*tags)`: Replace all tags
  - `tagged_with?(tag)`: Check if record has a tag
- **CSV interface**:
  - `tag_list`: Export tags as comma-separated string
  - `tag_list=`: Import tags from string with custom delimiter support
- **Normalization features**:
  - Automatic lowercase conversion (`normalize: true`)
  - Whitespace stripping (`strip: true`, default)
  - Minimum length enforcement (`min_length: 2`)
  - Maximum length truncation (`max_length: 30`)
- **Validation system**:
  - Minimum/maximum tag count validation
  - Whitelist validation (`allowed_tags`)
  - Blacklist validation (`forbidden_tags`)
- **Statistics & analytics**:
  - `tag_counts`: Count occurrences across all records
  - `popular_tags(limit:)`: Most frequently used tags
  - `related_tags(tag, limit:)`: Co-occurrence analysis
- **Predicable integration**:
  - Automatic `predicates` registration for tag searches
  - Support for `tags_contains`, `tags_overlaps`, `tags_contains_all`
- **JSON serialization**:
  - `as_json(include_tag_list: true)`: Include CSV string
  - `as_json(include_tag_stats: true)`: Include count and array
- **Database support**:
  - PostgreSQL native arrays (recommended)
  - SQLite/MySQL with JSON serialization
  - Thread-safe frozen configuration

#### Documentation
- **Taggable guide** (22 KB): Complete documentation with setup, configuration, and integration patterns
- **Taggable examples** (15+ KB): Progressive examples from basic to advanced with 8 complete scenarios
- Updated **examples/README.md**: Added Taggable as 10th module with navigation
- Updated **main README.md**:
  - Added Taggable to Quick Start with configuration example
  - Added tag management, query, and statistics examples
  - Added Taggable to Features Overview section
  - Updated "9 concerns" to "10 concerns"
  - Added Taggable to individual concerns list

### Changed

#### README Enhancements
- Features Overview: 9 → 10 concerns
- Updated Quick Start with Taggable configuration block
- Added comprehensive tag usage examples (management, queries, statistics)
- Updated test coverage statistics: 92.57% (1507/1628 lines)
- Added Taggable to module compatibility matrix
- Renumbered example files: `11_use_cases.md` → `12_use_cases.md`

### Testing & Quality

#### Test Suite
- **Total tests**: 751 (+97 from v1.2.0)
  - Added 83 comprehensive Taggable tests across 14 phases
  - Coverage: Tag management, CSV, normalization, validation, statistics, integration
- **Total assertions**: 2366 (+105 from v1.2.0)
- **Code coverage**: 92.57% (1507/1628 lines, +1.12% from v1.2.0)
- **Pass rate**: 100% for Taggable tests
  - 0 failures in Taggable
  - 0 errors in Taggable
  - 0 skips in Taggable

#### Taggable Test Coverage
- **Phase 1**: Setup and configuration (6 tests)
- **Phase 2**: Tag management (tag_with, untag, retag, tagged_with?) (12 tests)
- **Phase 3**: CSV interface (tag_list, delimiter) (7 tests)
- **Phase 4**: Normalization (lowercase, strip, length) (7 tests)
- **Phase 5**: Validations (min, max, whitelist, blacklist) (8 tests)
- **Phase 6**: Statistics (tag_counts, popular_tags, related_tags) (9 tests)
- **Phase 7**: Predicable integration (1 test)
- **Phase 8**: JSON serialization (3 tests)
- **Phase 9**: Thread safety (4 tests)
- **Phase 12**: Edge cases (nil, empty, unicode, special chars) (12 tests)
- **Phase 14**: Integration with other modules (9 tests)
- **Additional**: Performance and error handling (5 tests)

#### Code Quality
- **RuboCop**: 100% compliant (0 offenses)
- All Taggable code follows Rails Omakase style guide
- Thread-safe configuration with frozen objects
- Comprehensive error handling

### Technical Details

#### Database Schema
- Added `tags` column to test articles table (text/array type)
- SQLite: Uses `serialize :tags, coder: JSON, type: Array`
- PostgreSQL: Native array column support recommended

#### Integration
- Taggable works seamlessly with:
  - **Predicable**: Automatic tag search scopes
  - **Searchable**: Unified search with tag filters
  - **Traceable**: Audit trail for tag changes
  - **Statusable**: Tag-based status conditions
  - **Permissible**: Tag-based permissions

## [1.2.0] - 2025-10-30

### Added

#### Thread-Safety Improvements
- **CLASS_CREATION_MUTEX**: Thread-safe dynamic class creation in Traceable and Stateable
- **Double-checked locking pattern**: Optimal performance with thread safety
- **Thread-safety test suite**:
  - Traceable: 6 comprehensive concurrency tests
  - Stateable: 8 comprehensive concurrency tests
- Concurrent version/transition class creation tests
- Multiple table name handling tests

#### Database Adapter Safety
- **PostgreSQL support**: JSONB operators for optimal query performance in Traceable
- **MySQL/Trilogy support**: JSON_EXTRACT functions for change queries
- **SQLite fallback**: Graceful degradation with logging
- **Adapter detection**: `postgres?` and `mysql?` methods in ChangeQuery
- Cross-database compatibility for field change tracking

#### Documentation
- **Traceable guide** (23.6 KB): Complete documentation with time-travel, rollback, and query scopes
- **Stateable guide** (25.8 KB): State machine documentation with guards, validations, and callbacks
- **Integration guide** (21.2 KB): Patterns for combining multiple concerns effectively
- **Performance guide** (19.5 KB): Database indexing, query optimization, N+1 prevention
- **Migration guide** (23.4 KB): Adding BetterModel to existing applications
- **Total documentation**: 113+ KB of comprehensive guides
- Updated README with Traceable examples and complete documentation links
- Features Overview section in README
- Complete Documentation section with links to all 12 guides

### Changed

#### README Enhancements
- Added Traceable to Quick Start section with time-travel example
- Added Traceable usage examples (audit trail, rollback, change queries)
- Created Features Overview section with all 9 concerns
- Added Complete Documentation section linking to all guides
- Enhanced Traceable section in detailed Features

#### Code Improvements
- Improved exception handling in Traceable rollback methods
- Better error messages for version validation failures
- Enhanced ChangeQuery architecture with adapter-specific optimizations

### Fixed
- Removed inconsistent exception types in rollback validation tests
- Fixed method redefinition warnings in thread-safety tests
- Cleaned up redundant test files (documentation structure tests, adapter tests)

### Testing & Quality

#### Test Suite
- **Total tests**: 654 (+26 from v1.1.0)
  - Added 15 thread-safety tests (Traceable + Stateable)
  - Removed 24 unnecessary tests (documentation structure, non-runnable adapter tests)
- **Code coverage**: 91.45% (1272/1391 lines covered)
- **Pass rate**: 100% - All tests passing
  - 0 failures
  - 0 errors
  - 0 skips
  - 0 warnings in project code
- **Test execution time**: ~6.6s for full test suite

#### Code Quality
- **RuboCop**: 100% compliant (0 offenses)
- **Test files**: 83 files inspected
- All auto-correctable style violations fixed

### Technical Details

#### Database Schema Updates
- Added test tables for thread-safety verification
- Enhanced schema with version/transition tracking tables
- Improved indexing strategy documentation

## [1.1.0] - 2025-10-30

### Added

#### Validatable - Declarative Validation System
- **Opt-in activation**: Enable with `validatable do...end` block
- **Basic validations**: Clean DSL with `check` method for all ActiveModel validation types
- **Conditional validations**: Use Rails `if:`/`unless:` options for conditional logic
- **Complex validations**: `register_complex_validation` + `check_complex` for cross-field and business rules
- **Validation groups**: Partial validation for multi-step forms with `validation_group`
- **Instance methods**: `valid?(group)`, `validate_group(group)`, `errors_for_group(group)`
- **Seamless integration** with Statusable for status-based conditional validations
- **Thread-safe** with frozen immutable configuration

**DEPRECATED in v2.0.0** (removed methods - see current API in docs/validatable.md):
- ~~`validate_if`/`validate_unless`~~ → Use Rails `if:`/`unless:` options
- ~~`validate_order`~~ → Use `register_complex_validation` for cross-field comparisons
- ~~`validate_business_rule`~~ → Use `register_complex_validation` + `check_complex`

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
- **Total tests**: 628 automated tests (+95 from v1.0.0, +17.8% increase)
  - Unit tests: 628 with 1912 assertions
  - New test suites:
    - Searchable: +13 tests (OR conditions, security validation)
    - Stateable: +7 tests (edge cases, guard exceptions, nil state handling)
    - Validatable: +8 tests (nested conditions, validation groups, complex rules)
- **Code coverage**: 91.41% (1245/1362 lines covered, +6.06% from 85.35%)
- **Pass rate**: 100% - All tests passing (0 failures, 0 errors, 10 skips)
- **Test execution time**: ~7s for full test suite

#### Documentation
- **README enhancements**: Strategic emoji placement for improved readability and scannability
  - Section headers with category icons (📦 Installation, ⚡ Quick Start, 📚 Features, etc.)
  - Code examples categorized with visual markers (✅, 🔐, ⬆️, 🔍, etc.)
  - Step-by-step guides with numbered emojis (1️⃣, 2️⃣, 3️⃣)
  - Key benefits highlighted with relevant icons
  - Contributing workflow visualized with process emojis (🍴, 🌿, 🧪, 🎉)

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

[2.1.0]: https://github.com/alessiobussolari/better_model/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/alessiobussolari/better_model/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/alessiobussolari/better_model/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/alessiobussolari/better_model/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/alessiobussolari/better_model/releases/tag/v1.1.0
[1.0.0]: https://github.com/alessiobussolari/better_model/releases/tag/v1.0.0
