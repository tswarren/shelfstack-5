# frozen_string_literal: true

require "application_system_test_case"

# Phase 5g exit-gate coverage: Customer Request -> Purchase-Order Allocation
# -> receipt conversion to Inventory Reservation -> Product Request
# Fulfilment through POS completion, mixing browser steps (allocation,
# receipt posting) with the existing POS service helpers (no UI yet links a
# POS line to a Product Request).
class ProductRequestFulfillmentFlowTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @vendor = vendors(:acme_distributor)
    @variant = product_variants(:sample_book_standard)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)

    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"
  end

  test "allocation converts to reservation on receipt and fulfils through POS completion" do
    request = Requests::CreateProductRequest.call(
      store: @store, actor: @admin,
      attributes: {
        request_type: "customer_request", product_id: @variant.product_id, product_variant_id: @variant.id,
        requested_quantity: 2, priority: "high", customer_reference: "SYS-CR-1"
      }
    ).product_request
    assert request.persisted?

    purchase_order = Purchasing::CreatePurchaseOrder.call(
      purchase_order: @store.purchase_orders.new(vendor: @vendor),
      lines_attributes: [
        { product_variant_id: @variant.id, ordered_quantity: 2, cost_entry_method: "direct_net_cost",
          expected_unit_cost_cents: 700, position: 0 }
      ],
      actor: @admin, store: @store
    ).purchase_order
    place_result = Purchasing::PlacePurchaseOrder.call(purchase_order: purchase_order, actor: @admin, store: @store)
    assert place_result.success?, place_result.error
    line = purchase_order.purchase_order_lines.first

    visit product_request_path(request)
    assert_text "Product request ##{request.id}"

    option_text = "#{purchase_order.reload.purchase_order_number} — The Illustrated Man — Standard · SKU 2800000000011 (open 2)"
    select option_text, from: "Purchase order line"
    fill_in "Quantity", with: "2"
    click_button "Create allocation"

    assert_text "Allocation created."
    assert_equal 1, request.purchase_order_allocations.count
    assert_equal 2, request.reload.remaining_allocated_quantity

    receipt = Inventory::CreateReceipt.call(
      receipt: @store.receipts.new(vendor: @vendor),
      lines_attributes: [
        { product_variant_id: @variant.id, purchase_order_line_id: line.id, delivered_quantity: 2,
          accepted_quantity: 2, actual_unit_cost_cents: 700, cost_quality: "actual" }
      ],
      actor: @admin, store: @store
    ).receipt
    assert receipt.persisted?

    visit receipt_path(receipt)
    accept_confirm { click_button "Post receipt" }
    assert_text "Receipt posted"

    reservation = InventoryReservation.active.find_by(source_type: "product_request", source_id: request.id)
    assert_not_nil reservation, "expected the allocation to convert to an active Inventory Reservation on receipt"
    assert_equal 2, reservation.quantity
    assert_equal 0, request.reload.remaining_allocated_quantity

    _day, session = pos_open_cash_session(store: @store, device: @device, drawer: @drawer, actor: @admin)
    pos_complete_cash_sale(
      session: session, variant: @variant, quantity: 2, actor: @admin, cash: tender_types(:cash),
      key: "sys-fulfil-#{request.id}", product_request: request.reload
    )

    visit product_request_path(request)
    assert_text "Fulfilled"
    assert_equal "fulfilled", request.reload.status
    assert_equal 2, request.fulfilled_quantity
  end
end
