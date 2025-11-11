# Taggable - Flexible Tag Management System

Declarative tag management with automatic normalization, validation, and built-in statistics. Perfect for categorizing records with flexible, user-defined labels.

**Requirements**: Rails 8.0+, Ruby 3.0+, PostgreSQL (recommended) or SQLite/MySQL with serialization
**Installation**: Add tags column to table (array for PostgreSQL, text for SQLite/MySQL)

**⚠️ Version 3.0.0 Compatible**: All error handling in this document uses standard Ruby exception patterns.

---

## Database Setup

### PostgreSQL Native Arrays

**Cosa fa**: Uses PostgreSQL array column with GIN index for fast searches

**Quando usarlo**: Production apps requiring high performance tag searches

**Esempio**:
```ruby
# Migration
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :string, array: true, default: []
    add_index :articles, :tags, using: :gin
  end
end

# Model (no serialization needed)
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
  end
end
```

---

### SQLite/MySQL JSON Serialization

**Cosa fa**: Stores tags as JSON array in text column

**Quando usarlo**: Development, SQLite/MySQL databases, or simpler setup

**Esempio**:
```ruby
# Migration
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :text
  end
end

# Model (requires serialization)
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end
end
```

---

## Basic Configuration

### Minimal Setup

**Cosa fa**: Enables tagging with default settings

**Quando usarlo**: Quick setup for basic tag management

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
  end
end

article = Article.create!(title: "Rails Guide")
article.tag_with("ruby", "rails")
article.tags  # => ["ruby", "rails"]
```

---

### Normalization Options

**Cosa fa**: Automatically normalizes tags before storage

**Quando usarlo**: To ensure consistent tag format across records

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true      # "Ruby" → "ruby"
    strip true          # " rails " → "rails" (default: true)
    min_length 2        # Skip tags < 2 chars
    max_length 50       # Truncate tags > 50 chars
  end
end

article = Article.new
article.tag_with("Ruby", "  RAILS  ", "x")
article.tags  # => ["ruby", "rails"] ("x" skipped due to min_length)
```

---

### Tag Validation

**Cosa fa**: Enforces tag count limits and whitelist/blacklist

**Quando usarlo**: To control tag quality and prevent abuse

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
    validates_tags minimum: 1,
                  maximum: 10,
                  allowed_tags: ["ruby", "rails", "javascript", "python"],
                  forbidden_tags: ["spam", "nsfw"]
  end
end

article = Article.new(tags: [])
article.valid?  # => false (minimum: 1)

article.tags = ["spam"]
article.valid?  # => false (forbidden tag)

article.tags = ["ruby", "rails"]
article.valid?  # => true
```

---

## Tag Management

### Adding Tags

**Cosa fa**: Adds one or more tags to a record

**Quando usarlo**: To categorize or label records

**Esempio**:
```ruby
article = Article.create!(title: "Rails Guide")

# Add single tag
article.tag_with("ruby")
article.tags  # => ["ruby"]

# Add multiple tags
article.tag_with("rails", "tutorial", "beginner")
article.tags  # => ["ruby", "rails", "tutorial", "beginner"]

# Duplicates automatically removed
article.tag_with("ruby")
article.tags  # => ["ruby", "rails", "tutorial", "beginner"] (no duplicate)

# Auto-saves if persisted
article.persisted?  # => true (automatically saved)
```

---

### Removing Tags

**Cosa fa**: Removes one or more tags from a record

**Quando usarlo**: To uncategorize or clean up labels

**Esempio**:
```ruby
article.tags  # => ["ruby", "rails", "tutorial", "beginner"]

# Remove single tag
article.untag("beginner")
article.tags  # => ["ruby", "rails", "tutorial"]

# Remove multiple tags
article.untag("tutorial", "advanced")
article.tags  # => ["ruby", "rails"]

# Non-existent tags silently ignored
article.untag("python")  # No error
article.tags  # => ["ruby", "rails"] (unchanged)
```

---

### Replacing All Tags

**Cosa fa**: Replaces all existing tags with new ones

**Quando usarlo**: For complete tag refresh or clearing

**Esempio**:
```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

# Replace all tags
article.retag("python", "django", "web")
article.tags  # => ["python", "django", "web"]

# Clear all tags
article.retag()
article.tags  # => []
```

---

### Checking for Tags

**Cosa fa**: Checks if record has a specific tag

**Quando usarlo**: For conditional logic based on tags

**Esempio**:
```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

article.tagged_with?("ruby")     # => true
article.tagged_with?("python")   # => false

