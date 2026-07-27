# frozen_string_literal: true

require "test_helper"

module Pos
  class StartPickupTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session

      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 5000, moving_average_cost_cents: 1000, cost_quality: "actual"
      )
      @request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product,
        product_variant: @variant, requested_quantity: 2, requested_by_user: @admin,
        customer: customers(:jordan_lee)
      )
    end

    test "opens a transaction and adds a linked pickup line" do
      result = StartPickup.call(
        pos_session: @session, actor: @admin, product_request: @request, quantity: 1
      )

      assert result.success?, result.error
      assert result.pos_transaction.open?
      line = result.pos_line_item
      assert_equal @variant, line.product_variant
      assert_equal @request, line.product_request
      assert_equal 1, line.quantity
    end

    test "failed pickup leaves no empty open transaction" do
      assert_no_difference -> { PosTransaction.count } do
        result = StartPickup.call(
          pos_session: @session, actor: @admin, product_request: @request, quantity: 99
        )
        refute result.success?
        assert_match(/outstanding/i, result.error)
      end
    end

    test "rejects staff suggestions" do
      staff = product_requests(:open_staff_suggestion)
      result = StartPickup.call(
        pos_session: @session, actor: @admin, product_request: staff, quantity: 1
      )
      refute result.success?
      assert_match(/open customer request/i, result.error)
    end
  end
end
