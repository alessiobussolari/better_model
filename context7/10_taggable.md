# Taggable - Flexible Tag Management System

## Overview

**Taggable** is a declarative, opt-in tagging system for Rails models that provides flexible tag management with automatic normalization, validation, and built-in statistics. It enables you to organize and categorize records using custom tags with powerful filtering and search capabilities.

**Key Features**:
- **Flexible Tag Management**: Add, remove, replace, and check tags with simple API methods
- **CSV Interface**: Import/export tags from comma-separated strings for easy form integration
- **Automatic Normalization**: Lowercase conversion, whitespace stripping, length enforcement
- **Declarative Validations**: Enforce min/max tag counts, whitelists (allowed_tags), blacklists (forbidden_tags)
- **Built-in Statistics**: Tag counts, popular tags, and related tags out of the box
- **Predicable Integration**: Automatic predicate registration for filtering
- **Searchable Integration**: Works seamlessly with unified search API
- **Database Flexible**: PostgreSQL native arrays or serialized JSON for SQLite/MySQL
- **Thread-Safe**: Immutable configuration and safe concurrent access

**When to Use Taggable**:
- Blog posts and articles requiring categorization
- E-commerce products with multi-dimensional attributes
- Document management systems with metadata tags
- Social media content with hashtags
- Knowledge bases with topic organization
- Task/project management with labels
- Recipe platforms with ingredient/cuisine tags
- Any system requiring flexible categorization

## Basic Concepts

### Opt-In Activation

Taggable is **not active by default**. You must explicitly enable it:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # For SQLite/MySQL: serialize tags as JSON array
  serialize :tags, coder: JSON, type: Array

  # Enable Taggable
  taggable do
    tag_field :tags
    normalize true
  end
end
```

### Tag Storage

Tags are stored as arrays in a database column:

**PostgreSQL** (recommended for production):
```ruby
# Migration
add_column :articles, :tags, :string, array: true, default: []
add_index :articles, :tags, using: :gin

# Model - no serialization needed
taggable do
  tag_field :tags
end
```

**SQLite/MySQL** (serialized JSON):
```ruby
# Migration
add_column :articles, :tags, :text

# Model - requires serialization
serialize :tags, coder: JSON, type: Array

taggable do
  tag_field :tags
end
```

### Normalization

Tags can be automatically normalized before storage:

```ruby
taggable do
  normalize true    # "Ruby" → "ruby", "RAILS" → "rails"
  strip true        # " rails " → "rails" (default: true)
  min_length 2      # Skip tags shorter than 2 chars
  max_length 50     # Truncate tags longer than 50 chars
end

# Example:
article.tag_with("Ruby", "  RAILS  ", "API")
article.tags  # => ["ruby", "rails", "api"]
```

### Validation

Enforce tag rules declaratively:

```ruby
taggable do
  validates_tags minimum: 1,                              # At least 1 tag required
                maximum: 10,                             # At most 10 tags
                allowed_tags: ["ruby", "rails", "go"],  # Whitelist
                forbidden_tags: ["spam", "nsfw"]        # Blacklist
end
```

### Statistics

Get insights from tag usage across records:

```ruby
# Tag frequency
Article.tag_counts
# => {"ruby" => 45, "rails" => 38, "tutorial" => 12}

# Most popular tags
Article.popular_tags(limit: 10)
# => [["ruby", 45], ["rails", 38], ["tutorial", 12], ...]

# Related tags (co-occurrence)
Article.related_tags("ruby", limit: 5)
# => ["rails", "tutorial", "activerecord", "gem", "api"]
```

## Database Setup

### PostgreSQL (Recommended for Production)

Use native array columns with GIN indexes:

```ruby
# Migration
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :string, array: true, default: []
    add_index :articles, :tags, using: :gin  # For fast array searches
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel

  # No serialization needed for PostgreSQL arrays
  taggable do
    tag_field :tags
    normalize true
  end
end
```

**Advantages**:
- Native array support
- GIN indexes for fast searches
- Efficient storage
- Better query performance

### SQLite/MySQL (Serialized JSON)

Use text column with JSON serialization:

```ruby
# Migration
class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :text
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel

  # Serialize as JSON array
  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end
end
```

**Considerations**:
- Text storage with JSON encoding
- No native array operations
- Adequate for small/medium datasets
- Simpler setup for development

## Configuration

### Basic Configuration

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags    # Field name (default: :tags)
    normalize true     # Convert to lowercase
    strip true         # Remove whitespace (default: true)
    delimiter ','      # CSV delimiter (default: ',')
  end
end
```

### Normalization Options

Control how tags are processed before storage:

```ruby
taggable do
  tag_field :tags

  # Text normalization
  normalize true     # "Ruby" → "ruby"
  strip true         # " rails " → "rails"

  # Length constraints
  min_length 2       # Skip tags < 2 chars
  max_length 50      # Truncate tags > 50 chars

  # CSV parsing
  delimiter ','      # Use comma (default)
  # delimiter ';'    # Or semicolon
  # delimiter '|'    # Or pipe
end

# Examples:
article.tag_with("Ruby", "Go", "x")
# With min_length 2: tags => ["ruby", "go"] ("x" skipped)

article.tag_with("a-very-long-tag-name-that-exceeds-the-maximum-length-limit")
# With max_length 50: truncated to 50 characters
```

### Validation Options

Enforce tag rules:

```ruby
taggable do
  tag_field :tags
  normalize true

  validates_tags minimum: 1,                              # At least 1 tag
                maximum: 10,                             # At most 10 tags
                allowed_tags: ["ruby", "rails", "go"],  # Whitelist
                forbidden_tags: ["spam", "nsfw", "xxx"] # Blacklist
end

# Validation examples:
article.tags = []
article.valid?  # => false (minimum: 1)

article.tags = ["ruby"] * 15
article.valid?  # => false (maximum: 10)

article.tags = ["python"]
article.valid?  # => false (not in allowed_tags)

article.tags = ["ruby", "spam"]
article.valid?  # => false ("spam" in forbidden_tags)
```

