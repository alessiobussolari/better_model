# frozen_string_literal: true

require "test_helper"

module BetterModel
  class TaggableSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_taggables, force: true do |t|
          t.text :tags
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_taggables"
        include BetterModel::Taggable
      end
      Object.const_set(:SecureTaggable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_taggables, if_exists: true
      end
      Object.send(:remove_const, :SecureTaggable) if Object.const_defined?(:SecureTaggable)
    end

    test "taggable config is frozen after setup" do
      SecureTaggable.class_eval { taggable }
      assert SecureTaggable.taggable_config.frozen?
    end

    test "config is immutable" do
      SecureTaggable.class_eval { taggable }

      # Config è frozen quindi non può essere riassegnato
      assert SecureTaggable.taggable_config.frozen?
    end

    test "config is thread-safe" do
      SecureTaggable.class_eval { taggable }

      results = 3.times.map do
        Thread.new { SecureTaggable.taggable_config.object_id }
      end.map(&:value)

      assert_equal 1, results.uniq.size
    end
  end
end
