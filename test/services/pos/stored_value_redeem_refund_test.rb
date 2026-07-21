# frozen_string_literal: true

require "test_helper"

module Pos
  class StoredValueRedeemRefundTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @cash = tender_types(:cash)
      @sv_tender = tender_types(:stored_value)
      @variant = product_variants(:sample_book_standard)
      IdentifierSequence.ensure_defaults!
      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)

      @account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      StoredValue::PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 5000,
        posting_key: "sv-seed", actor: @admin
      )

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "redemption settles sale and debits ledger" do
      transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: transaction, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: transaction).net_total_cents

      tender_result = AddStoredValueTender.call(
        pos_transaction: transaction, tender_type: @sv_tender, account: @account,
        amount_cents: net, actor: @admin
      )
      assert tender_result.success?, tender_result.error

      completed = CompleteTransaction.call(
        pos_transaction: transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sv-redeem-1"
      )
      assert completed.success?, completed.error
      assert_equal 5000 - net, @account.reload.current_balance_cents
      assert StoredValueEntry.exists?(entry_type: "redeemed", amount_cents: -net)
    end

    test "refund creates store credit account and credits on complete" do
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-for-refund"
      ).success?
      sale_line = sale.pos_line_items.where(status: "completed").first

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      return_result = AddLinkedReturnLine.call(
        pos_transaction: ret,
        original_pos_line_item: sale_line,
        quantity: 1,
        return_reason: return_reasons(:unwanted),
        return_disposition: "return_to_stock",
        actor: @admin
      )
      assert return_result.success?, return_result.error

      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      assert refund_due.positive?

      result = AddStoredValueRefundTender.call(
        pos_transaction: ret, tender_type: @sv_tender, amount_cents: refund_due,
        actor: @admin, create_store_credit: true
      )
      assert result.success?, result.error
      credit_account = result.account
      assert_equal "store_credit", credit_account.account_type

      completed = CompleteTransaction.call(
        pos_transaction: ret, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sv-refund-1"
      )
      assert completed.success?, completed.error
      assert_equal refund_due, credit_account.reload.current_balance_cents
      assert StoredValueEntry.exists?(
        stored_value_account_id: credit_account.id, entry_type: "refunded", amount_cents: refund_due
      )
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      reason = inventory_adjustment_reasons(:opening_initial)
      adjustment = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: reason, created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment, product_variant: variant, position: 0,
        quantity_delta: quantity, input_unit_cost_cents: unit_cost_cents,
        input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: adjustment, actor: @admin, store: @store).success?
    end
  end
end