**Validation Details**:
- `minimum` - Minimum number of tags required
- `maximum` - Maximum number of tags allowed
- `allowed_tags` - Whitelist (only these tags allowed)
- `forbidden_tags` - Blacklist (these tags not allowed)
- Validations run on save, not on method calls

## Instance Methods

### tag_with(*tags)

Add one or more tags to the record:

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

# Automatic normalization (if configured)
article.tag_with("Ruby", "RAILS")
article.tags  # => ["ruby", "rails", "tutorial", "beginner"] (normalized)

# Auto-saves if record is persisted
article.persisted?  # => true
# tag_with automatically calls save!
```

### untag(*tags)

Remove one or more tags from the record:

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

# Auto-saves if record is persisted
```

### retag(*tags)

Replace all existing tags with new ones:

```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

# Replace all tags
article.retag("python", "django", "web")
article.tags  # => ["python", "django", "web"]

# Clear all tags (empty retag)
article.retag()
article.tags  # => []

# Auto-saves if record is persisted
```

### tagged_with?(tag)

Check if record has a specific tag:

```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

# Check for tag
article.tagged_with?("ruby")     # => true
article.tagged_with?("python")   # => false

# Case-insensitive if normalize: true
article.tagged_with?("RUBY")     # => true
article.tagged_with?("Ruby")     # => true
```

### tag_list (getter)

Get tags as comma-separated string:

```ruby
article.tags  # => ["ruby", "rails", "tutorial"]

# Get as CSV string
article.tag_list  # => "ruby, rails, tutorial"

# Empty tags return empty string
article.tags = []
article.tag_list  # => ""

# Custom delimiter (if configured with delimiter: ';')
article.tag_list  # => "ruby; rails; tutorial"
```

### tag_list= (setter)

Set tags from comma-separated string:

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

# Custom delimiter parsing (if configured)
article.tag_list = "ruby;rails;tutorial"
article.tags  # => ["ruby", "rails", "tutorial"]

# Auto-saves if record is persisted
```

### as_json(options)

Include tag data in JSON serialization:

```ruby
article = Article.create!(title: "Rails Guide", tags: ["ruby", "rails"])

# Default (includes tags array)
article.as_json
# => {"id" => 1, "title" => "Rails Guide", "tags" => ["ruby", "rails"], ...}

# Include tag_list as CSV string
article.as_json(include_tag_list: true)
# => {..., "tag_list" => "ruby, rails"}

# Include tag statistics
article.as_json(include_tag_stats: true)
# => {..., "tag_stats" => {"count" => 2, "tags" => ["ruby", "rails"]}}

# Include both
article.as_json(include_tag_list: true, include_tag_stats: true)
# => {..., "tag_list" => "ruby, rails", "tag_stats" => {...}}
```

## Class Methods

### tag_counts

Get frequency count for all tags across all records:

```ruby
# Create articles with tags
Article.create!(title: "A1", tags: ["ruby", "rails"])
Article.create!(title: "A2", tags: ["ruby", "python"])
Article.create!(title: "A3", tags: ["ruby", "tutorial"])

# Get tag counts
Article.tag_counts
# => {"ruby" => 3, "rails" => 1, "python" => 1, "tutorial" => 1}

# Use for tag clouds, statistics
counts = Article.tag_counts
counts.each do |tag, count|
  puts "#{tag}: #{count} articles"
end
```

**Performance Note**: Iterates all records with `find_each`. Cache results for large datasets.

### popular_tags(limit: 10)

Get the most popular tags ordered by frequency:

```ruby
# Get top 10 popular tags
Article.popular_tags(limit: 10)
# => [
#   ["ruby", 45],
#   ["rails", 38],
#   ["tutorial", 12],
#   ["api", 8],
#   ["gem", 5],
#   ...
# ]

# Get top 5
Article.popular_tags(limit: 5)
# => [["ruby", 45], ["rails", 38], ["tutorial", 12], ["api", 8], ["gem", 5]]

# Use for tag cloud display
Article.popular_tags(limit: 20).each do |tag, count|
  font_size = (count * 2) + 12  # Scale font by popularity
  puts "<span style='font-size: #{font_size}px'>#{tag}</span>"
end
```

### related_tags(tag, limit: 10)

Find tags that frequently appear together with a specific tag:

```ruby
Article.create!(tags: ["ruby", "rails", "activerecord"])
Article.create!(tags: ["ruby", "rails", "tutorial"])
Article.create!(tags: ["ruby", "sinatra"])
Article.create!(tags: ["ruby", "gem"])

# Find tags that appear with "ruby"
Article.related_tags("ruby", limit: 10)
# => ["rails", "activerecord", "tutorial", "sinatra", "gem"]
# Ordered by frequency (rails appears 2x, others 1x)

# The query tag itself is excluded from results
Article.related_tags("ruby")  # "ruby" not in results

# Use for recommendations
related = Article.related_tags("ruby", limit: 5)
puts "Articles tagged with 'ruby' often also have: #{related.join(', ')}"
```

## Search & Filtering

### Integration with Predicable

Taggable automatically registers predicates for the tag field:

```ruby
class Article < ApplicationRecord
  include BetterModel

  serialize :tags, coder: JSON, type: Array

  taggable do
    tag_field :tags
    normalize true
  end

  # Predicable automatically generates predicates:
  predicates :tags, :title, :status
end

# Array predicates available:
Article.tags_present(true)   # Articles with at least one tag
Article.tags_blank(true)     # Articles with no tags
Article.tags_eq(["ruby"])    # Exact array match

