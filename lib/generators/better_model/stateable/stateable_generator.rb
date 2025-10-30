# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module BetterModel
  module Generators
    # Generator per aggiungere Stateable a un modello esistente
    #
    # Usage:
    #   rails generate better_model:stateable MODEL_NAME [options]
    #
    # Examples:
    #   rails generate better_model:stateable Order
    #   rails generate better_model:stateable Article --initial-state=draft
    #
    class StateableGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :initial_state, type: :string, default: nil,
                                   desc: "Initial state name (default: first state defined)"

      desc "Adds Stateable support to an existing model by adding a 'state' column"

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/add_stateable_to_#{table_name}.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end

      private

      def table_name
        name.tableize
      end

      def model_name
        name.camelize
      end

      def initial_state_value
        options[:initial_state] || "pending"
      end
    end
  end
end
