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

ActiveRecord::Schema[7.2].define(version: 2026_03_22_215030) do
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
  end

  create_table "entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "contest_id", null: false
    t.float "score", default: 0.0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contest_id"], name: "index_entries_on_contest_id"
    t.index ["user_id", "contest_id"], name: "index_entries_on_user_id_and_contest_id", unique: true
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "picks", force: :cascade do |t|
    t.bigint "entry_id", null: false
    t.bigint "prop_id", null: false
    t.string "selection", null: false
    t.string "result", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  add_foreign_key "entries", "contests"
  add_foreign_key "entries", "users"
  add_foreign_key "picks", "entries"
  add_foreign_key "picks", "props"
  add_foreign_key "props", "contests"
end
