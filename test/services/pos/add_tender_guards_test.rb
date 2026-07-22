# frozen_string_literal: true

require "test_helper"

module Pos
  class AddTenderGuardsTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @cash = tender_types(:cash)
      @card = tender_types(:card_standalone)
      @department = departments(:books_new)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department, unit_price_cents: 1000, actor: @admin
      )
    end

    test "card tender exceeding balance returns amount_mismatch when over-tender is disallowed" do
      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH1", actor: @admin
      )
      refute result.success?
      assert result.amount_mismatch?
      assert_match(/exceeds remaining balance/, result.error)
    end

    test "partial card tender is accepted within remaining balance" do
      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 400,
        authorization_code: "AUTH-PARTIAL", actor: @admin
      )
      assert result.success?, result.error
      assert_equal 400, result.pos_tender.amount_cents
      assert result.pos_tender.authorized?

      remainder = AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 600, actor: @admin
      )
      assert remainder.success?, remainder.error
    end

    test "record voided card tender retains refs after mismatch" do
      voided = RecordVoidedCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500, actor: @admin,
        authorization_code: "AUTH-VOID", external_void_confirmed: true,
        external_void_reference: "EXT-1"
      )
      assert voided.success?, voided.error
      assert_equal "voided", voided.pos_tender.status
      assert_equal "AUTH-VOID", voided.pos_tender.authorization_code
      assert_equal 1500, voided.pos_tender.amount_cents
    end

    test "required tender references are enforced from tender type" do
      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 500,
        authorization_code: "", actor: @admin
      )
      refute result.success?
      refute result.amount_mismatch?
      assert_match(/required/i, result.error)
    end

    test "card tender accepts exact remaining balance" do
      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH1", actor: @admin
      )
      assert result.success?, result.error
    end

    test "inactive tender type is rejected" do
      @cash.update!(active: false)
      result = AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 1000, actor: @admin
      )
      refute result.success?
      assert_match(/inactive/, result.error)
    end

    test "payment_disabled tender type is rejected" do
      @cash.update!(payment_enabled: false)
      result = AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 1000, actor: @admin
      )
      refute result.success?
      assert_match(/payment-enabled/, result.error)
    end

    test "calculation blockers prevent cash tender creation" do
      store_tax_rules(:physical_book_gst).update!(active: false)
      store_tax_rules(:physical_book_food_not_applicable).update!(active: false)
      line = @transaction.pos_line_items.pending.first
      line.update!(tax_category: tax_categories(:unconfigured_category))

      result = AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: 1000, actor: @admin
      )
      refute result.success?
      assert_match(/blockers/, result.error)
    end
  end
end
