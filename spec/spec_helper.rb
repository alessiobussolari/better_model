# frozen_string_literal: true

# Code Coverage - must be at the very top
require "simplecov"
require "simplecov-cobertura"

SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/test/"

  add_group "Concerns", "lib/better_model"
  add_group "Models", "spec/rails_app/app/models"

  # Output Cobertura XML for Codecov compatibility
  formatter SimpleCov::Formatter::CoberturaFormatter
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order to surface order dependencies
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option
  Kernel.srand config.seed
end
