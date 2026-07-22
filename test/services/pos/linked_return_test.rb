# frozen_string_literal: true

require "test_helper"

module Pos
  class LinkedReturnTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @reason = return_reasons(:defective)

      open_inventory(@variant, quantity: 2, unit_cost_cents: 500)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @sale_line = AddLine.call(pos_transaction: @sale, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item
      net = RecalculateTransaction.call(pos_transaction: @sale).net_total_cents
      AddCashTender.call(pos_transaction: @sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: @sale, pos_session: @session, actor: @admin, completion_idempotency_key: "sale-1"
      )
      @sale_line.reload
      @original_attrs = @sale_line.attributes.slice("unit_price_cents", "quantity", "status")
      @original_tax = @sale_line.pos_line_item_taxes.map { |t| [ t.amount_cents, t.rate.to_s ] }
    end

    test "linked return completes without mutating original sale line and restores stock" do
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLine.call(
        pos_transaction: ret_txn,
        original_pos_line_item: @sale_line,
        quantity: 2,
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin
      )
      assert result.success?, result.error
      return_line = result.pos_line_item

      assert_equal "return", return_line.direction
      assert_equal @sale_line.id, return_line.original_pos_line_item_id
      assert return_line.pos_line_item_taxes.sum(:amount_cents).positive?

      @sale_line.reload
      assert_equal @original_attrs["unit_price_cents"], @sale_line.unit_price_cents
      assert_equal @original_attrs["quantity"], @sale_line.quantity
      assert_equal "completed", @sale_line.status
      assert_equal @original_tax, @sale_line.pos_line_item_taxes.map { |t| [ t.amount_cents, t.rate.to_s ] }

      net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
      assert net.negative?
      refund = pos_add_cash_refund(
        pos_transaction: ret_txn, amount_cents: -net, actor: @admin
      )
      assert refund.success?, refund.error

      complete = CompleteTransaction.call(
        pos_transaction: ret_txn, pos_session: @session, actor: @admin, completion_idempotency_key: "ret-1"
      )
      assert complete.success?, complete.error

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 2, balance.on_hand

      ledger = InventoryLedgerEntry.find_by(posting_key: Inventory::PostCustomerReturn.posting_key(return_line))
      assert ledger
      assert_equal "customer_return", ledger.movement_type
      assert_equal 2, ledger.quantity_delta
    end

    test "cannot return more than remaining quantity" do
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLine.call(
        pos_transaction: ret_txn,
        original_pos_line_item: @sale_line,
        quantity: 3,
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin
      )
      refute result.success?
      assert_match(/exceeds remaining/, result.error)
    end

    test "denied without pos.return.create" do
      clerk = users(:clerk)
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLine.call(
        pos_transaction: ret_txn,
        original_pos_line_item: @sale_line,
        quantity: 1,
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: clerk
      )
      refute result.success?
      assert_match(/missing permission/, result.error)
    end

    test "linked return reverses historical discount so refund matches net paid" do
      open_inventory(@variant, quantity: 1, unit_cost_cents: 500)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item
      discount = ApplyDiscount.call(
        pos_transaction: sale, scope: "line", pos_line_item: line, method: "fixed_amount",
        amount_cents: 200, actor: @admin
      )
      assert discount.success?, discount.error
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin, completion_idempotency_key: "sale-disc-1"
      )
      line.reload

      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      assert result.success?, result.error
      return_line = result.pos_line_item
      assert_equal 200, return_line.pos_discount_allocations.sum(:allocated_amount_cents)

      return_net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
      assert_equal(-sale_net, return_net)
    end

    test "linked return quantity cannot be edited and creates no outbound reservation" do
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      return_line = AddLinkedReturnLine.call(
        pos_transaction: ret_txn,
        original_pos_line_item: @sale_line,
        quantity: 1,
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin
      ).pos_line_item

      assert_equal 0, InventoryReservation.active.where(
        source_type: "pos_line_item", source_id: return_line.id
      ).count

      result = UpdateLineQty.call(pos_line_item: return_line, quantity: 2, actor: @admin)

      assert_not result.success?
      assert_match(/linked return quantity cannot be edited/i, result.error)
      assert_equal 1, return_line.reload.quantity
      assert_equal 0, InventoryReservation.active.where(
        source_type: "pos_line_item", source_id: return_line.id
      ).count

      net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
      pos_add_cash_refund(
        pos_transaction: ret_txn, amount_cents: -net, actor: @admin
      )
      complete = CompleteTransaction.call(
        pos_transaction: ret_txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "ret-qty-immutable"
      )
      assert complete.success?, complete.error
      assert_equal 0, InventoryReservation.active.where(
        source_type: "pos_line_item", source_id: return_line.id
      ).count
    end

    test "non-stock disposition restores on_hand as unavailable" do
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: @sale_line, quantity: 1,
        return_reason: @reason, return_disposition: "damaged", actor: @admin
      )
      assert result.success?, result.error
      net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
      pos_add_cash_refund(pos_transaction: ret_txn, amount_cents: -net, actor: @admin)
      complete = CompleteTransaction.call(
        pos_transaction: ret_txn, pos_session: @session, actor: @admin, completion_idempotency_key: "ret-damaged"
      )
      assert complete.success?, complete.error

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 1, balance.on_hand
      assert_equal 1, balance.unavailable
      assert_equal 0, balance.available
    end

    test "cancelling a return transaction restores returnable quantity" do
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: @sale_line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      assert_equal 1, @sale_line.remaining_returnable_quantity

      cancel = CancelTransaction.call(pos_transaction: ret_txn, actor: @admin, reason: "customer changed mind")
      assert cancel.success?, cancel.error
      assert_equal "removed", ret_txn.pos_line_items.first.reload.status
      assert_equal 2, @sale_line.remaining_returnable_quantity
    end

    test "tax exemption on a mixed transaction still refunds linked return tax" do
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: @sale_line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      AddOpenRingLine.call(
        pos_transaction: ret_txn, department: departments(:books_new), unit_price_cents: 500, actor: @admin
      )
      ApplyTaxExemption.call(pos_transaction: ret_txn, exemption_type: "nonprofit", actor: @admin)

      totals = RecalculateTransaction.call(pos_transaction: ret_txn)
      assert totals.tax_exempt?
      assert totals.tax_total_cents.negative?, "expected refunded original tax to remain after exemption"
      return_line = ret_txn.pos_line_items.returns.pending.first
      assert return_line.pos_line_item_taxes.sum(:amount_cents).positive?
    end

    test "partial returns exactly exhaust original tax cents" do
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      # Force a awkward tax amount via open-ring style is hard; use existing calc then assert residual policy.
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin, completion_idempotency_key: "sale-partial-tax"
      )
      line.reload
      original_tax = line.pos_line_item_taxes.sum(:amount_cents)
      skip "need positive tax for residual test" if original_tax <= 0

      refunded = 0
      3.times do |i|
        ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
        result = AddLinkedReturnLine.call(
          pos_transaction: ret_txn, original_pos_line_item: line, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        )
        assert result.success?, result.error
        refunded += result.pos_line_item.pos_line_item_taxes.sum(:amount_cents)
        net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
        pos_add_cash_refund(pos_transaction: ret_txn, amount_cents: -net, actor: @admin)
        CompleteTransaction.call(
          pos_transaction: ret_txn, pos_session: @session, actor: @admin,
          completion_idempotency_key: "ret-partial-#{i}"
        )
      end

      assert_equal original_tax, refunded
    end

    test "pending return in another transaction does not claim tax residual cents" do
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin, completion_idempotency_key: "sale-pending-residual"
      )
      line.reload
      original_tax = line.pos_line_item_taxes.sum(:amount_cents)
      skip "need positive tax for residual test" if original_tax <= 0

      pending_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      pending = AddLinkedReturnLine.call(
        pos_transaction: pending_txn, original_pos_line_item: line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      assert pending.success?, pending.error

      completed_refund = 0
      2.times do |i|
        ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
        result = AddLinkedReturnLine.call(
          pos_transaction: ret_txn, original_pos_line_item: line, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        )
        assert result.success?, result.error
        completed_refund += result.pos_line_item.pos_line_item_taxes.sum(:amount_cents)
        net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
        pos_add_cash_refund(pos_transaction: ret_txn, amount_cents: -net, actor: @admin)
        CompleteTransaction.call(
          pos_transaction: ret_txn, pos_session: @session, actor: @admin,
          completion_idempotency_key: "ret-pending-residual-#{i}"
        )
      end

      CancelTransaction.call(pos_transaction: pending_txn, actor: @admin, reason: "abandoned")

      final_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      final = AddLinkedReturnLine.call(
        pos_transaction: final_txn, original_pos_line_item: line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      assert final.success?, final.error
      completed_refund += final.pos_line_item.pos_line_item_taxes.sum(:amount_cents)

      assert_equal original_tax, completed_refund
    end

    test "two pending return lines in one transaction allocate residual by line order" do
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin, completion_idempotency_key: "sale-multi-line-residual"
      )
      line.reload
      original_tax = line.pos_line_item_taxes.sum(:amount_cents)
      skip "need positive tax for residual test" if original_tax <= 0

      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      first = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      second = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      third = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      assert first.success? && second.success? && third.success?

      recalc = RecalculateTransaction.call(pos_transaction: ret_txn)
      assert recalc.success?, recalc.blockers.inspect
      refunded = ret_txn.pos_line_items.returns.pending.sum { |l| l.pos_line_item_taxes.sum(:amount_cents) }
      assert_equal original_tax, refunded
    end

    test "return-line cost_extended residuals reassign uneven extended cost on the POS lines" do
      # Residual ownership is tracked on pos_line_items.cost_extended_cents.
      # Inventory ledger posting still uses unit cost × quantity; this test does
      # not claim uneven extended cost is reflected in inventory valuation.
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-cost-residual"
      )
      line.reload
      line.update_columns(cost_extended_cents: 100, cost_unit_cost_cents: 33)
      assert_equal 100, line.cost_extended_cents
      assert_equal 3, line.quantity

      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      3.times do
        result = AddLinkedReturnLine.call(
          pos_transaction: ret_txn, original_pos_line_item: line, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        )
        assert result.success?, result.error
      end

      reversed = ret_txn.pos_line_items.returns.pending.sum(:cost_extended_cents)
      assert_equal 100, reversed
      assert_equal [ 33, 34, 33 ], ret_txn.pos_line_items.returns.pending.order(:position, :id).pluck(:cost_extended_cents)
    end

    test "two separate pending return transactions reassign cost residuals when completed in either order" do
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-cross-txn-cost"
      )
      line.reload
      line.update_columns(cost_extended_cents: 100, cost_unit_cost_cents: 33)

      a = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      b = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      c = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      [ a, b, c ].each do |txn|
        assert AddLinkedReturnLine.call(
          pos_transaction: txn, original_pos_line_item: line, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        ).success?
      end

      # AddCashRefundTender / CompleteTransaction finalize residuals under locks.
      complete_return = ->(txn, key) {
        net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
        pos_add_cash_refund(pos_transaction: txn, amount_cents: -net, actor: @admin)
        assert CompleteTransaction.call(
          pos_transaction: txn, pos_session: @session, actor: @admin,
          completion_idempotency_key: key
        ).success?
        txn.pos_line_items.returns.where(status: "completed").sum(:cost_extended_cents)
      }

      costs_ab = [ complete_return.call(a, "cross-a"), complete_return.call(b, "cross-b"), complete_return.call(c, "cross-c") ]
      assert_equal 100, costs_ab.sum

      # Reverse order on a fresh sale
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      sale2 = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line2 = AddLine.call(pos_transaction: sale2, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      sale2_net = RecalculateTransaction.call(pos_transaction: sale2).net_total_cents
      AddCashTender.call(pos_transaction: sale2, tender_type: @cash, amount_tendered_cents: sale2_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale2, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-cross-txn-cost-2"
      )
      line2.reload
      line2.update_columns(cost_extended_cents: 100, cost_unit_cost_cents: 33)

      x = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      y = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      z = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      [ x, y, z ].each do |txn|
        assert AddLinkedReturnLine.call(
          pos_transaction: txn, original_pos_line_item: line2, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        ).success?
      end

      costs_zyx = [ complete_return.call(z, "cross-z"), complete_return.call(y, "cross-y"), complete_return.call(x, "cross-x") ]
      assert_equal 100, costs_zyx.sum
    end

    test "concurrent completion across separate POS sessions preserves cost residual total" do
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-concurrent-cost"
      )
      line.reload
      line.update_columns(cost_extended_cents: 100, cost_unit_cost_cents: 33)

      # Separate devices/drawers so CompleteTransaction session locks do not serialize
      # the threads before they reach original-line residual locks.
      sessions = [ @session ]
      2.times do |i|
        device = PosDevice.create!(
          store: @store, code: "REG-X#{i}", name: "Register X#{i}", device_type: "register", active: true
        )
        drawer = CashDrawer.create!(
          store: @store, code: "DRW-X#{i}", name: "Drawer X#{i}", active: true
        )
        sessions << OpenSession.call(
          business_day: @day, store: @store, pos_device: device, cash_drawer: drawer,
          opening_cash_cents: 0, cashier: @admin, actor: @admin
        ).pos_session
      end

      pairs = sessions.map { |session|
        txn = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
        assert AddLinkedReturnLine.call(
          pos_transaction: txn, original_pos_line_item: line, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        ).success?
        [ txn, session ]
      }

      barriers = Queue.new
      results = Queue.new
      threads = pairs.each_with_index.map do |(txn, session), idx|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barriers << true
            sleep 0.05 until barriers.size >= 3
            net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
            pos_add_cash_refund(pos_transaction: txn, amount_cents: -net, actor: @admin)
            completed = CompleteTransaction.call(
              pos_transaction: txn, pos_session: session, actor: @admin,
              completion_idempotency_key: "concurrent-cost-#{idx}"
            )
            results << [ completed.success?, txn.id, completed.error ]
          end
        end
      end
      threads.each(&:join)

      outcomes = 3.times.map { results.pop }
      assert outcomes.all?(&:first), outcomes.inspect
      total = PosLineItem.where(
        original_pos_line_item_id: line.id, status: "completed", direction: "return"
      ).sum(:cost_extended_cents)
      assert_equal 100, total
    end

    test "card refund after sibling completion uses finalized residual net" do
      open_inventory(@variant, quantity: 3, unit_cost_cents: 100)
      card = tender_types(:card_standalone)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item
      assert ApplyDiscount.call(
        pos_transaction: sale, scope: "line", pos_line_item: line, method: "fixed_amount",
        amount_cents: 100, actor: @admin
      ).success?
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: card, amount_cents: sale_net,
        authorization_code: "SALE-RES", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-card-residual"
      ).success?
      line.reload
      sale_card = sale.pos_tenders.where(status: "completed").first

      a = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      b = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      [ a, b ].each do |txn|
        assert AddLinkedReturnLine.call(
          pos_transaction: txn, original_pos_line_item: line, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        ).success?
      end

      due_a = ActiveRecord::Base.transaction {
        -FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(a.id))
          .recalculation.net_total_cents
      }
      assert AddCardRefundTender.call(
        pos_transaction: a, tender_type: card, amount_cents: due_a, actor: @admin,
        authorization_code: "RFND-A", original_pos_tender: sale_card
      ).success?
      assert CompleteTransaction.call(
        pos_transaction: a, pos_session: @session, actor: @admin,
        completion_idempotency_key: "ret-a-residual"
      ).success?

      due_b = ActiveRecord::Base.transaction {
        -FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(b.id))
          .recalculation.net_total_cents
      }
      assert AddCardRefundTender.call(
        pos_transaction: b, tender_type: card, amount_cents: due_b, actor: @admin,
        authorization_code: "RFND-B", original_pos_tender: sale_card
      ).success?
    end

    test "net-positive mixed txn received tenders finalize after sibling return" do
      open_inventory(@variant, quantity: 12, unit_cost_cents: 400)
      card = tender_types(:card_standalone)
      sv_tender = tender_types(:stored_value)
      IdentifierSequence.ensure_defaults!
      account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      StoredValue::PostEntry.call(
        account: account, store: @store, entry_type: "issued", amount_cents: 50_000,
        posting_key: "mixed-sv-seed", actor: @admin
      )

      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 5, actor: @admin).pos_line_item
      assert ApplyDiscount.call(
        pos_transaction: sale, scope: "line", pos_line_item: line, method: "fixed_amount",
        amount_cents: 100, actor: @admin
      ).success?
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-mixed-finalize"
      ).success?
      line.reload

      build_mixed = lambda {
        txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
        assert AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 2, actor: @admin).success?
        assert AddLinkedReturnLine.call(
          pos_transaction: txn, original_pos_line_item: line, quantity: 1,
          return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
        ).success?
        due = ActiveRecord::Base.transaction {
          FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(txn.id))
            .recalculation.net_total_cents
        }
        assert due.positive?, "expected net-positive mixed txn"
        [ txn, due ]
      }

      mixed_card, = build_mixed.call
      sibling = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: sibling, original_pos_line_item: line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      ).success?
      sib_due = -ActiveRecord::Base.transaction {
        FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(sibling.id))
          .recalculation.net_total_cents
      }
      pos_add_cash_refund(pos_transaction: sibling, amount_cents: sib_due, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: sibling, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sibling-mixed"
      ).success?

      current_due = ActiveRecord::Base.transaction {
        FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(mixed_card.id))
          .recalculation.net_total_cents
      }
      # External auth amount no longer matches finalized balance — amount_mismatch for record-and-void.
      card_tender = AddCardTender.call(
        pos_transaction: mixed_card, tender_type: card, amount_cents: current_due + 50,
        authorization_code: "MIXED-STALE", actor: @admin
      )
      refute card_tender.success?
      assert card_tender.requires_void_confirmation?
      assert RecordVoidedCardTender.call(
        pos_transaction: mixed_card, tender_type: card, amount_cents: current_due + 50,
        authorization_code: "MIXED-STALE", actor: @admin, external_void_confirmed: true
      ).success?
      assert AddCardTender.call(
        pos_transaction: mixed_card, tender_type: card, amount_cents: current_due,
        authorization_code: "MIXED-OK", actor: @admin
      ).success?

      mixed_cash, = build_mixed.call
      cash_due = ActiveRecord::Base.transaction {
        FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(mixed_cash.id))
          .recalculation.net_total_cents
      }
      assert AddCashTender.call(
        pos_transaction: mixed_cash, tender_type: @cash, amount_tendered_cents: cash_due, actor: @admin
      ).success?

      mixed_sv, = build_mixed.call
      sv_due = ActiveRecord::Base.transaction {
        FinalizeReturnFinancials.call(pos_transaction: PosTransaction.lock.find(mixed_sv.id))
          .recalculation.net_total_cents
      }
      assert AddStoredValueTender.call(
        pos_transaction: mixed_sv, tender_type: sv_tender, account: account,
        amount_cents: sv_due, actor: @admin
      ).success?
    end

    test "stored-value sale lines are not linked-returnable" do
      account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddStoredValueLine.call(
        pos_transaction: sale, account: account, operation: "issue",
        amount_cents: 500, actor: @admin
      ).success?
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sv-no-return"
      ).success?
      sv_line = sale.pos_line_items.where(line_kind: "stored_value").first
      assert_equal 0, sv_line.remaining_returnable_quantity

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      denied = AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sv_line, quantity: 1,
        return_reason: @reason, return_disposition: "return_to_stock", actor: @admin
      )
      refute denied.success?
      assert_match(/stored-value lines cannot be returned/, denied.error)
    end

    test "discard disposition leaves pre-existing inventory valuation unchanged" do
      # Sale setup left on_hand at 0 with historical sale cost 500. Restock at a
      # different cost so discard must not blend the returned unit into survivors.
      open_inventory(@variant, quantity: 10, unit_cost_cents: 1000)
      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 10, balance.on_hand
      assert_equal 10_000, balance.inventory_value_cents

      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: @sale_line, quantity: 1,
        return_reason: @reason, return_disposition: "discard", actor: @admin
      )
      assert result.success?, result.error
      net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
      pos_add_cash_refund(pos_transaction: ret_txn, amount_cents: -net, actor: @admin)
      complete = CompleteTransaction.call(
        pos_transaction: ret_txn, pos_session: @session, actor: @admin, completion_idempotency_key: "ret-discard-val"
      )
      assert complete.success?, complete.error

      balance.reload
      assert_equal 10, balance.on_hand
      assert_equal 10_000, balance.inventory_value_cents
      assert_equal 1000, balance.moving_average_cost_cents

      discard_entry = InventoryLedgerEntry.find_by!(
        posting_key: Inventory::PostCustomerReturn.discard_posting_key(result.pos_line_item)
      )
      assert_equal(-1, discard_entry.quantity_delta)
      assert_equal 500, discard_entry.unit_cost_cents
      assert_equal(-500, discard_entry.inventory_value_delta_cents)
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
        input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
    end
  end
end
