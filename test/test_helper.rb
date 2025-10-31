# Code Coverage
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/spec/"

  add_group "Concerns", "lib/better_model"
  add_group "Models", "test/dummy/app/models"

  minimum_coverage 80
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
require "rails/test_help"

# Enable transactional tests for automatic rollback
ActiveSupport::TestCase.use_transactional_tests = true

# Global setup to ensure clean database for each test
class ActiveSupport::TestCase
  setup do
    # Clean up all test data before each test to prevent pollution
    Article.delete_all
    if defined?(BetterModel::ArticleVersion)
      BetterModel::ArticleVersion.delete_all
    end
  end
end

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  # ActiveSupport::TestCase.fixtures :all  # Commented out - no fixtures in use, relying on transactional rollback
end
