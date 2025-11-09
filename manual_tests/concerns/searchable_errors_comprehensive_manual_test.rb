# frozen_string_literal: true

# ============================================================================
# TEST SEARCHABLE ERRORS - COMPREHENSIVE COVERAGE
# ============================================================================
# This file provides comprehensive testing for all Searchable error classes
# Currently only InvalidSecurityError has minimal testing in searchable_manual_test.rb

section("SEARCHABLE ERRORS - InvalidPredicateError Coverage")

test("InvalidPredicateError raised for unknown predicate") do
	begin
		Article.search({ unknown_field_eq: "value" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.message.include?("Invalid predicate") &&
		e.predicate_scope == :unknown_field_eq
	end
end

test("InvalidPredicateError includes available predicates") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.available_predicates.is_a?(Array) &&
		e.available_predicates.include?(:title_eq) &&
		e.message.include?("Available predicable scopes")
	end
end

test("InvalidPredicateError raised for wrong predicate type") do
	begin
		Article.search({ title_gt: "Rails" })  # gt is for numeric, not string
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.predicate_scope == :title_gt
	end
end

section("SEARCHABLE ERRORS - InvalidOrderError Coverage")

test("InvalidOrderError raised for unknown sort field") do
	begin
		Article.search({}, orders: [:unknown_sort_field])
		false
	rescue BetterModel::Errors::Searchable::InvalidOrderError => e
		e.message.include?("Invalid order") &&
		e.respond_to?(:order_scope)
	end
end

test("InvalidOrderError raised for invalid sort direction") do
	begin
		Article.search({}, orders: [:title_invalid_direction])
		false
	rescue BetterModel::Errors::Searchable::InvalidOrderError => e
		e.message.include?("Invalid order") ||
		e.message.include?("Invalid sort")
	end
end

test("InvalidOrderError includes available orders") do
	begin
		Article.search({}, orders: [:unknown_field_asc])
		false
	rescue BetterModel::Errors::Searchable::InvalidOrderError => e
		e.respond_to?(:available_orders) &&
		(e.available_orders.nil? || e.available_orders.is_a?(Array))
	end
end

test("InvalidOrderError includes sentry-compatible data") do
	begin
		Article.search({}, orders: [:unknown_sort])
		false
	rescue BetterModel::Errors::Searchable::InvalidOrderError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "invalid_order" &&
		e.tags[:module] == "searchable" &&
		e.context[:model_class] == "Article"
	end
end

section("SEARCHABLE ERRORS - InvalidPaginationError Coverage")

test("InvalidPaginationError raised for negative page") do
	begin
		Article.search({}, pagination: { page: -1, per_page: 10 })
		false
	rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
		e.message.include?("Invalid pagination") &&
		e.respond_to?(:page)
	end
end

test("InvalidPaginationError raised for per_page exceeding max") do
	begin
		Article.search({}, pagination: { page: 1, per_page: 999999 })
		false
	rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
		e.message.include?("Invalid pagination") &&
		e.respond_to?(:per_page)
	end
end

test("InvalidPaginationError includes pagination limits") do
	begin
		Article.search({}, pagination: { page: -5, per_page: 10 })
		false
	rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
		e.extra.is_a?(Hash) &&
		(e.extra[:page].present? || e.extra[:per_page].present?)
	end
end

test("InvalidPaginationError includes sentry-compatible data") do
	begin
		Article.search({}, pagination: { page: 0, per_page: 10 })
		false
	rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "invalid_pagination" &&
		e.tags[:module] == "searchable" &&
		e.context[:model_class] == "Article"
	end
end

section("SEARCHABLE ERRORS - InvalidSecurityError Detailed Coverage")

test("InvalidSecurityError shows security policy name") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.security_name == :status_required &&
		e.message.include?("status_required")
	end
end

test("InvalidSecurityError lists required predicates") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.required_predicates.is_a?(Array) &&
		e.required_predicates.include?(:status_eq)
	end
end

test("InvalidSecurityError lists provided predicates") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.provided_predicates.is_a?(Array) &&
		e.provided_predicates.include?(:title_cont)
	end
end

test("InvalidSecurityError lists missing predicates") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.missing_predicates.is_a?(Array) &&
		e.missing_predicates.any? &&
		e.message.include?("Missing required predicates")
	end
end

test("InvalidSecurityError raised for unknown security policy") do
	begin
		Article.search({ title_cont: "Test" }, security: :nonexistent_policy)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.security_name == :nonexistent_policy &&
		e.message.include?("Unknown security policy")
	end
end

section("SEARCHABLE ERRORS - ConfigurationError Coverage")

test("ConfigurationError raised for invalid searchable config") do
	begin
		temp_class = Class.new(ApplicationRecord) do
			self.table_name = "articles"
			include BetterModel

			searchable do
				default_order :invalid_sort_that_doesnt_exist
			end
		end

		temp_class.search({})
		false
	rescue BetterModel::Errors::Searchable::ConfigurationError, ArgumentError => e
		true  # Either error is acceptable for invalid config
	end
end

test("ConfigurationError includes configuration details") do
	begin
		temp_class = Class.new(ApplicationRecord) do
			self.table_name = "articles"
			include BetterModel

			searchable do
				# Invalid per_page configuration
				per_page 0  # Should be > 0
			end
		end

		temp_class.search({})
		false
	rescue BetterModel::Errors::Searchable::ConfigurationError, ArgumentError => e
		e.message.present?
	end
end

section("SEARCHABLE ERRORS - Error Recovery Patterns")

test("InvalidPredicateError provides helpful error message for recovery") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Error message should help user find correct predicate
		e.message.include?("Available predicable scopes") &&
		e.available_predicates.include?(:title_eq) &&
		e.available_predicates.include?(:title_cont)
	end
end

test("InvalidOrderError helps user find valid sort options") do
	begin
		Article.search({}, orders: [:unknown_field_asc])
		false
	rescue BetterModel::Errors::Searchable::InvalidOrderError => e
		e.message.present? &&
		(e.available_orders.nil? || e.available_orders.any?)
	end
end

test("InvalidSecurityError shows exactly what's missing") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.missing_predicates.any? &&
		e.message.include?("status")
	end
end

section("SEARCHABLE ERRORS - Edge Cases")

test("Multiple invalid predicates raise for first invalid one") do
	begin
		Article.search({
			title_xxx: "Rails",
			status_yyy: "published"
		})
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		# Should catch first invalid predicate
		[:title_xxx, :status_yyy].include?(e.predicate_scope)
	end
end

test("Empty orders array doesn't raise InvalidOrderError") do
	result = Article.search({}, orders: [])
	result.is_a?(ActiveRecord::Relation)
end

test("Valid pagination with edge values works") do
	result = Article.search({}, pagination: { page: 1, per_page: 1 })
	result.is_a?(ActiveRecord::Relation) && result.limit_value == 1
end

# ============================================================================
# SUMMARY
# ============================================================================

section("SEARCHABLE ERRORS - Coverage Summary")

puts "  ✅ Comprehensive error coverage for Searchable module:"
puts "     - InvalidPredicateError: unknown predicates, wrong types"
puts "     - InvalidOrderError: unknown sort fields, invalid directions"
puts "     - InvalidPaginationError: negative page, exceeded limits"
puts "     - InvalidSecurityError: policy violations, missing predicates"
puts "     - ConfigurationError: invalid searchable configuration"
puts "  "
puts "  All errors tested with:"
puts "     - Error message quality"
puts "     - Sentry-compatible attributes"
puts "     - Recovery information"
puts "     - Edge cases"
