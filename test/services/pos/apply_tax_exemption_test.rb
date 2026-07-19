# frozen_string_literal: true

require "test_helper"

module Pos
  class ApplyTaxExemptionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @books_department = departments(:books_new)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @line = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @books_department, unit_price_cents: 1999, actor: @admin
      ).pos_line_item
    end

    test "applying an exemption is idempotent against the one-per-transaction record" do
      first = ApplyTaxExemption.call(
        pos_transaction: @transaction, exemption_type: "resale_certificate", actor: @admin, notes: "cert #123"
      )
      assert first.success?

      second = ApplyTaxExemption.call(
        pos_transaction: @transaction, exemption_type: "resale_certificate", actor: @admin, notes: "cert #123"
      )
      assert second.success?
      assert_equal first.pos_tax_exemption.id, second.pos_tax_exemption.id
      assert_equal 1, @transaction.pos_tax_exemptions.count
    end

    test "denies a user lacking pos.tax.exempt" do
      result = ApplyTaxExemption.call(
        pos_transaction: @transaction, exemption_type: "resale_certificate", actor: @clerk
      )

      refute result.success?
      refute @transaction.reload.tax_exempt?
    end

    test "coverage is always whole_transaction" do
      result = ApplyTaxExemption.call(
        pos_transaction: @transaction, exemption_type: "resale_certificate", actor: @admin
      )

      assert result.success?
      assert_equal "whole_transaction", result.pos_tax_exemption.coverage
    end
  end
end
