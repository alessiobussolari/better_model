# frozen_string_literal: true

require "test_helper"
require "generators/better_model/archivable/archivable_generator"

module BetterModel
  module Generators
    class ArchivableGeneratorTest < Rails::Generators::TestCase
      tests BetterModel::Generators::ArchivableGenerator
      destination File.expand_path("../../tmp", __dir__)
      setup :prepare_destination

      # ========================================
      # Basic Generation Tests
      # ========================================

      test "generator runs without errors" do
        run_generator [ "Article" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb"
      end

      test "generates migration with correct class name" do
        run_generator [ "Article" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/class AddArchivableToArticles/, content)
        end
      end

      test "generates migration with correct table name" do
        run_generator [ "Article" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/change_table :articles/, content)
        end
      end

      test "generates migration with archived_at column" do
        run_generator [ "Article" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/t\.datetime :archived_at/, content)
        end
      end

      test "generates migration with archived_at index by default" do
        run_generator [ "Article" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/add_index :articles, :archived_at/, content)
        end
      end

      # ========================================
      # Option: --with-tracking
      # ========================================

      test "with --with-tracking includes archived_by_id column" do
        run_generator [ "Article", "--with-tracking" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/t\.integer :archived_by_id/, content)
        end
      end

      test "with --with-tracking includes archive_reason column" do
        run_generator [ "Article", "--with-tracking" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/t\.string :archive_reason/, content)
        end
      end

      test "with --with-tracking includes archived_by_id index" do
        run_generator [ "Article", "--with-tracking" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/add_index :articles, :archived_by_id/, content)
        end
      end

      # ========================================
      # Option: --with-by
      # ========================================

      test "with --with-by includes only archived_by_id column" do
        run_generator [ "Article", "--with-by" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/t\.integer :archived_by_id/, content)
          assert_no_match(/t\.string :archive_reason/, content)
        end
      end

      test "with --with-by includes archived_by_id index" do
        run_generator [ "Article", "--with-by" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/add_index :articles, :archived_by_id/, content)
        end
      end

      # ========================================
      # Option: --with-reason
      # ========================================

      test "with --with-reason includes only archive_reason column" do
        run_generator [ "Article", "--with-reason" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/t\.string :archive_reason/, content)
          assert_no_match(/t\.integer :archived_by_id/, content)
        end
      end

      # ========================================
      # Option: --skip-indexes
      # ========================================

      test "with --skip-indexes does not add any indexes" do
        run_generator [ "Article", "--skip-indexes" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_no_match(/add_index/, content)
        end
      end

      test "with --with-tracking and --skip-indexes includes columns but no indexes" do
        run_generator [ "Article", "--with-tracking", "--skip-indexes" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          assert_match(/t\.datetime :archived_at/, content)
          assert_match(/t\.integer :archived_by_id/, content)
          assert_match(/t\.string :archive_reason/, content)
          assert_no_match(/add_index/, content)
        end
      end

      # ========================================
      # Multiple Model Names
      # ========================================

      test "works with singular model names" do
        run_generator [ "User" ]

        assert_migration "db/migrate/add_archivable_to_users.rb" do |content|
          assert_match(/class AddArchivableToUsers/, content)
          assert_match(/change_table :users/, content)
        end
      end

      test "works with multi-word model names" do
        run_generator [ "BlogPost" ]

        assert_migration "db/migrate/add_archivable_to_blog_posts.rb" do |content|
          assert_match(/class AddArchivableToBlogPosts/, content)
          assert_match(/change_table :blog_posts/, content)
        end
      end

      # ========================================
      # Migration Version
      # ========================================

      test "generates migration with current Rails version" do
        run_generator [ "Article" ]

        assert_migration "db/migrate/add_archivable_to_articles.rb" do |content|
          # Should include ActiveRecord::Migration with version
          assert_match(/ActiveRecord::Migration\[\d+\.\d+\]/, content)
        end
      end
    end
  end
end
