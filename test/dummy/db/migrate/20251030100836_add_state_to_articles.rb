class AddStateToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :state, :string, null: false, default: "draft"
    add_index :articles, :state
  end
end