# Case-insensitive if normalize: true
article.tagged_with?("RUBY")     # => true
article.tagged_with?("Ruby")     # => true
```

---

## CSV Interface

### Getting Tags as CSV String

**Cosa fa**: Returns tags as comma-separated string

**Quando usarlo**: For form display or export

**Esempio**:
```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

# Get as CSV string
article.tag_list  # => "ruby, rails, tutorial"

# Empty tags return empty string
article.tags = []
article.tag_list  # => ""

# Works with custom delimiter (if configured)
# delimiter ';' → "ruby; rails; tutorial"
```

---

### Setting Tags from CSV String

**Cosa fa**: Parses and sets tags from comma-separated string

**Quando usarlo**: For form input processing

**Esempio**:
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

# Nil treated as empty
article.tag_list = nil
article.tags  # => []
```

---

## Statistics

### Tag Frequency Counts

**Cosa fa**: Returns count of each tag across all records

**Quando usarlo**: For tag clouds, analytics, or understanding tag usage

**Esempio**:
```ruby
Article.create!(title: "A1", tags: ["ruby", "rails"])
Article.create!(title: "A2", tags: ["ruby", "python"])
Article.create!(title: "A3", tags: ["ruby", "tutorial"])

# Get tag counts
Article.tag_counts
# => {"ruby" => 3, "rails" => 1, "python" => 1, "tutorial" => 1}

# Use for display
Article.tag_counts.each do |tag, count|
  puts "#{tag}: #{count} articles"
end
```

---

### Popular Tags

**Cosa fa**: Returns most frequently used tags ordered by count

**Quando usarlo**: For tag cloud display or trending tags

**Esempio**:
```ruby
# Get top 10 popular tags
Article.popular_tags(limit: 10)
# => [
#   ["ruby", 45],
#   ["rails", 38],
#   ["tutorial", 12],
#   ...
# ]

# Use for tag cloud with size scaling
Article.popular_tags(limit: 20).each do |tag, count|
  font_size = (count * 2) + 12
  # Render with scaled font size
end
```

---

### Related Tags

**Cosa fa**: Finds tags that frequently appear together with a specific tag

**Quando usarlo**: For content recommendations and related tag suggestions

**Esempio**:
```ruby
Article.create!(tags: ["ruby", "rails", "activerecord"])
Article.create!(tags: ["ruby", "rails", "tutorial"])
Article.create!(tags: ["ruby", "sinatra"])

# Find tags that appear with "ruby"
Article.related_tags("ruby", limit: 10)
# => ["rails", "activerecord", "tutorial", "sinatra"]
# Ordered by frequency (rails appears 2x, others 1x)

# Query tag excluded from results
Article.related_tags("ruby")  # "ruby" not in results
```

---

## Integration with Predicable

### Automatic Predicate Registration

**Cosa fa**: Taggable automatically registers predicates for tag field

**Quando usarlo**: To filter/search records by tags

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end

  # Predicable gets automatic predicates for tags
  predicates :tags, :title, :status
end

# Array predicates available:
Article.tags_present(true)   # Articles with at least one tag
Article.tags_blank(true)     # Articles with no tags
Article.tags_eq(["ruby"])    # Exact array match

# No custom scopes needed - handled by Predicable
```

---

## Integration with Searchable

### Unified Search with Tags

**Cosa fa**: Uses tags in unified search via Predicable predicates

**Quando usarlo**: For filtering content by tags in search interface

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end

  predicates :tags, :title, :status
  sort :title, :created_at

  searchable do
    per_page 25
    default_order [:sort_created_at_desc]
  end
end

# Search with tag filters
Article.search(
  { tags_present: true, status_eq: "published" },
  pagination: { page: 1, per_page: 20 },
  orders: [:sort_created_at_desc]
)

# All handled by Predicable/Searchable integration
```

---

## JSON Serialization

### Basic JSON with Tags

**Cosa fa**: Includes tags array in JSON output

**Quando usarlo**: For API responses

**Esempio**:
```ruby
article = Article.create!(
  title: "Rails Guide",
  tags: ["ruby", "rails"]
)

# Default includes tags array
article.as_json
# => {
#   "id" => 1,
#   "title" => "Rails Guide",
#   "tags" => ["ruby", "rails"],
#   ...
# }
```

---

### JSON with Tag List

**Cosa fa**: Includes tag_list as CSV string in JSON

**Quando usarlo**: For form-friendly API responses

**Esempio**:
```ruby
article = Article.create!(tags: ["ruby", "rails"])

# Include CSV string
article.as_json(include_tag_list: true)
# => {
#   ...,
#   "tags" => ["ruby", "rails"],
#   "tag_list" => "ruby, rails"
# }
```

