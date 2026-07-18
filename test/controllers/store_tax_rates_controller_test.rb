# frozen_string_literal: true

require "test_helper"

class StoreTaxRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists current store's tax rates" do
    get store_tax_rates_path
    assert_response :success
    assert_match "GST13", response.body
  end

  test "creates store tax rate in current store and writes audit" do
    assert_difference("StoreTaxRate.count") do
      assert_difference("AdministrativeAuditEvent.count") do
        post store_tax_rates_path, params: {
          store_tax_rate: { code: "HST", name: "HST 15%", rate: "0.15000000", receipt_code: "H", active: true }
        }
      end
    end

    rate = StoreTaxRate.find_by!(code: "HST")
    assert_redirected_to store_tax_rates_path
    assert_equal stores(:main_street).id, rate.store_id
    assert_equal "store_tax_rate.created", AdministrativeAuditEvent.order(:id).last.action
  end

  test "denies clerk without manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get new_store_tax_rate_path
    assert_redirected_to root_path
  end
end
