# frozen_string_literal: true

class Article < ApplicationRecord
  include BetterModel
  include BetterModel::Searchable

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
    default_order [:sort_created_at_desc]
    per_page 25
    max_per_page 100

    # Example securities for testing
    security :status_required, [:status_eq]
    security :featured_only, [:featured_true]
  end
end
