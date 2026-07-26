# frozen_string_literal: true

require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "index renders page header and list" do
    get customers_path
    assert_response :success
    assert_match "Customers", response.body
    assert_match customers(:jordan_lee).display_name, response.body
  end

  test "show, new, and edit render" do
    customer = customers(:jordan_lee)

    get customer_path(customer)
    assert_response :success
    assert_match customer.customer_number, response.body

    get new_customer_path
    assert_response :success

    get edit_customer_path(customer)
    assert_response :success
  end

  test "new defaults country and region from the current store" do
    store = stores(:main_street)
    store.update!(country_code: "CA", region: "ON")

    get new_customer_path
    assert_response :success
    assert_select "select[name='customer[country_code]'] option[selected][value='CA']"
    assert_select "input[name='customer[region]'][value='ON']"
    assert_select "label", text: "Country"
    assert_select "label", text: /ISO/, count: 0
  end
end
