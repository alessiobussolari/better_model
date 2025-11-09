# 🏷️ Taggable

Taggable provides a flexible, declarative tagging system for Rails models with tag management, normalization, validation, and statistics. It enables you to organize and categorize records using custom tags with powerful filtering and search capabilities.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
  - [Migration Setup](#migration-setup)
  - [Model Configuration](#model-configuration)
- [Configuration](#configuration)
  - [Basic Configuration](#basic-configuration)
  - [Normalization Options](#normalization-options)
  - [Validation Options](#validation-options)
- [Basic Usage](#basic-usage)
  - [Adding Tags](#adding-tags)
  - [Removing Tags](#removing-tags)
  - [Replacing Tags](#replacing-tags)
  - [Checking Tags](#checking-tags)
- [Tag List (CSV Interface)](#tag-list-csv-interface)
- [Tag Statistics](#tag-statistics)
  - [Tag Counts](#tag-counts)
  - [Popular Tags](#popular-tags)
  - [Related Tags](#related-tags)
- [Instance Methods](#instance-methods)
- [Class Methods](#class-methods)
- [Database Schema](#database-schema)
- [Integration with Other Concerns](#integration-with-other-concerns)
  - [With Predicable](#with-predicable)
  - [With Searchable](#with-searchable)
  - [With Statusable](#with-statusable)
  - [With Archivable](#with-archivable)
  - [With Traceable](#with-traceable)
- [JSON Serialization](#json-serialization)
- [Real-world Examples](#real-world-examples)
  - [Blog Post Tagging](#blog-post-tagging)
  - [E-commerce Product Categories](#e-commerce-product-categories)
  - [Document Management System](#document-management-system)
- [Performance Considerations](#performance-considerations)
- [Best Practices](#best-practices)

## Overview

**Key Features:**

- **🎯 Opt-in Activation**: Taggable is not active by default. You must explicitly enable it with `taggable do...end`.
- **🏷️ Flexible Tag Management**: Add, remove, replace, and check tags with simple API methods.
- **📝 CSV Interface**: Import/export tags from comma-separated strings for easy integration.
- **🔤 Automatic Normalization**: Lowercase, strip whitespace, and enforce length limits automatically.
- **✅ Declarative Validations**: Enforce min/max tag counts, whitelists, and blacklists with DSL.
- **📊 Built-in Statistics**: Get tag counts, popular tags, and related tags out of the box.
- **🔍 Seamless Search Integration**: Automatically integrates with Predicable for powerful filtering.
- **🛡️ Thread-safe**: Immutable configuration and safe concurrent access.

## Setup

### Migration Setup

Add a `tags` column to your table. For SQLite (testing/development), use a serialized text column:

```ruby
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :text
  end
end
```

For PostgreSQL (production), you can use native array columns:

```ruby
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :string, array: true, default: []
    add_index :articles, :tags, using: 'gin'  # For array search performance
  end
end
```

### Model Configuration

Configure serialization (for SQLite) and enable Taggable:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Serialize tags as array (SQLite/MySQL)
  serialize :tags, coder: JSON, type: Array

  # Enable and configure Taggable
  taggable do
    tag_field :tags
    normalize true
  end
end
```

## Configuration

### Basic Configuration

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags          # Field to use for tags (default: :tags)
    normalize true           # Convert to lowercase (default: false)
    strip true              # Strip whitespace (default: true)
    delimiter ','           # CSV delimiter (default: ',')
  end
end
```

### Normalization Options

Control how tags are normalized before saving:

```ruby
taggable do
  tag_field :tags

  # Text normalization
  normalize true           # Convert to lowercase: "Ruby" → "ruby"
  strip true              # Remove whitespace: " rails " → "rails"

  # Length constraints
  min_length 2            # Skip tags shorter than 2 chars
  max_length 50           # Truncate tags longer than 50 chars

  # CSV parsing
  delimiter ','           # Use comma as separator (default)
  # delimiter ';'         # Or use semicolon
end
```

### Validation Options

Enforce tag validation rules declaratively:

```ruby
taggable do
  tag_field :tags
  normalize true

  validates_tags minimum: 1,                              # At least 1 tag
                maximum: 10,                             # At most 10 tags
                allowed_tags: ["ruby", "rails", "go"],  # Whitelist
                forbidden_tags: ["spam", "nsfw"]        # Blacklist
end
```

## Basic Usage

### Adding Tags

Add one or more tags to a record:

```ruby
article = Article.create!(title: "Rails Guide", content: "...")

# Add single tag
article.tag_with("ruby")

# Add multiple tags
article.tag_with("rails", "tutorial", "beginner")

# Tags are automatically normalized
article.tag_with("Ruby", "RAILS")  # Becomes ["ruby", "rails"]

# Duplicates are automatically removed
article.tag_with("ruby")  # Already exists, not added again
```

### Removing Tags

Remove one or more tags from a record:

```ruby
article.tags  # => ["ruby", "rails", "tutorial", "beginner"]

# Remove single tag
article.untag("beginner")

# Remove multiple tags
article.untag("tutorial", "advanced")

# Non-existent tags are silently ignored
article.untag("python")  # No error, just ignored
```

### Replacing Tags

Replace all existing tags with new ones:

```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

# Replace all tags
article.retag("python", "django", "web")

article.tags  # => ["python", "django", "web"]
```

### Checking Tags

Check if a record has a specific tag:

```ruby
article.tags  # => ["ruby", "rails"]

# Check for tag (case-insensitive if normalize: true)
article.tagged_with?("ruby")   # => true
article.tagged_with?("RUBY")   # => true (if normalize: true)
article.tagged_with?("python") # => false
```

## Tag List (CSV Interface)

### Reading Tag List

Get tags as a comma-separated string:

```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

# Get as CSV string
article.tag_list  # => "ruby, rails, tutorial"

# Empty tags return empty string
article.tags = []
article.tag_list  # => ""
```

### Writing Tag List

Set tags from a comma-separated string:

```ruby
# Parse from CSV string
article.tag_list = "ruby, rails, tutorial"
article.tags  # => ["ruby", "rails", "tutorial"]

# Automatic normalization
article.tag_list = "Ruby, RAILS,  Tutorial  "
article.tags  # => ["ruby", "rails", "tutorial"]

# Clear all tags
article.tag_list = ""
article.tags  # => []

# Custom delimiter (if configured)
article.tag_list = "ruby;rails;tutorial"  # If delimiter: ';'
```

## Tag Statistics

### Tag Counts

Get frequency count for all tags across all records:

```ruby
# Create some articles with tags
Article.create!(title: "A1", tags: ["ruby", "rails"])
Article.create!(title: "A2", tags: ["ruby", "python"])
Article.create!(title: "A3", tags: ["ruby"])

# Get tag counts
Article.tag_counts
# => {"ruby" => 3, "rails" => 1, "python" => 1}
```

### Popular Tags

Get the most popular tags ordered by frequency:

```ruby
# Get top 10 popular tags
Article.popular_tags(limit: 10)
# => [["ruby", 45], ["rails", 38], ["tutorial", 12], ...]

# Get top 5
Article.popular_tags(limit: 5)
# => [["ruby", 45], ["rails", 38], ["tutorial", 12], ["python", 8], ["javascript", 5]]
```

### Related Tags

Find tags that frequently appear together with a specific tag:

```ruby
Article.create!(tags: ["ruby", "rails", "activerecord"])
Article.create!(tags: ["ruby", "rails"])
Article.create!(tags: ["ruby", "sinatra"])

# Find tags that appear with "ruby"
Article.related_tags("ruby", limit: 10)
# => ["rails", "activerecord", "sinatra"]
# Ordered by frequency (rails appears 2x, others 1x)

# The query tag itself is excluded from results
```

## Instance Methods

| Method | Description | Returns | Example |
|--------|-------------|---------|---------|
| `tag_with(*tags)` | Add one or more tags | `self` | `article.tag_with("ruby", "rails")` |
| `untag(*tags)` | Remove one or more tags | `self` | `article.untag("tutorial")` |
| `retag(*tags)` | Replace all tags with new ones | `self` | `article.retag("python", "django")` |
| `tagged_with?(tag)` | Check if record has tag | `Boolean` | `article.tagged_with?("ruby")` |
| `tag_list` | Get tags as CSV string | `String` | `article.tag_list # => "ruby, rails"` |
| `tag_list=(string)` | Set tags from CSV string | `Array` | `article.tag_list = "ruby, rails"` |
| `as_json(options)` | Serialize with tag data | `Hash` | `article.as_json(include_tag_list: true)` |

## Class Methods

| Method | Description | Returns | Example |
|--------|-------------|---------|---------|
| `tag_counts` | Get frequency of all tags | `Hash` | `Article.tag_counts` |
| `popular_tags(limit:)` | Get most popular tags | `Array<[tag, count]>` | `Article.popular_tags(limit: 10)` |
| `related_tags(tag, limit:)` | Find tags that appear with tag | `Array<String>` | `Article.related_tags("ruby")` |

## Database Schema

### SQLite / MySQL (Serialized Array)

```ruby
# Migration
add_column :articles, :tags, :text

# Model
serialize :tags, coder: JSON, type: Array
```

### PostgreSQL (Native Array)

```ruby
# Migration
add_column :articles, :tags, :string, array: true, default: []
add_index :articles, :tags, using: 'gin'

# Model (no serialization needed)
# PostgreSQL arrays work natively
```

## Integration with Other Concerns

### With Predicable

Taggable automatically registers predicates for the tag field:

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end

  # Predicable automatically generates:
  # - tags_eq(array)
  # - tags_in(array)
  # - tags_present
  # - tags_blank
  # etc.
end

# Usage
Article.tags_present  # Articles with at least one tag
Article.tags_blank    # Articles with no tags
```

### With Searchable

Tags work seamlessly with the unified search interface:

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end

  predicates :tags, :title, :status

  searchable do
    per_page 25
  end
end

# Unified search with tags
Article.search(
  title_cont: "Ruby",
  pagination: { page: 1, per_page: 20 }
)
```

### With Statusable

Use tags with status-based logic:

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  # Define statuses
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }

  # Configure tagging
  taggable do
    tag_field :tags
    normalize true
  end
end

# Usage
article = Article.create!(status: "draft", tags: ["ruby", "tutorial"])
article.is?(:draft)          # => true
article.tagged_with?("ruby") # => true
```

### With Archivable

Tags are preserved when archiving:

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end

  archivable do
    skip_archived_by_default true
  end
end

# Archive with tags preserved
article = Article.create!(tags: ["ruby", "rails"])
article.archive!(by: admin, reason: "Outdated")

article.archived?             # => true
article.tags                  # => ["ruby", "rails"] (preserved)
article.tagged_with?("ruby")  # => true (still works)

# Restore
article.restore!
```

### With Traceable

Tag changes are tracked in version history:

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end

  traceable do
    track :title, :tags  # Track tag changes
  end
end

# Tag changes are versioned
article = Article.create!(tags: ["ruby"])
article.tag_with("rails")

# View changes
article.versions.last.object_changes
# => {"tags" => [["ruby"], ["ruby", "rails"]]}

article.audit_trail
# Shows tag modifications in history
```

## JSON Serialization

Customize JSON output with tag data:

```ruby
article = Article.create!(title: "Rails Guide", tags: ["ruby", "rails"])

# Default (includes tags array)
article.as_json
# => {"id" => 1, "title" => "Rails Guide", "tags" => ["ruby", "rails"], ...}

# Include tag_list as string
article.as_json(include_tag_list: true)
# => {..., "tag_list" => "ruby, rails"}

# Include tag statistics
article.as_json(include_tag_stats: true)
# => {..., "tag_stats" => {"count" => 2, "tags" => ["ruby", "rails"]}}
```

## Real-world Examples

### Blog Post Tagging

Complete blog post tagging system with categories and tags:

```ruby
class Post < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  # Statuses
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }

  # Permissions
  permit :edit, -> { is?(:draft) }
  permit :publish, -> { is?(:draft) && tags.size >= 1 }

  # Tagging with validations
  taggable do
    tag_field :tags
    normalize true
    validates_tags minimum: 1, maximum: 5,
                  forbidden_tags: ["spam", "nsfw"]
  end

  # Search configuration
  predicates :title, :content, :tags, :status
  searchable do
    per_page 20
  end
end

# Usage
post = Post.create!(
  title: "Getting Started with Ruby",
  content: "...",
  status: "draft"
)

# Add tags
post.tag_list = "ruby, tutorial, beginner-friendly"
post.tags  # => ["ruby", "tutorial", "beginner-friendly"]

# Check permissions (requires at least 1 tag)
post.permit?(:publish)  # => true

# Publish
post.update!(status: "published", published_at: Time.current)

# Find related posts
Post.search(status_eq: "published")

# Popular tags for tag cloud
Post.popular_tags(limit: 20).each do |tag, count|
  puts "#{tag} (#{count})"
end
```

### E-commerce Product Categories

Product tagging with categories, features, and filters:

```ruby
class Product < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  # Product statuses
  is :available, -> { stock_quantity > 0 && !discontinued }
  is :low_stock, -> { stock_quantity > 0 && stock_quantity <= 5 }
  is :out_of_stock, -> { stock_quantity <= 0 }

  # Tagging
  taggable do
    tag_field :tags
    normalize true
    validates_tags maximum: 15,
                  allowed_tags: PRODUCT_TAGS  # Predefined list
  end

  # Filtering
  predicates :name, :price, :tags, :stock_quantity
  sortable :name, :price, :created_at

  searchable do
    per_page 24
    default_order [:sort_created_at_desc]
  end
end

# Usage
product = Product.create!(
  name: "Ruby on Rails T-Shirt",
  price: 29.99,
  stock_quantity: 50
)

# Multi-dimensional tagging
product.tag_with(
  "clothing", "t-shirt",           # Category
  "ruby", "rails",                 # Technology
  "cotton", "size-m", "color-red"  # Attributes
)

# Advanced filtering
Product.search(
  tags: ["clothing"],
  price_between: [20, 50],
  pagination: { page: 1 }
)

# Tag-based recommendations
product.related_tags("ruby", limit: 5)
# => ["rails", "programming", "developer", "tech", "shirt"]

# Popular tags for filters
Product.popular_tags(limit: 10)
```

### Document Management System

Document categorization with metadata tagging:

```ruby
class Document < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  # Document states
  stateable do
    state :draft, initial: true
    state :review
    state :approved
    state :published

    transition :submit_for_review, from: :draft, to: :review do
      check { tags.include?("categorized") }
    end

    transition :approve, from: :review, to: :approved
    transition :publish, from: :approved, to: :published
  end

  # Tagging
  taggable do
    tag_field :tags
    normalize true
    strip true
    validates_tags minimum: 2,  # Require categorization
                  maximum: 20
  end

  # Archiving
  archivable do
    skip_archived_by_default true
  end

  # Audit trail
  traceable do
    track :title, :content, :tags, :state
  end

  # Search
  predicates :title, :tags, :state
  searchable do
    per_page 50
  end
end

# Usage
doc = Document.create!(
  title: "API Documentation",
  content: "..."
)

# Categorize with tags
doc.tag_with(
  "documentation", "api", "technical",  # Type
  "version-2.0", "public",              # Metadata
  "categorized"                         # Workflow flag
)

# State transition requires categorization
doc.submit_for_review!  # Works because "categorized" tag exists

# Search by tags and state
Document.search(
  tags_contains: "api",
  state_eq: "published"
)

# Audit trail shows tag changes
doc.audit_trail
# Shows when tags were added/modified

# Related documents
Document.related_tags("api")
# => ["documentation", "technical", "rest", "graphql"]
```

## Performance Considerations

### Indexing

For PostgreSQL arrays, use GIN indexes for optimal search performance:

```ruby
add_index :articles, :tags, using: 'gin'
```

### Tag Statistics Caching

For large datasets, cache tag statistics:

```ruby
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
  end

  # Cache expensive operations
  def self.cached_tag_counts
    Rails.cache.fetch("articles/tag_counts", expires_in: 1.hour) do
      tag_counts
    end
  end

  def self.cached_popular_tags(limit: 10)
    Rails.cache.fetch("articles/popular_tags/#{limit}", expires_in: 1.hour) do
      popular_tags(limit: limit)
    end
  end
end
```

### Batch Operations

For bulk tagging operations, use database transactions:

```ruby
Article.transaction do
  Article.where(status: "draft").find_each do |article|
    article.tag_with("needs-review")
  end
end
```

## Best Practices

### ✅ Do

- **Normalize consistently** - Always enable `normalize: true` for case-insensitive tags
- **Validate tag counts** - Set reasonable `minimum` and `maximum` limits
- **Use whitelists for controlled vocabularies** - When tags should be from a fixed set
- **Cache expensive statistics** - Tag counts and popular tags can be cached
- **Sanitize user input** - Validate and clean tags from user-submitted data
- **Index appropriately** - Use GIN indexes for PostgreSQL array columns
- **Use `tag_list` for forms** - CSV interface is perfect for text inputs
- **Clean up periodically** - Monitor and remove unused or spam tags
- **Integrate with search** - Leverage Predicable and Searchable integration
- **Track changes** - Use Traceable for important tag modifications

### ❌ Don't

- **Mix normalized and non-normalized** - Be consistent with `normalize` setting
- **Skip validation** - Always validate tag input to prevent abuse
- **Allow unlimited tags** - Set `maximum` to prevent spam
- **Forget case sensitivity** - Use `normalize: true` for user-facing tags
- **Use tags for relationships** - Tags are for categorization, not relational data
- **Store structured data in tags** - Use proper columns for structured data
- **Create too many unique tags** - Consider controlled vocabularies
- **Ignore performance** - Index tags columns and cache statistics

---

**Next Steps:**

- Read [Examples](examples/11_taggable.md) for progressive learning examples

**Related Documentation:**
- [Predicable](predicable.md) - Automatic tag filtering integration
- [Searchable](searchable.md) - Unified search with tags
- [Statusable](statusable.md) - Status-based tag logic
- [Archivable](archivable.md) - Preserve tags when archiving
- [Traceable](traceable.md) - Track tag changes in audit trail
