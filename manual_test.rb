# frozen_string_literal: true

# Manual Testing Script per BetterModel
#
# IMPORTANT: This file is wrapped in a transaction with automatic rollback
# to prevent database pollution. All changes made during this script are
# automatically rolled back when the script completes.
#
# HOW TO USE:
#   cd test/dummy
#   rails console
#   load '../../manual_test.rb'
#
# NOTE: This file should NOT be auto-loaded during the test suite.
# If tests are finding unexpected "Perf Article" records, it means
# this file was executed outside of a transaction. Make sure to run
# it only via the console using 'load' command.

puts "\n" + "=" * 80
puts "  BETTERMODEL - MANUAL TESTING SCRIPT"
puts "=" * 80
puts "  (Running in transaction - all changes will be rolled back)"
puts "=" * 80

# Load support modules
require_relative "manual_tests/support/test_helpers"
require_relative "manual_tests/support/counters"
require_relative "manual_tests/support/fixtures"

# Wrap everything in a transaction with rollback
ActiveRecord::Base.transaction do
  # Include support modules to make helpers available
  include ManualTests::TestHelpers
  include ManualTests::Counters
  include ManualTests::Fixtures

  # Initialize counters
  initialize_counters

  # Setup test data (MUST run first)
  setup_fixtures

  # Load and execute test files in order
  # Note: Using 'load' instead of 'require_relative' to re-execute test code
  load File.expand_path("manual_tests/concerns/statusable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/permissible_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/sortable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/predicable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/validatable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/searchable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/archivable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/integration_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/traceable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/concerns/stateable_manual_test.rb", __dir__)
  load File.expand_path("manual_tests/performance_manual_test.rb", __dir__)

  # Print final report
  print_report

  # Force rollback to prevent database pollution
  raise ActiveRecord::Rollback
end

puts "\n  (Transaction rolled back - database unchanged)\n\n"
