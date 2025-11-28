# frozen_string_literal: true

require "test_helper"

module BetterModel
  class ConfigurationTest < ActiveSupport::TestCase
    def setup
      # Reset configuration before each test
      BetterModel.reset_configuration!
    end

    def teardown
      # Reset configuration after each test
      BetterModel.reset_configuration!
    end

    # ========================================
    # 1. DEFAULT VALUES
    # ========================================

    test "configuration has default searchable_max_per_page of 100" do
      assert_equal 100, BetterModel.configuration.searchable_max_per_page
    end

    test "configuration has default searchable_default_per_page of 25" do
      assert_equal 25, BetterModel.configuration.searchable_default_per_page
    end

    test "configuration has default searchable_strict_predicates of false" do
      assert_equal false, BetterModel.configuration.searchable_strict_predicates
    end

    test "configuration has default traceable_default_table_name of nil" do
      assert_nil BetterModel.configuration.traceable_default_table_name
    end

    test "configuration has default stateable_default_table_name of state_transitions" do
      assert_equal "state_transitions", BetterModel.configuration.stateable_default_table_name
    end

    test "configuration has default archivable_skip_archived_by_default of false" do
      assert_equal false, BetterModel.configuration.archivable_skip_archived_by_default
    end

    test "configuration has default strict_mode of false" do
      assert_equal false, BetterModel.configuration.strict_mode
    end

    test "configuration has default logger of nil" do
      assert_nil BetterModel.configuration.logger
    end

    # ========================================
    # 2. CONFIGURE BLOCK
    # ========================================

    test "configure block modifies searchable settings" do
      BetterModel.configure do |config|
        config.searchable_max_per_page = 50
        config.searchable_default_per_page = 10
      end

      assert_equal 50, BetterModel.configuration.searchable_max_per_page
      assert_equal 10, BetterModel.configuration.searchable_default_per_page
    end

    test "configure block modifies traceable settings" do
      BetterModel.configure do |config|
        config.traceable_default_table_name = "custom_versions"
      end

      assert_equal "custom_versions", BetterModel.configuration.traceable_default_table_name
    end

    test "configure block modifies stateable settings" do
      BetterModel.configure do |config|
        config.stateable_default_table_name = "custom_transitions"
      end

      assert_equal "custom_transitions", BetterModel.configuration.stateable_default_table_name
    end

    test "configure block modifies archivable settings" do
      BetterModel.configure do |config|
        config.archivable_skip_archived_by_default = true
      end

      assert_equal true, BetterModel.configuration.archivable_skip_archived_by_default
    end

    test "configure block modifies strict_mode" do
      BetterModel.configure do |config|
        config.strict_mode = true
      end

      assert_equal true, BetterModel.configuration.strict_mode
    end

    test "configure block modifies logger" do
      custom_logger = Logger.new(STDOUT)
      BetterModel.configure do |config|
        config.logger = custom_logger
      end

      assert_equal custom_logger, BetterModel.configuration.logger
    end

    test "configure block can set searchable_strict_predicates" do
      BetterModel.configure do |config|
        config.searchable_strict_predicates = true
      end

      assert_equal true, BetterModel.configuration.searchable_strict_predicates
    end

    # ========================================
    # 3. RESET CONFIGURATION
    # ========================================

    test "reset_configuration! restores default values" do
      BetterModel.configure do |config|
        config.searchable_max_per_page = 50
        config.searchable_default_per_page = 10
        config.strict_mode = true
        config.traceable_default_table_name = "custom_versions"
      end

      BetterModel.reset_configuration!

      assert_equal 100, BetterModel.configuration.searchable_max_per_page
      assert_equal 25, BetterModel.configuration.searchable_default_per_page
      assert_equal false, BetterModel.configuration.strict_mode
      assert_nil BetterModel.configuration.traceable_default_table_name
    end

    test "Configuration#reset! restores default values on instance" do
      config = BetterModel.configuration
      config.searchable_max_per_page = 50
      config.strict_mode = true

      config.reset!

      assert_equal 100, config.searchable_max_per_page
      assert_equal false, config.strict_mode
    end

    # ========================================
    # 4. TO_H METHOD
    # ========================================

    test "to_h returns configuration as hash" do
      result = BetterModel.configuration.to_h

      assert result.is_a?(Hash)
      assert result.key?(:searchable)
      assert result.key?(:traceable)
      assert result.key?(:stateable)
      assert result.key?(:archivable)
      assert result.key?(:global)
    end

    test "to_h includes searchable settings" do
      BetterModel.configure do |config|
        config.searchable_max_per_page = 50
        config.searchable_default_per_page = 10
        config.searchable_strict_predicates = true
      end

      result = BetterModel.configuration.to_h

      assert_equal 50, result[:searchable][:max_per_page]
      assert_equal 10, result[:searchable][:default_per_page]
      assert_equal true, result[:searchable][:strict_predicates]
    end

    test "to_h includes traceable settings" do
      BetterModel.configure do |config|
        config.traceable_default_table_name = "custom_versions"
      end

      result = BetterModel.configuration.to_h

      assert_equal "custom_versions", result[:traceable][:default_table_name]
    end

    test "to_h includes stateable settings" do
      result = BetterModel.configuration.to_h

      assert_equal "state_transitions", result[:stateable][:default_table_name]
    end

    test "to_h includes archivable settings" do
      result = BetterModel.configuration.to_h

      assert_equal false, result[:archivable][:skip_archived_by_default]
    end

    test "to_h includes global settings" do
      BetterModel.configure do |config|
        config.strict_mode = true
      end

      result = BetterModel.configuration.to_h

      assert_equal true, result[:global][:strict_mode]
    end

    # ========================================
    # 5. EFFECTIVE LOGGER
    # ========================================

    test "effective_logger returns custom logger when set" do
      custom_logger = Logger.new(STDOUT)
      BetterModel.configure do |config|
        config.logger = custom_logger
      end

      assert_equal custom_logger, BetterModel.configuration.effective_logger
    end

    test "effective_logger returns nil when no logger and no Rails" do
      # Reset to ensure no logger is set
      BetterModel.reset_configuration!

      # When Rails.logger is not available (in test without Rails), should return nil or Rails.logger
      result = BetterModel.configuration.effective_logger

      # In test environment, Rails.logger should be available
      if defined?(Rails) && Rails.respond_to?(:logger)
        assert_equal Rails.logger, result
      else
        assert_nil result
      end
    end

    # ========================================
    # 6. STRICT MODE BEHAVIOR
    # ========================================

    test "warn method logs warning when strict_mode is false" do
      logged_messages = []
      custom_logger = Object.new
      custom_logger.define_singleton_method(:warn) { |msg| logged_messages << msg }

      BetterModel.configure do |config|
        config.strict_mode = false
        config.logger = custom_logger
      end

      BetterModel.configuration.warn("Test warning")

      assert_equal 1, logged_messages.size
      assert_match(/\[BetterModel\] Test warning/, logged_messages.first)
    end

    test "warn method raises error when strict_mode is true" do
      BetterModel.configure do |config|
        config.strict_mode = true
      end

      assert_raises(BetterModel::Errors::BetterModelError) do
        BetterModel.configuration.warn("Test warning")
      end
    end

    test "info method logs info message" do
      logged_messages = []
      custom_logger = Object.new
      custom_logger.define_singleton_method(:info) { |msg| logged_messages << msg }

      BetterModel.configure do |config|
        config.logger = custom_logger
      end

      BetterModel.configuration.info("Test info")

      assert_equal 1, logged_messages.size
      assert_match(/\[BetterModel\] Test info/, logged_messages.first)
    end

    test "debug method logs debug message" do
      logged_messages = []
      custom_logger = Object.new
      custom_logger.define_singleton_method(:debug) { |msg| logged_messages << msg }

      BetterModel.configure do |config|
        config.logger = custom_logger
      end

      BetterModel.configuration.debug("Test debug")

      assert_equal 1, logged_messages.size
      assert_match(/\[BetterModel\] Test debug/, logged_messages.first)
    end

    # ========================================
    # 7. CONFIGURATION SINGLETON
    # ========================================

    test "configuration returns same instance across multiple calls" do
      config1 = BetterModel.configuration
      config2 = BetterModel.configuration

      assert_same config1, config2
    end

    test "reset_configuration! creates new instance" do
      config1 = BetterModel.configuration
      BetterModel.reset_configuration!
      config2 = BetterModel.configuration

      refute_same config1, config2
    end
  end
end
