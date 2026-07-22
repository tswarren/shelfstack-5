# frozen_string_literal: true

require "test_helper"

module Pos
  # Phase 5f: Product Request Fulfilment created/reversed atomically inside
  # Pos::CompleteTransaction (OD-007).
  class CompleteTransactionFulfilmentTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)

      pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)
      @day, @session = pos_open_cash_session(store: @store, device: @device, drawer: @drawer, actor: @admin)
      @request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product, product_variant: @variant,
        requested_quantity: 2, requested_by_user: @admin
      )
    end

    test "completion creates a fulfilment fact, consumes the reservation, and closes a fully fulfilled request" do
      reserved = Requests::ReserveInHouseInventory.call(
        product_request: @request, quantity: 2, actor: @admin, store: @store, physically_confirmed: true
      )
      assert reserved.success?, reserved.error

      txn, line, _net = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 2, actor: @admin, cash: @cash, key: "fulfil-1", product_request: @request
      )

      fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: line.id, kind: "fulfill")
      assert fulfillment
      assert_equal 2, fulfillment.quantity
      assert_equal reserved.reservation, fulfillment.inventory_reservation
      assert_equal @request, fulfillment.product_request

      reserved.reservation.reload
      assert_equal "converted", reserved.reservation.status
      assert_equal "pos_line_item", reserved.reservation.source_type
      assert_equal line.id, reserved.reservation.source_id

      @request.reload
      assert @request.fulfilled?
      assert_equal 2, @request.fulfilled_quantity
      assert_equal 0, @request.uncovered_quantity

      assert txn.completed?
    end

    test "partial fulfilment leaves the customer request open" do
      pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin, cash: @cash, key: "fulfil-partial", product_request: @request
      )

      @request.reload
      assert @request.open?
      assert_equal 1, @request.fulfilled_quantity
      assert_equal 1, @request.uncovered_quantity
    end

    test "fulfilment succeeds even without a pre-existing in-house reservation" do
      txn, line, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin, cash: @cash, key: "fulfil-no-reservation", product_request: @request
      )

      fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: line.id)
      assert fulfillment
      # AddLine still creates a POS-line reservation for the sale; completion
      # converts it and links that converted reservation to the fulfilment.
      assert_equal "converted", fulfillment.inventory_reservation.status
      assert_equal "pos_line_item", fulfillment.inventory_reservation.source_type
      assert_equal line.id, fulfillment.inventory_reservation.source_id
      assert txn.completed?
    end

    test "a failed completion leaves no fulfilment fact (atomicity)" do
      txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = Pos::AddLine.call(
        pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin, product_request: @request
      ).pos_line_item
      # Deliberately under-tender so completion fails on settlement.
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: 1, actor: @admin)

      result = Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "atomic-fail"
      )
      refute result.success?

      refute ProductRequestFulfillment.exists?(pos_line_item_id: line.id)
      @request.reload
      assert @request.open?
      assert_equal 0, @request.fulfilled_quantity
    end

    test "denies completion when the actor lacks requests.customer_request.fulfill (whole completion rolls back)" do
      reserved = Requests::ReserveInHouseInventory.call(
        product_request: @request, quantity: 1, actor: @admin, store: @store, physically_confirmed: true
      )
      assert reserved.success?, reserved.error

      txn = Pos::OpenTransaction.call(pos_session: @session, actor: @clerk).pos_transaction
      line = Pos::AddLine.call(
        pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @clerk, product_request: @request
      ).pos_line_item
      net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @clerk)

      result = Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @clerk, completion_idempotency_key: "denied-fulfil"
      )

      refute result.success?
      assert_match(/not permitted/i, result.error)

      txn.reload
      assert txn.open?
      line.reload
      assert line.pending?
      refute ProductRequestFulfillment.exists?(pos_line_item_id: line.id)

      reserved.reservation.reload
      assert reserved.reservation.active?
    end

    test "repeating completion with the same idempotency key does not duplicate the fulfilment fact" do
      txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = Pos::AddLine.call(
        pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin, product_request: @request
      ).pos_line_item
      net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)

      first = Pos::CompleteTransaction.call(pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "dup-key")
      assert first.success?, first.error

      second = Pos::CompleteTransaction.call(pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "dup-key")
      assert second.success?
      assert second.replayed

      assert_equal 1, ProductRequestFulfillment.where(pos_line_item_id: line.id).count
      assert_equal 1, @request.reload.fulfilled_quantity
    end

    test "a linked return of a fulfilled sale line appends a reverse fulfilment and reopens the request" do
      txn, line, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 2, actor: @admin, cash: @cash, key: "fulfil-then-return", product_request: @request
      )
      assert @request.reload.fulfilled?

      return_txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      return_line = Pos::AddLinkedReturnLine.call(
        pos_transaction: return_txn, original_pos_line_item: line, quantity: 2,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).pos_line_item
      net = Pos::RecalculateTransaction.call(pos_transaction: return_txn).net_total_cents
      pos_add_cash_refund(pos_transaction: return_txn, amount_cents: net.abs, actor: @admin)

      result = Pos::CompleteTransaction.call(
        pos_transaction: return_txn, pos_session: @session, actor: @admin, completion_idempotency_key: "return-key"
      )
      assert result.success?, result.error

      reversal = ProductRequestFulfillment.find_by(pos_line_item_id: return_line.id, kind: "reverse")
      assert reversal
      assert_equal 2, reversal.quantity
      original_fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: line.id, kind: "fulfill")
      assert_equal original_fulfillment, reversal.linked_fulfilment

      @request.reload
      assert @request.open?
      assert_equal 0, @request.fulfilled_quantity
      assert_equal 2, @request.uncovered_quantity
    end

    test "ordering, receiving, and reserving alone do not close the customer request" do
      po = Purchasing::CreatePurchaseOrder.call(
        purchase_order: PurchaseOrder.new(vendor: @vendor),
        lines_attributes: [ { product_variant_id: @variant.id, ordered_quantity: 2,
                               cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 700 } ],
        actor: @admin, store: @store
      )
      assert po.success?, po.error
      placed = Purchasing::PlacePurchaseOrder.call(purchase_order: po.purchase_order, actor: @admin, store: @store)
      assert placed.success?, placed.error
      po_line = placed.purchase_order.purchase_order_lines.first

      allocation = Purchasing::CreateAllocation.call(purchase_order_line: po_line, product_request: @request, quantity: 2, actor: @admin, store: @store)
      assert allocation.success?, allocation.error
      assert @request.reload.open?

      receipt = Inventory::CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ { product_variant_id: @variant.id, purchase_order_line_id: po_line.id,
                               delivered_quantity: 2, accepted_quantity: 2, actual_unit_cost_cents: 700, cost_quality: "actual" } ],
        actor: @admin, store: @store
      ).receipt
      posted = Inventory::PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert posted.success?, posted.error
      assert @request.reload.open?

      reservation = InventoryReservation.find_by(source_type: "product_request", source_id: @request.id)
      assert_equal 2, reservation.quantity
      assert @request.reload.open?
      assert_equal 0, @request.uncovered_quantity

      # Only completing a sale against the reserved supply fulfils and closes it.
      pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 2, actor: @admin, cash: @cash, key: "close-via-pos", product_request: @request
      )
      assert @request.reload.fulfilled?
    end

    test "non-inventory product sales still record product request fulfilment" do
      none_variant = product_variants(:gift_wrap_service_standard)
      request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: none_variant.product,
        product_variant: none_variant, requested_quantity: 1, requested_by_user: @admin
      )

      txn, line, = pos_complete_cash_sale(
        session: @session, variant: none_variant, quantity: 1, actor: @admin, cash: @cash,
        key: "fulfil-none-tracking", product_request: request
      )

      fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: line.id, kind: "fulfill")
      assert fulfillment
      assert_nil fulfillment.inventory_reservation_id
      assert_equal 1, fulfillment.quantity
      assert request.reload.fulfilled?
      assert txn.completed?
    end

    test "post-void of a fulfilled sale reverses fulfilment and reopens the request" do
      reserved = Requests::ReserveInHouseInventory.call(
        product_request: @request, quantity: 2, actor: @admin, store: @store, physically_confirmed: true
      )
      assert reserved.success?, reserved.error

      txn, line, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 2, actor: @admin, cash: @cash,
        key: "fulfil-then-void", product_request: @request
      )
      assert @request.reload.fulfilled?

      result = PostVoidTransaction.call(
        original_transaction: txn, pos_session: @session, actor: @admin,
        reason: "fulfilment void", completion_idempotency_key: "pv-fulfil",
        approver: @admin, approver_pin: "1234"
      )
      assert result.success?, result.error

      reverse = ProductRequestFulfillment.find_by(pos_line_item_id: result.pos_transaction.pos_line_items.first.id, kind: "reverse")
      assert reverse || ProductRequestFulfillment.exists?(kind: "reverse", product_request_id: @request.id)
      @request.reload
      refute @request.fulfilled?
      assert_equal 0, @request.fulfilled_quantity
      assert ProductRequestFulfillment.exists?(pos_line_item_id: line.id, kind: "fulfill")
    end

    test "concurrent return completion and post-void do not deadlock; one path wins" do
      reserved = Requests::ReserveInHouseInventory.call(
        product_request: @request, quantity: 2, actor: @admin, store: @store, physically_confirmed: true
      )
      assert reserved.success?, reserved.error

      txn, line, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 2, actor: @admin, cash: @cash,
        key: "fulfil-race", product_request: @request
      )

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: line, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      assert pos_add_cash_refund(
        pos_transaction: ret, amount_cents: refund_due, actor: @admin
      ).success?

      results = {}
      barrier = Concurrent::CyclicBarrier.new(2)
      t1 = Thread.new do
        barrier.wait
        results[:return] = CompleteTransaction.call(
          pos_transaction: ret, pos_session: @session, actor: @admin,
          completion_idempotency_key: "ret-race"
        )
      end
      t2 = Thread.new do
        barrier.wait
        results[:void] = PostVoidTransaction.call(
          original_transaction: txn, pos_session: @session, actor: @admin,
          reason: "race void", completion_idempotency_key: "pv-race-fulfill",
          approver: @admin, approver_pin: "1234"
        )
      end
      [ t1, t2 ].each(&:join)

      assert results.values.any?(&:success?), results.transform_values(&:error).inspect
      # Exactly one of: return completed, or original post-voided (not both effects surviving inconsistently).
      ret_done = results[:return].success?
      void_done = results[:void].success?
      assert ret_done ^ void_done || (ret_done && !void_done) || (!ret_done && void_done)
      if ret_done
        refute txn.reload.post_voided?
      end
      if void_done
        refute ret.reload.completed?
      end
    end
  end
end
