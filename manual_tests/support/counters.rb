# frozen_string_literal: true

module ManualTests
  module Counters
    def initialize_counters
      @tests_passed = 0
      @tests_failed = 0
      @errors = []
    end

    def print_report
      puts "\n" + "=" * 80
      puts "  TEST SUMMARY"
      puts "=" * 80
      puts "  Total Tests: #{@tests_passed + @tests_failed}"
      puts "  Passed: #{@tests_passed}"
      puts "  Failed: #{@tests_failed}"

      if @tests_failed > 0
        puts "\n  Failed Tests:"
        @errors.each do |error|
          puts "    - #{error}"
        end
      end

      puts "=" * 80

      if @tests_failed == 0
        puts "  ✓ ALL TESTS PASSED!"
      else
        puts "  ✗ SOME TESTS FAILED"
      end
      puts "=" * 80
    end
  end
end
