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

ActiveRecord::Schema[8.1].define(version: 2025_01_29_000003) do
  create_table "articles", force: :cascade do |t|
    t.string "archive_reason"
    t.datetime "archived_at"
    t.integer "archived_by_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.boolean "featured", default: false
    t.datetime "published_at"
    t.datetime "scheduled_at"
    t.string "status", default: "draft"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0
    t.index [ "archived_at" ], name: "index_articles_on_archived_at"
  end
end
