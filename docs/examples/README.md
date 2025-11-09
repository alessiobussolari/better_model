# BetterModel Examples

Welcome to the BetterModel examples directory! This collection provides practical, self-contained examples for each BetterModel module.

## Quick Navigation

1. [Statusable](#01-statusable) - Declarative status checks with lambdas
2. [Permissible](#02-permissible) - Role-based permissions
3. [Predicable](#03-predicable) - Auto-generated query scopes
4. [Sortable](#04-sortable) - Flexible sorting with NULL handling
5. [Searchable](#05-searchable) - Unified search interface
6. [Archivable](#06-archivable) - Soft delete with tracking
7. [Validatable](#07-validatable) - Declarative validation system
8. [Stateable](#08-stateable) - State machine with transitions
9. [Traceable](#09-traceable) - Audit trail and time travel
10. [Taggable](#10-taggable) - Tag management with statistics
11. [Repositable](#11-repositable) - Repository Pattern for data access

## Module Overview

### 01. Statusable
**When to use**: Define business logic status checks without polluting your model with boolean columns.

**Example use case**: Blog post that can be "draft", "published", "expired", "popular"

[View Examples →](01_statusable.md)

### 02. Permissible
**When to use**: Implement permission checks based on statuses or other conditions.

**Example use case**: Users can edit drafts but not published posts

[View Examples →](02_permissible.md)

### 03. Predicable
**When to use**: Need powerful filtering without writing custom scopes.

**Example use case**: Filter articles by status, date range, view count

[View Examples →](03_predicable.md)

### 04. Sortable
**When to use**: Need flexible sorting with database-agnostic NULL handling.

**Example use case**: Sort articles by published date with unpublished ones last

[View Examples →](04_sortable.md)

### 05. Searchable
**When to use**: Build search UIs with filtering, sorting, and pagination.

**Example use case**: Article search page with filters and sort options

[View Examples →](05_searchable.md)

### 06. Archivable
**When to use**: Soft delete records with user tracking and restore capability.

**Example use case**: Archive articles instead of deleting them

[View Examples →](06_archivable.md)

### 07. Validatable
**When to use**: Need declarative validations, conditional validation groups, or cross-field validation.

**Example use case**: Multi-step form validation, business rule validation

[View Examples →](07_validatable.md)

### 08. Stateable
**When to use**: Implement state machines with transitions, guards, and callbacks.

**Example use case**: Article workflow from draft → published → archived

[View Examples →](08_stateable.md)

### 09. Traceable
**When to use**: Track all changes to specific fields with full audit trail.

**Example use case**: Track who changed article title and when, with rollback capability

[View Examples →](09_traceable.md)

### 10. Taggable
**When to use**: Manage tags with normalization, validation, and statistics.

**Example use case**: Blog posts with tags, product categories, keyword management

[View Examples →](11_taggable.md)

### 11. Repositable
**When to use**: Implement Repository Pattern for clean architecture and testability.

**Example use case**: Separate data access from business logic, complex queries, service-oriented architecture

[View Examples →](14_repositable.md)

## Advanced Integration Guides

### Integration Patterns
Learn proven patterns for combining multiple modules:

**[→ View Integration Patterns](10_integration_patterns.md)**

- **Pattern 1: Complete Workflow** - Stateable + Permissible + Statusable + Traceable
- **Pattern 2: Search & Filter** - Searchable + Predicable + Sortable
- **Pattern 3: Audit Trail** - Traceable + Stateable + Archivable
- **Pattern 4: Multi-step Form** - Validatable + Stateable + Permissible
- **Pattern 5: Content Lifecycle** - All modules combined

### Real-World Use Cases
Complete end-to-end implementations:

**[→ View Use Cases](12_use_cases.md)**

- **Blog Publishing Platform** - Article workflow with approvals
- **E-commerce Order Management** - Payment and shipping lifecycle
- **CMS Content System** - Page builder with validations
- **Task Management System** - Assignments and permissions

### Cookbook & Recipes
Quick solutions to specific problems:

**[→ View Cookbook](13_cookbook.md)**

1. Three-Level Approval Workflow
2. Soft Delete with Selective Restore
3. Advanced API Filters with Validation
4. Time-Limited Edit Window
5. Partial Field Rollback
6. Conditional Required Fields
7. Auto-Archive Based on Criteria
8. Search with Complex OR Conditions
9. State-Based Validation
10. Audit Export for Compliance

## Module Compatibility Matrix

| Primary Module | Works Best With | Common Use Case |
|----------------|-----------------|-----------------|
| **Statusable** | Permissible, Stateable | Permission logic based on state |
| **Permissible** | Statusable, Stateable | Role-based workflows |
| **Predicable** | Searchable, Sortable | Filtered data views |
| **Sortable** | Searchable, Predicable | Ordered result sets |
| **Searchable** | Predicable, Sortable | API endpoints, search UIs |
| **Archivable** | Traceable, Stateable | Soft delete with history |
| **Validatable** | Stateable, Permissible | Multi-step forms |
| **Stateable** | All modules | Central workflow engine |
| **Traceable** | Stateable, Archivable | Compliance and audit |
| **Taggable** | Predicable, Searchable | Tag-based filtering |
| **Repositable** | Searchable, Predicable, Sortable | Clean data access layer |

## Combining Modules

BetterModel modules work great together! Here's a common pattern:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # 1. Define statuses (business logic)
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }

  # 2. Define permissions based on statuses
  permit :edit, -> { is?(:draft) }
  permit :publish, -> { is?(:draft) }

  # 3. Enable filtering and search
  predicates :title, :status, :published_at
  sort :title, :published_at

  # 4. Add state machine
  stateable do
    state :draft, initial: true
    state :published

    transition :publish, from: :draft, to: :published do
      check { can?(:publish) }  # Uses Permissible
      before { self.published_at = Time.current }
    end
  end

  # 5. Track changes
  traceable do
    track :title, :status
  end

  # 6. Enable archiving
  archivable do
    skip_archived_by_default true
  end
end

# Now you have a powerful Article model with:
# - Status checks: article.is?(:published)
# - Permissions: article.can?(:edit)
# - Filtering: Article.status_eq("draft").published_at_within(7.days)
# - Search: Article.search(predicates, sort: :published_at_desc)
# - State machine: article.publish!
# - Audit trail: article.versions, article.rollback_to(version)
# - Soft delete: article.archive!(by: current_user, reason: "Outdated")
```

## Running Examples

All examples are self-contained and can be adapted to your models. To try them:

1. Ensure your model has the required database columns
2. Include BetterModel: `include BetterModel`
3. Copy and adapt the example code
4. Run migrations if using Archivable, Stateable, or Traceable

## Additional Resources

- [Main README](../../README.md) - Full documentation
- [Test Suite](../../test/better_model/) - Complete test coverage with more examples
- [Changelog](../../CHANGELOG.md) - Version history and updates

## Getting Help

If you need help or find issues:
- Check the main README for detailed documentation
- Look at the test files for advanced usage patterns
- Open an issue on GitHub

---

*Happy coding with BetterModel!*
