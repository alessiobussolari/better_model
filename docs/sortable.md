## Sortable - Type-Aware Ordering System

Define ordering capabilities on your models with automatic scope generation based on column types. Use semantic, expressive method names like `sort_title_asc`, `sort_view_count_desc_nulls_last`, and `sort_published_at_newest`.

**Key Benefits:**
- **Type-aware:** Different scopes for strings, numbers, and dates
- **Semantic naming:** Use `sort_field_asc/desc` pattern for clarity
- **Case-insensitive:** Built-in `_i` suffix for case-insensitive string ordering
- **NULL handling:** Proper NULL value handling with `_nulls_last/_nulls_first`
- **Date shortcuts:** Use `_newest/_oldest` instead of `_desc/_asc` for dates
- **Chainable:** Combine multiple orderings easily
- **Thread-safe:** Immutable registries with frozen Sets

### Basic Sortable Usage

Simply call `sort` with the fields you want to make sortable:

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Auto-generate sorting scopes based on column types
  sort :title, :view_count, :published_at
end
```

### Generated Scopes

**For String Fields (:title):**
```ruby
Article.sort_title_asc              # ORDER BY title ASC
Article.sort_title_desc             # ORDER BY title DESC
Article.sort_title_asc_i            # ORDER BY LOWER(title) ASC (case-insensitive)
Article.sort_title_desc_i           # ORDER BY LOWER(title) DESC
```

**For Numeric Fields (:view_count):**
```ruby
Article.sort_view_count_asc                     # ORDER BY view_count ASC
Article.sort_view_count_desc                    # ORDER BY view_count DESC
Article.sort_view_count_asc_nulls_last          # ASC with NULL values at end
Article.sort_view_count_desc_nulls_last         # DESC with NULL values at end
Article.sort_view_count_asc_nulls_first         # ASC with NULL values at start
Article.sort_view_count_desc_nulls_first        # DESC with NULL values at start
```

**For Date/DateTime Fields (:published_at):**
```ruby
Article.sort_published_at_asc       # ORDER BY published_at ASC
Article.sort_published_at_desc      # ORDER BY published_at DESC
Article.sort_published_at_newest    # Most recent first (DESC) - semantic alias
Article.sort_published_at_oldest    # Oldest first (ASC) - semantic alias
```

### Using Sort Scopes

```ruby
# Simple usage
@articles = Article.sort_title_asc
@popular = Article.where(status: 'published').sort_view_count_desc

# Chain multiple orderings
@articles = Article.sort_published_at_newest
                   .sort_view_count_desc
                   .sort_title_asc_i

# Case-insensitive alphabetical
@articles = Article.sort_title_asc_i

# Handle NULL values explicitly
@products = Product.sort_price_asc_nulls_last  # Products without price at end
```

### Chaining Multiple Orderings

Order by multiple fields with clear precedence:

```ruby
# Primary: newest first, Secondary: highest views, Tertiary: alphabetical
Article.where(status: 'published')
       .sort_published_at_newest
       .sort_view_count_desc
       .sort_title_asc_i
```

### Class Methods

```ruby
# Check if a field is sortable
Article.sortable_field?(:title)      # => true
Article.sortable_field?(:nonexistent) # => false

# Check if a scope exists
Article.sortable_scope?(:sort_title_asc)  # => true

# Get all sortable fields
Article.sortable_fields
# => #<Set: {:title, :view_count, :published_at, :created_at}>

# Get all generated sort scopes
Article.sortable_scopes
# => #<Set: {:sort_title_asc, :sort_title_desc, :sort_title_asc_i, ...}>
```

### Instance Methods

```ruby
article = Article.first

# Get list of sortable attributes (excludes sensitive fields)
article.sortable_attributes
# => ["id", "title", "content", "status", "view_count", "published_at", ...]
# (automatically excludes fields starting with "password" or "encrypted_")
```

### Real-World Examples

**Blog Posts:**
```ruby
class Post < ApplicationRecord
  include BetterModel

  sort :title, :view_count, :published_at, :created_at
end

# Most popular published posts
@posts = Post.where(status: 'published')
             .sort_view_count_desc
             .limit(10)

# Recent posts, alphabetically
@posts = Post.sort_created_at_newest
             .sort_title_asc_i

# Posts with most views, NULL views at end
@posts = Post.sort_view_count_desc_nulls_last
```

**E-commerce Products:**
```ruby
class Product < ApplicationRecord
  include BetterModel

  sort :name, :price, :stock, :created_at
end

# Cheapest in-stock products first
@products = Product.where('stock > 0')
                   .sort_price_asc

# Newest products, expensive first
@products = Product.sort_created_at_newest
                   .sort_price_desc

# Products with stock, out-of-stock at end
@products = Product.sort_stock_desc_nulls_last
                   .sort_name_asc_i
```

**Users with Activity:**
```ruby
class User < ApplicationRecord
  include BetterModel

  sort :name, :email, :created_at, :last_sign_in_at
end

