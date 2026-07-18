# frozen_string_literal: true

require "test_helper"

class TaxCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists organization tax categories" do
    get tax_categories_path
    assert_response :success
    assert_match "physical_book", response.body
  end

  test "creates tax category in current organization and writes audit" do
    assert_difference("TaxCategory.count") do
      assert_difference("AdministrativeAuditEvent.count") do
        post tax_categories_path, params: {
          tax_category: {
            code: "services",
            name: "Services",
            active: true
          }
        }
      end
    end

    tax_category = TaxCategory.find_by!(code: "services")
    assert_redirected_to tax_category_path(tax_category)
    assert_equal organizations(:acme).id, tax_category.organization_id
    assert_equal "tax_category.created", AdministrativeAuditEvent.order(:id).last.action
  end

  test "denies clerk without manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get new_tax_category_path
    assert_redirected_to root_path
  end
end