# Note: No custom scopes needed - all handled by Predicable
```

### Integration with Searchable

Tags work seamlessly with unified search:

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

# Unified search with tags (via Predicable predicates)
Article.search(
  { tags_present: true, status_eq: "published" },
  pagination: { page: 1, per_page: 20 },
  orders: [:sort_created_at_desc]
)

# Search is delegated entirely to Predicable/Searchable
# No custom "tagged_with" scopes needed
```

## Real-World Examples

### Example 1: Blog Post Tagging System

Complete blog post tagging with categories, validation, and tag cloud:

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  include BetterModel

  belongs_to :author, class_name: "User"
  has_many :comments, dependent: :destroy

  # Serialize tags for SQLite
  serialize :tags, coder: JSON, type: Array

  # Status definitions
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :scheduled, -> { scheduled_at.present? && scheduled_at > Time.current }

  # Permissions (require tags for publishing)
  permit :edit, -> { is?(:draft) }
  permit :publish, -> { is?(:draft) && tags.size >= 1 }
  permit :unpublish, -> { is?(:published) }

  # Tagging with validation
  taggable do
    tag_field :tags
    normalize true           # Case-insensitive
    strip true
    min_length 2
    max_length 30
    validates_tags minimum: 1,
                  maximum: 5,
                  forbidden_tags: ["spam", "nsfw", "xxx", "porn"]
  end

  # Search configuration
  predicates :title, :content, :tags, :status, :published_at
  sort :title, :published_at, :created_at

  searchable do
    per_page 20
    max_per_page 100
    default_order [:sort_published_at_desc]
  end

  # Validations
  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }
end

# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    @posts = Post.search(
      build_search_params,
      pagination: { page: params[:page], per_page: 20 },
      orders: [:sort_published_at_desc]
    )

    # Tag cloud for sidebar
    @popular_tags = Post.popular_tags(limit: 30)
  end

  def show
    # Related posts by tags
    @related_posts = Post.search(
      { status_eq: "published" },
      pagination: { page: 1, per_page: 5 },
      orders: [:sort_published_at_desc]
    ).select { |p| p.tags.any? { |t| @post.tags.include?(t) } && p.id != @post.id }
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)
    @post.author = current_user
    @post.status = "draft"

    if @post.save
      redirect_to @post, notice: "Post created successfully"
    else
      render :new
    end
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post updated successfully"
    else
      render :edit
    end
  end

  def publish
    @post = Post.find(params[:id])

    unless @post.permit?(:publish)
      redirect_to edit_post_path(@post), alert: "Cannot publish: at least 1 tag required"
      return
    end

    if @post.update(status: "published", published_at: Time.current)
      redirect_to @post, notice: "Post published"
    else
      redirect_to edit_post_path(@post), alert: "Failed to publish"
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :content, :excerpt, :tag_list)
  end

  def build_search_params
    params.permit(:title_cont, :status_eq, :tags_present).to_h
  end
end

# app/views/posts/_form.html.erb
<%= form_with model: @post do |f| %>
  <div class="field">
    <%= f.label :title %>
    <%= f.text_field :title, class: "form-control" %>
  </div>

  <div class="field">
    <%= f.label :content %>
    <%= f.text_area :content, class: "form-control", rows: 10 %>
  </div>

  <div class="field">
    <%= f.label :tag_list, "Tags (comma-separated)" %>
    <%= f.text_field :tag_list, class: "form-control", placeholder: "ruby, rails, tutorial" %>
    <small class="form-text text-muted">
      Enter 1-5 tags, separated by commas. Each tag must be 2-30 characters.
    </small>
  </div>

  <%= f.submit class: "btn btn-primary" %>
<% end %>

# app/views/posts/index.html.erb
<h1>Blog Posts</h1>

<!-- Tag Cloud -->
<div class="tag-cloud">
  <h3>Popular Tags</h3>
  <% @popular_tags.each do |tag, count| %>
    <% font_size = [12 + (count * 2), 32].min %>
    <%= link_to tag,
                posts_path(tags_contains: tag),
                style: "font-size: #{font_size}px; margin: 0 8px;",
                class: "tag" %>
  <% end %>
</div>

<!-- Posts -->
<div class="posts">
  <% @posts.each do |post| %>
    <article class="post-card">
      <h2><%= link_to post.title, post %></h2>
      <div class="meta">
        By <%= post.author.name %> on <%= post.published_at&.strftime("%B %d, %Y") %>
      </div>
      <div class="tags">
        <% post.tags.each do |tag| %>
          <%= link_to tag, posts_path(tags_contains: tag), class: "badge badge-secondary" %>
        <% end %>
      </div>
      <p><%= truncate(post.content, length: 200) %></p>
    </article>
  <% end %>
</div>

# Usage:
post = Post.create!(
  title: "Getting Started with Ruby on Rails",
  content: "Rails is a web application framework...",
  author: current_user,
  status: "draft"
)

# Add tags via form (tag_list)
post.tag_list = "ruby, rails, tutorial, beginner-friendly"
post.save!

# Or programmatically
post.tag_with("web-development", "mvc")

# Check publishing permission (requires at least 1 tag)
post.permit?(:publish)  # => true

# Publish
post.update!(status: "published", published_at: Time.current)

# Find related posts
Post.related_tags("ruby", limit: 5)
# => ["rails", "tutorial", "gem", "activerecord", "api"]

# Popular tags for tag cloud
Post.popular_tags(limit: 30).each do |tag, count|
  puts "#{tag} (#{count} posts)"