---

### JSON with Tag Statistics

**Cosa fa**: Includes tag statistics in JSON output

**Quando usarlo**: For UI display with tag metadata

**Esempio**:
```ruby
article = Article.create!(tags: ["ruby", "rails"])

# Include statistics
article.as_json(include_tag_stats: true)
# => {
#   ...,
#   "tags" => ["ruby", "rails"],
#   "tag_stats" => {
#     "count" => 2,
#     "tags" => ["ruby", "rails"]
#   }
# }
```

---

## Real-World Use Cases

### Blog Post Tagging

**Cosa fa**: Blog with tag validation and tag cloud

**Quando usarlo**: Content management systems

**Esempio**:
```ruby
class Post < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  is :published, -> { status == "published" }

  taggable do
    tag_field :tags
    normalize true
    min_length 2
    max_length 30
    validates_tags minimum: 1,
                  maximum: 5,
                  forbidden_tags: ["spam", "nsfw"]
  end

  predicates :title, :tags, :status
  sort :published_at, :created_at

  searchable do
    per_page 20
    default_order [:sort_published_at_desc]
  end
end

# Create post with tags via CSV
post = Post.create!(
  title: "Getting Started with Rails",
  content: "...",
  status: "draft"
)

post.tag_list = "ruby, rails, tutorial, beginner"
post.save!

# Publish
post.update!(status: "published", published_at: Time.current)

# Popular tags for tag cloud
Post.popular_tags(limit: 30)
```

---

### E-commerce Product Categorization

**Cosa fa**: Multi-dimensional product tagging with controlled vocabulary

**Quando usarlo**: Products with categories, features, and attributes

**Esempio**:
```ruby
class Product < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  CATEGORY_TAGS = ["electronics", "clothing", "home", "books"]
  FEATURE_TAGS = ["bestseller", "new-arrival", "eco-friendly"]
  ATTRIBUTE_TAGS = ["small", "medium", "large", "red", "blue"]
  ALLOWED_TAGS = CATEGORY_TAGS + FEATURE_TAGS + ATTRIBUTE_TAGS

  taggable do
    tag_field :tags
    normalize true
    validates_tags maximum: 15, allowed_tags: ALLOWED_TAGS
  end

  predicates :name, :price, :tags
  sort :name, :price, :created_at

  searchable do
    per_page 24
    default_order [:sort_created_at_desc]
  end
end

# Multi-dimensional tagging
product = Product.create!(
  name: "Ruby T-Shirt",
  price: 29.99
)

product.tag_with(
  "clothing",                    # Category
  "bestseller", "new-arrival",   # Features
  "medium", "red"                # Attributes
)

# Filter by multiple tags
Product.search(
  { tags_contains: "clothing", price_between: [20, 50] },
  pagination: { page: 1, per_page: 24 }
)
```

---

### Document Management with Metadata

**Cosa fa**: Document tagging with type, department, and workflow flags

**Quando usarlo**: Document repositories and knowledge bases

**Esempio**:
```ruby
class Document < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  DOCUMENT_TYPES = ["policy", "procedure", "guideline", "form"]
  DEPARTMENTS = ["hr", "finance", "it", "legal"]
  WORKFLOW_FLAGS = ["categorized", "ready-to-publish"]
  ALLOWED_TAGS = DOCUMENT_TYPES + DEPARTMENTS + WORKFLOW_FLAGS

  taggable do
    tag_field :tags
    normalize true
    validates_tags minimum: 2,
                  maximum: 20,
                  allowed_tags: ALLOWED_TAGS
  end

  predicates :title, :tags, :state
  sort :title, :updated_at

  searchable do
    per_page 50
    default_order [:sort_updated_at_desc]
  end
end

# Categorize document
document = Document.create!(
  title: "Employee Handbook 2025",
  content: "..."
)

# Add metadata tags
document.tag_with("policy", "hr", "internal", "categorized")

# Check if ready for workflow
document.tagged_with?("categorized")  # => true

# Find related documents
Document.related_tags("policy", limit: 10)
# => ["hr", "procedure", "guideline", ...]
```

---

### Social Media Hashtags

**Cosa fa**: Hashtag-style tagging with trending analysis

**Quando usarlo**: Social platforms, content discovery

