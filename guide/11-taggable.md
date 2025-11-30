# Taggable Examples

This guide provides practical, progressive examples of using `BetterModel::Taggable` for managing tags in Rails applications.

## Table of Contents

- [Basic Tag Management](#basic-tag-management)
- [CSV Tag Lists](#csv-tag-lists)
- [Tag Normalization](#tag-normalization)
- [Tag Validation](#tag-validation)
- [Tag Statistics and Analytics](#tag-statistics-and-analytics)
- [Integration with Predicable](#integration-with-predicable)
- [Integration with Searchable](#integration-with-searchable)
- [Advanced Integration Patterns](#advanced-integration-patterns)
- [Tips & Best Practices](#tips--best-practices)

---

## Basic Tag Management

### Adding and Removing Tags

```ruby
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
  end
end

# Create article and add tags
article = Article.create!(title: "Getting Started with Rails")

article.tag_with("ruby", "rails", "tutorial")
article.tags
# => ["ruby", "rails", "tutorial"]

# Add more tags (no duplicates)
article.tag_with("ruby", "beginner")
article.tags
# => ["ruby", "rails", "tutorial", "beginner"]

# Check if tagged
article.tagged_with?("ruby")   # => true
article.tagged_with?("python") # => false

# Remove tags
article.untag("beginner")
article.tags
# => ["ruby", "rails", "tutorial"]

# Replace all tags
article.retag("advanced", "performance", "optimization")
article.tags
# => ["advanced", "performance", "optimization"]
```

### Bulk Tag Operations

```ruby
# Add multiple tags at once
article.tag_with("ruby", "rails", "activerecord", "postgresql")

# Remove multiple tags at once
article.untag("rails", "activerecord")

# Replace with array
new_tags = ["docker", "deployment", "production"]
article.retag(*new_tags)
```

---

## CSV Tag Lists

### Import/Export Tags as Strings

```ruby
class Product < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :categories
    delimiter ","
  end
end

product = Product.create!(name: "Laptop")

# Import from CSV string
product.tag_list = "electronics, computers, laptops, apple"
product.categories
# => ["electronics", "computers", "laptops", "apple"]

# Export to CSV string
product.tag_list
# => "electronics, computers, laptops, apple"

# Works in forms
# <%= form.text_field :tag_list %>
```

### Custom Delimiter

```ruby
class Video < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    delimiter "|"  # Use pipe instead of comma
  end
end

video = Video.create!(title: "Rails Tutorial")
video.tag_list = "beginner|tutorial|rails|webdev"
video.tags
# => ["beginner", "tutorial", "rails", "webdev"]

video.tag_list
# => "beginner|tutorial|rails|webdev"
```

---

## Tag Normalization

### Automatic Lowercase and Trimming

```ruby
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true  # Automatic lowercase
    strip true      # Remove whitespace (default)
  end
end

article = Article.create!(title: "Test")

# All tags normalized automatically
article.tag_with("Ruby", "  Rails  ", "TUTORIAL")
article.tags
# => ["ruby", "rails", "tutorial"]

# CSV import also normalizes
article.tag_list = "Python, DJANGO,   flask   "
article.tags
# => ["python", "django", "flask"]

# Case-insensitive checks
article.tagged_with?("RUBY")     # => true
article.tagged_with?("ruby")     # => true
article.tagged_with?("Ruby")     # => true
```

### Length Constraints

```ruby
class Document < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :keywords
    normalize true
    min_length 3       # Reject tags shorter than 3 chars
    max_length 20      # Truncate tags longer than 20 chars
  end
end

doc = Document.create!(title: "Research Paper")

# Short tags ignored
doc.tag_with("ai", "ml", "deep-learning")
doc.keywords
# => ["deep-learning"]  # "ai" and "ml" rejected (< 3 chars)

# Long tags truncated
doc.tag_with("supercalifragilisticexpialidocious")
doc.keywords.last.length
# => 20
```

---

## Tag Validation

### Minimum and Maximum Tag Count

```ruby
class BlogPost < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
    validates_tags minimum: 1, maximum: 5
  end
end

# Too few tags
post = BlogPost.new(title: "Test")
post.valid?
# => false
post.errors[:tags]
# => ["must have at least 1 tags"]

# Just right
post.tag_with("ruby", "rails")
post.valid?
# => true

# Too many tags
post.tag_with("tutorial", "beginner", "advanced", "intermediate")
post.valid?
# => false
post.errors[:tags]
# => ["must have at most 5 tags"]
```

### Whitelist (Allowed Tags)

```ruby
class Product < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :categories
    normalize true
    validates_tags allowed_tags: ["electronics", "clothing", "books", "toys"]
  end
end

product = Product.new(name: "Laptop")

# Valid tags
product.tag_with("electronics")
product.valid?
# => true

# Invalid tags
product.tag_with("food")
product.valid?
# => false
product.errors[:categories]
# => ["contains invalid tags: food"]

# Multiple invalid tags
product.tag_list = "electronics, furniture, appliances"
product.valid?
# => false
product.errors[:categories]
# => ["contains invalid tags: furniture, appliances"]
```

### Blacklist (Forbidden Tags)

```ruby
class Comment < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :flags
    normalize true
    validates_tags forbidden_tags: ["spam", "offensive", "inappropriate"]
  end
end

comment = Comment.new(body: "Great article!")

# Clean tags
comment.tag_with("helpful", "insightful")
comment.valid?
# => true

# Forbidden tag
comment.tag_with("spam")
comment.valid?
# => false
comment.errors[:flags]
# => ["contains forbidden tags: spam"]
```

---

## Tag Statistics and Analytics

### Tag Counts Across Records

```ruby
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
  end
end

# Create sample data
Article.create!(title: "Rails Guide", tags: ["ruby", "rails", "tutorial"])
Article.create!(title: "Python Intro", tags: ["python", "tutorial", "beginner"])
Article.create!(title: "Rails API", tags: ["ruby", "rails", "api"])
Article.create!(title: "Rails Testing", tags: ["ruby", "rails", "testing"])

# Get all tag counts
Article.tag_counts
# => {
#   "ruby" => 3,
#   "rails" => 3,
#   "tutorial" => 2,
#   "python" => 1,
#   "beginner" => 1,
#   "api" => 1,
#   "testing" => 1
# }

# Get popular tags
Article.popular_tags(limit: 5)
# => [
#   ["ruby", 3],
#   ["rails", 3],
#   ["tutorial", 2],
#   ["python", 1],
#   ["beginner", 1]
# ]

# Display in view
<% Article.popular_tags(limit: 10).each do |tag, count| %>
  <%= link_to "#{tag} (#{count})", articles_path(tag: tag) %>
<% end %>
```

### Related Tags (Co-occurrence)

```ruby
# Find tags that appear with "rails"
Article.related_tags("rails", limit: 5)
# => ["ruby", "tutorial", "api", "testing"]

# Find tags that appear with "tutorial"
Article.related_tags("tutorial", limit: 3)
# => ["ruby", "rails", "python"]

# Use for tag suggestions
article = Article.new(tags: ["ruby"])
suggested = Article.related_tags("ruby", limit: 5)
# => ["rails", "tutorial", "api", "testing"]

# Display in form
<div class="tag-suggestions">
  <p>Suggested tags:</p>
  <% suggested.each do |tag| %>
    <%= link_to tag, "#", class: "tag-suggestion" %>
  <% end %>
</div>
```

### Building a Tag Cloud

```ruby
class TagCloudService
  def self.generate(limit: 50)
    counts = Article.popular_tags(limit: limit)
    max_count = counts.first[1]
    min_count = counts.last[1]

    counts.map do |tag, count|
      # Calculate relative size (1-5)
      size = if max_count == min_count
        3
      else
        1 + ((count - min_count) * 4.0 / (max_count - min_count)).round
      end

      { tag: tag, count: count, size: size }
    end
  end
end

# In view
<div class="tag-cloud">
  <% TagCloudService.generate.each do |item| %>
    <%= link_to item[:tag],
                articles_path(tag: item[:tag]),
                class: "tag tag-size-#{item[:size]}",
                title: "#{item[:count]} articles" %>
  <% end %>
</div>
```

---

## Integration with Predicable

Taggable automatically registers predicates for tag searches:

```ruby
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
  end
end

# Taggable auto-calls: predicates :tags

# Array contains value
Article.tags_contains("ruby")
# => SELECT * FROM articles WHERE 'ruby' = ANY(tags)

# Array overlaps with values
Article.tags_overlaps(["ruby", "python"])
# => SELECT * FROM articles WHERE tags && ARRAY['ruby', 'python']

# Array includes all values
Article.tags_contains_all(["ruby", "rails"])
# => SELECT * FROM articles WHERE tags @> ARRAY['ruby', 'rails']

# Combine with other predicates
Article.tags_contains("ruby").status_eq("published")
# => Articles tagged with "ruby" AND status is "published"

# Empty/present checks
Article.tags_empty          # No tags
Article.tags_present        # Has at least one tag
```

### Complex Tag Queries

```ruby
# Articles with Ruby OR Python
Article.tags_overlaps(["ruby", "python"])

# Articles with Ruby AND Rails
Article.tags_contains_all(["ruby", "rails"])

# Articles with Ruby but not Python
Article.tags_contains("ruby")
       .where.not(id: Article.tags_contains("python"))

# Articles with exactly 3 tags
Article.where("array_length(tags, 1) = ?", 3)

# Most tagged articles
Article.order(Arel.sql("array_length(tags, 1) DESC"))
```

---

## Integration with Searchable

Combine tag searches with Searchable's query builder:

```ruby
class Article < ApplicationRecord
  include BetterModel
  include BetterModel::Searchable

  taggable do
    tag_field :tags
    normalize true
  end

  predicates :title, :status, :tags, :published_at

  searchable do
    default_order [:sort_published_at_desc]
    per_page 25
  end
end

# Simple tag search via Searchable
results = Article.search({ tags_contains: "ruby" })
results.records
# => [<Article...>, <Article...>]

# Combined filters
results = Article.search({
  tags_contains: "ruby",
  status_eq: "published",
  published_at_gte: 1.year.ago
})

# Multiple tag search
results = Article.search({
  tags_overlaps: ["ruby", "python"],
  sort: "published_at_desc"
})

# Tag cloud with published filter
published_counts = Article.search({ status_eq: "published" })
                          .records
                          .each_with_object(Hash.new(0)) do |article, counts|
  article.tags.each { |tag| counts[tag] += 1 }
end.sort_by { |_, count| -count }.first(10)
```

### Controller Integration

```ruby
class ArticlesController < ApplicationController
  def index
    @results = Article.search(search_params)
    @articles = @results.records
    @popular_tags = Article.popular_tags(limit: 20)
  end

  def tagged
    @tag = params[:tag]
    @results = Article.search({
      tags_contains: @tag,
      status_eq: "published",
      sort: "published_at_desc"
    })
    @articles = @results.records
    @related_tags = Article.related_tags(@tag, limit: 10)
  end

  private

  def search_params
    params.permit(:tags_contains, :status_eq, :sort, :page)
  end
end
```

---

## Advanced Integration Patterns

### Taggable + Statusable + Archivable

```ruby
class Document < ApplicationRecord
  include BetterModel

  # Multiple concerns working together
  taggable do
    tag_field :tags
    normalize true
    validates_tags minimum: 1
  end

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }

  archivable do
    skip_archived_by_default true
  end

  predicates :tags, :status, :archived_at
end

# Complex queries
Document.tags_contains("important")
        .status_eq("published")
        .not_archived

# Tag popular documents only
Document.not_archived
        .where(status: "published")
        .tag_counts

# Find related tags for active documents
Document.not_archived.related_tags("legal", limit: 10)
```

### Taggable + Traceable (Audit Tag Changes)

```ruby
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
  end

  traceable do
    track :title, :tags, :status
  end
end

article = Article.create!(title: "Test", tags: ["ruby"])
article.update!(tags: ["ruby", "rails"])
article.update!(tags: ["python"])

# View tag history
article.versions.each do |version|
  if version.object_changes["tags"]
    old_tags, new_tags = version.object_changes["tags"]
    puts "#{version.event}: #{old_tags} => #{new_tags}"
  end
end
# Output:
# created: [] => ["ruby"]
# updated: ["ruby"] => ["ruby", "rails"]
# updated: ["ruby", "rails"] => ["python"]

# Rollback tags to previous version
previous_version = article.versions[-2]
article.rollback_to(previous_version)
article.tags
# => ["ruby", "rails"]
```

### Taggable + Permissible (Tag-based Permissions)

```ruby
class Project < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
  end

  is :internal, -> { tags.include?("internal") }
  is :confidential, -> { tags.include?("confidential") }
  is :public, -> { !is?(:internal) && !is?(:confidential) }

  permit :view, ->(user) {
    is?(:public) || user.admin? || (is?(:internal) && user.employee?)
  }

  permit :edit, ->(user) {
    user.admin? || (!is?(:confidential) && user.employee?)
  }
end

project = Project.create!(name: "API Redesign", tags: ["internal", "api"])

project.is?(:internal)      # => true
project.is?(:public)        # => false

project.permitted?(:view, employee_user)  # => true
project.permitted?(:view, guest_user)     # => false
```

### JSON Serialization for APIs

```ruby
class Product < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :categories
    normalize true
  end
end

product = Product.create!(
  name: "Laptop",
  categories: ["electronics", "computers", "apple"]
)

# Standard JSON
product.as_json
# => {"id"=>1, "name"=>"Laptop", "categories"=>["electronics", "computers", "apple"]}

# Include CSV tag list
product.as_json(include_tag_list: true)
# => {
#   "id" => 1,
#   "name" => "Laptop",
#   "categories" => ["electronics", "computers", "apple"],
#   "tag_list" => "electronics, computers, apple"
# }

# Include tag statistics
product.as_json(include_tag_stats: true)
# => {
#   "id" => 1,
#   "name" => "Laptop",
#   "categories" => ["electronics", "computers", "apple"],
#   "tag_stats" => {
#     "count" => 3,
#     "tags" => ["electronics", "computers", "apple"]
#   }
# }

# API controller
class Api::ProductsController < ApplicationController
  def show
    product = Product.find(params[:id])
    render json: product.as_json(
      include_tag_list: true,
      include_tag_stats: true,
      include: :manufacturer
    )
  end
end
```

---

## Tips & Best Practices

### Performance

**Cache Tag Counts**
```ruby
# Bad: Recalculate on every request
def index
  @popular_tags = Article.popular_tags(limit: 20)
end

# Good: Cache for 1 hour
def index
  @popular_tags = Rails.cache.fetch("popular_tags", expires_in: 1.hour) do
    Article.popular_tags(limit: 20)
  end
end

# Better: Invalidate on create/update
class Article < ApplicationRecord
  after_save :invalidate_tag_cache

  private

  def invalidate_tag_cache
    Rails.cache.delete("popular_tags") if saved_change_to_tags?
  end
end
```

**Use Database Indexes**
```ruby
# PostgreSQL GIN index for array searches
class AddTagsIndexToArticles < ActiveRecord::Migration[8.0]
  def change
    add_index :articles, :tags, using: :gin
  end
end
```

**Limit Statistics Scope**
```ruby
# Bad: Count across all records
Article.tag_counts

# Good: Scope to relevant records
Article.where(status: "published")
       .where("published_at > ?", 1.year.ago)
       .tag_counts
```

### Validation

**Validate Before Tag Operations**
```ruby
# Prevent invalid tags from being added
class Article < ApplicationRecord
  include BetterModel

  taggable do
    tag_field :tags
    normalize true
    min_length 2
    max_length 30
    validates_tags maximum: 10
  end

  # Ensure valid state
  def tag_with(*new_tags)
    super
    unless valid?
      reload  # Rollback invalid changes
      raise ActiveRecord::RecordInvalid, self
    end
  end
end
```

### User Input

**Sanitize User-Provided Tags**
```ruby
class ArticlesController < ApplicationController
  def create
    @article = Article.new(article_params)

    # Sanitize tag input
    if params[:article][:tag_list].present?
      @article.tag_list = sanitize_tags(params[:article][:tag_list])
    end

    if @article.save
      redirect_to @article
    else
      render :new
    end
  end

  private

  def sanitize_tags(tag_string)
    tag_string.gsub(/[^a-zA-Z0-9,\s\-_]/, '')  # Remove special chars
              .split(',')
              .map(&:strip)
              .reject(&:blank?)
              .first(10)  # Limit to 10 tags
              .join(', ')
  end
end
```

### Testing

**Test Tag Behavior in Models**
```ruby
# test/models/article_test.rb
class ArticleTest < ActiveSupport::TestCase
  test "normalizes tags on creation" do
    article = Article.create!(title: "Test", tags: ["Ruby", "RAILS"])
    assert_equal ["ruby", "rails"], article.tags
  end

  test "prevents duplicate tags" do
    article = Article.create!(title: "Test")
    article.tag_with("ruby", "ruby", "rails")
    assert_equal ["ruby", "rails"], article.tags
  end

  test "validates minimum tags" do
    article = Article.new(title: "Test", tags: [])
    assert_not article.valid?
    assert_includes article.errors[:tags], "must have at least 1 tags"
  end
end
```

### Common Patterns

**Tag Autocomplete**
```ruby
# Controller
class TagsController < ApplicationController
  def autocomplete
    query = params[:q].to_s.downcase

    # Get all tags matching query
    all_tags = Article.tag_counts.keys
    matching = all_tags.select { |tag| tag.start_with?(query) }
                       .sort
                       .first(10)

    render json: matching
  end
end

# JavaScript (Stimulus)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async search(event) {
    const query = event.target.value
    const response = await fetch(`/tags/autocomplete?q=${query}`)
    const tags = await response.json()
    this.showSuggestions(tags)
  }
}
```

**Tag Filtering UI**
```ruby
<!-- views/articles/index.html.erb -->
<div class="tag-filters">
  <% @popular_tags.each do |tag, count| %>
    <%= link_to articles_path(tag: tag),
                class: tag_filter_class(tag) do %>
      <%= tag %>
      <span class="count"><%= count %></span>
    <% end %>
  <% end %>

  <% if params[:tag].present? %>
    <%= link_to "Clear filter", articles_path, class: "clear-filter" %>
  <% end %>
</div>

<%= render @articles %>

<%# Helper %>
<% def tag_filter_class(tag)
  classes = ["tag-filter"]
  classes << "active" if params[:tag] == tag
  classes.join(" ")
end %>
```

**Batch Tagging**
```ruby
# Tag multiple records at once
class BulkTagService
  def self.tag_all(articles, *tags)
    Article.transaction do
      articles.each do |article|
        article.tag_with(*tags)
      end
    end
  end

  def self.retag_all(articles, *tags)
    Article.transaction do
      articles.each do |article|
        article.retag(*tags)
      end
    end
  end
end

# Usage
articles = Article.where(author_id: current_user.id)
BulkTagService.tag_all(articles, "featured", "promoted")
```

---

## Summary

Taggable provides powerful tag management with:

- **Simple API**: tag_with, untag, retag, tagged_with?
- **CSV Interface**: Import/export with tag_list
- **Smart Normalization**: Automatic lowercase, trimming, length control
- **Validation**: Min/max counts, whitelist, blacklist
- **Statistics**: Counts, popularity, co-occurrence
- **Search Integration**: Automatic Predicable registration
- **Flexibility**: Works with SQLite and PostgreSQL

For complete documentation, see [docs/taggable.md](../taggable.md).
