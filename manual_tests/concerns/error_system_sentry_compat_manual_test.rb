# frozen_string_literal: true

# ============================================================================
# TEST ERROR SYSTEM - SENTRY COMPATIBILITY v3.0.0
# ============================================================================
# This file tests the Sentry-compatible error structure introduced in v3.0.0
# All BetterModel errors should include:
# - tags: Filterable metadata for grouping/searching
# - context: High-level structured metadata
# - extra: Detailed debug data with all error-specific parameters

section("ERROR SYSTEM - Sentry Compatible Structure Overview")

puts "  Testing v3.0.0 Sentry-compatible error system"
puts "  All errors should include .tags, .context, .extra attributes"

# ============================================================================
# SEARCHABLE ERRORS - Sentry Compatibility
# ============================================================================

section("ERROR SYSTEM - Searchable::InvalidPredicateError")

test("InvalidPredicateError includes sentry tags") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "invalid_predicate" &&
		e.tags[:module] == "searchable" &&
		e.tags[:predicate].present?
	end
end

test("InvalidPredicateError includes sentry context") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.context.is_a?(Hash) &&
		e.context[:model_class] == "Article"
	end
end

test("InvalidPredicateError includes sentry extra") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.extra.is_a?(Hash) &&
		e.extra[:predicate_scope] == :title_xxx &&
		e.extra[:available_predicates].is_a?(Array)
	end
end

test("InvalidPredicateError provides attribute readers") do
	begin
		Article.search({ title_xxx: "Rails" })
		false
	rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
		e.respond_to?(:predicate_scope) &&
		e.respond_to?(:available_predicates) &&
		e.predicate_scope == :title_xxx
	end
end

section("ERROR SYSTEM - Searchable::InvalidSecurityError")

test("InvalidSecurityError includes sentry tags") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "invalid_security" &&
		e.tags[:module] == "searchable"
	end
end

test("InvalidSecurityError includes sentry context") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.context.is_a?(Hash) &&
		e.context[:model_class] == "Article"
	end
end

test("InvalidSecurityError includes sentry extra") do
	begin
		Article.search({ title_cont: "Test" }, security: :status_required)
		false
	rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
		e.extra.is_a?(Hash) &&
		e.extra[:security_name].present? &&
		e.extra[:required_predicates].is_a?(Array)
	end
end

# ============================================================================
# STATEABLE ERRORS - Sentry Compatibility
# ============================================================================

section("ERROR SYSTEM - Stateable::InvalidTransitionError")

test("InvalidTransitionError includes sentry tags") do
	article = Article.unscoped.create!(
		title: "Test Transition",
		content: "Content",
		status: "draft"
	)

	begin
		article.publish!  # Can't publish from draft
		false
	rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "transition" &&
		e.tags[:module] == "stateable" &&
		e.tags[:event] == "publish"
	end
end

test("InvalidTransitionError includes sentry context") do
	article = Article.unscoped.create!(
		title: "Test Transition",
		content: "Content",
		status: "draft"
	)

	begin
		article.publish!
		false
	rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
		e.context.is_a?(Hash) &&
		e.context[:model_class] == "Article"
	end
end

test("InvalidTransitionError includes sentry extra") do
	article = Article.unscoped.create!(
		title: "Test Transition",
		content: "Content",
		status: "draft"
	)

	begin
		article.publish!
		false
	rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
		e.extra.is_a?(Hash) &&
		e.extra[:event] == :publish &&
		e.extra[:from_state].present? &&
		e.extra[:to_state].present?
	end
end

test("InvalidTransitionError provides attribute readers") do
	article = Article.unscoped.create!(
		title: "Test Transition",
		content: "Content",
		status: "draft"
	)

	begin
		article.publish!
		false
	rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
		e.respond_to?(:event) &&
		e.respond_to?(:from_state) &&
		e.respond_to?(:to_state) &&
		e.event == :publish
	end
end

section("ERROR SYSTEM - Stateable::CheckFailedError")

test("CheckFailedError includes sentry tags") do
	check_article = Article.unscoped.create!(
		title: "Check Test",
		content: "Content",
		status: "draft",
		scheduled_at: nil  # Will fail check
	)

	begin
		check_article.submit_for_review!
		false
	rescue BetterModel::Errors::Stateable::CheckFailedError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "check_failed" &&
		e.tags[:module] == "stateable"
	end
end

test("CheckFailedError includes sentry context and extra") do
	check_article = Article.unscoped.create!(
		title: "Check Test",
		content: "Content",
		status: "draft",
		scheduled_at: nil
	)

	begin
		check_article.submit_for_review!
		false
	rescue BetterModel::Errors::Stateable::CheckFailedError => e
		e.context.is_a?(Hash) &&
		e.extra.is_a?(Hash) &&
		e.extra[:event].present?
	end
