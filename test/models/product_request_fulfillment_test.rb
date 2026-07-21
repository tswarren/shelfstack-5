# frozen_string_literal: true

require "test_helper"

class ProductRequestFulfillmentTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @variant = product_variants(:sample_book_standard)
    @request = ProductRequest.create!(
      store: @store, request_type: "customer_request", product: @variant.product, product_variant: @variant,
      requested_quantity: 2, requested_by_user: @admin
    )

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    session = Pos::OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin).pos_session
    transaction = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
    @line = PosLineItem.create!(
      pos_transaction: transaction, line_kind: "product", status: "completed",
      product_variant: @variant, department: departments(:books_new), quantity: 1,
      unit_price_cents: 1999, created_by_user: @admin, product_request: @request
    )
  end

  test "requires a valid kind" do
    fulfillment = ProductRequestFulfillment.new(
      product_request: @request, pos_line_item: @line, quantity: 1, kind: "bogus",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "k1"
    )

    refute fulfillment.valid?
    assert_includes fulfillment.errors[:kind], "is not included in the list"
  end

  test "fulfill records forbid a linked fulfilment" do
    other = ProductRequestFulfillment.create!(
      product_request: @request, pos_line_item: @line, quantity: 1, kind: "fulfill",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "k-fulfill"
    )

    fulfillment = ProductRequestFulfillment.new(
      product_request: @request, pos_line_item: @line, quantity: 1, kind: "fulfill",
      linked_fulfilment: other, fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "k2"
    )

    refute fulfillment.valid?
    assert_includes fulfillment.errors[:linked_fulfilment], "must be blank for fulfill records"
  end

  test "reverse records require a linked fulfilment" do
    fulfillment = ProductRequestFulfillment.new(
      product_request: @request, pos_line_item: @line, quantity: 1, kind: "reverse",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "k3"
    )

    refute fulfillment.valid?
    assert_includes fulfillment.errors[:linked_fulfilment], "is required for reverse fulfilments"
  end

  test "reverse quantity cannot exceed the linked fulfilment's remaining reversible quantity" do
    original = ProductRequestFulfillment.create!(
      product_request: @request, pos_line_item: @line, quantity: 2, kind: "fulfill",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "k-original"
    )

    fulfillment = ProductRequestFulfillment.new(
      product_request: @request, pos_line_item: @line, quantity: 3, kind: "reverse",
      linked_fulfilment: original, fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "k4"
    )

    refute fulfillment.valid?
    assert_includes fulfillment.errors[:quantity], "exceeds the linked fulfilment's remaining reversible quantity"
  end

  test "requires a positive quantity" do
    fulfillment = ProductRequestFulfillment.new(
      product_request: @request, pos_line_item: @line, quantity: 0, kind: "fulfill",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "k5"
    )

    refute fulfillment.valid?
    assert_includes fulfillment.errors[:quantity], "must be greater than 0"
  end

  test "posting_key must be unique" do
    ProductRequestFulfillment.create!(
      product_request: @request, pos_line_item: @line, quantity: 1, kind: "fulfill",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "dup-key"
    )

    dup = ProductRequestFulfillment.new(
      product_request: @request, pos_line_item: @line, quantity: 1, kind: "fulfill",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "dup-key"
    )

    refute dup.valid?
    assert_includes dup.errors[:posting_key], "has already been taken"
  end

  test "is append-only: updates and destroys are prevented" do
    fulfillment = ProductRequestFulfillment.create!(
      product_request: @request, pos_line_item: @line, quantity: 1, kind: "fulfill",
      fulfilled_at: Time.current, fulfilled_by_user: @admin, posting_key: "append-only-key"
    )

    assert_raises(ActiveRecord::ReadOnlyRecord) { fulfillment.update!(quantity: 2) }
    refute fulfillment.destroy
    assert_includes fulfillment.errors[:base], "product request fulfilments are append-only"
  end
end
