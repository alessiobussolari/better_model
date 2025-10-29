# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module BetterModel
  module Generators
    class ArchivableGenerator < Rails::Generators::NamedBase
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :with_tracking, type: :boolean, default: false,
                   desc: "Add archived_by_id and archive_reason columns"
      class_option :with_by, type: :boolean, default: false,
                   desc: "Add archived_by_id column only"
      class_option :with_reason, type: :boolean, default: false,
                   desc: "Add archive_reason column only"
      class_option :skip_indexes, type: :boolean, default: false,
                   desc: "Skip adding indexes"

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def create_migration_file
        migration_template "migration.rb.tt",
                          "db/migrate/add_archivable_to_#{table_name}.rb"
      end

      private

      def table_name
        name.tableize
      end

      def migration_class_name
        "AddArchivableTo#{name.camelize.pluralize}"
      end

      def with_by_column?
        options[:with_tracking] || options[:with_by]
      end

      def with_reason_column?
        options[:with_tracking] || options[:with_reason]
      end

      def add_indexes?
        !options[:skip_indexes]
      end
    end
  end
end
