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

  test "pos_discount_summary labels fixed-amount method without repeating the amount" do
    discount = PosDiscount.new(
      method: "fixed_amount",
      applied_amount_cents: 200,
      rate_bps: nil,
      requested_amount_cents: nil
    )
    Current.store = stores(:main_street)

    summary = pos_discount_summary(discount)
    assert_match(/\AFixed amount · /, summary)
    assert_equal 1, summary.scan(pos_money(200)).size
  ensure
    Current.store = nil
  end
end
