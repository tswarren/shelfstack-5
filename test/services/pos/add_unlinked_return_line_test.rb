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
      @prior_balance = StockBalance.find_by!(store: @store, product_variant: @variant)
    end

    test "product unlinked return preserves known valuation with estimated MAC cost" do
      prior_value = @prior_balance.inventory_value_cents
      prior_mac = @prior_balance.moving_average_cost_cents
      assert prior_value.present?
      assert prior_mac.present?

      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "external_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: @variant.regular_price_cents,
        tax_basis: "current_configured_rules",
        confirm_cost_basis: true
      )
      assert result.success?, result.error
      line = result.pos_line_item
      assert_equal "return", line.direction
      assert_equal "external_receipt", line.return_source
      assert_equal "current_configured_rules", line.tax_basis_snapshot
      assert_equal "moving_average", line.cost_method_snapshot
      assert_equal "estimated", line.cost_quality_snapshot
      assert_equal prior_mac, line.cost_unit_cost_cents
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
      assert balance.inventory_value_cents.present?
      assert balance.moving_average_cost_cents.present?
      assert_includes %w[actual estimated mixed], balance.cost_quality
      refute_equal "unknown", balance.cost_quality
    end

    test "external receipt tax basis uses explicit tax amount" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "external_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "external_receipt_tax",
        explicit_tax_amount_cents: 75
      )
      assert result.success?, result.error
      assert_equal "external_receipt_tax", result.pos_line_item.tax_basis_snapshot
      assert_equal 75, result.pos_line_item.explicit_tax_amount_cents
      assert_equal 75, result.pos_line_item.pos_line_item_taxes.sum(:amount_cents)
    end

    test "blocks inventory-affecting return without cost confirmation" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "gift_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 100,
        confirm_cost_basis: false
      )
      refute result.success?
      assert_match(/confirm the proposed inventory cost/i, result.error)
    end

    test "discard restores pre-return on_hand and inventory value" do
      prior_on_hand = @prior_balance.on_hand
      prior_value = @prior_balance.inventory_value_cents

      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "gift_receipt",
        return_reason: @reason,
        return_disposition: "discard",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: @variant.regular_price_cents,
        confirm_cost_basis: true
      )
      assert result.success?, result.error

      net = RecalculateTransaction.call(pos_transaction: @txn).net_total_cents
      refund = pos_add_cash_refund(pos_transaction: @txn, amount_cents: -net, actor: @admin)
      assert refund.success?, refund.error
      assert CompleteTransaction.call(
        pos_transaction: @txn, pos_session: @session, actor: @admin,
        completion_idempotency_key: "unlinked-discard-1"
      ).success?

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal prior_on_hand, balance.on_hand
      assert_equal prior_value, balance.inventory_value_cents
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

    test "no_receipt approval rolls back with failed line create" do
      RolePermission.find_or_create_by!(
        role: roles(:administrator),
        permission: permissions(:pos_return_no_receipt)
      )
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      membership.update!(maximum_no_receipt_return_cents: 10_000_00)

      before_approvals = PosApproval.count
      denied = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 100,
        confirm_cost_basis: false
      )
      refute denied.success?
      assert_equal before_approvals, PosApproval.count
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
        unit_price_cents: 100,
        confirm_cost_basis: true
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
        unit_price_cents: 100,
        confirm_cost_basis: true
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
        unit_price_cents: 1000,
        confirm_cost_basis: true
      )
      refute result.success?
      assert_match(/linked return/i, result.error)
    end
  end
end
