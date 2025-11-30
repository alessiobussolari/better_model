# frozen_string_literal: true

class Article < ApplicationRecord
  include BetterModel
  include BetterModel::Searchable

  # Associations
  belongs_to :author, optional: true
  has_many :comments, dependent: :destroy

  # Serialize tags as array (for SQLite compatibility)
  # In PostgreSQL, this would be a native array column
  serialize :tags, coder: JSON, type: Array

  # Configure Taggable
  taggable do
    tag_field :tags
    normalize true
  end

  # Define various statuses for testing
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :scheduled, -> { scheduled_at.present? && scheduled_at > Time.current }
  is :ready_to_publish, -> { scheduled_at.present? && scheduled_at <= Time.current }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :popular, -> { view_count >= 100 }
  is :active, -> { status == "published" && published_at.present? && !is?(:expired) }

  # Define various permissions for testing
  permit :delete, -> { is?(:draft) }
  permit :edit, -> { is?(:draft) || (is?(:published) && !is?(:expired)) }
  permit :publish, -> { is?(:draft) }
  permit :unpublish, -> { is?(:published) }
  permit :archive, -> { is?(:published) && created_at < 1.year.ago }

  # Define sortable fields for testing
  sort :title, :view_count, :published_at, :created_at

  # Define predicable fields for testing
  predicates :title, :status, :view_count, :published_at, :created_at, :featured

  # Define searchable configuration for testing
  searchable do
    default_order [ :sort_created_at_desc ]
    per_page 25
    max_per_page 100

    # Example securities for testing
    security :status_required, [ :status_eq ]
    security :featured_only, [ :featured_eq ]
  end

  # ========================================
  # Archivable (Opt-In)
  # ========================================
  # Enable archivable functionality for integration tests
  archivable

  # ========================================
  # Traceable (Opt-In)
  # ========================================
  # Enable change tracking for integration tests
  # Track key fields for audit trail
  traceable do
    track :title, :status, :content, :published_at, :view_count
    versions_table "article_versions"
  end

  # ========================================
  # Validatable (Opt-In)
  # ========================================
  # Register complex validations for integration tests
  # NOTE: These validations are registered but NOT automatically applied
  # They can be manually triggered in tests via validate_group or explicit calls
  register_complex_validation :content_required_for_publish do
    # Only validate content when explicitly checking publish_info group
    # This is used for multi-step form validation, not global save
  end

  register_complex_validation :valid_publish_date do
    # This validation checks that published_at < expires_at
    # Only triggered when explicitly called via validate_group
    if published_at.present? && expires_at.present? && published_at >= expires_at
      errors.add(:published_at, "must be before expiration date")
    end
  end

  # Enable validatable with groups for multi-step form testing
  # NOTE: Using validation groups for controlled, explicit validation
  # Complex validations are NOT applied globally to avoid breaking existing tests
  validatable do
    # Validation groups for multi-step workflows
    validation_group :basic_info, [ :title ]
    validation_group :publish_info, [ :content, :published_at ]
    validation_group :date_validation, [ :published_at, :expires_at ]
  end
end
