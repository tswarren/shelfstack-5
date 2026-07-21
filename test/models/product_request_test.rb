# frozen_string_literal: true

require "test_helper"

class ProductRequestTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @product = products(:upc_product)
    @variant = product_variants(:upc_product_standard)
    @user = users(:admin)
  end

  test "requires a product" do
    request = ProductRequest.new(
      store: @store, request_type: "staff_suggestion", requested_quantity: 1,
      requested_by_user: @user
    )

    assert_not request.valid?
    assert_includes request.errors[:product], "must exist"
  end

  test "product variant is optional until resolved" do
    request = ProductRequest.new(
      store: @store, request_type: "customer_request", product: @product,
      requested_quantity: 1, requested_by_user: @user
    )

    assert request.valid?, request.errors.full_messages.to_sentence
    assert_nil request.product_variant_id
  end

  test "rejects a variant that does not belong to the requested product" do
    other_variant = product_variants(:signed_book_standard)
    request = ProductRequest.new(
      store: @store, request_type: "staff_suggestion", product: @product,
      product_variant: other_variant, requested_quantity: 1, requested_by_user: @user
    )

    assert_not request.valid?
    assert_includes request.errors[:product_variant], "must belong to the requested product"
  end

  test "rejects requested_quantity that is not positive" do
    request = ProductRequest.new(
      store: @store, request_type: "staff_suggestion", product: @product,
      requested_quantity: 0, requested_by_user: @user
    )

    assert_not request.valid?
    assert_includes request.errors[:requested_quantity], "must be greater than 0"
  end

  test "rejects resolved_quantity greater than requested_quantity" do
    request = ProductRequest.new(
      store: @store, request_type: "staff_suggestion", product: @product,
      requested_quantity: 2, resolved_quantity: 3, requested_by_user: @user
    )

    assert_not request.valid?
    assert_includes request.errors[:resolved_quantity], "must not exceed requested quantity"
  end

  test "rejects an unknown request_type" do
    request = ProductRequest.new(
      store: @store, request_type: "bogus", product: @product,
      requested_quantity: 1, requested_by_user: @user
    )

    assert_not request.valid?
    assert_includes request.errors[:request_type], "is not included in the list"
  end

  test "rejects an unknown resolution code" do
    request = ProductRequest.new(
      store: @store, request_type: "staff_suggestion", product: @product,
      requested_quantity: 1, requested_by_user: @user, resolution: "bogus"
    )

    assert_not request.valid?
    assert_includes request.errors[:resolution], "is not included in the list"
  end

  test "rejects a supersedes_product_request from a different store" do
    other_store_request = ProductRequest.create!(
      store: stores(:warehouse), request_type: "staff_suggestion", product: @product,
      requested_quantity: 1, requested_by_user: @user
    )
    request = ProductRequest.new(
      store: @store, request_type: "staff_suggestion", product: @product,
      requested_quantity: 1, requested_by_user: @user,
      supersedes_product_request: other_store_request
    )

    assert_not request.valid?
    assert_includes request.errors[:supersedes_product_request], "must belong to the same store"
  end

  test "customer_request?/non_customer_request? distinguish obligation semantics" do
    customer = product_requests(:open_customer_request)
    staff = product_requests(:open_staff_suggestion)

    assert customer.customer_request?
    assert_not customer.non_customer_request?
    assert staff.non_customer_request?
    assert_not staff.customer_request?
  end

  test "open_requests scope returns only open requests" do
    assert_includes ProductRequest.open_requests, product_requests(:open_customer_request)
    assert_not_includes ProductRequest.open_requests, product_requests(:resolved_frontlist)
    assert_not_includes ProductRequest.open_requests, product_requests(:cancelled_staff_suggestion)
  end

  test "uncovered_quantity subtracts fulfilled, actively reserved, and remaining allocated quantity" do
    variant = product_variants(:sample_book_standard)
    request = ProductRequest.create!(
      store: @store, request_type: "customer_request", product: variant.product,
      product_variant: variant, requested_quantity: 10, requested_by_user: @user
    )
    assert_equal 10, request.uncovered_quantity

    day = Pos::OpenBusinessDay.call(store: @store, actor: @user).business_day
    session = Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: pos_devices(:register_1), cashier: @user, actor: @user
    ).pos_session
    txn = Pos::OpenTransaction.call(pos_session: session, actor: @user).pos_transaction
    line = PosLineItem.create!(
      pos_transaction: txn, line_kind: "product", status: "completed", direction: "sale",
      product_variant: variant, department: departments(:books_new), quantity: 2,
      unit_price_cents: 1000, created_by_user: @user, product_request: request
    )
    ProductRequestFulfillment.create!(
      product_request: request, pos_line_item: line, quantity: 2, kind: "fulfill",
      fulfilled_at: Time.current, fulfilled_by_user: @user, posting_key: "coverage-test-fulfill"
    )
    assert_equal 2, request.reload.fulfilled_quantity

    InventoryReservation.create!(
      store: @store, product_variant: variant, quantity: 3, status: "active",
      source_type: "product_request", source_id: request.id, reserved_at: Time.current
    )
    assert_equal 3, request.reload.active_reserved_quantity

    pending_line = PosLineItem.create!(
      pos_transaction: txn, line_kind: "product", status: "pending", direction: "sale",
      product_variant: variant, department: departments(:books_new), quantity: 1,
      unit_price_cents: 1000, created_by_user: @user, product_request: request
    )
    InventoryReservation.create!(
      store: @store, product_variant: variant, quantity: 1, status: "active",
      source_type: "pos_line_item", source_id: pending_line.id, reserved_at: Time.current
    )
    assert_equal 4, request.reload.active_reserved_quantity
    assert_equal 1, request.pos_held_reserved_quantity

    allocation = PurchaseOrderAllocation.create!(
      purchase_order_line: purchase_order_lines(:ordered_po_line1), product_request: request,
      quantity: 5, created_by_user: @user
    )
    allocation.release!(quantity: 1, reason: "manual_release", actor: @user)
    assert_equal 4, request.reload.remaining_allocated_quantity

    assert_equal 10 - 2 - 4 - 4, request.uncovered_quantity
  end
end
