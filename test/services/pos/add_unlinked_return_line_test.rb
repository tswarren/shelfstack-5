# frozen_string_literal: true

require "test_helper"

module Pos
  class AddUnlinkedReturnLineTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @reason = return_reasons(:defective)
      @department = departments(:books_new)

      pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      @txn = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "product unlinked return calculates tax basis and restores stock on complete" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "external_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: @variant.regular_price_cents
      )
      assert result.success?, result.error
      line = result.pos_line_item
      assert_equal "return", line.direction
      assert_equal "external_receipt", line.return_source
      assert_nil line.original_pos_line_item_id
      assert line.pos_line_item_taxes.sum(:amount_cents).positive?

      net = RecalculateTransaction.call(pos_transaction: @txn).net_total_cents
      assert net.negative?
      refund = pos_add_cash_refund(pos_transaction: @txn, amount_cents: -net, actor: @admin)
      assert refund.success?, refund.error

      complete = CompleteTransaction.call(
        pos_transaction: @txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "unlinked-ext-1"
      )
      assert complete.success?, complete.error

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 3, balance.on_hand
    end

    test "open-ring unlinked return completes without inventory posting" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "gift_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        department: @department,
        description: "Misc gift return",
        quantity: 1,
        unit_price_cents: 500
      )
      assert result.success?, result.error
      assert_equal "open_ring", result.pos_line_item.line_kind
      assert_equal "Misc gift return", result.pos_line_item.description_snapshot

      net = RecalculateTransaction.call(pos_transaction: @txn).net_total_cents
      refund = pos_add_cash_refund(pos_transaction: @txn, amount_cents: -net, actor: @admin)
      assert refund.success?, refund.error
      complete = CompleteTransaction.call(
        pos_transaction: @txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "unlinked-gift-1"
      )
      assert complete.success?, complete.error
    end

    test "no_receipt source requires pos.return.no_receipt permission and authority" do
      denied = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 100
      )
      refute denied.success?
      assert_match(/pos\.return\.no_receipt/, denied.error)

      RolePermission.find_or_create_by!(
        role: roles(:administrator),
        permission: permissions(:pos_return_no_receipt)
      )
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      membership.update!(maximum_no_receipt_return_cents: 10_000_00)

      allowed = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 100
      )
      assert allowed.success?, allowed.error
      assert_equal "no_receipt", allowed.pos_line_item.return_source
    end

    test "rejects individually tracked variants without a linked original" do
      unit_variant = product_variants(:signed_book_standard)

      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "external_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: unit_variant,
        quantity: 1,
        unit_price_cents: 1000
      )
      refute result.success?
      assert_match(/linked return/i, result.error)
    end
  end
end