**Esempio**:
```ruby
class Post < ApplicationRecord
  include BetterModel

  serialize :hashtags, coder: JSON, type: Array

  taggable do
    tag_field :hashtags
    normalize true
    min_length 2
    max_length 50
    delimiter ' '  # Space-separated like Twitter
    validates_tags maximum: 30, forbidden_tags: ["spam", "nsfw"]
  end

  predicates :content, :hashtags
  sort :published_at, :likes_count

  searchable do
    per_page 20
    default_order [:sort_published_at_desc]
  end

  # Extract hashtags from content
  before_validation :auto_tag_from_content

  def extract_hashtags_from_content
    content.scan(/#(\w+)/).flatten.map(&:downcase).uniq
  end

  private

  def auto_tag_from_content
    extracted = extract_hashtags_from_content
    self.hashtags = (self.hashtags + extracted).uniq if extracted.any?
  end
end

# Create post with hashtags in content
post = Post.create!(
  content: "Just launched my #Rails app with #Ruby! #WebDev",
  published_at: Time.current
)

# Hashtags automatically extracted
post.hashtags  # => ["rails", "ruby", "webdev"]

# Find trending hashtags (custom logic)
recent_posts = Post.where("published_at > ?", 24.hours.ago)
tag_counts = Hash.new(0)
recent_posts.find_each { |p| p.hashtags.each { |t| tag_counts[t] += 1 } }
trending = tag_counts.sort_by { |_, count| -count }.first(20)
```

---

### Knowledge Base Topic Tags

**Cosa fa**: Article organization with topic areas and difficulty levels

**Quando usarlo**: Documentation, wikis, knowledge bases

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :topic_tags, coder: JSON, type: Array

  TOPIC_AREAS = ["getting-started", "tutorial", "api", "troubleshooting"]
  DIFFICULTY = ["beginner", "intermediate", "advanced"]
  TECH_TAGS = ["ruby", "rails", "javascript", "postgresql"]
  ALL_TAGS = TOPIC_AREAS + DIFFICULTY + TECH_TAGS

  taggable do
    tag_field :topic_tags
    normalize true
    validates_tags minimum: 1, maximum: 10, allowed_tags: ALL_TAGS
  end

  predicates :title, :topic_tags, :status
  sort :view_count, :updated_at

  searchable do
    per_page 30
    default_order [:sort_updated_at_desc]
  end
end

# Create article with structured tags
article = Article.create!(
  title: "Getting Started with Rails",
  content: "...",
  status: "published"
)

# Tag with metadata
article.tag_with(
  "getting-started",  # Topic area
  "tutorial",         # Type
  "beginner",         # Difficulty
  "rails", "ruby"     # Technologies
)

# Find related articles
Article.related_tags("rails", limit: 10)
# => ["ruby", "tutorial", "api", "activerecord", ...]

# Popular topics for navigation
Article.popular_tags(limit: 30)
```

---

## Form Integration

### Simple Form with tag_list

**Cosa fa**: Rails form with CSV tag input

**Quando usarlo**: Standard Rails forms

**Esempio**:
```ruby
# View (form)
<%= form_with model: @article do |f| %>
  <%= f.label :title %>
  <%= f.text_field :title %>

  <%= f.label :tag_list, "Tags (comma-separated)" %>
  <%= f.text_field :tag_list, placeholder: "ruby, rails, tutorial" %>
  <small>Enter 1-5 tags, separated by commas.</small>

  <%= f.submit %>
<% end %>

# Controller
class ArticlesController < ApplicationController
  def create
    @article = Article.new(article_params)
    if @article.save
      redirect_to @article
    else
      render :new
    end
  end

  private

  def article_params
    params.require(:article).permit(:title, :content, :tag_list)
  end
end
```

---

### Display Tags in Views

**Cosa fa**: Shows tags as clickable badges

**Quando usarlo**: Article/product display pages

**Esempio**:
```ruby
<!-- Article show page -->
<h1><%= @article.title %></h1>

<div class="tags">
  <% @article.tags.each do |tag| %>
    <%= link_to tag,
                articles_path(tag: tag),
                class: "badge badge-secondary" %>
  <% end %>
</div>

<div class="content">
  <%= @article.content %>
</div>
```

---

### Tag Cloud Display

**Cosa fa**: Renders popular tags with size-based styling

**Quando usarlo**: Sidebar navigation, tag browsing

**Esempio**:
```ruby
<!-- Tag cloud in sidebar -->
<div class="tag-cloud">
  <h3>Popular Tags</h3>
  <% @popular_tags.each do |tag, count| %>
    <% font_size = [12 + (count * 2), 32].min %>
    <%= link_to tag,
                articles_path(tag: tag),
                style: "font-size: #{font_size}px; margin: 0 8px;",
                class: "tag" %>
  <% end %>
</div>

