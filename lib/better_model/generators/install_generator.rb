# frozen_string_literal: true

require "rails/generators"

module BetterModel
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install BetterModel configuration"

      def create_initializer
        create_file "config/initializers/better_model.rb", <<~RUBY
          # frozen_string_literal: true

          BetterModel.configure do |config|
            # Maximum records per page for searchable
            # config.searchable_max_per_page = 100

            # Default records per page for searchable
            # config.searchable_default_per_page = 25

            # Enable strict mode for better error messages
            # config.strict_mode = true

            # Logger instance
            # config.logger = Rails.logger
          end
        RUBY
      end

      def show_readme
        say "\nBetterModel has been installed!", :green
        say "You can configure it in config/initializers/better_model.rb"
      end
    end
  end
end
