# frozen_string_literal: true

require "rails/generators"

module BetterModel
  module Generators
    # Generator for creating repository classes that implement the Repository Pattern.
    #
    # This generator creates a repository class for a given model, integrating seamlessly
    # with BetterModel's Searchable, Predicable, and Sortable concerns.
    #
    # @example Generate a repository for Article model
    #   rails generate better_model:repository Article
    #
    # @example Generate with custom path
    #   rails generate better_model:repository Article --path app/services/repositories
    #
    # @example Skip ApplicationRepository creation
    #   rails generate better_model:repository Article --skip-base
    #
    class RepositoryGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :path, type: :string, default: "app/repositories",
                   desc: "Directory where the repository will be created"
      class_option :skip_base, type: :boolean, default: false,
                   desc: "Skip creating ApplicationRepository if it doesn't exist"
      class_option :namespace, type: :string, default: nil,
                   desc: "Namespace for the repository class"

      # Create the ApplicationRepository base class if it doesn't exist
      def create_application_repository
        return if options[:skip_base]
        return if File.exist?(File.join(destination_root, application_repository_path))

        template "application_repository.rb.tt", application_repository_path
        say "Created ApplicationRepository at #{application_repository_path}", :green
      end

      # Create the model-specific repository class
      def create_repository_file
        template "repository.rb.tt", repository_path
        say "Created #{repository_class_name} at #{repository_path}", :green
      end

      # Display usage instructions
      def show_instructions
        say "\nRepository created successfully!", :green
        say "\nUsage example:", :yellow
        say "  repo = #{repository_class_name}.new", :white
        say "  results = repo.search({ #{example_predicate} })", :white
        say "  record = repo.search({ id_eq: 1 }, limit: 1)", :white
        say "  all = repo.search({}, limit: nil)", :white
        say "\nAdd custom methods to #{repository_path}", :yellow

        if model_has_better_model_features?
          say "\nYour model has BetterModel features enabled:", :green
          display_available_features
        else
          say "\nTip: Include BetterModel in your #{class_name} model to unlock:", :yellow
          say "  - Predicable: Auto-generated filter scopes", :white
          say "  - Sortable: Auto-generated sort scopes", :white
          say "  - Searchable: Unified search interface", :white
        end
      end

      private

      def repository_path
        File.join(options[:path], "#{file_name}_repository.rb")
      end

      def application_repository_path
        File.join(options[:path], "application_repository.rb")
      end

      def repository_class_name
        if options[:namespace]
          "#{options[:namespace]}::#{class_name}Repository"
        else
          "#{class_name}Repository"
        end
      end

      def base_repository_class
        if options[:skip_base]
          "BetterModel::Repositable::BaseRepository"
        else
          "ApplicationRepository"
        end
      end

      def example_predicate
        if model_class_exists? && model_class.column_names.include?("name")
          "name_cont: 'search'"
        elsif model_class_exists? && model_class.column_names.include?("title")
          "title_cont: 'search'"
        elsif model_class_exists? && model_class.column_names.include?("status")
          "status_eq: 'active'"
        else
          "id_eq: 1"
        end
      end

      def model_class_exists?
        return false unless Object.const_defined?(class_name)
        klass = class_name.constantize
        klass < ActiveRecord::Base && klass.table_exists?
      rescue NameError, ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
        false
      end

      def model_class
        class_name.constantize if model_class_exists?
      end

      def model_has_better_model_features?
        return false unless model_class_exists?
        model_class.respond_to?(:predicable_fields) ||
          model_class.respond_to?(:sortable_fields) ||
          model_class.respond_to?(:searchable_fields)
      end

      def display_available_features
        return unless model_class_exists?

        if model_class.respond_to?(:predicable_fields) && model_class.predicable_fields.any?
          say "  • Predicable fields: #{model_class.predicable_fields.to_a.join(', ')}", :white
        end

        if model_class.respond_to?(:sortable_fields) && model_class.sortable_fields.any?
          say "  • Sortable fields: #{model_class.sortable_fields.to_a.join(', ')}", :white
        end

        if model_class.respond_to?(:searchable_fields) && model_class.searchable_fields.any?
          say "  • Searchable fields: #{model_class.searchable_fields.to_a.join(', ')}", :white
        end
      end
    end
  end
end
