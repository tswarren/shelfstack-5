# frozen_string_literal: true

require "test_helper"

module Catalog
  class TrackingModeGuardTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @variant = product_variants(:sample_book_standard)
    end

    test "blocks tracking mode change after stock balance exists" do
      StockBalance.create!(
        store: @store,
        product_variant: @variant,
        on_hand: 0,
        reserved: 0,
        unavailable: 0,
        inventory_value_cents: 0,
        cost_quality: "unknown"
      )

      result = UpdateVariant.call(
        variant: @variant,
        attributes: { inventory_tracking_mode: "none" },
        actor: @user,
        store: @store
      )

      refute result
      assert_includes @variant.errors[:inventory_tracking_mode].join, "cannot change"
      assert_equal "quantity", @variant.reload.inventory_tracking_mode
    end
  end
end
