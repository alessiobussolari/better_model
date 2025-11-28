# frozen_string_literal: true

module BetterModel
  # Global configuration for BetterModel gem.
  #
  # This class holds global settings that affect all BetterModel modules.
  # Configuration is typically done in an initializer.
  #
  # @example Basic configuration in config/initializers/better_model.rb
  #   BetterModel.configure do |config|
  #     # Searchable defaults
  #     config.searchable_max_per_page = 100
  #     config.searchable_default_per_page = 25
  #
  #     # Traceable defaults
  #     config.traceable_default_table_name = "versions"
  #
  #     # Stateable defaults
  #     config.stateable_default_table_name = "state_transitions"
  #
  #     # Enable strict mode (raises errors instead of warnings)
  #     config.strict_mode = true
  #   end
  #
  # @example Accessing configuration
  #   BetterModel.configuration.searchable_max_per_page  # => 100
  #
  class Configuration
    # Searchable module defaults
    attr_accessor :searchable_max_per_page
    attr_accessor :searchable_default_per_page
    attr_accessor :searchable_strict_predicates

    # Traceable module defaults
    attr_accessor :traceable_default_table_name

    # Stateable module defaults
    attr_accessor :stateable_default_table_name

    # Archivable module defaults
    attr_accessor :archivable_skip_archived_by_default

    # Global settings
    attr_accessor :strict_mode
    attr_accessor :logger

    def initialize
      # Searchable defaults
      @searchable_max_per_page = 100
      @searchable_default_per_page = 25
      @searchable_strict_predicates = false

      # Traceable defaults
      @traceable_default_table_name = nil  # Uses model-specific default

      # Stateable defaults
      @stateable_default_table_name = "state_transitions"

      # Archivable defaults
      @archivable_skip_archived_by_default = false

      # Global settings
      @strict_mode = false
      @logger = nil
    end

    # Reset configuration to defaults
    #
    # @return [void]
    def reset!
      initialize
    end

    # Get the logger, defaulting to Rails.logger if available
    #
    # @return [Logger, nil]
    def effective_logger
      @logger || (defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : nil)
    end

    # Log a warning message
    #
    # @param message [String] Warning message
    # @return [void]
    def warn(message)
      if strict_mode
        raise BetterModel::Errors::BetterModelError, message
      elsif effective_logger
        effective_logger.warn("[BetterModel] #{message}")
      end
    end

    # Log an info message
    #
    # @param message [String] Info message
    # @return [void]
    def info(message)
      effective_logger&.info("[BetterModel] #{message}")
    end

    # Log a debug message
    #
    # @param message [String] Debug message
    # @return [void]
    def debug(message)
      effective_logger&.debug("[BetterModel] #{message}")
    end

    # Convert configuration to hash
    #
    # @return [Hash] Configuration as hash
    def to_h
      {
        searchable: {
          max_per_page: searchable_max_per_page,
          default_per_page: searchable_default_per_page,
          strict_predicates: searchable_strict_predicates
        },
        traceable: {
          default_table_name: traceable_default_table_name
        },
        stateable: {
          default_table_name: stateable_default_table_name
        },
        archivable: {
          skip_archived_by_default: archivable_skip_archived_by_default
        },
        global: {
          strict_mode: strict_mode,
          logger: logger.class.name
        }
      }
    end
  end

  class << self
    # Access the global configuration
    #
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure BetterModel globally
    #
    # @yield [config] Configuration block
    # @yieldparam config [Configuration] The configuration object
    #
    # @example
    #   BetterModel.configure do |config|
    #     config.searchable_max_per_page = 50
    #   end
    def configure
      yield(configuration)
    end

    # Reset configuration to defaults
    #
    # @return [void]
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
