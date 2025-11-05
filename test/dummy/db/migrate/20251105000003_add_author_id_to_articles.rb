# frozen_string_literal: true

class AddAuthorIdToArticles < ActiveRecord::Migration[8.0]
  def change
    add_reference :articles, :author, foreign_key: true, null: true, index: true
  end
end
