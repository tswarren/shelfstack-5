# frozen_string_literal: true

require "test_helper"

class PosHelperTest < ActionView::TestCase
  include ApplicationHelper
  include PosHelper

  test "pos_money delegates to format_money for store currency" do
    store = stores(:main_street)
    store.update!(currency_code: "CAD")
    Current.store = store

    assert_equal format_money(2500), pos_money(2500)
    assert_includes pos_money(2500), "CA$"
  ensure
    Current.store = nil
  end
end
