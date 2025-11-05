# Cookbook: Solutions to Common Problems

Quick solutions to specific problems using BetterModel modules.

## Table of Contents
1. [Three-Level Approval Workflow](#recipe-1-three-level-approval-workflow)
2. [Soft Delete with Selective Restore](#recipe-2-soft-delete-with-selective-restore)
3. [Advanced API Filters](#recipe-3-advanced-api-filters-with-validation)
4. [Time-Limited Edit Window](#recipe-4-time-limited-edit-window)
5. [Partial Field Rollback](#recipe-5-partial-field-rollback)
6. [Conditional Required Fields](#recipe-6-conditional-required-fields)
7. [Auto-Archive Based on Criteria](#recipe-7-auto-archive-based-on-criteria)
8. [Search with Complex OR Conditions](#recipe-8-search-with-complex-or-conditions)
9. [State-Based Validation](#recipe-9-state-based-validation)
10. [Audit Export for Compliance](#recipe-10-audit-export-for-compliance)

---

## Recipe 1: Three-Level Approval Workflow

**Problem**: Need draft → manager approval → director approval → published workflow

**Solution**: Stateable + Permissible

```ruby
class Document < ApplicationRecord
  include BetterModel

  belongs_to :author, class_name: "User"
  belongs_to :manager, class_name: "User", optional: true
  belongs_to :director, class_name: "User", optional: true

  is :author, -> { author_id == Current.user&.id }
  is :manager_role, -> { Current.user&.manager? }
  is :director_role, -> { Current.user&.director? }
  is :admin, -> { Current.user&.admin? }

  permit :submit_for_approval, -> { is?(:author) }
  permit :manager_approve, -> { is?(:manager_role) || is?(:admin) }
  permit :director_approve, -> { is?(:director_role) || is?(:admin) }

  stateable do
    state :draft, initial: true
    state :manager_review
    state :director_review
    state :published
    state :rejected

    transition :submit, from: :draft, to: :manager_review do
      guard { can?(:submit_for_approval) }
      after :notify_managers
    end

    transition :manager_approve, from: :manager_review, to: :director_review do
      guard { can?(:manager_approve) }
      before { self.manager_id = Current.user.id }
      after :notify_directors
    end

    transition :manager_reject, from: :manager_review, to: :rejected do
      guard { can?(:manager_approve) }
      before { self.manager_id = Current.user.id }
      after :notify_author_rejected
    end

    transition :director_approve, from: :director_review, to: :published do
      guard { can?(:director_approve) }
      before do
        self.director_id = Current.user.id
        self.published_at = Time.current
      end
      after :notify_author_published
    end

    transition :director_reject, from: :director_review, to: :rejected do
      guard { can?(:director_approve) }
      before { self.director_id = Current.user.id }
      after :notify_author_rejected
    end
  end

  private

  def notify_managers
    ManagerMailer.new_document_for_review(self).deliver_later
  end

  def notify_directors
    DirectorMailer.new_document_for_review(self).deliver_later
  end

  def notify_author_published
    AuthorMailer.document_published(self).deliver_later
  end

  def notify_author_rejected
    AuthorMailer.document_rejected(self).deliver_later
  end
end
```

---

## Recipe 2: Soft Delete with Selective Restore

**Problem**: Archive records but restore only specific fields, not all

**Solution**: Archivable + Traceable + custom logic

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable
  traceable do
    track :title, :content, :status, :published_at
  end

  def restore_selective!(fields: [])
    raise NotArchivedError unless archived?

    # Get version before archival
    last_active_version = versions
      .where("created_at < ?", archived_at)
      .order(created_at: :desc)
      .first

    return false unless last_active_version

    transaction do
      # Restore only specified fields
      if fields.any?
        fields.each do |field|
          if last_active_version.object_changes.key?(field.to_s)
            old_value = last_active_version.object_changes[field.to_s].first
            self.send("#{field}=", old_value)
          end
        end
      end

      # Clear archive metadata
      self.archived_at = nil
      self.archived_by_id = nil
      self.archive_reason = nil

      save!(validate: false)
    end
  end
end

# Usage
article.archive!(by: user, reason: "Outdated")
# ... later ...
article.restore_selective!(fields: [:title, :published_at])
# Restores only title and published_at, keeps other current values
```

---

## Recipe 3: Advanced API Filters with Validation

**Problem**: Build secure API with complex filters, preventing injection

**Solution**: Searchable + Strong Parameters + Whitelisting

```ruby
class Api::V1::ProductsController < Api::V1::BaseController
  ALLOWED_PREDICATES = %i[
    name_cont
    category_eq category_in
    price_gteq price_lteq price_between
    stock_count_gt stock_count_eq
    featured_true
    published_at_gteq published_at_lteq published_at_within
  ].freeze

  ALLOWED_SORTS = %i[
    name_asc name_desc
    price_asc price_desc
    published_at_asc published_at_desc
    stock_count_asc stock_count_desc
  ].freeze

  def index
    # Validate and sanitize filters
    filters = validate_filters(params[:filters] || {})
    sort = validate_sort(params[:sort])
    pagination = validate_pagination(params[:page], params[:per_page])

    results = Product.search(filters, sort: sort, pagination: pagination)

    render json: {
      data: serialize_products(results),
      meta: pagination_meta(results),
      applied_filters: filters,
      available_filters: filter_options
    }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def validate_filters(filters)
    validated = {}

    filters.each do |key, value|
      sym_key = key.to_sym
      next unless ALLOWED_PREDICATES.include?(sym_key)

      # Type validation
      validated[sym_key] = case sym_key
      when :name_cont
        value.to_s.strip
      when :category_eq
        value.to_s if Product.distinct.pluck(:category).include?(value.to_s)
      when :category_in
        Array(value) & Product.distinct.pluck(:category)
      when :price_gteq, :price_lteq
        Float(value) rescue nil
      when :price_between
        [Float(value.first), Float(value.last)] rescue nil
      when :stock_count_gt, :stock_count_eq
        Integer(value) rescue nil
      when :featured_true
        value.to_s == "true"
      when :published_at_gteq, :published_at_lteq
        Time.parse(value.to_s) rescue nil
      when :published_at_within
        duration_from_string(value)
      end
    end

    validated.compact
  end

  def validate_sort(sort)
    sym_sort = sort.to_sym
    ALLOWED_SORTS.include?(sym_sort) ? sym_sort : :published_at_desc
  end

  def validate_pagination(page, per_page)
    {
      page: [[page.to_i, 1].max, 1000].min,
      per_page: [[per_page.to_i, 1].max, 100].min
    }
  end

  def duration_from_string(value)
    case value.to_s
    when /^(\d+)\.days$/ then $1.to_i.days
    when /^(\d+)\.weeks$/ then $1.to_i.weeks
    when /^(\d+)\.months$/ then $1.to_i.months
    else 7.days
    end
  end

  def filter_options
    {
      categories: Product.distinct.pluck(:category).compact.sort,
      price_range: {
        min: Product.minimum(:price),
        max: Product.maximum(:price)
      },
      sorts: ALLOWED_SORTS
    }
  end
end
```

---

## Recipe 4: Time-Limited Edit Window

**Problem**: Allow editing only within 24 hours of publication

**Solution**: Permissible + Statusable + Time Logic

```ruby
class Post < ApplicationRecord
  include BetterModel

  is :published, -> { status == "published" && published_at.present? }
  is :within_edit_window, -> { published_at.present? && published_at >= 24.hours.ago }
  is :author, -> { user_id == Current.user&.id }
  is :admin, -> { Current.user&.admin? }

  permit :edit, -> {
    return true if is?(:admin)
    is?(:author) && (!is?(:published) || is?(:within_edit_window))
  }

  permit :delete, -> {
    return true if is?(:admin)
    is?(:author) && !is?(:published)
  }

  # Helper to show edit deadline
  def edit_deadline
    return nil unless published?
    published_at + 24.hours
  end

  def time_until_locked
    return nil unless published? && within_edit_window?
    edit_deadline - Time.current
  end

  def locked?
    published? && !within_edit_window? && !Current.user&.admin?
  end
end

# In views
<% if @post.locked? %>
  <div class="alert">
    This post is locked. Edit window expired <%= time_ago_in_words(@post.edit_deadline) %> ago.
  </div>
<% elsif @post.within_edit_window? %>
  <div class="notice">
    You can edit for <%= distance_of_time_in_words(@post.time_until_locked) %> more.
  </div>
<% end %>
```

---

## Recipe 5: Partial Field Rollback

**Problem**: Rollback only specific fields from a version, not entire record

**Solution**: Traceable + Custom Method

```ruby
class Article < ApplicationRecord
  include BetterModel

  traceable do
    track :title, :content, :status, :published_at
  end

  def rollback_fields(version_id, fields:)
    version = versions.find(version_id)
    raise ArgumentError, "Version not found" unless version

    transaction do
      fields.each do |field|
        field_str = field.to_s
        next unless version.object_changes.key?(field_str)

        # Get the "from" value (before the change in that version)
        old_value = version.object_changes[field_str].first
        self.send("#{field}=", old_value)
      end

      save!

      # Track the partial rollback
      versions.last.update(
        updated_by_id: Current.user&.id,
        updated_reason: "Partial rollback of #{fields.join(', ')} from version #{version_id}"
      )
    end
  end

  # Rollback to a point in time, but only certain fields
  def rollback_fields_to_time(time, fields:)
    version = versions.where("created_at <= ?", time)
                     .order(created_at: :desc)
                     .first

    return false unless version
    rollback_fields(version.id, fields: fields)
  end
end

# Usage
article.update!(title: "New Title", content: "New Content", status: "published")
# ... later, realize title was wrong but content is good ...
old_version = article.versions.where("created_at < ?", 1.hour.ago).last
article.rollback_fields(old_version.id, fields: [:title])
# Only title is rolled back, content and status remain current
```

---

## Recipe 6: Conditional Required Fields

**Problem**: Fields required only in certain states or conditions

**Solution**: Validatable + Conditional Blocks

```ruby
class Form < ApplicationRecord
  include BetterModel

  validatable do
    # Always required
    check :name, presence: true

    # Required when published
    validate_if -> { status == "published" } do
      check :description, presence: true, length: { minimum: 50 }
      check :published_at, presence: true
    end

    # Required for premium tier
    validate_if -> { tier == "premium" } do
      check :premium_features, presence: true
      check :support_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    end

    # Required if condition field is checked
    validate_if -> { requires_approval? } do
      check :approver_email, presence: true
      check :approval_deadline, presence: true
    end

    # Complex conditional: required unless another field is present
    validate_business_rule :either_phone_or_email_required
  end

  private

  def either_phone_or_email_required
    if phone.blank? && email.blank?
      errors.add(:base, "Either phone or email must be provided")
    end
  end
end
```

---

## Recipe 7: Auto-Archive Based on Criteria

**Problem**: Automatically archive records meeting specific criteria

**Solution**: Archivable + Scheduled Job

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable do
    skip_archived_by_default true
  end

  # Criteria for auto-archival
  def self.archivable_criteria
    [
      # Older than 2 years with no views
      where("created_at < ? AND view_count = 0", 2.years.ago),

      # Marked as obsolete
      where(status: "obsolete"),

      # Superseded by newer version
      where.not(superseded_by_id: nil),

      # Author requested deletion
      where(deletion_requested: true).where("deletion_requested_at < ?", 30.days.ago)
    ]
  end

  def self.auto_archive!
    count = 0

    archivable_criteria.each do |scope|
      scope.find_each do |article|
        next if article.archived?

        reason = determine_archive_reason(article)
        article.archive!(by: 0, reason: reason)  # 0 = System
        count += 1
      end
    end

    count
  end

  def self.determine_archive_reason(article)
    case
    when article.view_count == 0 && article.created_at < 2.years.ago
      "No views in 2+ years"
    when article.status == "obsolete"
      "Marked as obsolete"
    when article.superseded_by_id.present?
      "Superseded by article ##{article.superseded_by_id}"
    when article.deletion_requested?
      "Author requested deletion #{article.deletion_requested_at.to_date}"
    else
      "Auto-archived by system"
    end
  end
end

# Rake task
# lib/tasks/archive.rake
namespace :articles do
  desc "Auto-archive articles meeting criteria"
  task auto_archive: :environment do
    count = Article.auto_archive!
    puts "Archived #{count} articles"
  end
end

# Run daily via cron or sidekiq-scheduler
```

---

## Recipe 8: Search with Complex OR Conditions

**Problem**: Search where (field1 = A OR field2 = B) AND field3 = C

**Solution**: Searchable + OR syntax

```ruby
class Product < ApplicationRecord
  include BetterModel

  predicates :name, :description, :category, :status, :price
  searchable
end

# Controller
def search
  # Find products where:
  # (name contains "ruby" OR description contains "ruby")
  # AND category = "books"
  # AND status = "available"
  # AND price <= 50

  results = Product.search({
    category_eq: "books",
    status_eq: "available",
    price_lteq: 50,
    or: [
      { name_cont: "ruby" },
      { description_cont: "ruby" }
    ]
  })

  # More complex: (A OR B) AND (C OR D)
  # This requires multiple searches
  results1 = Product.search({
    or: [{ name_cont: "ruby" }, { description_cont: "ruby" }]
  })

  results2 = Product.search({
    or: [{ category_eq: "books" }, { category_eq: "ebooks" }]
  })

  # Combine with set intersection
  @products = results1 & results2
end
```

---

## Recipe 9: State-Based Validation

**Problem**: Different validation rules for each state

**Solution**: Validatable + Stateable Integration

```ruby
class Order < ApplicationRecord
  include BetterModel

  validatable do
    # Always required
    check :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

    # Draft state: minimal validation
    # (no additional validations needed)

    # Processing state: need payment info
    validate_if -> { state == "processing" } do
      check :payment_method, presence: true
      check :billing_address, presence: true
    end

    # Shipping state: need shipping info
    validate_if -> { state == "shipping" || state == "shipped" } do
      check :shipping_address, presence: true
      check :shipping_method, presence: true
      check :tracking_number, presence: true
    end

    # Delivered state: need confirmation
    validate_if -> { state == "delivered" } do
      check :delivered_at, presence: true
      check :signature, presence: true
    end
  end

  stateable do
    state :draft, initial: true
    state :processing
    state :shipping
    state :shipped
    state :delivered

    transition :process, from: :draft, to: :processing do
      guard { valid? }  # Uses validations for "processing" state
    end

    transition :ship, from: :processing, to: :shipping do
      guard { valid? }
    end

    # etc.
  end
end
```

---

## Recipe 10: Audit Export for Compliance

**Problem**: Export complete audit trail in multiple formats for compliance

**Solution**: Traceable + Custom Export

```ruby
class Record < ApplicationRecord
  include BetterModel

  traceable do
    track :title, :content, :status, :sensitive_data
  end

  # Export audit trail as CSV
  def audit_trail_csv
    require 'csv'

    CSV.generate do |csv|
      csv << ["Timestamp", "Event", "Field", "Old Value", "New Value", "User ID", "Reason"]

      versions.order(created_at: :asc).each do |version|
        if version.object_changes.present?
          version.object_changes.each do |field, (old_val, new_val)|
            csv << [
              version.created_at.iso8601,
              version.event,
              field,
              old_val,
              new_val,
              version.updated_by_id,
              version.updated_reason
            ]
          end
        else
          csv << [
            version.created_at.iso8601,
            version.event,
            "-",
            "-",
            "-",
            version.updated_by_id,
            version.updated_reason
          ]
        end
      end
    end
  end

  # Export as JSON for API
  def audit_trail_json
    {
      record_id: id,
      record_type: self.class.name,
      current_state: as_json(only: tracked_fields),
      audit_trail: versions.order(created_at: :asc).map do |v|
        {
          version_id: v.id,
          timestamp: v.created_at.iso8601,
          event: v.event,
          changes: v.object_changes,
          metadata: {
            user_id: v.updated_by_id,
            reason: v.updated_reason
          }
        }
      end,
      statistics: {
        total_versions: versions.count,
        created_at: created_at.iso8601,
        last_updated: updated_at.iso8601,
        change_frequency: change_frequency
      }
    }
  end

  # Export as PDF (using Prawn or similar)
  def audit_trail_pdf
    require 'prawn'

    Prawn::Document.new do |pdf|
      pdf.text "Audit Trail for #{self.class.name} ##{id}", size: 20, style: :bold
      pdf.move_down 20

      pdf.text "Generated: #{Time.current.to_s(:long)}"
      pdf.text "Total Versions: #{versions.count}"
      pdf.move_down 20

      versions.order(created_at: :asc).each do |version|
        pdf.text "#{version.created_at.to_s(:long)} - #{version.event.upcase}", style: :bold
        pdf.move_down 5

        if version.object_changes.present?
          version.object_changes.each do |field, (old_val, new_val)|
            pdf.text "  #{field}: #{old_val.inspect} → #{new_val.inspect}"
          end
        end

        pdf.text "  Updated by: User ##{version.updated_by_id}" if version.updated_by_id
        pdf.text "  Reason: #{version.updated_reason}" if version.updated_reason
        pdf.move_down 10
      end
    end.render
  end

  private

  def tracked_fields
    self.class.traceable_config[:tracked_fields]
  end

  def change_frequency
    return 0 if versions.count <= 1
    days_since_creation = (Time.current - created_at) / 1.day
    (versions.count.to_f / days_since_creation).round(2)
  end
end

# Controller
class AuditsController < ApplicationController
  def export
    @record = Record.find(params[:id])
    authorize! :export_audit, @record

    respond_to do |format|
      format.csv do
        send_data @record.audit_trail_csv,
                  filename: "audit_#{@record.id}_#{Date.today}.csv"
      end

      format.json do
        render json: @record.audit_trail_json
      end

      format.pdf do
        send_data @record.audit_trail_pdf,
                  filename: "audit_#{@record.id}_#{Date.today}.pdf",
                  type: "application/pdf"
      end
    end
  end
end
```

---

## Tips for Using These Recipes

1. **Copy and Adapt**: These are starting points, customize for your needs
2. **Test Thoroughly**: Each recipe should have comprehensive tests
3. **Consider Performance**: Some solutions may need optimization at scale
4. **Document Changes**: Comment why you chose a particular approach
5. **Combine Recipes**: Many of these can work together

## Related Documentation

- [Integration Patterns](10_integration_patterns.md) - Complete pattern implementations
- [Use Cases](11_use_cases.md) - Real-world applications
- [Individual Modules](README.md) - Detailed module documentation

---

[Back to Examples Index](README.md)