end
```

### Example 2: E-commerce Product Categorization

Multi-dimensional product tagging with categories, features, and controlled vocabulary:

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  include BetterModel

  belongs_to :category
  has_many :reviews, dependent: :destroy

  serialize :tags, coder: JSON, type: Array

  # Product statuses
  is :available, -> { stock_quantity > 0 && !discontinued }
  is :low_stock, -> { stock_quantity > 0 && stock_quantity <= 5 }
  is :out_of_stock, -> { stock_quantity <= 0 }
  is :on_sale, -> { sale_price.present? && sale_price < price }

  # Tagging with controlled vocabulary
  CATEGORY_TAGS = ["electronics", "clothing", "home", "books", "toys", "sports"]
  FEATURE_TAGS = ["bestseller", "new-arrival", "eco-friendly", "handmade", "imported"]
  ATTRIBUTE_TAGS = ["small", "medium", "large", "xl", "red", "blue", "green", "black", "white"]

  ALLOWED_TAGS = CATEGORY_TAGS + FEATURE_TAGS + ATTRIBUTE_TAGS

  taggable do
    tag_field :tags
    normalize true
    validates_tags maximum: 15,
                  allowed_tags: ALLOWED_TAGS
  end

  # Search and filtering
  predicates :name, :description, :price, :tags, :stock_quantity
  sort :name, :price, :created_at, :stock_quantity

  searchable do
    per_page 24
    max_per_page 100
    default_order [:sort_created_at_desc]
  end

  # Validations
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
end

# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  def index
    @products = Product.search(
      build_search_params,
      pagination: { page: params[:page], per_page: 24 },
      orders: build_order_params
    )

    # Faceted search - tag categories
    @category_tags = Product.popular_tags(limit: 50)
                           .select { |tag, _| Product::CATEGORY_TAGS.include?(tag) }
    @feature_tags = Product.popular_tags(limit: 50)
                          .select { |tag, _| Product::FEATURE_TAGS.include?(tag) }
  end

  def show
    @product = Product.find(params[:id])

    # Related products via shared tags
    @related_products = find_related_products(@product)
  end

  private

  def build_search_params
    search_params = {}

    search_params[:name_i_cont] = params[:q] if params[:q].present?
    search_params[:price_between] = [params[:min_price], params[:max_price]] if price_range_present?

    # Tag filtering (multiple selections)
    if params[:tags].present?
      # User can filter by multiple tags
      params[:tags].each_with_index do |tag, index|
        search_params[:"tags_contains_#{index}"] = tag
      end
    end

    search_params[:stock_quantity_gt] = 0 if params[:in_stock] == "1"

    search_params
  end

  def build_order_params
    case params[:sort]
    when "price_asc" then [:sort_price_asc]
    when "price_desc" then [:sort_price_desc]
    when "name_asc" then [:sort_name_asc]
    when "newest" then [:sort_created_at_desc]
    else [:sort_created_at_desc]
    end
  end

  def find_related_products(product)
    return [] if product.tags.empty?

    # Find products with shared tags
    Product.where.not(id: product.id)
           .where("stock_quantity > ?", 0)
           .limit(10)
           .select { |p| (p.tags & product.tags).any? }
           .sort_by { |p| (p.tags & product.tags).size }
           .reverse
           .first(5)
  end
end

# app/views/products/index.html.erb
<h1>Products</h1>

<!-- Faceted Search -->
<div class="filters">
  <h3>Filter by Category</h3>
  <% @category_tags.each do |tag, count| %>
    <%= link_to "#{tag} (#{count})",
                products_path(tags: [tag]),
                class: "filter-link" %>
  <% end %>

  <h3>Features</h3>
  <% @feature_tags.each do |tag, count| %>
    <%= link_to "#{tag} (#{count})",
                products_path(tags: [tag]),
                class: "filter-link" %>
  <% end %>
</div>

<!-- Products Grid -->
<div class="products-grid">
  <% @products.each do |product| %>
    <div class="product-card">
      <h3><%= link_to product.name, product %></h3>
      <div class="price">$<%= product.price %></div>
      <div class="tags">
        <% product.tags.each do |tag| %>
          <%= link_to tag, products_path(tags: [tag]), class: "badge" %>
        <% end %>
      </div>
      <% if product.is?(:low_stock) %>
        <span class="badge badge-warning">Only <%= product.stock_quantity %> left!</span>
      <% end %>
    </div>
  <% end %>
</div>

# Usage:
product = Product.create!(
  name: "Ruby on Rails T-Shirt",
  price: 29.99,
  stock_quantity: 50,
  category: Category.find_by(name: "Clothing")
)

# Multi-dimensional tagging
product.tag_with(
  "clothing",                    # Category
  "bestseller", "new-arrival",   # Features
  "medium", "red", "cotton"      # Attributes
)

# Advanced filtering
Product.search(
  {
    tags_contains: "clothing",
    price_between: [20, 50]
  },
  pagination: { page: 1, per_page: 24 }
)

# Tag-based recommendations
related_tags = Product.related_tags("clothing", limit: 10)
# => ["t-shirt", "bestseller", "cotton", "medium", "red", ...]

# Popular tags for each category
Product.popular_tags(limit: 50)
       .select { |tag, _| Product::CATEGORY_TAGS.include?(tag) }
```

### Example 3: Document Management System

