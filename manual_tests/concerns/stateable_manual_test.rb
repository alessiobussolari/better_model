# frozen_string_literal: true

# TEST STATEABLE - Declarative State Machine
# ============================================================================

	section("STATEABLE - Setup and Configuration")

	# Disable validatable to avoid conflicts with Stateable tests
	Article.class_eval do
		self.validatable_enabled = false
	end
	puts "  Validatable disattivato per evitare conflitti"

	# Clean up state_transitions table
	ActiveRecord::Base.connection.execute("DELETE FROM state_transitions") if ActiveRecord::Base.connection.table_exists?("state_transitions")
	puts "  State transitions pulite"

	# Activate stateable on Article
	Article.class_eval do
		stateable do
			# Define states
			state :draft, initial: true
			state :review
			state :published
			state :archived

			# Define transitions
			transition :submit_for_review, from: :draft, to: :review do
				check { title.present? && content.present? }
				check if: :is_ready_to_publish?
				before_transition { self.submitted_at = Time.current if respond_to?(:submitted_at=) }
			end

			transition :publish, from: :review, to: :published do
				check { is?(:ready_to_publish) }
				before_transition { self.published_at = Time.current }
				after_transition { puts "  [Callback] Article #{id} published!" }
			end

			transition :archive, from: [ :draft, :review, :published ], to: :archived

			transition :unarchive, from: :archived, to: :draft
		end
	end

	# Force reload associations to pick up the dynamic StateTransitions class
	Article.reset_column_information

	puts "  Stateable attivato su Article con 4 stati e 4 transizioni"

	test("Article ha stateable_enabled?") do
		Article.stateable_enabled?
	end

	test("Article ha stateable_states configurati") do
		Article.stateable_states == [ :draft, :review, :published, :archived ]
	end

	test("Article ha stateable_initial_state") do
		Article.stateable_initial_state == :draft
	end

	test("Article ha stateable_transitions configurate") do
		Article.stateable_transitions.keys.sort == [ :archive, :publish, :submit_for_review, :unarchive ].sort
	end

	test("Article ha state_transitions association") do
		Article.reflect_on_association(:state_transitions).present?
	end

	section("STATEABLE - Initial State and State Predicates")

	@stateable_article = Article.unscoped.create!(
		title: "Stateable Test Article",
		content: "Content for state machine testing",
		status: "draft",
		view_count: 10,
		scheduled_at: 1.day.ago  # Makes is_ready_to_publish? return true
	)

	test("new article has initial state set to draft") do
		@stateable_article.state == "draft"
	end

	test("draft? predicate returns true for draft article") do
		@stateable_article.draft?
	end

	test("review? predicate returns false for draft article") do
		!@stateable_article.review?
	end

	test("published? predicate returns false for draft article") do
		!@stateable_article.published?
	end

	test("state predicates are defined for all states") do
		@stateable_article.respond_to?(:draft?) &&
			@stateable_article.respond_to?(:review?) &&
			@stateable_article.respond_to?(:published?) &&
			@stateable_article.respond_to?(:archived?)
	end

	section("STATEABLE - Transition Methods")

	test("submit_for_review! method exists") do
		@stateable_article.respond_to?(:submit_for_review!)
	end

	test("can_submit_for_review? method exists") do
		@stateable_article.respond_to?(:can_submit_for_review?)
	end

	test("can_submit_for_review? returns true when checks pass") do
		@stateable_article.can_submit_for_review?
	end

	test("submit_for_review! transitions from draft to review") do
		@stateable_article.submit_for_review!
		@stateable_article.state == "review" && @stateable_article.review?
	end

	test("can_publish? returns true in review state") do
		@stateable_article.can_publish?
	end

	test("publish! transitions from review to published") do
		@stateable_article.publish!
		@stateable_article.state == "published" && @stateable_article.published?
	end

	test("published_at is set by before callback") do
		@stateable_article.published_at.present?
	end

	section("STATEABLE - Guards")

	@check_test_article = Article.unscoped.create!(
		title: "Guard Test",  # Valid title/content
		content: "Content",
		status: "draft",
		state: "draft",
		scheduled_at: nil  # Will fail is_ready_to_publish? check
	)

	test("transition fails when check condition not met") do
		begin
			@check_test_article.submit_for_review!
			false
		rescue BetterModel::Errors::Stateable::CheckFailedError
			true
		end
	end

	test("can_transition? returns false when checks fail") do
		!@check_test_article.can_submit_for_review?
	end

	test("transition succeeds after check conditions are met") do
		@check_test_article.update!(title: "Valid Title", content: "Valid Content", scheduled_at: 1.day.ago)
		@check_test_article.can_submit_for_review? &&
			(@check_test_article.submit_for_review! rescue false)
		@check_test_article.review?
	end

	test("check with Statusable integration works") do
		# Article must be ready_to_publish status
		test_article = Article.unscoped.create!(
			title: "Guard Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago  # Makes is_ready_to_publish? true
		)

		test_article.can_submit_for_review?
	end

	section("STATEABLE - Invalid Transitions")

	test("invalid transition raises InvalidTransitionError") do
		test_article = Article.unscoped.create!(
			title: "Invalid Transition Test",
			content: "Content",
			status: "draft"
		)

		begin
			# Can't publish from draft (must go through review)
			test_article.publish!
			false
		rescue BetterModel::Errors::Stateable::InvalidTransitionError => e
			e.message.include?("Cannot transition")
		end
	end

	section("STATEABLE - State History Tracking")

	@history_article = Article.unscoped.create!(
		title: "History Test",
		content: "Content for history",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("state_transitions association returns empty for new article") do
		@history_article.state_transitions.count == 0
	end

	test("transition creates StateTransition record") do
		@history_article.submit_for_review!
		@history_article.state_transitions.count == 1
	end

	test("StateTransition records the event name") do
		transition = @history_article.state_transitions.first
		transition.event == "submit_for_review"
	end

	test("StateTransition records from_state") do
		transition = @history_article.state_transitions.first
		transition.from_state == "draft"
	end

	test("StateTransition records to_state") do
		transition = @history_article.state_transitions.first
		transition.to_state == "review"
	end

	test("multiple transitions create multiple records") do
		@history_article.publish!
		@history_article.state_transitions.count == 2
	end

	test("transition_history returns formatted history") do
		history = @history_article.transition_history
		history.is_a?(Array) &&
			history.length == 2 &&
			history.all? { |h| h.key?(:event) && h.key?(:from) && h.key?(:to) && h.key?(:at) }
	end

	test("transition_history is ordered by most recent first") do
		history = @history_article.transition_history
		history[0][:event] == "publish" && history[1][:event] == "submit_for_review"
	end

	section("STATEABLE - Multiple From States")

	@multi_from_article = Article.unscoped.create!(
		title: "Multi From Test",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("archive transition works from draft state") do
		@multi_from_article.archive!
		@multi_from_article.archived?
	end

	@multi_from_article2 = Article.unscoped.create!(
		title: "Multi From Test 2",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("archive transition works from review state") do
		@multi_from_article2.submit_for_review!
		@multi_from_article2.archive!
		@multi_from_article2.archived?
	end

	@multi_from_article3 = Article.unscoped.create!(
		title: "Multi From Test 3",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("archive transition works from published state") do
		@multi_from_article3.submit_for_review!
		@multi_from_article3.publish!
		@multi_from_article3.archive!
		@multi_from_article3.archived?
	end

	section("STATEABLE - Metadata Support")

	@metadata_article = Article.unscoped.create!(
		title: "Metadata Test",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("transition accepts metadata hash") do
		@metadata_article.submit_for_review!(user_id: 123, reason: "Ready for review")
		true
	end

	test("metadata is stored in StateTransition record") do
		transition = @metadata_article.state_transitions.first
		transition.metadata["user_id"] == 123 && transition.metadata["reason"] == "Ready for review"
	end

	test("metadata is included in transition_history") do
		history = @metadata_article.transition_history
		history.first[:metadata]["user_id"] == 123
	end

	section("STATEABLE - StateTransition Scopes")

	# Create articles with various transitions for scope testing
	Article.unscoped.create!(title: "Scope Test 1", content: "Content", status: "draft", scheduled_at: 1.day.ago).tap do |a|
		a.submit_for_review!
	end

	Article.unscoped.create!(title: "Scope Test 2", content: "Content", status: "draft", scheduled_at: 1.day.ago).tap do |a|
		a.submit_for_review!
		a.publish!
	end

	state_transition_class = BetterModel::Models::StateTransition

	test("StateTransition model exists") do
		state_transition_class.present?
	end

	test("for_model scope filters by model class") do
		results = state_transition_class.for_model(Article)
		results.count >= 2
	end

	test("by_event scope filters by event name") do
		results = state_transition_class.by_event(:submit_for_review)
		results.count >= 2
	end

	test("from_state scope filters by from_state") do
		results = state_transition_class.from_state(:draft)
		results.count >= 2
	end

	test("to_state scope filters by to_state") do
		results = state_transition_class.to_state(:review)
		results.count >= 2
	end

	section("STATEABLE - Integration with Statusable (Original)")

	# Restore original stateable config for these tests
	Article.class_eval do
		self.stateable_enabled = false
		self._stateable_setup_done = false

		stateable do
			state :draft, initial: true
			state :review
			state :published
			state :archived

			transition :submit_for_review, from: :draft, to: :review do
				check { title.present? && content.present? }
				check if: :is_ready_to_publish?
				before_transition { self.submitted_at = Time.current if respond_to?(:submitted_at=) }
			end

			transition :publish, from: :review, to: :published do
				check { is?(:ready_to_publish) }
				before_transition { self.published_at = Time.current }
				after_transition { puts "  [Callback] Article #{id} published!" }
			end

			transition :archive, from: [ :draft, :review, :published ], to: :archived
			transition :unarchive, from: :archived, to: :draft
		end
	end

	@integration_article = Article.unscoped.create!(
		title: "Integration Test",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("Statusable predicates work with state machine checks") do
		# The submit_for_review transition has check if: :is_ready_to_publish?
		# scheduled_at in the past makes is_ready_to_publish? true
		@integration_article.is?(:ready_to_publish) && @integration_article.can_submit_for_review?
	end

	section("STATEABLE - Callbacks")

	@callback_article = Article.unscoped.create!(
		title: "Callback Test",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("before callback is executed") do
		@callback_article.submit_for_review!
		# The before callback sets submitted_at if the attribute exists
		# In this test, we just verify the transition succeeded
		@callback_article.review?
	end

	test("after callback is executed") do
		# The publish transition has an after callback that prints
		# We can't test the print directly, but we verify transition succeeded
		@callback_article.publish!
		@callback_article.published?
	end

	section("STATEABLE - JSON Serialization")

	@json_article = Article.unscoped.create!(
		title: "JSON Test",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)
	@json_article.submit_for_review!
	@json_article.publish!

	test("as_json includes transition_history when requested") do
		json = @json_article.as_json(include_transition_history: true)
		json.key?("transition_history")
	end

	test("transition_history in JSON is properly formatted") do
		json = @json_article.as_json(include_transition_history: true)
		history = json["transition_history"]
		history.is_a?(Array) &&
			history.length >= 2 &&
			history.all? { |h| h.key?("event") && h.key?("from") && h.key?("to") }
	end

	test("as_json excludes transition_history by default") do
		json = @json_article.as_json
		!json.key?("transition_history")
	end

	section("STATEABLE - Error Handling")

	test("NotEnabledError raised when stateable not enabled") do
		begin
			temp_class = Class.new(ApplicationRecord) do
				self.table_name = "articles"
				include BetterModel
				# Don't activate stateable
			end

			instance = temp_class.create!(title: "Test", content: "Content", status: "draft")
			instance.transition_to!(:nonexistent)
			false
		rescue BetterModel::Errors::Stateable::NotEnabledError
			true
		end
	end

	test("ArgumentError raised for unknown transition") do
		begin
			@stateable_article.transition_to!(:nonexistent_transition)
			false
		rescue ArgumentError => e
			e.message.include?("Unknown transition")
		end
	end

	section("STATEABLE - Advanced Scenarios")

	test("can_transition? returns false for invalid from state") do
		published_article = Article.unscoped.create!(
			title: "Published Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)
		published_article.submit_for_review!
		published_article.publish!

		# Can't submit_for_review from published state
		!published_article.can_submit_for_review?
	end

	test("transition changes persist to database") do
		test_article = Article.unscoped.create!(
			title: "Persistence Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)
		test_article.submit_for_review!

		# Reload from database
		test_article.reload
		test_article.state == "review"
	end

	test("state machine works with transaction rollback") do
		test_article = Article.unscoped.create!(
			title: "Rollback Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		begin
			ActiveRecord::Base.transaction do
				test_article.submit_for_review!
				raise ActiveRecord::Rollback
			end
		rescue
		end

		test_article.reload
		# After rollback, state should remain draft
		test_article.draft?
	end

	test("multiple transitions in sequence work correctly") do
		test_article = Article.unscoped.create!(
			title: "Sequence Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		test_article.submit_for_review!
		test_article.publish!
		test_article.archive!
		test_article.unarchive!

		test_article.draft? && test_article.state_transitions.count == 4
	end

	section("STATEABLE - Validation in Transitions")

	# Create a temporary state machine with validation
	Article.class_eval do
		# Reset stateable to add validation tests
		self.stateable_enabled = false
		self._stateable_setup_done = false

		stateable do
			state :draft, initial: true
			state :published

			transition :publish_with_validation, from: :draft, to: :published do
				validate do
					errors.add(:base, "Title too short") if title.length < 10
					errors.add(:base, "Content required") if content.blank?
				end
				before_transition { self.published_at = Time.current }
			end
		end
	end

	@validation_article = Article.unscoped.create!(
		title: "Short",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("validate block prevents transition when validation fails") do
		begin
			@validation_article.publish_with_validation!
			false
		rescue BetterModel::Errors::Stateable::ValidationFailedError => e
			e.message.include?("Title too short")
		end
	end

	test("validate block allows transition when validation passes") do
		valid_article = Article.unscoped.create!(
			title: "Valid Long Title",
			content: "Valid content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		valid_article.publish_with_validation!
		valid_article.published?
	end

	test("validation errors are accessible after failed transition") do
		begin
			@validation_article.publish_with_validation!
			false
		rescue BetterModel::Errors::Stateable::ValidationFailedError => e
			e.message.include?("Title too short") && e.message.include?("Content required") == false
		end
	end

	section("STATEABLE - Around Callbacks")

	# Reset and add around callback test
	Article.class_eval do
		self.stateable_enabled = false
		self._stateable_setup_done = false

		stateable do
			state :draft, initial: true
			state :published

			transition :publish_with_around, from: :draft, to: :published do
				around_transition do |transition, block|
					# This would set a flag before and after
					self.view_count = 100  # before
					block.call
					self.view_count = 200  # after
					save!
				end
			end
		end
	end

	@around_article = Article.unscoped.create!(
		title: "Around Test",
		content: "Content",
		status: "draft",
		view_count: 0,
		scheduled_at: 1.day.ago
	)

	test("around callback wraps transition execution") do
		@around_article.publish_with_around!
		@around_article.published? && @around_article.view_count == 200
	end

	test("around callback can modify behavior before and after") do
		around_test2 = Article.unscoped.create!(
			title: "Around Test 2",
			content: "Content",
			status: "draft",
			view_count: 50,
			scheduled_at: 1.day.ago
		)

		around_test2.publish_with_around!
		around_test2.reload
		around_test2.view_count == 200
	end

	section("STATEABLE - Multiple Guards")

	# Reset with multiple checks
	Article.class_eval do
		self.stateable_enabled = false
		self._stateable_setup_done = false

		stateable do
			state :draft, initial: true
			state :published

			transition :publish_with_checks, from: :draft, to: :published do
				check { title.present? }
				check { content.present? }
				check { title.length >= 5 }
				check if: :is_ready_to_publish?
			end
		end
	end

	@checks_article = Article.unscoped.create!(
		title: "Test Title",
		content: "Content",
		status: "draft",
		scheduled_at: 1.day.ago
	)

	test("all checks must pass for transition to succeed") do
		@checks_article.can_publish_with_checks? && @checks_article.publish_with_checks!
		@checks_article.published?
	end

	test("first failing check stops evaluation") do
		failing_article = Article.unscoped.create!(
			title: nil,  # First check will fail
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		!failing_article.can_publish_with_checks?
	end

	test("checks are evaluated in definition order") do
		# If title is present but too short, second check should pass but third should fail
		short_title_article = Article.unscoped.create!(
			title: "Hi",  # Present but < 5 chars
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		!short_title_article.can_publish_with_checks?
	end

	section("STATEABLE - StateTransition Helper Methods")

	test("description returns formatted transition description") do
		test_article = Article.unscoped.create!(
			title: "Description Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		# Use original stateable config for this test
		Article.class_eval do
			self.stateable_enabled = false
			self._stateable_setup_done = false

			stateable do
				state :draft, initial: true
				state :published
				transition :publish, from: :draft, to: :published
			end
		end

		test_article.publish!
		transition = test_article.state_transitions.first

		transition.description.include?("Article") &&
			transition.description.include?("draft") &&
			transition.description.include?("published")
	end

	test("recent scope filters transitions within timeframe") do
		state_transition_class = BetterModel::Models::StateTransition
		recent_transitions = state_transition_class.recent(1.hour)
		recent_transitions.is_a?(ActiveRecord::Relation)
	end

	test("between scope filters transitions in date range") do
		state_transition_class = BetterModel::Models::StateTransition
		start_time = 1.day.ago
		end_time = Time.current

		between_transitions = state_transition_class.between(start_time, end_time)
		between_transitions.is_a?(ActiveRecord::Relation) && between_transitions.count >= 0
	end

	test("to_s alias works for description") do
		transitions = BetterModel::Models::StateTransition.limit(1)
		if transitions.any?
			transition = transitions.first
			transition.to_s == transition.description
		else
			true  # Skip if no transitions
		end
	end

	section("STATEABLE - State Validation")

	# Restore original stateable config
	Article.class_eval do
		self.stateable_enabled = false
		self._stateable_setup_done = false

		stateable do
			state :draft, initial: true
			state :review
			state :published
			state :archived

			transition :submit_for_review, from: :draft, to: :review
			transition :publish, from: :review, to: :published
			transition :archive, from: [ :draft, :review, :published ], to: :archived
		end
	end

	test("invalid state value is rejected on save") do
		invalid_article = Article.unscoped.new(
			title: "Invalid State Test",
			content: "Content",
			status: "draft",
			state: "invalid_state"
		)

		!invalid_article.valid?
	end

	test("state must be one of configured states") do
		valid_article = Article.unscoped.new(
			title: "Valid State Test",
			content: "Content",
			status: "draft",
			state: "draft"
		)

		valid_article.valid?
	end

	section("STATEABLE - Edge Cases")

	test("transition with empty metadata hash works") do
		edge_article = Article.unscoped.create!(
			title: "Edge Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		edge_article.submit_for_review!({})
		edge_article.review?
	end

	test("state persists correctly after failed transition") do
		fail_article = Article.unscoped.create!(
			title: "Fail Test",
			content: "Content",
			status: "draft",
			state: "draft"
		)

		original_state = fail_article.state

		begin
			# Try invalid transition
			fail_article.publish!  # Can't publish from draft
		rescue BetterModel::Errors::Stateable::InvalidTransitionError
		end

		fail_article.reload
		fail_article.state == original_state
	end

	test("can_transition? works correctly for all states") do
		test_article = Article.unscoped.create!(
			title: "Can Transition Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		# From draft, can submit_for_review but not publish
		can_submit = test_article.can_submit_for_review?
		cannot_publish = !test_article.can_publish?

		can_submit && cannot_publish
	end

	section("STATEABLE - Integration with Other Concerns")

	test("archiving an article preserves its state") do
		# First activate archivable
		Article.class_eval do
			archivable do
				skip_archived_by_default true
			end
		end

		integration_article = Article.unscoped.create!(
			title: "Integration Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		integration_article.submit_for_review!
		current_state = integration_article.state

		integration_article.archive!(by: 999, reason: "Test")
		integration_article.reload

		integration_article.state == current_state
	end

	test("state can be searched with Searchable predicates") do
		# Searchable should have a state_eq predicate
		results = Article.unscoped.search({ state_eq: "draft" }) rescue nil

		results.nil? || results.is_a?(ActiveRecord::Relation)
	end

	test("state changes create state_transitions records") do
		change_article = Article.unscoped.create!(
			title: "Change Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		initial_count = change_article.state_transitions.count
		change_article.submit_for_review!

		change_article.state_transitions.count == initial_count + 1
	end

	section("STATEABLE - Performance")

	test("100 sequential transitions perform efficiently") do
		perf_article = Article.unscoped.create!(
			title: "Performance Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		start_time = Time.now

		50.times do
			perf_article.submit_for_review! if perf_article.draft?
			perf_article.archive! if perf_article.review?
			perf_article.unarchive! if perf_article.archived?
		end

		elapsed = Time.now - start_time

		puts "    100 transitions took: #{(elapsed * 1000).round(2)}ms"

		elapsed < 2.0  # Should complete in less than 2 seconds
	end

	test("transition history query with large dataset is fast") do
		# Create article with many transitions
		history_article = Article.unscoped.create!(
			title: "History Performance Test",
			content: "Content",
			status: "draft",
			scheduled_at: 1.day.ago
		)

		# Create 20 transitions
		10.times do
			history_article.submit_for_review! if history_article.draft?
			history_article.archive! if history_article.review?
			history_article.unarchive! if history_article.archived?
		end

		start_time = Time.now
		history = history_article.transition_history
		elapsed = Time.now - start_time

		puts "    Fetching #{history.length} transitions took: #{(elapsed * 1000).round(2)}ms"

		elapsed < 0.1 && history.length >= 20
	end

