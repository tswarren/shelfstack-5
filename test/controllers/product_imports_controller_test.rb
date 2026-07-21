# frozen_string_literal: true

require "test_helper"

class ProductImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "creates a product from structured attributes and redirects to the new product request form" do
    assert_difference "Product.count", 1 do
      post product_imports_path, params: {
        product: {
          name: "Imported Via Thin Path", product_type: "book",
          product_format_id: product_formats(:hardcover).id
        },
        return_to: new_product_request_path
      }
    end

    product = Product.order(:id).last
    assert_redirected_to new_product_request_path(product_id: product.id)
  end

  test "surfaces duplicate candidates instead of creating a second product" do
    existing = products(:upc_product)

    assert_no_difference "Product.count" do
      post product_imports_path, params: {
        product: { identifier: existing.identifier, name: "Duplicate Attempt", product_type: "book" }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/possible duplicate/i, response.body)
  end

  test "denies clerk without catalog.product.create" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get new_product_import_path
    assert_redirected_to root_path
  end
end
