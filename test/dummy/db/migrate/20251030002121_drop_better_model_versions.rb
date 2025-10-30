class DropBetterModelVersions < ActiveRecord::Migration[8.1]
  def change
    drop_table :better_model_versions if table_exists?(:better_model_versions)
  end
end
