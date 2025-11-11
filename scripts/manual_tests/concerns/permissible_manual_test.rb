# frozen_string_literal: true

# ============================================================================
# TEST PERMISSIBLE
# ============================================================================

section("PERMISSIBLE - Test Permission Definitions")

test("Article ha defined_permissions") { Article.respond_to?(:defined_permissions) }
test("defined_permissions include :delete") { Article.defined_permissions.include?(:delete) }
test("defined_permissions include :edit") { Article.defined_permissions.include?(:edit) }
test("permission_defined?(:delete) returns true") { Article.permission_defined?(:delete) }
test("permission_defined?(:nonexistent) returns false") { !Article.permission_defined?(:nonexistent) }

section("PERMISSIBLE - Test Permission Checks")

# Test permit? method - delete permission
test("draft.permit?(:delete) is true") { @draft.permit?(:delete) }
test("published.permit?(:delete) is false") { !@published.permit?(:delete) }

# Test permit? method - edit permission
test("draft.permit?(:edit) is true") { @draft.permit?(:edit) }
test("published.permit?(:edit) is true") { @published.permit?(:edit) }
test("expired.permit?(:edit) is false") { !@expired.permit?(:edit) }

# Test permit? method - publish/unpublish
test("draft.permit?(:publish) is true") { @draft.permit?(:publish) }
test("published.permit?(:publish) is false") { !@published.permit?(:publish) }
test("published.permit?(:unpublish) is true") { @published.permit?(:unpublish) }
test("draft.permit?(:unpublish) is false") { !@draft.permit?(:unpublish) }

# Test permit? method - archive permission
test("old_article.permit?(:archive) is true") { @old_article.permit?(:archive) }
test("published.permit?(:archive) is false") { !@published.permit?(:archive) }

# Test helper methods
test("draft.permit_delete? exists") { @draft.respond_to?(:permit_delete?) }
test("draft.permit_delete? is true") { @draft.permit_delete? }
test("published.permit_delete? is false") { !@published.permit_delete? }

# Test permissions method
test("draft.permissions returns hash") { @draft.permissions.is_a?(Hash) }
test("draft.permissions includes :delete") { @draft.permissions.key?(:delete) && @draft.permissions[:delete] == true }
test("draft.permissions includes :edit") { @draft.permissions.key?(:edit) && @draft.permissions[:edit] == true }
test("draft.permissions includes :publish") { @draft.permissions.key?(:publish) && @draft.permissions[:publish] == true }
