# frozen_string_literal: true

require "test_helper"

module Tax
  class CalculateTransactionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @completion_date = Date.new(2026, 8, 1)
    end

    test "aggregates three $0.05 lines at 13% into two cents using largest remainder, not three" do
      category = tax_categories(:physical_book)
      lines = [
        { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 5, position: 0 },
        { id: 2, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 5, position: 1 },
        { id: 3, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 5, position: 2 }
      ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      assert result.success?
      amounts = result.lines.sort_by(&:line_id).map(&:tax_amount_cents)
      assert_equal [ 1, 1, 0 ], amounts
      assert_equal 2, result.total_tax_cents_by_direction["sale"]
    end

    test "compounding component taxes the merchandise amount plus finalized prior tax" do
      category = tax_categories(:imported_gift)
      lines = [
        { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1000, position: 0 }
      ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      assert result.success?
      line = result.lines.first
      gst_component = line.components.find { |c| c.component_code == "GST13" }
      pst_component = line.components.find { |c| c.component_code == "PST7" }

      # GST: 1000 * 0.13 = 130.00 exact -> 130 cents.
      assert_equal 130, gst_component.amount_cents
      # PST compounds on (allocated taxable amount 1000) + (finalized GST 130) = 1130 * 0.07 = 79.1 -> 79 cents.
      assert_equal 79, pst_component.amount_cents
      assert_equal 209, line.tax_amount_cents
    end

    test "taxable fraction reduces the taxable base before rounding and allocation" do
      category = tax_categories(:mixed_use_item)
      lines = [
        { id: "a", tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 999, position: 0 },
        { id: "b", tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1, position: 1 }
      ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      assert result.success?
      line_a = result.lines.find { |l| l.line_id == "a" }
      line_b = result.lines.find { |l| l.line_id == "b" }

      # taxable base: 999*0.5=499.5, 1*0.5=0.5; sum 500.0 -> 500; tie broken by position -> line a gets the cent.
      assert_equal 500, line_a.components.first.taxable_amount_cents
      assert_equal 0, line_b.components.first.taxable_amount_cents
      # tax: 500*0.13=65.0 -> 65 all to line a.
      assert_equal 65, line_a.tax_amount_cents
      assert_equal 0, line_b.tax_amount_cents
    end

    test "sale and return directions are separate rounding pools" do
      category = tax_categories(:physical_book)
      lines = [
        { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 5, position: 0 },
        { id: 2, tax_category_id: category.id, direction: "return", taxable_merchandise_amount_cents: 5, position: 0 }
      ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      assert result.success?
      assert_equal 1, result.total_tax_cents_by_direction["sale"]
      assert_equal 1, result.total_tax_cents_by_direction["return"]
    end

    test "taxable treatment produces a component with a positive amount" do
      category = tax_categories(:physical_book)
      lines = [ { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1000, position: 0 } ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      line = result.lines.first
      assert_equal 1, line.components.size
      assert_equal "taxable", line.components.first.treatment_snapshot
      assert_equal 130, line.components.first.amount_cents
      assert_equal 130, line.tax_amount_cents
      # FOOD125 not_applicable may still snapshot as a non-collecting companion rule.
      assert_empty line.exempt_components.select { |c| c.treatment_snapshot == "exempt" }
    end

    test "zero_rated treatment produces an explicit zero-amount component with a taxable base" do
      category = tax_categories(:stationery)
      lines = [ { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1000, position: 0 } ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      line = result.lines.first
      assert_equal 1, line.components.size
      component = line.components.first
      assert_equal "zero_rated", component.treatment_snapshot
      assert_equal 1000, component.taxable_amount_cents
      assert_equal 0, component.amount_cents
      assert_equal 0, line.tax_amount_cents
    end

    test "exempt treatment produces no component row and collects no tax" do
      category = tax_categories(:digital_service)
      lines = [ { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1000, position: 0 } ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      assert result.success?
      line = result.lines.first
      assert_empty line.components
      assert_equal 0, line.tax_amount_cents
      assert_equal 1, line.exempt_components.size
      assert_equal "exempt", line.exempt_components.first.treatment_snapshot
    end

    test "not_applicable treatment is snapshotted without collecting tax alongside taxable components" do
      category = tax_categories(:physical_book)
      lines = [ { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1000, position: 0 } ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      assert result.success?
      line = result.lines.first
      assert_equal 1, line.components.size
      assert_equal "GST13", line.components.first.component_code
      assert_equal 130, line.tax_amount_cents
      na = line.exempt_components.find { |c| c.treatment_snapshot == "not_applicable" }
      assert na, "expected a not_applicable non-collecting snapshot for FOOD125"
      assert_equal "FOOD125", na.component_code
    end

    test "missing effective store tax rule is a blocker, not an exemption" do
      category = tax_categories(:unconfigured_category)
      lines = [ { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1000, position: 0 } ]

      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      refute result.success?
      assert_equal 1, result.blockers.size
      assert_match(/No effective store tax rule/, result.blockers.first)

      line = result.lines.first
      assert_empty line.components
      assert_equal 0, line.tax_amount_cents
    end

    test "an effective period outside the completion date is not resolved" do
      category = tax_categories(:physical_book)
      store_tax_rules(:physical_book_gst).update!(effective_from: Date.new(2030, 1, 1))
      store_tax_rules(:physical_book_food_not_applicable).update!(effective_from: Date.new(2030, 1, 1))

      lines = [ { id: 1, tax_category_id: category.id, direction: "sale", taxable_merchandise_amount_cents: 1000, position: 0 } ]
      result = CalculateTransaction.call(store: @store, lines: lines, completion_date: @completion_date)

      refute result.success?
    end
  end
end