Document categorization with metadata tagging, state machines, and audit trail:

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  include BetterModel

  belongs_to :created_by, class_name: "User"
  belongs_to :department
  has_many :document_versions, dependent: :destroy

  serialize :tags, coder: JSON, type: Array

  # Document workflow states
  stateable do
    state :draft, initial: true
    state :review
    state :approved
    state :published
    state :archived

    # Transitions with tag requirements
    transition :submit_for_review, from: :draft, to: :review do
      guard { tags.include?("categorized") && tags.size >= 2 }
    end

    transition :approve, from: :review, to: :approved
    transition :reject, from: :review, to: :draft

    transition :publish, from: :approved, to: :published do
      guard { tags.include?("ready-to-publish") }
    end

    transition :archive, from: [:approved, :published], to: :archived
  end

  # Tagging with metadata requirements
  DOCUMENT_TYPES = ["policy", "procedure", "guideline", "form", "template", "report"]
  DEPARTMENTS = ["hr", "finance", "it", "legal", "operations", "sales"]
  VISIBILITY = ["public", "internal", "confidential", "restricted"]
  WORKFLOW_FLAGS = ["categorized", "ready-to-publish", "needs-review"]

  ALLOWED_TAGS = DOCUMENT_TYPES + DEPARTMENTS + VISIBILITY + WORKFLOW_FLAGS

  taggable do
    tag_field :tags
    normalize true
    strip true
    validates_tags minimum: 2,    # Require categorization
                  maximum: 20,
                  allowed_tags: ALLOWED_TAGS
  end

  # Archiving
  archivable do
    skip_archived_by_default true
  end

  # Change tracking
  traceable do
    track :title, :content, :tags, :state, :version_number
  end

  # Search
  predicates :title, :content, :tags, :state, :department_id
  sort :title, :created_at, :updated_at, :version_number

  searchable do
    per_page 50
    max_per_page 200
    default_order [:sort_updated_at_desc]
  end

  # Validations
  validates :title, presence: true
  validates :version_number, presence: true, numericality: { greater_than: 0 }
end

# app/services/document_workflow_service.rb
class DocumentWorkflowService
  def initialize(document)
    @document = document
  end

  def categorize(tags:, categorized_by:)
    # Add metadata tags
    @document.tag_with(*tags)

    # Add workflow flag
    @document.tag_with("categorized")

    # Save with audit
    @document.updated_by_id = categorized_by.id
    @document.updated_reason = "Document categorized with: #{tags.join(', ')}"
    @document.save!
  end

  def submit_for_review(submitted_by:)
    unless @document.submit_for_review!
      raise "Cannot submit: document must have 'categorized' tag and at least 2 tags total"
    end

    # Notify reviewers
    notify_reviewers(@document)

    # Audit
    @document.update!(
      updated_by_id: submitted_by.id,
      updated_reason: "Submitted for review"
    )
  end

  def approve(approved_by:, notes:)
    @document.approve!

    # Add workflow flag for publishing
    @document.tag_with("ready-to-publish")

    # Audit
    @document.update!(
      updated_by_id: approved_by.id,
      updated_reason: "Approved: #{notes}"
    )
  end

  def publish(published_by:)
    unless @document.publish!
      raise "Cannot publish: document must have 'ready-to-publish' tag"
    end

    # Remove workflow flags
    @document.untag("categorized", "ready-to-publish", "needs-review")

    # Update version
    @document.version_number += 1
    @document.published_at = Time.current

    # Audit
    @document.update!(
      updated_by_id: published_by.id,
      updated_reason: "Published version #{@document.version_number}"
    )

    # Create version snapshot
    create_version_snapshot(@document)
  end

  private

  def notify_reviewers(document)
    ReviewerMailer.new_document_for_review(document).deliver_later
  end

  def create_version_snapshot(document)
    DocumentVersion.create!(
      document: document,
      content: document.content,
      version_number: document.version_number,
      tags: document.tags,
      created_at: Time.current
    )
  end
end

# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy, :workflow]

  def index
    @documents = Document.search(
      build_search_params,
      pagination: { page: params[:page], per_page: 50 },
      orders: [:sort_updated_at_desc]
    )

    # Filter options
    @document_types = Document::DOCUMENT_TYPES
    @departments = Document::DEPARTMENTS
    @states = [:draft, :review, :approved, :published]
  end

  def show
    # Related documents by tags
    @related_documents = find_related_documents(@document)

    # Audit trail for changes
    @audit_trail = @document.audit_trail
  end

  def workflow
    service = DocumentWorkflowService.new(@document)

    case params[:action_type]
    when "categorize"
      service.categorize(
        tags: params[:tags].split(",").map(&:strip),
        categorized_by: current_user
      )
      redirect_to @document, notice: "Document categorized"

    when "submit_for_review"
      service.submit_for_review(submitted_by: current_user)
      redirect_to @document, notice: "Submitted for review"

    when "approve"
      service.approve(approved_by: current_user, notes: params[:notes])
      redirect_to @document, notice: "Document approved"

    when "publish"
      service.publish(published_by: current_user)
      redirect_to @document, notice: "Document published"

    else
      redirect_to @document, alert: "Unknown action"
    end
  rescue => e
    redirect_to @document, alert: "Error: #{e.message}"
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def build_search_params
    search_params = {}

    search_params[:title_i_cont] = params[:q] if params[:q].present?
    search_params[:state_eq] = params[:state] if params[:state].present?
    search_params[:department_id_eq] = params[:department_id] if params[:department_id].present?

    # Tag filtering
    if params[:document_type].present?
      search_params[:tags_contains] = params[:document_type]
    end

    search_params
  end

  def find_related_documents(document)
    Document.where.not(id: document.id)
            .where(state: [:approved, :published])
            .limit(20)
            .select { |d| (d.tags & document.tags).size >= 2 }
            .first(5)
  end
end

# Usage:
document = Document.create!(
  title: "Employee Handbook 2025",
  content: "...",
  created_by: current_user,
  department: hr_department,
  version_number: 1
)

# Categorize with service
service = DocumentWorkflowService.new(document)
service.categorize(
  tags: ["policy", "hr", "internal", "employee-relations"],
  categorized_by: current_user
)

# Document can now be submitted (has 'categorized' tag and >= 2 tags)
service.submit_for_review(submitted_by: current_user)

# Reviewer approves
service.approve(approved_by: reviewer, notes: "Looks good, ready for publication")

# Publish (requires 'ready-to-publish' tag from approval)
service.publish(published_by: admin)

