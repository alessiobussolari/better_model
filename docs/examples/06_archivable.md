# Archivable Examples

Archivable provides soft delete functionality with user tracking and restore capability—a better alternative to hard deletes.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Simple Archive](#example-1-simple-archive)
- [Example 2: Archive with Tracking](#example-2-archive-with-tracking)
- [Example 3: Restore Archived Records](#example-3-restore-archived-records)
- [Example 4: Querying Archived Records](#example-4-querying-archived-records)
- [Example 5: Auto-hide Archived Records](#example-5-auto-hide-archived-records)
- [Example 6: Archive Metadata](#example-6-archive-metadata)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Migration
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :archived_at, :datetime
    add_column :articles, :archived_by_id, :integer  # Optional
    add_column :articles, :archive_reason, :string   # Optional

    add_index :articles, :archived_at
    add_index :articles, :archived_by_id
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel

  # Enable archiving
  archivable
end
```

## Example 1: Simple Archive

```ruby
article = Article.create!(title: "Draft Article", status: "draft")

# Archive the article
article.archive!

article.archived?
# => true

article.active?
# => false

article.archived_at
# => 2025-10-30 10:30:00 UTC

# Try to archive again
article.archive!
# => BetterModel::AlreadyArchivedError: Record is already archived
```

**Output Explanation**: `archive!` sets `archived_at` to current time and raises error if already archived.

## Example 2: Archive with Tracking

```ruby
# Archive with user and reason
article = Article.create!(title: "Old Article")

article.archive!(
  by: current_user,  # User object or ID
  reason: "Content outdated"
)

article.archived_by_id
# => 42

article.archive_reason
# => "Content outdated"

# Archive with just ID
another_article.archive!(by: 99, reason: "Spam")
another_article.archived_by_id
# => 99
```

**Output Explanation**: Track who archived records and why for audit purposes.

## Example 3: Restore Archived Records

```ruby
article = Article.create!(title: "Archived Article")
article.archive!(by: current_user, reason: "Mistake")

# Restore the article
article.restore!

article.archived?
# => false

article.archived_at
# => nil

article.archived_by_id
# => nil (cleared on restore)

article.archive_reason
# => nil (cleared on restore)

# Try to restore again
article.restore!
# => BetterModel::NotArchivedError: Record is not archived
```

**Output Explanation**: `restore!` clears all archive metadata and returns article to active state.

## Example 4: Querying Archived Records

Archivable auto-generates predicates and scopes:

```ruby
# Create test data
active = Article.create!(title: "Active Article")
archived1 = Article.create!(title: "Archived Yesterday")
archived1.archive!
archived1.update_column(:archived_at, 1.day.ago)

archived2 = Article.create!(title: "Archived Last Week")
archived2.archive!
archived2.update_column(:archived_at, 8.days.ago)

# Query archived records
Article.archived.pluck(:title)
# => ["Archived Yesterday", "Archived Last Week"]

# Query active records
Article.not_archived.pluck(:title)
# => ["Active Article"]

# Date-based queries (automatic from Predicable)
Article.archived_at_within(7.days).pluck(:title)
# => ["Archived Yesterday"]

Article.archived_at_today.count
# => 0

# Helper methods
Article.archived_today.count
# => 0

Article.archived_this_week.pluck(:title)
# => ["Archived Yesterday"]

Article.archived_recently(30.days).count
# => 2
```

**Output Explanation**: Archivable integrates with Predicable for powerful date-based queries.

## Example 5: Auto-hide Archived Records

Configure default scope to hide archived records:

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end
end

# Create test data
active = Article.create!(title: "Active")
archived = Article.create!(title: "Archived")
archived.archive!

# Default queries exclude archived
Article.all.pluck(:title)
# => ["Active"]

Article.count
# => 1

# Explicitly include archived
Article.unscoped.all.pluck(:title)
# => ["Active", "Archived"]

# Query only archived
Article.archived_only.pluck(:title)
# => ["Archived"]

# Temporarily include archived
Article.unscope(where: :archived_at).all
# => All records including archived
```

**Output Explanation**: `skip_archived_by_default` adds a default scope that hides archived records.

## Example 6: Archive Metadata

Include archive info in JSON responses:

```ruby
article = Article.create!(title: "Article with Metadata")
article.archive!(by: 42, reason: "Outdated content")

# Standard JSON
article.as_json
# => {"id"=>1, "title"=>"Article with Metadata", ...}

# Include archive metadata
article.as_json(include_archive_info: true)
# => {
#   "id" => 1,
#   "title" => "Article with Metadata",
#   "archive_info" => {
#     "archived" => true,
#     "archived_at" => "2025-10-30T10:30:00.000Z",
#     "archived_by_id" => 42,
#     "archive_reason" => "Outdated content"
#   }
# }

# For API responses
render json: @article.as_json(include_archive_info: true)
```

**Output Explanation**: `include_archive_info` option adds archive metadata to JSON output.

## Advanced Usage

### Combining with Stateable

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end

  stateable do
    state :draft, initial: true
    state :published
    state :archived

    transition :publish, from: :draft, to: :published
    transition :archive, from: [:draft, :published], to: :archived do
      after { archive!(by: Current.user) }
    end
  end
end

article = Article.create!(title: "Article")
article.publish!
article.archive_transition!  # Calls both state transition AND archive!

article.state
# => "archived"

article.archived?
# => true (soft deleted)
```

### Permissions Integration

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :archived, -> { archived? }

  archivable

  permit :edit, -> { is_not?(:archived) }
  permit :delete, -> { is_not?(:archived) }
  permit :restore, -> { is?(:archived) }
end

article = Article.create!(title: "Article")
article.can?(:edit)
# => true

article.archive!
article.can?(:edit)
# => false

article.can?(:restore)
# => true
```

### Searchable Integration

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :archived_at
  sort :title, :archived_at

  archivable do
    skip_archived_by_default true
  end

  searchable
end

# Search only active articles (default)
Article.search({ status_eq: "published" })
# => Active published articles

# Search including archived
Article.unscoped.search({
  status_eq: "published",
  archived_at_present: true
})
# => Archived published articles

# Search by archive date
Article.unscoped.search({
  archived_at_within: 30.days
},
  sort: :archived_at_desc
)
# => Recently archived articles
```

## Tips & Best Practices

### 1. Always Use archived_by Tracking
```ruby
# Bad: No audit trail
article.archive!

# Good: Track who archived
article.archive!(by: current_user, reason: "Spam")
```

### 2. Add Indexes for Performance
```ruby
class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :archived_at, :datetime
    add_column :articles, :archived_by_id, :integer
    add_column :articles, :archive_reason, :string

    # Essential for performance
    add_index :articles, :archived_at
    add_index :articles, :archived_by_id

    # Composite for common queries
    add_index :articles, [:archived_at, :status]
  end
end
```

### 3. Use skip_archived_by_default Carefully
```ruby
# Consider your use case:

# If most queries should exclude archived:
archivable do
  skip_archived_by_default true  # Good for user-facing content
end

# If you often need both:
archivable  # No default scope, explicitly filter when needed
```

### 4. Handle Archiving in Bulk
```ruby
# Archive multiple records
Article.where(status: "spam").find_each do |article|
  article.archive!(by: admin, reason: "Spam detected")
end

# Or with custom scope
class Article < ApplicationRecord
  def self.archive_spam!(user)
    where(status: "spam").find_each do |article|
      article.archive!(by: user, reason: "Spam cleanup")
    end
  end
end
```

### 5. Soft Delete vs Hard Delete
```ruby
# When to use archive (soft delete):
# - User content that might need restoration
# - Records with important audit history
# - Data with foreign key relationships

# When to use destroy (hard delete):
# - Truly sensitive data (GDPR compliance)
# - Test/temporary data
# - When disk space is critical
```

### 6. Restore with Validation
```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable

  def restore_with_validation!
    restore!
    unless valid?
      archive!  # Re-archive if invalid
      raise ActiveRecord::RecordInvalid.new(self)
    end
  end
end
```

## Related Documentation

- [Main README](../../README.md#archivable) - Full Archivable documentation
- [Stateable Examples](08_stateable.md) - Combine with state machines
- [Searchable Examples](05_searchable.md) - Search archived records
- [Test File](../../test/better_model/archivable_test.rb) - Complete test coverage

---

[← Searchable Examples](05_searchable.md) | [Back to Examples Index](README.md) | [Next: Validatable Examples →](07_validatable.md)
