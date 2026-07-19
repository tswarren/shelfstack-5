# frozen_string_literal: true

require "test_helper"

class PosLineItemTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @department = departments(:books_new)
    @variant = product_variants(:sample_book_standard)

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    session = Pos::OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
  end

  test "product line requires a product variant" do
    line = PosLineItem.new(
      pos_transaction: @transaction, line_kind: "product", status: "pending",
      department: @department, quantity: 1, unit_price_cents: 100, created_by_user: @admin
    )

    refute line.valid?
    assert_includes line.errors[:product_variant], "is required for product lines"
  end

  test "open_ring line forbids a product variant and requires a description snapshot" do
    line = PosLineItem.new(
      pos_transaction: @transaction, line_kind: "open_ring", status: "pending",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin
    )

    refute line.valid?
    assert_includes line.errors[:product_variant], "must be blank for open-ring lines"
    assert_includes line.errors[:description_snapshot], "must be resolved before save"
  end

  test "extended_price_cents multiplies quantity by unit price" do
    line = PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "pending",
      product_variant: @variant, department: @department, quantity: 3,
      unit_price_cents: 250, created_by_user: @admin
    )

    assert_equal 750, line.extended_price_cents
  end

  test "direction defaults to sale and exposes sale?/return? helpers" do
    line = PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "pending",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin
    )

    assert_equal "sale", line.direction
    assert line.sale?
    refute line.return?
  end

  test "return direction requires original line, return reason, and disposition" do
    line = PosLineItem.new(
      pos_transaction: @transaction, line_kind: "product", status: "pending",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin, direction: "return"
    )

    refute line.valid?
    assert_includes line.errors[:original_pos_line_item], "is required for return lines"
    assert_includes line.errors[:return_reason], "is required for return lines"
    assert_includes line.errors[:return_disposition], "is required for return lines"
  end

  test "return line rejects an unsupported disposition value" do
    original = PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "completed",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin
    )

    line = PosLineItem.new(
      pos_transaction: @transaction, line_kind: "product", status: "pending",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin, direction: "return",
      original_pos_line_item: original, return_reason: return_reasons(:unwanted),
      return_disposition: "not_a_real_disposition"
    )

    refute line.valid?
    assert_includes line.errors[:return_disposition], "is not included in the list"
  end

  test "remaining_returnable_quantity subtracts pending and completed linked returns" do
    original = PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "completed",
      product_variant: @variant, department: @department, quantity: 5,
      unit_price_cents: 100, created_by_user: @admin
    )

    assert_equal 5, original.remaining_returnable_quantity

    PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "pending",
      product_variant: @variant, department: @department, quantity: 2,
      unit_price_cents: 100, created_by_user: @admin, direction: "return",
      original_pos_line_item: original, return_reason: return_reasons(:unwanted),
      return_disposition: "return_to_stock"
    )

    assert_equal 3, original.remaining_returnable_quantity

    PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "completed",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin, direction: "return",
      original_pos_line_item: original, return_reason: return_reasons(:defective),
      return_disposition: "inspection_required"
    )

    assert_equal 2, original.remaining_returnable_quantity
  end

  test "remaining_returnable_quantity is zero for a return line" do
    original = PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "completed",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin
    )
    return_line = PosLineItem.create!(
      pos_transaction: @transaction, line_kind: "product", status: "pending",
      product_variant: @variant, department: @department, quantity: 1,
      unit_price_cents: 100, created_by_user: @admin, direction: "return",
      original_pos_line_item: original, return_reason: return_reasons(:unwanted),
      return_disposition: "return_to_stock"
    )

    assert_equal 0, return_line.remaining_returnable_quantity
  end
end
