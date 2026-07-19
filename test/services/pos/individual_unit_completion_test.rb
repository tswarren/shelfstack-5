# frozen_string_literal: true

require "test_helper"

module Pos
  class IndividualUnitCompletionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:signed_book_standard)
      @cash = tender_types(:cash)

      @unit = Inventory::CreateInventoryUnit.call(
        store: @store, product_variant: @variant, actor: @admin, acquisition_cost_cents: 1500
      ).inventory_unit

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "adding an individually tracked line reserves the exact unit" do
      result = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, actor: @admin, inventory_unit: @unit
      )

      assert result.success?, result.error
      assert_equal @unit, result.pos_line_item.inventory_unit
      assert_equal "reserved", @unit.reload.status
      reservation = InventoryReservation.active.find_by(inventory_unit_id: @unit.id)
      assert reservation
      assert_equal "pos_line_item", reservation.source_type
      assert_equal result.pos_line_item.id, reservation.source_id
    end

    test "adding an individually tracked line without a unit fails" do
      result = AddLine.call(pos_transaction: @transaction, product_variant: @variant, actor: @admin)

      refute result.success?
      assert_match(/exact inventory unit is required/, result.error)
    end

    test "adding an already-reserved unit to a second line fails" do
      AddLine.call(pos_transaction: @transaction, product_variant: @variant, actor: @admin, inventory_unit: @unit)

      other_transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      result = AddLine.call(
        pos_transaction: other_transaction, product_variant: @variant, actor: @admin, inventory_unit: @unit
      )

      refute result.success?
      assert_match(/already reserved|not available/, result.error)
    end

    test "updating quantity on an individually tracked line is rejected" do
      line = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, actor: @admin, inventory_unit: @unit
      ).pos_line_item

      result = UpdateLineQty.call(pos_line_item: line, quantity: 2, actor: @admin)

      refute result.success?
      assert_match(/quantity is fixed at 1/, result.error)
    end

    test "exact-unit sale completes and marks the unit sold" do
      line = AddLine.call(
        pos_transaction: @transaction, product_variant: @variant, actor: @admin, inventory_unit: @unit
      ).pos_line_item

      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin)

      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "unit-sale-1"
      )

      assert result.success?, result.error

      @unit.reload
      assert @unit.sold?
      assert @unit.sold_at.present?

      line.reload
      assert line.completed?
      assert_equal 1500, line.cost_unit_cost_cents
      assert_equal 1500, line.cost_extended_cents
      assert_equal "explicit", line.cost_method_snapshot
      assert_equal "actual", line.cost_quality_snapshot

      reservation = InventoryReservation.find_by(inventory_unit_id: @unit.id)
      assert_equal "converted", reservation.status

      assert AdministrativeAuditEvent.exists?(action: "inventory_unit.sold", subject_type: "InventoryUnit", subject_id: @unit.id)
    end

    test "repeating completion with the same idempotency key replays without re-selling the unit" do
      AddLine.call(pos_transaction: @transaction, product_variant: @variant, actor: @admin, inventory_unit: @unit)
      net_total = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net_total, actor: @admin)

      first = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "unit-double"
      )
      second = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "unit-double"
      )

      assert first.success?
      assert second.success?
      assert second.replayed
      assert @unit.reload.sold?
    end

    test "failed completion (tenders do not settle) leaves the unit reserved, not sold" do
      AddLine.call(pos_transaction: @transaction, product_variant: @variant, actor: @admin, inventory_unit: @unit)
      AddCashTender.call(pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 1, actor: @admin)

      result = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin, completion_idempotency_key: "unit-short-tender"
      )

      refute result.success?
      assert_equal "reserved", @unit.reload.status
    end
  end
end
