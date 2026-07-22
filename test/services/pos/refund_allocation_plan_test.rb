# frozen_string_literal: true

require "test_helper"

module Pos
  class RefundAllocationPlanTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      @sv_tender = tender_types(:stored_value)
      IdentifierSequence.ensure_defaults!
      pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)

      @account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      StoredValue::PostEntry.call(
        account: @account, store: @store, entry_type: "issued", amount_cents: 50_000,
        posting_key: "sv-plan-seed", actor: @admin
      )

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "same return may restore SV then cash without exception approval" do
      sale_line, sv_original, cash_original = complete_split_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      sv_amount = [ sv_original.amount_cents, refund_due ].min
      cash_amount = refund_due - sv_amount
      assert cash_amount.positive?

      assert AddStoredValueRefundTender.call(
        pos_transaction: ret, tender_type: @sv_tender, amount_cents: sv_amount,
        actor: @admin, original_pos_tender: sv_original
      ).success?

      cash_refund = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: cash_amount,
        actor: @admin, original_pos_tender: cash_original
      )
      assert cash_refund.success?, cash_refund.error
      assert_nil cash_refund.pos_tender.pos_approval_id

      completed = CompleteTransaction.call(
        pos_transaction: ret, pos_session: @session, actor: @admin,
        completion_idempotency_key: "plan-sv-cash-#{SecureRandom.hex(3)}"
      )
      assert completed.success?, completed.error
    end

    test "pending SV restoration in another return still requires cash exception" do
      sale_line, sv_original, cash_original = complete_split_sale(quantity: 2)

      ret_a = open_return(sale_line, quantity: 1)
      due_a = -RecalculateTransaction.call(pos_transaction: ret_a).net_total_cents
      sv_amount = [ sv_original.amount_cents, due_a ].min
      assert AddStoredValueRefundTender.call(
        pos_transaction: ret_a, tender_type: @sv_tender, amount_cents: sv_amount,
        actor: @admin, original_pos_tender: sv_original
      ).success?

      ret_b = open_return(sale_line, quantity: 1)
      due_b = -RecalculateTransaction.call(pos_transaction: ret_b).net_total_cents

      denied = AddCashRefundTender.call(
        pos_transaction: ret_b, tender_type: @cash, amount_cents: due_b,
        actor: @admin, original_pos_tender: cash_original
      )
      refute denied.success?
      assert_match(/restore remaining original|exception approval/, denied.error)
    end

    test "concurrent removal of in-flight SV refund locks original tender with completion" do
      sale_line, sv_original, cash_original = complete_split_sale(quantity: 2)

      ret_a = open_return(sale_line, quantity: 1)
      due_a = -RecalculateTransaction.call(pos_transaction: ret_a).net_total_cents
      sv_refund = AddStoredValueRefundTender.call(
        pos_transaction: ret_a, tender_type: @sv_tender,
        amount_cents: [ due_a, sv_original.amount_cents ].min,
        actor: @admin, original_pos_tender: sv_original
      )
      assert sv_refund.success?, sv_refund.error

      ret_b = open_return(sale_line, quantity: 1)
      due_b = -RecalculateTransaction.call(pos_transaction: ret_b).net_total_cents
      manager = create_manager_approver
      cash_b = AddCashRefundTender.call(
        pos_transaction: ret_b, tender_type: @cash, amount_cents: due_b, actor: @admin,
        original_pos_tender: cash_original,
        exception_approver: manager, exception_approver_pin: "9999"
      )
      assert cash_b.success?, cash_b.error

      results = {}
      barrier = Concurrent::CyclicBarrier.new(2)
      t_remove = Thread.new do
        barrier.wait
        results[:remove] = RemoveTender.call(pos_tender: sv_refund.pos_tender, actor: @admin)
      end
      t_complete = Thread.new do
        barrier.wait
        results[:complete] = CompleteTransaction.call(
          pos_transaction: ret_b, pos_session: @session, actor: @admin,
          completion_idempotency_key: "race-refund-plan-#{SecureRandom.hex(3)}"
        )
      end
      t_remove.join
      t_complete.join

      assert results[:remove].success?, results[:remove].error
      assert results[:complete].success?, results[:complete].error
      assert cash_b.pos_tender.reload.pos_approval_id.present?
    end

    test "cashier destination permission requests exception; SV refund alone cannot approve" do
      cashier = create_user_with_permissions(
        "cashier_exc_#{SecureRandom.hex(2)}",
        %w[pos.tender.cash pos.return.create pos.access]
      )
      sv_only_approver = create_user_with_permissions(
        "sv_only_#{SecureRandom.hex(2)}",
        %w[stored_value.tender.refund],
        pin: "9999"
      )
      manager = create_manager_approver

      sale_line, cash_original = complete_cash_sale
      ret = open_return(sale_line)
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      denied = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due,
        actor: cashier, exception_approver: sv_only_approver, exception_approver_pin: "9999"
      )
      refute denied.success?
      assert_match(/approver lacks|exception approval/, denied.error)

      # Exception path (no original link) with proper approver.
      allowed = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due,
        actor: cashier, exception_approver: manager, exception_approver_pin: "9999"
      )
      assert allowed.success?, allowed.error
      assert allowed.pos_tender.pos_approval_id.present?

      # Ordinary restoration still works for the cashier with original link.
      ret2_line, = complete_cash_sale
      ret2 = open_return(ret2_line)
      due2 = -RecalculateTransaction.call(pos_transaction: ret2).net_total_cents
      original = ret2_line.pos_transaction.pos_tenders.where(status: "completed").first
      linked = AddCashRefundTender.call(
        pos_transaction: ret2, tender_type: @cash, amount_cents: due2,
        actor: cashier, original_pos_tender: original
      )
      assert linked.success?, linked.error
      assert_nil linked.pos_tender.pos_approval_id
    end

    private

    def complete_split_sale(quantity:)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: quantity, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      sv_pay = net / 2
      cash_pay = net - sv_pay
      assert sv_pay.positive? && cash_pay.positive?
      assert AddStoredValueTender.call(
        pos_transaction: sale, tender_type: @sv_tender, account: @account,
        amount_cents: sv_pay, actor: @admin
      ).success?
      AddCashTender.call(
        pos_transaction: sale, tender_type: @cash, amount_tendered_cents: cash_pay, actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "split-sale-#{SecureRandom.hex(3)}"
      ).success?
      line = sale.pos_line_items.where(status: "completed").first
      sv_t = sale.pos_tenders.joins(:tender_type)
        .where(status: "completed", tender_types: { tender_category: "stored_value" }).first
      cash_t = sale.pos_tenders.joins(:tender_type)
        .where(status: "completed", tender_types: { tender_category: "cash" }).first
      [ line, sv_t, cash_t ]
    end

    def complete_cash_sale
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCashTender.call(pos_transaction: sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "cash-sale-#{SecureRandom.hex(3)}"
      ).success?
      [ sale.pos_line_items.where(status: "completed").first, sale.pos_tenders.where(status: "completed").first ]
    end

    def open_return(sale_line, quantity: 1)
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: quantity,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      ret
    end

    def create_manager_approver
      create_user_with_permissions(
        "mgr_exc_#{SecureRandom.hex(2)}",
        %w[pos.return.refund_exception.approve pos.tender.cash stored_value.tender.refund],
        pin: "9999"
      )
    end

    def create_user_with_permissions(username, permission_codes, pin: nil)
      attrs = {
        username: username,
        user_number: rand(10_000..99_999),
        first_name: "Test", last_name: username,
        password: "password123",
        active: true, default_store: @store
      }
      if pin
        attrs[:pin] = pin
        attrs[:pin_confirmation] = pin
      end
      user = User.create!(attrs)
      role = Role.create!(
        organization: @store.organization,
        code: "role_#{username}",
        name: "Role #{username}",
        active: true
      )
      permission_codes.each do |code|
        RolePermission.create!(role: role, permission: Permission.find_by!(code: code))
      end
      StoreMembership.create!(user: user, store: @store, role: role, active: true)
      user
    end
  end
end
