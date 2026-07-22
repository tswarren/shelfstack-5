# frozen_string_literal: true

require "test_helper"

module Pos
  class PrepareCardRefundTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @card = tender_types(:card_standalone)
      @cash = tender_types(:cash)
      IdentifierSequence.ensure_defaults!
      pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "exception preparation creates exactly one approval reused on record" do
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(
        pos_transaction: sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "prep-exception-sale"
      ).success?
      sale_line = sale.pos_line_items.where(status: "completed").first

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      manager = create_manager_approver
      before = PosApproval.where(pos_transaction: ret).count
      prepared = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: nil,
        exception_approver: manager,
        exception_approver_pin: "9999"
      )
      assert prepared.ready?, prepared.error
      assert_equal before + 1, PosApproval.where(pos_transaction: ret).count
      assert_equal prepared.preparation.pos_approval_id, PosApproval.where(pos_transaction: ret).order(:id).last.id

      recorded = AddCardRefundTender.call(
        preparation: prepared.preparation,
        authorization_code: "RFND-EX",
        actor: @admin
      )
      assert recorded.success?, recorded.error
      assert_equal prepared.preparation.pos_approval_id, recorded.pos_tender.pos_approval_id
      assert_equal before + 1, PosApproval.where(pos_transaction: ret).count
    end

    test "persists plan snapshot and fingerprint" do
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: net,
        authorization_code: "SALE", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "prep-snap-sale"
      ).success?
      sale_line = sale.pos_line_items.where(status: "completed").first
      card_tender = sale.pos_tenders.where(status: "completed").first

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      prepared = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      )
      assert prepared.ready?, prepared.error
      prep = prepared.preparation
      assert prep.plan_snapshot["transaction_id"] == ret.id
      assert prep.plan_fingerprint.present?
      assert_equal RefundPlanSnapshot::VERSION, prep.fingerprint_version
      assert_equal card_tender.id, prep.intended_original_pos_tender_id
    end

    private

    def create_manager_approver
      username = "mgr_prep_#{SecureRandom.hex(2)}"
      user = User.create!(
        username: username,
        user_number: rand(10_000..99_999),
        first_name: "Test", last_name: username,
        password: "password123",
        pin: "9999", pin_confirmation: "9999",
        active: true, default_store: @store
      )
      role = Role.create!(
        organization: @store.organization,
        code: "role_#{username}",
        name: "Role #{username}",
        active: true
      )
      %w[pos.return.refund_exception.approve pos.tender.card_standalone].each do |code|
        RolePermission.create!(role: role, permission: Permission.find_by!(code: code))
      end
      StoreMembership.create!(user: user, store: @store, role: role, active: true)
      user
    end
  end
end
