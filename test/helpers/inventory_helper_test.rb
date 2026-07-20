# frozen_string_literal: true

require "test_helper"

class InventoryHelperTest < ActionView::TestCase
  include ApplicationHelper
  include InventoryHelper

  test "inventory_money delegates to format_money for store currency" do
    store = stores(:main_street)
    store.update!(currency_code: "CAD")
    Current.store = store

    assert_equal format_money(199), inventory_money(199)
    assert_equal "unknown", inventory_money(nil, quality: "unknown")
  ensure
    Current.store = nil
  end
end
