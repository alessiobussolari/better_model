# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Concerns::BaseConfigurator do
  # Test class that uses articles table
  let(:model_class) { Article }

  # Custom configurator for testing
  let(:configurator_class) do
    Class.new(described_class) do
      attr_reader :options

      def initialize(model_class)
        super
        @options = {}
      end

      def add_option(name, value)
        validate_symbol!(name, "option name")
        @options[name] = value
      end

      def to_h
        { options: @options }
      end

      # Expose protected methods for testing
      public :validate_symbol!
      public :validate_array!
      public :validate_positive_integer!
      public :validate_non_negative_integer!
      public :validate_boolean!
      public :validate_inclusion!
      public :column_exists?
      public :method_exists?
    end
  end

  let(:configurator) { configurator_class.new(model_class) }

  describe "#initialize" do
    it "accepts a model class" do
      expect(configurator.model_class).to eq(model_class)
    end

    it "raises ArgumentError when model_class is nil" do
      expect do
        configurator_class.new(nil)
      end.to raise_error(ArgumentError, "model_class cannot be nil")
    end
  end

  describe "#to_h" do
    it "returns configuration hash" do
      expect(configurator.to_h).to eq({ options: {} })
    end

    it "returns empty hash for base class" do
      base = described_class.new(model_class)
      expect(base.to_h).to eq({})
    end
  end

  describe "#validate_symbol!" do
    context "with valid symbol" do
      it "does not raise error" do
        expect { configurator.validate_symbol!(:test, "param") }.not_to raise_error
      end
    end

    context "with string instead of symbol" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_symbol!("test", "param")
        end.to raise_error(ArgumentError, "param must be a symbol, got String")
      end
    end

    context "with integer instead of symbol" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_symbol!(123, "param")
        end.to raise_error(ArgumentError, "param must be a symbol, got Integer")
      end
    end

    context "with nil instead of symbol" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_symbol!(nil, "param")
        end.to raise_error(ArgumentError, "param must be a symbol, got NilClass")
      end
    end
  end

  describe "#validate_array!" do
    context "with valid array" do
      it "does not raise error for empty array" do
        expect { configurator.validate_array!([], "param") }.not_to raise_error
      end

      it "does not raise error for array with elements" do
        expect { configurator.validate_array!([ 1, 2, 3 ], "param") }.not_to raise_error
      end
    end

    context "with string instead of array" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_array!("test", "param")
        end.to raise_error(ArgumentError, "param must be an array, got String")
      end
    end

    context "with hash instead of array" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_array!({ a: 1 }, "param")
        end.to raise_error(ArgumentError, "param must be an array, got Hash")
      end
    end

    context "with nil instead of array" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_array!(nil, "param")
        end.to raise_error(ArgumentError, "param must be an array, got NilClass")
      end
    end
  end

  describe "#validate_positive_integer!" do
    context "with valid positive integer" do
      it "does not raise error for 1" do
        expect { configurator.validate_positive_integer!(1, "param") }.not_to raise_error
      end

      it "does not raise error for large positive integer" do
        expect { configurator.validate_positive_integer!(1000, "param") }.not_to raise_error
      end
    end

    context "with zero" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_positive_integer!(0, "param")
        end.to raise_error(ArgumentError, "param must be a positive integer, got 0")
      end
    end

    context "with negative integer" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_positive_integer!(-5, "param")
        end.to raise_error(ArgumentError, "param must be a positive integer, got -5")
      end
    end

    context "with float" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_positive_integer!(1.5, "param")
        end.to raise_error(ArgumentError, "param must be a positive integer, got 1.5")
      end
    end

    context "with string" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_positive_integer!("5", "param")
        end.to raise_error(ArgumentError, 'param must be a positive integer, got "5"')
      end
    end
  end

  describe "#validate_non_negative_integer!" do
    context "with valid non-negative integer" do
      it "does not raise error for 0" do
        expect { configurator.validate_non_negative_integer!(0, "param") }.not_to raise_error
      end

      it "does not raise error for positive integer" do
        expect { configurator.validate_non_negative_integer!(100, "param") }.not_to raise_error
      end
    end

    context "with negative integer" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_non_negative_integer!(-1, "param")
        end.to raise_error(ArgumentError, "param must be a non-negative integer, got -1")
      end
    end

    context "with float" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_non_negative_integer!(0.5, "param")
        end.to raise_error(ArgumentError, "param must be a non-negative integer, got 0.5")
      end
    end

    context "with nil" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_non_negative_integer!(nil, "param")
        end.to raise_error(ArgumentError, "param must be a non-negative integer, got nil")
      end
    end
  end

  describe "#validate_boolean!" do
    context "with valid boolean" do
      it "does not raise error for true" do
        expect { configurator.validate_boolean!(true, "param") }.not_to raise_error
      end

      it "does not raise error for false" do
        expect { configurator.validate_boolean!(false, "param") }.not_to raise_error
      end
    end

    context "with truthy value that is not boolean" do
      it "raises ArgumentError for 1" do
        expect do
          configurator.validate_boolean!(1, "param")
        end.to raise_error(ArgumentError, "param must be a boolean, got Integer")
      end

      it "raises ArgumentError for string 'true'" do
        expect do
          configurator.validate_boolean!("true", "param")
        end.to raise_error(ArgumentError, "param must be a boolean, got String")
      end
    end

    context "with nil" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_boolean!(nil, "param")
        end.to raise_error(ArgumentError, "param must be a boolean, got NilClass")
      end
    end
  end

  describe "#validate_inclusion!" do
    let(:allowed_values) { [ :draft, :published, :archived ] }

    context "with value in allowed list" do
      it "does not raise error" do
        expect { configurator.validate_inclusion!(:draft, allowed_values, "status") }.not_to raise_error
      end

      it "does not raise error for any allowed value" do
        allowed_values.each do |value|
          expect { configurator.validate_inclusion!(value, allowed_values, "status") }.not_to raise_error
        end
      end
    end

    context "with value not in allowed list" do
      it "raises ArgumentError" do
        expect do
          configurator.validate_inclusion!(:unknown, allowed_values, "status")
        end.to raise_error(ArgumentError, "status must be one of [:draft, :published, :archived], got :unknown")
      end
    end

    context "with nil value" do
      it "raises ArgumentError when nil is not allowed" do
        expect do
          configurator.validate_inclusion!(nil, allowed_values, "status")
        end.to raise_error(ArgumentError, "status must be one of [:draft, :published, :archived], got nil")
      end

      it "does not raise error when nil is allowed" do
        allowed_with_nil = [ :draft, :published, nil ]
        expect { configurator.validate_inclusion!(nil, allowed_with_nil, "status") }.not_to raise_error
      end
    end
  end

  describe "#column_exists?" do
    context "when column exists" do
      it "returns true for existing column" do
        expect(configurator.column_exists?(:title)).to be true
      end

      it "returns true for string column name" do
        expect(configurator.column_exists?("title")).to be true
      end
    end

    context "when column does not exist" do
      it "returns false for non-existing column" do
        expect(configurator.column_exists?(:nonexistent_column)).to be false
      end
    end

    context "when model does not respond to column_names" do
      let(:model_without_columns) do
        Class.new do
          def self.table_exists?
            true
          end
        end
      end

      it "returns false" do
        config = configurator_class.new(model_without_columns)
        expect(config.column_exists?(:any)).to be false
      end
    end

    context "when table does not exist" do
      let(:model_without_table) do
        Class.new do
          def self.respond_to?(method, *)
            method == :column_names || method == :table_exists? || super
          end

          def self.table_exists?
            false
          end

          def self.column_names
            [ "id", "name" ]
          end
        end
      end

      it "returns false" do
        config = configurator_class.new(model_without_table)
        expect(config.column_exists?(:name)).to be false
      end
    end

    context "when model does not respond to table_exists?" do
      let(:model_without_table_exists) do
        Class.new do
          def self.respond_to?(method, *)
            method == :column_names || super
          end

          def self.column_names
            [ "id", "name" ]
          end
        end
      end

      it "returns false" do
        config = configurator_class.new(model_without_table_exists)
        expect(config.column_exists?(:name)).to be false
      end
    end
  end

  describe "#method_exists?" do
    context "when public method exists" do
      it "returns true" do
        expect(configurator.method_exists?(:save)).to be true
      end
    end

    context "when private method exists" do
      let(:model_with_private_method) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"

          private

          def secret_method
            "secret"
          end
        end
      end

      it "returns true for private methods" do
        config = configurator_class.new(model_with_private_method)
        expect(config.method_exists?(:secret_method)).to be true
      end
    end

    context "when method does not exist" do
      it "returns false" do
        expect(configurator.method_exists?(:nonexistent_method)).to be false
      end
    end
  end

  describe "subclass usage" do
    it "can define custom options using validation" do
      configurator.add_option(:custom, "value")
      expect(configurator.options).to eq({ custom: "value" })
    end

    it "validates option names" do
      expect do
        configurator.add_option("string_key", "value")
      end.to raise_error(ArgumentError, /must be a symbol/)
    end
  end
end
