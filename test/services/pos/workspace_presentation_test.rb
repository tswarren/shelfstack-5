# frozen_string_literal: true

require "test_helper"

module Pos
  class WorkspacePresentationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
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
    end

    test "ready when no transaction" do
      result = WorkspacePresentation.for(pos_transaction: nil, open_session: @session)
      assert_equal "ready", result.state
    end

    test "forces tender when unresolved tenders exist" do
      txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, actor: @admin, quantity: 1)
      AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: 100, actor: @admin
      )

      result = WorkspacePresentation.for(
        pos_transaction: txn.reload,
        presentation_param: nil,
        net_total_cents: 1000,
        balance_due_cents: 900
      )
      assert_equal "tender", result.state
      assert result.forced_tender
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
