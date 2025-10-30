# frozen_string_literal: true

require "rails/generators"

module BetterModel
  module Generators
    class TraceableGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      argument :name, type: :string, default: "model", desc: "Model name (optional, used for default table name)"

      class_option :create_table, type: :boolean, default: false,
                   desc: "Create the versions table (only needed once per table)"

      class_option :table_name, type: :string, default: nil,
                   desc: "Custom table name for versions (default: {model}_versions)"

      def create_migration_file
        if options[:create_table]
          template "create_table_migration.rb.tt",
                   "db/migrate/#{timestamp}_create_#{versions_table_name}.rb"

          say "Created migration for '#{versions_table_name}' table", :green
          say "Run 'rails db:migrate' to create the table", :green
        else
          say "Traceable will use the '#{versions_table_name}' table", :yellow
          say "If the table doesn't exist yet, run:", :yellow
          say "  rails g better_model:traceable #{name} --create-table#{table_name_option_hint}", :green
          say "  rails db:migrate", :green
        end
      end

      def show_usage_instructions
        say "\nTo enable Traceable in your model:", :yellow
        say "  class #{class_name} < ApplicationRecord", :white
        say "    include BetterModel", :white
        say "    ", :white
        say "    traceable do", :white
        say "      track :field1, :field2, :field3", :white
        if custom_table_name?
          say "      table_name '#{versions_table_name}'", :white
        else
          say "      # table_name '#{versions_table_name}' (default)", :white
        end
        say "    end", :white
        say "  end", :white
        say "\nSee documentation for more options and usage examples", :yellow
      end

      private

      def timestamp
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def class_name
        name.camelize
      end

      def model_name
        name.underscore
      end

      def versions_table_name
        @versions_table_name ||= options[:table_name] || "#{model_name}_versions"
      end

      def custom_table_name?
        options[:table_name].present?
      end

      def table_name_option_hint
        custom_table_name? ? " --table-name=#{versions_table_name}" : ""
      end
    end
  end
end
