# frozen_string_literal: true

require "test_helper"

module Pos
  class OverrideTaxCategoryTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @books_department = departments(:books_new)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @books_department, unit_price_cents: 1999, actor: @admin
      ).pos_line_item
    end

    test "permitted user overrides tax category and retains the original for audit" do
      original_category_id = @line.tax_category_id

      result = OverrideTaxCategory.call(
        pos_line_item: @line, tax_category: tax_categories(:stationery), reason: "miscategorized at intake", actor: @admin
      )

      assert result.success?
      @line.reload
      assert_equal tax_categories(:stationery), @line.tax_category
      assert_equal original_category_id, @line.original_tax_category_id
      assert @line.tax_category_overridden?
      assert_equal @admin, @line.tax_category_overridden_by_user
      assert_equal "miscategorized at intake", @line.tax_category_override_reason
    end

    test "denies a user lacking pos.tax_category.override with no escalation path offered" do
      result = OverrideTaxCategory.call(
        pos_line_item: @line, tax_category: tax_categories(:stationery), reason: "miscategorized at intake", actor: @clerk
      )

      refute result.success?
      assert_match(/missing permission pos\.tax_category\.override/, result.error)
      @line.reload
      refute @line.tax_category_overridden?
    end

    test "an approver cannot bypass a requester who lacks the permission" do
      result = OverrideTaxCategory.call(
        pos_line_item: @line, tax_category: tax_categories(:stationery), reason: "miscategorized at intake",
        actor: @clerk, approver: @admin, approver_pin: "1234"
      )

      refute result.success?
      assert_match(/missing permission pos\.tax_category\.override/, result.error)
      @line.reload
      refute @line.tax_category_overridden?
    end

    test "an override reason is required" do
      result = OverrideTaxCategory.call(
        pos_line_item: @line, tax_category: tax_categories(:stationery), reason: "", actor: @admin
      )

      refute result.success?
      assert_match(/reason/, result.error)
    end
  end
end
