# frozen_string_literal: true

# ============================================================================
# TEST ERROR HANDLING - REAL-WORLD SCENARIOS
# ============================================================================
# This file tests production-like error handling patterns:
# - Rescue and re-raise
# - Error inspection for debugging
# - Error recovery patterns
# - Errors in transactions
# - Error context preservation

section("ERROR HANDLING - Rescue and Re-raise Patterns")

test("Rescue InvalidPredicateError and provide suggestion") do
	begin
		Article.search({ title_xxx: "Rails" })
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# In real app, might log error and show user-friendly message
		available = e.available_predicates
		suggestion = available.select { |p| p.to_s.start_with?("title_") }.first

		e.predicate_scope == :title_xxx &&
		suggestion.present? &&
		suggestion.to_s.start_with?("title_")
	end
end

test("Rescue and re-raise with additional context") do
	begin
		Article.search({ unknown_field: "value" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Re-raise with additional application context
		begin
			raise StandardError, "Search failed for user request: #{e.message}"
		rescue StandardError => new_error
			new_error.message.include?("Search failed") &&
			new_error.message.include?("Invalid predicate")
		end
	end
end

test("Catch multiple error types in rescue block") do
	errors_caught = []

	begin
		Article.search({ title_xxx: "Rails" })
	rescue BetterModel::Errors::Searchable::InvalidPredicateError,
	       BetterModel::Errors::Searchable::InvalidOrderError => e
		errors_caught << e.class.name
	end

	begin
		Article.search({}, orders: [:unknown_sort])
	rescue BetterModel::Errors::Searchable::InvalidPredicateError,
	       BetterModel::Errors::Searchable::InvalidOrderError => e
		errors_caught << e.class.name
	end

	errors_caught.length == 2
end

section("ERROR HANDLING - Error Inspection for Debugging")

test("Inspect error attributes for debugging") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Simulate debugging session
		debug_info = {
			error_class: e.class.name,
			message: e.message,
			predicate: e.predicate_scope,
			available: e.available_predicates.first(3),
			tags: e.tags,
			context: e.context,
			extra_keys: e.extra.keys
		}

		debug_info[:error_class].present? &&
		debug_info[:tags].is_a?(Hash) &&
		debug_info[:context].is_a?(Hash)
	end
end

test("Build error report from Sentry attributes") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Simulate building error report for monitoring
		report = {
			category: e.tags[:error_category],
			module: e.tags[:module],
			model: e.context[:model_class],
			details: e.extra
		}

		report[:category] == "invalid_predicate" &&
		report[:module] == "searchable" &&
		report[:model] == "Article" &&
		report[:details].is_a?(Hash)
	end
end

test("Extract all error-specific data from extra") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		# All error-specific params should be in extra
		e.extra[:security_name].present? &&
		e.extra[:required_predicates].is_a?(Array) &&
		e.extra[:provided_predicates].is_a?(Array) &&
		e.extra[:missing_predicates].is_a?(Array)
	end
end

section("ERROR HANDLING - Error Recovery Patterns")

test("Retry with corrected parameters after InvalidPredicateError") do
	attempts = 0
	result = nil

	begin
		attempts += 1
		if attempts == 1
			# First attempt with wrong predicate
			Article.search({ title_xxx: "Rails" })
		else
			# Retry with correct predicate
			Article.search({ title_cont: "Rails" })
		end
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Use error info to correct and retry
		retry if attempts < 2
	end

	attempts == 2
end

test("Fallback to default when InvalidOrderError occurs") do
	result = nil

	begin
		result = Article.search({}, orders: [:unknown_sort_field])
	rescue BetterModel::Errors::Searchable::InvalidOrderError => e
		# Fallback to default order
		result = Article.search({})
	end

	result.is_a?(ActiveRecord::Relation)
end

test("Use error.extra to determine recovery action") do
	recovery_action = nil

	begin
		Article.search({}, pagination: { page: -1, per_page: 10 })
	rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
		# Decide recovery based on what's in extra
		if e.extra[:page]&.negative?
			recovery_action = :reset_to_first_page
		end
	end

	recovery_action == :reset_to_first_page
end

section("ERROR HANDLING - Errors in Transaction Context")

test("Error preserves context across transaction rollback") do
	error_info = nil

	begin
		Article.unscoped.transaction do
			article = Article.unscoped.create!(
				title: "Transaction Test",
				content: "Content",
				status: "draft"
			)

			# Try invalid transition
			article.publish!  # Should fail
		end
	rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
		error_info = {
			event: e.event,
			from_state: e.from_state,
			to_state: e.to_state,
			tags: e.tags
		}
	end

	error_info.present? &&
	error_info[:event] == :publish &&
	error_info[:tags][:module] == "stateable"
end

test("Multiple errors in nested operations preserve context") do
	errors_collected = []

	begin
		Article.unscoped.transaction do
			# Try invalid search
			begin
				Article.search({ invalid_predicate: "value" })
			rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
				errors_collected << { type: :search, error: e }
				# Continue despite error
			end

			# Try invalid state transition
			article = Article.unscoped.create!(title: "Test", content: "Content", status: "draft")
			article.publish!  # Invalid transition
		end
	rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
		errors_collected << { type: :transition, error: e }
	end

	errors_collected.length == 2 &&
	errors_collected[0][:type] == :search &&
	errors_collected[1][:type] == :transition
end

section("ERROR HANDLING - Error Message Quality")

test("Error messages are actionable and helpful") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Message should tell user what's wrong AND how to fix it
		e.message.include?("Invalid predicate") &&
		e.message.include?("Available")
	end
end

test("Error messages include relevant values") do
	begin
		article = Article.unscoped.create!(title: "Test", content: "Content", status: "draft")
		article.publish!
		false
	rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
		# Message should show actual states involved
		e.message.include?("draft") &&
		(e.message.include?("publish") || e.message.include?("published"))
	end
end

test("NotEnabledError explains how to enable module") do
	begin
		temp_class = Class.new(ApplicationRecord) do
			self.table_name = "articles"
			include BetterModel
		end

		instance = temp_class.new
		instance.archive!
		false
	rescue BetterModel::Errors::Archivable::NotEnabledError => e
		# Should explain how to enable
		e.message.include?("not enabled") &&
		e.message.include?("archivable do")
	end
end

section("ERROR HANDLING - Sentry Integration Readiness")

test("Error can be passed directly to Sentry") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Simulate Sentry.capture_exception with scope
		sentry_data = {
			context: e.context,
			tags: e.tags,
			extra: e.extra
		}

		# Verify Sentry would receive correct data
		sentry_data[:context].is_a?(Hash) &&
		sentry_data[:tags].is_a?(Hash) &&
		sentry_data[:extra].is_a?(Hash) &&
		sentry_data[:tags][:error_category].present? &&
		sentry_data[:tags][:module].present?
	end
end

test("Multiple similar errors group correctly by tags") do
	errors = []

	# Generate multiple similar errors
	3.times do |i|
		begin
			Article.search({ "unknown_#{i}".to_sym => "value" })
		rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
			errors << e
		end
	end

	# All should have same error_category and module for grouping
	errors.all? { |e| e.tags[:error_category] == "invalid_predicate" } &&
	errors.all? { |e| e.tags[:module] == "searchable" }
end

section("ERROR HANDLING - Error Backtrace Preservation")

test("Error includes backtrace for debugging") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.backtrace.is_a?(Array) &&
		e.backtrace.any? &&
		e.backtrace.first.include?(".rb")
	end
end

test("Error class hierarchy is correct") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.is_a?(BetterModel::Errors::Searchable::SearchableError) &&
		e.is_a?(BetterModel::Errors::BetterModelError) &&
		e.is_a?(StandardError)
	end
end

# ============================================================================
# SUMMARY
# ============================================================================

section("ERROR HANDLING - Real-World Patterns Summary")

puts "  ✅ Production-ready error handling patterns tested:"
puts "     - Rescue/re-raise with context preservation"
puts "     - Error inspection for debugging"
puts "     - Error recovery with retry and fallback"
puts "     - Errors in transaction context"
puts "     - Multiple errors in nested operations"
puts "  "
puts "  Sentry integration verified:"
puts "     - Error data structure compatible"
puts "     - Error grouping by tags"
puts "     - Backtrace preservation"
puts "  "
puts "  Error quality verified:"
puts "     - Actionable error messages"
puts "     - Recovery information available"
puts "     - Helpful guidance for developers"
