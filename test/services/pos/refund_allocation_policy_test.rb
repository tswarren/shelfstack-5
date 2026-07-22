# frozen_string_literal: true

require "test_helper"

module Pos
  class RefundAllocationPolicyTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @card = tender_types(:card_standalone)
      @sv_tender = tender_types(:stored_value)
      IdentifierSequence.ensure_defaults!
      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)

      @account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      StoredValue::PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 5000,
        posting_key: "sv-seed-refund-policy", actor: @admin
      )

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "cash refund is blocked while original SV tender remains refundable" do
      sale_line, = complete_sv_sale
      ret = open_return(sale_line)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      denied = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due, actor: @admin
      )
      refute denied.success?
      assert_match(/restore remaining original/, denied.error)
    end

    test "cash refund allowed with exception approval while original SV remains" do
      sale_line, = complete_sv_sale
      ret = open_return(sale_line)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      other = create_other_approver

      allowed = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due, actor: @admin,
        exception_approver: other, exception_approver_pin: "9999"
      )
      assert allowed.success?, allowed.error
      assert allowed.pos_tender.pos_approval_id.present?
    end

    test "cash refund links original cash tender and reduces remaining refundable" do
      sale_line, sale_tender = complete_cash_sale
      ret = open_return(sale_line)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      refund = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due, actor: @admin,
        original_pos_tender: sale_tender
      )
      assert refund.success?, refund.error
      assert_equal sale_tender.id, refund.pos_tender.original_pos_tender_id
      assert_equal 0, sale_tender.reload.remaining_refundable_cents
    end

    test "cash refund without original is blocked while original cash remains" do
      sale_line, = complete_cash_sale
      ret = open_return(sale_line)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      denied = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due, actor: @admin
      )
      refute denied.success?
      assert_match(/restore remaining original/, denied.error)
    end

    test "card refund links original card tender" do
      sale_line, sale_tender = complete_card_sale
      ret = open_return(sale_line)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      refund = AddCardRefundTender.call(
        pos_transaction: ret, tender_type: @card, amount_cents: refund_due,
        authorization_code: "REF-1", actor: @admin, original_pos_tender: sale_tender
      )
      assert refund.success?, refund.error
      assert_equal sale_tender.id, refund.pos_tender.original_pos_tender_id
      assert_equal "authorized", refund.pos_tender.status
      assert_equal 0, sale_tender.reload.remaining_refundable_cents
    end

    test "non-original SV refund cannot credit a gift_card account" do
      sale_line, = complete_cash_sale
      ret = open_return(sale_line)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      other = create_other_approver

      denied = AddStoredValueRefundTender.call(
        pos_transaction: ret, tender_type: @sv_tender, amount_cents: refund_due, actor: @admin,
        account: @account,
        exception_approver: other, exception_approver_pin: "9999"
      )
      refute denied.success?
      assert_match(/store_credit/, denied.error)
    end

    private

    def complete_sv_sale
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      assert AddStoredValueTender.call(
        pos_transaction: sale, tender_type: @sv_tender, account: @account,
        amount_cents: sale_net, actor: @admin
      ).success?
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-sv-policy-#{SecureRandom.hex(3)}"
      ).success?
      [ sale.pos_line_items.where(status: "completed").first, sale.pos_tenders.where(status: "completed").first ]
    end

    def complete_cash_sale
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(
        pos_transaction: sale, tender_type: @cash, amount_tendered_cents: sale_net, actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-cash-policy-#{SecureRandom.hex(3)}"
      ).success?
      [ sale.pos_line_items.where(status: "completed").first, sale.pos_tenders.where(status: "completed").first ]
    end

    def complete_card_sale
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      sale_net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: sale_net,
        authorization_code: "SALE-1", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "sale-card-policy-#{SecureRandom.hex(3)}"
      ).success?
      [ sale.pos_line_items.where(status: "completed").first, sale.pos_tenders.where(status: "completed").first ]
    end

    def open_return(sale_line)
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      ret
    end

    def create_other_approver
      user = User.create!(
        username: "cash_refund_approver_#{SecureRandom.hex(2)}",
        user_number: rand(10_000..99_999),
        first_name: "Cash", last_name: "Approver",
        password: "password123", pin: "9999", pin_confirmation: "9999",
        active: true, default_store: @store
      )
      StoreMembership.create!(user: user, store: @store, role: roles(:administrator), active: true)
      user
    end

    def open_inventory(variant, quantity:, unit_cost_cents:)
      reason = inventory_adjustment_reasons(:opening_initial)
      adjustment = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: reason, created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment, product_variant: variant, position: 0,
        quantity_delta: quantity, input_unit_cost_cents: unit_cost_cents,
        input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: adjustment, actor: @admin, store: @store).success?
    end
  end
end
