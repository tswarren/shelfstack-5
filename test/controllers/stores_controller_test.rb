# frozen_string_literal: true

require "test_helper"

class StoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists organization stores" do
    get stores_path
    assert_response :success
    assert_match "Main Street", response.body
  end

  test "creates store in current organization and writes audit" do
    assert_difference("Store.count") do
      assert_difference("AdministrativeAuditEvent.count") do
        post stores_path, params: {
          store: {
            code: "003",
            name: "Annex",
            timezone: "America/New_York",
            currency_code: "USD",
            active: true
          }
        }
      end
    end
    assert_redirected_to store_path(Store.find_by!(code: "003"))
    assert_equal organizations(:acme).id, Store.find_by!(code: "003").organization_id
  end

  test "denies clerk without manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get new_store_path
    assert_redirected_to root_path
  end

  test "cannot show store from another organization by id" do
    other = Organization.create!(
      code: "beta",
      name: "Beta",
      default_currency_code: "USD",
      default_timezone: "UTC"
    )
    foreign = other.stores.create!(
      code: "X",
      name: "Foreign",
      timezone: "UTC",
      currency_code: "USD"
    )
    get store_path(foreign)
    assert_response :not_found
  end
end
