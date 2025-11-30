# frozen_string_literal: true

class AddFeaturedToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :featured, :boolean, default: false
  end
end
