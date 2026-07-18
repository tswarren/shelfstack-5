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
end