# View audit trail (shows all tag changes and state transitions)
document.audit_trail.each do |entry|
  puts "#{entry[:at]}: #{entry[:changes]}"
  puts "By: #{User.find(entry[:by]).name}"
  puts "Reason: #{entry[:reason]}"
end

# Find related documents
Document.related_tags("policy", limit: 10)
# => ["hr", "procedure", "guideline", "internal", ...]
```

### Example 4: Social Media Content (Hashtags)

Social media platform with hashtag-style tagging, trending tags, and content discovery:

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  include BetterModel

  belongs_to :user
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :shares, dependent: :destroy

  serialize :hashtags, coder: JSON, type: Array

  # Post statuses
  is :published, -> { published_at.present? && !deleted_at.present? }
  is :draft, -> { published_at.nil? }
  is :trending, -> { likes_count > 100 && created_at > 24.hours.ago }
  is :viral, -> { shares_count > 50 }

  # Hashtag tagging
  taggable do
    tag_field :hashtags
    normalize true     # Hashtags are case-insensitive
    strip true
    min_length 2
    max_length 50
    delimiter ' '     # Space-separated like Twitter
    validates_tags maximum: 30,
                  forbidden_tags: ["spam", "nsfw", "hate", "violence"]
  end

  # Counters
  has_many :post_metrics, dependent: :destroy

  # Search
  predicates :content, :hashtags, :user_id, :published_at
  sort :published_at, :likes_count, :shares_count, :created_at

  searchable do
    per_page 20
    max_per_page 100
    default_order [:sort_published_at_desc]
  end

  # Extract hashtags from content
  def extract_hashtags_from_content
    content.scan(/#(\w+)/).flatten.map(&:downcase).uniq
  end

  # Auto-tag from content
  before_validation :auto_tag_from_content, if: :content_changed?

  private

  def auto_tag_from_content
    extracted = extract_hashtags_from_content
    self.hashtags = (self.hashtags + extracted).uniq if extracted.any?
  end
end

# app/services/trending_service.rb
class TrendingService
  TRENDING_WINDOW = 24.hours
  TRENDING_THRESHOLD = 10  # Minimum posts to be trending

  def self.trending_hashtags(limit: 20)
    # Get posts from last 24 hours
    recent_posts = Post.where("published_at > ?", TRENDING_WINDOW.ago)
                      .where.not(published_at: nil)

    # Count hashtags
    tag_counts = Hash.new(0)
    recent_posts.find_each do |post|
      post.hashtags.each { |tag| tag_counts[tag] += 1 }
    end

    # Filter by threshold and sort
    tag_counts.select { |_, count| count >= TRENDING_THRESHOLD }
              .sort_by { |_, count| -count }
              .first(limit)
  end

  def self.hashtag_timeline(hashtag)
    # Posts with this hashtag over time
    Post.where("hashtags LIKE ?", "%#{hashtag}%")
        .where.not(published_at: nil)
        .group_by_day(:published_at, last: 30)
        .count
  end

  def self.hashtag_engagement(hashtag)
    posts = Post.where("hashtags LIKE ?", "%#{hashtag}%")
                .where.not(published_at: nil)

    {
      total_posts: posts.count,
      total_likes: posts.sum(:likes_count),
      total_shares: posts.sum(:shares_count),
      total_comments: posts.sum(:comments_count),
      avg_engagement: posts.average(:likes_count).to_f.round(2)
    }
  end
end

# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def index
    @posts = Post.search(
      build_search_params,
      pagination: { page: params[:page], per_page: 20 },
      orders: build_order_params
    )

    # Trending hashtags for sidebar
    @trending = TrendingService.trending_hashtags(limit: 10)
  end

  def show
    @post = Post.find(params[:id])
    @related_posts = find_related_posts(@post)
  end

  def hashtag
    @hashtag = params[:tag]
    @posts = Post.search(
      { hashtags_contains: @hashtag, published_at_present: true },
      pagination: { page: params[:page], per_page: 20 },
      orders: [:sort_published_at_desc]
    )

    # Hashtag statistics
    @stats = TrendingService.hashtag_engagement(@hashtag)
    @timeline = TrendingService.hashtag_timeline(@hashtag)
    @related_tags = Post.related_tags(@hashtag, limit: 10)
  end

  def trending
    @trending_tags = TrendingService.trending_hashtags(limit: 50)
  end

  def create
    @post = Post.new(post_params)
    @post.user = current_user
    @post.published_at = Time.current

    if @post.save
      redirect_to @post, notice: "Post created"
    else
      render :new
    end
  end

  private

  def post_params
    params.require(:post).permit(:content, :image_url, hashtag_list: [])
  end

  def build_search_params
    search_params = { published_at_present: true }

    search_params[:content_i_cont] = params[:q] if params[:q].present?
    search_params[:hashtags_contains] = params[:tag] if params[:tag].present?

    search_params
  end

  def build_order_params
    case params[:sort]
    when "trending" then [:sort_likes_count_desc]
    when "viral" then [:sort_shares_count_desc]
    else [:sort_published_at_desc]
    end
  end

  def find_related_posts(post)
    return [] if post.hashtags.empty?

    Post.where.not(id: post.id)
        .where.not(published_at: nil)
        .limit(20)
        .select { |p| (p.hashtags & post.hashtags).any? }
        .sort_by { |p| (p.hashtags & post.hashtags).size }
        .reverse
        .first(5)
  end
end

# app/views/posts/index.html.erb
<h1>Feed</h1>

<!-- Trending Sidebar -->
<aside class="trending">
  <h3>Trending Now</h3>
  <% @trending.each do |tag, count| %>
    <div class="trending-tag">
      <%= link_to hashtag_posts_path(tag: tag) do %>
        #<%= tag %>
        <span class="count"><%= count %> posts</span>
      <% end %>
    </div>
  <% end %>
  <%= link_to "See all trending", trending_posts_path %>
</aside>

<!-- Posts Feed -->
<div class="feed">
  <% @posts.each do |post| %>
    <article class="post-card">
      <div class="post-header">
        <strong><%= post.user.name %></strong>
        <span class="timestamp"><%= time_ago_in_words(post.published_at) %> ago</span>
      </div>

      <div class="post-content">
        <%= sanitize(post.content) %>
      </div>

      <div class="post-hashtags">
        <% post.hashtags.each do |tag| %>
          <%= link_to "##{tag}", hashtag_posts_path(tag: tag), class: "hashtag" %>
        <% end %>
      </div>

      <div class="post-actions">
        <%= link_to "Like (#{post.likes_count})", like_post_path(post), method: :post %>
        <%= link_to "Share (#{post.shares_count})", share_post_path(post), method: :post %>
        <%= link_to "Comment (#{post.comments_count})", post %>
      </div>
    </article>
  <% end %>
</div>

# app/views/posts/hashtag.html.erb
<h1>#<%= @hashtag %></h1>

<!-- Hashtag Stats -->
<div class="hashtag-stats">
  <div class="stat">
    <strong><%= number_with_delimiter(@stats[:total_posts]) %></strong>
    <span>Posts</span>
  </div>
  <div class="stat">
    <strong><%= number_with_delimiter(@stats[:total_likes]) %></strong>
    <span>Likes</span>
  </div>
  <div class="stat">
    <strong><%= number_with_delimiter(@stats[:total_shares]) %></strong>
    <span>Shares</span>
  </div>
</div>

<!-- Related Hashtags -->
<div class="related-tags">
  <h3>Related Hashtags</h3>
  <% @related_tags.each do |tag| %>
    <%= link_to "##{tag}", hashtag_posts_path(tag: tag), class: "badge" %>
  <% end %>
</div>

<!-- Posts with this hashtag -->
<div class="feed">
  <% @posts.each do |post| %>
    <%= render "post_card", post: post %>
  <% end %>
</div>

# Usage:
# Create post with hashtags in content
post = Post.create!(
  user: current_user,
  content: "Just launched my new #Rails app with #Ruby! Check it out #WebDev #Programming",
  published_at: Time.current
)

# Hashtags automatically extracted
post.hashtags
# => ["rails", "ruby", "webdev", "programming"]

# Or manually add hashtags
post.tag_with("tutorial", "beginner-friendly")

# Find trending hashtags
TrendingService.trending_hashtags(limit: 20)
# => [["rails", 145], ["ruby", 120], ["webdev", 98], ...]

# Hashtag engagement stats
TrendingService.hashtag_engagement("rails")
# => {
#   total_posts: 145,
#   total_likes: 2340,
#   total_shares: 567,
#   avg_engagement: 16.14
# }

# Related hashtags (co-occurrence)
Post.related_tags("rails", limit: 10)
# => ["ruby", "webdev", "activerecord", "api", "tutorial", ...]

# Search posts by hashtag
Post.search(
  { hashtags_contains: "rails", published_at_present: true },
  pagination: { page: 1, per_page: 20 },
  orders: [:sort_likes_count_desc]
)
```

