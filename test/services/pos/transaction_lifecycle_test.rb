# frozen_string_literal: true

require "test_helper"

module Pos
  class TransactionLifecycleTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device_a = pos_devices(:register_1)
      @device_b = PosDevice.create!(store: @store, code: "REG2", name: "Register 2", device_type: "register", active: true)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @none_variant = product_variants(:gift_wrap_service_standard)
      @department = departments(:books_new)

      opening = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening,
        product_variant: @variant,
        position: 0,
        quantity_delta: 10,
        input_unit_cost_cents: 500,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session_a = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device_a, cash_drawer: @drawer, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "add product line on quantity-tracked variant reserves inventory" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      result = AddLine.call(pos_transaction: transaction, product_variant: @variant, quantity: 2, actor: @admin)

      assert result.success?
      assert_empty result.warnings
      reservation = InventoryReservation.active.find_by(source_type: "pos_line_item", source_id: result.pos_line_item.id)
      assert reservation
      assert_equal 2, reservation.quantity
      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal 2, balance.reserved
    end

    test "add product line on none-tracked variant creates no reservation" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      result = AddLine.call(pos_transaction: transaction, product_variant: @none_variant, quantity: 1, actor: @admin)

      assert result.success?
      assert_nil InventoryReservation.find_by(source_type: "pos_line_item", source_id: result.pos_line_item.id)
      assert_equal "none", result.pos_line_item.product_variant.inventory_tracking_mode
    end

    test "update line qty re-reserves in place" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: transaction, product_variant: @variant, quantity: 2, actor: @admin).pos_line_item

      result = UpdateLineQty.call(pos_line_item: line, quantity: 5, actor: @admin)
      assert result.success?
      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal 5, balance.reserved
      assert_equal 1, InventoryReservation.where(source_type: "pos_line_item", source_id: line.id).count
    end

    test "remove line soft-removes and releases reservation" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: transaction, product_variant: @variant, quantity: 3, actor: @admin).pos_line_item

      result = RemoveLine.call(pos_line_item: line, actor: @admin, reason: "customer changed mind")
      assert result.success?
      line.reload
      assert_equal "removed", line.status
      assert line.removed_at.present?
      assert_equal @admin, line.removed_by_user

      assert PosLineItem.exists?(id: line.id)
      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal 0, balance.reserved
      assert_equal "released", InventoryReservation.find_by(source_type: "pos_line_item", source_id: line.id).status
    end

    test "open-ring line effective description defaults to department name when blank" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      result = AddOpenRingLine.call(
        pos_transaction: transaction, department: @department, unit_price_cents: 1500, actor: @admin
      )

      assert result.success?
      line = result.pos_line_item
      assert_equal @department.name, line.description_snapshot
      assert_equal @department.name, line.effective_description
      assert_equal @department.default_tax_category, line.tax_category
      assert_nil line.product_variant
    end

    test "open-ring line keeps explicit description when provided" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      result = AddOpenRingLine.call(
        pos_transaction: transaction, department: @department, unit_price_cents: 500,
        description: "Gift wrapping", actor: @admin
      )

      assert result.success?
      assert_equal "Gift wrapping", result.pos_line_item.description_snapshot
    end

    test "cancel releases reservations for pending product lines" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: transaction, product_variant: @variant, quantity: 4, actor: @admin).pos_line_item

      result = CancelTransaction.call(pos_transaction: transaction, actor: @admin, reason: "test cancel")
      assert result.success?
      transaction.reload
      assert transaction.cancelled?

      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal 0, balance.reserved
      assert_equal "released", InventoryReservation.find_by(source_type: "pos_line_item", source_id: line.id).status
    end

    test "suspend in session A, close A, open B, recall in B" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction
      line = AddLine.call(pos_transaction: transaction, product_variant: @variant, quantity: 1, actor: @admin).pos_line_item

      suspend_result = SuspendTransaction.call(pos_transaction: transaction, actor: @admin)
      assert suspend_result.success?
      transaction.reload
      assert transaction.suspended?
      assert_nil transaction.active_pos_session_id

      close_result = CloseSession.call(pos_session: @session_a, actor: @admin)
      assert close_result.success?

      session_b = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device_b, cashier: @admin, actor: @admin
      ).pos_session

      recall_result = RecallTransaction.call(pos_transaction: transaction, pos_session: session_b, actor: @admin)
      assert recall_result.success?
      transaction.reload
      assert transaction.open?
      assert_equal session_b.id, transaction.active_pos_session_id
      assert_equal @session_a.id, transaction.origin_pos_session_id

      # Reservation survived suspension and the session hop.
      balance = StockBalance.find_by(store: @store, product_variant: @variant)
      assert_equal 1, balance.reserved
      assert InventoryReservation.active.exists?(source_type: "pos_line_item", source_id: line.id)
    end

    test "recalling a non-suspended transaction fails" do
      transaction = OpenTransaction.call(pos_session: @session_a, actor: @admin).pos_transaction

      result = RecallTransaction.call(pos_transaction: transaction, pos_session: @session_a, actor: @admin)
      refute result.success?
      assert_match(/suspended/, result.error)
    end
  end
end
