# Error Handling - Practical Examples

Real-world examples of error handling patterns with BetterModel's error system.

## Table of Contents

- [Controller Error Handling](#controller-error-handling)
  - [Basic Error Rescue](#basic-error-rescue)
  - [Multi-Error Handler](#multi-error-handler)
  - [JSON:API Error Responses](#jsonapi-error-responses)
  - [GraphQL Error Handling](#graphql-error-handling)
- [Service Object Patterns](#service-object-patterns)
  - [Result Object Pattern](#result-object-pattern)
  - [Railway-Oriented Programming](#railway-oriented-programming)
  - [Command Pattern with Errors](#command-pattern-with-errors)
- [API Error Responses](#api-error-responses)
  - [RESTful API Errors](#restful-api-errors)
  - [Problem Details (RFC 7807)](#problem-details-rfc-7807)
  - [Custom Error Format](#custom-error-format)
- [Background Job Handling](#background-job-handling)
  - [Retry Strategies](#retry-strategies)
  - [Dead Letter Queue](#dead-letter-queue)
  - [Error Notifications](#error-notifications)
- [Sentry Integration](#sentry-integration)
  - [Complete Setup](#complete-setup)
  - [Custom Error Grouping](#custom-error-grouping)
  - [Performance Monitoring](#performance-monitoring)
- [Testing Strategies](#testing-strategies)
  - [RSpec Examples](#rspec-examples)
  - [Minitest Examples](#minitest-examples)
  - [Request Specs](#request-specs)

---

## Controller Error Handling

### Basic Error Rescue

Simple error handling in a single controller.

```ruby
class ArticlesController < ApplicationController
  def publish
    article = Article.find(params[:id])
    article.publish!(by: current_user)

    render json: {
      status: "published",
      article: article_json(article)
    }, status: :ok
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    render json: {
      error: "Cannot publish article",
      message: "Article is in #{e.from_state} state and cannot be published",
      current_state: e.from_state
    }, status: :unprocessable_entity
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    render json: {
      error: "Requirements not met",
      message: user_friendly_check_message(e),
      requirements: article_requirements(article)
    }, status: :unprocessable_entity
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    render json: {
      error: "Validation failed",
      errors: e.errors_object.full_messages,
      error_details: e.errors_object.details
    }, status: :unprocessable_entity
  end

  private

  def user_friendly_check_message(error)
    case error.check_description
    when /content/
      "Article must have content before publishing"
    when /images/
      "Article must have at least one featured image"
    when /category/
      "Article must have a category assigned"
    else
      "Article does not meet publishing requirements"
    end
  end

  def article_requirements(article)
    {
      has_content: article.content.present?,
      has_images: article.images.any?,
      has_category: article.category.present?
    }
  end

  def article_json(article)
    {
      id: article.id,
      title: article.title,
      state: article.state,
      published_at: article.published_at
    }
  end
end
```

---

### Multi-Error Handler

Global error handler in `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  # Order matters: rescue most specific errors first
  rescue_from BetterModel::Errors::Searchable::InvalidSecurityError, with: :handle_security_error
  rescue_from BetterModel::Errors::Searchable::InvalidPredicateError, with: :handle_invalid_predicate
  rescue_from BetterModel::Errors::Searchable::InvalidOrderError, with: :handle_invalid_order
  rescue_from BetterModel::Errors::Searchable::InvalidPaginationError, with: :handle_invalid_pagination
  rescue_from BetterModel::Errors::Stateable::InvalidTransitionError, with: :handle_invalid_transition
  rescue_from BetterModel::Errors::Stateable::CheckFailedError, with: :handle_check_failed
  rescue_from BetterModel::Errors::Stateable::ValidationFailedError, with: :handle_validation_failed
  rescue_from BetterModel::Errors::Archivable::AlreadyArchivedError, with: :handle_already_archived
  rescue_from BetterModel::Errors::Archivable::NotArchivedError, with: :handle_not_archived
  rescue_from ArgumentError, with: :handle_configuration_error
  rescue_from BetterModel::Errors::BetterModelError, with: :handle_generic_better_model_error

  private

  # Security violations
  def handle_security_error(error)
    log_security_violation(error)
    capture_in_sentry(error, level: :error, fingerprint: ["security", error.policy_name])

    render json: {
      error: "Access denied",
      code: "SECURITY_VIOLATION"
    }, status: :forbidden
  end

  # Search errors
  def handle_invalid_predicate(error)
    capture_in_sentry(error, level: :warning)

    render json: {
      error: "Invalid search parameter",
      invalid_parameter: error.predicate_scope,
      available_parameters: error.available_predicates,
      hint: "Use one of the available search parameters"
    }, status: :bad_request
  end

  def handle_invalid_order(error)
    capture_in_sentry(error, level: :warning)

    render json: {
      error: "Invalid sort parameter",
      invalid_sort: error.order_scope,
      available_sorts: error.available_sorts
    }, status: :bad_request
  end

  def handle_invalid_pagination(error)
    capture_in_sentry(error, level: :info)

    render json: {
      error: "Invalid pagination parameter",
      parameter: error.parameter_name,
      value: error.value,
      valid_range: error.valid_range
    }, status: :bad_request
  end

  # State machine errors
  def handle_invalid_transition(error)
    capture_in_sentry(error, level: :info)

    render json: {
      error: "Invalid action",
      message: "This action cannot be performed in the current state",
      current_state: error.from_state,
      attempted_action: error.event
    }, status: :unprocessable_entity
  end

  def handle_check_failed(error)
    capture_in_sentry(error, level: :info)

    render json: {
      error: "Requirements not met",
      message: error.check_description || "Operation requirements not met",
      current_state: error.current_state
    }, status: :unprocessable_entity
  end

  def handle_validation_failed(error)
    capture_in_sentry(error, level: :info)

    render json: {
      error: "Validation failed",
      errors: error.errors_object.full_messages,
      error_details: error.errors_object.details
    }, status: :unprocessable_entity
  end

  # Archive errors
  def handle_already_archived(error)
    # Idempotent operation - return success
    Rails.logger.info("Record already archived: #{error.archived_at}")

    render json: {
      status: "archived",
      archived_at: error.archived_at
    }, status: :ok
  end

  def handle_not_archived(error)
    render json: {
      error: "Record is not archived",
      message: "This operation requires an archived record"
    }, status: :bad_request
  end

  # Configuration errors
  def handle_configuration_error(error)
    # Configuration errors should be caught in development
    capture_in_sentry(error, level: :error)
    Rails.logger.error("Configuration error: #{error.message}")

    if Rails.env.production?
      render json: { error: "Service temporarily unavailable" }, status: :service_unavailable
    else
      render json: {
        error: "Configuration error",
        message: error.message,
        hint: "Check your model configuration"
      }, status: :internal_server_error
    end
  end

  # Catch-all for other BetterModel errors
  def handle_generic_better_model_error(error)
    capture_in_sentry(error, level: :error)

    render json: {
      error: "An error occurred",
      message: error.message,
      category: error.tags[:error_category]
    }, status: :internal_server_error
  end

  # Helper methods
  def log_security_violation(error)
    Rails.logger.error("Security violation detected")
    Rails.logger.error("  Policy: #{error.policy_name}")
    Rails.logger.error("  User: #{current_user&.id}")
    Rails.logger.error("  IP: #{request.remote_ip}")
    Rails.logger.error("  Path: #{request.path}")
  end

  def capture_in_sentry(error, level: :error, fingerprint: nil)
    Sentry.capture_exception(error) do |scope|
      scope.set_level(level)
      scope.set_context("error_details", error.context)
      scope.set_tags(error.tags.merge(
        controller: controller_name,
        action: action_name,
        user_id: current_user&.id
      ))
      scope.set_extras(error.extra)
      scope.set_fingerprint(fingerprint) if fingerprint

      # Add request context
      scope.set_context("request", {
        url: request.url,
        method: request.method,
        params: safe_params
      })
    end
  end

  def safe_params
    request.params.except(:password, :password_confirmation, :token, :api_key)
  end
end
```

---

### JSON:API Error Responses

Implementing JSON:API compliant error responses:

```ruby
class Api::V1::BaseController < ApplicationController
  rescue_from BetterModel::Errors::BetterModelError, with: :render_jsonapi_error

  private

  def render_jsonapi_error(error)
    render json: {
      errors: [build_jsonapi_error(error)]
    }, status: http_status_for_error(error)
  end

  def build_jsonapi_error(error)
    {
      id: generate_error_id(error),
      links: {
        about: error_documentation_url(error)
      },
      status: http_status_code(error),
      code: error_code(error),
      title: error_title(error),
      detail: error.message,
      source: error_source(error),
      meta: {
        module: error.tags[:module],
        category: error.tags[:error_category],
        context: error.context,
        timestamp: Time.current.iso8601
      }
    }
  end

  def generate_error_id(error)
    # Generate unique error ID for tracking
    Digest::SHA256.hexdigest([
      Time.current.to_i,
      error.class.name,
      current_user&.id,
      rand(1000)
    ].join("-"))[0..15]
  end

  def error_documentation_url(error)
    module_name = error.tags[:module]
    "https://docs.example.com/errors/#{module_name}##{error.tags[:error_category]}"
  end

  def http_status_code(error)
    http_status_for_error(error).to_s
  end

  def http_status_for_error(error)
    case error
    when BetterModel::Errors::Searchable::InvalidPredicateError,
         BetterModel::Errors::Searchable::InvalidOrderError,
         BetterModel::Errors::Searchable::InvalidPaginationError,
         BetterModel::Errors::Archivable::NotArchivedError
      :bad_request
    when BetterModel::Errors::Searchable::InvalidSecurityError
      :forbidden
    when BetterModel::Errors::Stateable::InvalidTransitionError,
         BetterModel::Errors::Stateable::CheckFailedError,
         BetterModel::Errors::Stateable::ValidationFailedError
      :unprocessable_entity
    when ArgumentError
      :bad_request
    else
      :internal_server_error
    end
  end

  def error_code(error)
    [
      error.tags[:module]&.upcase,
      error.tags[:error_category]&.upcase
    ].compact.join("_")
  end

  def error_title(error)
    error.class.name.demodulize.titleize
  end

  def error_source(error)
    source = { pointer: request.path }

    # Add parameter pointer for search errors
    if error.respond_to?(:predicate_scope)
      source[:parameter] = error.predicate_scope
    elsif error.respond_to?(:parameter_name)
      source[:parameter] = error.parameter_name
    end

    source
  end
end
```

---

### GraphQL Error Handling

Handling BetterModel errors in GraphQL:

```ruby
class BetterModelSchema < GraphQL::Schema
  rescue_from(BetterModel::Errors::BetterModelError) do |error, object, args, context, field|
    graphql_error = graphql_error_from_better_model_error(error, context)
    raise GraphQL::ExecutionError, graphql_error
  end

  def self.graphql_error_from_better_model_error(error, context)
    GraphQL::ExecutionError.new(
      error.message,
      extensions: {
        code: error_code(error),
        module: error.tags[:module],
        category: error.tags[:error_category],
        context: error.context,
        extra: error.extra
      }
    ).tap do |graphql_error|
      # Capture in Sentry
      Sentry.capture_exception(error) do |scope|
        scope.set_context("graphql", {
          operation: context[:current_operation]&.name,
          query: context.query.query_string
        })
        scope.set_tags(error.tags.merge(
          user_id: context[:current_user]&.id
        ))
      end
    end
  end

  def self.error_code(error)
    case error
    when BetterModel::Errors::Searchable::InvalidPredicateError
      "INVALID_PREDICATE"
    when BetterModel::Errors::Stateable::InvalidTransitionError
      "INVALID_TRANSITION"
    when BetterModel::Errors::Stateable::CheckFailedError
      "CHECK_FAILED"
    when BetterModel::Errors::Stateable::ValidationFailedError
      "VALIDATION_FAILED"
    else
      "BETTER_MODEL_ERROR"
    end
  end
end

# Example mutation with error handling
class Mutations::PublishArticle < Mutations::BaseMutation
  argument :id, ID, required: true

  field :article, Types::ArticleType, null: true
  field :errors, [Types::UserErrorType], null: false

  def resolve(id:)
    article = Article.find(id)
    article.publish!(by: context[:current_user])

    { article: article, errors: [] }
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    {
      article: nil,
      errors: [{
        message: "Cannot publish article in #{e.from_state} state",
        path: ["publishArticle"],
        code: "INVALID_TRANSITION"
      }]
    }
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    {
      article: nil,
      errors: [{
        message: e.check_description,
        path: ["publishArticle"],
        code: "CHECK_FAILED"
      }]
    }
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    {
      article: nil,
      errors: e.errors_object.full_messages.map { |msg|
        {
          message: msg,
          path: ["publishArticle"],
          code: "VALIDATION_FAILED"
        }
      }
    }
  end
end
```

---

## Service Object Patterns

### Result Object Pattern

Using Result objects for explicit error handling:

```ruby
# app/services/application_service.rb
class ApplicationService
  class Result
    attr_reader :value, :error, :error_details

    def initialize(success:, value: nil, error: nil, error_details: {})
      @success = success
      @value = value
      @error = error
      @error_details = error_details
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  class << self
    def call(*args, **kwargs, &block)
      new(*args, **kwargs).call(&block)
    end
  end

  def success(value = nil)
    Result.new(success: true, value: value)
  end

  def failure(error, details = {})
    Result.new(success: false, error: error, error_details: details)
  end
end

# app/services/article_publish_service.rb
class ArticlePublishService < ApplicationService
  def initialize(article, published_by:, notify: true)
    @article = article
    @published_by = published_by
    @notify = notify
  end

  def call
    validate_permissions!
    validate_article_ready!

    @article.transaction do
      @article.publish!(by: @published_by)
      update_seo_metadata
      schedule_social_media_posts
    end

    send_notifications if @notify

    success(@article)
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    failure(:invalid_state, {
      current_state: e.from_state,
      attempted_event: e.event,
      message: "Article cannot be published from #{e.from_state} state"
    })
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    failure(:requirements_not_met, {
      check: e.check_description,
      check_type: e.check_type,
      message: friendly_check_message(e)
    })
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    failure(:validation_failed, {
      errors: e.errors_object.full_messages,
      error_details: e.errors_object.details
    })
  rescue PermissionError => e
    failure(:permission_denied, {
      message: "You don't have permission to publish this article"
    })
  rescue StandardError => e
    Sentry.capture_exception(e)
    failure(:unexpected_error, {
      message: "An unexpected error occurred"
    })
  end

  private

  def validate_permissions!
    unless @published_by.can_publish?(@article)
      raise PermissionError, "User lacks publish permissions"
    end
  end

  def validate_article_ready!
    errors = []
    errors << "Title is required" if @article.title.blank?
    errors << "Content is required" if @article.content.blank?
    errors << "Category is required" if @article.category_id.nil?

    if errors.any?
      raise BetterModel::Errors::Stateable::CheckFailedError.new(
        event: :publish,
        check_description: errors.join(", "),
        current_state: @article.state
      )
    end
  end

  def update_seo_metadata
    SeoMetadataService.call(@article)
  end

  def schedule_social_media_posts
    SocialMediaScheduler.schedule(@article)
  end

  def send_notifications
    NotificationService.notify_subscribers(@article)
  end

  def friendly_check_message(error)
    case error.check_description
    when /content/
      "Article must have content"
    when /title/
      "Article must have a title"
    when /category/
      "Article must have a category"
    else
      error.check_description
    end
  end

  class PermissionError < StandardError; end
end

# Usage in controller
class ArticlesController < ApplicationController
  def publish
    article = Article.find(params[:id])
    result = ArticlePublishService.call(article, published_by: current_user)

    if result.success?
      render json: {
        status: "published",
        article: ArticleSerializer.new(result.value).as_json
      }, status: :ok
    else
      render json: {
        error: result.error,
        details: result.error_details
      }, status: error_status_for(result.error)
    end
  end

  private

  def error_status_for(error_type)
    case error_type
    when :invalid_state, :requirements_not_met, :validation_failed
      :unprocessable_entity
    when :permission_denied
      :forbidden
    else
      :internal_server_error
    end
  end
end
```

---

### Railway-Oriented Programming

Using dry-rb for railway-oriented error handling:

```ruby
# Gemfile
gem 'dry-monads'
gem 'dry-transaction'

# app/services/article_publish_service.rb
class ArticlePublishService
  include Dry::Monads[:result]
  include Dry::Transaction

  step :validate_permissions
  step :validate_article
  step :publish_article
  step :update_metadata
  step :send_notifications

  def initialize(article, published_by:)
    @article = article
    @published_by = published_by
  end

  def validate_permissions(article, published_by)
    if published_by.can_publish?(article)
      Success([article, published_by])
    else
      Failure([:permission_denied, "You don't have permission to publish"])
    end
  end

  def validate_article(article, published_by)
    errors = []
    errors << "Title required" if article.title.blank?
    errors << "Content required" if article.content.blank?

    if errors.empty?
      Success([article, published_by])
    else
      Failure([:validation_failed, errors])
    end
  end

  def publish_article(article, published_by)
    article.publish!(by: published_by)
    Success([article, published_by])
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    Failure([:invalid_state, {
      current_state: e.from_state,
      message: e.message
    }])
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    Failure([:requirements_not_met, {
      check: e.check_description,
      message: e.message
    }])
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    Failure([:validation_failed, e.errors_object.full_messages])
  end

  def update_metadata(article, published_by)
    SeoMetadataService.call(article)
    Success([article, published_by])
  rescue StandardError => e
    Sentry.capture_exception(e)
    # Non-critical - continue
    Success([article, published_by])
  end

  def send_notifications(article, published_by)
    NotificationService.notify_subscribers(article)
    Success(article)
  rescue StandardError => e
    Sentry.capture_exception(e)
    # Non-critical - still return success
    Success(article)
  end
end

# Usage
result = ArticlePublishService.new(article, published_by: current_user).call

case result
in Success(article)
  render json: { status: "published", article: article }
in Failure([:permission_denied, message])
  render json: { error: message }, status: :forbidden
in Failure([:validation_failed, errors])
  render json: { error: "Validation failed", errors: errors }, status: :unprocessable_entity
in Failure([:invalid_state, details])
  render json: { error: "Invalid state", details: details }, status: :unprocessable_entity
in Failure([:requirements_not_met, details])
  render json: { error: "Requirements not met", details: details }, status: :unprocessable_entity
end
```

---

### Command Pattern with Errors

Using command pattern for complex operations:

```ruby
# app/commands/application_command.rb
class ApplicationCommand
  include ActiveModel::Validations

  class << self
    def call(*args, **kwargs)
      new(*args, **kwargs).tap(&:validate!).call
    end
  end

  def call
    raise NotImplementedError
  end

  def validate!
    raise ValidationError, errors.full_messages unless valid?
  end

  class ValidationError < StandardError
    def initialize(messages)
      super(messages.join(", "))
      @messages = messages
    end

    attr_reader :messages
  end
end

# app/commands/publish_article_command.rb
class PublishArticleCommand < ApplicationCommand
  attr_reader :article, :published_by

  validates :article, presence: true
  validates :published_by, presence: true
  validate :user_can_publish

  def initialize(article:, published_by:)
    @article = article
    @published_by = published_by
  end

  def call
    ActiveRecord::Base.transaction do
      publish_article
      update_search_index
      notify_subscribers
    end

    article
  rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
    raise CommandError.new(:invalid_transition, e.message, original_error: e)
  rescue BetterModel::Errors::Stateable::CheckFailedError => e
    raise CommandError.new(:check_failed, e.check_description, original_error: e)
  rescue BetterModel::Errors::Stateable::ValidationFailedError => e
    raise CommandError.new(:validation_failed, e.errors_object.full_messages.join(", "), original_error: e)
  end

  private

  def user_can_publish
    errors.add(:published_by, "doesn't have publish permission") unless published_by.can_publish?(article)
  end

  def publish_article
    article.publish!(by: published_by)
  end

  def update_search_index
    UpdateSearchIndexJob.perform_later(article.id)
  end

  def notify_subscribers
    NotifySubscribersJob.perform_later(article.id)
  end

  class CommandError < StandardError
    attr_reader :error_type, :original_error

    def initialize(error_type, message, original_error: nil)
      super(message)
      @error_type = error_type
      @original_error = original_error
    end
  end
end

# Usage in controller
class ArticlesController < ApplicationController
  def publish
    article = Article.find(params[:id])
    result = PublishArticleCommand.call(
      article: article,
      published_by: current_user
    )

    render json: {
      status: "published",
      article: ArticleSerializer.new(result).as_json
    }, status: :ok
  rescue PublishArticleCommand::ValidationError => e
    render json: {
      error: "Validation failed",
      errors: e.messages
    }, status: :bad_request
  rescue PublishArticleCommand::CommandError => e
    Sentry.capture_exception(e.original_error) if e.original_error

    status = case e.error_type
             when :invalid_transition, :check_failed, :validation_failed
               :unprocessable_entity
             else
               :internal_server_error
             end

    render json: {
      error: e.error_type.to_s.humanize,
      message: e.message
    }, status: status
  end
end
```

---

## API Error Responses

### RESTful API Errors

Complete RESTful API error handling:

```ruby
# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ApplicationController
      rescue_from BetterModel::Errors::BetterModelError, with: :render_better_model_error
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      private

      def render_better_model_error(error)
        log_error(error)
        capture_in_sentry(error)

        render json: {
          success: false,
          error: {
            type: error_type(error),
            code: error_code(error),
            message: error.message,
            details: error_details(error),
            timestamp: Time.current.iso8601,
            request_id: request.uuid
          }
        }, status: http_status_for(error)
      end

      def render_not_found(error)
        render json: {
          success: false,
          error: {
            type: "not_found",
            code: "RESOURCE_NOT_FOUND",
            message: error.message,
            timestamp: Time.current.iso8601,
            request_id: request.uuid
          }
        }, status: :not_found
      end

      def render_parameter_missing(error)
        render json: {
          success: false,
          error: {
            type: "validation_error",
            code: "PARAMETER_MISSING",
            message: "Required parameter missing: #{error.param}",
            details: { missing_parameter: error.param },
            timestamp: Time.current.iso8601,
            request_id: request.uuid
          }
        }, status: :bad_request
      end

      def error_type(error)
        case error
        when BetterModel::Errors::Searchable::InvalidPredicateError,
             BetterModel::Errors::Searchable::InvalidOrderError,
             BetterModel::Errors::Searchable::InvalidPaginationError
          "invalid_parameters"
        when BetterModel::Errors::Searchable::InvalidSecurityError
          "security_violation"
        when BetterModel::Errors::Stateable::InvalidTransitionError
          "invalid_state"
        when BetterModel::Errors::Stateable::CheckFailedError
          "requirements_not_met"
        when BetterModel::Errors::Stateable::ValidationFailedError
          "validation_failed"
        else
          "application_error"
        end
      end

      def error_code(error)
        [
          error.tags[:module]&.upcase,
          error.tags[:error_category]&.upcase
        ].compact.join("_")
      end

      def error_details(error)
        base_details = {
          module: error.tags[:module],
          category: error.tags[:error_category]
        }

        # Add error-specific details
        case error
        when BetterModel::Errors::Searchable::InvalidPredicateError
          base_details.merge(
            invalid_predicate: error.predicate_scope,
            available_predicates: error.available_predicates
          )
        when BetterModel::Errors::Stateable::InvalidTransitionError
          base_details.merge(
            current_state: error.from_state,
            attempted_event: error.event
          )
        when BetterModel::Errors::Stateable::ValidationFailedError
          base_details.merge(
            errors: error.errors_object.full_messages,
            error_fields: error.errors_object.keys
          )
        else
          base_details.merge(error.extra)
        end
      end

      def http_status_for(error)
        case error
        when BetterModel::Errors::Searchable::InvalidPredicateError,
             BetterModel::Errors::Searchable::InvalidOrderError,
             BetterModel::Errors::Searchable::InvalidPaginationError
          :bad_request
        when BetterModel::Errors::Searchable::InvalidSecurityError
          :forbidden
        when BetterModel::Errors::Stateable::InvalidTransitionError,
             BetterModel::Errors::Stateable::CheckFailedError,
             BetterModel::Errors::Stateable::ValidationFailedError
          :unprocessable_entity
        else
          :internal_server_error
        end
      end

      def log_error(error)
        Rails.logger.error("API Error: #{error.class.name}")
        Rails.logger.error("  Message: #{error.message}")
        Rails.logger.error("  Module: #{error.tags[:module]}")
        Rails.logger.error("  Category: #{error.tags[:error_category]}")
        Rails.logger.error("  Context: #{error.context.inspect}")
      end

      def capture_in_sentry(error)
        Sentry.capture_exception(error) do |scope|
          scope.set_context("error_details", error.context)
          scope.set_tags(error.tags.merge(
            api_version: "v1",
            endpoint: "#{controller_name}##{action_name}"
          ))
          scope.set_extras(error.extra.merge(
            request_id: request.uuid,
            request_path: request.path
          ))
        end
      end
    end
  end
end
```

---

### Problem Details (RFC 7807)

Implementing RFC 7807 Problem Details:

```ruby
# app/controllers/concerns/problem_details.rb
module ProblemDetails
  extend ActiveSupport::Concern

  included do
    rescue_from BetterModel::Errors::BetterModelError, with: :render_problem_details
  end

  private

  def render_problem_details(error)
    problem = build_problem_details(error)
    render json: problem, status: problem[:status], content_type: "application/problem+json"
  end

  def build_problem_details(error)
    {
      type: problem_type_uri(error),
      title: problem_title(error),
      status: http_status_code(error),
      detail: error.message,
      instance: request.path,
      # Extensions
      module: error.tags[:module],
      category: error.tags[:error_category],
      context: error.context,
      extra: error.extra,
      timestamp: Time.current.iso8601,
      trace_id: request.uuid
    }
  end

  def problem_type_uri(error)
    base_url = "https://docs.example.com/problems"
    module_name = error.tags[:module]
    category = error.tags[:error_category]

    "#{base_url}/#{module_name}/#{category}"
  end

  def problem_title(error)
    error.class.name.demodulize.titleize
  end

  def http_status_code(error)
    Rack::Utils.status_code(http_status_for(error))
  end

  def http_status_for(error)
    # ... (same as previous examples)
  end
end

# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ApplicationController
      include ProblemDetails
    end
  end
end
```

---

### Custom Error Format

Creating a custom structured error format:

```ruby
# app/services/error_response_builder.rb
class ErrorResponseBuilder
  def self.build(error, request: nil, user: nil)
    new(error, request: request, user: user).build
  end

  def initialize(error, request: nil, user: nil)
    @error = error
    @request = request
    @user = user
  end

  def build
    {
      error: {
        id: error_id,
        type: error_type,
        code: error_code,
        message: @error.message,
        severity: error_severity,
        recoverable: error_recoverable?,
        context: error_context,
        suggestions: error_suggestions,
        documentation: documentation_url,
        support: support_info
      },
      meta: meta_info
    }
  end

  private

  def error_id
    @error_id ||= Digest::SHA256.hexdigest([
      Time.current.to_f,
      @error.class.name,
      @user&.id,
      rand(10000)
    ].join("-"))[0..15]
  end

  def error_type
    @error.class.name
  end

  def error_code
    [
      @error.tags[:module]&.upcase,
      @error.tags[:error_category]&.upcase
    ].compact.join("_")
  end

  def error_severity
    case @error
    when BetterModel::Errors::Searchable::InvalidSecurityError
      "high"
    when BetterModel::Errors::Stateable::InvalidTransitionError,
         BetterModel::Errors::Stateable::CheckFailedError
      "medium"
    else
      "low"
    end
  end

  def error_recoverable?
    case @error
    when BetterModel::Errors::Searchable::InvalidPredicateError,
         BetterModel::Errors::Searchable::InvalidOrderError,
         BetterModel::Errors::Searchable::InvalidPaginationError
      true
    when BetterModel::Errors::Stateable::ValidationFailedError
      true
    else
      false
    end
  end

  def error_context
    @error.context.merge(
      module: @error.tags[:module],
      category: @error.tags[:error_category]
    )
  end

  def error_suggestions
    case @error
    when BetterModel::Errors::Searchable::InvalidPredicateError
      [
        "Use one of the available predicates: #{@error.available_predicates&.first(3)&.join(', ')}",
        "Check the API documentation for valid search parameters"
      ]
    when BetterModel::Errors::Stateable::CheckFailedError
      [
        "Ensure all requirements are met before attempting this action",
        "Review the current state and requirements"
      ]
    when BetterModel::Errors::Stateable::ValidationFailedError
      @error.errors_object.full_messages.map { |msg| "Fix: #{msg}" }
    else
      ["Contact support if the issue persists"]
    end
  end

  def documentation_url
    module_name = @error.tags[:module]
    "https://docs.example.com/errors/#{module_name}"
  end

  def support_info
    {
      email: "support@example.com",
      error_id: error_id
    }
  end

  def meta_info
    {
      timestamp: Time.current.iso8601,
      request_id: @request&.uuid,
      request_path: @request&.path,
      user_id: @user&.id,
      environment: Rails.env
    }
  end
end

# Usage in controller
class Api::V1::BaseController < ApplicationController
  rescue_from BetterModel::Errors::BetterModelError do |error|
    response = ErrorResponseBuilder.build(
      error,
      request: request,
      user: current_user
    )

    render json: response, status: http_status_for(error)
  end
end
```

---

## Background Job Handling

### Retry Strategies

Different retry strategies for different error types:

```ruby
# app/jobs/process_article_job.rb
class ProcessArticleJob < ApplicationJob
  queue_as :default

  # Retry checks - they might pass later (e.g., waiting for related data)
  retry_on BetterModel::Errors::Stateable::CheckFailedError,
           wait: :polynomially_longer,  # 1s, 4s, 9s, 16s, 25s...
           attempts: 5 do |job, error|
    notify_about_check_failure(job, error)
  end

  # Don't retry invalid transitions - state is wrong
  discard_on BetterModel::Errors::Stateable::InvalidTransitionError do |job, error|
    handle_invalid_transition(job, error)
  end

  # Don't retry validation errors - need manual fix
  discard_on BetterModel::Errors::Stateable::ValidationFailedError do |job, error|
    handle_validation_failure(job, error)
  end

  # Don't retry security violations
  discard_on BetterModel::Errors::Searchable::InvalidSecurityError do |job, error|
    handle_security_violation(job, error)
  end

  def perform(article_id, action, **options)
    article = Article.find(article_id)

    case action
    when :publish
      article.publish!(**options)
    when :archive
      article.archive!(**options)
    else
      raise ArgumentError, "Unknown action: #{action}"
    end

    Rails.logger.info("Successfully processed article #{article_id}: #{action}")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Article not found: #{article_id}")
    Sentry.capture_exception(e)
    # Don't retry - record doesn't exist
  end

  private

  def self.notify_about_check_failure(job, error)
    article_id = job.arguments.first
    Rails.logger.warn("Check failed for article #{article_id}, retries exhausted")
    Rails.logger.warn("  Check: #{error.check_description}")

    # Notify admins after all retries exhausted
    AdminMailer.job_check_failed(
      article_id: article_id,
      error: error,
      attempts: job.executions
    ).deliver_later
  end

  def self.handle_invalid_transition(job, error)
    article_id = job.arguments.first
    Rails.logger.error("Invalid transition for article #{article_id}")
    Rails.logger.error("  From: #{error.from_state}")
    Rails.logger.error("  Event: #{error.event}")

    Sentry.capture_exception(error) do |scope|
      scope.set_context("job", {
        job_class: job.class.name,
        article_id: article_id,
        attempts: job.executions
      })
    end

    # Create admin notification
    AdminNotification.create!(
      notification_type: :job_invalid_transition,
      article_id: article_id,
      details: {
        from_state: error.from_state,
        event: error.event,
        message: error.message
      }
    )
  end

  def self.handle_validation_failure(job, error)
    article_id = job.arguments.first
    Rails.logger.error("Validation failed for article #{article_id}")
    Rails.logger.error("  Errors: #{error.errors_object.full_messages}")

    Sentry.capture_exception(error)

    # Create admin task
    AdminTask.create!(
      task_type: :fix_article_validation,
      article_id: article_id,
      details: {
        errors: error.errors_object.full_messages,
        error_details: error.errors_object.details
      }
    )
  end

  def self.handle_security_violation(job, error)
    article_id = job.arguments.first
    Rails.logger.error("Security violation in job for article #{article_id}")
    Rails.logger.error("  Policy: #{error.policy_name}")

    Sentry.capture_exception(error) do |scope|
      scope.set_level(:error)
      scope.set_fingerprint(["job-security-violation", error.policy_name])
    end

    SecurityAlert.create!(
      alert_type: :job_security_violation,
      article_id: article_id,
      policy: error.policy_name,
      details: error.extra
    )
  end
end
```

---

### Dead Letter Queue

Implementing a dead letter queue for failed jobs:

```ruby
# app/jobs/dead_letter_job.rb
class DeadLetterJob < ApplicationJob
  queue_as :dead_letter

  def perform(original_job_class, arguments, error_info)
    DeadLetter.create!(
      job_class: original_job_class,
      arguments: arguments,
      error_class: error_info[:class],
      error_message: error_info[:message],
      error_backtrace: error_info[:backtrace],
      error_context: error_info[:context],
      failed_at: Time.current
    )

    # Notify admins
    AdminMailer.dead_letter_created(
      job_class: original_job_class,
      error: error_info[:message]
    ).deliver_later
  end
end

# app/jobs/process_article_job.rb
class ProcessArticleJob < ApplicationJob
  rescue_from Exception do |error|
    error_info = {
      class: error.class.name,
      message: error.message,
      backtrace: error.backtrace&.first(10),
      context: error.is_a?(BetterModel::Errors::BetterModelError) ? error.context : {}
    }

    # Send to dead letter queue
    DeadLetterJob.perform_later(
      self.class.name,
      arguments,
      error_info
    )

    # Re-raise to mark job as failed
    raise
  end

  def perform(article_id, action)
    # ... job logic
  end
end

# app/models/dead_letter.rb
class DeadLetter < ApplicationRecord
  scope :unprocessed, -> { where(processed_at: nil) }
  scope :by_error_class, ->(error_class) { where(error_class: error_class) }
  scope :recent, -> { where("created_at >= ?", 24.hours.ago) }

  def retry!
    job_class = job_class.constantize
    job_class.perform_later(*arguments)
    update!(processed_at: Time.current, retry_count: retry_count + 1)
  end

  def discard!
    update!(processed_at: Time.current, discarded: true)
  end
end

# Rake task to review dead letters
# lib/tasks/dead_letters.rake
namespace :dead_letters do
  desc "List recent dead letters"
  task list: :environment do
    DeadLetter.unprocessed.recent.each do |dl|
      puts "ID: #{dl.id}"
      puts "Job: #{dl.job_class}"
      puts "Error: #{dl.error_message}"
      puts "Failed at: #{dl.failed_at}"
      puts "---"
    end
  end

  desc "Retry dead letter by ID"
  task :retry, [:id] => :environment do |t, args|
    dl = DeadLetter.find(args[:id])
    dl.retry!
    puts "Retried dead letter #{dl.id}"
  end
end
```

---

### Error Notifications

Setting up comprehensive error notifications:

```ruby
# app/services/error_notification_service.rb
class ErrorNotificationService
  def self.notify(error, context = {})
    new(error, context).notify
  end

  def initialize(error, context = {})
    @error = error
    @context = context
  end

  def notify
    # Always capture in Sentry
    capture_in_sentry

    # Notify based on error severity
    case error_severity
    when :critical
      notify_critical
    when :high
      notify_high
    when :medium
      notify_medium
    else
      notify_low
    end
  end

  private

  def error_severity
    case @error
    when BetterModel::Errors::Searchable::InvalidSecurityError
      :critical
    when BetterModel::Errors::Stateable::InvalidTransitionError
      :high
    when BetterModel::Errors::Stateable::CheckFailedError,
         BetterModel::Errors::Stateable::ValidationFailedError
      :medium
    else
      :low
    end
  end

  def capture_in_sentry
    Sentry.capture_exception(@error) do |scope|
      scope.set_level(sentry_level)
      scope.set_context("error_details", @error.context)
      scope.set_tags(@error.tags.merge(@context[:tags] || {}))
      scope.set_extras(@error.extra.merge(@context[:extra] || {}))
    end
  end

  def sentry_level
    case error_severity
    when :critical then :fatal
    when :high then :error
    when :medium then :warning
    else :info
    end
  end

  def notify_critical
    # Immediate notification via multiple channels
    notify_slack(channel: "#critical-alerts", urgent: true)
    notify_pagerduty
    notify_email(recipients: admin_emails)
    create_incident
  end

  def notify_high
    notify_slack(channel: "#alerts")
    notify_email(recipients: admin_emails)
  end

  def notify_medium
    notify_slack(channel: "#monitoring")
  end

  def notify_low
    # Just log and Sentry
    Rails.logger.info("Low severity error: #{@error.message}")
  end

  def notify_slack(channel:, urgent: false)
    SlackNotifier.notify(
      channel: channel,
      text: slack_message,
      urgent: urgent,
      attachments: slack_attachments
    )
  end

  def notify_pagerduty
    PagerdutyNotifier.trigger_incident(
      summary: "Critical Error: #{@error.class.name}",
      details: {
        message: @error.message,
        context: @error.context,
        extra: @error.extra
      }
    )
  end

  def notify_email(recipients:)
    ErrorMailer.error_notification(
      error: @error,
      context: @context,
      recipients: recipients
    ).deliver_later
  end

  def create_incident
    Incident.create!(
      severity: :critical,
      error_class: @error.class.name,
      error_message: @error.message,
      error_context: @error.context,
      error_extra: @error.extra,
      context: @context
    )
  end

  def slack_message
    "*#{error_severity.to_s.upcase}*: #{@error.class.name}\n#{@error.message}"
  end

  def slack_attachments
    [
      {
        color: severity_color,
        fields: [
          {
            title: "Module",
            value: @error.tags[:module],
            short: true
          },
          {
            title: "Category",
            value: @error.tags[:error_category],
            short: true
          },
          {
            title: "Context",
            value: @error.context.inspect,
            short: false
          }
        ]
      }
    ]
  end

  def severity_color
    case error_severity
    when :critical then "danger"
    when :high then "warning"
    else "good"
    end
  end

  def admin_emails
    User.where(admin: true).pluck(:email)
  end
end

# Usage in jobs
class ProcessArticleJob < ApplicationJob
  rescue_from BetterModel::Errors::BetterModelError do |error|
    ErrorNotificationService.notify(error, {
      tags: { job: self.class.name },
      extra: { article_id: arguments.first }
    })

    raise  # Re-raise to mark job as failed
  end
end
```

---

## Sentry Integration

### Complete Setup

Production-ready Sentry configuration:

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Environment
  config.environment = Rails.env
  config.enabled_environments = %w[production staging]

  # Release tracking
  config.release = ENV['HEROKU_SLUG_COMMIT'] || `git rev-parse HEAD`.strip

  # Sampling
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f
  config.profiles_sample_rate = ENV.fetch('SENTRY_PROFILES_SAMPLE_RATE', 0.1).to_f

  # Performance monitoring
  config.traces_sampler = lambda do |sampling_context|
    # Higher rate for critical endpoints
    if sampling_context[:parent_sampled] == false
      0.0
    elsif sampling_context.dig(:env, 'REQUEST_PATH')&.include?('/api/')
      0.5
    else
      0.1
    end
  end

  # Filter sensitive data
  config.before_send = lambda do |event, hint|
    # Filter password fields
    if event.request
      event.request.data = filter_sensitive_data(event.request.data)
      event.request.env = filter_sensitive_env(event.request.env)
    end

    # Add custom tags for BetterModel errors
    if hint[:exception].is_a?(BetterModel::Errors::BetterModelError)
      error = hint[:exception]
      event.tags.merge!(error.tags)
      event.contexts[:error_details] = error.context
      event.extra.merge!(error.extra)
    end

    event
  end

  # Breadcrumbs
  config.before_breadcrumb = lambda do |breadcrumb, hint|
    # Filter sensitive breadcrumb data
    if breadcrumb.category == "sql.active_record"
      breadcrumb.data = filter_sql(breadcrumb.data)
    end

    breadcrumb
  end

  private

  def self.filter_sensitive_data(data)
    return data unless data.is_a?(Hash)

    data.except(:password, :password_confirmation, :token, :api_key, :secret)
  end

  def self.filter_sensitive_env(env)
    return env unless env.is_a?(Hash)

    env.except('HTTP_AUTHORIZATION', 'HTTP_COOKIE')
  end

  def self.filter_sql(data)
    return data unless data.is_a?(Hash)

    if data[:sql]
      data[:sql] = data[:sql].gsub(/('password'|'token')\s*=\s*'[^']*'/, "\\1 = '[FILTERED]'")
    end

    data
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_sentry_context

  rescue_from BetterModel::Errors::BetterModelError do |error|
    capture_better_model_error(error)
    render_error_response(error)
  end

  private

  def set_sentry_context
    Sentry.set_user(
      id: current_user&.id,
      email: current_user&.email,
      username: current_user&.username
    )

    Sentry.set_context("request", {
      url: request.url,
      method: request.method,
      controller: controller_name,
      action: action_name,
      params: safe_params
    })
  end

  def capture_better_model_error(error)
    Sentry.capture_exception(error) do |scope|
      # Error-specific data
      scope.set_context("error_details", error.context)
      scope.set_tags(error.tags)
      scope.set_extras(error.extra)

      # Request context
      scope.set_context("controller", {
        name: controller_name,
        action: action_name,
        format: request.format.symbol
      })

      # Custom fingerprinting
      scope.set_fingerprint(custom_fingerprint(error))
    end
  end

  def custom_fingerprint(error)
    [
      error.tags[:module],
      error.tags[:error_category],
      controller_name,
      action_name
    ].compact
  end

  def safe_params
    params.except(:password, :password_confirmation, :token).to_unsafe_h
  end
end
```

---

### Custom Error Grouping

Advanced error grouping strategies:

```ruby
# app/services/sentry_fingerprinter.rb
class SentryFingerprinter
  def self.fingerprint_for(error, context = {})
    new(error, context).fingerprint
  end

  def initialize(error, context = {})
    @error = error
    @context = context
  end

  def fingerprint
    case @error
    when BetterModel::Errors::Searchable::InvalidPredicateError
      predicate_error_fingerprint
    when BetterModel::Errors::Searchable::InvalidSecurityError
      security_error_fingerprint
    when BetterModel::Errors::Stateable::InvalidTransitionError
      transition_error_fingerprint
    when BetterModel::Errors::Stateable::CheckFailedError
      check_error_fingerprint
    when BetterModel::Errors::Stateable::ValidationFailedError
      validation_error_fingerprint
    else
      default_fingerprint
    end
  end

  private

  def predicate_error_fingerprint
    [
      "searchable",
      "invalid_predicate",
      @error.predicate_scope.to_s,
      @context[:controller],
      @context[:action]
    ].compact
  end

  def security_error_fingerprint
    [
      "security_violation",
      @error.policy_name,
      @context[:user_role],
      @context[:controller]
    ].compact
  end

  def transition_error_fingerprint
    [
      "stateable",
      "invalid_transition",
      @error.from_state.to_s,
      @error.event.to_s,
      @error.context[:model_class]
    ].compact
  end

  def check_error_fingerprint
    # Group by check type for similar checks
    check_category = categorize_check(@error.check_description)

    [
      "stateable",
      "check_failed",
      check_category,
      @error.event.to_s,
      @error.context[:model_class]
    ].compact
  end

  def validation_error_fingerprint
    # Group by validation fields
    fields = @error.errors_object.keys.sort.join(",")

    [
      "stateable",
      "validation_failed",
      @error.event.to_s,
      fields,
      @error.context[:model_class]
    ].compact
  end

  def default_fingerprint
    [
      @error.tags[:module],
      @error.tags[:error_category],
      @error.context[:model_class]
    ].compact
  end

  def categorize_check(description)
    return "unknown" unless description

    case description
    when /content|text|body/i
      "content_check"
    when /image|photo|media/i
      "media_check"
    when /payment|price|cost/i
      "payment_check"
    when /permission|auth/i
      "permission_check"
    else
      "other_check"
    end
  end
end

# Usage
Sentry.capture_exception(error) do |scope|
  fingerprint = SentryFingerprinter.fingerprint_for(error, {
    controller: controller_name,
    action: action_name,
    user_role: current_user&.role
  })

  scope.set_fingerprint(fingerprint)
end
```

---

### Performance Monitoring

Monitoring BetterModel operations:

```ruby
# app/controllers/concerns/better_model_monitoring.rb
module BetterModelMonitoring
  extend ActiveSupport::Concern

  included do
    around_action :monitor_better_model_operations
  end

  private

  def monitor_better_model_operations
    transaction = Sentry.start_transaction(
      name: "#{controller_name}##{action_name}",
      op: "http.server"
    )

    Sentry.get_current_scope.set_span(transaction)

    yield

    transaction.finish
  rescue BetterModel::Errors::BetterModelError => e
    transaction.set_http_status(http_status_for(e))
    transaction.finish

    raise
  end
end

# Custom instrumentation
ActiveSupport::Notifications.subscribe("transition.stateable") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000  # Convert to milliseconds

  Sentry.get_current_scope.set_measurement("transition_duration", duration, "millisecond")

  Sentry.add_breadcrumb(
    Sentry::Breadcrumb.new(
      category: "stateable",
      message: "State transition: #{payload[:event]}",
      level: "info",
      data: {
        event: payload[:event],
        from_state: payload[:from_state],
        to_state: payload[:to_state],
        duration_ms: duration
      }
    )
  )
end
```

---

## Testing Strategies

### RSpec Examples

Comprehensive error testing with RSpec:

```ruby
# spec/models/article_spec.rb
RSpec.describe Article, type: :model do
  describe "state transitions" do
    describe "#publish!" do
      context "when transition is valid" do
        it "publishes the article" do
          article = create(:article, :draft)

          expect { article.publish! }.not_to raise_error
          expect(article).to be_published
        end
      end

      context "when already published" do
        it "raises InvalidTransitionError" do
          article = create(:article, :published)

          expect {
            article.publish!
          }.to raise_error(BetterModel::Errors::Stateable::InvalidTransitionError) do |error|
            expect(error.event).to eq(:publish)
            expect(error.from_state).to eq(:published)
            expect(error.to_state).to eq(:published)
            expect(error.tags[:error_category]).to eq("transition")
            expect(error.tags[:module]).to eq("stateable")
          end
        end
      end

      context "when content is missing" do
        it "raises CheckFailedError" do
          article = create(:article, :draft, content: nil)

          expect {
            article.publish!
          }.to raise_error(BetterModel::Errors::Stateable::CheckFailedError) do |error|
            expect(error.event).to eq(:publish)
            expect(error.check_description).to include("content")
            expect(error.current_state).to eq(:draft)
          end
        end
      end

      context "when validation fails" do
        it "raises ValidationFailedError" do
          article = create(:article, :draft, title: "")

          expect {
            article.publish!
          }.to raise_error(BetterModel::Errors::Stateable::ValidationFailedError) do |error|
            expect(error.event).to eq(:publish)
            expect(error.errors_object.full_messages).to include(/Title/)
            expect(error.current_state).to eq(:draft)
            expect(error.target_state).to eq(:published)
          end
        end
      end
    end
  end

  describe "search errors" do
    describe ".search" do
      context "with invalid predicate" do
        it "raises InvalidPredicateError" do
          expect {
            Article.search(title_unknown: "test")
          }.to raise_error(BetterModel::Errors::Searchable::InvalidPredicateError) do |error|
            expect(error.predicate_scope).to eq(:title_unknown)
            expect(error.value).to eq("test")
            expect(error.available_predicates).to be_an(Array)
            expect(error.available_predicates).to include(:title_eq)
          end
        end
      end

      context "with invalid pagination" do
        it "raises InvalidPaginationError" do
          expect {
            Article.search({}, pagination: { page: -1 })
          }.to raise_error(BetterModel::Errors::Searchable::InvalidPaginationError) do |error|
            expect(error.parameter_name).to eq("page")
            expect(error.value).to eq(-1)
          end
        end
      end
    end
  end
end
```

---

### Minitest Examples

Error testing with Minitest:

```ruby
# test/models/article_test.rb
class ArticleTest < ActiveSupport::TestCase
  test "publish raises InvalidTransitionError when already published" do
    article = articles(:published)

    error = assert_raises(BetterModel::Errors::Stateable::InvalidTransitionError) do
      article.publish!
    end

    assert_equal :publish, error.event
    assert_equal :published, error.from_state
    assert_equal "stateable", error.tags[:module]
    assert_equal "transition", error.tags[:error_category]
  end

  test "publish raises CheckFailedError without content" do
    article = Article.new(title: "Test", content: nil)

    error = assert_raises(BetterModel::Errors::Stateable::CheckFailedError) do
      article.publish!
    end

    assert_equal :publish, error.event
    assert_includes error.check_description, "content"
  end

  test "search with invalid predicate raises InvalidPredicateError" do
    error = assert_raises(BetterModel::Errors::Searchable::InvalidPredicateError) do
      Article.search(title_unknown: "test")
    end

    assert_equal :title_unknown, error.predicate_scope
    assert_equal "test", error.value
    assert_includes error.available_predicates, :title_eq
  end
end
```

---

### Request Specs

Testing error responses:

```ruby
# spec/requests/articles_spec.rb
RSpec.describe "Articles API", type: :request do
  describe "POST /api/v1/articles/:id/publish" do
    context "when article is already published" do
      it "returns unprocessable_entity with error details" do
        article = create(:article, :published)

        post "/api/v1/articles/#{article.id}/publish"

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid action")
        expect(json["current_state"]).to eq("published")
        expect(json["attempted_action"]).to eq("publish")
      end
    end

    context "when checks fail" do
      it "returns unprocessable_entity with requirements" do
        article = create(:article, :draft, content: nil)

        post "/api/v1/articles/#{article.id}/publish"

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Requirements not met")
        expect(json["message"]).to include("content")
      end
    end
  end

  describe "GET /api/v1/articles/search" do
    context "with invalid predicate" do
      it "returns bad_request with available predicates" do
        get "/api/v1/articles/search", params: { title_unknown: "test" }

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid search parameter")
        expect(json["invalid_parameter"]).to eq("title_unknown")
        expect(json["available_parameters"]).to be_an(Array)
      end
    end

    context "with security violation" do
      it "returns forbidden without exposing details" do
        get "/api/v1/articles/search", params: { per_page: 10000 }

        expect(response).to have_http_status(:forbidden)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Access denied")
        expect(json).not_to have_key("details")  # Don't expose security details
      end
    end
  end
end
```

---

## Related Documentation

- [Error System](../errors.md) - Comprehensive error documentation
- [Context7 Errors](../../context7/12_errors.md) - Quick reference
- [Stateable](../stateable.md) - State machine errors
- [Searchable](../searchable.md) - Search errors
- [Archivable](../archivable.md) - Archive errors
