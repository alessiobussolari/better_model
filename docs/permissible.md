## Permissible - Permission Management

### Basic Permission Usage

Define permissions using the `permit` DSL:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define permissions with lambdas
  permit :delete, -> { status != "published" }
  permit :edit, -> { status == "draft" || status == "scheduled" }
  permit :publish, -> { status == "draft" && title.present? }
  permit :archive, -> { created_at < 1.year.ago }
end
```

You can also use block syntax:

```ruby
class Article < ApplicationRecord
  include BetterModel

  permit :delete do
    status != "published"
  end
end
```

### Checking Permissions

```ruby
article = Article.find(1)

# Using permit? method
article.permit?(:delete)  # => true/false

# Using dynamic methods
article.permit_delete?    # => true/false
article.permit_edit?      # => true/false
article.permit_publish?   # => true/false
```

### Getting All Permissions

```ruby
# Get a hash of all permissions with their current values
article.permissions
# => { delete: true, edit: false, publish: false, archive: false }
```

### Helper Methods

```ruby
# Check if any permission is granted
article.has_any_permission?
# => true

# Check if all specified permissions are granted
article.has_all_permissions?([:edit, :delete])
# => true

# Filter and get only granted permissions from a list
article.granted_permissions([:edit, :delete, :publish, :archive])
# => [:delete] (only granted ones)
```

### Class Methods

```ruby
# Get all defined permission names
Article.defined_permissions
# => [:delete, :edit, :publish, :archive]

# Check if a permission is defined
Article.permission_defined?(:delete)
# => true

Article.permission_defined?(:nonexistent)
# => false
```

### JSON Serialization

Include permissions in JSON output when needed:

```ruby
# Without permissions (default)
article.as_json
# => { "id" => 1, "title" => "...", "status" => "draft", ... }

# With permissions
article.as_json(include_permissions: true)
# => {
#      "id" => 1,
#      "title" => "...",
#      "status" => "draft",
#      "permissions" => {
#        "delete" => true,
#        "edit" => false,
#        "publish" => false
#      }
#    }

# Include both statuses and permissions
article.as_json(include_statuses: true, include_permissions: true)
```

### Integration with Statusable

Permissions can reference statuses for powerful combinations:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }

  # Permissions reference statuses
  permit :delete, -> { is?(:draft) }
  permit :edit, -> { is?(:draft) || (is?(:published) && !is?(:expired)) }
  permit :publish, -> { is?(:draft) && valid? }
  permit :unpublish, -> { is?(:published) && !is?(:expired) }
end

article = Article.find(1)
article.permit_delete?    # => true/false based on draft status
article.permit_edit?      # => true/false based on status and expiration
```

### Real-World Permission Examples

**E-commerce Order:**

```ruby
class Order < ApplicationRecord
  include BetterModel

  is :pending, -> { status == "pending" }
  is :paid, -> { payment_status == "paid" }
  is :shipped, -> { status == "shipped" }

  permit :cancel, -> { is?(:pending) || (is?(:paid) && !is?(:shipped)) }
  permit :refund, -> { is?(:paid) && !is?(:shipped) }
  permit :ship, -> { is?(:paid) && !is?(:shipped) }
  permit :mark_delivered, -> { is?(:shipped) }
end

order = Order.find(1)
order.permit_cancel?    # => true (can cancel if not shipped)
order.permit_refund?    # => true (can refund if paid but not shipped)
```

**Blog Post:**

```ruby
class Post < ApplicationRecord
  include BetterModel

  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" }
  is :archived, -> { archived_at.present? }

  permit :edit, -> { is?(:draft) || is?(:published) }
  permit :delete, -> { is?(:draft) }
  permit :publish, -> { is?(:draft) && valid?(:publication) }
  permit :unpublish, -> { is?(:published) }
  permit :archive, -> { is?(:published) && created_at < 1.year.ago }
  permit :restore, -> { is?(:archived) }
end
```

**User Account:**

```ruby
class User < ApplicationRecord
  include BetterModel

  is :active, -> { !suspended_at }
  is :suspended, -> { suspended_at.present? }
  is :admin, -> { role == "admin" }

  permit :login, -> { is?(:active) && email_verified_at.present? }
  permit :change_password, -> { is?(:active) }
  permit :delete_account, -> { is?(:active) && !is?(:admin) }
  permit :suspend_users, -> { is?(:admin) }
  permit :unsuspend, -> { is?(:suspended) && suspension_expires_at < Time.current }
end
```

### Permission Best Practices

1. **Use action verbs for permission names** - `delete`, `edit`, `publish` (not `deletable`, `can_delete`)
2. **Reference statuses when appropriate** - Use `is?(:status)` for cleaner logic
3. **Keep conditions simple** - Complex logic should be moved to private methods
4. **Avoid database queries in conditions** - Use loaded associations or cached values
5. **Document complex permissions** - Add comments explaining non-obvious business rules

### Permission Error Handling

Permissible raises ConfigurationError for invalid configuration with full Sentry-compatible error data:

```ruby
# Missing condition
begin
  permit :delete
rescue BetterModel::Errors::Permissible::ConfigurationError => e
  # Error attributes
  e.reason        # => "Condition proc or block is required"
  e.model_class   # => Article
  e.expected      # => "Proc or block"
  e.provided      # => nil

  # Sentry-compatible data
  e.tags     # => {error_category: 'configuration', module: 'permissible'}
  e.context  # => {model_class: 'Article'}
  e.extra    # => {reason: 'Condition proc or block is required', expected: 'Proc or block', provided: nil}

  # Error message
  e.message  # => "Condition proc or block is required (expected: \"Proc or block\")"
end

# Blank permission name
begin
  permit "", -> { true }
rescue BetterModel::Errors::Permissible::ConfigurationError => e
  e.reason   # => "Permission name cannot be blank"
  e.message  # => "Permission name cannot be blank"
end

# Non-callable condition
begin
  permit :delete, "not a proc"
rescue BetterModel::Errors::Permissible::ConfigurationError => e
  e.reason      # => "Condition must respond to call"
  e.provided    # => "not a proc"
  e.message     # => "Condition must respond to call (provided: \"not a proc\")"
end
```

Undefined permissions return `false` by default (secure by default):

```ruby
article.permit?(:nonexistent_permission)  # => false
```

**Integration with Sentry:**

```ruby
rescue_from BetterModel::Errors::Permissible::ConfigurationError do |error|
  Sentry.capture_exception(error, {
    tags: error.tags,
    contexts: { permissible: error.context },
    extra: error.extra
  })
end
```

