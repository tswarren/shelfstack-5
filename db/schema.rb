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

ActiveRecord::Schema[8.1].define(version: 2026_07_22_230000) do
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

  create_table "business_days", force: :cascade do |t|
    t.datetime "closed_at"
    t.bigint "closed_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "opened_at", null: false
    t.bigint "opened_by_user_id", null: false
    t.date "reporting_date", null: false
    t.string "status", default: "open", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_by_user_id"], name: "index_business_days_on_closed_by_user_id"
    t.index ["opened_by_user_id"], name: "index_business_days_on_opened_by_user_id"
    t.index ["store_id"], name: "index_business_days_on_store_id"
    t.index ["store_id"], name: "index_business_days_one_open_per_store", unique: true, where: "((status)::text = 'open'::text)"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'closed'::character varying::text])", name: "business_days_status_check"
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

  create_table "cash_movement_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.boolean "requires_approval", default: true, null: false
    t.boolean "requires_reference", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_cash_movement_types_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_cash_movement_types_on_organization_id"
  end

  create_table "departments", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.string "cogs_gl_account_code", limit: 20
    t.datetime "created_at", null: false
    t.integer "default_cost_estimation_margin_bps"
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
    t.check_constraint "default_cost_estimation_margin_bps IS NULL OR default_cost_estimation_margin_bps >= 0 AND default_cost_estimation_margin_bps <= 10000", name: "departments_margin_bps_range"
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
    t.check_constraint "default_calculation_method::text = ANY (ARRAY['percentage'::character varying::text, 'fixed_amount'::character varying::text, 'fixed_price'::character varying::text])", name: "discount_reasons_calculation_method_check"
    t.check_constraint "default_rate_bps IS NULL OR default_rate_bps >= 0", name: "discount_reasons_default_rate_bps_non_negative"
    t.check_constraint "maximum_rate_bps IS NULL OR maximum_rate_bps >= 0", name: "discount_reasons_maximum_rate_bps_non_negative"
  end

  create_table "identifier_sequences", primary_key: "namespace", id: { type: :string, limit: 2 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "next_value", default: 1, null: false
    t.datetime "updated_at", null: false
    t.check_constraint "namespace::text = ANY (ARRAY['21'::character varying::text, '27'::character varying::text, '28'::character varying::text, '29'::character varying::text])", name: "identifier_sequences_namespace_check"
    t.check_constraint "next_value >= 1", name: "identifier_sequences_next_value_positive"
  end

  create_table "inventory_adjustment_lines", force: :cascade do |t|
    t.bigint "corrected_inventory_value_cents"
    t.datetime "created_at", null: false
    t.bigint "estimate_department_id"
    t.integer "estimate_margin_bps"
    t.integer "estimate_regular_price_cents"
    t.integer "estimate_unit_cost_cents"
    t.string "input_cost_method"
    t.string "input_cost_quality"
    t.integer "input_unit_cost_cents"
    t.bigint "inventory_adjustment_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity_delta", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["estimate_department_id"], name: "index_inventory_adjustment_lines_on_estimate_department_id"
    t.index ["inventory_adjustment_id", "product_variant_id"], name: "index_inv_adj_lines_on_adj_and_variant", unique: true
    t.index ["inventory_adjustment_id"], name: "index_inventory_adjustment_lines_on_inventory_adjustment_id"
    t.index ["product_variant_id"], name: "index_inventory_adjustment_lines_on_product_variant_id"
    t.check_constraint "input_cost_method IS NULL OR (input_cost_method::text = ANY (ARRAY['explicit'::character varying::text, 'configured_estimate'::character varying::text, 'moving_average'::character varying::text, 'unknown'::character varying::text]))", name: "inv_adj_lines_input_cost_method"
    t.check_constraint "input_cost_quality IS NULL OR (input_cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text]))", name: "inv_adj_lines_input_cost_quality"
  end

  create_table "inventory_adjustment_reasons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "adjustment_kind", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.boolean "requires_note", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "adjustment_kind", "code"], name: "index_inv_adj_reasons_on_org_kind_code", unique: true
    t.index ["organization_id"], name: "index_inventory_adjustment_reasons_on_organization_id"
    t.check_constraint "active = ANY (ARRAY[true, false])", name: "inv_adj_reasons_active_boolean"
    t.check_constraint "adjustment_kind::text = ANY (ARRAY['opening_inventory'::character varying::text, 'quantity_only'::character varying::text, 'cost_correction'::character varying::text])", name: "inv_adj_reasons_kind"
    t.check_constraint "requires_note = ANY (ARRAY[true, false])", name: "inv_adj_reasons_requires_note_boolean"
  end

  create_table "inventory_adjustments", force: :cascade do |t|
    t.text "cancel_note"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_user_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "inventory_adjustment_reason_id", null: false
    t.string "kind", null: false
    t.text "note"
    t.datetime "posted_at"
    t.bigint "posted_by_user_id"
    t.string "posting_key"
    t.string "reason_code_snapshot"
    t.string "reason_name_snapshot"
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cancelled_by_user_id"], name: "index_inventory_adjustments_on_cancelled_by_user_id"
    t.index ["created_by_user_id"], name: "index_inventory_adjustments_on_created_by_user_id"
    t.index ["inventory_adjustment_reason_id"], name: "index_inventory_adjustments_on_inventory_adjustment_reason_id"
    t.index ["posted_by_user_id"], name: "index_inventory_adjustments_on_posted_by_user_id"
    t.index ["posting_key"], name: "index_inventory_adjustments_on_posting_key", unique: true, where: "(posting_key IS NOT NULL)"
    t.index ["store_id"], name: "index_inventory_adjustments_on_store_id"
    t.check_constraint "kind::text = ANY (ARRAY['opening_inventory'::character varying::text, 'quantity_only'::character varying::text, 'cost_correction'::character varying::text])", name: "inventory_adjustments_kind"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'posted'::character varying::text, 'cancelled'::character varying::text])", name: "inventory_adjustments_status"
  end

  create_table "inventory_ledger_entries", force: :cascade do |t|
    t.string "availability_reason"
    t.string "cost_method", null: false
    t.string "cost_quality", null: false
    t.datetime "created_at", null: false
    t.bigint "estimate_department_id"
    t.integer "estimate_margin_bps"
    t.integer "estimate_regular_price_cents"
    t.integer "estimate_unit_cost_cents"
    t.bigint "inventory_value_delta_cents"
    t.integer "movement_cost_cents"
    t.string "movement_type", null: false
    t.datetime "posted_at", null: false
    t.bigint "posted_by_user_id", null: false
    t.string "posting_key", null: false
    t.string "prior_deficit_cost_quality"
    t.bigint "prior_open_provisional_deficit_cost_cents"
    t.bigint "product_variant_id", null: false
    t.bigint "provisional_cost_released_cents"
    t.string "provisional_deficit_cost_quality_snapshot"
    t.integer "quantity_delta", null: false
    t.string "reason_code"
    t.text "reason_note"
    t.string "resulting_cost_quality", null: false
    t.string "resulting_deficit_cost_quality"
    t.bigint "resulting_inventory_value_cents"
    t.integer "resulting_moving_average_cost_cents"
    t.integer "resulting_on_hand", null: false
    t.bigint "resulting_open_provisional_deficit_cost_cents"
    t.integer "resulting_unavailable", null: false
    t.bigint "reversal_of_entry_id"
    t.bigint "settlement_variance_cents"
    t.string "settlement_variance_kind"
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.bigint "store_id", null: false
    t.integer "unavailable_delta", default: 0, null: false
    t.integer "unit_cost_cents"
    t.datetime "updated_at", null: false
    t.index ["estimate_department_id"], name: "index_inventory_ledger_entries_on_estimate_department_id"
    t.index ["posted_by_user_id"], name: "index_inventory_ledger_entries_on_posted_by_user_id"
    t.index ["posting_key"], name: "index_inventory_ledger_entries_on_posting_key", unique: true
    t.index ["product_variant_id"], name: "index_inventory_ledger_entries_on_product_variant_id"
    t.index ["reversal_of_entry_id"], name: "index_inv_ledger_reversal_of_entry_id_unique", unique: true, where: "(reversal_of_entry_id IS NOT NULL)"
    t.index ["reversal_of_entry_id"], name: "index_inventory_ledger_entries_on_reversal_of_entry_id"
    t.index ["source_type", "source_id"], name: "index_inventory_ledger_entries_on_source_type_and_source_id"
    t.index ["store_id", "product_variant_id", "posted_at"], name: "idx_on_store_id_product_variant_id_posted_at_3e7a285cee"
    t.index ["store_id"], name: "index_inventory_ledger_entries_on_store_id"
    t.check_constraint "cost_method::text = ANY (ARRAY['explicit'::character varying::text, 'configured_estimate'::character varying::text, 'moving_average'::character varying::text, 'last_known'::character varying::text, 'unknown'::character varying::text])", name: "inv_ledger_cost_method"
    t.check_constraint "cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text])", name: "inv_ledger_cost_quality"
    t.check_constraint "movement_cost_cents IS NULL OR movement_cost_cents >= 0", name: "inv_ledger_movement_cost_nonneg"
    t.check_constraint "movement_type::text = ANY (ARRAY['opening_inventory'::text, 'quantity_adjustment'::text, 'cost_correction'::text, 'sale'::text, 'customer_return'::text, 'receipt'::text, 'receipt_deficit_settlement'::text])", name: "inv_ledger_movement_type"
    t.check_constraint "prior_deficit_cost_quality IS NULL OR (prior_deficit_cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text]))", name: "inv_ledger_prior_deficit_quality_check"
    t.check_constraint "provisional_deficit_cost_quality_snapshot IS NULL OR (provisional_deficit_cost_quality_snapshot::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text]))", name: "inv_ledger_deficit_quality_snapshot_check"
    t.check_constraint "resulting_cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text])", name: "inv_ledger_resulting_cost_quality"
    t.check_constraint "resulting_deficit_cost_quality IS NULL OR (resulting_deficit_cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text]))", name: "inv_ledger_resulting_deficit_quality_check"
    t.check_constraint "settlement_variance_kind IS NULL OR (settlement_variance_kind::text = ANY (ARRAY['ordinary'::character varying::text, 'late_cost_recognition'::character varying::text]))", name: "inv_ledger_variance_kind_check"
    t.check_constraint "unit_cost_cents IS NULL OR unit_cost_cents >= 0", name: "inv_ledger_unit_cost_nonneg"
  end

  create_table "inventory_reservations", force: :cascade do |t|
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.bigint "inventory_unit_id"
    t.bigint "product_variant_id", null: false
    t.integer "quantity", null: false
    t.text "release_reason"
    t.datetime "released_at"
    t.bigint "released_by_user_id"
    t.datetime "reserved_at", null: false
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.string "status", default: "active", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_unit_id"], name: "index_inv_reservations_active_unit_unique", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["inventory_unit_id"], name: "index_inventory_reservations_on_inventory_unit_id"
    t.index ["product_variant_id"], name: "index_inventory_reservations_on_product_variant_id"
    t.index ["released_by_user_id"], name: "index_inventory_reservations_on_released_by_user_id"
    t.index ["store_id", "product_variant_id", "source_type", "source_id"], name: "index_inv_reservations_active_qty_source_unique", unique: true, where: "(((status)::text = 'active'::text) AND (inventory_unit_id IS NULL))"
    t.index ["store_id", "product_variant_id", "status"], name: "idx_on_store_id_product_variant_id_status_6ca347337e"
    t.index ["store_id"], name: "index_inventory_reservations_on_store_id"
    t.check_constraint "inventory_unit_id IS NULL OR quantity = 1", name: "inv_reservations_unit_quantity_one"
    t.check_constraint "quantity > 0", name: "inv_reservations_quantity_positive"
    t.check_constraint "source_type::text = ANY (ARRAY['pos_line_item'::character varying::text, 'product_request'::character varying::text])", name: "inv_reservations_source_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'released'::character varying::text, 'converted'::character varying::text])", name: "inv_reservations_status"
  end

  create_table "inventory_units", force: :cascade do |t|
    t.datetime "acquired_at", null: false
    t.integer "acquisition_cost_cents"
    t.bigint "acquisition_source_id"
    t.string "acquisition_source_type"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.string "description"
    t.text "internal_notes"
    t.bigint "product_condition_id"
    t.bigint "product_variant_id", null: false
    t.datetime "sold_at"
    t.bigint "sold_pos_line_item_id"
    t.string "status", default: "available", null: false
    t.bigint "store_id", null: false
    t.string "unit_identifier", null: false
    t.integer "unit_price_cents"
    t.datetime "updated_at", null: false
    t.index ["acquisition_source_type", "acquisition_source_id"], name: "idx_on_acquisition_source_type_acquisition_source_i_d5d02d1bb1"
    t.index ["created_by_user_id"], name: "index_inventory_units_on_created_by_user_id"
    t.index ["product_condition_id"], name: "index_inventory_units_on_product_condition_id"
    t.index ["product_variant_id"], name: "index_inventory_units_on_product_variant_id"
    t.index ["sold_pos_line_item_id"], name: "index_inventory_units_on_sold_pos_line_item_id"
    t.index ["store_id", "product_variant_id", "status"], name: "idx_on_store_id_product_variant_id_status_93e8b8db14"
    t.index ["store_id"], name: "index_inventory_units_on_store_id"
    t.index ["unit_identifier"], name: "index_inventory_units_on_unit_identifier", unique: true
    t.check_constraint "acquisition_cost_cents IS NULL OR acquisition_cost_cents >= 0", name: "inventory_units_acquisition_cost_non_negative"
    t.check_constraint "acquisition_source_type IS NULL OR (acquisition_source_type::text = ANY (ARRAY['receipt_line'::character varying::text, 'return_line'::character varying::text, 'buyback'::character varying::text, 'adjustment'::character varying::text, 'other'::character varying::text]))", name: "inventory_units_acquisition_source_type_check"
    t.check_constraint "status::text = ANY (ARRAY['available'::character varying::text, 'reserved'::character varying::text, 'sold'::character varying::text, 'inspection'::character varying::text, 'damaged'::character varying::text, 'discarded'::character varying::text, 'rtv'::character varying::text, 'in_transfer'::character varying::text])", name: "inventory_units_status_check"
    t.check_constraint "unit_price_cents IS NULL OR unit_price_cents >= 0", name: "inventory_units_unit_price_non_negative"
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
    t.check_constraint "level::text = ANY (ARRAY['primary'::character varying::text, 'secondary'::character varying::text, 'minor'::character varying::text])", name: "merchandise_classes_level_check"
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

  create_table "pos_approvals", force: :cascade do |t|
    t.string "action_type", null: false
    t.datetime "approved_at", null: false
    t.bigint "approved_by_user_id", null: false
    t.decimal "approved_value", precision: 18, scale: 8
    t.decimal "authorization_limit_snapshot", precision: 18, scale: 8
    t.datetime "created_at", null: false
    t.bigint "pos_line_item_id"
    t.bigint "pos_session_id"
    t.bigint "pos_transaction_id"
    t.text "reason", null: false
    t.bigint "requested_by_user_id", null: false
    t.decimal "requested_value", precision: 18, scale: 8
    t.bigint "store_id", null: false
    t.index ["approved_by_user_id"], name: "index_pos_approvals_on_approved_by_user_id"
    t.index ["pos_line_item_id"], name: "index_pos_approvals_on_pos_line_item_id"
    t.index ["pos_session_id"], name: "index_pos_approvals_on_pos_session_id"
    t.index ["pos_transaction_id"], name: "index_pos_approvals_on_pos_transaction_id"
    t.index ["requested_by_user_id"], name: "index_pos_approvals_on_requested_by_user_id"
    t.index ["store_id"], name: "index_pos_approvals_on_store_id"
    t.check_constraint "action_type::text = ANY (ARRAY['price_override'::character varying::text, 'discount_apply'::character varying::text, 'tax_exemption'::character varying::text, 'tax_category_override'::character varying::text, 'cash_movement'::character varying::text, 'post_void'::character varying::text, 'stored_value_adjustment'::character varying::text, 'stored_value_refund_exception'::character varying::text, 'card_refund_reconciliation'::character varying::text])", name: "pos_approvals_action_type_check"
  end

  create_table "pos_cash_movements", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "approved_by_user_id"
    t.bigint "cash_movement_type_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "pos_approval_id"
    t.bigint "pos_session_id", null: false
    t.text "reason"
    t.string "reference"
    t.bigint "store_id", null: false
    t.index ["approved_by_user_id"], name: "index_pos_cash_movements_on_approved_by_user_id"
    t.index ["cash_movement_type_id"], name: "index_pos_cash_movements_on_cash_movement_type_id"
    t.index ["created_by_user_id"], name: "index_pos_cash_movements_on_created_by_user_id"
    t.index ["pos_approval_id"], name: "index_pos_cash_movements_on_pos_approval_id"
    t.index ["pos_session_id"], name: "index_pos_cash_movements_on_pos_session_id"
    t.index ["store_id"], name: "index_pos_cash_movements_on_store_id"
    t.check_constraint "amount_cents > 0", name: "pos_cash_movements_amount_positive"
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

  create_table "pos_discount_allocations", force: :cascade do |t|
    t.integer "allocated_amount_cents", null: false
    t.datetime "created_at", null: false
    t.integer "eligible_amount_cents"
    t.bigint "pos_discount_id", null: false
    t.bigint "pos_line_item_id", null: false
    t.index ["pos_discount_id", "pos_line_item_id"], name: "index_pos_discount_allocations_on_discount_and_line", unique: true
    t.index ["pos_discount_id"], name: "index_pos_discount_allocations_on_pos_discount_id"
    t.index ["pos_line_item_id"], name: "index_pos_discount_allocations_on_pos_line_item_id"
    t.check_constraint "allocated_amount_cents >= 0", name: "pos_discount_allocations_amount_non_negative"
    t.check_constraint "eligible_amount_cents IS NULL OR eligible_amount_cents >= 0", name: "pos_discount_allocations_eligible_non_negative"
  end

  create_table "pos_discounts", force: :cascade do |t|
    t.integer "applied_amount_cents", null: false
    t.integer "base_amount_cents"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "discount_reason_id"
    t.string "method", null: false
    t.bigint "pos_transaction_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "rate_bps"
    t.integer "requested_amount_cents"
    t.string "scope", null: false
    t.bigint "target_pos_line_item_id"
    t.string "tax_treatment", default: "reduces_taxable_base", null: false
    t.index ["created_by_user_id"], name: "index_pos_discounts_on_created_by_user_id"
    t.index ["discount_reason_id"], name: "index_pos_discounts_on_discount_reason_id"
    t.index ["pos_transaction_id"], name: "index_pos_discounts_on_pos_transaction_id"
    t.index ["target_pos_line_item_id"], name: "index_pos_discounts_on_target_pos_line_item_id"
    t.check_constraint "applied_amount_cents >= 0", name: "pos_discounts_applied_amount_non_negative"
    t.check_constraint "base_amount_cents IS NULL OR base_amount_cents >= 0", name: "pos_discounts_base_amount_non_negative"
    t.check_constraint "method::text = ANY (ARRAY['percentage'::character varying::text, 'fixed_amount'::character varying::text, 'fixed_price'::character varying::text])", name: "pos_discounts_method_check"
    t.check_constraint "rate_bps IS NULL OR rate_bps >= 0", name: "pos_discounts_rate_bps_non_negative"
    t.check_constraint "requested_amount_cents IS NULL OR requested_amount_cents >= 0", name: "pos_discounts_requested_amount_non_negative"
    t.check_constraint "scope::text = 'line'::text AND target_pos_line_item_id IS NOT NULL OR scope::text = 'transaction'::text AND target_pos_line_item_id IS NULL", name: "pos_discounts_target_matches_scope"
    t.check_constraint "scope::text = ANY (ARRAY['line'::character varying::text, 'transaction'::character varying::text])", name: "pos_discounts_scope_check"
    t.check_constraint "tax_treatment::text = ANY (ARRAY['reduces_taxable_base'::character varying::text, 'does_not_reduce_taxable_base'::character varying::text])", name: "pos_discounts_tax_treatment_check"
  end

  create_table "pos_line_item_taxes", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.boolean "compounds_on_prior_tax_snapshot", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "pos_line_item_id", null: false
    t.integer "position", default: 0, null: false
    t.decimal "rate", precision: 10, scale: 8
    t.string "receipt_code_snapshot"
    t.bigint "store_tax_rate_id"
    t.bigint "store_tax_rule_id", null: false
    t.bigint "tax_category_id", null: false
    t.integer "taxable_amount_cents", default: 0, null: false
    t.decimal "taxable_fraction_snapshot", precision: 10, scale: 8, null: false
    t.string "treatment_snapshot", null: false
    t.index ["pos_line_item_id"], name: "index_pos_line_item_taxes_on_pos_line_item_id"
    t.index ["store_tax_rate_id"], name: "index_pos_line_item_taxes_on_store_tax_rate_id"
    t.index ["store_tax_rule_id"], name: "index_pos_line_item_taxes_on_store_tax_rule_id"
    t.index ["tax_category_id"], name: "index_pos_line_item_taxes_on_tax_category_id"
    t.check_constraint "amount_cents >= 0", name: "pos_line_item_taxes_amount_non_negative"
    t.check_constraint "taxable_amount_cents >= 0", name: "pos_line_item_taxes_taxable_amount_non_negative"
    t.check_constraint "treatment_snapshot::text = ANY (ARRAY['taxable'::character varying::text, 'zero_rated'::character varying::text, 'exempt'::character varying::text, 'not_applicable'::character varying::text])", name: "pos_line_item_taxes_treatment_check"
  end

  create_table "pos_line_items", force: :cascade do |t|
    t.datetime "completed_at"
    t.integer "cost_extended_cents"
    t.string "cost_method_snapshot"
    t.string "cost_quality_snapshot"
    t.integer "cost_unit_cost_cents"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "department_id"
    t.string "description_snapshot"
    t.string "direction", default: "sale", null: false
    t.bigint "inventory_unit_id"
    t.string "line_kind", null: false
    t.bigint "original_pos_line_item_id"
    t.bigint "original_tax_category_id"
    t.bigint "pos_transaction_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "price_overridden_at"
    t.bigint "price_overridden_by_user_id"
    t.bigint "product_request_id"
    t.bigint "product_variant_id"
    t.integer "quantity", default: 1, null: false
    t.text "remove_reason"
    t.datetime "removed_at"
    t.bigint "removed_by_user_id"
    t.string "return_disposition"
    t.bigint "return_reason_id"
    t.string "return_source"
    t.bigint "reverses_pos_line_item_id"
    t.string "status", default: "pending", null: false
    t.bigint "stored_value_account_id"
    t.string "stored_value_account_number_snapshot"
    t.string "stored_value_account_type_snapshot"
    t.string "stored_value_operation"
    t.bigint "tax_category_id"
    t.datetime "tax_category_overridden_at"
    t.bigint "tax_category_overridden_by_user_id"
    t.text "tax_category_override_reason"
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_pos_line_items_on_created_by_user_id"
    t.index ["department_id"], name: "index_pos_line_items_on_department_id"
    t.index ["inventory_unit_id"], name: "index_pos_line_items_on_inventory_unit_id"
    t.index ["original_pos_line_item_id"], name: "index_pos_line_items_on_original_pos_line_item_id"
    t.index ["original_tax_category_id"], name: "index_pos_line_items_on_original_tax_category_id"
    t.index ["pos_transaction_id"], name: "index_pos_line_items_on_pos_transaction_id"
    t.index ["price_overridden_by_user_id"], name: "index_pos_line_items_on_price_overridden_by_user_id"
    t.index ["product_request_id"], name: "index_pos_line_items_on_product_request_id"
    t.index ["product_variant_id"], name: "index_pos_line_items_on_product_variant_id"
    t.index ["removed_by_user_id"], name: "index_pos_line_items_on_removed_by_user_id"
    t.index ["return_reason_id"], name: "index_pos_line_items_on_return_reason_id"
    t.index ["reverses_pos_line_item_id"], name: "index_pos_line_items_on_reverses_pos_line_item_id"
    t.index ["reverses_pos_line_item_id"], name: "index_pos_line_items_reverses_unique", unique: true, where: "(reverses_pos_line_item_id IS NOT NULL)"
    t.index ["stored_value_account_id"], name: "index_pos_line_items_on_stored_value_account_id"
    t.index ["tax_category_id"], name: "index_pos_line_items_on_tax_category_id"
    t.index ["tax_category_overridden_by_user_id"], name: "index_pos_line_items_on_tax_category_overridden_by_user_id"
    t.check_constraint "(line_kind::text = ANY (ARRAY['product'::character varying::text, 'open_ring'::character varying::text])) AND department_id IS NOT NULL OR line_kind::text = 'stored_value'::text AND department_id IS NULL", name: "pos_line_items_department_matches_kind"
    t.check_constraint "cost_extended_cents IS NULL OR cost_extended_cents >= 0", name: "pos_line_items_cost_extended_non_negative"
    t.check_constraint "cost_method_snapshot IS NULL OR (cost_method_snapshot::text = ANY (ARRAY['explicit'::character varying::text, 'configured_estimate'::character varying::text, 'moving_average'::character varying::text, 'last_known'::character varying::text, 'unknown'::character varying::text]))", name: "pos_line_items_cost_method_snapshot_check"
    t.check_constraint "cost_quality_snapshot IS NULL OR (cost_quality_snapshot::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text]))", name: "pos_line_items_cost_quality_snapshot_check"
    t.check_constraint "cost_unit_cost_cents IS NULL OR cost_unit_cost_cents >= 0", name: "pos_line_items_cost_unit_cost_non_negative"
    t.check_constraint "direction::text = 'sale'::text OR reverses_pos_line_item_id IS NOT NULL OR original_pos_line_item_id IS NOT NULL AND return_reason_id IS NOT NULL AND return_disposition IS NOT NULL", name: "pos_line_items_return_requires_link"
    t.check_constraint "direction::text = ANY (ARRAY['sale'::character varying::text, 'return'::character varying::text])", name: "pos_line_items_direction_check"
    t.check_constraint "inventory_unit_id IS NULL OR line_kind::text = 'product'::text", name: "pos_line_items_unit_matches_kind"
    t.check_constraint "inventory_unit_id IS NULL OR quantity = 1", name: "pos_line_items_unit_quantity_one"
    t.check_constraint "line_kind::text = 'product'::text AND product_variant_id IS NOT NULL OR line_kind::text = 'open_ring'::text AND product_variant_id IS NULL OR line_kind::text = 'stored_value'::text AND product_variant_id IS NULL AND inventory_unit_id IS NULL AND tax_category_id IS NULL AND department_id IS NULL AND stored_value_account_id IS NOT NULL AND (stored_value_operation::text = ANY (ARRAY['issue'::character varying::text, 'reload'::character varying::text])) AND quantity = 1 AND direction::text = 'sale'::text", name: "pos_line_items_product_variant_matches_kind"
    t.check_constraint "line_kind::text = ANY (ARRAY['product'::character varying::text, 'open_ring'::character varying::text, 'stored_value'::character varying::text])", name: "pos_line_items_line_kind_check"
    t.check_constraint "product_request_id IS NULL OR line_kind::text = 'product'::text AND direction::text = 'sale'::text", name: "pos_line_items_product_request_requires_product_sale"
    t.check_constraint "quantity > 0", name: "pos_line_items_quantity_positive"
    t.check_constraint "return_disposition IS NULL OR (return_disposition::text = ANY (ARRAY['return_to_stock'::character varying::text, 'inspection_required'::character varying::text, 'damaged'::character varying::text, 'return_to_vendor'::character varying::text, 'discard'::character varying::text, 'non_inventory'::character varying::text]))", name: "pos_line_items_return_disposition_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'completed'::character varying::text, 'removed'::character varying::text])", name: "pos_line_items_status_check"
    t.check_constraint "unit_price_cents >= 0", name: "pos_line_items_unit_price_non_negative"
  end

  create_table "pos_session_cash_counts", force: :cascade do |t|
    t.string "count_type", null: false
    t.datetime "counted_at", null: false
    t.bigint "counted_by_user_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "denomination_detail"
    t.bigint "pos_session_id", null: false
    t.integer "total_cents", null: false
    t.index ["counted_by_user_id"], name: "index_pos_session_cash_counts_on_counted_by_user_id"
    t.index ["pos_session_id", "count_type"], name: "index_pos_session_cash_counts_one_opening_closing", unique: true, where: "((count_type)::text = ANY (ARRAY[('opening'::character varying)::text, ('closing'::character varying)::text]))"
    t.index ["pos_session_id"], name: "index_pos_session_cash_counts_on_pos_session_id"
    t.check_constraint "count_type::text = ANY (ARRAY['opening'::character varying::text, 'closing'::character varying::text, 'manager_recount'::character varying::text, 'reconciled'::character varying::text])", name: "pos_session_cash_counts_type_check"
    t.check_constraint "total_cents >= 0", name: "pos_session_cash_counts_total_non_negative"
  end

  create_table "pos_sessions", force: :cascade do |t|
    t.bigint "business_day_id", null: false
    t.bigint "cash_drawer_id"
    t.integer "cash_variance_cents"
    t.bigint "cashier_user_id", null: false
    t.datetime "closed_at"
    t.bigint "closed_by_user_id"
    t.integer "counted_cash_cents"
    t.datetime "created_at", null: false
    t.integer "expected_cash_cents"
    t.datetime "opened_at", null: false
    t.bigint "opened_by_user_id", null: false
    t.integer "opening_cash_cents"
    t.bigint "pos_device_id", null: false
    t.string "status", default: "open", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["business_day_id"], name: "index_pos_sessions_on_business_day_id"
    t.index ["cash_drawer_id"], name: "index_pos_sessions_on_cash_drawer_id"
    t.index ["cash_drawer_id"], name: "index_pos_sessions_one_active_per_drawer", unique: true, where: "(((status)::text = 'open'::text) AND (cash_drawer_id IS NOT NULL))"
    t.index ["cashier_user_id"], name: "index_pos_sessions_on_cashier_user_id"
    t.index ["closed_by_user_id"], name: "index_pos_sessions_on_closed_by_user_id"
    t.index ["opened_by_user_id"], name: "index_pos_sessions_on_opened_by_user_id"
    t.index ["pos_device_id"], name: "index_pos_sessions_on_pos_device_id"
    t.index ["pos_device_id"], name: "index_pos_sessions_one_open_per_device", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["store_id"], name: "index_pos_sessions_on_store_id"
    t.check_constraint "counted_cash_cents IS NULL OR counted_cash_cents >= 0", name: "pos_sessions_counted_cash_non_negative"
    t.check_constraint "opening_cash_cents IS NULL OR opening_cash_cents >= 0", name: "pos_sessions_opening_cash_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'closed'::character varying::text])", name: "pos_sessions_status_check"
  end

  create_table "pos_tax_exemptions", force: :cascade do |t|
    t.string "coverage", default: "whole_transaction", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.string "exemption_type", null: false
    t.text "notes"
    t.bigint "pos_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_pos_tax_exemptions_on_created_by_user_id"
    t.index ["pos_transaction_id"], name: "index_pos_tax_exemptions_on_pos_transaction_id"
    t.index ["pos_transaction_id"], name: "index_pos_tax_exemptions_one_per_transaction", unique: true
    t.check_constraint "coverage::text = 'whole_transaction'::text", name: "pos_tax_exemptions_coverage_check"
  end

  create_table "pos_tenders", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.integer "amount_tendered_cents"
    t.string "authorization_code"
    t.datetime "authorized_at"
    t.integer "change_due_cents"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.string "direction", default: "received", null: false
    t.datetime "external_void_confirmed_at"
    t.bigint "external_void_confirmed_by_user_id"
    t.string "external_void_reference"
    t.bigint "original_pos_tender_id"
    t.bigint "pos_approval_id"
    t.bigint "pos_transaction_id", null: false
    t.string "recording_idempotency_key"
    t.text "remove_reason"
    t.datetime "removed_at"
    t.bigint "removed_by_user_id"
    t.boolean "requires_reconciliation", default: false, null: false
    t.bigint "reverses_pos_tender_id"
    t.string "status", default: "pending", null: false
    t.bigint "store_id", null: false
    t.bigint "stored_value_account_id"
    t.bigint "tender_type_id", null: false
    t.string "terminal_reference"
    t.datetime "updated_at", null: false
    t.text "void_reason"
    t.datetime "voided_at"
    t.bigint "voided_by_user_id"
    t.index ["created_by_user_id"], name: "index_pos_tenders_on_created_by_user_id"
    t.index ["external_void_confirmed_by_user_id"], name: "index_pos_tenders_on_external_void_confirmed_by_user_id"
    t.index ["original_pos_tender_id"], name: "index_pos_tenders_on_original_pos_tender_id"
    t.index ["pos_approval_id"], name: "index_pos_tenders_on_pos_approval_id"
    t.index ["pos_transaction_id", "status"], name: "index_pos_tenders_on_pos_transaction_id_and_status"
    t.index ["pos_transaction_id"], name: "index_pos_tenders_on_pos_transaction_id"
    t.index ["recording_idempotency_key"], name: "index_pos_tenders_on_recording_idempotency_key_unique", unique: true, where: "(recording_idempotency_key IS NOT NULL)"
    t.index ["removed_by_user_id"], name: "index_pos_tenders_on_removed_by_user_id"
    t.index ["reverses_pos_tender_id"], name: "index_pos_tenders_on_reverses_pos_tender_id"
    t.index ["reverses_pos_tender_id"], name: "index_pos_tenders_reverses_unique", unique: true, where: "(reverses_pos_tender_id IS NOT NULL)"
    t.index ["store_id"], name: "index_pos_tenders_on_store_id"
    t.index ["stored_value_account_id"], name: "index_pos_tenders_on_stored_value_account_id"
    t.index ["tender_type_id"], name: "index_pos_tenders_on_tender_type_id"
    t.index ["voided_by_user_id"], name: "index_pos_tenders_on_voided_by_user_id"
    t.check_constraint "amount_cents >= 0", name: "pos_tenders_amount_non_negative"
    t.check_constraint "amount_tendered_cents IS NULL OR amount_tendered_cents >= 0", name: "pos_tenders_amount_tendered_non_negative"
    t.check_constraint "change_due_cents IS NULL OR change_due_cents >= 0", name: "pos_tenders_change_due_non_negative"
    t.check_constraint "direction::text = ANY (ARRAY['received'::character varying::text, 'refunded'::character varying::text])", name: "pos_tenders_direction_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'authorized'::character varying::text, 'completed'::character varying::text, 'voided'::character varying::text, 'removed'::character varying::text, 'void_required'::character varying::text])", name: "pos_tenders_status_check"
  end

  create_table "pos_transactions", force: :cascade do |t|
    t.bigint "active_pos_session_id"
    t.text "cancel_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_user_id"
    t.bigint "cashier_user_id", null: false
    t.datetime "completed_at"
    t.bigint "completed_by_user_id"
    t.bigint "completed_pos_session_id"
    t.string "completion_idempotency_key"
    t.datetime "created_at", null: false
    t.bigint "discount_total_cents"
    t.bigint "net_total_cents"
    t.datetime "opened_at", null: false
    t.bigint "origin_pos_session_id", null: false
    t.bigint "post_void_pos_approval_id"
    t.text "post_void_reason"
    t.string "public_id", null: false
    t.datetime "recalled_at"
    t.string "receipt_number"
    t.bigint "receipt_sequence"
    t.bigint "reverses_pos_transaction_id"
    t.string "status", default: "open", null: false
    t.bigint "store_id", null: false
    t.bigint "subtotal_cents"
    t.datetime "suspended_at"
    t.bigint "tax_total_cents"
    t.datetime "updated_at", null: false
    t.index ["active_pos_session_id"], name: "index_pos_transactions_on_active_pos_session_id"
    t.index ["cancelled_by_user_id"], name: "index_pos_transactions_on_cancelled_by_user_id"
    t.index ["cashier_user_id"], name: "index_pos_transactions_on_cashier_user_id"
    t.index ["completed_by_user_id"], name: "index_pos_transactions_on_completed_by_user_id"
    t.index ["completed_pos_session_id"], name: "index_pos_transactions_on_completed_pos_session_id"
    t.index ["completion_idempotency_key"], name: "index_pos_transactions_on_completion_idempotency_key", unique: true, where: "(completion_idempotency_key IS NOT NULL)"
    t.index ["origin_pos_session_id"], name: "index_pos_transactions_on_origin_pos_session_id"
    t.index ["post_void_pos_approval_id"], name: "index_pos_transactions_on_post_void_pos_approval_id"
    t.index ["public_id"], name: "index_pos_transactions_on_public_id", unique: true
    t.index ["reverses_pos_transaction_id"], name: "index_pos_transactions_on_reverses_pos_transaction_id"
    t.index ["reverses_pos_transaction_id"], name: "index_pos_transactions_reverses_unique", unique: true, where: "(reverses_pos_transaction_id IS NOT NULL)"
    t.index ["store_id", "receipt_number"], name: "index_pos_transactions_on_store_and_receipt_number", unique: true, where: "(receipt_number IS NOT NULL)"
    t.index ["store_id", "receipt_sequence"], name: "index_pos_transactions_on_store_and_receipt_sequence", unique: true, where: "(receipt_sequence IS NOT NULL)"
    t.index ["store_id"], name: "index_pos_transactions_on_store_id"
    t.check_constraint "status::text <> 'completed'::text OR receipt_number IS NOT NULL AND completed_at IS NOT NULL", name: "pos_transactions_completed_requires_receipt"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'suspended'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text])", name: "pos_transactions_status_check"
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
    t.index ["organization_id", "short_code"], name: "index_product_formats_on_organization_id_and_short_code", unique: true
    t.index ["organization_id"], name: "index_product_formats_on_organization_id"
    t.check_constraint "default_inventory_tracking_mode::text = ANY (ARRAY['quantity'::character varying::text, 'individual'::character varying::text, 'none'::character varying::text])", name: "product_formats_tracking_mode_check"
  end

  create_table "product_request_fulfillments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "fulfilled_at", null: false
    t.bigint "fulfilled_by_user_id", null: false
    t.bigint "inventory_reservation_id"
    t.string "kind", default: "fulfill", null: false
    t.bigint "linked_fulfilment_id"
    t.bigint "pos_line_item_id", null: false
    t.string "posting_key", null: false
    t.bigint "product_request_id", null: false
    t.integer "quantity", null: false
    t.index ["fulfilled_by_user_id"], name: "index_product_request_fulfillments_on_fulfilled_by_user_id"
    t.index ["inventory_reservation_id"], name: "index_product_request_fulfillments_on_inventory_reservation_id"
    t.index ["linked_fulfilment_id"], name: "index_product_request_fulfillments_on_linked_fulfilment_id"
    t.index ["pos_line_item_id"], name: "index_product_request_fulfillments_on_pos_line_item_id"
    t.index ["posting_key"], name: "index_product_request_fulfillments_on_posting_key", unique: true
    t.index ["product_request_id"], name: "index_product_request_fulfillments_on_product_request_id"
    t.check_constraint "kind::text = 'fulfill'::text AND linked_fulfilment_id IS NULL OR kind::text = 'reverse'::text AND linked_fulfilment_id IS NOT NULL", name: "prf_reverse_requires_link"
    t.check_constraint "kind::text = ANY (ARRAY['fulfill'::character varying::text, 'reverse'::character varying::text])", name: "prf_kind_check"
    t.check_constraint "quantity > 0", name: "prf_quantity_positive"
  end

  create_table "product_requests", force: :cascade do |t|
    t.bigint "assigned_buyer_user_id"
    t.datetime "created_at", null: false
    t.string "customer_reference"
    t.date "needed_by_on"
    t.text "notes"
    t.string "priority", default: "normal", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.string "request_type", null: false
    t.bigint "requested_by_user_id", null: false
    t.integer "requested_quantity", null: false
    t.string "resolution"
    t.text "resolution_note"
    t.datetime "resolved_at"
    t.bigint "resolved_by_user_id"
    t.integer "resolved_quantity"
    t.string "status", default: "open", null: false
    t.bigint "store_id", null: false
    t.bigint "supersedes_product_request_id"
    t.datetime "updated_at", null: false
    t.index ["assigned_buyer_user_id"], name: "index_product_requests_on_assigned_buyer_user_id"
    t.index ["product_id"], name: "index_product_requests_on_product_id"
    t.index ["product_variant_id"], name: "index_product_requests_on_product_variant_id"
    t.index ["requested_by_user_id"], name: "index_product_requests_on_requested_by_user_id"
    t.index ["resolved_by_user_id"], name: "index_product_requests_on_resolved_by_user_id"
    t.index ["store_id", "request_type", "status"], name: "index_product_requests_on_store_type_status"
    t.index ["store_id", "request_type"], name: "index_product_requests_on_store_id_and_request_type"
    t.index ["store_id", "status"], name: "index_product_requests_on_store_id_and_status"
    t.index ["store_id"], name: "index_product_requests_on_store_id"
    t.index ["supersedes_product_request_id"], name: "index_product_requests_on_supersedes_product_request_id"
    t.check_constraint "priority::text = ANY (ARRAY['normal'::character varying::text, 'high'::character varying::text, 'urgent'::character varying::text])", name: "product_requests_priority_check"
    t.check_constraint "request_type::text = ANY (ARRAY['customer_request'::character varying::text, 'staff_suggestion'::character varying::text, 'stock_replenishment'::character varying::text, 'frontlist_selection'::character varying::text])", name: "product_requests_request_type_check"
    t.check_constraint "requested_quantity > 0", name: "product_requests_requested_quantity_positive"
    t.check_constraint "resolution IS NULL OR (resolution::text = ANY (ARRAY['ordered'::character varying::text, 'declined'::character varying::text, 'deferred'::character varying::text, 'duplicate'::character varying::text, 'superseded'::character varying::text, 'no_longer_needed'::character varying::text]))", name: "product_requests_resolution_check"
    t.check_constraint "resolved_quantity IS NULL OR resolved_quantity <= requested_quantity", name: "product_requests_resolved_quantity_within_requested"
    t.check_constraint "resolved_quantity IS NULL OR resolved_quantity >= 0", name: "product_requests_resolved_quantity_nonneg"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'fulfilled'::character varying::text, 'declined'::character varying::text, 'cancelled'::character varying::text, 'closed'::character varying::text])", name: "product_requests_status_check"
    t.check_constraint "supersedes_product_request_id IS NULL OR supersedes_product_request_id <> id", name: "product_requests_supersedes_not_self"
  end

  create_table "product_variant_vendors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "discount_bps"
    t.integer "expected_unit_cost_cents"
    t.datetime "last_ordered_at"
    t.datetime "last_received_at"
    t.integer "list_cost_cents"
    t.integer "minimum_order_quantity"
    t.text "notes"
    t.integer "order_multiple"
    t.boolean "preferred", default: false, null: false
    t.bigint "product_variant_id", null: false
    t.boolean "returnable"
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.string "vendor_identifier"
    t.string "vendor_item_code"
    t.index ["product_variant_id", "vendor_id"], name: "index_product_variant_vendors_on_variant_and_vendor", unique: true
    t.index ["product_variant_id"], name: "index_product_variant_vendors_on_product_variant_id"
    t.index ["vendor_id"], name: "index_product_variant_vendors_on_vendor_id"
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
    t.index ["product_id"], name: "index_product_variants_on_product_id_unique", unique: true
    t.index ["return_policy_id"], name: "index_product_variants_on_return_policy_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.index ["tax_category_id"], name: "index_product_variants_on_tax_category_id"
    t.check_constraint "available_from IS NULL OR available_until IS NULL OR available_from <= available_until", name: "product_variants_availability_window_order"
    t.check_constraint "inventory_tracking_mode::text = ANY (ARRAY['quantity'::character varying::text, 'individual'::character varying::text, 'none'::character varying::text])", name: "product_variants_inventory_tracking_mode_check"
    t.check_constraint "regular_price_cents IS NULL OR regular_price_cents >= 0", name: "product_variants_regular_price_cents_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'discontinued'::character varying::text])", name: "product_variants_status_check"
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
    t.check_constraint "identifier_validation_status::text = ANY (ARRAY['valid'::character varying::text, 'warning'::character varying::text, 'invalid'::character varying::text, 'not_applicable'::character varying::text])", name: "products_identifier_validation_status_check"
    t.check_constraint "list_price_cents IS NULL OR list_price_cents >= 0", name: "products_list_price_cents_non_negative"
    t.check_constraint "product_type::text = ANY (ARRAY['book'::character varying::text, 'recorded_music'::character varying::text, 'video'::character varying::text, 'periodical'::character varying::text, 'game'::character varying::text, 'stationery'::character varying::text, 'gift'::character varying::text, 'cafe'::character varying::text, 'service'::character varying::text, 'other'::character varying::text])", name: "products_product_type_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'discontinued'::character varying::text])", name: "products_status_check"
    t.check_constraint "variant_structure::text = 'single'::text", name: "products_variant_structure_single"
  end

  create_table "purchase_order_allocation_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "inventory_reservation_id"
    t.text "note"
    t.datetime "occurred_at", null: false
    t.string "posting_key"
    t.bigint "purchase_order_allocation_id", null: false
    t.integer "quantity", null: false
    t.string "reason"
    t.bigint "receipt_line_id"
    t.bigint "user_id", null: false
    t.index ["inventory_reservation_id"], name: "idx_on_inventory_reservation_id_b6d5c66ee6"
    t.index ["posting_key"], name: "index_po_allocation_events_on_posting_key", unique: true
    t.index ["purchase_order_allocation_id"], name: "idx_on_purchase_order_allocation_id_bd612eb847"
    t.index ["receipt_line_id"], name: "index_purchase_order_allocation_events_on_receipt_line_id"
    t.index ["user_id"], name: "index_purchase_order_allocation_events_on_user_id"
    t.check_constraint "event_type::text <> 'released'::text OR reason IS NOT NULL", name: "po_allocation_events_released_requires_reason"
    t.check_constraint "event_type::text = ANY (ARRAY['converted_to_reservation'::character varying::text, 'released'::character varying::text])", name: "po_allocation_events_event_type_check"
    t.check_constraint "quantity > 0", name: "po_allocation_events_quantity_positive"
    t.check_constraint "reason IS NULL OR (reason::text = ANY (ARRAY['purchase_order_cancelled'::character varying::text, 'line_quantity_cancelled'::character varying::text, 'vendor_unavailable'::character varying::text, 'received_unavailable'::character varying::text, 'request_cancelled'::character varying::text, 'request_quantity_reduced'::character varying::text, 'fulfilled_from_earlier_supply'::character varying::text, 'reallocated_to_other_supply'::character varying::text, 'manual_release'::character varying::text]))", name: "po_allocation_events_reason_check"
  end

  create_table "purchase_order_allocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "product_request_id", null: false
    t.bigint "purchase_order_line_id", null: false
    t.integer "quantity", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_purchase_order_allocations_on_created_by_user_id"
    t.index ["product_request_id"], name: "index_purchase_order_allocations_on_product_request_id"
    t.index ["purchase_order_line_id", "product_request_id"], name: "index_po_allocations_on_line_and_request", unique: true
    t.index ["purchase_order_line_id"], name: "index_purchase_order_allocations_on_purchase_order_line_id"
    t.check_constraint "quantity > 0", name: "po_allocations_quantity_positive"
  end

  create_table "purchase_order_lines", force: :cascade do |t|
    t.integer "cancelled_quantity", default: 0, null: false
    t.string "cost_entry_method", null: false
    t.string "cost_provenance"
    t.datetime "created_at", null: false
    t.string "description_snapshot"
    t.integer "discount_bps"
    t.integer "expected_extended_cost_cents"
    t.integer "expected_unit_cost_cents", null: false
    t.string "identifier_snapshot"
    t.integer "list_cost_cents"
    t.text "notes"
    t.integer "ordered_quantity", null: false
    t.integer "position", default: 0, null: false
    t.bigint "product_variant_id", null: false
    t.bigint "product_variant_vendor_id"
    t.bigint "purchase_order_id", null: false
    t.integer "received_quantity", default: 0, null: false
    t.boolean "returnable_snapshot"
    t.string "sku_snapshot"
    t.datetime "updated_at", null: false
    t.string "vendor_item_code_snapshot"
    t.index ["product_variant_id"], name: "index_purchase_order_lines_on_product_variant_id"
    t.index ["product_variant_vendor_id"], name: "index_purchase_order_lines_on_product_variant_vendor_id"
    t.index ["purchase_order_id"], name: "index_purchase_order_lines_on_purchase_order_id"
    t.check_constraint "cancelled_quantity <= ordered_quantity", name: "po_lines_cancelled_quantity_within_ordered"
    t.check_constraint "cancelled_quantity >= 0", name: "po_lines_cancelled_quantity_nonneg"
    t.check_constraint "cost_entry_method::text = ANY (ARRAY['discount_from_list'::character varying::text, 'direct_net_cost'::character varying::text])", name: "po_lines_cost_entry_method_check"
    t.check_constraint "discount_bps IS NULL OR discount_bps >= 0 AND discount_bps <= 10000", name: "po_lines_discount_bps_range"
    t.check_constraint "expected_extended_cost_cents IS NULL OR expected_extended_cost_cents >= 0", name: "po_lines_expected_extended_cost_nonneg"
    t.check_constraint "expected_unit_cost_cents >= 0", name: "po_lines_expected_unit_cost_nonneg"
    t.check_constraint "list_cost_cents IS NULL OR list_cost_cents >= 0", name: "po_lines_list_cost_nonneg"
    t.check_constraint "ordered_quantity > 0", name: "po_lines_ordered_quantity_positive"
    t.check_constraint "received_quantity >= 0", name: "po_lines_received_quantity_nonneg"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.bigint "buyer_user_id"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_user_id"
    t.datetime "closed_at"
    t.bigint "closed_by_user_id"
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.date "expected_on"
    t.text "notes"
    t.datetime "ordered_at"
    t.bigint "ordered_by_user_id"
    t.date "ordered_on"
    t.string "purchase_order_number", null: false
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.string "vendor_reference"
    t.index ["buyer_user_id"], name: "index_purchase_orders_on_buyer_user_id"
    t.index ["cancelled_by_user_id"], name: "index_purchase_orders_on_cancelled_by_user_id"
    t.index ["closed_by_user_id"], name: "index_purchase_orders_on_closed_by_user_id"
    t.index ["ordered_by_user_id"], name: "index_purchase_orders_on_ordered_by_user_id"
    t.index ["store_id", "purchase_order_number"], name: "index_purchase_orders_on_store_and_number", unique: true
    t.index ["store_id"], name: "index_purchase_orders_on_store_id"
    t.index ["vendor_id"], name: "index_purchase_orders_on_vendor_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'ordered'::character varying::text, 'closed'::character varying::text, 'cancelled'::character varying::text])", name: "purchase_orders_status_check"
  end

  create_table "receipt_lines", force: :cascade do |t|
    t.integer "accepted_quantity", default: 0, null: false
    t.integer "accepted_unavailable_quantity", default: 0, null: false
    t.integer "actual_unit_cost_cents"
    t.string "cost_provenance"
    t.string "cost_quality"
    t.datetime "created_at", null: false
    t.integer "delivered_quantity", null: false
    t.string "discrepancy_reason"
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.bigint "product_variant_id", null: false
    t.bigint "purchase_order_line_id"
    t.bigint "receipt_id", null: false
    t.integer "rejected_quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_receipt_lines_on_product_variant_id"
    t.index ["purchase_order_line_id"], name: "index_receipt_lines_on_purchase_order_line_id"
    t.index ["receipt_id", "position"], name: "index_receipt_lines_on_receipt_and_position"
    t.index ["receipt_id"], name: "index_receipt_lines_on_receipt_id"
    t.check_constraint "(accepted_quantity + rejected_quantity) <= delivered_quantity", name: "receipt_lines_accepted_rejected_within_delivered"
    t.check_constraint "accepted_quantity >= 0", name: "receipt_lines_accepted_nonneg"
    t.check_constraint "accepted_unavailable_quantity <= accepted_quantity", name: "receipt_lines_accepted_unavailable_within_accepted"
    t.check_constraint "accepted_unavailable_quantity >= 0", name: "receipt_lines_accepted_unavailable_nonneg"
    t.check_constraint "actual_unit_cost_cents IS NULL OR actual_unit_cost_cents >= 0", name: "receipt_lines_unit_cost_nonneg"
    t.check_constraint "cost_provenance IS NULL OR (cost_provenance::text = ANY (ARRAY['purchase_order_expected'::character varying::text, 'purchase_order_list_discount'::character varying::text, 'vendor_source_expected'::character varying::text, 'vendor_list_discount'::character varying::text, 'manual_receipt'::character varying::text, 'unknown'::character varying::text, 'confirmed_zero'::character varying::text]))", name: "receipt_lines_cost_provenance_check"
    t.check_constraint "cost_quality IS NULL OR (cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'unknown'::character varying::text, 'confirmed_zero'::character varying::text]))", name: "receipt_lines_cost_quality_check"
    t.check_constraint "cost_quality::text IS DISTINCT FROM 'confirmed_zero'::text OR actual_unit_cost_cents = 0 AND cost_provenance::text = 'confirmed_zero'::text", name: "receipt_lines_cost_confirmed_zero_tuple_check"
    t.check_constraint "cost_quality::text IS DISTINCT FROM 'unknown'::text OR actual_unit_cost_cents IS NULL AND cost_provenance::text = 'unknown'::text", name: "receipt_lines_cost_unknown_tuple_check"
    t.check_constraint "delivered_quantity >= 0", name: "receipt_lines_delivered_nonneg"
    t.check_constraint "rejected_quantity >= 0", name: "receipt_lines_rejected_nonneg"
  end

  create_table "receipts", force: :cascade do |t|
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_user_id"
    t.datetime "created_at", null: false
    t.text "notes"
    t.datetime "posted_at"
    t.bigint "posted_by_user_id"
    t.string "posting_key"
    t.string "receipt_number", null: false
    t.datetime "received_at"
    t.bigint "received_by_user_id"
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.index ["cancelled_by_user_id"], name: "index_receipts_on_cancelled_by_user_id"
    t.index ["posted_by_user_id"], name: "index_receipts_on_posted_by_user_id"
    t.index ["posting_key"], name: "index_receipts_on_posting_key", unique: true, where: "(posting_key IS NOT NULL)"
    t.index ["received_by_user_id"], name: "index_receipts_on_received_by_user_id"
    t.index ["store_id", "receipt_number"], name: "index_receipts_on_store_and_number", unique: true
    t.index ["store_id"], name: "index_receipts_on_store_id"
    t.index ["vendor_id"], name: "index_receipts_on_vendor_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'posted'::character varying::text, 'cancelled'::character varying::text])", name: "receipts_status_check"
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

  create_table "stock_balances", force: :cascade do |t|
    t.string "cost_quality", default: "unknown", null: false
    t.datetime "created_at", null: false
    t.string "deficit_cost_quality", default: "unknown", null: false
    t.bigint "inventory_value_cents", default: 0
    t.string "last_known_cost_quality"
    t.integer "last_known_unit_cost_cents"
    t.integer "lock_version", default: 0, null: false
    t.integer "moving_average_cost_cents"
    t.integer "on_hand", default: 0, null: false
    t.bigint "open_provisional_deficit_cost_cents", default: 0
    t.bigint "product_variant_id", null: false
    t.integer "reserved", default: 0, null: false
    t.bigint "store_id", null: false
    t.integer "unavailable", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_stock_balances_on_product_variant_id"
    t.index ["store_id", "product_variant_id"], name: "index_stock_balances_on_store_id_and_product_variant_id", unique: true
    t.index ["store_id"], name: "index_stock_balances_on_store_id"
    t.check_constraint "cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text])", name: "stock_balances_cost_quality"
    t.check_constraint "deficit_cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text])", name: "stock_balances_deficit_cost_quality_check"
    t.check_constraint "last_known_cost_quality IS NULL OR (last_known_cost_quality::text = ANY (ARRAY['actual'::character varying::text, 'estimated'::character varying::text, 'mixed'::character varying::text, 'unknown'::character varying::text]))", name: "stock_balances_last_known_cost_quality"
    t.check_constraint "on_hand < 0 OR open_provisional_deficit_cost_cents = 0 AND deficit_cost_quality::text = 'unknown'::text", name: "stock_balances_deficit_zero_state"
    t.check_constraint "on_hand <= 0 OR cost_quality::text = 'unknown'::text AND inventory_value_cents IS NULL OR cost_quality::text <> 'unknown'::text AND inventory_value_cents IS NOT NULL", name: "stock_balances_positive_value_state"
    t.check_constraint "on_hand <> 0 OR cost_quality::text = 'unknown'::text", name: "stock_balances_zero_quality_unknown"
    t.check_constraint "on_hand > 0 OR inventory_value_cents = 0 AND moving_average_cost_cents IS NULL", name: "stock_balances_nonpositive_value_state"
    t.check_constraint "open_provisional_deficit_cost_cents IS NULL OR open_provisional_deficit_cost_cents >= 0", name: "stock_balances_deficit_cost_nonneg"
    t.check_constraint "reserved >= 0", name: "stock_balances_reserved_nonneg"
    t.check_constraint "unavailable >= 0", name: "stock_balances_unavailable_nonneg"
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

  create_table "store_tax_rates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.date "effective_from"
    t.date "effective_to"
    t.string "jurisdiction_name"
    t.string "name", null: false
    t.decimal "rate", precision: 10, scale: 8, null: false
    t.string "receipt_code", limit: 3
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "code"], name: "index_store_tax_rates_on_store_id_and_code", unique: true
    t.index ["store_id"], name: "index_store_tax_rates_on_store_id"
    t.check_constraint "effective_from IS NULL OR effective_to IS NULL OR effective_from <= effective_to", name: "store_tax_rates_effective_period_order"
    t.check_constraint "rate >= 0::numeric", name: "store_tax_rates_rate_non_negative"
  end

  create_table "store_tax_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "calculation_order", limit: 2, default: 0, null: false
    t.string "component_code", null: false
    t.boolean "compounds_on_prior_tax", default: false, null: false
    t.datetime "created_at", null: false
    t.date "effective_from"
    t.date "effective_to"
    t.bigint "store_id", null: false
    t.bigint "store_tax_rate_id"
    t.bigint "tax_category_id", null: false
    t.decimal "taxable_fraction", precision: 10, scale: 8, default: "1.0", null: false
    t.string "treatment", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "tax_category_id", "component_code"], name: "index_store_tax_rules_on_store_category_component"
    t.index ["store_id"], name: "index_store_tax_rules_on_store_id"
    t.index ["store_tax_rate_id"], name: "index_store_tax_rules_on_store_tax_rate_id"
    t.index ["tax_category_id"], name: "index_store_tax_rules_on_tax_category_id"
    t.check_constraint "(treatment::text = ANY (ARRAY['taxable'::character varying::text, 'zero_rated'::character varying::text])) AND store_tax_rate_id IS NOT NULL OR (treatment::text = ANY (ARRAY['exempt'::character varying::text, 'not_applicable'::character varying::text]))", name: "store_tax_rules_rate_required_unless_non_collecting"
    t.check_constraint "calculation_order >= 0", name: "store_tax_rules_calculation_order_non_negative"
    t.check_constraint "effective_from IS NULL OR effective_to IS NULL OR effective_from <= effective_to", name: "store_tax_rules_effective_period_order"
    t.check_constraint "taxable_fraction >= 0::numeric AND taxable_fraction <= 1::numeric", name: "store_tax_rules_taxable_fraction_range"
    t.check_constraint "treatment::text = ANY (ARRAY['taxable'::character varying::text, 'zero_rated'::character varying::text, 'exempt'::character varying::text, 'not_applicable'::character varying::text])", name: "store_tax_rules_treatment_check"
  end

  create_table "stored_value_accounts", force: :cascade do |t|
    t.string "account_number", null: false
    t.string "account_type", null: false
    t.string "alternate_identifier"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "current_balance_cents", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "organization_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["account_number"], name: "index_stored_value_accounts_on_account_number", unique: true
    t.index ["created_by_user_id"], name: "index_stored_value_accounts_on_created_by_user_id"
    t.index ["organization_id", "alternate_identifier"], name: "index_sv_accounts_on_org_and_alternate", unique: true, where: "(alternate_identifier IS NOT NULL)"
    t.index ["organization_id"], name: "index_stored_value_accounts_on_organization_id"
    t.check_constraint "account_type::text = ANY (ARRAY['gift_card'::character varying::text, 'store_credit'::character varying::text, 'trade_credit'::character varying::text])", name: "sv_accounts_type_check"
    t.check_constraint "current_balance_cents >= 0", name: "sv_accounts_balance_nonneg"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text])", name: "sv_accounts_status_check"
  end

  create_table "stored_value_adjustment_reasons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.boolean "requires_note", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_sv_adjustment_reasons_on_org_and_code", unique: true
    t.index ["organization_id"], name: "index_stored_value_adjustment_reasons_on_organization_id"
  end

  create_table "stored_value_entries", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.text "description"
    t.string "entry_type", null: false
    t.bigint "pos_approval_id"
    t.bigint "pos_line_item_id"
    t.bigint "pos_tender_id"
    t.bigint "pos_transaction_id"
    t.string "posting_key", null: false
    t.bigint "reverses_entry_id"
    t.bigint "store_id", null: false
    t.bigint "stored_value_account_id", null: false
    t.bigint "stored_value_adjustment_reason_id"
    t.index ["created_by_user_id"], name: "index_stored_value_entries_on_created_by_user_id"
    t.index ["pos_approval_id"], name: "index_stored_value_entries_on_pos_approval_id"
    t.index ["pos_line_item_id"], name: "index_stored_value_entries_on_pos_line_item_id"
    t.index ["pos_tender_id"], name: "index_stored_value_entries_on_pos_tender_id"
    t.index ["pos_transaction_id"], name: "index_stored_value_entries_on_pos_transaction_id"
    t.index ["posting_key"], name: "index_stored_value_entries_on_posting_key", unique: true
    t.index ["reverses_entry_id"], name: "index_stored_value_entries_on_reverses_entry_id"
    t.index ["reverses_entry_id"], name: "index_sv_entries_reverses_unique", unique: true, where: "(reverses_entry_id IS NOT NULL)"
    t.index ["store_id"], name: "index_stored_value_entries_on_store_id"
    t.index ["stored_value_account_id"], name: "index_stored_value_entries_on_stored_value_account_id"
    t.index ["stored_value_account_id"], name: "index_sv_entries_one_issued_per_account", unique: true, where: "((entry_type)::text = 'issued'::text)"
    t.index ["stored_value_adjustment_reason_id"], name: "idx_on_stored_value_adjustment_reason_id_b8c64f83a2"
    t.check_constraint "amount_cents <> 0", name: "sv_entries_amount_nonzero"
    t.check_constraint "entry_type::text = ANY (ARRAY['issued'::character varying::text, 'reloaded'::character varying::text, 'redeemed'::character varying::text, 'refunded'::character varying::text, 'manual_adjustment'::character varying::text, 'reversal'::character varying::text])", name: "sv_entries_type_check"
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
    t.bigint "next_purchase_order_number", default: 1, null: false
    t.bigint "next_receipt_number", default: 1, null: false
    t.bigint "next_receipt_sequence", default: 1, null: false
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
    t.check_constraint "next_purchase_order_number >= 1", name: "stores_next_purchase_order_number_positive"
    t.check_constraint "next_receipt_number >= 1", name: "stores_next_receipt_number_positive"
    t.check_constraint "next_receipt_sequence >= 1", name: "stores_next_receipt_sequence_positive"
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

  create_table "tender_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "allows_over_tender", default: false, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.boolean "payment_enabled", default: true, null: false
    t.boolean "provides_change", default: false, null: false
    t.string "reference_1_label", limit: 20
    t.string "reference_1_mask"
    t.string "reference_1_requirement", default: "none", null: false
    t.string "reference_2_label", limit: 20
    t.string "reference_2_mask"
    t.string "reference_2_requirement", default: "none", null: false
    t.boolean "refund_enabled", default: true, null: false
    t.string "shortcut", limit: 3
    t.string "tender_category", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_tender_types_on_organization_id_and_code", unique: true
    t.index ["organization_id", "shortcut"], name: "index_tender_types_on_organization_id_and_shortcut", unique: true, where: "(shortcut IS NOT NULL)"
    t.index ["organization_id"], name: "index_tender_types_on_organization_id"
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

  create_table "vendors", force: :cascade do |t|
    t.string "account_reference"
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "default_supplier_discount_bps"
    t.string "legal_name"
    t.string "name", null: false
    t.text "notes"
    t.string "ordering_contact"
    t.string "ordering_email"
    t.bigint "organization_id", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_vendors_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_vendors_on_organization_id"
  end

  add_foreign_key "administrative_audit_events", "organizations", on_delete: :restrict
  add_foreign_key "administrative_audit_events", "stores", on_delete: :restrict
  add_foreign_key "administrative_audit_events", "users", column: "actor_user_id", on_delete: :restrict
  add_foreign_key "business_days", "stores", on_delete: :restrict
  add_foreign_key "business_days", "users", column: "closed_by_user_id", on_delete: :restrict
  add_foreign_key "business_days", "users", column: "opened_by_user_id", on_delete: :restrict
  add_foreign_key "cash_drawers", "stores", on_delete: :restrict
  add_foreign_key "cash_movement_types", "organizations", on_delete: :restrict
  add_foreign_key "departments", "departments", column: "parent_department_id", on_delete: :restrict
  add_foreign_key "departments", "organizations", on_delete: :restrict
  add_foreign_key "departments", "return_policies", column: "default_return_policy_id", on_delete: :restrict
  add_foreign_key "departments", "tax_categories", column: "default_tax_category_id", on_delete: :restrict
  add_foreign_key "discount_reasons", "organizations", on_delete: :restrict
  add_foreign_key "discount_reasons", "return_policies", column: "resulting_return_policy_id", on_delete: :nullify
  add_foreign_key "inventory_adjustment_lines", "departments", column: "estimate_department_id", on_delete: :restrict
  add_foreign_key "inventory_adjustment_lines", "inventory_adjustments", on_delete: :restrict
  add_foreign_key "inventory_adjustment_lines", "product_variants", on_delete: :restrict
  add_foreign_key "inventory_adjustment_reasons", "organizations", on_delete: :restrict
  add_foreign_key "inventory_adjustments", "inventory_adjustment_reasons", on_delete: :restrict
  add_foreign_key "inventory_adjustments", "stores", on_delete: :restrict
  add_foreign_key "inventory_adjustments", "users", column: "cancelled_by_user_id", on_delete: :restrict
  add_foreign_key "inventory_adjustments", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "inventory_adjustments", "users", column: "posted_by_user_id", on_delete: :restrict
  add_foreign_key "inventory_ledger_entries", "departments", column: "estimate_department_id", on_delete: :restrict
  add_foreign_key "inventory_ledger_entries", "inventory_ledger_entries", column: "reversal_of_entry_id", on_delete: :restrict
  add_foreign_key "inventory_ledger_entries", "product_variants", on_delete: :restrict
  add_foreign_key "inventory_ledger_entries", "stores", on_delete: :restrict
  add_foreign_key "inventory_ledger_entries", "users", column: "posted_by_user_id", on_delete: :restrict
  add_foreign_key "inventory_reservations", "inventory_units", on_delete: :restrict
  add_foreign_key "inventory_reservations", "product_variants", on_delete: :restrict
  add_foreign_key "inventory_reservations", "stores", on_delete: :restrict
  add_foreign_key "inventory_reservations", "users", column: "released_by_user_id", on_delete: :restrict
  add_foreign_key "inventory_units", "pos_line_items", column: "sold_pos_line_item_id", on_delete: :restrict
  add_foreign_key "inventory_units", "product_conditions", on_delete: :restrict
  add_foreign_key "inventory_units", "product_variants", on_delete: :restrict
  add_foreign_key "inventory_units", "stores", on_delete: :restrict
  add_foreign_key "inventory_units", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "merchandise_classes", "departments", column: "default_department_id", on_delete: :restrict
  add_foreign_key "merchandise_classes", "departments", column: "default_used_department_id", on_delete: :restrict
  add_foreign_key "merchandise_classes", "merchandise_classes", column: "parent_id", on_delete: :restrict
  add_foreign_key "merchandise_classes", "organizations", on_delete: :restrict
  add_foreign_key "merchandise_classes", "tax_categories", column: "default_tax_category_id", on_delete: :restrict
  add_foreign_key "pos_approvals", "pos_line_items", on_delete: :restrict
  add_foreign_key "pos_approvals", "pos_sessions", on_delete: :restrict
  add_foreign_key "pos_approvals", "pos_transactions", on_delete: :restrict
  add_foreign_key "pos_approvals", "stores", on_delete: :restrict
  add_foreign_key "pos_approvals", "users", column: "approved_by_user_id", on_delete: :restrict
  add_foreign_key "pos_approvals", "users", column: "requested_by_user_id", on_delete: :restrict
  add_foreign_key "pos_cash_movements", "cash_movement_types", on_delete: :restrict
  add_foreign_key "pos_cash_movements", "pos_approvals", on_delete: :restrict
  add_foreign_key "pos_cash_movements", "pos_sessions", on_delete: :restrict
  add_foreign_key "pos_cash_movements", "stores", on_delete: :restrict
  add_foreign_key "pos_cash_movements", "users", column: "approved_by_user_id", on_delete: :restrict
  add_foreign_key "pos_cash_movements", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "pos_devices", "stores", on_delete: :restrict
  add_foreign_key "pos_discount_allocations", "pos_discounts", on_delete: :restrict
  add_foreign_key "pos_discount_allocations", "pos_line_items", on_delete: :restrict
  add_foreign_key "pos_discounts", "discount_reasons", on_delete: :restrict
  add_foreign_key "pos_discounts", "pos_line_items", column: "target_pos_line_item_id", on_delete: :restrict
  add_foreign_key "pos_discounts", "pos_transactions", on_delete: :restrict
  add_foreign_key "pos_discounts", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "pos_line_item_taxes", "pos_line_items", on_delete: :restrict
  add_foreign_key "pos_line_item_taxes", "store_tax_rates", on_delete: :restrict
  add_foreign_key "pos_line_item_taxes", "store_tax_rules", on_delete: :restrict
  add_foreign_key "pos_line_item_taxes", "tax_categories", on_delete: :restrict
  add_foreign_key "pos_line_items", "departments", on_delete: :restrict
  add_foreign_key "pos_line_items", "inventory_units", on_delete: :restrict
  add_foreign_key "pos_line_items", "pos_line_items", column: "original_pos_line_item_id", on_delete: :restrict
  add_foreign_key "pos_line_items", "pos_line_items", column: "reverses_pos_line_item_id", on_delete: :restrict
  add_foreign_key "pos_line_items", "pos_transactions", on_delete: :restrict
  add_foreign_key "pos_line_items", "product_requests", on_delete: :restrict
  add_foreign_key "pos_line_items", "product_variants", on_delete: :restrict
  add_foreign_key "pos_line_items", "return_reasons", on_delete: :restrict
  add_foreign_key "pos_line_items", "stored_value_accounts", on_delete: :restrict
  add_foreign_key "pos_line_items", "tax_categories", column: "original_tax_category_id", on_delete: :restrict
  add_foreign_key "pos_line_items", "tax_categories", on_delete: :restrict
  add_foreign_key "pos_line_items", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "pos_line_items", "users", column: "price_overridden_by_user_id", on_delete: :restrict
  add_foreign_key "pos_line_items", "users", column: "removed_by_user_id", on_delete: :restrict
  add_foreign_key "pos_line_items", "users", column: "tax_category_overridden_by_user_id", on_delete: :restrict
  add_foreign_key "pos_session_cash_counts", "pos_sessions", on_delete: :restrict
  add_foreign_key "pos_session_cash_counts", "users", column: "counted_by_user_id", on_delete: :restrict
  add_foreign_key "pos_sessions", "business_days", on_delete: :restrict
  add_foreign_key "pos_sessions", "cash_drawers", on_delete: :restrict
  add_foreign_key "pos_sessions", "pos_devices", on_delete: :restrict
  add_foreign_key "pos_sessions", "stores", on_delete: :restrict
  add_foreign_key "pos_sessions", "users", column: "cashier_user_id", on_delete: :restrict
  add_foreign_key "pos_sessions", "users", column: "closed_by_user_id", on_delete: :restrict
  add_foreign_key "pos_sessions", "users", column: "opened_by_user_id", on_delete: :restrict
  add_foreign_key "pos_tax_exemptions", "pos_transactions", on_delete: :restrict
  add_foreign_key "pos_tax_exemptions", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "pos_tenders", "pos_approvals", on_delete: :restrict
  add_foreign_key "pos_tenders", "pos_tenders", column: "original_pos_tender_id", on_delete: :restrict
  add_foreign_key "pos_tenders", "pos_tenders", column: "reverses_pos_tender_id", on_delete: :restrict
  add_foreign_key "pos_tenders", "pos_transactions", on_delete: :restrict
  add_foreign_key "pos_tenders", "stored_value_accounts", on_delete: :restrict
  add_foreign_key "pos_tenders", "stores", on_delete: :restrict
  add_foreign_key "pos_tenders", "tender_types", on_delete: :restrict
  add_foreign_key "pos_tenders", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "pos_tenders", "users", column: "external_void_confirmed_by_user_id", on_delete: :restrict
  add_foreign_key "pos_tenders", "users", column: "removed_by_user_id", on_delete: :restrict
  add_foreign_key "pos_tenders", "users", column: "voided_by_user_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "pos_approvals", column: "post_void_pos_approval_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "pos_sessions", column: "active_pos_session_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "pos_sessions", column: "completed_pos_session_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "pos_sessions", column: "origin_pos_session_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "pos_transactions", column: "reverses_pos_transaction_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "stores", on_delete: :restrict
  add_foreign_key "pos_transactions", "users", column: "cancelled_by_user_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "users", column: "cashier_user_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "users", column: "completed_by_user_id", on_delete: :restrict
  add_foreign_key "product_conditions", "organizations", on_delete: :restrict
  add_foreign_key "product_formats", "organizations", on_delete: :restrict
  add_foreign_key "product_request_fulfillments", "inventory_reservations", on_delete: :restrict
  add_foreign_key "product_request_fulfillments", "pos_line_items", on_delete: :restrict
  add_foreign_key "product_request_fulfillments", "product_request_fulfillments", column: "linked_fulfilment_id", on_delete: :restrict
  add_foreign_key "product_request_fulfillments", "product_requests", on_delete: :restrict
  add_foreign_key "product_request_fulfillments", "users", column: "fulfilled_by_user_id", on_delete: :restrict
  add_foreign_key "product_requests", "product_requests", column: "supersedes_product_request_id", on_delete: :restrict
  add_foreign_key "product_requests", "product_variants", on_delete: :restrict
  add_foreign_key "product_requests", "products", on_delete: :restrict
  add_foreign_key "product_requests", "stores", on_delete: :restrict
  add_foreign_key "product_requests", "users", column: "assigned_buyer_user_id", on_delete: :restrict
  add_foreign_key "product_requests", "users", column: "requested_by_user_id", on_delete: :restrict
  add_foreign_key "product_requests", "users", column: "resolved_by_user_id", on_delete: :restrict
  add_foreign_key "product_variant_vendors", "product_variants"
  add_foreign_key "product_variant_vendors", "vendors"
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
  add_foreign_key "purchase_order_allocation_events", "inventory_reservations", on_delete: :restrict
  add_foreign_key "purchase_order_allocation_events", "purchase_order_allocations", on_delete: :restrict
  add_foreign_key "purchase_order_allocation_events", "receipt_lines", on_delete: :restrict
  add_foreign_key "purchase_order_allocation_events", "users", on_delete: :restrict
  add_foreign_key "purchase_order_allocations", "product_requests", on_delete: :restrict
  add_foreign_key "purchase_order_allocations", "purchase_order_lines", on_delete: :restrict
  add_foreign_key "purchase_order_allocations", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "purchase_order_lines", "product_variant_vendors", on_delete: :restrict
  add_foreign_key "purchase_order_lines", "product_variants", on_delete: :restrict
  add_foreign_key "purchase_order_lines", "purchase_orders", on_delete: :restrict
  add_foreign_key "purchase_orders", "stores", on_delete: :restrict
  add_foreign_key "purchase_orders", "users", column: "buyer_user_id", on_delete: :restrict
  add_foreign_key "purchase_orders", "users", column: "cancelled_by_user_id", on_delete: :restrict
  add_foreign_key "purchase_orders", "users", column: "closed_by_user_id", on_delete: :restrict
  add_foreign_key "purchase_orders", "users", column: "ordered_by_user_id", on_delete: :restrict
  add_foreign_key "purchase_orders", "vendors", on_delete: :restrict
  add_foreign_key "receipt_lines", "product_variants", on_delete: :restrict
  add_foreign_key "receipt_lines", "purchase_order_lines", on_delete: :restrict
  add_foreign_key "receipt_lines", "receipts", on_delete: :restrict
  add_foreign_key "receipts", "stores", on_delete: :restrict
  add_foreign_key "receipts", "users", column: "cancelled_by_user_id", on_delete: :restrict
  add_foreign_key "receipts", "users", column: "posted_by_user_id", on_delete: :restrict
  add_foreign_key "receipts", "users", column: "received_by_user_id", on_delete: :restrict
  add_foreign_key "receipts", "vendors", on_delete: :restrict
  add_foreign_key "return_policies", "organizations", on_delete: :restrict
  add_foreign_key "return_reasons", "organizations", on_delete: :restrict
  add_foreign_key "role_permissions", "permissions", on_delete: :restrict
  add_foreign_key "role_permissions", "roles", on_delete: :restrict
  add_foreign_key "roles", "organizations", on_delete: :restrict
  add_foreign_key "stock_balances", "product_variants", on_delete: :restrict
  add_foreign_key "stock_balances", "stores", on_delete: :restrict
  add_foreign_key "store_memberships", "roles", on_delete: :restrict
  add_foreign_key "store_memberships", "stores", on_delete: :restrict
  add_foreign_key "store_memberships", "users", column: "assigned_by_user_id", on_delete: :nullify
  add_foreign_key "store_memberships", "users", on_delete: :restrict
  add_foreign_key "store_tax_rates", "stores", on_delete: :restrict
  add_foreign_key "store_tax_rules", "store_tax_rates", on_delete: :restrict
  add_foreign_key "store_tax_rules", "stores", on_delete: :restrict
  add_foreign_key "store_tax_rules", "tax_categories", on_delete: :restrict
  add_foreign_key "stored_value_accounts", "organizations", on_delete: :restrict
  add_foreign_key "stored_value_accounts", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "stored_value_adjustment_reasons", "organizations", on_delete: :restrict
  add_foreign_key "stored_value_entries", "pos_approvals", on_delete: :restrict
  add_foreign_key "stored_value_entries", "pos_line_items", on_delete: :restrict
  add_foreign_key "stored_value_entries", "pos_tenders", on_delete: :restrict
  add_foreign_key "stored_value_entries", "pos_transactions", on_delete: :restrict
  add_foreign_key "stored_value_entries", "stored_value_accounts", on_delete: :restrict
  add_foreign_key "stored_value_entries", "stored_value_adjustment_reasons", on_delete: :restrict
  add_foreign_key "stored_value_entries", "stored_value_entries", column: "reverses_entry_id", on_delete: :restrict
  add_foreign_key "stored_value_entries", "stores", on_delete: :restrict
  add_foreign_key "stored_value_entries", "users", column: "created_by_user_id", on_delete: :restrict
  add_foreign_key "stores", "organizations", on_delete: :restrict
  add_foreign_key "tax_categories", "organizations", on_delete: :restrict
  add_foreign_key "tender_types", "organizations", on_delete: :restrict
  add_foreign_key "users", "stores", column: "default_store_id", on_delete: :nullify
  add_foreign_key "vendors", "organizations"
end
