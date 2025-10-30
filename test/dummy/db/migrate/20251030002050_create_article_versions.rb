class CreateArticleVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :article_versions do |t|
      # Polymorphic association to tracked models
      t.string :item_type, null: false
      t.integer :item_id, null: false

      # Event type: created, updated, destroyed
      t.string :event, null: false

      # Changes stored as JSON (before/after values)
      t.json :object_changes

      # Optional tracking fields
      t.integer :updated_by_id
      t.string :updated_reason

      t.datetime :created_at, null: false
    end

    # Indexes for performance
    add_index :article_versions, [ :item_type, :item_id ], name: "index_article_versions_on_item"
    add_index :article_versions, :created_at
    add_index :article_versions, :updated_by_id
    add_index :article_versions, :event
  end
end
