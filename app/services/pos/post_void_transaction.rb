# frozen_string_literal: true

module Pos
  # Policy A post-void: after approval and durable per-card confirmation audits,
  # creates a new completed reversing transaction. Never mutates the original.
  #
  # Confirmation audits are committed before the reverse attempt so a failed
  # reverse still leaves an investigation trail (Phase 7 / ops).
  class PostVoidTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error, :replayed, :confirmation_audit_event_ids)

    def initialize(
      original_transaction:,
      pos_session:,
      actor:,
      completion_idempotency_key:,
      pos_approval:,
      reason:,
      card_confirmations: {}
    )
      @original = original_transaction
      @pos_session = pos_session
      @actor = actor
      @reason = reason.to_s
      @pos_approval = pos_approval
      @completion_idempotency_key = completion_idempotency_key.to_s
      @card_confirmations = normalize_confirmations(card_confirmations)
      @confirmation_audits_by_tender_id = {}
      @confirmation_audit_event_ids = []
    end

    def call
      raise Error, "completion_idempotency_key is required" if @completion_idempotency_key.blank?
      raise Error, "pos_approval is required" if @pos_approval.blank?
      raise Error, "reason is required" if @reason.blank?

      existing = PosTransaction.find_by(reverses_pos_transaction_id: @original.id)
      if existing
        if existing.completion_idempotency_key == @completion_idempotency_key
          return Result.new(
            pos_transaction: existing, success?: true, error: nil, replayed: true,
            confirmation_audit_event_ids: @confirmation_audit_event_ids
          )
        end
        raise Error, "transaction has already been post-voided"
      end

      unless Authorization::EvaluatePermission.call(
        user: @actor, store: @original.store, permission_key: "pos.post_void.create"
      ) == :allow
        raise Error, "missing permission pos.post_void.create"
      end

      assert_approval!(@original)
      card_tenders = completed_card_tenders(@original)
      assert_confirmations!(card_tenders)
      persist_confirmation_audits!(card_tenders)

      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        raise Error, "session is not open" unless session.open?
        raise Error, "business day is not open" unless session.business_day.open?

        original = PosTransaction.lock.find(@original.id)

        existing = PosTransaction.find_by(reverses_pos_transaction_id: original.id)
        if existing
          if existing.completion_idempotency_key == @completion_idempotency_key
            return Result.new(
              pos_transaction: existing, success?: true, error: nil, replayed: true,
              confirmation_audit_event_ids: @confirmation_audit_event_ids
            )
          end
          raise Error, "transaction has already been post-voided"
        end

        # Canonical lock order (Pos::CompletionLockOrder): lines/tenders →
        # product requests → inventory → SV, then re-check eligibility under locks.
        lines = original.pos_line_items.lock.where(status: "completed").order(:position, :id).to_a
        tenders = original.pos_tenders.lock.where(status: "completed").order(:id).to_a

        request_ids = lines.filter_map { |line|
          next unless line.sale? && line.line_kind == "product"

          fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: line.id, kind: "fulfill")
          fulfillment&.product_request_id || line.product_request_id
        }.uniq.sort
        locked_requests = request_ids.index_with { |id| ProductRequest.lock.find(id) }

        CompletionLockOrder.lock_inventory_for_lines!(lines)
        CompletionLockOrder.lock_stored_value_accounts!(lines, tenders)

        eligibility = EvaluatePostVoidEligibility.call(original_transaction: original, store: session.store)
        raise Error, eligibility.blockers.join(", ") unless eligibility.eligible?

        now = Time.current
        reversing = PosTransaction.create!(
          store: original.store,
          origin_pos_session: session,
          active_pos_session: session,
          cashier_user: @actor,
          status: "open",
          opened_at: now,
          reverses_pos_transaction: original,
          post_void_reason: @reason,
          post_void_pos_approval: @pos_approval
        )

        line_map = {}
        lines.each_with_index do |original_line, index|
          line_map[original_line.id] = build_reversing_line!(reversing, original_line, index, now)
        end
        discount_map = clone_discounts!(original, reversing, line_map)

        lines.each do |original_line|
          reversing_line = line_map[original_line.id]
          reverse_inventory!(original_line, reversing_line)
          reverse_fulfillment!(original_line, reversing_line, now, locked_requests)
          reverse_stored_value_line!(original_line, reversing_line, original)
          copy_taxes_and_discounts!(original_line, reversing_line, discount_map)
        end

        tenders.each do |original_tender|
          reversing_tender = build_reversing_tender!(reversing, original_tender, now)
          reverse_stored_value_tender!(original_tender, reversing_tender, original)
        end

        line_map.each_value { |line| line.update!(status: "completed", completed_at: now) }
        reversing.pos_tenders.find_each { |tender| tender.update!(status: "completed", completed_at: now) }

        store = Store.lock.find(original.store_id)
        sequence = store.next_receipt_sequence
        store.update!(next_receipt_sequence: sequence + 1)

        reversing.update!(
          status: "completed",
          completed_at: now,
          completed_by_user: @actor,
          cashier_user: @actor,
          completed_pos_session: session,
          active_pos_session_id: nil,
          receipt_number: format_receipt_number(store, sequence),
          receipt_sequence: sequence,
          completion_idempotency_key: @completion_idempotency_key,
          subtotal_cents: -original.subtotal_cents.to_i,
          discount_total_cents: -original.discount_total_cents.to_i,
          tax_total_cents: -original.tax_total_cents.to_i,
          net_total_cents: -original.net_total_cents.to_i
        )

        Administration::RecordAuditEvent.call(
          actor: @actor, organization: store.organization, store: store,
          action: "pos_transaction.post_voided", subject: reversing,
          metadata: {
            "original_pos_transaction_id" => original.id,
            "receipt_number" => reversing.receipt_number,
            "pos_approval_id" => @pos_approval.id,
            "card_confirmation_audit_event_ids" => @confirmation_audit_event_ids
          }
        )

        Result.new(
          pos_transaction: reversing, success?: true, error: nil, replayed: false,
          confirmation_audit_event_ids: @confirmation_audit_event_ids
        )
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique,
           Inventory::ReverseLedgerEntry::Error, Inventory::ReverseLedgerEntry::ConflictError,
           StoredValue::PostEntry::Error => e
      audit_blocked_attempt!(e.message)
      Result.new(
        pos_transaction: nil, success?: false, error: e.message, replayed: false,
        confirmation_audit_event_ids: @confirmation_audit_event_ids
      )
    end

    private

    def normalize_confirmations(raw)
      Hash(raw).each_with_object({}) do |(key, value), out|
        attrs = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value
        out[key.to_s] = {
          "external_void_reference" => attrs["external_void_reference"].presence || attrs[:external_void_reference].presence,
          "confirmation_note" => attrs["confirmation_note"].presence || attrs[:confirmation_note].presence ||
            attrs["note"].presence || attrs[:note].presence
        }
      end
    end

    def assert_approval!(original)
      approval = PosApproval.find(@pos_approval.id)
      raise Error, "approval action must be post_void" unless approval.action_type == "post_void"
      raise Error, "approval does not belong to this transaction" unless approval.pos_transaction_id == original.id
      raise Error, "approval reason mismatch" if approval.reason.to_s != @reason.to_s
    end

    def completed_card_tenders(original)
      original.pos_tenders.where(status: "completed").includes(:tender_type).select { |t|
        t.tender_type.tender_category == "card"
      }
    end

    def assert_confirmations!(card_tenders)
      card_tenders.each do |tender|
        conf = @card_confirmations[tender.id.to_s]
        if conf.blank?
          raise Error, "card tender #{tender.id} requires an external void confirmation before post-void"
        end
        if conf["external_void_reference"].blank? && conf["confirmation_note"].blank?
          raise Error,
                "card tender #{tender.id} confirmation requires an external void reference or note"
        end
      end
    end

    def persist_confirmation_audits!(card_tenders)
      card_tenders.each do |tender|
        conf = @card_confirmations.fetch(tender.id.to_s)
        event = nil
        ActiveRecord::Base.transaction(requires_new: true) do
          event = Administration::RecordAuditEvent.call(
            actor: @actor,
            organization: @original.store.organization,
            store: @original.store,
            action: "pos_post_void.card_reversal_confirmed",
            subject: tender,
            metadata: {
              "original_pos_transaction_id" => @original.id,
              "original_pos_tender_id" => tender.id,
              "authorization_code" => tender.authorization_code,
              "terminal_reference" => tender.terminal_reference,
              "external_void_reference" => conf["external_void_reference"],
              "confirmation_note" => conf["confirmation_note"],
              "confirmed_by_user_id" => @actor.id,
              "confirmed_at" => Time.current.iso8601,
              "completion_idempotency_key" => @completion_idempotency_key,
              "pos_approval_id" => @pos_approval.id
            }
          )
        end
        @confirmation_audits_by_tender_id[tender.id] = { event: event, confirmation: conf }
        @confirmation_audit_event_ids << event.id
      end
    end

    def audit_blocked_attempt!(message)
      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: @original.store.organization,
        store: @original.store,
        action: "pos_transaction.post_void_blocked",
        subject: @original,
        metadata: {
          "reason" => message.to_s.truncate(500),
          "completion_idempotency_key" => @completion_idempotency_key,
          "card_confirmation_audit_event_ids" => @confirmation_audit_event_ids
        }
      )
    rescue StandardError
      nil
    end

    def clone_discounts!(original, reversing, line_map)
      PosDiscount.where(pos_transaction_id: original.id).order(:id).each_with_object({}) do |discount, map|
        target = discount.target_pos_line_item_id.present? ? line_map[discount.target_pos_line_item_id] : nil
        cloned = PosDiscount.create!(
          pos_transaction: reversing,
          scope: discount.scope,
          method: discount.method,
          tax_treatment: discount.tax_treatment,
          applied_amount_cents: discount.applied_amount_cents,
          base_amount_cents: discount.base_amount_cents,
          rate_bps: discount.rate_bps,
          requested_amount_cents: discount.requested_amount_cents,
          discount_reason_id: discount.discount_reason_id,
          position: discount.position,
          created_by_user: @actor,
          target_pos_line_item: target
        )
        map[discount.id] = cloned
      end
    end

    def build_reversing_line!(reversing, original_line, index, now)
      opposite = original_line.direction == "sale" ? "return" : "sale"
      attrs = {
        pos_transaction: reversing,
        line_kind: original_line.line_kind,
        direction: opposite,
        status: "pending",
        position: index,
        quantity: original_line.quantity,
        unit_price_cents: original_line.unit_price_cents,
        product_variant_id: original_line.product_variant_id,
        inventory_unit_id: original_line.inventory_unit_id,
        department_id: original_line.department_id,
        tax_category_id: original_line.tax_category_id,
        original_tax_category_id: original_line.original_tax_category_id,
        description_snapshot: original_line.description_snapshot,
        cost_unit_cost_cents: original_line.cost_unit_cost_cents,
        cost_extended_cents: original_line.cost_extended_cents,
        cost_method_snapshot: original_line.cost_method_snapshot,
        cost_quality_snapshot: original_line.cost_quality_snapshot,
        reverses_pos_line_item: original_line,
        created_by_user: @actor
      }

      if original_line.line_kind == "stored_value"
        # Reversing SV lines keep sale direction + snapshots; link via reverses_*.
        attrs[:direction] = "sale"
        attrs[:stored_value_account_id] = original_line.stored_value_account_id
        attrs[:stored_value_operation] = original_line.stored_value_operation
        attrs[:stored_value_account_type_snapshot] = original_line.stored_value_account_type_snapshot
        attrs[:stored_value_account_number_snapshot] = original_line.stored_value_account_number_snapshot
      end

      PosLineItem.create!(attrs)
    end

    def reverse_stored_value_line!(original_line, reversing_line, original_transaction)
      return unless original_line.line_kind == "stored_value"

      entry = StoredValueEntry.find_by!(pos_line_item_id: original_line.id)
      StoredValue::PostEntry.call(
        account: entry.stored_value_account,
        store: original_transaction.store,
        entry_type: "reversal",
        amount_cents: -entry.amount_cents,
        posting_key: "pos_line_item:#{reversing_line.id}:stored_value_reversal",
        actor: @actor,
        pos_transaction: reversing_line.pos_transaction,
        pos_line_item: reversing_line,
        reverses_entry: entry,
        allow_suspended: true
      )
    end

    def reverse_stored_value_tender!(original_tender, reversing_tender, original_transaction)
      return if original_tender.stored_value_account_id.blank?

      entry = StoredValueEntry.find_by!(pos_tender_id: original_tender.id)
      StoredValue::PostEntry.call(
        account: entry.stored_value_account,
        store: original_transaction.store,
        entry_type: "reversal",
        amount_cents: -entry.amount_cents,
        posting_key: "pos_tender:#{reversing_tender.id}:stored_value_reversal",
        actor: @actor,
        pos_transaction: reversing_tender.pos_transaction,
        pos_tender: reversing_tender,
        reverses_entry: entry,
        allow_suspended: true
      )
    end

    def reverse_inventory!(original_line, reversing_line)
      return unless original_line.line_kind == "product"
      return if original_line.product_variant.blank?

      case original_line.product_variant.inventory_tracking_mode
      when "quantity"
        sale_entry = InventoryLedgerEntry.find_by(
          posting_key: Inventory::ConvertReservation.posting_key(original_line)
        )
        return if sale_entry.blank?

        Inventory::ReverseLedgerEntry.call(
          reversal_of_entry: sale_entry,
          source: reversing_line,
          posting_key: "pos_line_item:#{reversing_line.id}:post_void_sale_reverse",
          posted_by_user: @actor,
          reason_code: "post_void",
          reason_note: @reason
        )
      when "individual"
        unit = InventoryUnit.lock.find(original_line.inventory_unit_id)
        raise Error, "unit is not in a reversible sold state" unless unit.status == "sold"
        raise Error, "unit was not sold on that line" unless unit.sold_pos_line_item_id == original_line.id

        unit.update!(status: "available", sold_at: nil, sold_pos_line_item_id: nil)
      end
    end

    def reverse_fulfillment!(original_line, reversing_line, now, locked_requests)
      return unless original_line.sale? && original_line.line_kind == "product"

      fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: original_line.id, kind: "fulfill")
      request_id = fulfillment&.product_request_id || original_line.product_request_id
      return if request_id.blank?

      result = Requests::ReverseFulfillment.call(
        original_pos_line_item: original_line,
        return_pos_line_item: reversing_line,
        actor: @actor,
        reversed_at: now,
        product_request: locked_requests[request_id]
      )
      raise Error, result.error unless result.success?
    end

    def copy_taxes_and_discounts!(original_line, reversing_line, discount_map)
      original_line.pos_line_item_taxes.find_each do |tax|
        PosLineItemTax.create!(
          pos_line_item: reversing_line,
          tax_category_id: tax.tax_category_id,
          store_tax_rule_id: tax.store_tax_rule_id,
          store_tax_rate_id: tax.store_tax_rate_id,
          rate: tax.rate,
          # Magnitudes stay non-negative (DB check); commercial sign is on the
          # reversing transaction totals and opposite line direction.
          taxable_amount_cents: tax.taxable_amount_cents,
          amount_cents: tax.amount_cents,
          treatment_snapshot: tax.treatment_snapshot,
          taxable_fraction_snapshot: tax.taxable_fraction_snapshot,
          compounds_on_prior_tax_snapshot: tax.compounds_on_prior_tax_snapshot,
          receipt_code_snapshot: tax.receipt_code_snapshot,
          position: tax.position
        )
      end

      original_line.pos_discount_allocations.find_each do |alloc|
        PosDiscountAllocation.create!(
          pos_line_item: reversing_line,
          pos_discount: discount_map.fetch(alloc.pos_discount_id),
          allocated_amount_cents: alloc.allocated_amount_cents,
          eligible_amount_cents: alloc.eligible_amount_cents
        )
      end
    end

    def build_reversing_tender!(reversing, original_tender, now)
      opposite = original_tender.direction == "received" ? "refunded" : "received"
      conf_bundle = @confirmation_audits_by_tender_id[original_tender.id]
      conf = conf_bundle&.dig(:confirmation) || {}

      PosTender.create!(
        pos_transaction: reversing,
        store: reversing.store,
        tender_type: original_tender.tender_type,
        direction: opposite,
        status: "pending",
        amount_cents: original_tender.amount_cents,
        amount_tendered_cents: original_tender.amount_tendered_cents,
        change_due_cents: original_tender.change_due_cents,
        authorization_code: original_tender.authorization_code,
        terminal_reference: original_tender.terminal_reference,
        external_void_reference: conf["external_void_reference"],
        stored_value_account_id: original_tender.stored_value_account_id,
        reverses_pos_tender: original_tender,
        created_by_user: @actor,
        external_void_confirmed_by_user: card_tender?(original_tender) ? @actor : nil,
        external_void_confirmed_at: card_tender?(original_tender) ? now : nil
      )
    end

    def card_tender?(tender)
      tender.tender_type.tender_category == "card"
    end

    def format_receipt_number(store, sequence)
      format("%s-%06d", store.code.to_s.upcase, sequence)
    end
  end
end
