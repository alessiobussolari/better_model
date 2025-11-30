# Permissible Examples

Permissible provides a declarative way to define permissions based on statuses or custom logic, making authorization checks clean and maintainable.

## Table of Contents
- [Basic Setup](#basic-setup)
- [Example 1: Simple Permissions](#example-1-simple-permissions)
- [Example 2: Status-based Permissions](#example-2-status-based-permissions)
- [Example 3: Role-based Permissions](#example-3-role-based-permissions)
- [Example 4: Time-based Permissions](#example-4-time-based-permissions)
- [Example 5: Complex Permission Logic](#example-5-complex-permission-logic)
- [Example 6: Multiple Permission Checks](#example-6-multiple-permission-checks)
- [Tips & Best Practices](#tips--best-practices)

## Basic Setup

```ruby
# Model
class Article < ApplicationRecord
  include BetterModel

  # Define statuses first
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }

  # Define permissions based on statuses
  permit :edit, -> { is?(:draft) }
  permit :delete, -> { is?(:draft) }
  permit :publish, -> { is?(:draft) }
end
```

## Example 1: Simple Permissions

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }

  permit :edit, -> { is?(:draft) }
  permit :delete, -> { is?(:draft) }
  permit :view, -> { is?(:published) }
end

# Usage
draft = Article.create!(title: "Draft Article", status: "draft")
published = Article.create!(title: "Published Article", status: "published")

# Check permissions
draft.can?(:edit)
# => true

draft.can?(:view)
# => false

published.can?(:edit)
# => false

published.can?(:view)
# => true

# Negation
draft.cannot?(:view)
# => true
```

**Output Explanation**: The `can?` method evaluates the permission lambda and returns true/false based on the current state.

## Example 2: Status-based Permissions

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :archived, -> { status == "archived" }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  # Permissions based on multiple statuses
  permit :edit, -> { is?(:draft) || (is?(:published) && is_not?(:expired)) }
  permit :delete, -> { is?(:draft) || is?(:archived) }
  permit :publish, -> { is?(:draft) }
  permit :archive, -> { is?(:published) || is?(:draft) }
  permit :restore, -> { is?(:archived) }
end

article = Article.create!(
  title: "Flexible Article",
  status: "published",
  expires_at: 7.days.from_now
)

article.can?(:edit)
# => true (published and not expired)

article.can?(:delete)
# => false (not draft or archived)

article.can?(:archive)
# => true (published)

# After expiration
article.update!(expires_at: 1.day.ago)
article.can?(:edit)
# => false (expired)
```

**Output Explanation**: Permissions can combine multiple status checks for fine-grained access control.

## Example 3: Role-based Permissions

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Assume user_id and role columns exist
  belongs_to :user

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :owned_by_current_user, -> { user_id == Current.user&.id }
  is :admin_user, -> { Current.user&.admin? }

  # Permissions considering ownership and roles
  permit :edit, -> {
    is?(:draft) && (is?(:owned_by_current_user) || is?(:admin_user))
  }

  permit :delete, -> {
    is?(:admin_user) || (is?(:draft) && is?(:owned_by_current_user))
  }

  permit :publish, -> {
    is?(:draft) && (is?(:owned_by_current_user) || is?(:admin_user))
  }

  permit :view, -> {
    is?(:published) || is?(:owned_by_current_user) || is?(:admin_user)
  }
end

# Usage with Current.user (Rails Current Attributes)
Current.user = User.find(1)  # Regular user

draft = Article.create!(
  title: "My Draft",
  status: "draft",
  user_id: Current.user.id
)

draft.can?(:edit)
# => true (owner and draft)

draft.can?(:delete)
# => true (owner and draft)

# Different user
Current.user = User.find(2)
draft.can?(:edit)
# => false (not owner, not admin)

# Admin user
Current.user = User.find_by(admin: true)
draft.can?(:edit)
# => true (admin can edit anything)
```

**Output Explanation**: Combine role checks with status checks for comprehensive authorization.

## Example 4: Time-based Permissions

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :recently_published, -> { published_at.present? && published_at >= 24.hours.ago }
  is :scheduled, -> { published_at.present? && published_at > Time.current }

  # Edit allowed only for drafts or recently published (within 24h)
  permit :edit, -> { is?(:draft) || is?(:recently_published) }

  # Can only reschedule if not yet published
  permit :reschedule, -> { is?(:scheduled) }

  # Delete only drafts or very old published articles
  permit :delete, -> {
    is?(:draft) || (is?(:published) && published_at < 1.year.ago)
  }
end

# Immediate publish
article = Article.create!(
  title: "Breaking News",
  status: "published",
  published_at: Time.current
)

article.can?(:edit)
# => true (recently published)

# After 25 hours
# article.can?(:edit) => false (no longer recent)

# Scheduled article
scheduled = Article.create!(
  title: "Future Post",
  status: "published",
  published_at: 2.days.from_now
)

scheduled.can?(:reschedule)
# => true

scheduled.can?(:edit)
# => false (not published yet)
```

**Output Explanation**: Time-based permissions enable editing windows and scheduled content management.

## Example 5: Complex Permission Logic

```ruby
class Article < ApplicationRecord
  include BetterModel

  belongs_to :user
  has_many :comments

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :owner, -> { user_id == Current.user&.id }
  is :admin, -> { Current.user&.admin? }
  is :moderator, -> { Current.user&.moderator? }
  is :has_comments, -> { comments_count > 0 }
  is :featured, -> { featured == true }

  # Complex cascading permissions
  permit :edit, -> {
    return true if is?(:admin)
    return true if is?(:draft) && is?(:owner)
    return true if is?(:published) && is?(:owner) && is_not?(:has_comments)
    false
  }

  permit :delete, -> {
    return true if is?(:admin)
    return false if is?(:featured)  # Never delete featured
    return true if is?(:draft) && is?(:owner)
    false
  }

  permit :feature, -> { is?(:admin) || is?(:moderator) }

  permit :comment, -> { is?(:published) }
end

Current.user = User.find(1)  # Regular user, owner

article = Article.create!(
  title: "Complex Article",
  status: "published",
  user_id: Current.user.id,
  comments_count: 0
)

article.can?(:edit)
# => true (owner, published, no comments yet)

article.update!(comments_count: 5)
article.can?(:edit)
# => false (has comments now)

article.can?(:delete)
# => false (not a draft)

article.can?(:feature)
# => false (not admin or moderator)

article.can?(:comment)
# => true (published)
```

**Output Explanation**: Use early returns in lambdas for complex cascading permission logic.

## Example 6: Multiple Permission Checks

```ruby
class Article < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  permit :edit, -> { is?(:draft) }
  permit :delete, -> { is?(:draft) }
  permit :publish, -> { is?(:draft) }
  permit :archive, -> { is?(:published) }
end

article = Article.create!(title: "Draft Article", status: "draft")

# Check multiple permissions at once
article.can?(:edit, :delete, :publish)
# => true (all three permissions are granted)

article.can?(:edit, :archive)
# => false (archive is not granted for drafts)

# Check with array
permissions_needed = [:edit, :delete]
article.can?(*permissions_needed)
# => true

# Get all granted permissions
article.update!(status: "published")
article.permissions
# => [:archive] (only archive is permitted for published)
```

**Output Explanation**: Check multiple permissions at once or get a list of all granted permissions.

## Tips & Best Practices

### 1. Keep Permissions Atomic
```ruby
# Good: Each permission is independent and clear
permit :edit, -> { is?(:draft) }
permit :delete, -> { is?(:draft) }
permit :publish, -> { is?(:draft) }

# Avoid: Shared complex logic
permit :edit, -> { complex_permission_logic }
permit :delete, -> { complex_permission_logic }
```

### 2. Use Statuses for Permission Logic
```ruby
# Good: Define status, use in permission
is :editable, -> { is?(:draft) || (is?(:published) && is_not?(:expired)) }
permit :edit, -> { is?(:editable) }

# Less clear: Inline all logic
permit :edit, -> {
  status == "draft" || (status == "published" && !expires_at&.<=(Time.current))
}
```

### 3. Document Complex Permissions
```ruby
class Article < ApplicationRecord
  include BetterModel

  # Articles can be edited by:
  # - Admins: always
  # - Owners: only drafts or published without comments
  # - Moderators: only to fix typos (not implemented yet)
  permit :edit, -> {
    return true if is?(:admin)
    return true if is?(:owner) && is?(:draft)
    return true if is?(:owner) && is?(:published) && is_not?(:has_comments)
    false
  }
end
```

### 4. Avoid N+1 in Permission Checks
```ruby
# Bad: Causes N+1 if checking permissions for multiple articles
permit :edit, -> { user.articles.include?(self) }

# Good: Use foreign key
permit :edit, -> { user_id == Current.user&.id }

# Also Good: Use counter cache
permit :delete, -> { comments_count == 0 }
```

### 5. Combine with Policy Objects
```ruby
class ArticlePolicy
  def initialize(user, article)
    @user = user
    @article = article
  end

  def edit?
    # Use BetterModel permissions internally
    @article.can?(:edit)
  end

  def delete?
    @article.can?(:delete)
  end
end

# In controller
def edit
  @article = Article.find(params[:id])
  authorize @article  # Uses ArticlePolicy which uses BetterModel
end
```

### 6. Test Permissions Thoroughly
```ruby
# In RSpec
RSpec.describe Article, type: :model do
  describe "permissions" do
    it "allows editing drafts" do
      article = Article.create!(status: "draft")
      expect(article.can?(:edit)).to be true
    end

    it "denies editing published articles" do
      article = Article.create!(status: "published")
      expect(article.can?(:edit)).to be false
    end
  end
end
```

## Integration with Authorization Gems

### Pundit
```ruby
class ArticlePolicy < ApplicationPolicy
  def edit?
    record.can?(:edit)
  end

  def destroy?
    record.can?(:delete)
  end
end
```

### CanCanCan
```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    can :edit, Article do |article|
      article.can?(:edit)
    end
  end
end
```

## Related Documentation

- [Main README](../../README.md#permissible) - Full Permissible documentation
- [Statusable Examples](01_statusable.md) - Define statuses for permissions
- [Stateable Examples](08_stateable.md) - Use permissions in state machine guards
- [Test File](../../test/better_model/permissible_test.rb) - Complete test coverage

---

[← Statusable Examples](01_statusable.md) | [Back to Examples Index](README.md) | [Next: Predicable Examples →](03_predicable.md)
