# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Validatable do
  # Helper per creare classi di test validatable
  def create_validatable_class(const_name, &block)
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name)

    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel
    end

    Object.const_set(const_name, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  describe "module inclusion" do
    it "is defined" do
      expect(defined?(BetterModel::Validatable)).to be_truthy
    end

    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Validatable
        end
      end.to raise_error(BetterModel::Errors::Validatable::ConfigurationError, /Invalid configuration/)
    end
  end

  describe "opt-in behavior" do
    it "does not enable validatable by default" do
      test_class = create_validatable_class("ValidatableOptInTest")

      expect(test_class.validatable_enabled?).to be false
    end

    it "enables validatable with validatable block" do
      test_class = create_validatable_class("ValidatableEnableTest") do
        validatable do
          # Empty block
        end
      end

      expect(test_class.validatable_enabled?).to be true
    end
  end

  describe "basic validations" do
    it "validates with presence" do
      test_class = create_validatable_class("ValidatablePresenceTest") do
        validatable do
          check :title, presence: true
        end
      end

      article = test_class.new(title: nil)
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("can't be blank")

      article.title = "Valid Title"
      expect(article).to be_valid
    end

    it "validates multiple fields" do
      test_class = create_validatable_class("ValidatableMultiTest") do
        validatable do
          check :title, :status, presence: true
        end
      end

      article = test_class.new(title: nil, status: nil)
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("can't be blank")
      expect(article.errors[:status]).to include("can't be blank")
    end

    it "validates with multiple options (presence + length)" do
      test_class = create_validatable_class("ValidatableMultiOptionsTest") do
        validatable do
          check :title, presence: true, length: { minimum: 5, maximum: 100 }
        end
      end

      # Missing title
      article = test_class.new(title: nil)
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("can't be blank")

      # Too short
      article = test_class.new(title: "Hi")
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("is too short (minimum is 5 characters)")

      # Too long
      article = test_class.new(title: "a" * 101)
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("is too long (maximum is 100 characters)")

      # Valid
      article = test_class.new(title: "Valid Title")
      expect(article).to be_valid
    end

    it "validates with format and numericality" do
      test_class = create_validatable_class("ValidatableFormatTest") do
        attr_accessor :email

        validatable do
          check :email, format: { with: URI::MailTo::EMAIL_REGEXP }
          check :view_count, numericality: { greater_than_or_equal_to: 0 }
        end
      end

      # Invalid email
      article = test_class.new(email: "not_an_email", view_count: 10)
      expect(article).not_to be_valid
      expect(article.errors[:email]).to include("is invalid")

      # Negative view_count
      article = test_class.new(email: "test@example.com", view_count: -5)
      expect(article).not_to be_valid
      expect(article.errors[:view_count]).to include("must be greater than or equal to 0")

      # Valid
      article = test_class.new(email: "test@example.com", view_count: 100)
      expect(article).to be_valid
    end

    it "validates with inclusion" do
      test_class = create_validatable_class("ValidatableInclusionTest") do
        validatable do
          check :status, inclusion: { in: %w[draft published archived] }
        end
      end

      %w[draft published archived].each do |status|
        article = test_class.new(status: status)
        expect(article).to be_valid
      end

      article = test_class.new(status: "invalid")
      expect(article).not_to be_valid
      expect(article.errors[:status]).to include("is not included in the list")
    end

    it "validates with custom message" do
      test_class = create_validatable_class("ValidatableCustomMsgTest") do
        validatable do
          check :title, presence: { message: "must not be empty" }
        end
      end

      article = test_class.new(title: nil)
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("must not be empty")
    end

    it "validates with allow_nil and allow_blank" do
      test_class = create_validatable_class("ValidatableAllowNilTest") do
        attr_accessor :optional_field, :another_field

        validatable do
          check :optional_field, length: { minimum: 5 }, allow_nil: true
          check :another_field, length: { minimum: 5 }, allow_blank: true
        end
      end

      # nil is allowed for optional_field
      article = test_class.new(optional_field: nil, another_field: "valid")
      expect(article).to be_valid

      # blank string is allowed for another_field
      article = test_class.new(optional_field: "valid", another_field: "")
      expect(article).to be_valid

      # Short value fails validation
      article = test_class.new(optional_field: "hi", another_field: "valid")
      expect(article).not_to be_valid
      expect(article.errors[:optional_field]).to include("is too short (minimum is 5 characters)")
    end

    it "validates with on: :create and on: :update" do
      test_class = create_validatable_class("ValidatableOnContextTest") do
        validatable do
          check :title, presence: true, on: :create
          check :status, presence: true, on: :update
        end
      end

      # Create validation
      article = test_class.new(title: nil, status: nil)
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("can't be blank")
      expect(article.errors.attribute_names).not_to include(:status)

      # Simulate persisted record
      article.title = "Valid"
      article.instance_variable_set(:@new_record, false)

      # Update validation
      article.status = nil
      expect(article).not_to be_valid
      expect(article.errors[:status]).to include("can't be blank")
    end

    it "validates with inline if/unless options" do
      test_class = create_validatable_class("ValidatableIfUnlessTest") do
        attr_accessor :draft_notes

        is :published, -> { status == "published" }

        validatable do
          check :published_at, presence: true, if: :is_published?
          check :draft_notes, presence: true, unless: :is_published?
        end
      end

      # Draft (if condition false, unless true)
      article = test_class.new(status: "draft", published_at: nil, draft_notes: nil)
      expect(article).not_to be_valid
      expect(article.errors[:draft_notes]).to include("can't be blank")
      expect(article.errors.attribute_names).not_to include(:published_at)

      # Published (if condition true, unless false)
      article = test_class.new(status: "published", published_at: nil, draft_notes: nil)
      expect(article).not_to be_valid
      expect(article.errors[:published_at]).to include("can't be blank")
      expect(article.errors.attribute_names).not_to include(:draft_notes)
    end
  end

  describe "validation groups" do
    it "defines groups correctly" do
      test_class = create_validatable_class("ValidatableGroupsTest") do
        validatable do
          check :title, presence: true
          check :status, presence: true
          check :view_count, presence: true

          validation_group :step1, [:title]
          validation_group :step2, [:status, :view_count]
        end
      end

      article = test_class.new(title: "Valid", status: nil, view_count: nil)

      # Full validation fails
      expect(article).not_to be_valid

      # Step1 validation passes (only title)
      expect(article.valid?(:step1)).to be true

      # Step2 validation fails (status and view_count missing)
      expect(article.valid?(:step2)).to be false
    end

    it "filters errors to group fields with errors_for_group" do
      test_class = create_validatable_class("ValidatableGroupErrorsTest") do
        validatable do
          check :title, presence: true
          check :status, presence: true

          validation_group :step1, [:title]
        end
      end

      article = test_class.new(title: nil, status: nil)
      article.valid? # Run full validation

      step1_errors = article.errors_for_group(:step1)
      expect(step1_errors[:title]).to be_present
      expect(step1_errors[:status]).to be_empty
    end

    it "raises NotEnabledError when validatable not enabled" do
      test_class = create_validatable_class("ValidatableNotEnabledTest")

      article = test_class.new
      expect do
        article.validate_group(:step1)
      end.to raise_error(BetterModel::Errors::Validatable::NotEnabledError, /Module is not enabled/)
    end

    it "raises NotEnabledError for errors_for_group when not enabled" do
      test_class = create_validatable_class("ValidatableNotEnabledTest2")

      article = test_class.new
      expect do
        article.errors_for_group(:step1)
      end.to raise_error(BetterModel::Errors::Validatable::NotEnabledError, /Module is not enabled/)
    end

    it "handles empty fields array" do
      test_class = create_validatable_class("ValidatableEmptyGroupTest") do
        validatable do
          check :title, presence: true
          validation_group :empty_group, []
        end
      end

      article = test_class.new(title: nil)

      # Empty group should pass
      expect(article.valid?(:empty_group)).to be true

      # Full validation should fail
      expect(article).not_to be_valid
    end

    it "raises error for duplicate group name" do
      expect do
        create_validatable_class("ValidatableDuplicateGroupTest") do
          validatable do
            validation_group :step1, [:title]
            validation_group :step1, [:status]
          end
        end
      end.to raise_error(ArgumentError, /Group already defined/)
    end

    it "handles overlapping fields in groups" do
      test_class = create_validatable_class("ValidatableOverlapGroupTest") do
        validatable do
          check :title, presence: true
          check :status, presence: true
          check :content, presence: true

          validation_group :group1, [:title, :status]
          validation_group :group2, [:status, :content]
        end
      end

      article = test_class.new(title: "Valid", status: nil, content: "Valid")

      # Group1 fails on status
      expect(article.valid?(:group1)).to be false
      expect(article.errors[:status]).to include("can't be blank")

      # Group2 also fails on status
      expect(article.valid?(:group2)).to be false
      expect(article.errors[:status]).to include("can't be blank")

      # Fix status
      article.status = "draft"
      expect(article.valid?(:group1)).to be true
      expect(article.valid?(:group2)).to be true
    end

    it "clears previous errors before validation with validate_group" do
      test_class = create_validatable_class("ValidatableClearErrorsTest") do
        validatable do
          check :title, presence: true
          check :status, presence: true

          validation_group :group1, [:title]
        end
      end

      article = test_class.new(title: nil, status: nil)

      # Run full validation first
      expect(article).not_to be_valid
      expect(article.errors[:title]).to be_present
      expect(article.errors[:status]).to be_present

      # Now validate only group1
      result = article.validate_group(:group1)

      # Errors should be cleared and only group1 errors present
      expect(result).to be false
      expect(article.errors[:title]).to be_present
      expect(article.errors[:status]).to be_empty
    end
  end

  describe "complex validations" do
    it "registers complex validation in registry" do
      test_class = create_validatable_class("ValidatableComplexRegTest") do
        attr_accessor :price, :sale_price

        register_complex_validation :valid_pricing do
          if sale_price.present? && sale_price >= price
            errors.add(:sale_price, "must be less than regular price")
          end
        end
      end

      expect(test_class.complex_validation?(:valid_pricing)).to be true
      expect(test_class.complex_validations_registry).to have_key(:valid_pricing)
    end

    it "requires a block for register_complex_validation" do
      expect do
        create_validatable_class("ValidatableComplexNoBlockTest") do
          register_complex_validation :test_validation
        end
      end.to raise_error(BetterModel::Errors::Validatable::ConfigurationError, /Invalid configuration/)
    end

    it "applies registered complex validation with check_complex" do
      test_class = create_validatable_class("ValidatableComplexApplyTest") do
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
      article = test_class.new(price: 100, sale_price: 80)
      expect(article).to be_valid

      # Invalid: sale_price >= price
      article = test_class.new(price: 100, sale_price: 120)
      expect(article).not_to be_valid
      expect(article.errors[:sale_price]).to include("must be less than regular price")
    end

    it "raises error for unknown complex validation" do
      expect do
        create_validatable_class("ValidatableComplexUnknownTest") do
          validatable do
            check_complex :nonexistent_validation
          end
        end
      end.to raise_error(ArgumentError, /Unknown complex validation/)
    end

    it "handles multi-field logic" do
      test_class = create_validatable_class("ValidatableComplexMultiTest") do
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
      article = test_class.new(starts_at: Time.now, ends_at: Time.now + 1.day)
      expect(article).to be_valid

      # Invalid: starts_at >= ends_at
      article = test_class.new(starts_at: Time.now, ends_at: Time.now - 1.day)
      expect(article).not_to be_valid
      expect(article.errors[:ends_at]).to include("must be after start date")
    end

    it "can add multiple errors" do
      test_class = create_validatable_class("ValidatableComplexMultiErrorTest") do
        attr_accessor :price, :sale_price, :stock

        register_complex_validation :product_consistency do
          errors.add(:sale_price, "required when on sale") if sale_price.blank? && stock && stock > 0
          errors.add(:price, "must be positive") if price && price <= 0
          errors.add(:stock, "cannot be negative") if stock && stock < 0
        end

        validatable do
          check_complex :product_consistency
        end
      end

      article = test_class.new(price: -10, stock: -5)
      expect(article).not_to be_valid
      expect(article.errors[:price]).to include("must be positive")
      expect(article.errors[:stock]).to include("cannot be negative")
    end

    it "supports multiple complex validations" do
      test_class = create_validatable_class("ValidatableMultiComplexTest") do
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
      article = test_class.new(price: 100, sale_price: 120, stock: 10, reserved_stock: 20)
      expect(article).not_to be_valid
      expect(article.errors[:sale_price]).to include("must be less than regular price")
      expect(article.errors[:reserved_stock]).to include("cannot exceed total stock")

      # Both validations valid
      article = test_class.new(price: 100, sale_price: 80, stock: 10, reserved_stock: 5)
      expect(article).to be_valid
    end

    it "are inherited by subclasses" do
      parent_class = create_validatable_class("ValidatableComplexParentTest") do
        attr_accessor :price

        register_complex_validation :valid_price do
          errors.add(:price, "must be positive") if price && price <= 0
        end

        validatable do
          check_complex :valid_price
        end
      end

      child_class = Class.new(parent_class)

      expect(child_class.complex_validation?(:valid_price)).to be true

      article = child_class.new(price: -10)
      expect(article).not_to be_valid
      expect(article.errors[:price]).to include("must be positive")
    end
  end

  describe "configuration immutability" do
    it "freezes configuration after setup" do
      test_class = create_validatable_class("ValidatableFrozenTest") do
        validatable do
          check :title, presence: true
        end
      end

      expect(test_class.validatable_config).to be_frozen
      expect(test_class.validatable_groups).to be_frozen
    end

    it "freezes complex_validations_registry" do
      test_class = create_validatable_class("ValidatableFrozenRegTest") do
        register_complex_validation :test_validation do
          errors.add(:base, "test")
        end
      end

      expect(test_class.complex_validations_registry).to be_frozen
    end
  end

  describe "integration" do
    it "combines with standard Rails validations" do
      test_class = create_validatable_class("ValidatableRailsIntegrationTest") do
        validates :content, presence: true

        validatable do
          check :title, presence: true
        end
      end

      article = test_class.new(title: nil, content: nil)
      expect(article).not_to be_valid
      expect(article.errors[:title]).to include("can't be blank")
      expect(article.errors[:content]).to include("can't be blank")
    end

    it "works with standard Rails validation contexts" do
      test_class = create_validatable_class("ValidatableContextsTest") do
        validatable do
          check :title, presence: true, on: :create
          check :status, presence: true, on: :update
        end
      end

      # Create context
      article = test_class.new(title: nil)
      expect(article.valid?(:create)).to be false

      # Simulate persisted record
      article.title = "Valid"
      article.instance_variable_set(:@new_record, false)

      # Update context
      article.status = nil
      expect(article.valid?(:update)).to be false
    end
  end

  describe "error messages" do
    it "includes validator metadata in details" do
      test_class = create_validatable_class("ValidatableDetailsTest") do
        validatable do
          check :title, presence: true, length: { minimum: 5 }
        end
      end

      article = test_class.new(title: "Hi")
      expect(article).not_to be_valid

      details = article.errors.details[:title]
      expect(details).to be_a(Array)
      expect(details.any? { |d| d[:error] == :too_short }).to be true
    end

    it "includes field names in full_messages" do
      test_class = create_validatable_class("ValidatableFullMsgTest") do
        validatable do
          check :title, presence: true
          check :status, presence: true
        end
      end

      article = test_class.new(title: nil, status: nil)
      expect(article).not_to be_valid

      full_messages = article.errors.full_messages
      expect(full_messages.any? { |msg| msg.include?("Title") }).to be true
      expect(full_messages.any? { |msg| msg.include?("Status") }).to be true
    end

    it "allows customizable error messages" do
      test_class = create_validatable_class("ValidatableCustomizeMsgTest") do
        validatable do
          check :title, presence: { message: "must be provided" }
          check :content, length: { minimum: 10, too_short: "needs at least %{count} characters" }
        end
      end

      article = test_class.new(title: nil, content: "Short")
      expect(article).not_to be_valid

      expect(article.errors[:title]).to include("must be provided")
      expect(article.errors[:content].any? { |msg| msg.include?("needs at least") }).to be true
    end
  end

  describe "performance" do
    it "handles many validations efficiently" do
      test_class = create_validatable_class("ValidatablePerfTest") do
        20.times { |i| attr_accessor "field_#{i}".to_sym }

        validatable do
          20.times { |i| check "field_#{i}".to_sym, presence: true }
        end
      end

      article = test_class.new

      start_time = Time.now
      article.valid?
      elapsed = Time.now - start_time

      expect(elapsed).to be < 0.1
      expect(article.errors.count).to eq(20)
    end

    it "performs well with many validation groups" do
      test_class = create_validatable_class("ValidatablePerfGroupsTest") do
        20.times { |i| attr_accessor "field_#{i}".to_sym }

        validatable do
          20.times { |i| check "field_#{i}".to_sym, presence: true }

          10.times do |i|
            validation_group "group_#{i}".to_sym, ["field_#{i * 2}".to_sym, "field_#{i * 2 + 1}".to_sym]
          end
        end
      end

      article = test_class.new

      start_time = Time.now
      10.times { |i| article.valid?("group_#{i}".to_sym) }
      elapsed = Time.now - start_time

      expect(elapsed).to be < 0.2
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Validatable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Validatable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Validatable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Validatable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end

  describe "NotEnabledError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Validatable::NotEnabledError)).to be_truthy
    end
  end
end
