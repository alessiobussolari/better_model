# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module BetterModel
  module Generators
    module Stateable
      # Generator per creare la tabella state_transitions
      #
      # Usage:
      #   rails generate better_model:stateable:install
      #   rails generate better_model:stateable:install --table-name=order_transitions
      #
      class InstallGenerator < Rails::Generators::Base
        include ActiveRecord::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        class_option :table_name, type: :string, default: "state_transitions",
                                  desc: "Custom table name for state transitions (default: state_transitions)"

        desc "Creates the state_transitions table for Stateable history tracking"

        def create_migration_file
          migration_template "install_migration.rb.tt", "db/migrate/create_#{transitions_table_name}.rb"
        end

        private

        def transitions_table_name
          options[:table_name]
        end
      end
    end
  end
end
