# frozen_string_literal: true

require "test_helper"

module Pos
  class RecalculateTransactionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @books_department = departments(:books_new)
      @unconfigured_department = departments(:unconfigured_tax_department)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "persisted pos_line_item_taxes match Tax::CalculateTransaction for the same inputs" do
      line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @books_department, unit_price_cents: 1999, actor: @admin
      ).pos_line_item

      expected = Tax::CalculateTransaction.call(
        store: @store,
        lines: [
          Tax::CalculateTransaction::Line.new(
            id: line.id, tax_category_id: line.tax_category_id, direction: "sale",
            taxable_merchandise_amount_cents: line.extended_price_cents, position: line.position
          )
        ]
      )

      persisted = PosLineItemTax.where(pos_line_item: line).order(:position)
      assert_equal 1, persisted.count
      expected_component = expected.lines.first.components.first
      row = persisted.first

      assert_equal expected_component.store_tax_rule_id, row.store_tax_rule_id
      assert_equal expected_component.store_tax_rate_id, row.store_tax_rate_id
      assert_equal expected_component.treatment_snapshot, row.treatment_snapshot
      assert_equal expected_component.taxable_amount_cents, row.taxable_amount_cents
      assert_equal expected_component.amount_cents, row.amount_cents
      assert_equal expected.total_tax_cents_by_direction.fetch("sale"), persisted.sum(&:amount_cents)
    end

    test "exempt store tax rule persists a zero-amount exempt snapshot row" do
      digital_department = Department.create!(
        organization: @store.organization, department_number: "700", code: "digital_test",
        name: "Digital Test", postable: true, default_tax_category: tax_categories(:digital_service), active: true
      )
      line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: digital_department, unit_price_cents: 500, actor: @admin
      ).pos_line_item

      row = PosLineItemTax.find_by(pos_line_item: line)
      assert_equal "exempt", row.treatment_snapshot
      assert_equal 0, row.amount_cents
      assert_nil row.store_tax_rate_id
    end

    test "a missing effective store tax rule blocks recalculation instead of implicitly exempting" do
      result = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @unconfigured_department, unit_price_cents: 1000, actor: @admin
      )

      assert result.success?, "adding the line itself should still succeed"
      assert result.warnings.any? { |w| w.match?(/No effective store tax rule/) }
      assert_empty PosLineItemTax.where(pos_line_item: result.pos_line_item)
    end

    test "whole-transaction exemption zeroes tax and skips persisting tax rows" do
      line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @books_department, unit_price_cents: 1999, actor: @admin
      ).pos_line_item
      assert PosLineItemTax.where(pos_line_item: line).exists?

      exemption = ApplyTaxExemption.call(
        pos_transaction: @transaction, exemption_type: "nonprofit", actor: @admin, notes: "501(c)(3) on file"
      )
      assert exemption.success?

      refute PosLineItemTax.where(pos_line_item: line).exists?
      recalculation = RecalculateTransaction.call(pos_transaction: @transaction.reload)
      assert recalculation.tax_exempt?
      assert_equal 0, recalculation.tax_total_cents
    end
  end
end
