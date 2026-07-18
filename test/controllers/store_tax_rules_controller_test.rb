# frozen_string_literal: true

require "test_helper"

class StoreTaxRulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists current store's tax rules" do
    get store_tax_rules_path
    assert_response :success
    assert_match "GST13", response.body
  end

  test "creates store tax rule in current store and writes audit" do
    category = tax_categories(:unconfigured_category)
    rate = store_tax_rates(:gst_13)

    assert_difference("StoreTaxRule.count") do
      assert_difference("AdministrativeAuditEvent.count") do
        post store_tax_rules_path, params: {
          store_tax_rule: {
            tax_category_id: category.id, store_tax_rate_id: rate.id, component_code: rate.code,
            treatment: "taxable", taxable_fraction: "1.00000000", calculation_order: 0,
            compounds_on_prior_tax: false, active: true
          }
        }
      end
    end

    rule = StoreTaxRule.find_by!(tax_category: category, component_code: rate.code)
    assert_redirected_to store_tax_rules_path
    assert_equal stores(:main_street).id, rule.store_id
    assert_equal "store_tax_rule.created", AdministrativeAuditEvent.order(:id).last.action
  end

  test "rejects a rule with an overlapping effective period for the same category and component" do
    existing = store_tax_rules(:physical_book_gst)

    post store_tax_rules_path, params: {
      store_tax_rule: {
        tax_category_id: existing.tax_category_id, store_tax_rate_id: existing.store_tax_rate_id,
        component_code: existing.component_code, treatment: "taxable", taxable_fraction: "1.00000000",
        calculation_order: 0, compounds_on_prior_tax: false, active: true
      }
    }

    assert_response :unprocessable_entity
    assert_match "overlaps", response.body
  end

  test "denies clerk without manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get new_store_tax_rule_path
    assert_redirected_to root_path
  end
end
