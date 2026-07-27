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
            confirm_cost_basis: true,
            reviewed_cost_unit_cents: StockBalance.find_by!(store: @store, product_variant: @variant).moving_average_cost_cents,
            reviewed_cost_source: "store_stock_balance_mac"
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

    test "does not open a transaction without pos.transaction.open" do
      cashier = create_limited_actor(%w[pos.access pos.return.create pos.return.no_receipt])
      membership = StoreMembership.find_by!(user: cashier, store: @store)
      membership.update!(maximum_no_receipt_return_cents: 10_000_00)

      assert_no_difference -> { PosTransaction.count } do
        assert_no_difference -> { PosLineItem.count } do
          result = StartUnlinkedReturn.call(
            pos_session: @session,
            actor: cashier,
            return_source: "no_receipt",
            return_reason: @reason,
            return_disposition: "non_inventory",
            product_variant: @variant,
            unit_price_cents: 100,
            quantity: 1,
            tax_basis: "current_configured_rules",
            confirm_cost_basis: false
          )
          assert_not result.success?
          assert_match(/pos\.transaction\.open/i, result.error)
        end
      end
    end

    private

    def create_limited_actor(permission_codes)
      username = "cashier_#{SecureRandom.hex(2)}"
      user = User.create!(
        username: username,
        user_number: rand(10_000..99_999),
        first_name: "Cash", last_name: "Ier",
        password: "password123",
        active: true, default_store: @store
      )
      role = Role.create!(
        organization: @store.organization,
        code: "role_#{username}",
        name: "Role #{username}",
        active: true
      )
      permission_codes.each do |code|
        RolePermission.create!(role: role, permission: Permission.find_by!(code: code))
      end
      StoreMembership.create!(user: user, store: @store, role: role, active: true)
      user
    end
  end
end
