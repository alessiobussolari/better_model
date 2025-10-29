# frozen_string_literal: true

class AddArchivableToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :archived_at, :datetime
    add_column :articles, :archived_by_id, :integer
    add_column :articles, :archive_reason, :string

    add_index :articles, :archived_at
  end
end
