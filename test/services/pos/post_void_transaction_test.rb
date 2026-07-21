# frozen_string_literal: true

require "test_helper"

module Pos
  class PostVoidTransactionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)

      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

      AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 2, actor: @admin)
      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "sale-1"
      ).success?
      @transaction.reload
    end

    test "post-void reverses inventory and creates a new receipt without mutating the original" do
      result = PostVoidTransaction.call(
        original_transaction: @transaction,
        pos_session: @session,
        actor: @admin,
        reason: "wrong tender",
        completion_idempotency_key: "pv-1",
        approver: @admin,
        approver_pin: "1234"
      )

      assert result.success?, result.error
      reversing = result.pos_transaction
      assert reversing.completed?
      assert_equal @transaction.id, reversing.reverses_pos_transaction_id
      assert reversing.receipt_number.present?
      refute_equal @transaction.receipt_number, reversing.receipt_number
      assert_equal(-@transaction.net_total_cents, reversing.net_total_cents)
      assert reversing.post_void_pos_approval_id.present?

      @transaction.reload
      assert @transaction.completed?
      assert_equal "sale-1", @transaction.completion_idempotency_key

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 5, balance.on_hand

      sale_line = @transaction.pos_line_items.where(status: "completed").find_by(line_kind: "product")
      sale_entry = InventoryLedgerEntry.find_by!(posting_key: Inventory::ConvertReservation.posting_key(sale_line))
      assert InventoryLedgerEntry.exists?(reversal_of_entry_id: sale_entry.id)
    end

    test "same idempotency key replays; different key is blocked" do
      first = PostVoidTransaction.call(
        original_transaction: @transaction, pos_session: @session, actor: @admin,
        reason: "void", completion_idempotency_key: "pv-same",
        approver: @admin, approver_pin: "1234"
      )
      assert first.success?

      second = PostVoidTransaction.call(
        original_transaction: @transaction, pos_session: @session, actor: @admin,
        reason: "void", completion_idempotency_key: "pv-same",
        approver: @admin, approver_pin: "1234"
      )
      assert second.success?
      assert second.replayed

      third = PostVoidTransaction.call(
        original_transaction: @transaction, pos_session: @session, actor: @admin,
        reason: "void", completion_idempotency_key: "pv-other",
        approver: @admin, approver_pin: "1234"
      )
      refute third.success?
      assert_match(/already been post-voided/, third.error)
    end

    test "self-approval without approve_self is denied" do
      RolePermission.where(
        role: roles(:administrator),
        permission: permissions(:pos_post_void_approve_self)
      ).delete_all

      result = PostVoidTransaction.call(
        original_transaction: @transaction, pos_session: @session, actor: @admin,
        reason: "void", completion_idempotency_key: "pv-self-denied",
        approver: @admin, approver_pin: "1234"
      )
      refute result.success?
      assert_match(/approve_self/, result.error)
    end

    test "post-void clones discounts onto the reversing transaction" do
      open_sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: open_sale, product_variant: @variant, quantity: 2, actor: @admin)
      line = open_sale.pos_line_items.pending.first
      assert ApplyDiscount.call(
        pos_transaction: open_sale, scope: "line", method: "fixed_amount",
        pos_line_item: line, amount_cents: 100, actor: @admin
      ).success?
      assert ApplyDiscount.call(
        pos_transaction: open_sale, scope: "transaction", method: "fixed_amount",
        amount_cents: 50, actor: @admin
      ).success?
      net = RecalculateTransaction.call(pos_transaction: open_sale).net_total_cents
      AddCashTender.call(pos_transaction: open_sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: open_sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-disc"
      ).success?
      open_sale.reload
      original_discount_ids = open_sale.pos_discounts.pluck(:id)
      original_alloc_sum = PosDiscountAllocation.where(pos_discount_id: original_discount_ids).sum(:allocated_amount_cents)

      result = PostVoidTransaction.call(
        original_transaction: open_sale, pos_session: @session, actor: @admin,
        reason: "discounted void", completion_idempotency_key: "pv-disc",
        approver: @admin, approver_pin: "1234"
      )
      assert result.success?, result.error
      reversing = result.pos_transaction
      refute_empty reversing.pos_discounts
      reversing.pos_discounts.each do |discount|
        refute_includes original_discount_ids, discount.id
      end
      assert_equal original_alloc_sum,
                   PosDiscountAllocation.where(pos_discount_id: original_discount_ids).sum(:allocated_amount_cents)
      assert PosDiscountAllocation.where(pos_discount_id: reversing.pos_discounts.select(:id)).exists?
    end

    test "individual unit sale post-void restores unit availability" do
      unit_variant = product_variants(:signed_book_standard)
      unit = Inventory::CreateInventoryUnit.call(
        store: @store, product_variant: unit_variant, actor: @admin, acquisition_cost_cents: 1500
      ).inventory_unit
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: unit_variant, actor: @admin, inventory_unit: unit)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "unit-sale"
      ).success?
      assert_equal "sold", unit.reload.status

      result = PostVoidTransaction.call(
        original_transaction: txn, pos_session: @session, actor: @admin,
        reason: "unit void", completion_idempotency_key: "pv-unit",
        approver: @admin, approver_pin: "1234"
      )
      assert result.success?, result.error
      assert_equal "available", unit.reload.status
      assert_nil unit.sold_pos_line_item_id
    end

    test "concurrent post-void allows only one success" do
      results = {}
      barrier = Concurrent::CyclicBarrier.new(2)
      t1 = Thread.new do
        barrier.wait
        results[:a] = PostVoidTransaction.call(
          original_transaction: @transaction, pos_session: @session, actor: @admin,
          reason: "race a", completion_idempotency_key: "pv-race-a",
          approver: @admin, approver_pin: "1234"
        )
      end
      t2 = Thread.new do
        barrier.wait
        results[:b] = PostVoidTransaction.call(
          original_transaction: @transaction, pos_session: @session, actor: @admin,
          reason: "race b", completion_idempotency_key: "pv-race-b",
          approver: @admin, approver_pin: "1234"
        )
      end
      [ t1, t2 ].each(&:join)
      successes = results.values.count(&:success?)
      assert_equal 1, successes
      assert_equal 1, PosTransaction.where(reverses_pos_transaction_id: @transaction.id).count
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
