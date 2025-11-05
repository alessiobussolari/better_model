# frozen_string_literal: true

require "test_helper"

module BetterModel
  class ArchivableSecurityTest < ActiveSupport::TestCase
    def setup
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_archivables, force: true do |t|
          t.string :title
          t.datetime :archived_at
          t.timestamps
        end
      end

      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_archivables"
        include BetterModel::Archivable
      end
      Object.const_set(:SecureArchivable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_archivables, if_exists: true
      end
      Object.send(:remove_const, :SecureArchivable) if Object.const_defined?(:SecureArchivable)
    end

    test "archivable module loads without errors" do
      # Verifica che il modulo sia incluso correttamente
      assert SecureArchivable.included_modules.include?(BetterModel::Archivable)
    end
  end
end
