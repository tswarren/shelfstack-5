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

  test "pos_original_card_tender_option_label includes receipt and terminal refs" do
    Current.store = stores(:main_street)
    txn = PosTransaction.new(
      receipt_number: "MAIN-000042",
      completed_at: Time.zone.parse("2026-07-22 15:30")
    )
    tender = PosTender.new(
      amount_cents: 1599,
      authorization_code: "AUTH-42",
      terminal_reference: "TERM-9",
      pos_transaction: txn,
      tender_type: tender_types(:card_standalone)
    )
    tender.define_singleton_method(:remaining_refundable_cents) { 1599 }

    label = pos_original_card_tender_option_label(tender)
    assert_includes label, "MAIN-000042"
    assert_includes label, "AUTH-42"
    assert_includes label, "TERM-9"
  ensure
    Current.store = nil
  end

  test "pos_receipt_discount_label prefers reason then percentage" do
    reason = DiscountReason.new(name: "Member discount")
    with_reason = PosDiscount.new(method: "percentage", rate_bps: 1000, discount_reason: reason)
    assert_equal "Member discount", pos_receipt_discount_label(with_reason)

    percentage = PosDiscount.new(method: "percentage", rate_bps: 1500)
    assert_equal "Discount 15%", pos_receipt_discount_label(percentage)
  end

  test "pos_masked_tender_reference masks long auth and terminal tokens" do
    tender = PosTender.new(
      authorization_code: "AUTH-123456",
      terminal_reference: "TERM-9876"
    )

    masked = pos_masked_tender_reference(tender)
    assert_match(/Auth .+3456/, masked)
    assert_match(/Term .+9876/, masked)
    refute_includes masked, "AUTH-123456"
  end

  test "pos_masked_tender_reference explains missing references" do
    assert_equal "No external reference recorded",
                 pos_masked_tender_reference(PosTender.new)
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
