# frozen_string_literal: true

require "test_helper"

module BetterModel
  class TraceableSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_traceables, force: true do |t|
          t.string :title
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_traceables"
        include BetterModel::Traceable
      end
      Object.const_set(:SecureTraceable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_traceables, if_exists: true
      end
      Object.send(:remove_const, :SecureTraceable) if Object.const_defined?(:SecureTraceable)
    end

    test "traceable config is frozen after setup" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      assert SecureTraceable.traceable_config.frozen?
    end

    test "cannot modify config at runtime" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      assert_raises(FrozenError) do
        SecureTraceable.traceable_config[:tracked_fields] = []
      end
    end

    test "config is thread-safe" do
      SecureTraceable.class_eval do
        traceable do
          track :title
        end
      end

      results = 3.times.map do
        Thread.new { SecureTraceable.traceable_config.object_id }
      end.map(&:value)

      assert_equal 1, results.uniq.size
    end
  end
end