<!-- Controller -->
def index
  @articles = Article.search(params[:tag] ? { tags_contains: params[:tag] } : {})
  @popular_tags = Article.popular_tags(limit: 30)
end
```

---

## Best Practices

### Always Normalize Tags

**Cosa fa**: Ensures consistent tag format

**Quando usarlo**: Always - prevents duplicate tags with different casing

**Esempio**:
```ruby
# Good - consistent tags
taggable do
  tag_field :tags
  normalize true  # "Ruby" → "ruby"
  strip true      # " rails " → "rails"
end

# Bad - inconsistent tags
# Without normalization: ["Ruby", "ruby", "RUBY"] are all different
```

---

### Set Min/Max Length

**Cosa fa**: Filters out too-short or too-long tags

**Quando usarlo**: To ensure tag quality

**Esempio**:
```ruby
# Good - enforce sensible limits
taggable do
  tag_field :tags
  min_length 2    # Skip single chars
  max_length 50   # Prevent extremely long tags
end

# Prevents: "x", "a" (too short)
# Prevents: "this-is-an-extremely-long-tag-that-makes-no-sense..." (too long)
```

---

### Use Controlled Vocabulary

**Cosa fa**: Limits tags to predefined allowed list

**Quando usarlo**: When tags need to be standardized

**Esempio**:
```ruby
# Good - controlled vocabulary
ALLOWED_TAGS = ["ruby", "rails", "python", "javascript"]

taggable do
  validates_tags allowed_tags: ALLOWED_TAGS
end

# Bad - uncontrolled tags
# Users can create any tags: typos, duplicates, nonsense tags
```

---

### Set Tag Count Limits

**Cosa fa**: Prevents tag spam and ensures focus

**Quando usarlo**: Always - keeps tagging meaningful

**Esempio**:
```ruby
# Good - sensible limits
taggable do
  validates_tags minimum: 1,   # Require categorization
                maximum: 10   # Prevent tag spam
end

# Bad - no limits
# Articles with 0 tags (uncategorized) or 100 tags (spam)
```

---

### Block Forbidden Tags

**Cosa fa**: Prevents inappropriate or spam tags

**Quando usarlo**: Public-facing tagging systems

**Esempio**:
```ruby
# Good - block problematic tags
taggable do
  validates_tags forbidden_tags: ["spam", "nsfw", "xxx", "hate"]
end

# Validation fails if any forbidden tag is used
```

---

### Cache Tag Statistics

**Cosa fa**: Improves performance for tag counts on large datasets

**Quando usarlo**: When tag statistics are frequently accessed

**Esempio**:
```ruby
# Controller with caching
def index
  @articles = Article.search(params)

  # Cache popular tags for 1 hour
  @popular_tags = Rails.cache.fetch("popular_tags", expires_in: 1.hour) do
    Article.popular_tags(limit: 50)
  end
end

# Clear cache when tags change
after_save :clear_tag_cache

def clear_tag_cache
  Rails.cache.delete("popular_tags") if saved_change_to_tags?
end
```

---

### Use GIN Index on PostgreSQL

**Cosa fa**: Significantly speeds up array searches

**Quando usarlo**: Always on PostgreSQL with array columns

**Esempio**:
```ruby
# Migration - always add GIN index
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :string, array: true, default: []
    add_index :articles, :tags, using: :gin  # Critical for performance!
  end
end

# Without GIN index: slow full table scans
# With GIN index: fast indexed lookups
```

---

## Summary

**Core Features**:
- **Flexible Tag Management**: add, remove, replace, check tags
- **CSV Interface**: `tag_list` getter/setter for forms
- **Automatic Normalization**: lowercase, strip, length enforcement
- **Declarative Validation**: min/max counts, whitelist, blacklist
- **Built-in Statistics**: tag_counts, popular_tags, related_tags
- **Predicable Integration**: automatic predicate registration
- **Searchable Integration**: unified search with tag filters

**Database Support**:
- PostgreSQL: Native arrays with GIN indexes (recommended)
- SQLite/MySQL: JSON serialization in text column

**Key Methods**:
- `instance.tag_with(*tags)` - Add tags
- `instance.untag(*tags)` - Remove tags
- `instance.retag(*tags)` - Replace all tags
- `instance.tagged_with?(tag)` - Check for tag
- `instance.tag_list` / `instance.tag_list=` - CSV interface
- `Model.tag_counts` - Frequency count
- `Model.popular_tags(limit:)` - Most popular tags
- `Model.related_tags(tag, limit:)` - Co-occurring tags

**Thread-safe**, **opt-in** (requires `taggable do...end`), **PostgreSQL optimized**.
