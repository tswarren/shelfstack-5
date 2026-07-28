# frozen_string_literal: true

require "test_helper"

module Pos
  class ReceiptDocumentFactsTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      pos_open_inventory(store: @store, variant: @variant, quantity: 5, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
    end

    test "return and post-void tax components are signed negative" do
      original, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "facts-tax-sale"
      )
      assert_operator original.tax_total_cents, :>, 0

      result = pos_post_void!(
        original: original, actor: @admin, reason: "tax sign",
        pos_session: @session, key: "facts-tax-void"
      )
      assert result.success?, result.error
      reversing = result.pos_transaction
      assert_operator reversing.tax_total_cents, :<, 0

      facts = ReceiptDocumentFacts.call(pos_transaction: reversing, store: @store, reprint: true)
      assert facts.tax_components.any?
      facts.tax_components.each do |component|
        assert_operator component[:amount_cents], :<, 0,
                        "expected #{component[:code]} amount to be negative, got #{component[:amount_cents]}"
        assert_operator component[:taxable_amount_cents], :<, 0,
                        "expected #{component[:code]} taxable to be negative"
      end
      assert_equal reversing.tax_total_cents, facts.tax_components.sum { |c| c[:amount_cents] }
    end

    test "sale tax components include code rate taxable markers and legend" do
      txn, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "facts-tax-sale-only"
      )
      facts = ReceiptDocumentFacts.call(pos_transaction: txn, store: @store, reprint: true)
      assert facts.tax_components.any?

      component = facts.tax_components.first
      assert component[:code].present?
      assert component[:rate].present?
      assert_operator component[:taxable_amount_cents], :>, 0
      assert_operator component[:amount_cents], :>, 0
      assert_equal txn.tax_total_cents, facts.tax_components.sum { |c| c[:amount_cents] }

      line = txn.pos_line_items.where(status: "completed").first
      markers = facts.tax_markers_by_line_id.fetch(line.id)
      assert_includes markers, component[:code]

      legend = facts.tax_legend.find { |entry| entry[:code] == component[:code] }
      assert legend.present?
      assert_equal store_tax_rates(:gst_13).name, legend[:name]
      assert_equal store_tax_rates(:gst_13).name, component[:name]

      assert_equal line.extended_price_cents, facts.merchandise_cents
      assert_equal 0, facts.refund_cents
      assert_equal 0, facts.non_merchandise_cents
      assert_equal facts.merchandise_cents, facts.subtotal_cents
      assert_equal 1, facts.items_sold_count
      assert_equal 0, facts.items_returned_count
    end

    test "cashier label prefers first and last name" do
      @admin.update!(first_name: "Jane", last_name: "Cashier")
      txn, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 2, actor: @admin,
        cash: @cash, key: "facts-cashier-name"
      )
      facts = ReceiptDocumentFacts.call(pos_transaction: txn, store: @store, reprint: true)
      assert_equal "Jane Cashier", facts.cashier_label
      assert_equal 2, facts.items_sold_count
    end

    test "total savings reflects sale discounts and SV redeem shows remaining balance" do
      IdentifierSequence.ensure_defaults!
      account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      StoredValue::PostEntry.call(
        account: account, store: @store, entry_type: "issued", amount_cents: 10_000,
        posting_key: "facts-sv-seed", actor: @admin
      )
      sv_tender = tender_types(:stored_value)

      txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      added = Pos::AddLine.call(
        pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin
      )
      assert added.success?
      line = added.pos_line_item
      assert Pos::ApplyDiscount.call(
        pos_transaction: txn, scope: "line", pos_line_item: line,
        method: "fixed_amount", amount_cents: 200, actor: @admin
      ).success?

      net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      assert Pos::AddStoredValueTender.call(
        pos_transaction: txn, tender_type: sv_tender, account: account,
        amount_cents: net, actor: @admin
      ).success?
      assert Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "facts-savings-sv"
      ).success?

      facts = ReceiptDocumentFacts.call(pos_transaction: txn.reload, store: @store, reprint: true)
      assert_equal 200, facts.total_savings_cents
      tender = facts.tenders.find { |row| row.tender_type.tender_category == "stored_value" }
      assert tender.present?
      remaining = facts.stored_value_tender_details_by_tender_id.fetch(tender.id)[:remaining_balance_cents]
      assert_equal 10_000 - net, remaining
    end
  end
end