# Recently active users
@users = User.sort_last_sign_in_at_newest
             .limit(50)

# Alphabetical, case-insensitive
@users = User.sort_name_asc_i

# Active users first, inactive at end
@users = User.sort_last_sign_in_at_desc_nulls_last
```

### Complex Sort

For multi-field ordering and advanced sorting logic, use `register_complex_sort`:

#### API Reference: register_complex_sort

**Method Signature:**
```ruby
register_complex_sort(name, &block)
```

**Parameters:**
- `name` (Symbol): The name of the sort (will be registered as `sort_#{name}`)
- `block` (Proc): Sorting logic that returns an ActiveRecord::Relation with ORDER BY

**Returns:** Registers a new scope with `sort_` prefix and adds it to `complex_sorts_registry`

**Thread Safety:** Registry is a frozen Hash, sorts defined at class load time

#### Basic Examples

**Multi-field sorting:**
```ruby
class Article < ApplicationRecord
  include BetterModel

  sort :published_at, :view_count, :title

  register_complex_sort :by_popularity do
    order(published_at: :desc, view_count: :desc, title: :asc)
  end
end

# Usage
Article.sort_by_popularity
# Equivalent to: ORDER BY published_at DESC, view_count DESC, title ASC
```

**Sorting with parameters:**
```ruby
register_complex_sort :by_relevance do |keyword|
  order(
    Arel.sql(
      "CASE WHEN title ILIKE '%#{sanitize_sql_like(keyword)}%' THEN 0 " \
      "WHEN content ILIKE '%#{sanitize_sql_like(keyword)}%' THEN 1 " \
      "ELSE 2 END ASC, " \
      "published_at DESC"
    )
  )
end

# Usage
Article.sort_by_relevance('rails')
# Title matches first, then content matches, then by date
```

**Conditional sorting with CASE WHEN:**
```ruby
register_complex_sort :by_priority do
  order(
    Arel.sql("CASE WHEN priority IS NULL THEN 1 ELSE 0 END"),
    priority: :desc,
    created_at: :desc
  )
end

# Usage
Article.sort_by_priority
# Non-NULL priorities first (highest first), then by creation date
```

**Combining filtering and sorting:**
```ruby
register_complex_sort :featured_and_recent do
  where(featured: true)
    .order(published_at: :desc, view_count: :desc)
end

# Usage
Article.sort_featured_and_recent
Article.where(status: 'published').sort_featured_and_recent
```

#### Integration with Predicables

Complex sorts work seamlessly with predicates:

```ruby
class Article < ApplicationRecord
  include BetterModel

  predicates :status, :view_count, :published_at
  sort :published_at

  register_complex_sort :trending do
    where("view_count >= ?", 500)
      .order(view_count: :desc, published_at: :desc)
  end
end

# Chainable usage
Article
  .status_eq("published")
  .published_at_within(30.days)
  .sort_trending
  .limit(5)
```

#### Class Methods

```ruby
# Check if a complex sort is registered
Article.complex_sort?(:by_popularity)  # => true

# Get all registered complex sorts
Article.complex_sorts_registry
# => {:by_popularity => #<Proc>, :by_relevance => #<Proc>}
```

#### Use Cases

- **Multi-field precedence:** Order by multiple fields with clear priority
- **Relevance ranking:** Sort search results by relevance score
- **Conditional ordering:** Use CASE WHEN for custom sort logic
- **Performance-critical queries:** Pre-structure complex sorting for reusability
- **Engagement metrics:** Sort by calculated scores from related records

### Database Compatibility

Sortable works across all major databases with automatic adaptation:

| Feature | PostgreSQL | MySQL/MariaDB | SQLite | Implementation |
|---------|------------|---------------|--------|----------------|
| **NULLS LAST/FIRST** | ✅ Native | ⚠️ CASE emulation | ✅ Native (3.30+) | Automatic fallback |
| **LOWER() function** | ✅ Native | ✅ Native | ✅ Native | Direct SQL |
| **Case-insensitive** | ✅ | ✅ | ✅ | LOWER() based |

The concern automatically detects your database adapter and uses native features when available, falling back to compatible SQL for older databases.

### Best Practices

1. **Use semantic names** - `sort_published_at_newest` is clearer than `sort_published_at_desc`
2. **Leverage case-insensitive** - Use `_asc_i/_desc_i` for user-facing string fields
3. **Handle NULLs explicitly** - Use `_nulls_last/_nulls_first` for fields with potential NULL values
4. **Chain logically** - Primary sort first, secondary sorts follow
5. **Define selectively** - Only make frequently-sorted fields sortable

### Thread Safety

Sortable registries are thread-safe:
- `sortable_fields` is a frozen Set
- `sortable_scopes` is a frozen Set
- Scopes are defined once at class load time
- No mutable shared state

### Performance Notes

- **Zero runtime overhead** - Scopes are compiled at class load time
- **Efficient SQL** - Uses Arel for optimal query generation
- **Registry lookups** - O(1) with Set data structure
- **Memory footprint** - ~100 bytes per model for registries

