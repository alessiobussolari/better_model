# Security Policy

## Overview

BetterModel provides powerful query building capabilities for Rails applications. This document outlines security considerations, best practices, and protections built into the gem.

**IMPORTANT**: BetterModel does NOT provide authorization or authentication. It is designed to work alongside authorization gems like Pundit, CanCanCan, or your custom authorization layer.

## Vulnerability Reporting

If you discover a security vulnerability, please email [your-email@example.com] instead of using the issue tracker. We will respond within 48 hours.

## Security Features

### 1. SQL Injection Protection

BetterModel uses multiple layers of protection against SQL injection:

#### LIKE Pattern Sanitization

All LIKE predicates (`_cont`, `_start`, `_end`, `_i_cont`, etc.) automatically sanitize input using `ActiveRecord::Base.sanitize_sql_like`:

```ruby
# Safe: special characters are properly escaped
Article.title_cont("100% success")  # ✅ Escaped
Article.title_start("test_")        # ✅ Escaped

# Attempted SQL injection is neutralized
Article.title_cont("'; DROP TABLE articles;--")  # ✅ Safe - treated as literal string
```

#### Arel-Based Query Building

Most predicates use Arel for query construction, which provides automatic parameter binding:

```ruby
# These use Arel and are automatically safe
Article.title_eq("user input")
Article.view_count_gt(100)
Article.published_at_lteq(Date.today)
```

#### PostgreSQL-Specific Sanitization

Array and JSONB operations use proper escaping via `connection.quote`:

```ruby
# Safe with PostgreSQL
Article.tags_overlaps(["ruby", "rails"])
Article.metadata_has_key("user_provided_key")
```

### 2. Strong Parameters Protection

**IMPORTANT**: BetterModel no longer bypasses Rails' strong parameters protection.

#### Old Behavior (UNSAFE)
```ruby
# ❌ This would bypass strong parameters
Article.search(params[:search])  # Used to call to_unsafe_h internally
```

#### New Behavior (SAFE)
```ruby
# ✅ You must explicitly permit parameters
def index
  search_params = params.require(:search).permit(
    :title_eq, :status_eq, :view_count_gt
  )
  @articles = Article.search(search_params)
end

# Or use permit! if you trust the source
@articles = Article.search(params[:search].permit!)
```

If you pass unpermitted `ActionController::Parameters`, you'll get an error:

```ruby
Article.search(params[:search])
# => ArgumentError: ActionController::Parameters must be explicitly permitted
```

### 3. Security Validation

The `security` feature ensures required predicates are present, but **this is NOT authorization**:

```ruby
class Article < ApplicationRecord
  include BetterModel

  searchable do
    security :public_only, [:status_eq]  # Require status filter
  end
end

# This enforces that status_eq is provided
Article.search({ title_eq: "Test" }, security: :public_only)
# => InvalidSecurityError: requires status_eq

# This passes validation but doesn't validate the VALUE
Article.search({ status_eq: "admin_secret" }, security: :public_only)
# => ✅ Passes (but you need authorization to validate the value!)
```

**CRITICAL**: Security validation only checks that predicates **exist**, not that their **values are authorized**. You must implement authorization separately:

```ruby
# ❌ INSECURE - no authorization
def index
  @articles = Article.search(params[:search], security: :public_only)
end

# ✅ SECURE - with authorization
def index
  search_params = authorize_search_params(params[:search])
  @articles = Article.search(search_params, security: :public_only)
  authorize @articles  # Using Pundit
end

private

def authorize_search_params(params)
  # Only allow users to search their own articles
  params.merge(author_id_eq: current_user.id)
end
```

#### OR Condition Security

Security validation also applies to OR conditions to prevent bypasses:

```ruby
# ❌ This would fail - OR conditions must also include required predicates
Article.search(
  { status_eq: "published", or: [{ title_eq: "test" }] },
  security: :status_required
)
# => InvalidSecurityError: OR condition must include status_eq

# ✅ This passes
Article.search(
  { status_eq: "published", or: [{ status_eq: "draft", title_eq: "test" }] },
  security: :status_required
)
```

### 4. DoS Protection

BetterModel includes several protections against Denial of Service attacks:

#### Query Complexity Limits

```ruby
# Limit total predicates (default: 100)
Article.search({ title_eq: "...", status_eq: "...", ... })  # Max 100 predicates

# Limit OR conditions (default: 50)
Article.search({ or: [...] })  # Max 50 OR conditions

# Limit page number (default: 10,000)
Article.search({}, pagination: { page: 10_001, per_page: 10 })
# => InvalidPaginationError: page must be <= 10000 (DoS protection)
```

#### Configurable Limits

```ruby
class Article < ApplicationRecord
  include BetterModel

  searchable do
    max_predicates 50         # Default: 100
    max_or_conditions 25      # Default: 50
    max_page 5_000           # Default: 10,000
    max_per_page 100         # Default: unlimited
  end
end
```

#### Why These Limits Matter

- **Large offsets are slow**: `OFFSET 999900` forces the database to skip 999900 rows
- **Complex queries consume resources**: 100+ predicates can generate expensive SQL
- **OR conditions multiply complexity**: Each OR creates a separate subquery

### 5. Predicate Validation

Only registered predicates can be used:

