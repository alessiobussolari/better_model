# frozen_string_literal: true

# ============================================================================
# TEST STATUSABLE
# ============================================================================

section("STATUSABLE - Test Status Definitions")

test("Article ha defined_statuses") { Article.respond_to?(:defined_statuses) }
test("defined_statuses include :draft") { Article.defined_statuses.include?(:draft) }
test("defined_statuses include :published") { Article.defined_statuses.include?(:published) }
test("status_defined?(:draft) returns true") { Article.status_defined?(:draft) }
test("status_defined?(:nonexistent) returns false") { !Article.status_defined?(:nonexistent) }

section("STATUSABLE - Test Status Checks")

# Test is? method
test("draft.is?(:draft) is true") { @draft.is?(:draft) }
test("draft.is?(:published) is false") { !@draft.is?(:published) }
test("published.is?(:published) is true") { @published.is?(:published) }
test("scheduled.is?(:scheduled) is true") { @scheduled.is?(:scheduled) }
test("ready_to_publish.is?(:ready_to_publish) is true") { @ready_to_publish.is?(:ready_to_publish) }
test("expired.is?(:expired) is true") { @expired.is?(:expired) }
test("popular.is?(:popular) is true") { @popular.is?(:popular) }

# Test complex status
test("published.is?(:active) is true") { @published.is?(:active) }
test("expired.is?(:active) is false") { !@expired.is?(:active) }

# Test helper methods
test("draft.is_draft? exists") { @draft.respond_to?(:is_draft?) }
test("draft.is_draft? is true") { @draft.is_draft? }
test("draft.is_published? is false") { !@draft.is_published? }

# Test statuses method
test("draft.statuses returns hash") { @draft.statuses.is_a?(Hash) }
test("draft.statuses includes :draft") { @draft.statuses.key?(:draft) && @draft.statuses[:draft] == true }
test("published.statuses includes :published") { @published.statuses.key?(:published) && @published.statuses[:published] == true }
test("published.statuses includes :active") { @published.statuses.key?(:active) && @published.statuses[:active] == true }
