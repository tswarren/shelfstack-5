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
                        "expected #{component[:label]} to be negative, got #{component[:amount_cents]}"
      end
      assert_equal reversing.tax_total_cents, facts.tax_components.sum { |c| c[:amount_cents] }
    end

    test "sale tax components remain positive" do
      txn, = pos_complete_cash_sale(
        session: @session, variant: @variant, quantity: 1, actor: @admin,
        cash: @cash, key: "facts-tax-sale-only"
      )
      facts = ReceiptDocumentFacts.call(pos_transaction: txn, store: @store, reprint: true)
      assert facts.tax_components.any?
      facts.tax_components.each do |component|
        assert_operator component[:amount_cents], :>, 0
      end
      assert_equal txn.tax_total_cents, facts.tax_components.sum { |c| c[:amount_cents] }
    end
  end
end
