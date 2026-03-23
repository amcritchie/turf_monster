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

ActiveRecord::Schema[7.2].define(version: 2026_03_23_100003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "contests", force: :cascade do |t|
    t.string "name", null: false
    t.integer "entry_fee_cents", default: 0, null: false
    t.string "status", default: "draft", null: false
    t.integer "max_entries"
    t.datetime "starts_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
  end

  create_table "entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "contest_id", null: false
    t.float "score", default: 0.0, null: false
    t.string "status", default: "cart", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["contest_id"], name: "index_entries_on_contest_id"
    t.index ["user_id", "contest_id"], name: "index_entries_on_user_id_and_contest_id"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "error_logs", force: :cascade do |t|
    t.text "message", null: false
    t.text "inspect"
    t.text "backtrace"
    t.string "target_type"
    t.bigint "target_id"
    t.string "target_name"
    t.string "parent_type"
    t.bigint "parent_id"
    t.string "parent_name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_error_logs_on_created_at"
    t.index ["parent_type", "parent_id"], name: "index_error_logs_on_parent_type_and_parent_id"
    t.index ["target_type", "target_id"], name: "index_error_logs_on_target_type_and_target_id"
  end

  create_table "picks", force: :cascade do |t|
    t.bigint "entry_id", null: false
    t.bigint "prop_id", null: false
    t.string "selection", null: false
    t.string "result", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["entry_id", "prop_id"], name: "index_picks_on_entry_id_and_prop_id", unique: true
    t.index ["entry_id"], name: "index_picks_on_entry_id"
    t.index ["prop_id"], name: "index_picks_on_prop_id"
  end

  create_table "props", force: :cascade do |t|
    t.bigint "contest_id", null: false
    t.string "description", null: false
    t.float "line", null: false
    t.string "stat_type"
    t.float "result_value"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["contest_id"], name: "index_props_on_contest_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email", null: false
    t.integer "balance_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest", default: "", null: false
    t.string "provider"
    t.string "uid"
    t.string "slug"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  add_foreign_key "entries", "contests"
  add_foreign_key "entries", "users"
  add_foreign_key "picks", "entries"
  add_foreign_key "picks", "props"
  add_foreign_key "props", "contests"
end
