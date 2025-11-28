# frozen_string_literal: true

require_relative "configuration"

module BetterModel
  # Rails integration for BetterModel.
  #
  # This Railtie provides:
  # - Automatic loading of configuration
  # - Rake tasks for introspection and maintenance
  # - Generator hooks
  # - Development console helpers
  #
  class Railtie < ::Rails::Railtie
    # Load configuration
    config.better_model = ActiveSupport::OrderedOptions.new

    # Initialize BetterModel after Rails is initialized
    initializer "better_model.configure" do |app|
      # Apply any Rails config to BetterModel configuration
      if app.config.better_model.respond_to?(:each)
        app.config.better_model.each do |key, value|
          if BetterModel.configuration.respond_to?("#{key}=")
            BetterModel.configuration.public_send("#{key}=", value)
          end
        end
      end

      # Set logger if not already set
      BetterModel.configuration.logger ||= Rails.logger
    end

    # Load rake tasks
    rake_tasks do
      load File.expand_path("tasks/better_model.rake", __dir__)
    end

    # Add console helpers in development/test
    console do
      if Rails.env.development? || Rails.env.test?
        # Add BetterModel helper methods to console
        Rails.application.config.console = Rails::Console
      end
    end

    # Provide generators
    generators do
      require_relative "generators/install_generator" if defined?(Rails::Generators)
    end
  end
end
