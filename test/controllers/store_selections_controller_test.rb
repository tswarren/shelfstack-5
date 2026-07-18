# frozen_string_literal: true

require "test_helper"

class StoreSelectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    StoreMembership.create!(
      user: users(:admin),
      store: stores(:warehouse),
      role: roles(:administrator),
      active: true
    )
    users(:admin).update!(default_store: nil)
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "selects an accessible store" do
    assert_redirected_to new_store_selection_path
    post store_selection_path, params: { store_id: stores(:warehouse).id }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "Warehouse", response.body
  end

  test "rejects store without membership" do
    other = Store.create!(
      organization: organizations(:acme),
      code: "999",
      name: "Other",
      timezone: "UTC",
      currency_code: "USD"
    )
    post store_selection_path, params: { store_id: other.id }
    assert_redirected_to new_store_selection_path
  end
end
