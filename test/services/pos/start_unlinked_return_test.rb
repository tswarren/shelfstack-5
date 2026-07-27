# frozen_string_literal: true

require "test_helper"

module Pos
  class StartUnlinkedReturnTest < ActiveSupport::TestCase
    include PosSetupHelper

    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @reason = return_reasons(:defective)
      pos_open_inventory(store: @store, variant: @variant, quantity: 2, unit_cost_cents: 500, actor: @admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: @device, drawer: @drawer, actor: @admin
      )
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      membership.update!(maximum_no_receipt_return_cents: 10_000_00)
    end

    test "opens transaction and adds unlinked return atomically" do
      assert_difference -> { PosTransaction.count }, 1 do
        assert_difference -> { PosLineItem.where(direction: "return").count }, 1 do
          result = StartUnlinkedReturn.call(
            pos_session: @session,
            actor: @admin,
            return_source: "no_receipt",
            return_reason: @reason,
            return_disposition: "return_to_stock",
            product_variant: @variant,
            unit_price_cents: @variant.regular_price_cents,
            quantity: 1,
            tax_basis: "current_configured_rules",
            confirm_cost_basis: true
          )
          assert result.success?, result.error
          assert result.pos_transaction.open?
          assert_equal "no_receipt", result.pos_line_item.return_source
        end
      end
    end

    test "failure leaves no empty transaction" do
      before = PosTransaction.open_transactions.where(active_pos_session: @session).count
      result = StartUnlinkedReturn.call(
        pos_session: @session,
        actor: @admin,
        return_source: "no_receipt",
        return_reason: @reason,
        return_disposition: "return_to_stock",
        product_variant: @variant,
        unit_price_cents: @variant.regular_price_cents,
        quantity: 1,
        tax_basis: "current_configured_rules",
        confirm_cost_basis: false
      )
      assert_not result.success?
      assert_equal before, PosTransaction.open_transactions.where(active_pos_session: @session).count
    end
  end
end
