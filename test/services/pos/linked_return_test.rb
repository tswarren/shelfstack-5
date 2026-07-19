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
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, cashier: @admin, actor: @admin
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
      refund = AddCashRefundTender.call(
        pos_transaction: ret_txn, tender_type: @cash, amount_cents: -net, actor: @admin
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

    test "non-stock disposition restores on_hand as unavailable" do
      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: @sale_line, quantity: 1,
        return_reason: @reason, return_disposition: "damaged", actor: @admin
      )
      assert result.success?, result.error
      net = RecalculateTransaction.call(pos_transaction: ret_txn).net_total_cents
      AddCashRefundTender.call(pos_transaction: ret_txn, tender_type: @cash, amount_cents: -net, actor: @admin)
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
        AddCashRefundTender.call(pos_transaction: ret_txn, tender_type: @cash, amount_cents: -net, actor: @admin)
        CompleteTransaction.call(
          pos_transaction: ret_txn, pos_session: @session, actor: @admin,
          completion_idempotency_key: "ret-partial-#{i}"
        )
      end

      assert_equal original_tax, refunded
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
