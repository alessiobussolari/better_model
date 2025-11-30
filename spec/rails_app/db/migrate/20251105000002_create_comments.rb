# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :article, null: false, foreign_key: true
      t.text :body, null: false
      t.string :author_name

      t.timestamps
    end

    add_index :comments, :created_at
  end
end
