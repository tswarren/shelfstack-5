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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_030000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "administrative_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_user_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.bigint "store_id"
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.index ["actor_user_id"], name: "index_administrative_audit_events_on_actor_user_id"
    t.index ["created_at"], name: "index_administrative_audit_events_on_created_at"
    t.index ["organization_id"], name: "index_administrative_audit_events_on_organization_id"
    t.index ["store_id"], name: "index_administrative_audit_events_on_store_id"
    t.index ["subject_type", "subject_id"], name: "idx_on_subject_type_subject_id_1fe0fde46f"
  end

  create_table "cash_drawers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "code"], name: "index_cash_drawers_on_store_id_and_code", unique: true
    t.index ["store_id"], name: "index_cash_drawers_on_store_id"
  end

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

  create_table "permissions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "permission_group"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_permissions_on_code", unique: true
  end

  create_table "pos_devices", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "device_type", default: "register", null: false
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "code"], name: "index_pos_devices_on_store_id_and_code", unique: true
    t.index ["store_id"], name: "index_pos_devices_on_store_id"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.boolean "system_template", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_roles_on_organization_id_and_code", unique: true
    t.index ["organization_id", "name"], name: "index_roles_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_roles_on_organization_id"
  end

  create_table "store_memberships", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "assigned_by_user_id"
    t.integer "cash_variance_review_threshold_cents"
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.integer "maximum_cash_refund_cents"
    t.integer "maximum_discount_amount_cents"
    t.decimal "maximum_discount_rate", precision: 10, scale: 8
    t.integer "maximum_no_receipt_return_cents"
    t.integer "maximum_paid_out_cents"
    t.decimal "maximum_price_override_rate", precision: 10, scale: 8
    t.bigint "role_id", null: false
    t.date "starts_on"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["assigned_by_user_id"], name: "index_store_memberships_on_assigned_by_user_id"
    t.index ["role_id"], name: "index_store_memberships_on_role_id"
    t.index ["store_id"], name: "index_store_memberships_on_store_id"
    t.index ["user_id", "store_id"], name: "index_store_memberships_on_user_id_and_store_id", unique: true
    t.index ["user_id"], name: "index_store_memberships_on_user_id"
    t.check_constraint "cash_variance_review_threshold_cents IS NULL OR cash_variance_review_threshold_cents >= 0", name: "store_memberships_cash_variance_non_negative"
    t.check_constraint "maximum_cash_refund_cents IS NULL OR maximum_cash_refund_cents >= 0", name: "store_memberships_cash_refund_non_negative"
    t.check_constraint "maximum_discount_amount_cents IS NULL OR maximum_discount_amount_cents >= 0", name: "store_memberships_discount_amount_non_negative"
    t.check_constraint "maximum_discount_rate IS NULL OR maximum_discount_rate >= 0::numeric AND maximum_discount_rate <= 1::numeric", name: "store_memberships_discount_rate_range"
    t.check_constraint "maximum_no_receipt_return_cents IS NULL OR maximum_no_receipt_return_cents >= 0", name: "store_memberships_no_receipt_return_non_negative"
    t.check_constraint "maximum_paid_out_cents IS NULL OR maximum_paid_out_cents >= 0", name: "store_memberships_paid_out_non_negative"
    t.check_constraint "maximum_price_override_rate IS NULL OR maximum_price_override_rate >= 0::numeric AND maximum_price_override_rate <= 1::numeric", name: "store_memberships_price_override_rate_range"
    t.check_constraint "starts_on IS NULL OR ends_on IS NULL OR starts_on <= ends_on", name: "store_memberships_starts_on_before_ends_on"
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

  add_foreign_key "administrative_audit_events", "organizations", on_delete: :restrict
  add_foreign_key "administrative_audit_events", "stores", on_delete: :restrict
  add_foreign_key "administrative_audit_events", "users", column: "actor_user_id", on_delete: :restrict
  add_foreign_key "cash_drawers", "stores", on_delete: :restrict
  add_foreign_key "pos_devices", "stores", on_delete: :restrict
  add_foreign_key "role_permissions", "permissions", on_delete: :restrict
  add_foreign_key "role_permissions", "roles", on_delete: :restrict
  add_foreign_key "roles", "organizations", on_delete: :restrict
  add_foreign_key "store_memberships", "roles", on_delete: :restrict
  add_foreign_key "store_memberships", "stores", on_delete: :restrict
  add_foreign_key "store_memberships", "users", column: "assigned_by_user_id", on_delete: :nullify
  add_foreign_key "store_memberships", "users", on_delete: :restrict
  add_foreign_key "stores", "organizations", on_delete: :restrict
  add_foreign_key "users", "stores", column: "default_store_id", on_delete: :nullify
end
