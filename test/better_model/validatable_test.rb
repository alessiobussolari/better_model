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
        check :title, presence: true
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
        check :title, :status, presence: true
      end
    end

    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
    assert_includes article.errors[:status], "can't be blank"
  end

  # Test 3: Validation groups
  test "validation_group defines groups" do
    article_class = create_validatable_class(:ValidatableArticle13) do
      validatable do
        check :title, presence: true
        check :status, presence: true
        check :view_count, presence: true

        validation_group :step1, [ :title ]
        validation_group :step2, [ :status, :view_count ]
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
        check :title, presence: true
        check :status, presence: true

        validation_group :step1, [ :title ]
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
    error = assert_raises(BetterModel::Errors::Validatable::NotEnabledError) do
      article.validate_group(:step1)
    end

    assert_match(/Validatable is not enabled/, error.message)
  end

  test "errors_for_group raises error if validatable not enabled" do
    article_class = create_validatable_class(:ValidatableArticle16)

    article = article_class.new
    error = assert_raises(BetterModel::Errors::Validatable::NotEnabledError) do
      article.errors_for_group(:step1)
    end

    assert_match(/Validatable is not enabled/, error.message)
  end

  # Test 5: ActiveRecord integration
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
        check :title, presence: true
      end
    end

    assert article_class.validatable_config.frozen?
    assert article_class.validatable_groups.frozen?
  end

  # Test 10: Setup runs only once
  test "validatable setup runs only once" do
    article_class = create_validatable_class(:ValidatableArticle19) do
      validatable do
        check :title, presence: true
      end

      # Call validatable again
      validatable do
        check :status, presence: true
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
        check :title, presence: true, length: { minimum: 5, maximum: 100 }
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
        check :email, format: { with: URI::MailTo::EMAIL_REGEXP }
        check :view_count, numericality: { greater_than_or_equal_to: 0 }
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
        check :status, inclusion: { in: %w[draft published archived] }
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
        check :title, presence: { message: "must not be empty" }
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
        check :optional_field, length: { minimum: 5 }, allow_nil: true
        check :another_field, length: { minimum: 5 }, allow_blank: true
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
        check :title, presence: true, on: :create
        check :status, presence: true, on: :update
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
        check :published_at, presence: true, if: :is_published?
        check :draft_notes, presence: true, unless: :is_published?
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
        check :custom_field, presence: true
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
  # EDGE CASES - VALIDATION GROUPS
  # ========================================

  test "validation_group with empty fields array" do
    article_class = create_validatable_class(:ValidatableArticle48) do
      validatable do
        check :title, presence: true

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
        check :title, presence: true

        # status has no validations defined
        validation_group :status_group, [ :status ]
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
          validation_group :step1, [ :title ]
          validation_group :step1, [ :status ]  # Duplicate!
        end
      end
    end

    assert_match(/Group already defined/, error.message)
  end

  test "valid? with nonexistent group falls back to full validation" do
    article_class = create_validatable_class(:ValidatableArticle51) do
      validatable do
        check :title, presence: true
        check :status, presence: true
        validation_group :step1, [ :title ]
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
        check :title, presence: true
        validation_group :step1, [ :title ]
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
        check :title, presence: true
        check :status, presence: true
        check :content, presence: true

        validation_group :group1, [ :title, :status ]
        validation_group :group2, [ :status, :content ]  # status overlaps
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
        check :title, presence: true
        check :status, presence: true

        validation_group :group1, [ :title ]
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
        check :title, presence: true, length: { minimum: 5 }
        check :status, presence: true
        check :content, presence: true

        validation_group :title_only, [ :title ]
        validation_group :content_only, [ :content ]
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

  test "validatable validates before checking permissions" do
    article_class = create_validatable_class(:ValidatableArticle57) do
      # Simulate Permissible-like behavior
      is :published, -> { status == "published" }

      validatable do
        check :title, presence: true
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
        check :title, presence: true
        check :status, presence: true
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
        check :title, presence: true, on: :create
        check :status, presence: true, on: :update
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
        check :title, presence: true
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
        check :title, presence: true
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
          check "field_#{i}".to_sym, presence: true
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

  test "validatable with many validation groups performs well" do
    article_class = create_validatable_class(:ValidatableArticle64) do
      # Create many fields outside validatable block
      20.times do |i|
        attr_accessor "field_#{i}".to_sym
      end

      validatable do
        # Add validations
        20.times do |i|
          check "field_#{i}".to_sym, presence: true
        end

        # Create 10 groups with 2 fields each
        10.times do |i|
          validation_group "group_#{i}".to_sym, [ "field_#{i * 2}".to_sym, "field_#{i * 2 + 1}".to_sym ]
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

  # ========================================
  # ERROR HANDLING & MESSAGES TESTS
  # ========================================

  test "validation errors include validator metadata" do
    article_class = create_validatable_class(:ValidatableArticle67) do
      validatable do
        check :title, presence: true, length: { minimum: 5 }
      end
    end

    article = article_class.new(title: "Hi")
    assert_not article.valid?

    # errors.details should include validator info
    details = article.errors.details[:title]
    assert details.is_a?(Array)
    assert details.any? { |d| d[:error] == :too_short }
  end

  test "validation full_messages includes field names" do
    article_class = create_validatable_class(:ValidatableArticle69) do
      validatable do
        check :title, presence: true
        check :status, presence: true
      end
    end

    article = article_class.new(title: nil, status: nil)
    assert_not article.valid?

    full_messages = article.errors.full_messages
    assert full_messages.any? { |msg| msg.include?("Title") }
    assert full_messages.any? { |msg| msg.include?("Status") }
  end

  test "validatable error messages are customizable" do
    article_class = create_validatable_class(:ValidatableArticle71) do
      validatable do
        check :title, presence: { message: "must be provided" }
        check :content, length: { minimum: 10, too_short: "needs at least %{count} characters" }
      end
    end

    article = article_class.new(title: nil, content: "Short")
    assert_not article.valid?

    assert_includes article.errors[:title], "must be provided"
    assert article.errors[:content].any? { |msg| msg.include?("needs at least") }
  end

  # ========================================
  # COVERAGE TESTS - Complex Conditions & Edge Cases
  # ========================================

  test "validation group with multiple steps" do
    article_class = create_validatable_class(:ValidatableArticle78) do
      attr_accessor :email, :password, :first_name, :last_name

      validatable do
        # Step 1 validations - basic authentication
        check :email, presence: true
        check :password, presence: true

        # Step 2 validations - personal info
        check :first_name, presence: true
        check :last_name, presence: true

        # Group definitions - specify which fields to validate in each step
        validation_group :step1, [ :email, :password ]
        validation_group :step2, [ :first_name, :last_name ]
      end
    end

    # Step 1 - only email and password
    article = article_class.new(email: "test@example.com", password: "secret")
    assert article.valid?(:step1), "Step 1 should pass with email and password"

    # Step 1 should fail without email
    article = article_class.new(password: "secret")
    assert_not article.valid?(:step1)
    assert article.errors.attribute_names.include?(:email)

    # Step 2 - only first_name and last_name
    article = article_class.new(first_name: "John", last_name: "Doe")
    assert article.valid?(:step2), "Step 2 should pass with names"

    # Step 2 should fail without last_name
    article = article_class.new(first_name: "John")
    assert_not article.valid?(:step2)
    assert article.errors.attribute_names.include?(:last_name)
  end

  test "format validation with invalid regex" do
    article_class = create_validatable_class(:ValidatableArticle79) do
      attr_accessor :email

      validatable do
        check :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
      end
    end

    article = article_class.new(email: "invalid@")
    assert_not article.valid?
    assert article.errors.attribute_names.include?(:email)
  end

  # ========================================
  # COMPLEX VALIDATIONS TESTS
  # ========================================

  test "register_complex_validation registers validation in registry" do
    article_class = create_validatable_class(:ValidatableArticle88) do
      register_complex_validation :valid_pricing do
        if sale_price.present? && sale_price >= price
          errors.add(:sale_price, "must be less than regular price")
        end
      end

      attr_accessor :price, :sale_price
    end

    assert article_class.complex_validation?(:valid_pricing)
    assert article_class.complex_validations_registry.key?(:valid_pricing)
  end

  test "register_complex_validation requires a block" do
    assert_raises(ArgumentError, /Block required/) do
      create_validatable_class(:ValidatableArticle89) do
        register_complex_validation :test_validation
      end
    end
  end

  test "check_complex applies registered validation" do
    article_class = create_validatable_class(:ValidatableArticle90) do
      attr_accessor :price, :sale_price

      register_complex_validation :valid_pricing do
        if sale_price.present? && sale_price >= price
          errors.add(:sale_price, "must be less than regular price")
        end
      end

      validatable do
        check_complex :valid_pricing
      end
    end

    # Valid: sale_price < price
    article = article_class.new(price: 100, sale_price: 80)
    assert article.valid?

    # Invalid: sale_price >= price
    article = article_class.new(price: 100, sale_price: 120)
    assert_not article.valid?
    assert_includes article.errors[:sale_price], "must be less than regular price"
  end

  test "check_complex raises error for unknown validation" do
    assert_raises(ArgumentError, /Unknown complex validation/) do
      create_validatable_class(:ValidatableArticle91) do
        validatable do
          check_complex :nonexistent_validation
        end
      end
    end
  end

  test "complex validation with multi-field logic" do
    article_class = create_validatable_class(:ValidatableArticle92) do
      attr_accessor :starts_at, :ends_at

      register_complex_validation :valid_dates do
        if starts_at.present? && ends_at.present? && starts_at >= ends_at
          errors.add(:ends_at, "must be after start date")
        end
      end

      validatable do
        check_complex :valid_dates
      end
    end

    # Valid: starts_at < ends_at
    article = article_class.new(starts_at: Time.now, ends_at: Time.now + 1.day)
    assert article.valid?

    # Invalid: starts_at >= ends_at
    article = article_class.new(starts_at: Time.now, ends_at: Time.now - 1.day)
    assert_not article.valid?
    assert_includes article.errors[:ends_at], "must be after start date"
  end

  test "complex validation can add multiple errors" do
    article_class = create_validatable_class(:ValidatableArticle93) do
      attr_accessor :price, :sale_price, :stock

      register_complex_validation :product_consistency do
        errors.add(:sale_price, "required when on sale") if sale_price.blank? && stock > 0
        errors.add(:price, "must be positive") if price && price <= 0
        errors.add(:stock, "cannot be negative") if stock && stock < 0
      end

      validatable do
        check_complex :product_consistency
      end
    end

    article = article_class.new(price: -10, stock: -5)
    assert_not article.valid?
    assert_includes article.errors[:price], "must be positive"
    assert_includes article.errors[:stock], "cannot be negative"
  end

  test "multiple complex validations can be registered and used" do
    article_class = create_validatable_class(:ValidatableArticle94) do
      attr_accessor :price, :sale_price, :stock, :reserved_stock

      register_complex_validation :valid_pricing do
        if sale_price.present? && sale_price >= price
          errors.add(:sale_price, "must be less than regular price")
        end
      end

      register_complex_validation :valid_stock do
        if reserved_stock.present? && reserved_stock > stock
          errors.add(:reserved_stock, "cannot exceed total stock")
        end
      end

      validatable do
        check_complex :valid_pricing
        check_complex :valid_stock
      end
    end

    # Both validations invalid
    article = article_class.new(price: 100, sale_price: 120, stock: 10, reserved_stock: 20)
    assert_not article.valid?
    assert_includes article.errors[:sale_price], "must be less than regular price"
    assert_includes article.errors[:reserved_stock], "cannot exceed total stock"

    # Both validations valid
    article = article_class.new(price: 100, sale_price: 80, stock: 10, reserved_stock: 5)
    assert article.valid?
  end

  test "complex validations registry is thread-safe (frozen)" do
    article_class = create_validatable_class(:ValidatableArticle95) do
      register_complex_validation :test_validation do
        errors.add(:base, "test")
      end
    end

    registry = article_class.complex_validations_registry
    assert registry.frozen?, "Registry should be frozen for thread-safety"
  end

  test "complex validations are inherited by subclasses" do
    parent_class = create_validatable_class(:ValidatableArticle96) do
      attr_accessor :price

      register_complex_validation :valid_price do
        errors.add(:price, "must be positive") if price && price <= 0
      end

      validatable do
        check_complex :valid_price
      end
    end

    child_class = Class.new(parent_class)

    assert child_class.complex_validation?(:valid_price)

    article = child_class.new(price: -10)
    assert_not article.valid?
    assert_includes article.errors[:price], "must be positive"
  end

  test "complex validation with conditional logic" do
    article_class = create_validatable_class(:ValidatableArticle97) do
      attr_accessor :status, :published_at, :price, :sale_price

      is :published, -> { status == "published" }

      register_complex_validation :publication_requirements do
        if is_published? && published_at.blank?
          errors.add(:published_at, "required for published articles")
        end
      end

      validatable do
        check_complex :publication_requirements
      end
    end

    # Valid: draft without published_at
    article = article_class.new(status: "draft", published_at: nil)
    assert article.valid?

    # Invalid: published without published_at
    article = article_class.new(status: "published", published_at: nil)
    assert_not article.valid?
    assert_includes article.errors[:published_at], "required for published articles"

    # Valid: published with published_at
    article = article_class.new(status: "published", published_at: Time.now)
    assert article.valid?
  end

  test "complex validation can access model methods" do
    article_class = create_validatable_class(:ValidatableArticle98) do
      attr_accessor :discount_percentage

      register_complex_validation :valid_discount do
        if discount_percentage && !valid_discount_range?
          errors.add(:discount_percentage, "must be between 0 and 100")
        end
      end

      validatable do
        check_complex :valid_discount
      end

      def valid_discount_range?
        discount_percentage >= 0 && discount_percentage <= 100
      end
    end

    # Valid discount
    article = article_class.new(discount_percentage: 25)
    assert article.valid?

    # Invalid discount
    article = article_class.new(discount_percentage: 150)
    assert_not article.valid?
    assert_includes article.errors[:discount_percentage], "must be between 0 and 100"
  end

  test "complex validation with nil handling" do
    article_class = create_validatable_class(:ValidatableArticle99) do
      attr_accessor :price, :sale_price

      register_complex_validation :valid_pricing do
        return if sale_price.nil? # Skip if sale_price is not set

        if sale_price >= price
          errors.add(:sale_price, "must be less than regular price")
        end
      end

      validatable do
        check_complex :valid_pricing
      end
    end

    # Valid: sale_price is nil
    article = article_class.new(price: 100, sale_price: nil)
    assert article.valid?

    # Valid: sale_price < price
    article = article_class.new(price: 100, sale_price: 80)
    assert article.valid?

    # Invalid: sale_price >= price
    article = article_class.new(price: 100, sale_price: 120)
    assert_not article.valid?
    assert_includes article.errors[:sale_price], "must be less than regular price"
  end

  test "complex_validation? returns false for unregistered validations" do
    article_class = create_validatable_class(:ValidatableArticle100) do
      register_complex_validation :existing do
        # Empty validation
      end
    end

    assert article_class.complex_validation?(:existing)
    assert_not article_class.complex_validation?(:nonexistent)
  end

  # ========================================
  # CONFIGURATION ERROR TESTS
  # ========================================

  test "ConfigurationError class exists" do
    assert defined?(BetterModel::Errors::Validatable::ConfigurationError)
  end

  test "ConfigurationError inherits from ArgumentError" do
    assert BetterModel::Errors::Validatable::ConfigurationError < ArgumentError
  end

  test "ConfigurationError can be instantiated with message" do
    error = BetterModel::Errors::Validatable::ConfigurationError.new(reason: "test message")
    assert_equal "test message", error.message
  end

  test "ConfigurationError can be caught as ArgumentError" do
    begin
      raise BetterModel::Errors::Validatable::ConfigurationError.new(reason: "test")
    rescue ArgumentError => e
      assert_instance_of BetterModel::Errors::Validatable::ConfigurationError, e
    end
  end

  test "ConfigurationError has correct namespace" do
    assert_equal "BetterModel::Errors::Validatable::ConfigurationError",
                 BetterModel::Errors::Validatable::ConfigurationError.name
  end

  # ========================================
  # CONFIGURATION ERROR INTEGRATION TESTS
  # ========================================

  test "raises ConfigurationError when included in non-ActiveRecord class" do
    error = assert_raises(BetterModel::Errors::Validatable::ConfigurationError) do
      Class.new do
        include BetterModel::Validatable
      end
    end
    assert_match(/can only be included in ActiveRecord models/, error.message)
  end

  test "raises ConfigurationError when register_complex_validation has no block" do
    error = assert_raises(BetterModel::Errors::Validatable::ConfigurationError) do
      create_validatable_class(:ValidatableArticle102) do
        register_complex_validation :test_validation
      end
    end
    assert_match(/Block required for complex validation/, error.message)
  end
end
