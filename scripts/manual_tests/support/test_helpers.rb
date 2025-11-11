# frozen_string_literal: true

module ManualTests
  module TestHelpers
    # Helper method to get the Article's version class
    def article_version_class
      # ArticleVersion is dynamically created by Traceable
      BetterModel::ArticleVersion
    end

    def test(description)
      print "  #{description}... "
      result = yield
      if result
        puts "✓"
        @tests_passed += 1
      else
        puts "✗"
        @tests_failed += 1
        @errors << description
      end
      result
    rescue => e
      puts "✗ (ERROR: #{e.message})"
      @tests_failed += 1
      @errors << "#{description} - #{e.message}"
      false
    end

    def section(name)
      puts "\n" + "-" * 80
      puts "  #{name}"
      puts "-" * 80
    end
  end
end
