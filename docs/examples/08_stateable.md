# Stateable Examples

Stateable provides a declarative state machine with transitions, guards, and callbacks—perfect for modeling complex workflows.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Simple State Machine](#example-1-simple-state-machine)
- [Example 2: Transitions with Guards](#example-2-transitions-with-guards)
- [Example 3: Callbacks](#example-3-callbacks)
- [Example 4: Multiple Transitions](#example-4-multiple-transitions)
- [Example 5: Integration with Other Modules](#example-5-integration-with-other-modules)
- [Example 6: Complex Workflow](#example-6-complex-workflow)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Migration - uses existing string column for state
class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :state, default: "draft", null: false
      t.string :title
      t.timestamps
    end

    add_index :articles, :state
  end
end

# Model
class Article < ApplicationRecord
  include BetterModel

  stateable do
    state :draft, initial: true
    state :published
    state :archived

    transition :publish, from: :draft, to: :published
    transition :archive, from: [:draft, :published], to: :archived
  end
end
```

## Example 1: Simple State Machine

```ruby
article = Article.create!(title: "My Article")

article.state
# => "draft"

article.draft?
# => true

# Transition to published
article.publish!

article.state
# => "published"

article.published?
# => true

article.draft?
# => false

# Invalid transition
article.publish!
# => BetterModel::InvalidTransitionError: Cannot transition from published to published

# Archive from published
article.archive!
article.archived?
# => true
```

**Output Explanation**: State machine manages valid state transitions and provides helper methods.

## Example 2: Transitions with Guards

Guards prevent transitions unless conditions are met:

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    state :draft, initial: true
    state :published
    state :archived

    transition :publish, from: :draft, to: :published do
      # Method guard
      guard :content_complete?

      # Inline lambda guard
      guard { title.present? && content.present? }

      # Multiple guards (all must pass)
      guard :reviewed?
      guard :has_featured_image?
    end

    transition :archive, from: [:draft, :published], to: :archived
  end

  private

  def content_complete?
    title.present? && content.present? && content.length >= 100
  end

  def reviewed?
    reviewed_by_id.present?
  end

  def has_featured_image?
    featured_image_url.present?
  end
end

# Incomplete article
article = Article.create!(title: "Draft")

article.publish!
# => BetterModel::GuardFailedError: Guard 'content_complete?' failed

# Complete article
article.update!(
  content: "A" * 100,
  reviewed_by_id: 1,
  featured_image_url: "http://example.com/image.jpg"
)

article.publish!
# => Success
article.published?
# => true
```

**Output Explanation**: Guards ensure articles meet requirements before publishing.

## Example 3: Callbacks

Execute code before/after transitions:

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    state :draft, initial: true
    state :published
    state :archived

    transition :publish, from: :draft, to: :published do
      # Before transition
      before :set_published_at
      before { self.published_by = Current.user }

      # After transition
      after :notify_subscribers
      after :update_search_index
      after { Rails.logger.info "Published: #{title}" }
    end

    transition :unpublish, from: :published, to: :draft do
      before { self.published_at = nil }
    end

    transition :archive, from: [:draft, :published], to: :archived do
      before :set_archived_at
      after :cleanup_cache
    end
  end

  private

  def set_published_at
    self.published_at = Time.current
  end

  def set_archived_at
    self.archived_at = Time.current
  end

  def notify_subscribers
    ArticleMailer.new_article(self).deliver_later
  end

  def update_search_index
    Article SearchIndexJob.perform_later(id)
  end

  def cleanup_cache
    Rails.cache.delete("article_#{id}")
  end
end

article = Article.create!(title: "Article with Callbacks")
article.publish!

# Callbacks executed:
# 1. before: set_published_at
# 2. before: set published_by
# 3. State changes to "published"
# 4. after: notify_subscribers
# 5. after: update_search_index
# 6. after: log message

article.published_at
# => 2025-10-30 10:30:00 UTC

article.published_by
# => <User id=1>
```

**Output Explanation**: Callbacks automate actions when state changes.

## Example 4: Multiple Transitions

Model complex workflows with multiple transition paths:

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    state :draft, initial: true
    state :review
    state :published
    state :archived

    # Draft → Review
    transition :submit_for_review, from: :draft, to: :review do
      guard { content_complete? }
    end

    # Review → Published
    transition :approve, from: :review, to: :published do
      guard { reviewed_by_id.present? }
      before { self.published_at = Time.current }
      after { notify_author }
    end

    # Review → Draft (rejected)
    transition :reject, from: :review, to: :draft do
      before { self.rejection_reason = "Needs improvement" }
      after { notify_author_rejection }
    end

    # Published → Archived
    transition :archive, from: :published, to: :archived

    # Archived → Draft (restore)
    transition :restore, from: :archived, to: :draft do
      before { self.archived_at = nil }
    end
  end
end

# Workflow
article = Article.create!(title: "Article", content: "...")

article.draft?
# => true

article.submit_for_review!
article.review?
# => true

# Reviewer approves
article.update!(reviewed_by_id: 1)
article.approve!
article.published?
# => true

# Or reviewer rejects
# article.reject!
# article.draft? => true
```

**Output Explanation**: Multiple transitions create flexible workflows with different paths.

## Example 5: Integration with Other Modules

Combine with Statusable, Permissible, and Archivable:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Statusable - define statuses based on state
  is :draft, -> { state == "draft" }
  is :published, -> { state == "published" }
  is :archived_state, -> { state == "archived" }

  # Permissible - permissions based on state
  permit :edit, -> { draft? || review? }
  permit :publish_action, -> { review? && reviewed_by_id.present? }
  permit :archive_action, -> { published? }

  # Stateable - state machine
  stateable do
    state :draft, initial: true
    state :review
    state :published
    state :archived

    transition :submit, from: :draft, to: :review do
      guard { can?(:submit_for_review) }
    end

    transition :publish, from: :review, to: :published do
      guard { can?(:publish_action) }
    end

    transition :archive, from: :published, to: :archived do
      guard { can?(:archive_action) }
      after { archive!(by: Current.user) }  # Archivable integration
    end
  end

  # Archivable - soft delete
  archivable
end

article = Article.create!(title: "Integrated Article")

# Check permissions before transitioning
article.can?(:edit)
# => true (draft state)

article.submit!

article.can?(:edit)
# => true (still editable in review)

article.can?(:publish_action)
# => false (needs reviewed_by_id)

article.update!(reviewed_by_id: 1)
article.publish!

article.can?(:archive_action)
# => true

article.archive!
article.archived?  # Archivable
# => true
article.archived_state?  # Stateable
# => true
```

**Output Explanation**: Modules work together for comprehensive model behavior.

## Example 6: Complex Workflow

Real-world article publishing workflow:

```ruby
class Article < ApplicationRecord
  include BetterModel

  stateable do
    # States
    state :draft, initial: true
    state :pending_review
    state :in_review
    state :changes_requested
    state :approved
    state :scheduled
    state :published
    state :unpublished
    state :archived

    # Submit for review
    transition :submit_for_review, from: [:draft, :changes_requested], to: :pending_review do
      guard :content_ready_for_review?
      after :notify_reviewers
    end

    # Start review
    transition :start_review, from: :pending_review, to: :in_review do
      guard { reviewer_id.present? }
      before { self.review_started_at = Time.current }
    end

    # Request changes
    transition :request_changes, from: :in_review, to: :changes_requested do
      guard { review_notes.present? }
      after :notify_author_changes
    end

    # Approve
    transition :approve, from: :in_review, to: :approved do
      guard { review_notes.present? }
      before { self.approved_at = Time.current }
      after :notify_author_approval
    end

    # Schedule
    transition :schedule, from: :approved, to: :scheduled do
      guard { scheduled_for.present? && scheduled_for.future? }
    end

    # Publish (from approved or scheduled)
    transition :publish, from: [:approved, :scheduled], to: :published do
      guard :ready_for_publication?
      before :set_published_at
      after :update_search_index
      after :notify_subscribers
    end

    # Unpublish
    transition :unpublish, from: :published, to: :unpublished do
      before { self.unpublished_at = Time.current }
      after :remove_from_search
    end

    # Archive
    transition :archive, from: [:published, :unpublished], to: :archived do
      before :set_archived_at
      after { archive!(by: Current.user) }
    end

    # Restore
    transition :restore_from_archive, from: :archived, to: :draft do
      before { self.archived_at = nil }
      after { restore! }  # Archivable restore
    end
  end

  private

  def content_ready_for_review?
    title.present? && content.present? && content.length >= 300
  end

  def ready_for_publication?
    approved? && featured_image_url.present?
  end

  def set_published_at
    self.published_at = scheduled_for || Time.current
  end

  def set_archived_at
    self.archived_at = Time.current
  end

  # Notification methods
  def notify_reviewers
    ReviewerMailer.new_article_for_review(self).deliver_later
  end

  def notify_author_changes
    AuthorMailer.changes_requested(self).deliver_later
  end

  def notify_author_approval
    AuthorMailer.article_approved(self).deliver_later
  end

  def notify_subscribers
    SubscriberMailer.new_article_published(self).deliver_later
  end

  def update_search_index
    SearchIndexJob.perform_later(id)
  end

  def remove_from_search
    SearchIndexJob.perform_later(id, action: :remove)
  end
end

# Complete workflow
article = Article.create!(title: "Complex Workflow", content: "..." * 100)

article.submit_for_review!
article.pending_review?
# => true

article.update!(reviewer_id: 1)
article.start_review!
article.in_review?
# => true

article.update!(review_notes: "Looks good!")
article.approve!
article.approved?
# => true

article.update!(featured_image_url: "...", scheduled_for: 2.days.from_now)
article.schedule!
article.scheduled?
# => true

# Auto-publish when scheduled_for arrives (via background job)
# article.publish!
# article.published? => true
```

**Output Explanation**: Complex workflows are clean and maintainable with Stateable.

## Tips & Best Practices

### 1. Keep States Focused
```ruby
# Good: Clear, distinct states
state :draft
state :published
state :archived

# Avoid: Ambiguous states
state :active  # Too vague
state :inactive  # What does this mean?
```

### 2. Use Guards for Business Logic
```ruby
# Good: Guard prevents invalid transitions
transition :publish, from: :draft, to: :published do
  guard { content.present? && title.present? }
  guard :reviewed_by_editor?
end

# Bad: Checking in controller
def publish
  if @article.content.present?
    @article.publish!
  end
end
```

### 3. Callbacks for Side Effects
```ruby
# Good: Callbacks handle side effects
transition :publish, from: :draft, to: :published do
  after :notify_subscribers
  after :update_search_index
end

# Avoid: Side effects in controller
def publish
  @article.publish!
  notify_subscribers(@article)
  update_search_index(@article)
end
```

### 4. Test State Machines Thoroughly
```ruby
RSpec.describe Article, type: :model do
  describe "state machine" do
    it "starts in draft state" do
      article = Article.create!
      expect(article).to be_draft
    end

    it "transitions from draft to published" do
      article = Article.create!
      article.publish!
      expect(article).to be_published
    end

    it "prevents invalid transitions" do
      article = Article.create!(state: "published")
      expect { article.publish! }.to raise_error(BetterModel::InvalidTransitionError)
    end

    it "enforces guards" do
      article = Article.create!(content: "")
      expect { article.publish! }.to raise_error(BetterModel::GuardFailedError)
    end
  end
end
```

### 5. Document Complex Workflows
```ruby
# Add comments for complex state machines
stateable do
  # Article Lifecycle:
  # 1. Draft → Review (author submits)
  # 2. Review → Approved/Rejected (editor reviews)
  # 3. Approved → Scheduled (optional)
  # 4. Scheduled/Approved → Published (auto or manual)
  # 5. Published → Archived (when outdated)

  state :draft, initial: true
  # ... states and transitions with comments
end
```

## Related Documentation

- [Main README](../../README.md#stateable) - Full Stateable documentation
- [Statusable Examples](01_statusable.md) - Define statuses based on states
- [Permissible Examples](02_permissible.md) - Permissions based on states
- [Test File](../../test/better_model/stateable_test.rb) - Complete test coverage

---

[← Validatable Examples](07_validatable.md) | [Back to Examples Index](README.md) | [Next: Traceable Examples →](09_traceable.md)
