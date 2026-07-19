# frozen_string_literal: true

require "test_helper"

module Pos
  class ApplyDiscountTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @department = departments(:books_new)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "transaction-scoped percentage discount allocates proportionally and defaults to reduces_taxable_base" do
      line_a = add_open_ring_line(1000)
      line_b = add_open_ring_line(2000)

      result = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "transaction", method: "percentage",
        rate_bps: 1000, actor: @admin
      )

      assert result.success?
      assert_equal "reduces_taxable_base", result.pos_discount.tax_treatment
      assert_equal 300, result.pos_discount.applied_amount_cents

      allocations = result.pos_discount.pos_discount_allocations.index_by(&:pos_line_item_id)
      assert_equal 100, allocations.fetch(line_a.id).allocated_amount_cents
      assert_equal 200, allocations.fetch(line_b.id).allocated_amount_cents
      assert_equal 300, allocations.values.sum(&:allocated_amount_cents)
    end

    test "allocation totals always equal the applied amount even with uneven rounding" do
      line_a = add_open_ring_line(1000)
      line_b = add_open_ring_line(1000)
      line_c = add_open_ring_line(1001)

      result = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "transaction", method: "percentage",
        rate_bps: 1000, actor: @admin
      )

      assert result.success?
      assert_equal 300, result.pos_discount.applied_amount_cents
      allocations = result.pos_discount.pos_discount_allocations
      assert_equal 300, allocations.sum(&:allocated_amount_cents)
      assert_equal [ line_a.id, line_b.id, line_c.id ].sort, allocations.map(&:pos_line_item_id).sort
    end

    test "line-scoped fixed_amount discount allocates entirely to the target line" do
      line_a = add_open_ring_line(1000)
      add_open_ring_line(2000)

      result = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line_a, method: "fixed_amount",
        amount_cents: 250, actor: @admin
      )

      assert result.success?
      assert_equal 250, result.pos_discount.applied_amount_cents
      assert_equal [ line_a.id ], result.pos_discount.pos_discount_allocations.map(&:pos_line_item_id)
    end

    test "does_not_reduce_taxable_base discount leaves the taxable base untouched" do
      line_a = add_open_ring_line(1000)

      result = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line_a, method: "fixed_amount",
        amount_cents: 500, tax_treatment: "does_not_reduce_taxable_base", actor: @admin
      )

      assert result.success?
      assert_equal "does_not_reduce_taxable_base", result.pos_discount.tax_treatment

      tax_row = PosLineItemTax.find_by(pos_line_item: line_a)
      assert_equal 1000, tax_row.taxable_amount_cents
      assert_equal 130, tax_row.amount_cents
    end

    test "discount beyond requester authority requires an independent approver" do
      line_a = add_open_ring_line(10_000)

      no_approver = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line_a, method: "percentage",
        rate_bps: 500, actor: @clerk
      )
      refute no_approver.success?
      assert_match(/authority/, no_approver.error)

      approved = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line_a, method: "percentage",
        rate_bps: 500, actor: @clerk, approver: @admin, approver_pin: "1234", reason: "manager override"
      )

      assert approved.success?
      assert approved.pos_approval.present?
      assert_equal @clerk, approved.pos_approval.requested_by_user
      assert_equal @admin, approved.pos_approval.approved_by_user
      assert_equal "discount_apply", approved.pos_approval.action_type
    end

    test "stacked discounts cannot exceed remaining line gross" do
      line = add_open_ring_line(1000)

      first = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line, method: "fixed_amount",
        amount_cents: 600, actor: @admin
      )
      assert first.success?

      second = ApplyDiscount.call(
        pos_transaction: @transaction, scope: "line", pos_line_item: line, method: "fixed_amount",
        amount_cents: 600, actor: @admin
      )
      assert second.success?
      assert_equal 400, second.pos_discount.applied_amount_cents
      assert_equal 1000, PosDiscountAllocation.where(pos_line_item: line).sum(:allocated_amount_cents)

      totals = RecalculateTransaction.call(pos_transaction: @transaction)
      assert totals.success?
      assert totals.net_total_cents >= 0
    end

    private

    def add_open_ring_line(unit_price_cents)
      AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department, unit_price_cents: unit_price_cents, actor: @admin
      ).pos_line_item
    end
  end
end
