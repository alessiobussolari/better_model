# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_05_000003) do
  create_table "article_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.json "object_changes"
    t.integer "updated_by_id"
    t.string "updated_reason"
    t.index [ "created_at" ], name: "index_article_versions_on_created_at"
    t.index [ "event" ], name: "index_article_versions_on_event"
    t.index [ "item_type", "item_id" ], name: "index_article_versions_on_item"
    t.index [ "updated_by_id" ], name: "index_article_versions_on_updated_by_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "archive_reason"
    t.datetime "archived_at"
    t.integer "archived_by_id"
    t.integer "author_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.datetime "expires_at"
    t.boolean "featured", default: false
    t.integer "max_views"
    t.datetime "published_at"
    t.datetime "scheduled_at"
    t.datetime "scheduled_for"
    t.datetime "starts_at"
    t.string "state", default: "draft", null: false
    t.string "status", default: "draft"
    t.text "tags"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0
    t.index [ "archived_at" ], name: "index_articles_on_archived_at"
    t.index [ "author_id" ], name: "index_articles_on_author_id"
    t.index [ "state" ], name: "index_articles_on_state"
  end

  create_table "authors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "email" ], name: "index_authors_on_email", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.integer "article_id", null: false
    t.string "author_name"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "article_id" ], name: "index_comments_on_article_id"
    t.index [ "created_at" ], name: "index_comments_on_created_at"
  end

  create_table "documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index [ "state" ], name: "index_documents_on_state"
  end

  create_table "state_transitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.string "from_state", null: false
    t.json "metadata"
    t.string "to_state", null: false
    t.integer "transitionable_id", null: false
    t.string "transitionable_type", null: false
    t.index [ "created_at" ], name: "index_state_transitions_on_created_at"
    t.index [ "event" ], name: "index_state_transitions_on_event"
    t.index [ "from_state" ], name: "index_state_transitions_on_from_state"
    t.index [ "to_state" ], name: "index_state_transitions_on_to_state"
    t.index [ "transitionable_type", "transitionable_id" ], name: "index_state_transitions_on_transitionable"
  end

  create_table "thread_safe_article_transitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.string "from_state", null: false
    t.json "metadata"
    t.string "to_state", null: false
    t.integer "transitionable_id", null: false
    t.string "transitionable_type", null: false
    t.index [ "created_at" ], name: "index_thread_safe_article_transitions_on_created_at"
    t.index [ "event" ], name: "index_thread_safe_article_transitions_on_event"
    t.index [ "from_state" ], name: "index_thread_safe_article_transitions_on_from_state"
    t.index [ "to_state" ], name: "index_thread_safe_article_transitions_on_to_state"
    t.index [ "transitionable_type", "transitionable_id" ], name: "idx_thread_safe_article_trans_on_transitionable"
  end

  create_table "thread_safe_article_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.json "object_changes"
    t.integer "updated_by_id"
    t.string "updated_reason"
    t.index [ "created_at" ], name: "index_thread_safe_article_versions_on_created_at"
    t.index [ "event" ], name: "index_thread_safe_article_versions_on_event"
    t.index [ "item_type", "item_id" ], name: "index_thread_safe_article_versions_on_item"
    t.index [ "updated_by_id" ], name: "index_thread_safe_article_versions_on_updated_by_id"
  end

  create_table "thread_safe_document_transitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.string "from_state", null: false
    t.json "metadata"
    t.string "to_state", null: false
    t.integer "transitionable_id", null: false
    t.string "transitionable_type", null: false
    t.index [ "created_at" ], name: "index_thread_safe_document_transitions_on_created_at"
    t.index [ "event" ], name: "index_thread_safe_document_transitions_on_event"
    t.index [ "from_state" ], name: "index_thread_safe_document_transitions_on_from_state"
    t.index [ "to_state" ], name: "index_thread_safe_document_transitions_on_to_state"
    t.index [ "transitionable_type", "transitionable_id" ], name: "idx_thread_safe_document_trans_on_transitionable"
  end

  create_table "thread_safe_document_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.json "object_changes"
    t.integer "updated_by_id"
    t.string "updated_reason"
    t.index [ "created_at" ], name: "index_thread_safe_document_versions_on_created_at"
    t.index [ "event" ], name: "index_thread_safe_document_versions_on_event"
    t.index [ "item_type", "item_id" ], name: "index_thread_safe_document_versions_on_item"
    t.index [ "updated_by_id" ], name: "index_thread_safe_document_versions_on_updated_by_id"
  end

  add_foreign_key "articles", "authors"
  add_foreign_key "comments", "articles"
end
