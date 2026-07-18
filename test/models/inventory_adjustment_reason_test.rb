# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentReasonTest < ActiveSupport::TestCase
  test "code is immutable after create" do
    reason = inventory_adjustment_reasons(:opening_initial)
    assert_raises(ActiveRecord::ReadonlyAttributeError) { reason.code = "changed" }
  end

  test "qualified code is derived" do
    reason = inventory_adjustment_reasons(:quantity_shortage)
    assert_equal "quantity_only.physical_count_shortage", reason.qualified_code
  end
end
