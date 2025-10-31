class AddTagsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :tags, :text
  end
end
