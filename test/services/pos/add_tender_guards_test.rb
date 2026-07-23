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

    test "card tender exceeding balance persists void_required tender" do
      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH1", actor: @admin
      )
      refute result.success?
      assert result.requires_void_confirmation?
      assert result.pos_tender.void_required?
      assert_equal "AUTH1", result.pos_tender.authorization_code
      assert_equal 1500, result.pos_tender.amount_cents
      assert_match(/exceeds remaining balance/, result.error)
    end

    test "zero remaining balance after valid refs persists void_required" do
      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      assert AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin
      ).success?

      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 500,
        authorization_code: "AUTH-ZERO", actor: @admin
      )
      refute result.success?
      assert result.requires_void_confirmation?
      assert result.pos_tender.void_required?
      assert_match(/no balance due/, result.error)
      assert RecordVoidedCardTender.call(
        pos_tender: result.pos_tender, actor: @admin, external_void_confirmed: true
      ).success?
      assert result.pos_tender.reload.voided?
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

    test "confirming void_required tender records voided status" do
      mismatch = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-VOID", actor: @admin
      )
      assert mismatch.pos_tender.void_required?

      voided = RecordVoidedCardTender.call(
        pos_tender: mismatch.pos_tender, actor: @admin,
        external_void_confirmed: true, external_void_reference: "EXT-1"
      )
      assert voided.success?, voided.error
      assert_equal "voided", voided.pos_tender.status
      assert_equal "AUTH-VOID", voided.pos_tender.authorization_code
      assert_equal "EXT-1", voided.pos_tender.external_void_reference
      assert_equal 1500, voided.pos_tender.amount_cents
    end

    test "required tender references are enforced from tender type" do
      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 500,
        authorization_code: "", actor: @admin
      )
      refute result.success?
      refute result.requires_void_confirmation?
      assert_nil result.pos_tender
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

    test "non-open transaction after valid refs persists void_required" do
      SuspendTransaction.call(pos_transaction: @transaction, actor: @admin)
      @transaction.reload

      result = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 500,
        authorization_code: "AUTH-SUSP", actor: @admin
      )
      refute result.success?
      assert result.requires_void_confirmation?
      assert result.pos_tender.void_required?
      assert_equal "AUTH-SUSP", result.pos_tender.authorization_code
      assert_match(/not open/, result.error)

      assert RecordVoidedCardTender.call(
        pos_tender: result.pos_tender, actor: @admin, external_void_confirmed: true
      ).success?
    end

    test "void_required blocks complete suspend and cancel" do
      mismatch = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-BLOCK", actor: @admin
      )
      assert mismatch.pos_tender.void_required?

      complete = CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "block-complete"
      )
      refute complete.success?
      assert_match(/void_required/, complete.error)

      suspend = SuspendTransaction.call(pos_transaction: @transaction, actor: @admin)
      refute suspend.success?
      assert_match(/void_required/, suspend.error)

      cancel = CancelTransaction.call(pos_transaction: @transaction, actor: @admin)
      refute cancel.success?
      assert_match(/void_required/, cancel.error)
    end

    test "same request UUID replays authorized card tender" do
      key = SecureRandom.uuid
      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      first = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-OK", actor: @admin, recording_idempotency_key: key
      )
      assert first.success?, first.error
      second = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-OK", actor: @admin, recording_idempotency_key: key
      )
      assert second.success?, second.error
      assert_equal first.pos_tender.id, second.pos_tender.id
      assert_equal key, first.pos_tender.recording_idempotency_key
    end

    test "same request UUID replays void_required tender" do
      key = SecureRandom.uuid
      first = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-IDEM", actor: @admin, recording_idempotency_key: key
      )
      second = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-IDEM", actor: @admin, recording_idempotency_key: key
      )
      assert first.pos_tender.void_required?
      assert second.requires_void_confirmation?
      assert_equal first.pos_tender.id, second.pos_tender.id
      assert_equal 1, @transaction.pos_tenders.void_required.count
    end

    test "distinct request UUIDs with identical refs create distinct void_required rows" do
      first = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-SAME", actor: @admin, recording_idempotency_key: SecureRandom.uuid
      )
      second = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-SAME", actor: @admin, recording_idempotency_key: SecureRandom.uuid
      )
      assert first.pos_tender.void_required?
      assert second.pos_tender.void_required?
      refute_equal first.pos_tender.id, second.pos_tender.id
      assert_equal 2, @transaction.pos_tenders.void_required.count
    end

    test "replay after void confirmation does not reattach" do
      key = SecureRandom.uuid
      mismatch = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-VOIDED-REPLAY", actor: @admin, recording_idempotency_key: key
      )
      assert mismatch.pos_tender.void_required?
      assert RecordVoidedCardTender.call(
        pos_tender: mismatch.pos_tender, actor: @admin, external_void_confirmed: true
      ).success?

      replay = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-VOIDED-REPLAY", actor: @admin, recording_idempotency_key: key
      )
      refute replay.success?
      refute replay.requires_void_confirmation?
      assert replay.pos_tender.voided?
      assert_match(/already voided/, replay.error)
      assert_equal 0, @transaction.pos_tenders.where(status: %w[authorized void_required]).count
    end

    test "payment replay with changed amount is an idempotency conflict" do
      key = SecureRandom.uuid
      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      first = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-CONFLICT", actor: @admin, recording_idempotency_key: key
      )
      assert first.success?, first.error

      conflict = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: [ net - 100, 100 ].max,
        authorization_code: "AUTH-CONFLICT", actor: @admin, recording_idempotency_key: key
      )
      refute conflict.success?
      refute conflict.requires_void_confirmation?
      assert_match(/already used with different details/, conflict.error)
      assert_equal 1, @transaction.pos_tenders.where(status: "authorized").count
    end

    test "payment replay with changed references is an idempotency conflict" do
      key = SecureRandom.uuid
      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      assert AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-A", actor: @admin, recording_idempotency_key: key
      ).success?

      conflict = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-B", actor: @admin, recording_idempotency_key: key
      )
      refute conflict.success?
      assert_match(/already used with different details/, conflict.error)
    end

    test "payment replay with different card tender type is an idempotency conflict" do
      key = SecureRandom.uuid
      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      other = @card.dup
      other.code = "card_other_#{SecureRandom.hex(4)}"
      other.name = "Other Card"
      other.shortcut = nil
      other.save!


      assert AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-TYPE", actor: @admin, recording_idempotency_key: key
      ).success?

      conflict = AddCardTender.call(
        pos_transaction: @transaction, tender_type: other, amount_cents: net,
        authorization_code: "AUTH-TYPE", actor: @admin, recording_idempotency_key: key
      )
      refute conflict.success?
      assert_match(/already used with different details/, conflict.error)
    end

    test "identical payment replay succeeds after tender-type reference config tightens" do
      key = SecureRandom.uuid
      net = RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      first = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-DRIFT", actor: @admin, recording_idempotency_key: key
      )
      assert first.success?, first.error

      @card.update!(reference_2_requirement: "required", reference_2_label: "Terminal ref")
      replay = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: net,
        authorization_code: "AUTH-DRIFT", actor: @admin, recording_idempotency_key: key
        # no terminal_reference — would fail current validation, but replay matches stored request
      )
      assert replay.success?, replay.error
      assert_equal first.pos_tender.id, replay.pos_tender.id
    end

    test "void resolution succeeds when tender type is later deactivated" do
      mismatch = AddCardTender.call(
        pos_transaction: @transaction, tender_type: @card, amount_cents: 1500,
        authorization_code: "AUTH-INACTIVE", actor: @admin
      )
      @card.update!(active: false, payment_enabled: false)

      result = RecordVoidedCardTender.call(
        pos_tender: mismatch.pos_tender, actor: @admin, external_void_confirmed: true
      )
      assert result.success?, result.error
      assert result.pos_tender.voided?
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
