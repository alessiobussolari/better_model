# frozen_string_literal: true

require "test_helper"

module BetterModel
  class RailtieTest < ActiveSupport::TestCase
    # ========================================
    # 1. RAILTIE LOADING
    # ========================================

    test "BetterModel::Railtie is defined" do
      assert defined?(BetterModel::Railtie)
    end

    test "Railtie inherits from Rails::Railtie" do
      assert BetterModel::Railtie < Rails::Railtie
    end

    # ========================================
    # 2. CONFIGURATION INTEGRATION
    # ========================================

    test "Rails.application.config responds to better_model" do
      skip "Rails application not available" unless defined?(Rails.application) && Rails.application

      assert Rails.application.config.respond_to?(:better_model)
    end

    test "better_model config is an OrderedOptions" do
      skip "Rails application not available" unless defined?(Rails.application) && Rails.application

      assert Rails.application.config.better_model.is_a?(ActiveSupport::OrderedOptions)
    end

    test "BetterModel configuration is available" do
      assert_respond_to BetterModel, :configuration
      assert_respond_to BetterModel, :configure
      assert_instance_of BetterModel::Configuration, BetterModel.configuration
    end

    # ========================================
    # 3. LOGGER INTEGRATION
    # ========================================

    test "logger is set from Rails.logger when not explicitly configured" do
      # Reset configuration to ensure clean state
      BetterModel.reset_configuration!

      # In Rails test environment, Rails.logger should be available
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        assert_equal Rails.logger, BetterModel.configuration.effective_logger
      end
    end

    test "custom logger overrides Rails.logger" do
      custom_logger = Logger.new(StringIO.new)

      BetterModel.configure do |config|
        config.logger = custom_logger
      end

      assert_equal custom_logger, BetterModel.configuration.effective_logger
    ensure
      BetterModel.reset_configuration!
    end

    # ========================================
    # 4. RAKE TASKS
    # ========================================

    test "rake tasks file exists" do
      tasks_path = File.expand_path("../../lib/better_model/tasks/better_model.rake", __dir__)
      assert File.exist?(tasks_path), "Rake tasks file should exist at #{tasks_path}"
    end

    # ========================================
    # 5. MODULE AUTOLOADING
    # ========================================

    test "all BetterModel modules are available" do
      modules = %w[
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
      ]

      modules.each do |mod|
        assert defined?(BetterModel.const_get(mod)), "#{mod} should be defined"
      end
    end

    test "BetterModel concern is includable" do
      test_class = Class.new(ActiveRecord::Base) do
        self.table_name = "taggable_posts"
        include BetterModel
      end

      assert test_class.included_modules.include?(BetterModel)
    end

    # ========================================
    # 6. ENVIRONMENT DETECTION
    # ========================================

    test "Rails environment is accessible" do
      skip "Rails not available" unless defined?(Rails)

      assert_respond_to Rails, :env
      assert Rails.env.present?
    end

    # ========================================
    # 7. INITIALIZER REGISTRATION
    # ========================================

    test "better_model.configure initializer is registered" do
      skip "Rails application not available" unless defined?(Rails.application) && Rails.application

      initializer_names = Rails.application.initializers.map(&:name)
      assert initializer_names.include?("better_model.configure"),
             "better_model.configure initializer should be registered"
    end
  end
end
