class AddValidatableFieldsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :starts_at, :datetime
    add_column :articles, :ends_at, :datetime
    add_column :articles, :scheduled_for, :datetime
    add_column :articles, :max_views, :integer
  end
end
