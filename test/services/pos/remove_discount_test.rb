# frozen_string_literal: true

require "test_helper"

module Pos
  class RemoveDiscountTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @department = departments(:books_new)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "removes a line-scoped discount and restores line discount total" do
      line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department, unit_price_cents: 1000, actor: @admin
      ).pos_line_item
      applied = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line,
        method: "fixed_amount", amount_cents: 250, actor: @admin
      )
      assert applied.success?
      discount = applied.pos_discount
      assert_equal 250, line.reload.discount_amount_cents

      result = RemoveDiscount.call(pos_discount: discount, actor: @admin)

      assert result.success?, result.error
      assert_nil PosDiscount.find_by(id: discount.id)
      assert_equal 0, PosDiscountAllocation.where(pos_discount_id: discount.id).count
      assert_equal 0, line.reload.discount_amount_cents
      assert_equal 0, RecalculateTransaction.call(pos_transaction: @transaction).discount_total_cents
    end

    test "removes a transaction-scoped discount and its allocations" do
      AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department, unit_price_cents: 1000, actor: @admin
      )
      AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department, unit_price_cents: 2000, actor: @admin
      )
      applied = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "transaction", method: "percentage",
        rate_bps: 1000, actor: @admin
      )
      assert applied.success?
      discount = applied.pos_discount
      assert_equal 300, discount.applied_amount_cents

      result = RemoveDiscount.call(pos_discount: discount, actor: @admin)

      assert result.success?, result.error
      assert_nil PosDiscount.find_by(id: discount.id)
      assert_equal 0, RecalculateTransaction.call(pos_transaction: @transaction).discount_total_cents
    end

    test "refuses to remove a discount after the transaction is no longer editable" do
      line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
      ).pos_line_item
      discount = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line,
        method: "fixed_amount", amount_cents: 100, actor: @admin
      ).pos_discount

      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(
        pos_transaction: @transaction, tender_type: tender_types(:cash),
        amount_tendered_cents: net, actor: @admin
      )
      CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "remove-discount-completed"
      )

      result = RemoveDiscount.call(pos_discount: discount, actor: @admin)

      assert_not result.success?
      assert_match(/not open for editing/i, result.error)
      assert PosDiscount.exists?(discount.id)
    end

    test "refuses to remove historical linked-return discount reversals" do
      variant = product_variants(:sample_book_standard)
      cash = tender_types(:cash)
      reason = return_reasons(:defective)

      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: variant, position: 0,
        quantity_delta: 1, input_unit_cost_cents: 500, input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?

      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      sale_line = AddLine.call(
        pos_transaction: sale, product_variant: variant, quantity: 1, actor: @admin
      ).pos_line_item
      ApplyDiscount.call(
        pos_transaction: sale, scope: "line", pos_line_item: sale_line,
        method: "fixed_amount", amount_cents: 200, actor: @admin
      )
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(
        pos_transaction: sale, tender_type: cash, amount_tendered_cents: sale_net, actor: @admin
      )
      CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "remove-return-reversal-sale"
      )
      sale_line.reload

      ret_txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      return_line = AddLinkedReturnLine.call(
        pos_transaction: ret_txn, original_pos_line_item: sale_line, quantity: 1,
        return_reason: reason, return_disposition: "return_to_stock", actor: @admin
      ).pos_line_item
      reversal = PosDiscount.find_by!(target_pos_line_item_id: return_line.id)

      result = RemoveDiscount.call(pos_discount: reversal, actor: @admin)

      assert_not result.success?
      assert_match(/historical return discount reversals cannot be removed/i, result.error)
      assert PosDiscount.exists?(reversal.id)
    end
  end
end
