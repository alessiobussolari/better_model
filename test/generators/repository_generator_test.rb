# frozen_string_literal: true

require "test_helper"
require "generators/better_model/repository/repository_generator"

module BetterModel
  module Generators
    class RepositoryGeneratorTest < Rails::Generators::TestCase
      tests BetterModel::Generators::RepositoryGenerator
      destination File.expand_path("../../tmp", __dir__)
      setup :prepare_destination

      # ========================================
      # Basic Generation Tests
      # ========================================

      test "generator runs without errors" do
        run_generator [ "Article" ]

        assert_file "app/repositories/article_repository.rb"
      end

      test "generates repository with correct class name" do
        run_generator [ "Article" ]

        assert_file "app/repositories/article_repository.rb" do |content|
          assert_match(/class ArticleRepository < ApplicationRepository/, content)
        end
      end

      test "generates repository with endless method syntax" do
        run_generator [ "Article" ]

        assert_file "app/repositories/article_repository.rb" do |content|
          assert_match(/def model_class = Article/, content)
        end
      end

      test "generates ApplicationRepository by default" do
        run_generator [ "Article" ]

        assert_file "app/repositories/application_repository.rb" do |content|
          assert_match(/class ApplicationRepository < BetterModel::Repositable::BaseRepository/, content)
        end
      end

      test "includes example methods in comments" do
        run_generator [ "Article" ]

        assert_file "app/repositories/article_repository.rb" do |content|
          assert_match(/# Add your custom query methods here/, content)
          assert_match(/# def active/, content)
          assert_match(/# def recent\(days: 7\)/, content)
        end
      end

      # ========================================
      # Option: --skip-base
      # ========================================

      test "with --skip-base does not create ApplicationRepository" do
        run_generator [ "Article", "--skip-base" ]

        assert_no_file "app/repositories/application_repository.rb"
      end

      test "with --skip-base inherits from BetterModel::Repositable::BaseRepository" do
        run_generator [ "Article", "--skip-base" ]

        assert_file "app/repositories/article_repository.rb" do |content|
          assert_match(/class ArticleRepository < BetterModel::Repositable::BaseRepository/, content)
        end
      end

      # ========================================
      # Option: --path
      # ========================================

      test "with --path creates repository in custom directory" do
        run_generator [ "Article", "--path", "app/services/repositories" ]

        assert_file "app/services/repositories/article_repository.rb"
        assert_file "app/services/repositories/application_repository.rb"
      end

      test "with --path and --skip-base creates only model repository" do
        run_generator [ "Article", "--path", "lib/repositories", "--skip-base" ]

        assert_file "lib/repositories/article_repository.rb"
        assert_no_file "lib/repositories/application_repository.rb"
      end

      # ========================================
      # Option: --namespace
      # ========================================

      test "with --namespace creates namespaced repository" do
        run_generator [ "Article", "--namespace", "Admin" ]

        assert_file "app/repositories/article_repository.rb" do |content|
          assert_match(/module Admin/, content)
          assert_match(/class ArticleRepository < ApplicationRepository/, content)
          assert_match(/def model_class = Article/, content)
          assert_match(/end\nend/, content) # Module end + Class end
        end
      end

      test "with --namespace and --skip-base uses correct base class" do
        run_generator [ "Article", "--namespace", "Admin", "--skip-base" ]

        assert_file "app/repositories/article_repository.rb" do |content|
          assert_match(/module Admin/, content)
          assert_match(/class ArticleRepository < BetterModel::Repositable::BaseRepository/, content)
        end
      end

      # ========================================
      # Multiple Model Names
      # ========================================

      test "works with singular model names" do
        run_generator [ "User" ]

        assert_file "app/repositories/user_repository.rb" do |content|
          assert_match(/class UserRepository < ApplicationRepository/, content)
          assert_match(/def model_class = User/, content)
        end
      end

      test "works with multi-word model names" do
        run_generator [ "BlogPost" ]

        assert_file "app/repositories/blog_post_repository.rb" do |content|
          assert_match(/class BlogPostRepository < ApplicationRepository/, content)
          assert_match(/def model_class = BlogPost/, content)
        end
      end

      test "works with underscored model names" do
        run_generator [ "admin_user" ]

        assert_file "app/repositories/admin_user_repository.rb" do |content|
          assert_match(/class AdminUserRepository < ApplicationRepository/, content)
          assert_match(/def model_class = AdminUser/, content)
        end
      end

      # ========================================
      # ApplicationRepository Already Exists
      # ========================================

      test "does not overwrite existing ApplicationRepository" do
        # Create ApplicationRepository first
        FileUtils.mkdir_p(File.join(destination_root, "app/repositories"))
        File.write(
          File.join(destination_root, "app/repositories/application_repository.rb"),
          "class ApplicationRepository\n  # Custom code\nend"
        )

        run_generator [ "Article" ]

        assert_file "app/repositories/application_repository.rb" do |content|
          assert_match(/# Custom code/, content)
          assert_no_match(/< BetterModel::Repositable::BaseRepository/, content)
        end
      end

      # ========================================
      # File Naming
      # ========================================

      test "generates file with correct naming conventions" do
        run_generator [ "ArticleComment" ]

        assert_file "app/repositories/article_comment_repository.rb"
      end

      test "repository file contains frozen string literal" do
        run_generator [ "Article" ]

        assert_file "app/repositories/article_repository.rb" do |content|
          assert_match(/# frozen_string_literal: true/, content)
        end
      end

      test "application repository file contains frozen string literal" do
        run_generator [ "Article" ]

        assert_file "app/repositories/application_repository.rb" do |content|
          assert_match(/# frozen_string_literal: true/, content)
        end
      end

      # ========================================
      # Multiple Runs
      # ========================================

      test "can generate multiple repositories" do
        run_generator [ "Article" ]
        run_generator [ "User" ]

        assert_file "app/repositories/article_repository.rb"
        assert_file "app/repositories/user_repository.rb"
        assert_file "app/repositories/application_repository.rb"
      end
    end
  end
end
