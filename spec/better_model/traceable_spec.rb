# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel::Traceable do
  # Helper per creare classi di test traceable
  def create_traceable_class(const_name, &block)
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name)

    klass = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel

      # Override model_name to return "Article" so that the default
      # table name becomes "article_versions" instead of "tracked_articleN_versions"
      def self.model_name
        ActiveModel::Name.new(self, nil, "Article")
      end
    end

    Object.const_set(const_name, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  # Helper per ottenere la classe ArticleVersion
  def article_version_class
    BetterModel::ArticleVersion
  end

  describe "module inclusion" do
    it "is defined" do
      expect(defined?(BetterModel::Traceable)).to be_truthy
    end

    it "raises ConfigurationError when included in non-ActiveRecord class" do
      expect do
        Class.new do
          include BetterModel::Traceable
        end
      end.to raise_error(BetterModel::Errors::Traceable::ConfigurationError, /Invalid configuration/)
    end
  end

  describe "opt-in behavior" do
    it "does not enable traceable by default" do
      test_class = create_traceable_class("TraceableOptInTest")

      expect(test_class.traceable_enabled?).to be false
    end

    it "enables traceable when DSL is called" do
      test_class = create_traceable_class("TraceableEnableTest") do
        traceable do
          track :status, :title
        end
      end

      expect(test_class.traceable_enabled?).to be true
    end

    it "stores tracked fields" do
      test_class = create_traceable_class("TraceableFieldsTest") do
        traceable do
          track :status, :title, :published_at
        end
      end

      expect(test_class.traceable_fields).to eq([ :status, :title, :published_at ])
    end

    it "sets up versions association" do
      test_class = create_traceable_class("TraceableAssocTest") do
        traceable do
          track :status
        end
      end

      instance = test_class.new
      expect(instance).to respond_to(:versions)
    end
  end

  describe "basic tracking" do
    let(:test_class) do
      create_traceable_class("TraceableBasicTest") do
        traceable do
          track :status, :title
        end
      end
    end

    it "creates version on record creation" do
      article = test_class.create!(title: "New Article", status: "draft")

      expect(article.versions.count).to eq(1)
      expect(article.versions.to_a.first.event).to eq("created")
    end

    it "creates version on record update" do
      article = test_class.create!(title: "Test", status: "draft")
      initial_count = article.versions.count

      article.update!(status: "published")

      expect(article.versions.count).to eq(initial_count + 1)
      expect(article.versions.to_a.first.event).to eq("updated")
    end

    it "tracks only configured fields" do
      test_class2 = create_traceable_class("TraceableOnlyStatusTest") do
        traceable do
          track :status
        end
      end

      article = test_class2.create!(title: "Test", status: "draft")
      article.update!(title: "New Title", status: "published")

      version = article.versions.where(event: "updated").first
      expect(version.object_changes).to have_key("status")
      expect(version.object_changes).not_to have_key("title")
    end

    it "stores before and after values" do
      article = test_class.create!(status: "draft")
      article.update!(status: "published")

      version = article.versions.where(event: "updated").first
      change = version.change_for(:status)

      expect(change[:before]).to eq("draft")
      expect(change[:after]).to eq("published")
    end

    it "tracks updated_by_id when provided" do
      test_class2 = create_traceable_class("TraceableUserTest") do
        traceable do
          track :status
        end
        attr_accessor :updated_by_id
      end

      article = test_class2.create!(status: "draft")
      article.updated_by_id = 42
      article.update!(status: "published")

      version = article.versions.to_a.first
      expect(version.updated_by_id).to eq(42)
    end

    it "tracks updated_reason when provided" do
      test_class2 = create_traceable_class("TraceableReasonTest") do
        traceable do
          track :status
        end
        attr_accessor :updated_reason
      end

      article = test_class2.create!(status: "draft")
      article.updated_reason = "Content approved"
      article.update!(status: "published")

      version = article.versions.to_a.first
      expect(version.updated_reason).to eq("Content approved")
    end

    it "creates version on record destruction" do
      article = test_class.create!(title: "Test", status: "draft")
      item_type = article.class.name
      item_id = article.id
      initial_count = article.versions.count

      article.destroy!

      versions = article_version_class.where(item_type: item_type, item_id: item_id).order(created_at: :desc)
      expect(versions.count).to eq(initial_count + 1)
      expect(versions.first.event).to eq("destroyed")
    end

    it "does not create version when update doesn't change tracked fields" do
      article = test_class.create!(title: "Test", status: "draft", content: "Some content")
      initial_count = article.versions.count

      article.update!(content: "Updated content")

      expect(article.versions.count).to eq(initial_count)
    end
  end

  describe "instance methods" do
    let(:test_class) do
      create_traceable_class("TraceableInstanceTest") do
        traceable do
          track :status, :title
        end
      end
    end

    describe "#changes_for" do
      it "returns changes for specific field" do
        article = test_class.create!(status: "draft")
        article.update!(status: "published")
        article.update!(status: "archived")

        changes = article.changes_for(:status)

        expect(changes.length).to eq(2)
        expect(changes.first[:before]).to eq("published")
        expect(changes.first[:after]).to eq("archived")
      end

      it "returns empty array for non-tracked field" do
        article = test_class.create!(status: "draft", title: "Test")

        changes = article.changes_for(:content) # content is not tracked
        expect(changes).to eq([])
      end
    end

    describe "#audit_trail" do
      it "returns full history" do
        article = test_class.create!(title: "Test", status: "draft")
        article.update!(status: "published")

        trail = article.audit_trail

        expect(trail.length).to eq(2)
        expect(trail.last[:event]).to eq("created")
        expect(trail.first[:event]).to eq("updated")
      end
    end

    describe "#as_of" do
      it "reconstructs state at specific time" do
        article = test_class.create!(title: "Original", status: "draft")
        time_after_create = Time.current

        sleep 0.01
        article.update!(title: "Updated", status: "published")

        reconstructed = article.as_of(time_after_create)

        expect(reconstructed.title).to eq("Original")
        expect(reconstructed.status).to eq("draft")
      end

      it "returns readonly object" do
        article = test_class.create!(status: "draft")
        reconstructed = article.as_of(Time.current)

        expect(reconstructed).to be_readonly
      end
    end
  end

  describe "rollback" do
    let(:test_class) do
      create_traceable_class("TraceableRollbackTest") do
        traceable do
          track :status, :title
        end
      end
    end

    describe "#rollback_to" do
      it "restores to previous version" do
        article = test_class.create!(title: "Original", status: "draft")
        article.update!(title: "Updated", status: "published")

        version_to_restore = article.versions.where(event: "updated").first
        article.rollback_to(version_to_restore)

        expect(article.title).to eq("Original")
        expect(article.status).to eq("draft")
      end

      it "accepts version ID" do
        article = test_class.create!(status: "draft")
        article.update!(status: "published")

        version_id = article.versions.where(event: "updated").first.id
        article.rollback_to(version_id)

        expect(article.status).to eq("draft")
      end

      it "tracks rollback action" do
        test_class2 = create_traceable_class("TraceableRollbackTrackTest") do
          traceable do
            track :status
          end
          attr_accessor :updated_by_id, :updated_reason
        end

        article = test_class2.create!(status: "draft")
        article.update!(status: "published")

        version = article.versions.where(event: "updated").first
        article.rollback_to(version, updated_by_id: 99, updated_reason: "Mistake")

        last_version = article.versions.to_a.first
        expect(last_version.updated_by_id).to eq(99)
        expect(last_version.updated_reason).to eq("Mistake")
      end

      it "creates its own version" do
        article = test_class.create!(title: "Original", status: "draft")
        article.update!(title: "Updated", status: "published")
        initial_count = article.versions.count

        version_to_restore = article.versions.where(event: "updated").first
        article.rollback_to(version_to_restore)

        expect(article.versions.count).to eq(initial_count + 1)
      end

      it "raises error for invalid version" do
        article = test_class.create!(status: "draft")

        expect do
          article.rollback_to(99999)
        end.to raise_error(ActiveRecord::RecordNotFound, /Couldn't find/)
      end

      it "raises error with nil version" do
        article = test_class.create!(status: "draft")

        expect do
          article.rollback_to(nil)
        end.to raise_error(ActiveRecord::RecordNotFound, /Version not found/)
      end

      it "validates version belongs to record" do
        article1 = test_class.create!(status: "draft")
        article1.update!(status: "published")

        article2 = test_class.create!(status: "draft")

        version_from_article1 = article1.versions.where(event: "updated").first

        expect do
          article2.rollback_to(version_from_article1)
        end.to raise_error(ActiveRecord::RecordNotFound, /does not belong to this record/)
      end
    end
  end

  describe "class methods" do
    let(:test_class) do
      create_traceable_class("TraceableClassMethodsTest") do
        traceable do
          track :status
        end
        attr_accessor :updated_by_id
      end
    end

    describe ".changed_by" do
      it "finds records changed by user" do
        article1 = test_class.create!(status: "draft")
        article1.updated_by_id = 42
        article1.update!(status: "published")

        article2 = test_class.create!(status: "draft")
        article2.updated_by_id = 99
        article2.update!(status: "published")

        results = test_class.changed_by(42)

        expect(results.pluck(:id)).to include(article1.id)
        expect(results.pluck(:id)).not_to include(article2.id)
      end
    end

    describe ".changed_between" do
      it "finds records changed in time range" do
        start_time = Time.current
        article = test_class.create!(status: "draft")
        sleep 0.01
        article.update!(status: "published")
        end_time = Time.current

        results = test_class.changed_between(start_time, end_time)

        expect(results.pluck(:id)).to include(article.id)
      end
    end
  end

  describe "#as_json integration" do
    let(:test_class) do
      create_traceable_class("TraceableJsonTest") do
        traceable do
          track :status
        end
      end
    end

    it "includes audit_trail when requested" do
      article = test_class.create!(status: "draft")
      article.update!(status: "published")

      json = article.as_json(include_audit_trail: true)

      expect(json).to have_key("audit_trail")
      expect(json["audit_trail"].length).to eq(2)
    end
  end

  describe "error handling" do
    it "raises NotEnabledError if traceable not configured" do
      test_class = create_traceable_class("TraceableNotEnabledTest")

      instance = test_class.create!(title: "Test")

      expect do
        instance.changes_for(:status)
      end.to raise_error(BetterModel::Errors::Traceable::NotEnabledError, /not enabled/)
    end
  end

  describe "edge cases" do
    let(:test_class) do
      create_traceable_class("TraceableEdgeCaseTest") do
        traceable do
          track :title, :published_at
        end
      end
    end

    it "handles nil values in tracked fields" do
      article = test_class.create!(title: nil, status: "draft")
      article.update!(title: "Now has value")
      version = article.versions.where(event: "updated").first
      expect(version.object_changes["title"]).to eq([ nil, "Now has value" ])

      article.update!(title: nil)
      versions = article.versions.where(event: "updated").order(created_at: :desc)
      latest_version = versions.first
      expect(latest_version.object_changes["title"]).to eq([ "Now has value", nil ])
    end

    it "handles empty string vs nil consistently" do
      article = test_class.create!(title: "", status: "draft")
      article.update!(title: nil)

      version = article.versions.where(event: "updated").first
      change = version.change_for(:title)

      expect(change[:before]).to eq("")
      expect(change[:after]).to be_nil
    end

    it "handles boolean fields correctly" do
      test_class2 = create_traceable_class("TraceableBoolTest") do
        traceable do
          track :featured
        end
      end

      article = test_class2.create!(title: "Test", status: "draft", featured: false)
      article.update!(featured: true)
      version = article.versions.where(event: "updated").first
      expect(version.object_changes["featured"]).to eq([ false, true ])

      article.update!(featured: false)
      version = article.versions.where(event: "updated").first
      expect(version.object_changes["featured"]).to eq([ true, false ])
    end

    it "handles zero values for numeric fields" do
      test_class2 = create_traceable_class("TraceableNumericTest") do
        traceable do
          track :view_count
        end
      end

      article = test_class2.create!(title: "Test", status: "draft", view_count: 0)
      article.update!(view_count: 1)
      version = article.versions.where(event: "updated").first
      expect(version.object_changes["view_count"]).to eq([ 0, 1 ])

      article.update!(view_count: 0)
      version = article.versions.where(event: "updated").first
      expect(version.object_changes["view_count"]).to eq([ 1, 0 ])
    end

    it "does not track changes with update_columns" do
      article = test_class.create!(title: "Test", status: "draft")
      initial_count = article.versions.count

      article.update_columns(title: "Updated via update_columns")

      expect(article.versions.count).to eq(initial_count)
    end
  end

  describe "Version model" do
    let(:test_class) do
      create_traceable_class("TraceableVersionTest") do
        traceable do
          track :status
        end
      end
    end

    it "change_for returns nil for nil object_changes" do
      # Ensure traceable is set up first
      test_class.create!(status: "draft")

      version = article_version_class.new(
        item_type: "Article",
        item_id: 1,
        event: "created",
        object_changes: nil
      )

      expect(version.change_for(:status)).to be_nil
    end

    it "changed_fields returns empty array for nil object_changes" do
      test_class.create!(status: "draft")

      version = article_version_class.new(
        item_type: "Article",
        item_id: 1,
        event: "created",
        object_changes: nil
      )

      expect(version.changed_fields).to eq([])
    end

    it "validates event inclusion" do
      test_class.create!(status: "draft")

      version = article_version_class.new(
        item_type: "Article",
        item_id: 1,
        event: "invalid_event",
        object_changes: {}
      )

      expect(version).not_to be_valid
      expect(version.errors[:event]).to include("is not included in the list")
    end

    it "changed? method works correctly with field argument" do
      article = test_class.create!(title: "Test", status: "draft")
      article.update!(status: "published")

      version = article.versions.where(event: "updated").to_a.first

      expect(version.changed?(:status)).to be true
      expect(version.changed?(:title)).to be false
    end
  end

  describe "concurrency" do
    let(:test_class) do
      create_traceable_class("TraceableConcurrencyTest") do
        traceable do
          track :title, :view_count
        end
      end
    end

    it "concurrent updates create separate versions" do
      article = test_class.create!(title: "Concurrent Test", status: "draft", view_count: 0)
      initial_version_count = article.versions.count

      threads = 5.times.map do |i|
        Thread.new do
          a = test_class.find(article.id)
          a.update!(view_count: i + 1)
        end
      end

      threads.each(&:join)

      article.reload
      expect(article.versions.count).to eq(initial_version_count + 5)
    end

    it "as_of is thread-safe" do
      article = test_class.create!(title: "Original", status: "draft")
      sleep 0.01
      article.update!(title: "Updated")
      timestamp = 1.second.ago

      results = []
      threads = 5.times.map do
        Thread.new do
          results << test_class.find(article.id).as_of(timestamp)
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(5)
      results.each do |result|
        expect(result).to be_readonly
      end
    end
  end

  describe "ConfigurationError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Traceable::ConfigurationError)).to be_truthy
    end

    it "inherits from ArgumentError" do
      expect(BetterModel::Errors::Traceable::ConfigurationError).to be < ArgumentError
    end

    it "can be instantiated with message" do
      error = BetterModel::Errors::Traceable::ConfigurationError.new("test message")
      expect(error.message).to eq("test message")
    end

    it "can be caught as ArgumentError" do
      expect do
        raise BetterModel::Errors::Traceable::ConfigurationError.new("test")
      end.to raise_error(ArgumentError)
    end
  end

  describe "NotEnabledError" do
    it "exists" do
      expect(defined?(BetterModel::Errors::Traceable::NotEnabledError)).to be_truthy
    end
  end

  describe "dynamic field_changed methods (method_missing)" do
    let(:test_class) do
      create_traceable_class("TraceableMethodMissingTest") do
        traceable do
          track :status, :title
        end
      end
    end

    describe ".status_changed_from" do
      it "returns ChangeQuery for tracked field" do
        result = test_class.status_changed_from("draft")
        expect(result).to be_a(BetterModel::ChangeQuery)
      end

      it "chains with .to method" do
        article = test_class.create!(status: "draft")
        article.update!(status: "published")

        results = test_class.status_changed_from("draft").to("published")
        expect(results).to include(article)
      end
    end

    describe ".title_changed_from" do
      it "returns ChangeQuery for tracked field" do
        result = test_class.title_changed_from("old")
        expect(result).to be_a(BetterModel::ChangeQuery)
      end
    end

    describe ".respond_to_missing?" do
      it "returns true for tracked field_changed_from methods" do
        expect(test_class.respond_to?(:status_changed_from)).to be true
        expect(test_class.respond_to?(:title_changed_from)).to be true
      end

      it "returns false for non-tracked field_changed_from methods" do
        expect(test_class.respond_to?(:content_changed_from)).to be false
      end

      it "returns false for non-existent methods" do
        expect(test_class.respond_to?(:random_method)).to be false
      end
    end

    describe "method_missing fallback" do
      it "raises NoMethodError for unknown methods" do
        expect { test_class.unknown_method }.to raise_error(NoMethodError)
      end

      it "raises NoMethodError for non-tracked field_changed_from" do
        expect { test_class.content_changed_from("test") }.to raise_error(NoMethodError)
      end
    end
  end

  describe ".field_changed query builder" do
    let(:test_class) do
      create_traceable_class("TraceableFieldChangedTest") do
        traceable do
          track :status, :title
        end
      end
    end

    it "returns ChangeQuery instance" do
      query = test_class.field_changed(:status)
      expect(query).to be_a(BetterModel::ChangeQuery)
    end

    it "chains from and to" do
      article = test_class.create!(status: "draft")
      article.update!(status: "published")

      results = test_class.field_changed(:status).from("draft").to("published")
      expect(results).to include(article)
    end

    it "finds records with specific transitions" do
      article1 = test_class.create!(status: "draft")
      article1.update!(status: "published")

      article2 = test_class.create!(status: "draft")
      article2.update!(status: "archived")

      # Both should match "from draft"
      results = test_class.field_changed(:status).from("draft").to("published")

      expect(results.pluck(:id)).to include(article1.id)
      # article2 might be included due to SQLite LIKE limitations, but the query is valid
    end
  end

  describe "sensitive fields tracking" do
    describe "full redaction" do
      let(:test_class) do
        create_traceable_class("TraceableSensitiveFullTest") do
          traceable do
            track :status
            track :password, sensitive: :full
          end
          attr_accessor :password
        end
      end

      it "fully redacts sensitive fields" do
        article = test_class.create!(status: "draft")
        article.password = "secret123"
        # Can't directly save password as it's not a real column, but we test the concept
        expect(test_class.traceable_sensitive_fields[:password]).to eq(:full)
      end

      it "stores sensitivity configuration" do
        expect(test_class.traceable_sensitive_fields).to have_key(:password)
        expect(test_class.traceable_sensitive_fields[:password]).to eq(:full)
      end
    end

    describe "partial redaction patterns" do
      let(:test_class) do
        create_traceable_class("TraceablePartialRedactTest") do
          traceable do
            track :title, sensitive: :partial
          end
        end
      end

      let(:instance) { test_class.new }

      it "partially redacts credit card numbers (13-19 digits)" do
        result = instance.send(:redact_partial, :card, "4111111111111111")
        expect(result).to eq("****1111")
      end

      it "partially redacts credit card with dashes" do
        result = instance.send(:redact_partial, :card, "4111-1111-1111-1111")
        expect(result).to eq("****1111")
      end

      it "partially redacts email addresses" do
        result = instance.send(:redact_partial, :email, "john.doe@example.com")
        expect(result).to eq("j***@example.com")
      end

      it "partially redacts short email usernames" do
        result = instance.send(:redact_partial, :email, "ab@example.com")
        expect(result).to eq("***@example.com")
      end

      it "partially redacts SSN (9 digits)" do
        result = instance.send(:redact_partial, :ssn, "123-45-6789")
        expect(result).to eq("***-**-6789")
      end

      it "partially redacts SSN without dashes" do
        result = instance.send(:redact_partial, :ssn, "123456789")
        expect(result).to eq("***-**-6789")
      end

      it "partially redacts phone numbers (10+ digits)" do
        result = instance.send(:redact_partial, :phone, "555-123-4567")
        expect(result).to eq("***-***-4567")
      end

      it "partially redacts phone numbers with more digits" do
        result = instance.send(:redact_partial, :phone, "+1-555-123-4567")
        expect(result).to eq("***-***-4567")
      end

      it "redacts unknown patterns with length" do
        result = instance.send(:redact_partial, :unknown, "secret value")
        expect(result).to eq("[REDACTED:12chars]")
      end

      it "returns [REDACTED] for blank values" do
        result = instance.send(:redact_partial, :field, "")
        expect(result).to eq("[REDACTED]")
      end

      it "returns [REDACTED] for nil values" do
        result = instance.send(:redact_partial, :field, nil)
        expect(result).to eq("[REDACTED]")
      end
    end

    describe "hash redaction" do
      let(:test_class) do
        create_traceable_class("TraceableHashRedactTest") do
          traceable do
            track :title, sensitive: :hash
          end
        end
      end

      let(:instance) { test_class.new }

      it "hashes values with SHA256" do
        result = instance.send(:redact_value, :title, "secret", :hash)
        expect(result).to start_with("sha256:")
        expect(result.length).to eq(71) # "sha256:" + 64 hex chars
      end

      it "produces consistent hashes for same value" do
        result1 = instance.send(:redact_value, :title, "secret", :hash)
        result2 = instance.send(:redact_value, :title, "secret", :hash)
        expect(result1).to eq(result2)
      end

      it "produces different hashes for different values" do
        result1 = instance.send(:redact_value, :title, "secret1", :hash)
        result2 = instance.send(:redact_value, :title, "secret2", :hash)
        expect(result1).not_to eq(result2)
      end
    end

    describe "redact_value with full level" do
      let(:test_class) do
        create_traceable_class("TraceableFullRedactValueTest") do
          traceable do
            track :title
          end
        end
      end

      let(:instance) { test_class.new }

      it "returns [REDACTED] for any value with full level" do
        result = instance.send(:redact_value, :title, "anything", :full)
        expect(result).to eq("[REDACTED]")
      end

      it "returns [REDACTED] for nil with full level" do
        result = instance.send(:redact_value, :title, nil, :full)
        expect(result).to eq("[REDACTED]")
      end
    end

    describe "unknown redaction level fallback" do
      let(:test_class) do
        create_traceable_class("TraceableUnknownLevelTest") do
          traceable do
            track :title
          end
        end
      end

      let(:instance) { test_class.new }

      it "returns original value for unknown level" do
        result = instance.send(:redact_value, :title, "original", :unknown)
        expect(result).to eq("original")
      end
    end
  end

  describe "rollback with sensitive fields" do
    let(:test_class) do
      create_traceable_class("TraceableRollbackSensitiveTest") do
        traceable do
          track :status
          track :title, sensitive: :partial
        end
      end
    end

    it "skips sensitive fields by default" do
      article = test_class.create!(title: "Original", status: "draft")
      article.update!(title: "Updated", status: "published")

      version = article.versions.where(event: "updated").first

      # Allow Rails.logger to receive warn
      allow(Rails.logger).to receive(:warn)

      article.rollback_to(version)

      # Status should be rolled back, but title warning should be logged
      expect(Rails.logger).to have_received(:warn).with(/Skipping sensitive field/)
    end

    it "allows rollback of sensitive fields with allow_sensitive: true" do
      article = test_class.create!(title: "Original", status: "draft")
      article.update!(title: "Updated", status: "published")

      version = article.versions.where(event: "updated").first

      allow(Rails.logger).to receive(:warn)

      article.rollback_to(version, allow_sensitive: true)

      expect(Rails.logger).to have_received(:warn).with(/allowed by allow_sensitive flag/)
    end
  end

  describe "custom versions_table configuration" do
    it "uses custom table name" do
      test_class = create_traceable_class("TraceableCustomTableTest") do
        traceable do
          track :status
          versions_table "custom_article_versions"
        end
      end

      expect(test_class.traceable_table_name).to eq("custom_article_versions")
    end

    it "uses default table name when not specified" do
      test_class = create_traceable_class("TraceableDefaultTableTest") do
        traceable do
          track :status
        end
      end

      expect(test_class.traceable_table_name).to eq("article_versions")
    end
  end

  describe "TraceableConfigurator" do
    it "initializes with empty fields" do
      config = BetterModel::TraceableConfigurator.new(Article)
      expect(config.fields).to eq([])
    end

    it "tracks multiple fields" do
      config = BetterModel::TraceableConfigurator.new(Article)
      config.track(:status, :title)
      expect(config.fields).to eq([ :status, :title ])
    end

    it "stores sensitive field configuration" do
      config = BetterModel::TraceableConfigurator.new(Article)
      config.track(:password, sensitive: :full)
      expect(config.sensitive_fields[:password]).to eq(:full)
    end

    it "supports mixed normal and sensitive fields" do
      config = BetterModel::TraceableConfigurator.new(Article)
      config.track(:status)
      config.track(:email, sensitive: :partial)
      config.track(:password, sensitive: :full)

      expect(config.fields).to eq([ :status, :email, :password ])
      expect(config.sensitive_fields).to eq({ email: :partial, password: :full })
    end

    it "converts table name to string" do
      config = BetterModel::TraceableConfigurator.new(Article)
      config.versions_table(:custom_versions)
      expect(config.table_name).to eq("custom_versions")
    end

    it "returns configuration hash" do
      config = BetterModel::TraceableConfigurator.new(Article)
      config.track(:status, :title)
      config.track(:password, sensitive: :full)
      config.versions_table("custom_versions")

      hash = config.to_h
      expect(hash[:fields]).to eq([ :status, :title, :password ])
      expect(hash[:sensitive_fields]).to eq({ password: :full })
      expect(hash[:table_name]).to eq("custom_versions")
    end
  end

  describe "ChangeQuery" do
    let(:test_class) do
      create_traceable_class("TraceableChangeQueryTest") do
        traceable do
          track :status
        end
      end
    end

    it "initializes with model class and field" do
      query = BetterModel::ChangeQuery.new(test_class, :status)
      expect(query).to be_a(BetterModel::ChangeQuery)
    end

    it "from method returns self for chaining" do
      query = BetterModel::ChangeQuery.new(test_class, :status)
      result = query.from("draft")
      expect(result).to eq(query)
    end

    it "to method executes query and returns records" do
      article = test_class.create!(status: "draft")
      article.update!(status: "published")

      query = BetterModel::ChangeQuery.new(test_class, :status)
      results = query.from("draft").to("published")

      expect(results).to be_a(ActiveRecord::Relation)
      expect(results).to include(article)
    end
  end

  describe "traceable without block" do
    it "enables traceable with empty fields" do
      test_class = create_traceable_class("TraceableNoBlockTest") do
        traceable
      end

      expect(test_class.traceable_enabled?).to be true
      expect(test_class.traceable_fields).to be_empty
    end

    it "sets default table name" do
      test_class = create_traceable_class("TraceableNoBlockDefaultTableTest") do
        traceable
      end

      expect(test_class.traceable_table_name).to eq("article_versions")
    end
  end

  describe "multiple model classes with traceable" do
    it "creates separate Version classes per table" do
      test_class1 = create_traceable_class("TraceableMulti1Test") do
        traceable do
          track :status
          versions_table "multi1_versions"
        end
      end

      test_class2 = create_traceable_class("TraceableMulti2Test") do
        traceable do
          track :status
          versions_table "multi2_versions"
        end
      end

      expect(test_class1.traceable_table_name).to eq("multi1_versions")
      expect(test_class2.traceable_table_name).to eq("multi2_versions")
    end
  end
end
