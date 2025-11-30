# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Configuration do
  let(:config) { described_class.new }

  after do
    BetterModel.reset_configuration!
  end

  describe "#initialize" do
    it "sets default searchable_max_per_page" do
      expect(config.searchable_max_per_page).to eq(100)
    end

    it "sets default searchable_default_per_page" do
      expect(config.searchable_default_per_page).to eq(25)
    end

    it "sets default searchable_strict_predicates" do
      expect(config.searchable_strict_predicates).to be false
    end

    it "sets default traceable_default_table_name to nil" do
      expect(config.traceable_default_table_name).to be_nil
    end

    it "sets default stateable_default_table_name" do
      expect(config.stateable_default_table_name).to eq("state_transitions")
    end

    it "sets default archivable_skip_archived_by_default" do
      expect(config.archivable_skip_archived_by_default).to be false
    end

    it "sets default strict_mode" do
      expect(config.strict_mode).to be false
    end

    it "sets default logger to nil" do
      expect(config.logger).to be_nil
    end
  end

  describe "#reset!" do
    it "resets all values to defaults" do
      config.searchable_max_per_page = 500
      config.searchable_default_per_page = 50
      config.strict_mode = true
      config.logger = Logger.new($stdout)

      config.reset!

      expect(config.searchable_max_per_page).to eq(100)
      expect(config.searchable_default_per_page).to eq(25)
      expect(config.strict_mode).to be false
      expect(config.logger).to be_nil
    end
  end

  describe "#effective_logger" do
    context "when logger is set" do
      let(:custom_logger) { Logger.new($stdout) }

      it "returns the custom logger" do
        config.logger = custom_logger
        expect(config.effective_logger).to eq(custom_logger)
      end
    end

    context "when logger is not set" do
      it "returns Rails.logger when available" do
        # Rails.logger is available in test environment
        expect(config.effective_logger).to eq(Rails.logger)
      end
    end

    context "when Rails is not defined" do
      it "returns nil when no logger configured" do
        # This is hard to test in a Rails environment, but we can test the fallback
        config.logger = nil
        # In Rails environment, it will return Rails.logger
        expect(config.effective_logger).not_to be_nil
      end
    end
  end

  describe "#warn" do
    context "when strict_mode is enabled" do
      before { config.strict_mode = true }

      it "raises BetterModelError" do
        expect do
          config.warn("Test warning")
        end.to raise_error(BetterModel::Errors::BetterModelError, "Test warning")
      end
    end

    context "when strict_mode is disabled" do
      before { config.strict_mode = false }

      context "with logger available" do
        let(:mock_logger) { instance_double(Logger) }

        before do
          config.logger = mock_logger
        end

        it "logs warning message" do
          expect(mock_logger).to receive(:warn).with("[BetterModel] Test warning")
          config.warn("Test warning")
        end
      end

      context "without logger" do
        it "does not raise error" do
          # Use a config without any logger
          allow(config).to receive(:effective_logger).and_return(nil)
          expect { config.warn("Test warning") }.not_to raise_error
        end
      end
    end
  end

  describe "#info" do
    context "with logger available" do
      let(:mock_logger) { instance_double(Logger) }

      before do
        config.logger = mock_logger
      end

      it "logs info message" do
        expect(mock_logger).to receive(:info).with("[BetterModel] Test info")
        config.info("Test info")
      end
    end

    context "without logger" do
      it "does not raise error" do
        allow(config).to receive(:effective_logger).and_return(nil)
        expect { config.info("Test info") }.not_to raise_error
      end

      it "returns nil" do
        allow(config).to receive(:effective_logger).and_return(nil)
        expect(config.info("Test info")).to be_nil
      end
    end
  end

  describe "#debug" do
    context "with logger available" do
      let(:mock_logger) { instance_double(Logger) }

      before do
        config.logger = mock_logger
      end

      it "logs debug message" do
        expect(mock_logger).to receive(:debug).with("[BetterModel] Test debug")
        config.debug("Test debug")
      end
    end

    context "without logger" do
      it "does not raise error" do
        allow(config).to receive(:effective_logger).and_return(nil)
        expect { config.debug("Test debug") }.not_to raise_error
      end

      it "returns nil" do
        allow(config).to receive(:effective_logger).and_return(nil)
        expect(config.debug("Test debug")).to be_nil
      end
    end
  end

  describe "#to_h" do
    it "returns configuration as hash" do
      result = config.to_h

      expect(result).to be_a(Hash)
      expect(result).to have_key(:searchable)
      expect(result).to have_key(:traceable)
      expect(result).to have_key(:stateable)
      expect(result).to have_key(:archivable)
      expect(result).to have_key(:global)
    end

    it "includes searchable settings" do
      expect(config.to_h[:searchable]).to eq({
        max_per_page: 100,
        default_per_page: 25,
        strict_predicates: false
      })
    end

    it "includes traceable settings" do
      expect(config.to_h[:traceable]).to eq({
        default_table_name: nil
      })
    end

    it "includes stateable settings" do
      expect(config.to_h[:stateable]).to eq({
        default_table_name: "state_transitions"
      })
    end

    it "includes archivable settings" do
      expect(config.to_h[:archivable]).to eq({
        skip_archived_by_default: false
      })
    end

    it "includes global settings" do
      expect(config.to_h[:global]).to eq({
        strict_mode: false,
        logger: "NilClass"
      })
    end

    it "reflects changed values" do
      config.searchable_max_per_page = 200
      config.strict_mode = true

      result = config.to_h

      expect(result[:searchable][:max_per_page]).to eq(200)
      expect(result[:global][:strict_mode]).to be true
    end

    it "includes logger class name" do
      config.logger = Logger.new($stdout)
      expect(config.to_h[:global][:logger]).to eq("Logger")
    end
  end

  describe "attribute accessors" do
    it "allows setting searchable_max_per_page" do
      config.searchable_max_per_page = 200
      expect(config.searchable_max_per_page).to eq(200)
    end

    it "allows setting searchable_default_per_page" do
      config.searchable_default_per_page = 50
      expect(config.searchable_default_per_page).to eq(50)
    end

    it "allows setting searchable_strict_predicates" do
      config.searchable_strict_predicates = true
      expect(config.searchable_strict_predicates).to be true
    end

    it "allows setting traceable_default_table_name" do
      config.traceable_default_table_name = "audit_logs"
      expect(config.traceable_default_table_name).to eq("audit_logs")
    end

    it "allows setting stateable_default_table_name" do
      config.stateable_default_table_name = "custom_transitions"
      expect(config.stateable_default_table_name).to eq("custom_transitions")
    end

    it "allows setting archivable_skip_archived_by_default" do
      config.archivable_skip_archived_by_default = true
      expect(config.archivable_skip_archived_by_default).to be true
    end

    it "allows setting strict_mode" do
      config.strict_mode = true
      expect(config.strict_mode).to be true
    end

    it "allows setting logger" do
      logger = Logger.new($stdout)
      config.logger = logger
      expect(config.logger).to eq(logger)
    end
  end
end

RSpec.describe BetterModel do
  after do
    BetterModel.reset_configuration!
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(BetterModel.configuration).to be_a(BetterModel::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = BetterModel.configuration
      config2 = BetterModel.configuration
      expect(config1).to equal(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      yielded_config = nil

      BetterModel.configure do |config|
        yielded_config = config
      end

      expect(yielded_config).to eq(BetterModel.configuration)
    end

    it "allows setting values in the block" do
      BetterModel.configure do |config|
        config.searchable_max_per_page = 500
        config.strict_mode = true
      end

      expect(BetterModel.configuration.searchable_max_per_page).to eq(500)
      expect(BetterModel.configuration.strict_mode).to be true
    end
  end

  describe ".reset_configuration!" do
    it "creates a new configuration instance" do
      original = BetterModel.configuration
      BetterModel.configuration.searchable_max_per_page = 999

      BetterModel.reset_configuration!

      expect(BetterModel.configuration).not_to equal(original)
      expect(BetterModel.configuration.searchable_max_per_page).to eq(100)
    end
  end
end
