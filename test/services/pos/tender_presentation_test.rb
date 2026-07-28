# frozen_string_literal: true

require "test_helper"

module Pos
  class TenderPresentationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @tender_types = @store.organization.tender_types.where(active: true).order(:name).to_a
    end

    test "defaults payment method to cash and exposes directional labels" do
      result = TenderPresentation.for(
        pos_transaction: @transaction,
        balance_due_cents: 1000,
        tender_types: @tender_types,
        pos_tenders: [],
        actor: @admin,
        store: @store
      )

      assert_equal "payment", result.direction
      assert_includes result.available_methods, "cash"
      assert_equal "cash", result.selected_method
      assert_equal "Cash payment", result.method_labels["cash"]
      assert result.cta_submits_form?
      assert_match(/Add tender/, result.cta_label)
      assert result.return_safe?
    end

    test "honors tender_method query for card" do
      result = TenderPresentation.for(
        pos_transaction: @transaction,
        balance_due_cents: 1000,
        tender_types: @tender_types,
        pos_tenders: [],
        tender_method_param: "card",
        actor: @admin,
        store: @store
      )

      assert_equal "card", result.selected_method
      assert_equal "Card payment", result.method_labels["card"]
    end

    test "refund mode prefers stored value when permitted" do
      result = TenderPresentation.for(
        pos_transaction: @transaction,
        balance_due_cents: -1500,
        tender_types: @tender_types,
        pos_tenders: [],
        actor: @admin,
        store: @store
      )

      assert result.refund_mode?
      assert_equal "stored_value", result.selected_method
      assert_equal "Stored Value refund", result.method_labels["stored_value"]
    end

    test "forced tender is not return-safe" do
      AddOpenRingLine.call(
        pos_transaction: @transaction, department: departments(:books_new),
        unit_price_cents: 500, actor: @admin
      )
      AddCashTender.call(
        pos_transaction: @transaction, tender_type: tender_types(:cash),
        amount_tendered_cents: 100, actor: @admin
      )

      result = TenderPresentation.for(
        pos_transaction: @transaction.reload,
        balance_due_cents: 465,
        tender_types: @tender_types,
        pos_tenders: @transaction.pos_tenders.where.not(status: "removed").to_a,
        actor: @admin,
        store: @store
      )

      assert result.forced_tender?
      refute result.return_safe?
    end

    test "zero balance is settled even without tender rows" do
      result = TenderPresentation.for(
        pos_transaction: @transaction,
        balance_due_cents: 0,
        tender_types: @tender_types,
        pos_tenders: [],
        actor: @admin,
        store: @store,
        ready_for_completion: false
      )

      assert result.settled?
      refute result.completable?
      assert_nil result.selected_method
      refute result.cta_submits_form?
    end

    test "settled and ready is completable" do
      result = TenderPresentation.for(
        pos_transaction: @transaction,
        balance_due_cents: 0,
        tender_types: @tender_types,
        pos_tenders: [],
        actor: @admin,
        store: @store,
        ready_for_completion: true
      )

      assert result.settled?
      assert result.completable?
      assert_equal "Complete transaction", result.cta_label
    end

    test "selected card type drives form metadata" do
      visa = TenderType.create!(
        organization: @store.organization,
        code: "card_visa_meta",
        name: "Visa terminal",
        tender_category: "card",
        payment_enabled: true,
        refund_enabled: true,
        allows_over_tender: false,
        provides_change: false,
        reference_1_requirement: "required",
        reference_1_label: "Visa auth",
        reference_2_requirement: "none",
        active: true
      )
      amex = TenderType.create!(
        organization: @store.organization,
        code: "card_amex_meta",
        name: "Amex terminal",
        tender_category: "card",
        payment_enabled: true,
        refund_enabled: true,
        allows_over_tender: false,
        provides_change: false,
        reference_1_requirement: "optional",
        reference_1_label: "Amex auth",
        reference_2_requirement: "required",
        reference_2_label: "Amex batch",
        active: true
      )
      types = [ visa, amex ]

      defaulted = TenderPresentation.for(
        pos_transaction: @transaction,
        balance_due_cents: 1000,
        tender_types: types,
        pos_tenders: [],
        tender_method_param: "card",
        actor: @admin,
        store: @store
      )
      assert_equal visa.id, defaulted.selected_card_type.id
      assert_equal "Visa auth", defaulted.selected_card_type.reference_1_label

      selected = TenderPresentation.for(
        pos_transaction: @transaction,
        balance_due_cents: 1000,
        tender_types: types,
        pos_tenders: [],
        tender_method_param: "card",
        tender_type_id_param: amex.id,
        actor: @admin,
        store: @store
      )
      assert_equal amex.id, selected.selected_card_type.id
      assert_equal "required", selected.selected_card_type.reference_2_requirement
    end
  end
end
