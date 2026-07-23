# frozen_string_literal: true

require "test_helper"

module Pos
  class ProjectCompletionReadinessTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "projection does not write tax rows" do
      add = AddLine.call(pos_transaction: @transaction, product_variant: @variant, actor: @admin, quantity: 1)
      assert add.success?, add.error

      tax_count_before = PosLineItemTax.where(pos_line_item_id: @transaction.pos_line_items.select(:id)).count
      updated_at_before = @transaction.pos_line_items.pending.order(:id).pluck(:id, :updated_at)

      result = ProjectCompletionReadiness.call(pos_transaction: @transaction)
      assert result.ready_for_tender?

      tax_count_after = PosLineItemTax.where(pos_line_item_id: @transaction.pos_line_items.select(:id)).count
      assert_equal tax_count_before, tax_count_after
      assert_equal updated_at_before, @transaction.pos_line_items.pending.order(:id).pluck(:id, :updated_at)
    end

    test "empty transaction is not ready for tender" do
      result = ProjectCompletionReadiness.call(pos_transaction: @transaction)
      assert_not result.ready_for_tender?
      assert result.blockers.any? { |i| i.code == "no_lines" }
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
