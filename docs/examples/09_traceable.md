# Traceable Examples

Traceable provides complete audit trail functionality with field-specific change tracking, time-travel capabilities, and rollback support.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Basic Change Tracking](#example-1-basic-change-tracking)
- [Example 2: Querying Version History](#example-2-querying-version-history)
- [Example 3: Field-Specific Changes](#example-3-field-specific-changes)
- [Example 4: Time Travel](#example-4-time-travel)
- [Example 5: Rollback](#example-5-rollback)
- [Example 6: Advanced Queries](#example-6-advanced-queries)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Migration - create versions table
class CreateArticleVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :article_versions do |t|
      t.string :item_type, null: false
      t.integer :item_id, null: false
      t.string :event, null: false
      t.json :object_changes
      t.integer :updated_by_id
      t.string :updated_reason
      t.datetime :created_at, null: false

      t.index [:item_type, :item_id]
      t.index :event
      t.index :created_at
      t.index :updated_by_id
    end
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel

  traceable do
    track :title, :content, :status, :published_at
    versions_table :article_versions
  end
end
```

## Example 1: Basic Change Tracking

```ruby
# Create article
article = Article.create!(
  title: "Original Title",
  content: "Original content",
  status: "draft"
)

# Check versions
article.versions.count
# => 1 (created event)

article.versions.first.event
# => "created"

# Update tracked field
article.update!(title: "Updated Title")

article.versions.count
# => 2 (created + updated)

# Latest version
version = article.versions.last
version.event
# => "updated"

version.object_changes
# => {
#   "title" => ["Original Title", "Updated Title"]
# }

# Update non-tracked field (no version created)
article.update!(view_count: 100)
article.versions.count
# => 2 (unchanged, view_count not tracked)
```

**Output Explanation**: Traceable only records changes to specified tracked fields.

## Example 2: Querying Version History

```ruby
article = Article.create!(title: "Article", status: "draft")

# Make several changes
article.update!(title: "Updated Article", updated_by: User.find(1))
article.update!(status: "published", updated_by: User.find(1))
article.update!(title: "Final Title", updated_by: User.find(2))

# Get all versions
article.versions.count
# => 4 (1 created + 3 updates)

# Query by event type
article.versions.where(event: "created").count
# => 1

article.versions.where(event: "updated").count
# => 3

# Query by user
article.versions_by_user(1).count
# => 2

article.versions_by_user(2).count
# => 1

# Query by date range
article.versions_between(1.week.ago, Time.current).count
# => 4

# Recent versions
article.recent_versions(7.days).count
# => 4
```

**Output Explanation**: Versions table is fully queryable with helper methods.

## Example 3: Field-Specific Changes

```ruby
article = Article.create!(
  title: "Article",
  content: "Content",
  status: "draft",
  published_at: nil
)

# Track changes to specific field
article.update!(title: "New Title", content: "New Content")
article.update!(status: "published", published_at: Time.current)
article.update!(title: "Final Title")

# Get all records that changed a specific field
Article.field_changed(:title).pluck(:title)
# => ["Final Title"]

# Find changes to title containing specific text
Article.field_changed_from_to(:title, "New Title", "Final Title")
# => [article]

# Check if field was ever changed
article.field_changed?(:title)
# => true

article.field_changed?(:view_count)
# => false (not tracked)

# Get all changes for a field
article.field_changes(:title)
# => [
#   {from: "Article", to: "New Title", at: <timestamp>, by: <user_id>},
#   {from: "New Title", to: "Final Title", at: <timestamp>, by: <user_id>}
# ]

# Count field changes
article.field_change_count(:title)
# => 2

article.field_change_count(:status)
# => 1
```

**Output Explanation**: Field-specific methods provide detailed change history per field.

## Example 4: Time Travel

Retrieve record state at a specific point in time:

```ruby
article = Article.create!(
  title: "Version 1",
  content: "Content 1",
  status: "draft"
)

# Update several times
Timecop.travel(1.day.ago) do
  article.update!(title: "Version 2", content: "Content 2")
end

Timecop.travel(12.hours.ago) do
  article.update!(status: "published")
end

article.update!(title: "Version 3")

# Current state
article.title
# => "Version 3"

article.status
# => "published"

# State 1 day ago
past_article = article.at_time(1.day.ago)
past_article.title
# => "Version 2"

past_article.status
# => "draft"

# State 12 hours ago
past_article = article.at_time(12.hours.ago)
past_article.title
# => "Version 2"

past_article.status
# => "published"

# State yesterday (date-based)
past_article = article.on_date(Date.yesterday)
past_article.title
# => "Version 2"
```

**Output Explanation**: Time travel returns a frozen snapshot of the record at that point in time.

## Example 5: Rollback

Undo changes by rolling back to a previous version:

```ruby
article = Article.create!(
  title: "Original",
  content: "Original Content",
  status: "draft"
)

# Make changes
article.update!(title: "Change 1")
article.update!(title: "Change 2")
article.update!(title: "Change 3")

article.title
# => "Change 3"

# Get specific version
version = article.versions.where(event: "updated").first

# Rollback to that version
article.rollback_to(version)

article.title
# => "Change 1"

article.reload.title
# => "Change 1" (persisted)

# Rollback by version ID
article.update!(title: "Change 4")
first_version_id = article.versions.first.id

article.rollback_to(first_version_id)
article.title
# => "Original"

# Rollback validation
article.rollback_to(999999)
# => ActiveRecord::RecordNotFound: Version not found
```

**Output Explanation**: Rollback restores tracked fields to their state in a specific version.

## Example 6: Advanced Queries

```ruby
# Track with user and reason
article = Article.create!(
  title: "Article",
  status: "draft"
)

article.update_with_reason!(
  { title: "Updated" },
  by: User.find(1),
  reason: "Fixed typo"
)

version = article.versions.last
version.updated_by_id
# => 1

version.updated_reason
# => "Fixed typo"

# Query by reason
Article.versions_with_reason("Fixed typo")
# => [version]

# Complex version queries
article.versions
  .where(event: "updated")
  .where("created_at >= ?", 1.week.ago)
  .order(created_at: :desc)

# Diff between versions
v1 = article.versions.first
v2 = article.versions.last

diff = v2.object_changes
# => {"title" => ["Original", "Updated"]}

# Restore specific fields only
article.update!(
  title: "Different Title",
  content: "Different Content"
)

old_version = article.versions.find_by(event: "created")
article.rollback_to(old_version, only: [:title])

article.title
# => "Article" (restored)

article.content
# => "Different Content" (unchanged)
```

**Output Explanation**: Advanced features support fine-grained tracking and restoration.

## Integration Examples

### With Traceable User Tracking

```ruby
class Article < ApplicationRecord
  include BetterModel

  belongs_to :user, optional: true

  traceable do
    track :title, :content, :status
  end

  # Override update to automatically track user
  def update_tracked!(attrs, by:, reason: nil)
    transaction do
      update!(attrs)
      versions.last&.update!(
        updated_by_id: by.id,
        updated_reason: reason
      )
    end
  end
end

# Usage
article = Article.create!(title: "Article")

article.update_tracked!(
  { title: "Updated" },
  by: current_user,
  reason: "Editorial review"
)

# All versions now tracked
article.versions.last.updated_by_id
# => current_user.id
```

### With State Machines

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    state :draft, initial: true
    state :published

    transition :publish, from: :draft, to: :published do
      after :track_publish
    end
  end

  traceable do
    track :state, :published_at
  end

  private

  def track_publish
    versions.last&.update!(
      updated_by_id: Current.user&.id,
      updated_reason: "Published article"
    )
  end
end

article = Article.create!(title: "Article")
article.publish!

article.versions.last.object_changes
# => {
#   "state" => ["draft", "published"],
#   "published_at" => [nil, <timestamp>]
# }
```

### Audit Trail UI

```ruby
# Controller
class ArticleVersionsController < ApplicationController
  def index
    @article = Article.find(params[:article_id])
    @versions = @article.versions
      .includes(:updated_by)
      .order(created_at: :desc)
      .page(params[:page])
  end

  def show
    @article = Article.find(params[:article_id])
    @version = @article.versions.find(params[:id])
    @article_at_version = @article.at_version(@version)
  end

  def rollback
    @article = Article.find(params[:article_id])
    @version = @article.versions.find(params[:id])

    @article.rollback_to(@version)
    redirect_to @article, notice: "Rolled back to version from #{@version.created_at}"
  end
end

# View (index.html.erb)
<h2>Version History for <%= @article.title %></h2>

<table>
  <thead>
    <tr>
      <th>Date</th>
      <th>Event</th>
      <th>Changes</th>
      <th>Updated By</th>
      <th>Reason</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @versions.each do |version| %>
      <tr>
        <td><%= version.created_at.to_s(:long) %></td>
        <td><%= version.event %></td>
        <td>
          <% version.object_changes&.each do |field, (old_val, new_val)| %>
            <div>
              <strong><%= field %>:</strong>
              <%= old_val %> → <%= new_val %>
            </div>
          <% end %>
        </td>
        <td><%= version.updated_by&.name || "System" %></td>
        <td><%= version.updated_reason %></td>
        <td>
          <%= link_to "View", article_version_path(@article, version) %>
          <%= link_to "Rollback", rollback_article_version_path(@article, version),
              method: :post, data: { confirm: "Rollback to this version?" } %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>

<%= paginate @versions %>
```

## Tips & Best Practices

### 1. Only Track Important Fields
```ruby
# Good: Track business-critical fields
traceable do
  track :title, :content, :status, :published_at
end

# Bad: Track everything (performance impact)
traceable do
  track :title, :content, :status, :view_count, :likes_count, :shares_count
end
```

### 2. Add Proper Indexes
```ruby
class CreateArticleVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :article_versions do |t|
      # ... columns

      # Essential indexes
      t.index [:item_type, :item_id]  # Most queries
      t.index :created_at              # Time-based queries
      t.index :event                   # Event filtering
      t.index :updated_by_id          # User tracking
    end
  end
end
```

### 3. Clean Up Old Versions
```ruby
# Rake task to clean old versions
namespace :versions do
  desc "Clean versions older than 1 year"
  task cleanup: :environment do
    cutoff = 1.year.ago

    ArticleVersion.where("created_at < ?", cutoff)
      .where.not(event: "created")  # Keep created events
      .delete_all
  end
end

# Or with retention policy
class Article < ApplicationRecord
  traceable do
    track :title, :content
    retain_versions_for 90.days  # Keep only recent versions
  end
end
```

### 4. Use Transactions for Consistency
```ruby
# Always use transactions when rollback affects multiple records
def restore_article_to_previous_state
  ActiveRecord::Base.transaction do
    article.rollback_to(previous_version)
    article.update!(restored_at: Time.current, restored_by: current_user)
    ArticleRestorationLog.create!(article: article, version: previous_version)
  end
end
```

### 5. Consider Storage Implications
```ruby
# For large text fields, consider compression
class CreateArticleVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :article_versions do |t|
      # Use compressed JSON on PostgreSQL
      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        t.jsonb :object_changes, default: {}, null: false, compression: :pglz
      else
        t.json :object_changes
      end

      t.timestamps
    end
  end
end
```

### 6. Test Version Tracking
```ruby
RSpec.describe Article, type: :model do
  describe "version tracking" do
    it "creates version on update" do
      article = Article.create!(title: "Original")

      expect {
        article.update!(title: "Updated")
      }.to change { article.versions.count }.by(1)
    end

    it "tracks field changes" do
      article = Article.create!(title: "Original")
      article.update!(title: "Updated")

      version = article.versions.last
      expect(version.object_changes["title"]).to eq(["Original", "Updated"])
    end

    it "supports rollback" do
      article = Article.create!(title: "Original")
      article.update!(title: "Changed")

      first_version = article.versions.first
      article.rollback_to(first_version)

      expect(article.reload.title).to eq("Original")
    end
  end
end
```

## Related Documentation

- [Main README](../../README.md#traceable) - Full Traceable documentation
- [Stateable Examples](08_stateable.md) - Track state transitions
- [Test File](../../test/better_model/traceable_test.rb) - Complete test coverage

---

[← Stateable Examples](08_stateable.md) | [Back to Examples Index](README.md)
