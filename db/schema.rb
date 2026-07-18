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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "organizations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "default_currency_code", limit: 3, null: false
    t.string "default_timezone", null: false
    t.string "legal_name"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_organizations_on_code", unique: true
  end

  create_table "stores", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "city"
    t.string "code", null: false
    t.string "country_code", limit: 2
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.string "email"
    t.string "legal_name"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "phone", limit: 30
    t.string "postal_code", limit: 12
    t.text "receipt_footer"
    t.text "receipt_header"
    t.string "region"
    t.string "san_number", limit: 8
    t.string "store_number"
    t.string "timezone", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_stores_on_organization_id_and_code", unique: true
    t.index ["organization_id", "store_number"], name: "index_stores_on_organization_id_and_store_number", unique: true, where: "(store_number IS NOT NULL)"
    t.index ["organization_id"], name: "index_stores_on_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "default_store_id"
    t.string "email"
    t.integer "failed_login_attempts", default: 0, null: false
    t.string "first_name"
    t.datetime "last_login_at"
    t.string "last_name"
    t.datetime "locked_at"
    t.datetime "password_changed_at"
    t.string "password_digest", null: false
    t.datetime "pin_changed_at"
    t.string "pin_digest"
    t.datetime "updated_at", null: false
    t.integer "user_number"
    t.string "username", null: false
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["default_store_id"], name: "index_users_on_default_store_id"
    t.index ["user_number"], name: "index_users_on_user_number", unique: true, where: "(user_number IS NOT NULL)"
    t.check_constraint "failed_login_attempts >= 0", name: "users_failed_login_attempts_non_negative"
  end

  add_foreign_key "stores", "organizations", on_delete: :restrict
  add_foreign_key "users", "stores", column: "default_store_id", on_delete: :nullify
end