```ruby
Article.search({ destroy_all: true })
# => InvalidPredicateError: Invalid predicate scope: destroy_all

Article.search({ system: "rm -rf /" })
# => InvalidPredicateError: Invalid predicate scope: system
```

## Best Practices

### 1. Always Use Authorization

```ruby
# ✅ GOOD - Using Pundit
class ArticlesController < ApplicationController
  def index
    search_params = permitted_search_params
    @articles = policy_scope(Article).search(search_params)
  end

  private

  def permitted_search_params
    params.require(:search).permit(:title_eq, :status_eq, :view_count_gt)
  end
end

# ✅ GOOD - Using CanCanCan
class ArticlesController < ApplicationController
  load_and_authorize_resource

  def index
    @articles = @articles.search(permitted_search_params)
  end
end

# ✅ GOOD - Custom authorization
class ArticlesController < ApplicationController
  def index
    base_scope = current_user.admin? ? Article.all : Article.published
    @articles = base_scope.search(permitted_search_params)
  end
end
```

### 2. Validate Input Values

```ruby
# ❌ BAD - Trusting user input
def index
  @articles = Article.search({ status_eq: params[:status] })
end

# ✅ GOOD - Validating against whitelist
def index
  allowed_statuses = %w[draft published archived]
  status = params[:status] if allowed_statuses.include?(params[:status])

  @articles = Article.search({ status_eq: status })
end
```

### 3. Use Security Declarations

```ruby
class Article < ApplicationRecord
  include BetterModel

  searchable do
    # Ensure users can't bypass author filtering
    security :user_scoped, [:author_id_eq]

    # Ensure status filter is present for public searches
    security :public_safe, [:status_eq]
  end
end

# In controller
def index
  search_params = params.permit(:title_eq, :status_eq)
                       .merge(author_id_eq: current_user.id)

  @articles = Article.search(search_params, security: :user_scoped)
end
```

### 4. Rate Limiting

Consider implementing rate limiting for search endpoints:

```ruby
class ArticlesController < ApplicationController
  # Using rack-attack or similar
  throttle("search/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/articles/search"
  end

  def search
    @articles = Article.search(permitted_search_params)
  end
end
```

### 5. Logging and Monitoring

Log complex queries for security monitoring:

```ruby
class Article < ApplicationRecord
  include BetterModel

  after_initialize do
    # Log suspicious search patterns
    Rails.logger.warn("Complex search detected") if complex_search?
  end
end
```

## Common Pitfalls

### ❌ Pitfall 1: Trusting Security Validation as Authorization

```ruby
# INSECURE: Security validation doesn't check VALUES
Article.search({ status_eq: "admin_secret" }, security: :status_required)
# This passes because status_eq is present, but value isn't validated!
```

**Solution**: Always implement proper authorization.

### ❌ Pitfall 2: Using Raw Parameters

```ruby
# INSECURE: Bypasses strong parameters
@articles = Article.search(params[:search].to_unsafe_h)  # Don't do this!
```

**Solution**: Use `permit` or `permit!` explicitly.

### ❌ Pitfall 3: Exposing Internal Scopes

```ruby
# INSECURE: Allows users to call any scope
@articles = Article.public_send(params[:scope])
```

**Solution**: Use BetterModel's predicate system which validates scope names.

### ❌ Pitfall 4: No Rate Limiting

```ruby
# INSECURE: Allows unlimited complex queries
def search
  Article.search(params[:search])  # No rate limiting!
end
```

**Solution**: Implement rate limiting at the controller or rack middleware level.

## Security Checklist

- [ ] Always use `permit` or `permit!` on ActionController::Parameters
- [ ] Implement authorization (Pundit, CanCanCan, or custom)
- [ ] Validate input values against whitelists
- [ ] Use security declarations for critical filters
- [ ] Configure appropriate DoS limits
- [ ] Implement rate limiting on search endpoints
- [ ] Log and monitor suspicious search patterns
- [ ] Test with malicious inputs (see test/better_model/security_test.rb)
- [ ] Never trust security validation as authorization
- [ ] Review search endpoints in penetration tests

## Known Limitations

1. **Not an authorization system**: BetterModel provides query building, not access control
2. **Performance**: Very complex queries can still impact performance even within limits
3. **Database-specific**: Some features (arrays, JSONB) are PostgreSQL-only
4. **Predicate values**: Security validation doesn't validate predicate values

## Testing Security

Run the security test suite:

```bash
bundle exec ruby -Itest test/better_model/security_test.rb
```

Test with malicious inputs:

```ruby
# SQL injection attempts
Article.title_cont("'; DROP TABLE articles;--")

# DoS attempts
Article.search({ or: 1000.times.map { { title_eq: "x" } } })

# Authorization bypass attempts
Article.search({ admin_eq: true }, security: :public_safe)
```

## Updates and Patching

- **Current Version**: 0.1.0
- **Security Updates**: Check GitHub releases for security patches
- **Supported Versions**: Only the latest version receives security updates

## Resources

- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [Pundit Gem](https://github.com/varvet/pundit) (recommended authorization)
- [CanCanCan Gem](https://github.com/CanCanCommunity/cancancan) (alternative authorization)

## License

This security policy is part of the BetterModel gem and follows the same license (MIT).
