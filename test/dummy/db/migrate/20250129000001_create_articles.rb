# frozen_string_literal: true

class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title
      t.text :content
      t.string :status, default: "draft"
      t.datetime :published_at
      t.datetime :scheduled_at
      t.datetime :expires_at
      t.integer :view_count, default: 0

      t.timestamps
    end
  end
end
