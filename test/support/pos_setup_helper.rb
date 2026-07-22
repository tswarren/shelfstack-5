# frozen_string_literal: true

# Shared builders for POS / inventory operational graphs in tests.
# Prefer calling application services over inserting half-valid rows.
module PosSetupHelper
  def pos_open_inventory(store:, variant:, quantity:, unit_cost_cents:, actor:)
    opening = InventoryAdjustment.create!(
      store: store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
      created_by_user: actor
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: variant, position: 0,
      quantity_delta: quantity, input_unit_cost_cents: unit_cost_cents,
      input_cost_method: "explicit", input_cost_quality: "actual"
    )
    result = Inventory::PostAdjustment.call(adjustment: opening, actor: actor, store: store)
    raise "open inventory failed: #{result.error}" unless result.success?

    opening
  end

  def pos_open_cash_session(store:, device:, drawer:, actor:, opening_cash_cents: 0)
    day_result = Pos::OpenBusinessDay.call(store: store, actor: actor)
    day = if day_result.success?
      day_result.business_day
    else
      # Leftover open day from a prior non-transactional concurrency test.
      BusinessDay.find_by(store_id: store.id, status: "open").tap do |existing|
        raise "open business day failed: #{day_result.error}" if existing.blank?
      end
    end

    session_result = Pos::OpenSession.call(
      business_day: day, store: store, pos_device: device, cash_drawer: drawer,
      opening_cash_cents: opening_cash_cents, cashier: actor, actor: actor
    )
    unless session_result.success?
      existing = PosSession.find_by(pos_device_id: device.id, status: "open")
      raise "open session failed: #{session_result.error}" if existing.blank?

      return [ day, existing ]
    end

    [ day, session_result.pos_session ]
  end

  def pos_complete_cash_sale(session:, variant:, quantity:, actor:, cash:, key:, product_request: nil)
    txn = Pos::OpenTransaction.call(pos_session: session, actor: actor).pos_transaction
    added = Pos::AddLine.call(
      pos_transaction: txn, product_variant: variant, quantity: quantity, actor: actor, product_request: product_request
    )
    raise "add line failed: #{added.error}" unless added.success?

    line = added.pos_line_item
    net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: txn, tender_type: cash, amount_tendered_cents: net, actor: actor
    )
    result = Pos::CompleteTransaction.call(
      pos_transaction: txn, pos_session: session, actor: actor, completion_idempotency_key: key
    )
    raise "complete failed: #{result.error}" unless result.success?

    [ txn.reload, line.reload, net ]
  end

  # Linked-return cash refund that restores the remaining original cash tender.
  def pos_add_cash_refund(pos_transaction:, amount_cents:, actor:, tender_type: nil)
    tender_type ||= pos_transaction.store.organization.tender_types.find_by!(tender_category: "cash")
    original = Pos::RefundAllocationPolicy.remaining_original_tenders(pos_transaction)
      .find { |t| t.tender_type.tender_category == "cash" }
    Pos::AddCashRefundTender.call(
      pos_transaction: pos_transaction,
      tender_type: tender_type,
      amount_cents: amount_cents,
      actor: actor,
      original_pos_tender: original
    )
  end

  def with_stubbed_singleton_call(klass, raiser)
    klass.singleton_class.alias_method :__original_call, :call
    klass.define_singleton_method(:call, raiser)
    yield
  ensure
    klass.singleton_class.alias_method :call, :__original_call
    klass.singleton_class.remove_method :__original_call
  end

  # Policy A: approve post-void and build card confirmation params for
  # PostVoidTransaction (no preparation tables).
  def pos_ready_post_void!(
    original:,
    actor:,
    reason: "test post-void",
    approver: nil,
    approver_pin: "1234",
    pos_session: nil,
    auth_prefix: "VOID"
  )
    approved = Pos::ApprovePostVoid.call(
      original_transaction: original,
      actor: actor,
      reason: reason,
      approver: approver || actor,
      approver_pin: approver_pin,
      pos_session: pos_session
    )
    raise "approve post-void failed: #{approved.error}" unless approved.success?

    confirmations = {}
    original.pos_tenders.where(status: "completed").includes(:tender_type).order(:id).each_with_index do |tender, index|
      next unless tender.tender_type.tender_category == "card"

      confirmations[tender.id.to_s] = {
        "external_void_reference" => "#{auth_prefix}-#{index + 1}",
        "confirmation_note" => "confirmed"
      }
    end

    {
      pos_approval: approved.pos_approval,
      reason: approved.reason,
      card_confirmations: confirmations
    }
  end

  def pos_post_void!(original:, actor:, pos_session:, reason: "test post-void", key: nil, **ready_opts)
    plan = pos_ready_post_void!(
      original: original, actor: actor, reason: reason, pos_session: pos_session, **ready_opts
    )
    Pos::PostVoidTransaction.call(
      original_transaction: original,
      pos_session: pos_session,
      actor: actor,
      completion_idempotency_key: key || SecureRandom.uuid,
      pos_approval: plan[:pos_approval],
      reason: plan[:reason],
      card_confirmations: plan[:card_confirmations]
    )
  end
end
