# frozen_string_literal: true

require "test_helper"

module Pos
  # Phase 4g-1: completed snapshots survive master-data edits.
  class CompletedTransactionHistoricalSnapshotsTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @product = @variant.product
      @cash = tender_types(:cash)
      @department = departments(:books_new)

      pos_open_inventory(
        store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin
      )
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      @transaction, @line, _net = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "hist-sale"
      )
      @line_snapshot = {
        description_snapshot: @line.description_snapshot,
        department_id: @line.department_id,
        tax_category_id: @line.tax_category_id,
        unit_price_cents: @line.unit_price_cents,
        tax_amount_cents: @line.tax_amount_cents,
        cost_unit_cost_cents: @line.cost_unit_cost_cents,
        cost_extended_cents: @line.cost_extended_cents,
        cost_method_snapshot: @line.cost_method_snapshot
      }
      @tax_snapshots = @line.pos_line_item_taxes.order(:position).map { |t|
        [ t.receipt_code_snapshot, t.amount_cents, t.rate.to_s, t.treatment_snapshot ]
      }
      @tender = @transaction.pos_tenders.sole
      @tender_snapshot = {
        amount_cents: @tender.amount_cents,
        tender_type_id: @tender.tender_type_id
      }
    end

    test "renaming product department tax and tender type does not change completed snapshots" do
      @product.update!(name: "Renamed After Sale")
      @department.update!(name: "Renamed Department")
      tax_categories(:physical_book).update!(name: "Renamed Tax Category")
      @cash.update!(name: "Renamed Cash")
      # Current inventory cost may change; completed line cost snapshots must not.
      InventoryLedgerEntry.where(store: @store, product_variant: @variant).update_all(unit_cost_cents: 9999)

      @line.reload
      @tender.reload
      assert_nil @line.description_snapshot
      assert_equal @line_snapshot[:department_id], @line.department_id
      assert_equal @line_snapshot[:tax_category_id], @line.tax_category_id
      assert_equal @line_snapshot[:unit_price_cents], @line.unit_price_cents
      assert_equal @line_snapshot[:tax_amount_cents], @line.tax_amount_cents
      assert_equal @line_snapshot[:cost_unit_cost_cents], @line.cost_unit_cost_cents
      assert_equal @line_snapshot[:cost_extended_cents], @line.cost_extended_cents
      assert_equal @line_snapshot[:cost_method_snapshot], @line.cost_method_snapshot
      assert_equal @tax_snapshots, @line.pos_line_item_taxes.order(:position).map { |t|
        [ t.receipt_code_snapshot, t.amount_cents, t.rate.to_s, t.treatment_snapshot ]
      }
      assert_equal @tender_snapshot[:amount_cents], @tender.amount_cents
      assert_equal @tender_snapshot[:tender_type_id], @tender.tender_type_id
    end
  end
end
