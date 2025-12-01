# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Validatable::Configurator do
  let(:model_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "articles"

      # Ensure complex_validation? method exists
      def self.complex_validations
        @complex_validations ||= {}
      end

      def self.complex_validation?(name)
        complex_validations.key?(name.to_sym)
      end

      def self.register_complex_validation(name, &block)
        complex_validations[name.to_sym] = block
      end
    end
  end

  let(:configurator) { described_class.new(model_class) }

  describe "#initialize" do
    it "accepts a model class" do
      expect(configurator).to be_a(described_class)
    end

    it "initializes with empty groups" do
      expect(configurator.groups).to eq({})
    end
  end

  describe "#check" do
    it "delegates to model class validates" do
      expect(model_class).to receive(:validates).with(:title, presence: true)
      configurator.check(:title, presence: true)
    end

    it "passes multiple fields to validates" do
      expect(model_class).to receive(:validates).with(:title, :content, presence: true)
      configurator.check(:title, :content, presence: true)
    end

    it "passes complex options to validates" do
      expect(model_class).to receive(:validates).with(:email, format: { with: /\A.+@.+\z/ }, presence: true)
      configurator.check(:email, format: { with: /\A.+@.+\z/ }, presence: true)
    end

    it "passes numericality options to validates" do
      expect(model_class).to receive(:validates).with(:age, numericality: { greater_than: 0 })
      configurator.check(:age, numericality: { greater_than: 0 })
    end

    it "passes length options to validates" do
      expect(model_class).to receive(:validates).with(:password, length: { minimum: 8, maximum: 100 })
      configurator.check(:password, length: { minimum: 8, maximum: 100 })
    end

    it "passes uniqueness options to validates" do
      expect(model_class).to receive(:validates).with(:email, uniqueness: true)
      configurator.check(:email, uniqueness: true)
    end

    it "passes inclusion options to validates" do
      expect(model_class).to receive(:validates).with(:status, inclusion: { in: %w[draft published] })
      configurator.check(:status, inclusion: { in: %w[draft published] })
    end
  end

  describe "#check_complex" do
    context "when complex validation is registered" do
      before do
        model_class.register_complex_validation(:valid_pricing) do
          errors.add(:price, "must be positive") if price.negative?
        end
      end

      it "accepts registered complex validation" do
        expect do
          configurator.check_complex(:valid_pricing)
        end.not_to raise_error
      end

      it "stores complex validation name" do
        configurator.check_complex(:valid_pricing)
        expect(configurator.to_h[:complex_validations]).to include(:valid_pricing)
      end

      it "converts string names to symbols" do
        configurator.check_complex("valid_pricing")
        expect(configurator.to_h[:complex_validations]).to include(:valid_pricing)
      end
    end

    context "when complex validation is not registered" do
      it "raises ArgumentError" do
        expect do
          configurator.check_complex(:unknown_validation)
        end.to raise_error(ArgumentError, /Unknown complex validation: unknown_validation/)
      end

      it "includes helpful message" do
        expect do
          configurator.check_complex(:missing)
        end.to raise_error(ArgumentError, /Use register_complex_validation to define it first/)
      end
    end

    it "allows multiple complex validations" do
      model_class.register_complex_validation(:validation1) { true }
      model_class.register_complex_validation(:validation2) { true }

      configurator.check_complex(:validation1)
      configurator.check_complex(:validation2)

      expect(configurator.to_h[:complex_validations]).to eq([ :validation1, :validation2 ])
    end
  end

  describe "#validation_group" do
    it "creates a validation group" do
      configurator.validation_group(:step1, [ :email, :password ])
      expect(configurator.groups).to have_key(:step1)
    end

    it "stores group name" do
      configurator.validation_group(:step1, [ :email, :password ])
      expect(configurator.groups[:step1][:name]).to eq(:step1)
    end

    it "stores fields array" do
      configurator.validation_group(:step1, [ :email, :password ])
      expect(configurator.groups[:step1][:fields]).to eq([ :email, :password ])
    end

    it "raises ArgumentError when group name is not a symbol" do
      expect do
        configurator.validation_group("step1", [ :email ])
      end.to raise_error(ArgumentError, "Group name must be a symbol")
    end

    it "raises ArgumentError when fields is not an array" do
      expect do
        configurator.validation_group(:step1, :email)
      end.to raise_error(ArgumentError, "Fields must be an array")
    end

    it "raises ArgumentError when fields is a hash" do
      expect do
        configurator.validation_group(:step1, { email: true })
      end.to raise_error(ArgumentError, "Fields must be an array")
    end

    it "raises ArgumentError when group is already defined" do
      configurator.validation_group(:step1, [ :email ])
      expect do
        configurator.validation_group(:step1, [ :password ])
      end.to raise_error(ArgumentError, "Group already defined: step1")
    end

    it "allows multiple groups" do
      configurator.validation_group(:step1, [ :email, :password ])
      configurator.validation_group(:step2, [ :first_name, :last_name ])
      configurator.validation_group(:step3, [ :address, :city ])

      expect(configurator.groups.keys).to eq([ :step1, :step2, :step3 ])
    end

    it "allows empty fields array" do
      expect do
        configurator.validation_group(:empty, [])
      end.not_to raise_error
      expect(configurator.groups[:empty][:fields]).to eq([])
    end
  end

  describe "#to_h" do
    it "returns hash with complex_validations" do
      expect(configurator.to_h).to have_key(:complex_validations)
    end

    it "returns empty complex_validations by default" do
      expect(configurator.to_h[:complex_validations]).to eq([])
    end

    context "with complex validations" do
      before do
        model_class.register_complex_validation(:check1) { true }
        model_class.register_complex_validation(:check2) { true }
        configurator.check_complex(:check1)
        configurator.check_complex(:check2)
      end

      it "includes all complex validations" do
        expect(configurator.to_h[:complex_validations]).to eq([ :check1, :check2 ])
      end
    end
  end

  describe "groups accessor" do
    it "returns all defined groups" do
      configurator.validation_group(:step1, [ :email ])
      configurator.validation_group(:step2, [ :name ])

      expect(configurator.groups.size).to eq(2)
    end

    it "returns empty hash when no groups defined" do
      expect(configurator.groups).to eq({})
    end

    it "provides read access to group details" do
      configurator.validation_group(:step1, [ :email, :password ])

      group = configurator.groups[:step1]
      expect(group[:name]).to eq(:step1)
      expect(group[:fields]).to eq([ :email, :password ])
    end
  end

  describe "integration scenarios" do
    it "supports wizard-style multi-step validation" do
      # Step 1: Account info
      expect(model_class).to receive(:validates).with(:email, :password, presence: true)
      configurator.check(:email, :password, presence: true)
      configurator.validation_group(:account, [ :email, :password ])

      # Step 2: Personal info
      expect(model_class).to receive(:validates).with(:first_name, :last_name, presence: true)
      configurator.check(:first_name, :last_name, presence: true)
      configurator.validation_group(:personal, [ :first_name, :last_name ])

      # Step 3: Address
      expect(model_class).to receive(:validates).with(:address, :city, :zip_code, presence: true)
      configurator.check(:address, :city, :zip_code, presence: true)
      configurator.validation_group(:address, [ :address, :city, :zip_code ])

      expect(configurator.groups.keys).to eq([ :account, :personal, :address ])
    end

    it "supports mixed standard and complex validations" do
      # Standard validations
      expect(model_class).to receive(:validates).with(:title, presence: true)
      expect(model_class).to receive(:validates).with(:price, numericality: { greater_than: 0 })

      configurator.check(:title, presence: true)
      configurator.check(:price, numericality: { greater_than: 0 })

      # Complex validations
      model_class.register_complex_validation(:sale_price_valid) do
        if sale_price.present? && sale_price >= price
          errors.add(:sale_price, "must be less than regular price")
        end
      end
      configurator.check_complex(:sale_price_valid)

      expect(configurator.to_h[:complex_validations]).to eq([ :sale_price_valid ])
    end
  end
end
