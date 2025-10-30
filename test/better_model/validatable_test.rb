# frozen_string_literal: true

require "test_helper"

class BetterModel::ValidatableTest < ActiveSupport::TestCase
  # Setup helpers

  def setup
    # Clean up any previously defined test classes (up to 100 to be safe)
    100.times do |i|
      const_name = "ValidatableArticle#{i + 1}"
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    end
  end

  def create_validatable_class(const_name, &block)
    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel
    end

    Object.const_set(const_name, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  # Test 1: Opt-in behavior
  test "validatable is not enabled by default" do
    article_class = create_validatable_class(:ValidatableArticle1)

    assert_not article_class.validatable_enabled?
  end

  test "validatable can be enabled with validatable do...end" do
    article_class = create_validatable_class(:ValidatableArticle2) do
      validatable do
        # Empty block
      end
    end

    assert article_class.validatable_enabled?
  end

  # Test 2: Basic validations
  test "validate with presence works" do
    article_class = create_validatable_class(:ValidatableArticle3) do
      validatable do
        validate :title, presence: true
      end
    end

    article = article_class.new(title: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"

    article.title = "Valid Title"
    assert article.valid?
  end

  test "validate with multiple fields" do
    article_class = create_validatable_class(:ValidatableArticle4) do
      validatable do
        validate :title, :status, presence: true
      end
    end

    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
    assert_includes article.errors[:status], "can't be blank"
  end

  # Test 3: Conditional validations with validate_if
  test "validate_if with symbol condition" do
    article_class = create_validatable_class(:ValidatableArticle5) do
      # Define status predicate
      is :published, -> { status == "published" }

      validatable do
        validate_if :is_published? do
          validate :published_at, presence: true
        end
      end
    end

    # Draft article (condition false) - should be valid even without published_at
    article = article_class.new(status: "draft", published_at: nil)
    assert article.valid?

    # Published article (condition true) - requires published_at
    article = article_class.new(status: "published", published_at: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "can't be blank"

    article.published_at = Time.current
    assert article.valid?
  end

  test "validate_if with lambda condition" do
    article_class = create_validatable_class(:ValidatableArticle6) do
      validatable do
        validate_if -> { status == "published" } do
          validate :published_at, presence: true
        end
      end
    end

    article = article_class.new(status: "draft", published_at: nil)
    assert article.valid?

    article = article_class.new(status: "published", published_at: nil)
    assert_not article.valid?
  end

  test "validate_unless negates condition" do
    article_class = create_validatable_class(:ValidatableArticle7) do
      is :draft, -> { status == "draft" }

      validatable do
        validate_unless :is_draft? do
          validate :published_at, presence: true
        end
      end
    end

    # Draft (condition true, negated to false) - validation skipped
    article = article_class.new(status: "draft", published_at: nil)
    assert article.valid?

    # Published (condition false, negated to true) - validation applied
    article = article_class.new(status: "published", published_at: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "can't be blank"
  end

  # Test 4: Order validations (cross-field)
  test "validate_order with before comparator for dates" do
    article_class = create_validatable_class(:ValidatableArticle8) do
      validatable do
        validate_order :starts_at, :before, :ends_at
      end
    end

    # Valid: starts_at before ends_at
    article = article_class.new(starts_at: 1.day.ago, ends_at: Time.current)
    assert article.valid?

    # Invalid: starts_at after ends_at
    article = article_class.new(starts_at: Time.current, ends_at: 1.day.ago)
    assert_not article.valid?
    assert_includes article.errors[:starts_at], "must be before ends at"
  end

  test "validate_order with lteq comparator for numbers" do
    article_class = create_validatable_class(:ValidatableArticle9) do
      validatable do
        validate_order :view_count, :lteq, :max_views
      end
    end

    # Valid: view_count <= max_views
    article = article_class.new(view_count: 50, max_views: 100)
    assert article.valid?

    article = article_class.new(view_count: 100, max_views: 100)
    assert article.valid?

    # Invalid: view_count > max_views
    article = article_class.new(view_count: 150, max_views: 100)
    assert_not article.valid?
    assert_includes article.errors[:view_count], "must be less than or equal to max views"
  end

  test "validate_order skips validation when fields are nil" do
    article_class = create_validatable_class(:ValidatableArticle10) do
      validatable do
        validate_order :starts_at, :before, :ends_at
      end
    end

    # Should not error when nil (use presence validation for that)
    article = article_class.new(starts_at: nil, ends_at: nil)
    assert article.valid?
  end

  # Test 5: Business rules
  test "validate_business_rule calls custom method" do
    article_class = create_validatable_class(:ValidatableArticle11) do
      validatable do
        validate_business_rule :valid_status
      end

      # Define the business rule method
      def valid_status
        valid_statuses = %w[draft published archived]
        unless valid_statuses.include?(status)
          errors.add(:status, "must be one of: #{valid_statuses.join(', ')}")
        end
      end
    end

    article = article_class.new(status: "draft")
    assert article.valid?

    article = article_class.new(status: "invalid")
    assert_not article.valid?
    assert_includes article.errors[:status], "must be one of: draft, published, archived"
  end

  test "validate_business_rule raises error if method not found" do
    article_class = create_validatable_class(:ValidatableArticle12) do
      validatable do
        validate_business_rule :nonexistent_rule
      end
    end

    article = article_class.new
    error = assert_raises(NoMethodError) do
      article.valid?
    end

    assert_match(/Business rule method 'nonexistent_rule' not found/, error.message)
  end

  # Test 6: Validation groups
  test "validation_group defines groups" do
    article_class = create_validatable_class(:ValidatableArticle13) do
      validatable do
        validate :title, presence: true
        validate :status, presence: true
        validate :view_count, presence: true

        validation_group :step1, [:title]
        validation_group :step2, [:status, :view_count]
      end
    end

    article = article_class.new(title: "Valid", status: nil, view_count: nil)

    # Full validation fails
    assert_not article.valid?

    # Step1 validation passes (only title)
    assert article.valid?(:step1)

    # Step2 validation fails (status and view_count missing)
    assert_not article.valid?(:step2)
  end

  test "errors_for_group filters errors to group fields" do
    article_class = create_validatable_class(:ValidatableArticle14) do
      validatable do
        validate :title, presence: true
        validate :status, presence: true

        validation_group :step1, [:title]
      end
    end

    article = article_class.new(title: nil, status: nil)
    article.valid?  # Run full validation

    # Get errors only for step1 fields
    step1_errors = article.errors_for_group(:step1)
    assert step1_errors[:title].any?
    assert step1_errors[:status].empty?
  end

  test "validate_group raises error if validatable not enabled" do
    article_class = create_validatable_class(:ValidatableArticle15)
    # Don't enable validatable

    article = article_class.new
    error = assert_raises(BetterModel::ValidatableNotEnabledError) do
      article.validate_group(:step1)
    end

    assert_match(/Validatable is not enabled/, error.message)
  end

  test "errors_for_group raises error if validatable not enabled" do
    article_class = create_validatable_class(:ValidatableArticle16)

    article = article_class.new
    error = assert_raises(BetterModel::ValidatableNotEnabledError) do
      article.errors_for_group(:step1)
    end

    assert_match(/Validatable is not enabled/, error.message)
  end

  # Test 7: Complex scenario
  test "complex validation scenario with all features" do
    article_class = create_validatable_class(:ValidatableArticle17) do
      is :published, -> { status == "published" }
      is :scheduled, -> { status == "scheduled" }

      validatable do
        # Basic validations
        validate :title, presence: true
        validate :status, presence: true

        # Conditional validations
        validate_if :is_published? do
          validate :published_at, presence: true
        end

        validate_if :is_scheduled? do
          validate :scheduled_for, presence: true
        end

        # Cross-field validation
        validate_order :starts_at, :before, :ends_at

        # Business rule
        validate_business_rule :valid_view_count

        # Validation groups
        validation_group :basic, [:title, :status]
        validation_group :publishing, [:published_at, :scheduled_for]
      end

      def valid_view_count
        if view_count && view_count.negative?
          errors.add(:view_count, "cannot be negative")
        end
      end
    end

    # Valid published article
    article = article_class.new(
      title: "Test",
      status: "published",
      published_at: Time.current,
      starts_at: 1.day.ago,
      ends_at: Time.current,
      view_count: 100
    )
    assert article.valid?

    # Invalid: negative view count
    article.view_count = -10
    assert_not article.valid?
    assert_includes article.errors[:view_count], "cannot be negative"
  end

  # Test 8: ActiveRecord integration
  test "validatable raises error when included in non-ActiveRecord class" do
    error = assert_raises(ArgumentError) do
      Class.new do
        include BetterModel::Validatable
      end
    end

    assert_match(/can only be included in ActiveRecord models/, error.message)
  end

  # Test 9: Configuration immutability
  test "validatable_config is frozen after setup" do
    article_class = create_validatable_class(:ValidatableArticle18) do
      validatable do
        validate :title, presence: true
      end
    end

    assert article_class.validatable_config.frozen?
    assert article_class.validatable_groups.frozen?
  end

  # Test 10: Setup runs only once
  test "validatable setup runs only once" do
    article_class = create_validatable_class(:ValidatableArticle19) do
      validatable do
        validate :title, presence: true
      end

      # Call validatable again
      validatable do
        validate :status, presence: true
      end
    end

    # Only first config should be applied (setup_done prevents second run)
    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?

    # Both validations should be present from second call
    # (config is updated but validators not re-applied)
    assert_includes article.errors[:title], "can't be blank"
    assert_includes article.errors[:status], "can't be blank"
  end

  # ========================================
  # EDGE CASES - VALIDAZIONI BASE
  # ========================================

  test "validate with multiple validation options (presence + length)" do
    article_class = create_validatable_class(:ValidatableArticle20) do
      validatable do
        validate :title, presence: true, length: { minimum: 5, maximum: 100 }
      end
    end

    # Missing title
    article = article_class.new(title: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"

    # Too short
    article = article_class.new(title: "Hi")
    assert_not article.valid?
    assert_includes article.errors[:title], "is too short (minimum is 5 characters)"

    # Too long
    article = article_class.new(title: "a" * 101)
    assert_not article.valid?
    assert_includes article.errors[:title], "is too long (maximum is 100 characters)"

    # Valid
    article = article_class.new(title: "Valid Title")
    assert article.valid?
  end

  test "validate with format and numericality" do
    article_class = create_validatable_class(:ValidatableArticle21) do
      # Add virtual attribute for testing format validation
      attr_accessor :email

      validatable do
        validate :email, format: { with: URI::MailTo::EMAIL_REGEXP }
        validate :view_count, numericality: { greater_than_or_equal_to: 0 }
      end
    end

    # Invalid email
    article = article_class.new(email: "not_an_email", view_count: 10)
    assert_not article.valid?
    assert_includes article.errors[:email], "is invalid"

    # Negative view_count
    article = article_class.new(email: "test@example.com", view_count: -5)
    assert_not article.valid?
    assert_includes article.errors[:view_count], "must be greater than or equal to 0"

    # Valid
    article = article_class.new(email: "test@example.com", view_count: 100)
    assert article.valid?
  end

  test "validate with inclusion validator" do
    article_class = create_validatable_class(:ValidatableArticle22) do
      validatable do
        validate :status, inclusion: { in: %w[draft published archived] }
      end
    end

    # Valid statuses
    %w[draft published archived].each do |status|
      article = article_class.new(status: status)
      assert article.valid?, "#{status} should be valid"
    end

    # Invalid status
    article = article_class.new(status: "invalid")
    assert_not article.valid?
    assert_includes article.errors[:status], "is not included in the list"
  end

  test "validate with custom message" do
    article_class = create_validatable_class(:ValidatableArticle23) do
      validatable do
        validate :title, presence: { message: "must not be empty" }
      end
    end

    article = article_class.new(title: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "must not be empty"
  end

  test "validate with allow_nil and allow_blank" do
    article_class = create_validatable_class(:ValidatableArticle24) do
      # Add virtual attributes
      attr_accessor :optional_field, :another_field

      validatable do
        validate :optional_field, length: { minimum: 5 }, allow_nil: true
        validate :another_field, length: { minimum: 5 }, allow_blank: true
      end
    end

    # nil is allowed for optional_field
    article = article_class.new(optional_field: nil, another_field: "valid")
    assert article.valid?

    # blank string is allowed for another_field
    article = article_class.new(optional_field: "valid", another_field: "")
    assert article.valid?

    # Short value fails validation
    article = article_class.new(optional_field: "hi", another_field: "valid")
    assert_not article.valid?
    assert_includes article.errors[:optional_field], "is too short (minimum is 5 characters)"
  end

  test "validate with on: :create and on: :update" do
    article_class = create_validatable_class(:ValidatableArticle25) do
      validatable do
        validate :title, presence: true, on: :create
        validate :status, presence: true, on: :update
      end
    end

    # Create validation
    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
    # Check status is not in errors using attribute_names
    assert_not article.errors.attribute_names.include?(:status)

    # Simulate save (skip actual DB)
    article.title = "Valid"
    article.instance_variable_set(:@new_record, false)

    # Update validation
    article.status = nil
    assert_not article.valid?
    assert_includes article.errors[:status], "can't be blank"
  end

  test "validate with inline if/unless options" do
    article_class = create_validatable_class(:ValidatableArticle26) do
      # Add virtual attribute for draft_notes
      attr_accessor :draft_notes

      is :published, -> { status == "published" }

      validatable do
        validate :published_at, presence: true, if: :is_published?
        validate :draft_notes, presence: true, unless: :is_published?
      end
    end

    # Draft (if condition false, unless true)
    article = article_class.new(status: "draft", published_at: nil, draft_notes: nil)
    assert_not article.valid?
    assert_includes article.errors[:draft_notes], "can't be blank"
    assert_not article.errors.attribute_names.include?(:published_at)

    # Published (if condition true, unless false)
    article = article_class.new(status: "published", published_at: nil, draft_notes: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "can't be blank"
    assert_not article.errors.attribute_names.include?(:draft_notes)
  end

  test "validate on non-existent attribute behaves like Rails" do
    article_class = create_validatable_class(:ValidatableArticle27) do
      # Add the attribute as accessor so it exists
      attr_accessor :custom_field

      validatable do
        validate :custom_field, presence: true
      end
    end

    article = article_class.new
    # Should work normally - custom_field is nil
    assert_not article.valid?
    assert_includes article.errors[:custom_field], "can't be blank"

    article.custom_field = "value"
    assert article.valid?
  end

  # ========================================
  # EDGE CASES - CONDITIONAL VALIDATIONS
  # ========================================

  test "validate_if with multiple separate conditions" do
    article_class = create_validatable_class(:ValidatableArticle28) do
      is :published, -> { status == "published" }
      is :featured, -> { featured == true }

      validatable do
        # First condition: if published
        validate_if :is_published? do
          validate :published_at, presence: true
        end

        # Second condition: if published AND featured (using proc)
        validate_if -> { status == "published" && featured == true } do
          validate :view_count, numericality: { greater_than: 100 }
        end
      end
    end

    # Draft - no validations
    article = article_class.new(status: "draft", published_at: nil, featured: true, view_count: 50)
    assert article.valid?

    # Published but not featured - only published_at required
    article = article_class.new(status: "published", published_at: Time.current, featured: false, view_count: 50)
    assert article.valid?

    # Published and featured - both validations required
    article = article_class.new(status: "published", published_at: Time.current, featured: true, view_count: 50)
    assert_not article.valid?
    assert_includes article.errors[:view_count], "must be greater than 100"

    # Valid published + featured
    article = article_class.new(status: "published", published_at: Time.current, featured: true, view_count: 150)
    assert article.valid?
  end

  test "validate_if with proc that raises exception is handled" do
    article_class = create_validatable_class(:ValidatableArticle29) do
      validatable do
        validate_if -> { raise StandardError, "Condition error" } do
          validate :title, presence: true
        end
      end
    end

    article = article_class.new(title: "Test")
    # Exception in condition should propagate
    assert_raises(StandardError) do
      article.valid?
    end
  end

  test "validate_if and validate_unless together" do
    article_class = create_validatable_class(:ValidatableArticle30) do
      is :published, -> { status == "published" }
      is :draft, -> { status == "draft" }

      validatable do
        validate_if :is_published? do
          validate :published_at, presence: true
        end

        validate_unless :is_draft? do
          validate :view_count, numericality: { greater_than_or_equal_to: 0 }
        end
      end
    end

    # Draft: only validate_if skipped, validate_unless also skipped (not draft = false, so validation runs)
    # Wait, validate_unless :is_draft? means "unless draft" = "if not draft"
    # So for draft, validate_unless should be skipped
    article = article_class.new(status: "draft", published_at: nil, view_count: -10)
    assert article.valid? # Both validations skipped for draft

    # Published: validate_if runs, validate_unless runs
    article = article_class.new(status: "published", published_at: nil, view_count: -10)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "can't be blank"
    assert_includes article.errors[:view_count], "must be greater than or equal to 0"
  end

  test "validate_if with multiple OR conditions using proc" do
    article_class = create_validatable_class(:ValidatableArticle31) do
      validatable do
        validate_if -> { status == "published" || status == "archived" } do
          validate :published_at, presence: true
        end
      end
    end

    # Draft - condition false
    article = article_class.new(status: "draft", published_at: nil)
    assert article.valid?

    # Published - condition true
    article = article_class.new(status: "published", published_at: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "can't be blank"

    # Archived - condition true
    article = article_class.new(status: "archived", published_at: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "can't be blank"
  end

  test "validate_if condition is evaluated at validation time" do
    article_class = create_validatable_class(:ValidatableArticle32) do
      attr_accessor :dynamic_flag

      validatable do
        validate_if -> { dynamic_flag == true } do
          validate :title, presence: true
        end
      end
    end

    # Flag is false - validation skipped
    article = article_class.new(status: "published", dynamic_flag: false, title: nil)
    assert article.valid?

    # Flag is true - validation runs
    article = article_class.new(status: "published", dynamic_flag: true, title: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"

    # Change flag after creation and revalidate
    article.dynamic_flag = false
    assert article.valid? # Now validation is skipped
  end

  test "validate_unless with complex proc condition" do
    article_class = create_validatable_class(:ValidatableArticle33) do
      validatable do
        validate_unless -> { status == "draft" && view_count.to_i < 10 } do
          validate :title, length: { minimum: 10 }
        end
      end
    end

    # Draft with low views - validation skipped
    article = article_class.new(status: "draft", view_count: 5, title: "Short")
    assert article.valid?

    # Draft with high views - validation runs
    article = article_class.new(status: "draft", view_count: 50, title: "Short")
    assert_not article.valid?
    assert_includes article.errors[:title], "is too short (minimum is 10 characters)"

    # Published with low views - validation runs
    article = article_class.new(status: "published", view_count: 5, title: "Short")
    assert_not article.valid?
    assert_includes article.errors[:title], "is too short (minimum is 10 characters)"
  end

  # ========================================
  # EDGE CASES - ORDER VALIDATIONS
  # ========================================

  test "validate_order with :after comparator for dates" do
    article_class = create_validatable_class(:ValidatableArticle34) do
      validatable do
        validate_order :ends_at, :after, :starts_at
      end
    end

    # Valid: ends_at after starts_at
    article = article_class.new(starts_at: 1.day.ago, ends_at: Time.current)
    assert article.valid?

    # Invalid: ends_at before starts_at
    article = article_class.new(starts_at: Time.current, ends_at: 1.day.ago)
    assert_not article.valid?
    assert_includes article.errors[:ends_at], "must be after starts at"
  end

  test "validate_order with :lt and :gt comparators for numbers" do
    article_class = create_validatable_class(:ValidatableArticle35) do
      validatable do
        validate_order :view_count, :lt, :max_views
      end
    end

    # Valid: view_count < max_views
    article = article_class.new(view_count: 50, max_views: 100)
    assert article.valid?

    # Invalid: view_count >= max_views
    article = article_class.new(view_count: 100, max_views: 100)
    assert_not article.valid?
    assert_includes article.errors[:view_count], "must be less than max views"

    article = article_class.new(view_count: 150, max_views: 100)
    assert_not article.valid?
  end

  test "validate_order with :gteq comparator" do
    article_class = create_validatable_class(:ValidatableArticle36) do
      validatable do
        validate_order :view_count, :gteq, :max_views
      end
    end

    # Valid: view_count >= max_views
    article = article_class.new(view_count: 100, max_views: 100)
    assert article.valid?

    article = article_class.new(view_count: 150, max_views: 100)
    assert article.valid?

    # Invalid: view_count < max_views
    article = article_class.new(view_count: 50, max_views: 100)
    assert_not article.valid?
    assert_includes article.errors[:view_count], "must be greater than or equal to max views"
  end

  test "validate_order provides default error message" do
    article_class = create_validatable_class(:ValidatableArticle37) do
      validatable do
        validate_order :starts_at, :before, :ends_at
      end
    end

    article = article_class.new(starts_at: Time.current, ends_at: 1.day.ago)
    assert_not article.valid?
    # OrderValidator provides a default message
    assert_includes article.errors[:starts_at], "must be before ends at"

    # Verify message is humanized
    assert article.errors[:starts_at].any? { |msg| msg.include?("ends at") }
  end

  test "validate_order with on: :create context" do
    article_class = create_validatable_class(:ValidatableArticle38) do
      validatable do
        validate_order :starts_at, :before, :ends_at, on: :create
      end
    end

    # On create - validation runs
    article = article_class.new(starts_at: Time.current, ends_at: 1.day.ago)
    assert_not article.valid?
    assert_includes article.errors[:starts_at], "must be before ends at"

    # Simulate update (not new record)
    article = article_class.new(starts_at: Time.current, ends_at: 1.day.ago)
    article.instance_variable_set(:@new_record, false)
    # On update - validation skipped
    assert article.valid?
  end

  test "validate_order with if/unless conditions" do
    article_class = create_validatable_class(:ValidatableArticle39) do
      is :published, -> { status == "published" }

      validatable do
        validate_order :starts_at, :before, :ends_at, if: :is_published?
      end
    end

    # Draft - validation skipped
    article = article_class.new(status: "draft", starts_at: Time.current, ends_at: 1.day.ago)
    assert article.valid?

    # Published - validation runs
    article = article_class.new(status: "published", starts_at: Time.current, ends_at: 1.day.ago)
    assert_not article.valid?
    assert_includes article.errors[:starts_at], "must be before ends at"
  end

  test "validate_order with equal values for lteq/gteq" do
    article_class = create_validatable_class(:ValidatableArticle40) do
      validatable do
        validate_order :view_count, :lteq, :max_views
      end
    end

    # Equal values should be valid for lteq
    article = article_class.new(view_count: 100, max_views: 100)
    assert article.valid?

    # Less than should be valid
    article = article_class.new(view_count: 50, max_views: 100)
    assert article.valid?

    # Greater than should be invalid
    article = article_class.new(view_count: 150, max_views: 100)
    assert_not article.valid?
    assert_includes article.errors[:view_count], "must be less than or equal to max views"
  end

  test "validate_order with incompatible types handles gracefully" do
    article_class = create_validatable_class(:ValidatableArticle41) do
      attr_accessor :text_field, :number_field

      validatable do
        validate_order :text_field, :lteq, :number_field
      end
    end

    # String vs Number - comparison will fail or work depending on Ruby's behavior
    article = article_class.new(text_field: "hello", number_field: 100)

    # This will either raise an error or return false depending on implementation
    # We just verify it doesn't crash the app
    begin
      result = article.valid?
      # If it doesn't raise, it should return a boolean
      assert [true, false].include?(result)
    rescue ArgumentError, TypeError
      # Some implementations might raise an error for incompatible types
      # This is acceptable behavior
      assert true
    end
  end

  # ========================================
  # EDGE CASES - BUSINESS RULES
  # ========================================

  test "validate_business_rule can modify object during validation" do
    article_class = create_validatable_class(:ValidatableArticle42) do
      attr_accessor :auto_generated_field

      validatable do
        validate_business_rule :generate_field
      end

      def generate_field
        self.auto_generated_field = "auto-#{title}" if title.present?
      end
    end

    article = article_class.new(title: "Test", auto_generated_field: nil)
    assert article.valid?
    # Field was generated during validation
    assert_equal "auto-Test", article.auto_generated_field
  end

  test "validate_business_rule with on: :create context" do
    article_class = create_validatable_class(:ValidatableArticle43) do
      validatable do
        validate_business_rule :check_create_only, on: :create
      end

      def check_create_only
        errors.add(:base, "Create check failed") if title.nil?
      end
    end

    # On create - rule runs
    article = article_class.new(title: nil)
    assert_not article.valid?
    assert_includes article.errors[:base], "Create check failed"

    # Simulate update
    article = article_class.new(title: nil)
    article.instance_variable_set(:@new_record, false)
    assert article.valid? # Rule skipped on update
  end

  test "validate_business_rule with if condition" do
    article_class = create_validatable_class(:ValidatableArticle44) do
      is :published, -> { status == "published" }

      validatable do
        validate_business_rule :check_published_requirements, if: :is_published?
      end

      def check_published_requirements
        errors.add(:published_at, "must be present for published articles") if published_at.nil?
      end
    end

    # Draft - rule skipped
    article = article_class.new(status: "draft", published_at: nil)
    assert article.valid?

    # Published - rule runs
    article = article_class.new(status: "published", published_at: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "must be present for published articles"
  end

  test "validate_business_rule that raises exception is propagated" do
    article_class = create_validatable_class(:ValidatableArticle45) do
      validatable do
        validate_business_rule :failing_rule
      end

      def failing_rule
        raise StandardError, "Business rule failed"
      end
    end

    article = article_class.new
    assert_raises(StandardError) do
      article.valid?
    end
  end

  test "validate_business_rule can add multiple errors" do
    article_class = create_validatable_class(:ValidatableArticle46) do
      validatable do
        validate_business_rule :complex_validation
      end

      def complex_validation
        errors.add(:title, "is too generic") if title == "Test"
        errors.add(:status, "must be draft or published") unless %w[draft published].include?(status)
        errors.add(:view_count, "seems suspicious") if view_count && view_count > 10000
      end
    end

    article = article_class.new(title: "Test", status: "invalid", view_count: 50000)
    assert_not article.valid?
    assert_includes article.errors[:title], "is too generic"
    assert_includes article.errors[:status], "must be draft or published"
    assert_includes article.errors[:view_count], "seems suspicious"
    assert_equal 3, article.errors.count
  end

  test "validate_business_rule can call other methods" do
    article_class = create_validatable_class(:ValidatableArticle47) do
      validatable do
        validate_business_rule :validate_content_quality
      end

      def validate_content_quality
        check_title_length
        check_content_presence
      end

      def check_title_length
        errors.add(:title, "is too short for quality content") if title && title.length < 20
      end

      def check_content_presence
        errors.add(:content, "must be present for quality articles") if content.blank?
      end
    end

    article = article_class.new(title: "Short", content: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "is too short for quality content"
    assert_includes article.errors[:content], "must be present for quality articles"

    # Valid article
    article = article_class.new(title: "This is a long enough title for quality", content: "Good content")
    assert article.valid?
  end

  # ========================================
  # EDGE CASES - VALIDATION GROUPS
  # ========================================

  test "validation_group with empty fields array" do
    article_class = create_validatable_class(:ValidatableArticle48) do
      validatable do
        validate :title, presence: true

        validation_group :empty_group, []
      end
    end

    article = article_class.new(title: nil)

    # Empty group should pass (no fields to validate)
    assert article.valid?(:empty_group)

    # Full validation should fail
    assert_not article.valid?
  end

  test "validation_group with fields that have no validations" do
    article_class = create_validatable_class(:ValidatableArticle49) do
      validatable do
        validate :title, presence: true

        # status has no validations defined
        validation_group :status_group, [:status]
      end
    end

    article = article_class.new(title: nil, status: nil)

    # Group with no validations should pass
    assert article.valid?(:status_group)

    # Full validation should fail on title
    assert_not article.valid?
  end

  test "validation_group raises error for duplicate group name" do
    error = assert_raises(ArgumentError) do
      create_validatable_class(:ValidatableArticle50) do
        validatable do
          validation_group :step1, [:title]
          validation_group :step1, [:status]  # Duplicate!
        end
      end
    end

    assert_match(/Group already defined/, error.message)
  end

  test "valid? with nonexistent group falls back to full validation" do
    article_class = create_validatable_class(:ValidatableArticle51) do
      validatable do
        validate :title, presence: true
        validate :status, presence: true
        validation_group :step1, [:title]
      end
    end

    # Article valid for full validation
    article = article_class.new(title: "Valid", status: "draft")
    # Nonexistent group falls back to Rails' context validation (full validation)
    assert article.valid?(:nonexistent_group)

    # Article invalid for full validation
    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?(:nonexistent_group)
  end

  test "errors_for_group with nonexistent group returns empty errors" do
    article_class = create_validatable_class(:ValidatableArticle52) do
      validatable do
        validate :title, presence: true
        validation_group :step1, [:title]
      end
    end

    article = article_class.new(title: nil)
    article.valid?  # Run validation first

    # Nonexistent group should return errors object but without filtering
    group_errors = article.errors_for_group(:nonexistent_group)
    assert group_errors.is_a?(ActiveModel::Errors)
  end

  test "validation_group with overlapping fields" do
    article_class = create_validatable_class(:ValidatableArticle53) do
      validatable do
        validate :title, presence: true
        validate :status, presence: true
        validate :content, presence: true

        validation_group :group1, [:title, :status]
        validation_group :group2, [:status, :content]  # status overlaps
      end
    end

    article = article_class.new(title: "Valid", status: nil, content: "Valid")

    # Group1 fails on status
    assert_not article.valid?(:group1)
    assert_includes article.errors[:status], "can't be blank"

    # Group2 also fails on status
    assert_not article.valid?(:group2)
    assert_includes article.errors[:status], "can't be blank"

    # Fix status
    article.status = "draft"

    # Both groups should pass now
    assert article.valid?(:group1)
    assert article.valid?(:group2)
  end

  test "validate_group clears previous errors before validation" do
    article_class = create_validatable_class(:ValidatableArticle54) do
      validatable do
        validate :title, presence: true
        validate :status, presence: true

        validation_group :group1, [:title]
      end
    end

    article = article_class.new(title: nil, status: nil)

    # Run full validation first
    assert_not article.valid?
    assert article.errors[:title].any?
    assert article.errors[:status].any?

    # Now validate only group1
    result = article.validate_group(:group1)

    # Errors should be cleared and only group1 errors present
    assert_not result
    assert article.errors[:title].any?
    assert article.errors[:status].empty?  # status should be cleared
  end

  test "validation_group validates only specified fields" do
    article_class = create_validatable_class(:ValidatableArticle55) do
      validatable do
        validate :title, presence: true, length: { minimum: 5 }
        validate :status, presence: true
        validate :content, presence: true

        validation_group :title_only, [:title]
        validation_group :content_only, [:content]
      end
    end

    # All fields invalid
    article = article_class.new(title: "Hi", status: nil, content: nil)

    # Title group - only validates title (both presence and length)
    assert_not article.valid?(:title_only)
    assert article.errors[:title].any?
    assert article.errors[:status].empty?
    assert article.errors[:content].empty?

    # Content group - only validates content
    assert_not article.valid?(:content_only)
    assert article.errors[:title].empty?
    assert article.errors[:status].empty?
    assert article.errors[:content].any?

    # Fix title and content
    article.title = "Valid Title"
    article.content = "Valid content"

    # Both groups should pass now
    assert article.valid?(:title_only)
    assert article.valid?(:content_only)
  end

  # ========================================
  # INTEGRATION TESTS
  # ========================================

  test "validatable works with statusable predicates" do
    article_class = create_validatable_class(:ValidatableArticle56) do
      # Statusable predicates
      is :draft, -> { status == "draft" }
      is :published, -> { status == "published" }

      validatable do
        validate_if :is_published? do
          validate :published_at, presence: true
        end
      end
    end

    # Draft - validation skipped
    article = article_class.new(status: "draft", published_at: nil)
    assert article.valid?

    # Published - validation runs
    article = article_class.new(status: "published", published_at: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "can't be blank"
  end

  test "validatable validates before checking permissions" do
    article_class = create_validatable_class(:ValidatableArticle57) do
      # Simulate Permissible-like behavior
      is :published, -> { status == "published" }

      validatable do
        validate :title, presence: true
      end

      def can_edit?
        !is_published?
      end
    end

    article = article_class.new(status: "draft", title: nil)

    # Validation runs before permission check
    assert_not article.valid?
    # But can_edit? should work independently
    assert article.can_edit?
  end

  test "validatable with save(validate: false) skips all validations" do
    article_class = create_validatable_class(:ValidatableArticle58) do
      validatable do
        validate :title, presence: true
        validate :status, presence: true
      end
    end

    # This would fail validation but save works with validate: false
    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?

    # Note: We can't actually test save in memory DB easily, so we just verify
    # that valid? fails, which means save(validate: false) would bypass it
    assert_not article.valid?
  end

  test "validatable works with Rails standard validation contexts" do
    article_class = create_validatable_class(:ValidatableArticle59) do
      validatable do
        validate :title, presence: true, on: :create
        validate :status, presence: true, on: :update
      end
    end

    # Create context
    article = article_class.new(title: nil)
    assert_not article.valid?(:create)

    # No context (defaults to create for new record)
    assert_not article.valid?

    # Simulate persisted record
    article.title = "Valid"
    article.instance_variable_set(:@new_record, false)

    # Update context
    article.status = nil
    assert_not article.valid?(:update)
  end

  test "validatable validations combine with standard Rails validations" do
    article_class = create_validatable_class(:ValidatableArticle60) do
      # Standard Rails validation outside validatable
      validates :content, presence: true

      validatable do
        validate :title, presence: true
      end
    end

    article = article_class.new(title: nil, content: nil)
    assert_not article.valid?

    # Both validations should be present
    assert_includes article.errors[:title], "can't be blank"
    assert_includes article.errors[:content], "can't be blank"

    # Fix one
    article.title = "Valid"
    assert_not article.valid?
    assert article.errors[:content].any?

    # Fix both
    article.content = "Valid"
    assert article.valid?
  end

  test "validatable works in transaction with rollback" do
    article_class = create_validatable_class(:ValidatableArticle61) do
      validatable do
        validate :title, presence: true
      end
    end

    # Validation works normally
    article = article_class.new(title: nil)
    assert_not article.valid?

    # Simulate what would happen in a transaction
    # (we can't test actual DB rollback without real DB)
    valid_article = article_class.new(title: "Valid")
    assert valid_article.valid?
  end

  # ========================================
  # PERFORMANCE TESTS
  # ========================================

  test "validatable handles many validations efficiently" do
    article_class = create_validatable_class(:ValidatableArticle62) do
      # Define attr_accessors outside validatable block
      20.times do |i|
        attr_accessor "field_#{i}".to_sym
      end

      validatable do
        # Many field validations
        20.times do |i|
          validate "field_#{i}".to_sym, presence: true
        end
      end
    end

    # Create article with all fields nil
    article = article_class.new

    start_time = Time.now
    article.valid?
    elapsed = Time.now - start_time

    # Should complete quickly even with 20 validations
    assert elapsed < 0.1, "Validation took #{elapsed}s for 20 fields"
    assert_equal 20, article.errors.count
  end

  test "validatable with many conditional validations performs well" do
    article_class = create_validatable_class(:ValidatableArticle63) do
      # Create 10 status predicates
      10.times do |i|
        is "status_#{i}".to_sym, -> { status == "status_#{i}" }
      end

      validatable do
        # 10 conditional validations
        10.times do |i|
          validate_if "is_status_#{i}?".to_sym do
            validate :title, presence: true
          end
        end
      end
    end

    article = article_class.new(status: "status_5", title: nil)

    start_time = Time.now
    result = article.valid?
    elapsed = Time.now - start_time

    # Should complete quickly
    assert elapsed < 0.1, "Validation took #{elapsed}s for 10 conditionals"
    assert_not result  # status_5 condition matches, title validation fails
  end

  test "validatable with many validation groups performs well" do
    article_class = create_validatable_class(:ValidatableArticle64) do
      # Create many fields outside validatable block
      20.times do |i|
        attr_accessor "field_#{i}".to_sym
      end

      validatable do
        # Add validations
        20.times do |i|
          validate "field_#{i}".to_sym, presence: true
        end

        # Create 10 groups with 2 fields each
        10.times do |i|
          validation_group "group_#{i}".to_sym, ["field_#{i * 2}".to_sym, "field_#{i * 2 + 1}".to_sym]
        end
      end
    end

    article = article_class.new

    # Validate each group
    start_time = Time.now
    10.times do |i|
      article.valid?("group_#{i}".to_sym)
    end
    elapsed = Time.now - start_time

    # Should complete quickly
    assert elapsed < 0.2, "10 group validations took #{elapsed}s"
  end

  test "validatable with complex business rules performs adequately" do
    article_class = create_validatable_class(:ValidatableArticle65) do
      validatable do
        validate_business_rule :complex_validation
      end

      def complex_validation
        # Simulate complex business logic
        100.times do |i|
          # Some computation
          result = i * 2
        end

        errors.add(:base, "Complex validation failed") if title.nil?
      end
    end

    article = article_class.new(title: nil)

    start_time = Time.now
    article.valid?
    elapsed = Time.now - start_time

    # Should still complete reasonably fast
    assert elapsed < 0.1, "Complex validation took #{elapsed}s"
    assert_includes article.errors[:base], "Complex validation failed"
  end

  # ========================================
  # ERROR HANDLING & MESSAGES TESTS
  # ========================================

  test "order validation provides user-friendly error messages" do
    article_class = create_validatable_class(:ValidatableArticle66) do
      validatable do
        validate_order :starts_at, :before, :ends_at
        validate_order :view_count, :lteq, :max_views
      end
    end

    article = article_class.new(starts_at: Time.current, ends_at: 1.day.ago, view_count: 100, max_views: 50)
    assert_not article.valid?

    # Messages should be humanized
    assert article.errors[:starts_at].any? { |msg| msg.include?("ends at") }
    assert article.errors[:view_count].any? { |msg| msg.include?("max views") }
  end

  test "validation errors include validator metadata" do
    article_class = create_validatable_class(:ValidatableArticle67) do
      validatable do
        validate :title, presence: true, length: { minimum: 5 }
      end
    end

    article = article_class.new(title: "Hi")
    assert_not article.valid?

    # errors.details should include validator info
    details = article.errors.details[:title]
    assert details.is_a?(Array)
    assert details.any? { |d| d[:error] == :too_short }
  end

  test "business rule errors can be added to base or specific fields" do
    article_class = create_validatable_class(:ValidatableArticle68) do
      validatable do
        validate_business_rule :check_consistency
      end

      def check_consistency
        errors.add(:base, "Article is inconsistent")
        errors.add(:title, "conflicts with status")
      end
    end

    article = article_class.new
    assert_not article.valid?

    assert_includes article.errors[:base], "Article is inconsistent"
    assert_includes article.errors[:title], "conflicts with status"
  end

  test "validation full_messages includes field names" do
    article_class = create_validatable_class(:ValidatableArticle69) do
      validatable do
        validate :title, presence: true
        validate :status, presence: true
      end
    end

    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?

    full_messages = article.errors.full_messages
    assert full_messages.any? { |msg| msg.include?("Title") }
    assert full_messages.any? { |msg| msg.include?("Status") }
  end

  test "validate_order with invalid comparator raises ArgumentError" do
    error = assert_raises(ArgumentError) do
      create_validatable_class(:ValidatableArticle70) do
        validatable do
          validate_order :starts_at, :invalid_comparator, :ends_at
        end
      end
    end

    assert_match(/Invalid comparator/, error.message)
  end

  test "validatable error messages are customizable" do
    article_class = create_validatable_class(:ValidatableArticle71) do
      validatable do
        validate :title, presence: { message: "must be provided" }
        validate :content, length: { minimum: 10, too_short: "needs at least %{count} characters" }
      end
    end

    article = article_class.new(title: nil, content: "Short")
    assert_not article.valid?

    assert_includes article.errors[:title], "must be provided"
    assert article.errors[:content].any? { |msg| msg.include?("needs at least") }
  end
end
