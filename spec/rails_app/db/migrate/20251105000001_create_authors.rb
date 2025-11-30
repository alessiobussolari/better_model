# frozen_string_literal: true

class CreateAuthors < ActiveRecord::Migration[8.0]
  def change
    create_table :authors do |t|
      t.string :name, null: false
      t.string :email

      t.timestamps
    end

    add_index :authors, :email, unique: true
  end
end
