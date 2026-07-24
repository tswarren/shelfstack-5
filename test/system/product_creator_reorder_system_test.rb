# frozen_string_literal: true

require "application_system_test_case"

class ProductCreatorReorderSystemTest < ApplicationSystemTestCase
  setup do
    IdentifierSequence.ensure_defaults!
    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"
  end

  test "reordering two creators on the product form persists the new order after save and reload" do
    product = products(:sample_book)
    bradbury = creators(:ray_bradbury)
    le_guin = creators(:ursula_le_guin)
    ProductCreator.create!(product: product, creator: bradbury, role: "author", position: 0)
    ProductCreator.create!(product: product, creator: le_guin, role: "illustrator", position: 1)

    visit edit_product_path(product)

    rows = all("[data-creator-assignments-target='row']")
    assert_equal 2, rows.size
    assert_equal bradbury.id.to_s, find("#product_creator_assignment_#{bradbury.id}_creator_id", visible: :all).value
    assert_equal le_guin.id.to_s, find("#product_creator_assignment_#{le_guin.id}_creator_id", visible: :all).value

    within rows.first do
      click_button "Move down"
    end

    reordered_ids = all("[data-creator-assignments-target='row'] input[type=hidden]", visible: :all).map(&:value)
    assert_equal [ le_guin.id.to_s, bradbury.id.to_s ], reordered_ids

    click_button "Update product"
    assert_text "Product updated."

    ordered = product.reload.product_creators.order(:position)
    assert_equal [ le_guin.id, bradbury.id ], ordered.pluck(:creator_id)
    assert_equal [ 0, 1 ], ordered.pluck(:position)
  end
end
