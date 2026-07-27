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
        **reviewed_mac_cost
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

    test "configured tax basis ignores leftover explicit tax field values" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "gift_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "current_configured_rules",
        explicit_tax_amount_cents: 0
      )
      assert result.success?, result.error
      assert_equal "current_configured_rules", result.pos_line_item.tax_basis_snapshot
      assert_nil result.pos_line_item.explicit_tax_amount_cents
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

    test "rejects unlinked discard disposition for MVP" do
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
      refute result.success?
      assert_match(/discard is not available/i, result.error)
    end

    test "rejects confirm_cost_basis without reviewed proposal facts" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "gift_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: @variant.regular_price_cents,
        confirm_cost_basis: true
      )
      refute result.success?
      assert_match(/reviewed inventory cost/i, result.error)
    end

    test "rejects stale reviewed cost proposal" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "gift_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: @variant.regular_price_cents,
        confirm_cost_basis: true,
        reviewed_cost_unit_cents: 1,
        reviewed_cost_source: "store_stock_balance_mac"
      )
      refute result.success?
      assert_match(/cost basis changed/i, result.error)
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
      RolePermission.where(
        role: roles(:administrator),
        permission: permissions(:pos_return_no_receipt)
      ).delete_all
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      membership.update!(maximum_no_receipt_return_cents: nil)

      denied = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 100,
        **reviewed_mac_cost
      )
      refute denied.success?
      assert_match(/pos\.return\.no_receipt|permission|approval/i, denied.error)

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
        **reviewed_mac_cost
      )
      assert allowed.success?, allowed.error
      assert_equal "no_receipt", allowed.pos_line_item.return_source
    end

    test "no_receipt authority accumulates pending lines in the transaction" do
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      membership.update!(maximum_no_receipt_return_cents: 1500)

      first = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "no_tax_refund",
        confirm_cost_basis: false
      )
      assert first.success?, first.error

      second = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "no_tax_refund",
        confirm_cost_basis: false
      )
      refute second.success?
      assert_match(/approval|authority|exceed/i, second.error)
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
        **reviewed_mac_cost
      )
      refute result.success?
      assert_match(/linked return/i, result.error)
    end

    test "rejects external_receipt_tax for no_receipt source" do
      result = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "external_receipt_tax",
        explicit_tax_amount_cents: 100,
        confirm_cost_basis: false
      )
      refute result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "no_receipt authority includes refunded tax" do
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      membership.update!(maximum_no_receipt_return_cents: 1000)

      denied = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "current_configured_rules",
        confirm_cost_basis: false
      )
      refute denied.success?
      assert_match(/approval|authority|exceed/i, denied.error)

      membership.update!(maximum_no_receipt_return_cents: 10_000_00)
      allowed = AddUnlinkedReturnLine.call(
        pos_transaction: @txn,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "non_inventory",
        actor: @admin,
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        tax_basis: "current_configured_rules",
        confirm_cost_basis: false
      )
      assert allowed.success?, allowed.error
      tax = allowed.pos_line_item.pos_line_item_taxes.sum(:amount_cents)
      assert tax.positive?, "expected configured return tax so authority includes tax"
    end

    private

    def reviewed_mac_cost
      proposal = ProposeUnlinkedReturnCost.call(store: @store, product_variant: @variant)
      assert proposal.available?, proposal.error
      {
        confirm_cost_basis: true,
        reviewed_cost_unit_cents: proposal.unit_cost_cents,
        reviewed_cost_source: proposal.source
      }
    end
  end
end
