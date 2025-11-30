# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Concerns::EnabledCheck do
  # Custom error class for testing
  let(:test_error_class) do
    Class.new(StandardError)
  end

  # Model with module enabled
  let(:enabled_model_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Concerns::EnabledCheck

      def self.test_module_enabled?
        true
      end
    end
  end

  # Model with module disabled
  let(:disabled_model_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Concerns::EnabledCheck

      def self.test_module_enabled?
        false
      end
    end
  end

  # Model without enabled method
  let(:model_without_enabled_method) do
    Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Concerns::EnabledCheck
    end
  end

  describe "instance methods" do
    describe "#ensure_module_enabled!" do
      context "when module is enabled" do
        let(:instance) { enabled_model_class.new }

        it "does not raise error" do
          expect do
            instance.ensure_module_enabled!(:test_module, test_error_class)
          end.not_to raise_error
        end

        it "returns nil" do
          result = instance.ensure_module_enabled!(:test_module, test_error_class)
          expect(result).to be_nil
        end
      end

      context "when module is disabled" do
        let(:instance) { disabled_model_class.new }

        it "raises the specified error class" do
          expect do
            instance.ensure_module_enabled!(:test_module, test_error_class)
          end.to raise_error(test_error_class)
        end

        it "uses default error message" do
          expect do
            instance.ensure_module_enabled!(:test_module, test_error_class)
          end.to raise_error(test_error_class, "Module is not enabled")
        end

        it "uses custom error message when provided" do
          expect do
            instance.ensure_module_enabled!(:test_module, test_error_class, message: "Custom message")
          end.to raise_error(test_error_class, "Custom message")
        end
      end

      context "when enabled method does not exist" do
        let(:instance) { model_without_enabled_method.new }

        it "raises error" do
          expect do
            instance.ensure_module_enabled!(:nonexistent, test_error_class)
          end.to raise_error(test_error_class)
        end
      end
    end

    describe "#if_module_enabled" do
      context "when module is enabled" do
        let(:instance) { enabled_model_class.new }

        it "yields the block" do
          result = instance.if_module_enabled(:test_module) { "executed" }
          expect(result).to eq("executed")
        end

        it "returns nil without block" do
          result = instance.if_module_enabled(:test_module)
          expect(result).to be_nil
        end

        it "ignores default value when enabled" do
          result = instance.if_module_enabled(:test_module, default: "default") { "executed" }
          expect(result).to eq("executed")
        end
      end

      context "when module is disabled" do
        let(:instance) { disabled_model_class.new }

        it "returns default value" do
          result = instance.if_module_enabled(:test_module, default: "default") { "executed" }
          expect(result).to eq("default")
        end

        it "returns nil as default when not specified" do
          result = instance.if_module_enabled(:test_module) { "executed" }
          expect(result).to be_nil
        end

        it "does not yield the block" do
          executed = false
          instance.if_module_enabled(:test_module) { executed = true }
          expect(executed).to be false
        end

        it "returns default without block" do
          result = instance.if_module_enabled(:test_module, default: [])
          expect(result).to eq([])
        end
      end

      context "when enabled method does not exist" do
        let(:instance) { model_without_enabled_method.new }

        it "returns default value" do
          result = instance.if_module_enabled(:nonexistent, default: "default")
          expect(result).to eq("default")
        end

        it "does not yield the block" do
          executed = false
          instance.if_module_enabled(:nonexistent) { executed = true }
          expect(executed).to be false
        end
      end
    end
  end

  describe "class methods" do
    describe ".ensure_module_enabled!" do
      context "when module is enabled" do
        it "does not raise error" do
          expect do
            enabled_model_class.ensure_module_enabled!(:test_module, test_error_class)
          end.not_to raise_error
        end

        it "returns nil" do
          result = enabled_model_class.ensure_module_enabled!(:test_module, test_error_class)
          expect(result).to be_nil
        end
      end

      context "when module is disabled" do
        it "raises the specified error class" do
          expect do
            disabled_model_class.ensure_module_enabled!(:test_module, test_error_class)
          end.to raise_error(test_error_class)
        end

        it "uses default error message" do
          expect do
            disabled_model_class.ensure_module_enabled!(:test_module, test_error_class)
          end.to raise_error(test_error_class, "Module is not enabled")
        end

        it "uses custom error message when provided" do
          expect do
            disabled_model_class.ensure_module_enabled!(:test_module, test_error_class, message: "Custom class message")
          end.to raise_error(test_error_class, "Custom class message")
        end
      end

      context "when enabled method does not exist" do
        it "raises error" do
          expect do
            model_without_enabled_method.ensure_module_enabled!(:nonexistent, test_error_class)
          end.to raise_error(test_error_class)
        end
      end
    end

    describe ".if_module_enabled" do
      context "when module is enabled" do
        it "yields the block" do
          result = enabled_model_class.if_module_enabled(:test_module) { "class executed" }
          expect(result).to eq("class executed")
        end

        it "returns nil without block" do
          result = enabled_model_class.if_module_enabled(:test_module)
          expect(result).to be_nil
        end

        it "ignores default value when enabled" do
          result = enabled_model_class.if_module_enabled(:test_module, default: "default") { "class executed" }
          expect(result).to eq("class executed")
        end
      end

      context "when module is disabled" do
        it "returns default value" do
          result = disabled_model_class.if_module_enabled(:test_module, default: "class default") { "executed" }
          expect(result).to eq("class default")
        end

        it "returns nil as default when not specified" do
          result = disabled_model_class.if_module_enabled(:test_module) { "executed" }
          expect(result).to be_nil
        end

        it "does not yield the block" do
          executed = false
          disabled_model_class.if_module_enabled(:test_module) { executed = true }
          expect(executed).to be false
        end

        it "returns default without block" do
          result = disabled_model_class.if_module_enabled(:test_module, default: {})
          expect(result).to eq({})
        end
      end

      context "when enabled method does not exist" do
        it "returns default value" do
          result = model_without_enabled_method.if_module_enabled(:nonexistent, default: "no method")
          expect(result).to eq("no method")
        end

        it "does not yield the block" do
          executed = false
          model_without_enabled_method.if_module_enabled(:nonexistent) { executed = true }
          expect(executed).to be false
        end
      end
    end
  end

  describe "integration with real BetterModel modules" do
    context "with Archivable module" do
      let(:archivable_model) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel

          archivable
        end
      end

      let(:non_archivable_model) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel
        end
      end

      it "returns true for archivable_enabled? on archivable model" do
        expect(archivable_model.archivable_enabled?).to be true
      end

      it "returns false for archivable_enabled? on non-archivable model" do
        expect(non_archivable_model.archivable_enabled?).to be false
      end
    end

    context "with Traceable module" do
      let(:traceable_model) do
        klass = Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel
        end
        stub_const("TraceableTestModel", klass)
        klass.class_eval { traceable }
        klass
      end

      let(:non_traceable_model) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel
        end
      end

      it "returns true for traceable_enabled? on traceable model" do
        expect(traceable_model.traceable_enabled?).to be true
      end

      it "returns false for traceable_enabled? on non-traceable model" do
        expect(non_traceable_model.traceable_enabled?).to be false
      end
    end
  end

  describe "edge cases" do
    context "with various default value types" do
      let(:instance) { disabled_model_class.new }

      it "returns empty array as default" do
        result = instance.if_module_enabled(:test_module, default: [])
        expect(result).to eq([])
      end

      it "returns empty hash as default" do
        result = instance.if_module_enabled(:test_module, default: {})
        expect(result).to eq({})
      end

      it "returns false as default" do
        result = instance.if_module_enabled(:test_module, default: false)
        expect(result).to be false
      end

      it "returns 0 as default" do
        result = instance.if_module_enabled(:test_module, default: 0)
        expect(result).to eq(0)
      end

      it "returns lambda as default" do
        default_proc = -> { "computed" }
        result = instance.if_module_enabled(:test_module, default: default_proc)
        expect(result).to eq(default_proc)
      end
    end

    context "when block raises error" do
      let(:instance) { enabled_model_class.new }

      it "propagates the error from block" do
        expect do
          instance.if_module_enabled(:test_module) { raise StandardError, "Block error" }
        end.to raise_error(StandardError, "Block error")
      end
    end

    context "with symbolic module names" do
      let(:model_with_underscore_module) do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel::Concerns::EnabledCheck

          def self.my_custom_module_enabled?
            true
          end
        end
      end

      it "handles underscored module names" do
        result = model_with_underscore_module.if_module_enabled(:my_custom_module) { "works" }
        expect(result).to eq("works")
      end
    end
  end
end
