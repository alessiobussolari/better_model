# BetterModel Documentation

User-facing documentation for BetterModel - a Rails engine that extends ActiveRecord with powerful features.

---

## Contents

| File | Description |
|------|-------------|
| [01-statusable.md](01-statusable.md) | Dynamic boolean status predicates |
| [02-permissible.md](02-permissible.md) | Instance-level permission management |
| [03-predicable.md](03-predicable.md) | Type-aware filtering with query scopes |
| [04-sortable.md](04-sortable.md) | Type-aware sorting with auto-generated scopes |
| [05-searchable.md](05-searchable.md) | Unified search orchestration |
| [06-archivable.md](06-archivable.md) | Soft delete system with archive tracking |
| [07-validatable.md](07-validatable.md) | Declarative validation with conditional rules |
| [08-stateable.md](08-stateable.md) | State machines with guards and transitions |
| [09-traceable.md](09-traceable.md) | Comprehensive audit trail and version history |
| [10-taggable.md](10-taggable.md) | Flexible tag management |
| [11-repositable.md](11-repositable.md) | Repository Pattern implementation |
| [12-errors.md](12-errors.md) | Error handling system |
| [13-configuration.md](13-configuration.md) | Global configuration options |
| [14-rails-integration.md](14-rails-integration.md) | Rails integration and generators |
| [15-performance.md](15-performance.md) | Performance optimization tips |

---

## Quick Start

```ruby
# Include BetterModel in your model
class Article < ApplicationRecord
  include BetterModel

  # Enable features you need
  stateable do
    state :draft, initial: true
    state :published
    transition :publish, from: :draft, to: :published
  end
end
```

---

## Requirements

- Ruby 3.2+
- Rails 8.1+
- ActiveRecord

---

## See Also

- [context7/](../context7/) - Technical API documentation for Context7
- [guide/](../guide/) - Tutorials and step-by-step examples
