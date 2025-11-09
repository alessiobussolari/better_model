# Repositable Examples

This guide provides practical examples for implementing the Repository Pattern with BetterModel's Repositable module.

## Table of Contents

- [Basic Setup](#basic-setup)
- [Example 1: Simple CRUD Repository](#example-1-simple-crud-repository)
- [Example 2: Repository with Predicates](#example-2-repository-with-predicates)
- [Example 3: Repository with Pagination](#example-3-repository-with-pagination)
- [Example 4: Repository with Eager Loading](#example-4-repository-with-eager-loading)
- [Example 5: Repository with Custom Business Logic](#example-5-repository-with-custom-business-logic)
- [Example 6: Multi-Model Repository Pattern](#example-6-multi-model-repository-pattern)
- [Example 7: Repository in Controllers](#example-7-repository-in-controllers)
- [Example 8: Repository in Service Objects](#example-8-repository-in-service-objects)
- [Example 9: Repository Testing Patterns](#example-9-repository-testing-patterns)
- [Example 10: Repository with Transactions](#example-10-repository-with-transactions)
- [Tips & Best Practices](#tips--best-practices)
- [Related Documentation](#related-documentation)

## Basic Setup

### Generate Repository

```bash
rails g better_model:repository Article
```

This creates:
- `app/repositories/application_repository.rb`
- `app/repositories/article_repository.rb`

### Minimal Repository

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article
end
```

That's it! You now have all CRUD operations and the `search()` method available.

## Example 1: Simple CRUD Repository

A basic repository providing standard CRUD operations.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Custom finder methods
  def find_by_slug(slug)
    find_by(slug: slug)
  end

  def find_or_create_by_title(title)
    find_by(title: title) || create(title: title, status: "draft")
  end
end
```

**Usage:**

```ruby
repo = ArticleRepository.new

# Find
article = repo.find(1)

# Find by attribute
article = repo.find_by(title: "Ruby Guide")

# Create
article = repo.create(title: "New Article", status: "draft")

# Update
repo.update(article.id, title: "Updated Title")

# Delete
repo.delete(article.id)

# Custom finders
article = repo.find_by_slug("ruby-guide")
article = repo.find_or_create_by_title("Ruby Basics")
```

**Output Explanation**: The repository provides a clean interface for all standard CRUD operations, abstracting away direct ActiveRecord calls.

## Example 2: Repository with Predicates

Using BetterModel predicates for flexible querying.

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  include BetterModel

  predicates :title, :status, :view_count, :published_at, :category
end

# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  def by_category(category)
    search({ category_eq: category })
  end

  def by_author(author_id)
    search({ author_id_eq: author_id })
  end

  def popular(min_views: 100)
    search({ view_count_gteq: min_views })
  end

  def recent(days: 7)
    search({ published_at_gteq: days.days.ago })
  end

  def search_by_title(query)
    search({ title_i_cont: query })
  end

  def published_in_category(category)
    search({
      status_eq: "published",
      category_eq: category
    })
  end
end
```

**Usage:**

```ruby
repo = ArticleRepository.new

# Simple queries
published = repo.published
ruby_articles = repo.by_category("Ruby")
my_articles = repo.by_author(current_user.id)

# Parameterized queries
popular = repo.popular(min_views: 500)
this_week = repo.recent(days: 7)

# Text search
rails_articles = repo.search_by_title("Rails")

# Composite queries
published_ruby = repo.published_in_category("Ruby")
```

**Output Explanation**: Predicates provide type-safe querying without writing raw SQL. Each method encapsulates business logic with a clear, domain-specific API.

## Example 3: Repository with Pagination

Implementing pagination strategies.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  DEFAULT_PER_PAGE = 25

  # Default pagination
  def paginated(page: 1, per_page: DEFAULT_PER_PAGE)
    search({}, page: page, per_page: per_page)
  end

  # Category-specific pagination
  def by_category_paginated(category, page: 1)
    search(
      { category_eq: category, status_eq: "published" },
      page: page,
      per_page: DEFAULT_PER_PAGE
    )
  end

  # Search with pagination
  def search_paginated(query, page: 1, per_page: DEFAULT_PER_PAGE)
    search(
      { title_i_cont: query },
      page: page,
      per_page: per_page
    )
  end

  # All results (no pagination)
  def all_published
    search({ status_eq: "published" }, limit: nil)
  end

  # Limited results
  def top_articles(limit: 10)
    search(
      { status_eq: "published" },
      limit: limit,
      order_scope: { field: :view_count, direction: :desc }
    )
  end
end
```

**Usage:**

```ruby
repo = ArticleRepository.new

# Paginated results
page1 = repo.paginated(page: 1, per_page: 25)
page2 = repo.paginated(page: 2, per_page: 25)

# Category pagination
ruby_page1 = repo.by_category_paginated("Ruby", page: 1)

# Search pagination
results = repo.search_paginated("Rails", page: 2, per_page: 50)

# All results (no pagination)
all_articles = repo.all_published

# Limited results
top_10 = repo.top_articles(limit: 10)
```

**Output Explanation**: Different pagination strategies for different use cases. Use `limit: nil` for exports, specific limits for "top N" queries, and default pagination for listings.

## Example 4: Repository with Eager Loading

Preventing N+1 queries with proper eager loading.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Basic eager loading
  def with_author
    search({}, includes: [:author])
  end

  # Multiple associations
  def with_full_data
    search({}, includes: [:author, :comments, :tags])
  end

  # Nested associations
  def with_nested_data
    search({}, includes: { comments: :author, author: :profile })
  end

  # Conditional eager loading
  def published_with_details(include_comments: false)
    includes_list = [:author]
    includes_list << :comments if include_comments

    search({ status_eq: "published" }, includes: includes_list)
  end

  # Joins for filtering
  def by_author_name(name)
    search(
      {},
      joins: [:author],
      order: "authors.name ASC"
    ).where("authors.name LIKE ?", "%#{name}%")
  end

  # Joins + Includes
  def published_with_author_details
    search(
      { status_eq: "published" },
      joins: [:author],
      includes: [:author],
      order: "authors.name ASC"
    )
  end
end
```

**Usage:**

```ruby
repo = ArticleRepository.new

# Basic eager loading (prevents N+1 on author)
articles = repo.with_author
articles.each { |a| puts a.author.name } # No additional queries

# Multiple associations
articles = repo.with_full_data
articles.each do |article|
  puts article.author.name      # No query
  puts article.comments.count   # No query
  puts article.tags.map(&:name) # No query
end

# Nested associations
articles = repo.with_nested_data
articles.each do |article|
  article.comments.each do |comment|
    puts comment.author.name # No query
  end
end

# Conditional eager loading
articles = repo.published_with_details(include_comments: true)
```

**Output Explanation**: Proper eager loading is crucial for performance. The repository encapsulates the complexity of includes, joins, and nested associations.

## Example 5: Repository with Custom Business Logic

Encapsulating complex business rules.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Business rule: Trending = published last 7 days + high views
  def trending(days: 7, min_views: 100)
    search({
      status_eq: "published",
      published_at_gteq: days.days.ago,
      view_count_gteq: min_views
    }, order_scope: { field: :view_count, direction: :desc })
  end

  # Business rule: Featured = published + featured flag + recent
  def featured_recent
    search({
      status_eq: "published",
      featured_eq: true,
      published_at_gteq: 30.days.ago
    }, order_scope: { field: :published_at, direction: :desc })
  end

  # Business rule: Ready to publish = draft + scheduled time passed
  def ready_to_publish
    search({
      status_eq: "draft",
      scheduled_for_lteq: Time.current
    })
  end

  # Business rule: Needs review = draft + created > 24 hours ago
  def needs_review
    search({
      status_eq: "draft",
      created_at_lteq: 24.hours.ago
    })
  end

  # Business rule: Expires soon = published + expires within 48 hours
  def expires_soon(hours: 48)
    search({
      status_eq: "published",
      expires_at_between: [Time.current, hours.hours.from_now]
    })
  end

  # Complex aggregation
  def statistics
    {
      total: count,
      published: Article.where(status: "published").count,
      drafts: Article.where(status: "draft").count,
      archived: Article.where(status: "archived").count,
      avg_views: Article.average(:view_count).to_f.round(2),
      total_views: Article.sum(:view_count)
    }
  end
end
```

**Usage:**

```ruby
repo = ArticleRepository.new

# Get trending articles
trending = repo.trending(days: 7, min_views: 200)

# Get featured recent articles
featured = repo.featured_recent

# Find articles ready to publish
ready = repo.ready_to_publish
ready.each { |article| PublishService.call(article) }

# Find articles needing review
needs_review = repo.needs_review
# Send notifications to editors

# Get articles expiring soon
expiring = repo.expires_soon(hours: 24)
# Send reminders to authors

# Get statistics
stats = repo.statistics
# Display on dashboard
```

**Output Explanation**: Business logic is encapsulated in repository methods with clear, intention-revealing names. This keeps controllers and views clean.

## Example 6: Multi-Model Repository Pattern

Coordinating data from multiple models.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def with_popular_comments
    Article.where(
      id: Comment.where("likes > ?", 10)
                 .select(:article_id)
                 .distinct
    )
  end

  def by_author_with_stats(author_id)
    articles = search({ author_id_eq: author_id })
    {
      articles: articles,
      total_count: articles.count,
      total_views: articles.sum(:view_count),
      avg_views: articles.average(:view_count).to_f
    }
  end
end

# app/repositories/dashboard_repository.rb
class DashboardRepository < ApplicationRepository
  def model_class = Article # Primary model

  def overview
    {
      articles: Article.count,
      published: Article.where(status: "published").count,
      comments: Comment.count,
      users: User.count,
      recent_articles: Article.order(created_at: :desc).limit(5),
      popular_articles: Article.order(view_count: :desc).limit(5),
      recent_comments: Comment.includes(:article, :author).order(created_at: :desc).limit(10)
    }
  end

  def author_leaderboard(limit: 10)
    Author.joins(:articles)
          .select("authors.*, COUNT(articles.id) as articles_count, SUM(articles.view_count) as total_views")
          .group("authors.id")
          .order("total_views DESC")
          .limit(limit)
  end
end
```

**Usage:**

```ruby
# Article repository with cross-model queries
article_repo = ArticleRepository.new
popular_comment_articles = article_repo.with_popular_comments
author_stats = article_repo.by_author_with_stats(current_user.id)

# Dashboard repository aggregating multiple models
dashboard_repo = DashboardRepository.new
overview = dashboard_repo.overview
leaderboard = dashboard_repo.author_leaderboard(limit: 20)
```

**Output Explanation**: Repositories can coordinate data from multiple models while providing a clean API to consumers.

## Example 7: Repository in Controllers

Integrating repositories with Rails controllers.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def published
    search({ status_eq: "published" })
  end

  def by_category(category)
    search({ category_eq: category, status_eq: "published" })
  end

  def search_articles(query)
    search({
      or: [
        { title_i_cont: query },
        { content_i_cont: query }
      ],
      status_eq: "published"
    })
  end
end

# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  before_action :set_repository

  def index
    @articles = @repo.published.page(params[:page])
  end

  def show
    @article = @repo.find(params[:id])
  end

  def create
    @article = @repo.create(article_params)

    if @article.persisted?
      redirect_to @article, notice: "Article created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @article = @repo.update(params[:id], article_params)
    redirect_to @article, notice: "Article updated."
  rescue ActiveRecord::RecordInvalid => e
    @article = e.record
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @repo.delete(params[:id])
    redirect_to articles_url, notice: "Article deleted."
  end

  def category
    @articles = @repo.by_category(params[:category]).page(params[:page])
    render :index
  end

  def search
    @articles = @repo.search_articles(params[:q]).page(params[:page])
    render :index
  end

  private

  def set_repository
    @repo = ArticleRepository.new
  end

  def article_params
    params.require(:article).permit(:title, :content, :status, :category)
  end
end
```

**Output Explanation**: The repository acts as a service layer between controllers and models, keeping controllers thin and focused on HTTP concerns.

## Example 8: Repository in Service Objects

Using repositories in service objects for complex business logic.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  def drafts
    search({ status_eq: "draft" })
  end

  def scheduled_for_today
    search({
      status_eq: "draft",
      scheduled_for_between: [Time.current.beginning_of_day, Time.current.end_of_day]
    })
  end
end

# app/services/article_publish_service.rb
class ArticlePublishService
  def initialize(repo: ArticleRepository.new)
    @repo = repo
  end

  def publish(article_id)
    article = @repo.find(article_id)

    ActiveRecord::Base.transaction do
      article.update!(
        status: "published",
        published_at: Time.current
      )

      notify_subscribers(article)
      update_search_index(article)
      post_to_social_media(article)
    end

    article
  end

  def publish_scheduled
    @repo.scheduled_for_today.find_each do |article|
      publish(article.id)
    end
  end

  private

  def notify_subscribers(article)
    # Notification logic
  end

  def update_search_index(article)
    # Search index logic
  end

  def post_to_social_media(article)
    # Social media logic
  end
end

# app/services/article_search_service.rb
class ArticleSearchService
  def initialize(repo: ArticleRepository.new)
    @repo = repo
  end

  def search(query, filters: {}, page: 1, per_page: 25)
    base_filters = {
      or: [
        { title_i_cont: query },
        { content_i_cont: query }
      ]
    }

    # Merge additional filters
    filters.each do |key, value|
      base_filters["#{key}_eq".to_sym] = value if value.present?
    end

    @repo.search(
      base_filters,
      page: page,
      per_page: per_page,
      order_scope: { field: :published_at, direction: :desc }
    )
  end
end
```

**Usage:**

```ruby
# Publish service
publish_service = ArticlePublishService.new
publish_service.publish(article.id)
publish_service.publish_scheduled

# Search service
search_service = ArticleSearchService.new
results = search_service.search(
  "Ruby",
  filters: { category: "Programming", status: "published" },
  page: 1,
  per_page: 25
)
```

**Output Explanation**: Services use repositories for data access, keeping business logic separate from data access logic. This makes services testable with mock repositories.

## Example 9: Repository Testing Patterns

Testing repositories with RSpec and Minitest.

```ruby
# spec/repositories/article_repository_spec.rb (RSpec)
RSpec.describe ArticleRepository do
  let(:repo) { described_class.new }

  describe "#published" do
    it "returns only published articles" do
      published = create(:article, status: "published")
      draft = create(:article, status: "draft")

      results = repo.published

      expect(results).to include(published)
      expect(results).not_to include(draft)
    end
  end

  describe "#trending" do
    it "returns articles with high views from last 7 days" do
      trending = create(:article,
        status: "published",
        published_at: 3.days.ago,
        view_count: 200
      )

      old = create(:article,
        status: "published",
        published_at: 10.days.ago,
        view_count: 300
      )

      results = repo.trending(days: 7, min_views: 100)

      expect(results).to include(trending)
      expect(results).not_to include(old)
    end
  end

  describe "#search" do
    it "filters by predicates" do
      ruby = create(:article, title: "Ruby Guide", status: "published")
      rails = create(:article, title: "Rails Tutorial", status: "draft")

      results = repo.search({ title_cont: "Ruby", status_eq: "published" })

      expect(results).to eq([ruby])
    end

    it "paginates results" do
      create_list(:article, 30, status: "published")

      page1 = repo.search({}, page: 1, per_page: 20)
      page2 = repo.search({}, page: 2, per_page: 20)

      expect(page1.count).to eq(20)
      expect(page2.count).to eq(10)
    end
  end
end

# test/repositories/article_repository_test.rb (Minitest)
class ArticleRepositoryTest < ActiveSupport::TestCase
  setup do
    @repo = ArticleRepository.new
  end

  test "published returns only published articles" do
    published = Article.create!(title: "Test", status: "published")
    draft = Article.create!(title: "Draft", status: "draft")

    results = @repo.published

    assert_includes results, published
    refute_includes results, draft
  end

  test "search filters by predicates" do
    ruby = Article.create!(title: "Ruby Guide", status: "published")
    rails = Article.create!(title: "Rails Tutorial", status: "draft")

    results = @repo.search({ title_cont: "Ruby", status_eq: "published" })

    assert_equal [ruby], results.to_a
  end
end
```

**Output Explanation**: Repositories are easy to test in isolation. Mock the model or use test database fixtures. Test both simple queries and complex business logic.

## Example 10: Repository with Transactions

Handling transactions and bulk operations.

```ruby
# app/repositories/article_repository.rb
class ArticleRepository < ApplicationRepository
  def model_class = Article

  # Publish multiple articles atomically
  def publish_batch(article_ids)
    Article.transaction do
      article_ids.each do |id|
        article = find(id)
        article.update!(
          status: "published",
          published_at: Time.current
        )
      end
    end
  end

  # Create article with tags atomically
  def create_with_tags(attributes, tag_names)
    Article.transaction do
      article = create!(attributes)

      tag_names.each do |name|
        article.tags.create!(name: name)
      end

      article
    end
  end

  # Bulk update with rollback on error
  def bulk_update(ids, attributes)
    Article.transaction do
      ids.each do |id|
        update(id, attributes)
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Bulk update failed: #{e.message}"
    raise # Re-raise to rollback transaction
  end

  # Archive with cleanup
  def archive_with_cleanup(article_id)
    Article.transaction do
      article = find(article_id)
      article.update!(status: "archived", archived_at: Time.current)

      # Cleanup related records
      article.comments.update_all(archived: true)
      article.notifications.destroy_all
    end
  end

  # Soft delete with history
  def soft_delete_with_history(article_id, deleted_by:, reason:)
    Article.transaction do
      article = find(article_id)

      # Create deletion history
      DeletionHistory.create!(
        deletable: article,
        deleted_by: deleted_by,
        reason: reason,
        metadata: article.attributes
      )

      # Soft delete
      article.update!(
        status: "deleted",
        deleted_at: Time.current,
        deleted_by_id: deleted_by.id
      )
    end
  end
end
```

**Usage:**

```ruby
repo = ArticleRepository.new

# Publish batch
repo.publish_batch([1, 2, 3, 4, 5])

# Create with tags
article = repo.create_with_tags(
  { title: "Ruby Guide", content: "..." },
  ["ruby", "programming", "tutorial"]
)

# Bulk update
repo.bulk_update([1, 2, 3], status: "reviewed")

# Archive with cleanup
repo.archive_with_cleanup(article.id)

# Soft delete with history
repo.soft_delete_with_history(
  article.id,
  deleted_by: current_user,
  reason: "Outdated content"
)
```

**Output Explanation**: Transactions ensure data consistency. If any operation fails, all changes are rolled back. Use transactions for multi-step operations that must succeed or fail together.

## Tips & Best Practices

### 1. Keep Repositories Focused

Each repository should focus on a single model or bounded context:

```ruby
# Good: Article-focused repository
class ArticleRepository < ApplicationRepository
  def model_class = Article
  # Article-specific methods
end

# Bad: God repository doing everything
class DataRepository < ApplicationRepository
  def articles; end
  def users; end
  def comments; end
end
```

### 2. Use Meaningful Method Names

Method names should describe business intent, not implementation:

```ruby
# Good: Business intent is clear
def published_recent
  search({ status_eq: "published", published_at_gteq: 7.days.ago })
end

# Bad: Implementation details exposed
def where_status_published_and_date_greater_than_seven_days
  search({ status_eq: "published", published_at_gteq: 7.days.ago })
end
```

### 3. Leverage BetterModel Features

Don't reinvent the wheel - use BetterModel's predicates, sorting, and searching:

```ruby
# Good: Using BetterModel predicates
def by_title(title)
  search({ title_cont: title })
end

# Bad: Manual SQL
def by_title(title)
  Article.where("title LIKE ?", "%#{title}%")
end
```

### 4. Don't Over-Abstract

Not every model needs a repository. Use repositories when you have complex queries or business logic:

```ruby
# Good: Tag is simple, use directly
Tag.all
Tag.find_by(name: "ruby")

# Good: Article has complex logic, use repository
ArticleRepository.new.trending(days: 7)
```

### 5. Test Repositories Independently

Write focused tests for repository logic:

```ruby
RSpec.describe ArticleRepository do
  it "returns trending articles" do
    trending = create(:article, view_count: 200, published_at: 2.days.ago)
    old = create(:article, view_count: 300, published_at: 10.days.ago)

    repo = described_class.new
    results = repo.trending

    expect(results).to include(trending)
    expect(results).not_to include(old)
  end
end
```

### 6. Use Dependency Injection for Testing

Make repositories easy to mock in services:

```ruby
class ArticlePublishService
  def initialize(repo: ArticleRepository.new)
    @repo = repo
  end

  def publish(id)
    @repo.find(id).update!(status: "published")
  end
end

# Test with mock repository
mock_repo = double("ArticleRepository")
service = ArticlePublishService.new(repo: mock_repo)
```

### 7. Document Complex Queries

Add comments explaining business rules:

```ruby
def trending
  # Business rule: Trending = published last 7 days + 100+ views
  # Ordered by view count descending
  search({
    status_eq: "published",
    published_at_gteq: 7.days.ago,
    view_count_gteq: 100
  }, order_scope: { field: :view_count, direction: :desc })
end
```

## Related Documentation

- [Repositable Main Documentation](../repositable.md) - Complete API reference
- [Searchable Documentation](../searchable.md) - Unified search interface
- [Predicable Documentation](../predicable.md) - Filter predicates
- [Sortable Documentation](../sortable.md) - Sorting scopes
- [Repository Pattern Guide](../../context7/11_repositable.md) - Complete guide for AI assistants
