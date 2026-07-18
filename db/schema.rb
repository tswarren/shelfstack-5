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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_170000) do
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

  create_table "departments", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.string "cogs_gl_account_code", limit: 20
    t.datetime "created_at", null: false
    t.bigint "default_return_policy_id"
    t.bigint "default_tax_category_id"
    t.string "department_number", null: false
    t.string "freight_in_gl_account_code", limit: 20
    t.string "inventory_adjustment_gl_account_code", limit: 20
    t.string "inventory_asset_gl_account_code", limit: 20
    t.string "inventory_shrinkage_gl_account_code", limit: 20
    t.string "inventory_write_down_gl_account_code", limit: 20
    t.decimal "maximum_merchandise_discount", precision: 8, scale: 4
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "parent_department_id"
    t.boolean "postable", default: true, null: false
    t.string "sales_discounts_gl_account_code", limit: 20
    t.string "sales_returns_gl_account_code", limit: 20
    t.string "sales_revenue_gl_account_code", limit: 20
    t.datetime "updated_at", null: false
    t.string "vendor_returns_gl_account_code", limit: 20
    t.index ["default_return_policy_id"], name: "index_departments_on_default_return_policy_id"
    t.index ["default_tax_category_id"], name: "index_departments_on_default_tax_category_id"
    t.index ["organization_id", "code"], name: "index_departments_on_organization_id_and_code", unique: true
    t.index ["organization_id", "department_number"], name: "index_departments_on_organization_id_and_department_number", unique: true
    t.index ["organization_id"], name: "index_departments_on_organization_id"
    t.index ["parent_department_id"], name: "index_departments_on_parent_department_id"
    t.check_constraint "postable = ANY (ARRAY[true, false])", name: "departments_postable_boolean"
  end

  create_table "discount_reasons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "default_amount_cents"
    t.string "default_calculation_method", null: false
    t.integer "default_rate_bps"
    t.integer "maximum_rate_bps"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.boolean "requires_approval", default: true, null: false
    t.bigint "resulting_return_policy_id"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_discount_reasons_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_discount_reasons_on_organization_id"
    t.index ["resulting_return_policy_id"], name: "index_discount_reasons_on_resulting_return_policy_id"
    t.check_constraint "default_amount_cents IS NULL OR default_amount_cents >= 0", name: "discount_reasons_default_amount_cents_non_negative"
    t.check_constraint "default_calculation_method::text = ANY (ARRAY['percentage'::character varying, 'fixed_amount'::character varying, 'fixed_price'::character varying]::text[])", name: "discount_reasons_calculation_method_check"
    t.check_constraint "default_rate_bps IS NULL OR default_rate_bps >= 0", name: "discount_reasons_default_rate_bps_non_negative"
    t.check_constraint "maximum_rate_bps IS NULL OR maximum_rate_bps >= 0", name: "discount_reasons_maximum_rate_bps_non_negative"
  end

  create_table "identifier_sequences", primary_key: "namespace", id: { type: :string, limit: 2 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "next_value", default: 1, null: false
    t.datetime "updated_at", null: false
    t.check_constraint "namespace::text = ANY (ARRAY['21'::character varying, '27'::character varying, '28'::character varying, '29'::character varying]::text[])", name: "identifier_sequences_namespace_check"
    t.check_constraint "next_value >= 1", name: "identifier_sequences_next_value_positive"
  end

  create_table "merchandise_classes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "default_department_id"
    t.string "default_discountability"
    t.string "default_inventory_tracking_mode"
    t.string "default_returnability"
    t.bigint "default_tax_category_id"
    t.bigint "default_used_department_id"
    t.text "description"
    t.string "level", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "parent_id"
    t.integer "position"
    t.text "shelving_guidance"
    t.datetime "updated_at", null: false
    t.index ["default_department_id"], name: "index_merchandise_classes_on_default_department_id"
    t.index ["default_tax_category_id"], name: "index_merchandise_classes_on_default_tax_category_id"
    t.index ["default_used_department_id"], name: "index_merchandise_classes_on_default_used_department_id"
    t.index ["organization_id", "code"], name: "index_merchandise_classes_on_organization_id_and_code", unique: true
    t.index ["organization_id", "parent_id"], name: "index_merchandise_classes_on_organization_id_and_parent_id"
    t.index ["organization_id"], name: "index_merchandise_classes_on_organization_id"
    t.index ["parent_id"], name: "index_merchandise_classes_on_parent_id"
    t.check_constraint "level::text = ANY (ARRAY['primary'::character varying, 'secondary'::character varying, 'minor'::character varying]::text[])", name: "merchandise_classes_level_check"
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
    t.index "(true)", name: "index_organizations_singleton", unique: true
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

  create_table "product_conditions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_product_conditions_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_product_conditions_on_organization_id"
  end

  create_table "product_formats", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "default_inventory_tracking_mode", null: false
    t.string "format_family", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "short_code", limit: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_product_formats_on_organization_id_and_code", unique: true
    t.index ["organization_id", "short_code"], name: "index_product_formats_on_organization_id_and_short_code", unique: true, where: "(short_code IS NOT NULL)"
    t.index ["organization_id"], name: "index_product_formats_on_organization_id"
    t.check_constraint "default_inventory_tracking_mode::text = ANY (ARRAY['quantity'::character varying, 'individual'::character varying, 'none'::character varying]::text[])", name: "product_formats_tracking_mode_check"
  end

  create_table "product_variants", force: :cascade do |t|
    t.date "available_from"
    t.date "available_until"
    t.datetime "created_at", null: false
    t.bigint "default_product_condition_id"
    t.bigint "department_id"
    t.text "description"
    t.string "discountability_setting"
    t.string "inventory_tracking_mode", default: "quantity", null: false
    t.bigint "merchandise_class_id"
    t.string "name", null: false
    t.bigint "product_id", null: false
    t.boolean "purchasable", default: true, null: false
    t.integer "regular_price_cents"
    t.bigint "return_policy_id"
    t.string "returnability_setting"
    t.boolean "sellable", default: true, null: false
    t.string "sku", null: false
    t.string "status", default: "active", null: false
    t.bigint "tax_category_id"
    t.datetime "updated_at", null: false
    t.index ["default_product_condition_id"], name: "index_product_variants_on_default_product_condition_id"
    t.index ["department_id"], name: "index_product_variants_on_department_id"
    t.index ["merchandise_class_id"], name: "index_product_variants_on_merchandise_class_id"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["return_policy_id"], name: "index_product_variants_on_return_policy_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.index ["tax_category_id"], name: "index_product_variants_on_tax_category_id"
    t.check_constraint "available_from IS NULL OR available_until IS NULL OR available_from <= available_until", name: "product_variants_availability_window_order"
    t.check_constraint "inventory_tracking_mode::text = ANY (ARRAY['quantity'::character varying, 'individual'::character varying, 'none'::character varying]::text[])", name: "product_variants_inventory_tracking_mode_check"
    t.check_constraint "regular_price_cents IS NULL OR regular_price_cents >= 0", name: "product_variants_regular_price_cents_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'discontinued'::character varying]::text[])", name: "product_variants_status_check"
  end

  create_table "products", force: :cascade do |t|
    t.string "alternate_identifier"
    t.date "available_from"
    t.date "available_until"
    t.datetime "created_at", null: false
    t.bigint "default_department_id"
    t.bigint "default_tax_category_id"
    t.text "description"
    t.string "identifier", null: false
    t.boolean "identifier_generated", default: false, null: false
    t.string "identifier_validation_status", default: "valid", null: false
    t.text "identifier_warning"
    t.string "imprint_or_brand_name"
    t.integer "list_price_cents"
    t.bigint "merchandise_class_id"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "product_format_id", null: false
    t.string "product_type", null: false
    t.string "publisher_or_manufacturer_name"
    t.boolean "sellable", default: false, null: false
    t.string "status", default: "active", null: false
    t.string "subtitle"
    t.datetime "updated_at", null: false
    t.string "variant_structure", default: "single", null: false
    t.index ["alternate_identifier"], name: "index_products_on_alternate_identifier"
    t.index ["default_department_id"], name: "index_products_on_default_department_id"
    t.index ["default_tax_category_id"], name: "index_products_on_default_tax_category_id"
    t.index ["merchandise_class_id"], name: "index_products_on_merchandise_class_id"
    t.index ["organization_id", "identifier"], name: "index_products_on_organization_id_and_identifier", unique: true
    t.index ["organization_id"], name: "index_products_on_organization_id"
    t.index ["product_format_id"], name: "index_products_on_product_format_id"
    t.check_constraint "available_from IS NULL OR available_until IS NULL OR available_from <= available_until", name: "products_availability_window_order"
    t.check_constraint "identifier_validation_status::text = ANY (ARRAY['valid'::character varying, 'warning'::character varying, 'invalid'::character varying, 'not_applicable'::character varying]::text[])", name: "products_identifier_validation_status_check"
    t.check_constraint "list_price_cents IS NULL OR list_price_cents >= 0", name: "products_list_price_cents_non_negative"
    t.check_constraint "product_type::text = ANY (ARRAY['book'::character varying, 'recorded_music'::character varying, 'video'::character varying, 'periodical'::character varying, 'game'::character varying, 'stationery'::character varying, 'gift'::character varying, 'cafe'::character varying, 'service'::character varying, 'other'::character varying]::text[])", name: "products_product_type_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'discontinued'::character varying]::text[])", name: "products_status_check"
    t.check_constraint "variant_structure::text = 'single'::text", name: "products_variant_structure_single"
  end

  create_table "return_policies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "final_sale", default: false, null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "return_window_days"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_return_policies_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_return_policies_on_organization_id"
    t.check_constraint "return_window_days IS NULL OR return_window_days >= 0", name: "return_policies_return_window_days_non_negative"
  end

  create_table "return_reasons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "default_return_disposition"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_return_reasons_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_return_reasons_on_organization_id"
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

  create_table "tax_categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_tax_categories_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_tax_categories_on_organization_id"
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
  add_foreign_key "departments", "departments", column: "parent_department_id"
  add_foreign_key "departments", "organizations"
  add_foreign_key "departments", "return_policies", column: "default_return_policy_id", on_delete: :restrict
  add_foreign_key "departments", "tax_categories", column: "default_tax_category_id"
  add_foreign_key "discount_reasons", "organizations", on_delete: :restrict
  add_foreign_key "discount_reasons", "return_policies", column: "resulting_return_policy_id", on_delete: :nullify
  add_foreign_key "merchandise_classes", "departments", column: "default_department_id"
  add_foreign_key "merchandise_classes", "departments", column: "default_used_department_id"
  add_foreign_key "merchandise_classes", "merchandise_classes", column: "parent_id"
  add_foreign_key "merchandise_classes", "organizations"
  add_foreign_key "merchandise_classes", "tax_categories", column: "default_tax_category_id"
  add_foreign_key "pos_devices", "stores", on_delete: :restrict
  add_foreign_key "product_conditions", "organizations"
  add_foreign_key "product_formats", "organizations"
  add_foreign_key "product_variants", "departments"
  add_foreign_key "product_variants", "merchandise_classes"
  add_foreign_key "product_variants", "product_conditions", column: "default_product_condition_id"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "return_policies", on_delete: :nullify
  add_foreign_key "product_variants", "tax_categories"
  add_foreign_key "products", "departments", column: "default_department_id"
  add_foreign_key "products", "merchandise_classes"
  add_foreign_key "products", "organizations"
  add_foreign_key "products", "product_formats"
  add_foreign_key "products", "tax_categories", column: "default_tax_category_id"
  add_foreign_key "return_policies", "organizations", on_delete: :restrict
  add_foreign_key "return_reasons", "organizations", on_delete: :restrict
  add_foreign_key "role_permissions", "permissions", on_delete: :restrict
  add_foreign_key "role_permissions", "roles", on_delete: :restrict
  add_foreign_key "roles", "organizations", on_delete: :restrict
  add_foreign_key "store_memberships", "roles", on_delete: :restrict
  add_foreign_key "store_memberships", "stores", on_delete: :restrict
  add_foreign_key "store_memberships", "users", column: "assigned_by_user_id", on_delete: :nullify
  add_foreign_key "store_memberships", "users", on_delete: :restrict
  add_foreign_key "stores", "organizations", on_delete: :restrict
  add_foreign_key "tax_categories", "organizations"
  add_foreign_key "users", "stores", column: "default_store_id", on_delete: :nullify
end
