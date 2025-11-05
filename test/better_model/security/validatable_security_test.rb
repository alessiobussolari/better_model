# frozen_string_literal: true

require "test_helper"

module BetterModel
  class ValidatableSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_validatables, force: true do |t|
          t.string :title
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_validatables"
        include BetterModel::Validatable
      end
      Object.const_set(:SecureValidatable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_validatables, if_exists: true
      end
      Object.send(:remove_const, :SecureValidatable) if Object.const_defined?(:SecureValidatable)
    end

    test "validatable config is frozen after setup" do
      SecureValidatable.class_eval do
        validatable do
          check :title, presence: true
        end
      end

      assert SecureValidatable.validatable_config.frozen?
    end

    test "cannot modify config at runtime" do
      SecureValidatable.class_eval do
        validatable do
          check :title, presence: true
        end
      end

      assert_raises(FrozenError) do
        SecureValidatable.validatable_config[:validations] = []
      end
    end

    test "config is thread-safe" do
      SecureValidatable.class_eval do
        validatable do
          check :title, presence: true
        end
      end

      results = 3.times.map do
        Thread.new { SecureValidatable.validatable_config.object_id }
      end.map(&:value)

      assert_equal 1, results.uniq.size
    end
  end
end
