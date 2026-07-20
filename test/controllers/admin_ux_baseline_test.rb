# frozen_string_literal: true

require "test_helper"

# Phase 4f UX baseline (PR4): administrative and classification back-office page
# patterns — shared page headers with browser titles, data-table lists, and
# human-readable percent/money entry parsed back to domain storage in the
# controller (rates as 0–1 decimals or basis points, money as integer cents).
class AdminUxBaselineTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    @org = organizations(:acme)
    @store = stores(:main_street)
    post session_path, params: { username: "admin", password: "password123" }
  end

  # --- Shared list patterns + browser titles -------------------------------

  test "administrative index screens render page headers, browser titles, and data tables" do
    {
      stores_path => "Stores",
      users_path => "Users",
      departments_path => "Departments",
      store_tax_rates_path => "Store tax rates"
    }.each do |path, title|
      get path
      assert_response :success
      assert_select "header.page-header h1", text: title
      assert_match "<title>#{title} · ShelfStack</title>", response.body
      assert_select "table.data-table"
    end
  end

  # --- Human-readable tax rate entry ---------------------------------------

  test "creating a store tax rate parses percent input into a decimal fraction" do
    assert_difference "StoreTaxRate.count", 1 do
      post store_tax_rates_path, params: {
        store_tax_rate: { code: "PST9", name: "PST 9%", rate_percent: "9", receipt_code: "P9", active: true }
      }
    end

    rate = StoreTaxRate.find_by!(code: "PST9")
    assert_equal 0.09, rate.rate.to_f
  end

  test "store tax rate form re-renders with shared errors when validation fails" do
    assert_no_difference "StoreTaxRate.count" do
      post store_tax_rates_path, params: {
        store_tax_rate: { code: "", name: "", rate_percent: "13", active: true }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
    assert_select "section.form-section"
  end

  test "invalid store tax rate percent preserves submitted percent and other fields" do
    rate = store_tax_rates(:gst_13)

    patch store_tax_rate_path(rate), params: {
      store_tax_rate: {
        name: "Renamed GST",
        rate_percent: "twelve",
        receipt_code: rate.receipt_code,
        active: true
      }
    }

    assert_response :unprocessable_entity
    assert_select "input[name='store_tax_rate[name]'][value='Renamed GST']"
    assert_select "input#store_tax_rate_rate[value='twelve'][aria-invalid='true']"
    assert_equal "GST 13%", rate.reload.name
  end

  test "invalid discount reason numerics preserve submitted values on update" do
    reason = DiscountReason.create!(
      organization: @org,
      code: "mgr_adj",
      name: "Manager adjustment",
      default_calculation_method: "percentage",
      default_rate_bps: 1000,
      requires_approval: true,
      active: true
    )

    patch discount_reason_path(reason), params: {
      discount_reason: {
        name: "Renamed adjustment",
        default_calculation_method: "fixed_amount",
        default_rate_percent: "bad",
        default_amount: "3.50",
        maximum_rate_percent: "25",
        requires_approval: "0",
        active: "1"
      }
    }

    assert_response :unprocessable_entity
    assert_select "input[name='discount_reason[name]'][value='Renamed adjustment']"
    assert_select "input#discount_reason_default_rate[value='bad'][aria-invalid='true']"
    assert_select "input#discount_reason_default_amount[value='3.50']"
    assert_equal "Manager adjustment", reason.reload.name
  end

  test "invalid membership authority preserves submitted role and raw values" do
    membership = store_memberships(:clerk_main_street)
    administrator = roles(:administrator)

    patch store_membership_path(membership), params: {
      store_membership: {
        role_id: administrator.id,
        active: "1",
        starts_on: membership.starts_on || Date.current,
        maximum_discount_rate_percent: "nope",
        maximum_cash_refund: "50.00"
      }
    }

    assert_response :unprocessable_entity
    assert_select "select#store_membership_role_id option[selected][value=?]", administrator.id.to_s
    assert_select "input#store_membership_maximum_discount_rate[value='nope'][aria-invalid='true']"
    assert_select "input#store_membership_maximum_cash_refund[value='50.00']"
    assert_not_equal administrator.id, membership.reload.role_id
  end

  test "invalid store tax rule taxable portion preserves submitted values" do
    rule = store_tax_rules(:physical_book_gst)

    patch store_tax_rule_path(rule), params: {
      store_tax_rule: {
        tax_category_id: rule.tax_category_id,
        store_tax_rate_id: rule.store_tax_rate_id,
        component_code: "RENAMED",
        treatment: rule.treatment,
        taxable_fraction_percent: "half",
        calculation_order: rule.calculation_order,
        compounds_on_prior_tax: rule.compounds_on_prior_tax,
        active: true
      }
    }

    assert_response :unprocessable_entity
    assert_select "input[name='store_tax_rule[component_code]'][value='RENAMED']"
    assert_select "input#store_tax_rule_taxable_fraction[value='half'][aria-invalid='true']"
    assert_not_equal "RENAMED", rule.reload.component_code
  end

  # --- Human-readable department margin / discount entry -------------------

  test "creating a department parses percent margin and maximum discount inputs" do
    assert_difference "Department.count", 1 do
      post departments_path, params: {
        department: {
          department_number: "205",
          code: "ux_test_dept",
          name: "UX Test Department",
          postable: true,
          maximum_merchandise_discount_percent: "20",
          default_cost_estimation_margin_percent: "40",
          active: true
        }
      }
    end

    department = Department.find_by!(code: "ux_test_dept")
    assert_equal 0.2, department.maximum_merchandise_discount.to_f
    assert_equal 4000, department.default_cost_estimation_margin_bps
  end

  test "department edit form renders percent affix fields for margin and discount" do
    get edit_department_path(departments(:books_new))
    assert_response :success
    assert_select "input#department_maximum_merchandise_discount"
    assert_select "input#department_default_cost_estimation_margin"
    assert_select ".input-affix .affix", text: "%"
  end

  # --- Render smoke tests across every converted admin/classification screen -

  test "converted index and new screens render successfully with page headers" do
    paths = [
      roles_path, new_role_path, permissions_path, administrative_audit_events_path,
      merchandise_classes_path, new_merchandise_class_path,
      product_formats_path, new_product_format_path,
      product_conditions_path, new_product_condition_path,
      return_policies_path, new_return_policy_path,
      return_reasons_path, new_return_reason_path,
      inventory_adjustment_reasons_path, new_inventory_adjustment_reason_path,
      tax_categories_path, new_tax_category_path,
      store_tax_rates_path, new_store_tax_rate_path,
      store_tax_rules_path, new_store_tax_rule_path,
      discount_reasons_path, new_discount_reason_path,
      store_memberships_path, new_store_membership_path,
      pos_devices_path, new_pos_device_path,
      cash_drawers_path, new_cash_drawer_path,
      business_days_path
    ]

    paths.each do |path|
      get path
      assert_response :success, "expected 200 for #{path}"
      assert_select "header.page-header", { minimum: 1 }, "expected a shared page header on #{path}"
    end
  end

  test "converted edit screens render successfully" do
    paths = []
    paths << edit_merchandise_class_path(MerchandiseClass.first) if MerchandiseClass.exists?
    paths << edit_product_format_path(ProductFormat.first) if ProductFormat.exists?
    paths << edit_product_condition_path(ProductCondition.first) if ProductCondition.exists?
    paths << edit_store_tax_rate_path(StoreTaxRate.first) if StoreTaxRate.exists?
    paths << edit_store_tax_rule_path(StoreTaxRule.first) if StoreTaxRule.exists?
    paths << edit_store_membership_path(StoreMembership.first) if StoreMembership.exists?

    assert paths.any?, "expected at least one editable fixture record"
    paths.each do |path|
      get path
      assert_response :success, "expected 200 for #{path}"
      assert_select "form.form"
    end
  end

  test "store tax rules index uses name-first category and treatment labels" do
    get store_tax_rules_path
    assert_response :success
    assert_match "Physical Book", response.body
    assert_match(/Taxable|Zero-rated|Exempt|Not applicable/, response.body)
    assert_match(/applies/i, response.body)
  end
end
