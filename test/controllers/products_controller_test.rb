# frozen_string_literal: true

require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists products" do
    get products_path
    assert_response :success
    assert_match "The Illustrated Man", response.body
  end

  test "searches by normalized ISBN-10 input" do
    get products_path, params: { q: "0-306-40615-2" }
    assert_response :success
    assert_match "The Illustrated Man", response.body
  end

  test "creates product through service" do
    assert_difference "Product.count", 1 do
      post products_path, params: {
        identifier: "",
        product: {
          name: "Created Via UI",
          merchandise_class_id: merchandise_classes(:fiction_primary).id,
          default_department_id: departments(:books_new).id,
          default_tax_category_id: tax_categories(:physical_book).id,
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 1599,
          sellable: true,
          status: "active"
        }
      }
    end

    product = Product.order(:id).last
    assert_redirected_to product_path(product)
    assert_match(/\A29\d{11}\z/, product.identifier)
  end

  test "denies clerk without catalog permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get products_path
    assert_redirected_to root_path
  end
end