### Example 5: Knowledge Base/Wiki

Article organization with topic tagging, related content, and version tracking:

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  include BetterModel

  belongs_to :created_by, class_name: "User"
  belongs_to :category
  has_many :article_links, dependent: :destroy
  has_many :linked_articles, through: :article_links

  serialize :topic_tags, coder: JSON, type: Array

  # Article statuses
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :outdated, -> { updated_at < 1.year.ago && status == "published" }
  is :popular, -> { view_count > 1000 }

  # Topic tagging
  TOPIC_AREAS = ["getting-started", "tutorial", "how-to", "reference", "troubleshooting",
                 "api", "security", "performance", "deployment", "testing"]
  DIFFICULTY_LEVELS = ["beginner", "intermediate", "advanced", "expert"]
  TECH_TAGS = ["ruby", "rails", "javascript", "react", "postgresql", "redis", "docker"]

  ALL_TAGS = TOPIC_AREAS + DIFFICULTY_LEVELS + TECH_TAGS

  taggable do
    tag_field :topic_tags
    normalize true
    strip true
    validates_tags minimum: 1,
                  maximum: 10,
                  allowed_tags: ALL_TAGS
  end

  # Archiving for outdated content
  archivable do
    skip_archived_by_default true
  end

  # Version tracking
  traceable do
    track :title, :content, :topic_tags, :status
  end

  # Search
  predicates :title, :content, :topic_tags, :status, :category_id
  sort :title, :view_count, :updated_at, :created_at

  searchable do
    per_page 30
    max_per_page 100
    default_order [:sort_updated_at_desc]
  end

  # Callbacks
  after_update :check_if_outdated
  before_save :extract_links

  private

  def check_if_outdated
    if is?(:outdated) && !archived?
      # Notify maintainers
      ArticleMailer.outdated_content(self).deliver_later
    end
  end

  def extract_links
    # Extract [[article-slug]] wiki-style links
    wiki_links = content.scan(/\[\[(.+?)\]\]/).flatten
    # Implementation to create article_links
  end
end

