# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Railtie do
  describe "railtie definition" do
    it "is defined" do
      expect(defined?(BetterModel::Railtie)).to be_truthy
    end

    it "inherits from Rails::Railtie" do
      expect(BetterModel::Railtie).to be < ::Rails::Railtie
    end
  end

  describe "configuration" do
    it "adds better_model config to Rails application" do
      expect(Rails.application.config).to respond_to(:better_model)
    end

    it "better_model config is an OrderedOptions" do
      expect(Rails.application.config.better_model).to be_a(ActiveSupport::OrderedOptions)
    end

    it "allows setting custom configuration values" do
      Rails.application.config.better_model.custom_value = "test"
      expect(Rails.application.config.better_model.custom_value).to eq("test")
    end
  end

  describe "initializer" do
    after do
      BetterModel.reset_configuration!
    end

    it "sets logger to Rails.logger if not configured" do
      # Reset to test default behavior
      BetterModel.reset_configuration!

      # Re-run initializer logic
      BetterModel.configuration.logger ||= Rails.logger

      expect(BetterModel.configuration.effective_logger).to eq(Rails.logger)
    end

    it "preserves custom logger if already set" do
      custom_logger = Logger.new($stdout)
      BetterModel.configuration.logger = custom_logger

      # Re-run initializer logic (won't override)
      BetterModel.configuration.logger ||= Rails.logger

      expect(BetterModel.configuration.logger).to eq(custom_logger)
    end
  end

  describe "rake tasks" do
    it "loads rake tasks file" do
      rake_file = File.expand_path("../../lib/better_model/tasks/better_model.rake", __dir__)
      expect(File.exist?(rake_file)).to be true
    end

    it "rake tasks file is valid Ruby" do
      rake_file = File.expand_path("../../lib/better_model/tasks/better_model.rake", __dir__)
      expect { RubyVM::InstructionSequence.compile_file(rake_file) }.not_to raise_error
    end

    it "rake tasks file defines better_model namespace" do
      rake_file = File.expand_path("../../lib/better_model/tasks/better_model.rake", __dir__)
      content = File.read(rake_file)

      expect(content).to include("namespace :better_model")
      expect(content).to include("task config:")
      expect(content).to include("task modules:")
      expect(content).to include("task models:")
      expect(content).to include("task model_info:")
      expect(content).to include("task health:")
      expect(content).to include("task reset_config:")
    end

    it "rake tasks file defines stats namespace" do
      rake_file = File.expand_path("../../lib/better_model/tasks/better_model.rake", __dir__)
      content = File.read(rake_file)

      expect(content).to include("namespace :stats")
      expect(content).to include("task tags:")
      expect(content).to include("task states:")
      expect(content).to include("task archives:")
    end
  end

  describe "generators" do
    it "has generators block defined" do
      # Verify generators hook is available in Railtie
      expect(BetterModel::Railtie).to respond_to(:generators)
    end
  end
end

RSpec.describe BetterModel::Configuration, "integration with Railtie" do
  after do
    BetterModel.reset_configuration!
  end

  describe "Rails config application" do
    it "applies Rails config to BetterModel configuration" do
      # Simulate what the initializer does
      Rails.application.config.better_model.searchable_max_per_page = 500

      # Apply config
      Rails.application.config.better_model.each do |key, value|
        if BetterModel.configuration.respond_to?("#{key}=")
          BetterModel.configuration.public_send("#{key}=", value)
        end
      end

      expect(BetterModel.configuration.searchable_max_per_page).to eq(500)
    end

    it "ignores unknown config keys" do
      Rails.application.config.better_model.unknown_config = "value"

      expect do
        Rails.application.config.better_model.each do |key, value|
          if BetterModel.configuration.respond_to?("#{key}=")
            BetterModel.configuration.public_send("#{key}=", value)
          end
        end
      end.not_to raise_error
    end

    it "applies multiple config values" do
      Rails.application.config.better_model.searchable_max_per_page = 200
      Rails.application.config.better_model.strict_mode = true
      Rails.application.config.better_model.stateable_default_table_name = "custom_transitions"

      Rails.application.config.better_model.each do |key, value|
        if BetterModel.configuration.respond_to?("#{key}=")
          BetterModel.configuration.public_send("#{key}=", value)
        end
      end

      expect(BetterModel.configuration.searchable_max_per_page).to eq(200)
      expect(BetterModel.configuration.strict_mode).to be true
      expect(BetterModel.configuration.stateable_default_table_name).to eq("custom_transitions")
    end
  end
end

RSpec.describe "Rake Tasks Content Verification" do
  let(:rake_file_path) { File.expand_path("../../lib/better_model/tasks/better_model.rake", __dir__) }
  let(:rake_content) { File.read(rake_file_path) }

  describe "config task" do
    it "outputs searchable configuration" do
      expect(rake_content).to include("config.searchable_max_per_page")
      expect(rake_content).to include("config.searchable_default_per_page")
      expect(rake_content).to include("config.searchable_strict_predicates")
    end

    it "outputs traceable configuration" do
      expect(rake_content).to include("config.traceable_default_table_name")
    end

    it "outputs stateable configuration" do
      expect(rake_content).to include("config.stateable_default_table_name")
    end

    it "outputs archivable configuration" do
      expect(rake_content).to include("config.archivable_skip_archived_by_default")
    end

    it "outputs global configuration" do
      expect(rake_content).to include("config.strict_mode")
      expect(rake_content).to include("config.logger")
    end
  end

  describe "modules task" do
    it "lists all BetterModel modules" do
      %w[
        Archivable
        Permissible
        Predicable
        Repositable
        Searchable
        Sortable
        Stateable
        Statusable
        Taggable
        Traceable
        Validatable
      ].each do |mod|
        expect(rake_content).to include(mod)
      end
    end
  end

  describe "models task" do
    it "eager loads application" do
      expect(rake_content).to include("eager_load!")
    end

    it "finds models with BetterModel modules" do
      expect(rake_content).to include("ActiveRecord::Base.descendants")
      expect(rake_content).to include('start_with?("BetterModel::")')
    end
  end

  describe "health task" do
    it "checks for state_transitions table" do
      expect(rake_content).to include("state_transitions")
      expect(rake_content).to include("table_exists?")
    end

    it "reports errors and warnings" do
      expect(rake_content).to include("errors")
      expect(rake_content).to include("warnings")
    end
  end

  describe "stats:tags task" do
    it "shows tag statistics" do
      expect(rake_content).to include("tag_counts")
      expect(rake_content).to include("Top 5 tags")
    end
  end

  describe "stats:states task" do
    it "shows state distribution" do
      expect(rake_content).to include("State Distribution")
      expect(rake_content).to include("group(column).count")
    end
  end

  describe "stats:archives task" do
    it "shows archive statistics" do
      expect(rake_content).to include("Archive Statistics")
      expect(rake_content).to include("archived.count")
    end
  end
end