end

# ============================================================================
# ARCHIVABLE ERRORS - Sentry Compatibility
# ============================================================================

section("ERROR SYSTEM - Archivable::AlreadyArchivedError")

test("AlreadyArchivedError includes sentry tags") do
	# Create a fresh archived article to avoid stateable conflicts
	archived_article = Article.unscoped.create!(
		title: "Archived Test",
		content: "Content",
		status: "draft"  # Use draft to avoid stateable transitions
	)
	archived_article.update_column(:archived_at, 1.day.ago)  # Bypass callbacks
	archived_article.reload

	begin
		archived_article.archive!
		false
	rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "already_archived" &&
		e.tags[:module] == "archivable"
	end
end

test("AlreadyArchivedError includes sentry context") do
	# Create a fresh archived article to avoid stateable conflicts
	archived_article = Article.unscoped.create!(
		title: "Archived Test 2",
		content: "Content",
		status: "draft"  # Use draft to avoid stateable transitions
	)
	archived_article.update_column(:archived_at, 1.day.ago)  # Bypass callbacks
	archived_article.reload

	begin
		archived_article.archive!
		false
	rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
		e.context.is_a?(Hash) &&
		e.context[:model_class] == "Article"
	end
end

test("AlreadyArchivedError includes sentry extra") do
	# Create a fresh archived article to avoid stateable conflicts
	archived_article = Article.unscoped.create!(
		title: "Archived Test 3",
		content: "Content",
		status: "draft"  # Use draft to avoid stateable transitions
	)
	archived_article.update_column(:archived_at, 1.day.ago)  # Bypass callbacks
	archived_article.reload

	begin
		archived_article.archive!
		false
	rescue BetterModel::Errors::Archivable::AlreadyArchivedError => e
		e.extra.is_a?(Hash) &&
		e.extra[:archived_at].present?
	end
end

section("ERROR SYSTEM - Archivable::NotArchivedError")

test("NotArchivedError includes sentry tags") do
	active_article = Article.unscoped.not_archived.first

	begin
		active_article.restore!
		false
	rescue BetterModel::Errors::Archivable::NotArchivedError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "not_archived" &&
		e.tags[:module] == "archivable"
	end
end

test("NotArchivedError includes sentry context and extra") do
	active_article = Article.unscoped.not_archived.first

	begin
		active_article.restore!
		false
	rescue BetterModel::Errors::Archivable::NotArchivedError => e
		e.context.is_a?(Hash) &&
		e.context[:model_class] == "Article" &&
		e.extra.is_a?(Hash)
	end
end

# ============================================================================
# TRACEABLE ERRORS - Sentry Compatibility
# ============================================================================

section("ERROR SYSTEM - Traceable::NotEnabledError")

test("Traceable::NotEnabledError includes sentry tags") do
	begin
		temp_class = Class.new(ApplicationRecord) do
			self.table_name = "articles"
			include BetterModel
			# NON attiva traceable
		end

		instance = temp_class.new
		instance.changes_for(:status)
		false
	rescue BetterModel::Errors::Traceable::NotEnabledError => e
		e.tags.is_a?(Hash) &&
		e.tags[:error_category] == "not_enabled" &&
		e.tags[:module] == "traceable"
	end
end

test("Traceable::NotEnabledError includes sentry context") do
	begin
		temp_class = Class.new(ApplicationRecord) do
			self.table_name = "articles"
			include BetterModel
		end

		instance = temp_class.new
		instance.changes_for(:status)
		false
	rescue BetterModel::Errors::Traceable::NotEnabledError => e
		e.context.is_a?(Hash) &&
		e.context[:module_name].present?
	end
end

# ============================================================================
# SUMMARY - Sentry Compatibility Coverage
# ============================================================================

section("ERROR SYSTEM - Sentry Compatibility Summary")

puts "  ✅ Sentry-compatible structure verified on:"
puts "     - Searchable errors (InvalidPredicateError, InvalidSecurityError)"
puts "     - Stateable errors (InvalidTransitionError, CheckFailedError)"
puts "     - Archivable errors (AlreadyArchivedError, NotArchivedError)"
puts "     - Traceable errors (NotEnabledError)"
puts "  "
puts "  All errors include:"
puts "     - .tags   → Filterable metadata (error_category, module)"
puts "     - .context → High-level metadata (model_class)"
puts "     - .extra   → Detailed debug data (error-specific params)"
puts "  "
puts "  Ready for Sentry integration! 🎉"
