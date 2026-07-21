# frozen_string_literal: true

require "test_helper"

module Purchasing
  class OnOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @variant = product_variants(:sample_book_standard)
    end

    test "sums open quantity across ordered purchase orders only" do
      assert_equal 5, OnOrder.call(store: @store, product_variant: @variant)
    end

    test "draft purchase orders do not contribute to on_order" do
      purchase_orders(:draft_po)
      assert_equal 5, OnOrder.call(store: @store, product_variant: @variant)
    end

    test "cancelled quantity reduces on_order" do
      line = purchase_order_lines(:ordered_po_line1)
      line.update!(cancelled_quantity: 2)
      assert_equal 3, OnOrder.call(store: @store, product_variant: @variant)
    end

    test "closed purchase orders do not contribute to on_order" do
      po = purchase_orders(:ordered_po)
      line = purchase_order_lines(:ordered_po_line1)
      line.update!(cancelled_quantity: line.ordered_quantity)
      po.update!(status: "closed", closed_at: Time.current, closed_by_user: users(:admin))
      assert_equal 0, OnOrder.call(store: @store, product_variant: @variant)
    end
  end
end