# app/services/article_recommendation_service.rb
class ArticleRecommendationService
  def initialize(article)
    @article = article
  end

  # Find related articles by shared tags
  def related_by_tags(limit: 5)
    return [] if @article.topic_tags.empty?

    Article.where.not(id: @article.id)
           .where(status: "published")
           .where.not(archived_at: nil)
           .limit(50)
           .select { |a| (a.topic_tags & @article.topic_tags).any? }
           .sort_by { |a| similarity_score(a) }
           .reverse
           .first(limit)
  end

  # Find articles in same category
  def related_by_category(limit: 5)
    Article.where(category_id: @article.category_id)
           .where.not(id: @article.id)
           .where(status: "published")
           .order(view_count: :desc)
           .limit(limit)
  end

  # Find prerequisite articles (for tutorials)
  def prerequisites
    return [] unless @article.topic_tags.include?("tutorial")

    difficulty_order = ["beginner", "intermediate", "advanced", "expert"]
    current_difficulty = @article.topic_tags.find { |t| difficulty_order.include?(t) }
    return [] unless current_difficulty

    current_index = difficulty_order.index(current_difficulty)
    prerequisite_difficulties = difficulty_order[0...current_index]

    Article.where(status: "published")
           .limit(50)
           .select { |a| (a.topic_tags & prerequisite_difficulties).any? &&
                        (a.topic_tags & @article.topic_tags).size >= 2 }
           .sort_by(&:view_count)
           .reverse
           .first(3)
  end

  private

  def similarity_score(other_article)
    shared_tags = @article.topic_tags & other_article.topic_tags
    weight = shared_tags.size

    # Boost if same difficulty level
    difficulty_tags = Article::DIFFICULTY_LEVELS
    if (@article.topic_tags & difficulty_tags).any? &&
       (other_article.topic_tags & difficulty_tags).any? &&
       (@article.topic_tags & difficulty_tags) == (other_article.topic_tags & difficulty_tags)
      weight += 2
    end

    weight
  end
end

# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      build_search_params,
      pagination: { page: params[:page], per_page: 30 },
      orders: [:sort_updated_at_desc]
    )

    # Topic cloud
    @popular_topics = Article.popular_tags(limit: 30)
  end

  def show
    @article = Article.find(params[:id])
    @article.increment!(:view_count)

    # Recommendations
    service = ArticleRecommendationService.new(@article)
    @related_articles = service.related_by_tags(limit: 5)
    @category_articles = service.related_by_category(limit: 5)
    @prerequisites = service.prerequisites

    # Version history
    @versions = @article.versions.order(created_at: :desc).limit(10)
  end

  def by_topic
    @topic = params[:topic]
    @articles = Article.search(
      { topic_tags_contains: @topic, status_eq: "published" },
      pagination: { page: params[:page], per_page: 30 },
      orders: [:sort_view_count_desc]
    )

    # Related topics
    @related_topics = Article.related_tags(@topic, limit: 10)

    # Topic stats
    @article_count = Article.where("topic_tags LIKE ?", "%#{@topic}%")
                           .where(status: "published")
                           .count
  end

  def topics
    @all_topics = {
      "Topic Areas" => Article::TOPIC_AREAS,
      "Difficulty" => Article::DIFFICULTY_LEVELS,
      "Technologies" => Article::TECH_TAGS
    }

    @topic_counts = Article.tag_counts
  end

  private

  def build_search_params
    search_params = { status_eq: "published" }

    search_params[:title_i_cont] = params[:q] if params[:q].present?
    search_params[:topic_tags_contains] = params[:topic] if params[:topic].present?
    search_params[:category_id_eq] = params[:category_id] if params[:category_id].present?

    search_params
  end
end

# app/views/articles/show.html.erb
<article>
  <h1><%= @article.title %></h1>

  <div class="article-meta">
    <span>By <%= @article.created_by.name %></span>
    <span>Updated <%= time_ago_in_words(@article.updated_at) %> ago</span>
    <span><%= @article.view_count %> views</span>
  </div>

  <!-- Topic Tags -->
  <div class="article-topics">
    <% @article.topic_tags.each do |tag| %>
      <%= link_to tag, articles_by_topic_path(topic: tag), class: "topic-badge" %>
    <% end %>
  </div>

  <!-- Content -->
  <div class="article-content">
    <%= sanitize(@article.content) %>
  </div>

  <!-- Prerequisites (for tutorials) -->
  <% if @prerequisites.any? %>
    <div class="prerequisites">
      <h3>Before You Start</h3>
      <p>You should first read:</p>
      <ul>
        <% @prerequisites.each do |prereq| %>
          <li><%= link_to prereq.title, prereq %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <!-- Related Articles -->
  <div class="related-articles">
    <h3>Related Articles</h3>
    <% @related_articles.each do |article| %>
      <div class="related-card">
        <%= link_to article.title, article %>
        <div class="topics">
          <% (article.topic_tags & @article.topic_tags).each do |tag| %>
            <span class="badge"><%= tag %></span>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Version History -->
  <div class="version-history">
    <h3>Revision History</h3>
    <% @versions.each do |version| %>
      <div class="version">
        <%= version.created_at.strftime("%Y-%m-%d %H:%M") %> -
        <%= User.find(version.updated_by_id).name %> -
        <%= version.updated_reason %>
      </div>
    <% end %>
  </div>
</article>

# Usage:
article = Article.create!(
  title: "Getting Started with Rails",
  content: "Rails is a web framework written in Ruby...",
  created_by: current_user,
  category: Category.find_by(name: "Guides"),
  status: "published",
  published_at: Time.current
)

# Tag with topic metadata
article.tag_with(
  "getting-started",  # Topic area
  "tutorial",         # Type
  "beginner",         # Difficulty
  "rails", "ruby"     # Technologies
)

# Find related articles
service = ArticleRecommendationService.new(article)
related = service.related_by_tags(limit: 5)

# Prerequisites for learning path
prerequisites = service.prerequisites
# Returns beginner articles with overlapping topics

# Popular topics for tag cloud
Article.popular_tags(limit: 30).each do |topic, count|
  puts "#{topic}: #{count} articles"
end

# Related topics
Article.related_tags("rails", limit: 10)
# => ["ruby", "activerecord", "tutorial", "api", ...]
```

(Continued due to length...)

The file is very long. Let me continue with the remaining examples and sections...
