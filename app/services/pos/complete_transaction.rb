# frozen_string_literal: true

module Pos
  # ADR-0008/ADR-0009 atomic, idempotent POS completion. Within one database
  # transaction: lock the Transaction and completion Session -> revalidate the
  # commercial fingerprint (recalculate tax; tax blockers fail completion) ->
  # convert Reservations / post sale Inventory Movements (snapshotting cost onto
  # each Line, D1) -> finalize Lines and Tenders -> obtain the store Receipt
  # sequence and assign the Receipt Number only on success -> mark the
  # Transaction completed -> commit. A raise at any point rolls back every
  # effect (no partial inventory/tender/receipt state).
  #
  # Idempotent: repeating the same `completion_idempotency_key` against the same
  # (now-completed) Transaction replays the prior success rather than re-running
  # side effects; a completed Transaction may not be completed again under a
  # different key.
  #
  # Product-line tracking modes `quantity`, `individual` (Phase 4d), and `none`
  # are in scope. Stored-value issue/reload lines and redeem/refund tenders post
  # through StoredValue::PostEntry in the same completion transaction.
  #
  # Phase 5f: a sale line linked to a Customer Request (`Pos::AddLine`'s
  # `product_request:`) creates the Product Request Fulfilment fact in the
  # same transaction as its sale movement; a linked return of a fulfilled
  # sale line appends a reversing fulfilment fact instead of mutating the
  # original (OD-007).
  class CompleteTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error, :warnings, :replayed)

    def initialize(pos_transaction:, pos_session:, actor:, completion_idempotency_key:)
      @pos_transaction = pos_transaction
      @pos_session = pos_session
      @actor = actor
      @completion_idempotency_key = completion_idempotency_key.to_s
    end

    def call
      raise Error, "completion_idempotency_key is required" if @completion_idempotency_key.blank?

      ActiveRecord::Base.transaction do
        # Canonical lock order: Session (parent) before Transaction (child).
        session = PosSession.lock.find(@pos_session.id)
        raise Error, "completion session is not open" unless session.open?
        raise Error, "business day is not open" unless session.business_day.open?

        transaction = PosTransaction.lock.find(@pos_transaction.id)

        if transaction.completed?
          if transaction.completion_idempotency_key == @completion_idempotency_key
            return Result.new(pos_transaction: transaction, success?: true, error: nil, warnings: [], replayed: true)
          end

          raise Error, "transaction is already completed"
        end

        raise Error, "transaction is not open" unless transaction.open?
        unless transaction.active_pos_session_id == session.id
          raise Error, "completion session does not control this transaction"
        end

        readiness = ValidateCompletionReadiness.call(
          pos_transaction: transaction, actor: @actor
        )
        recalculation = readiness.recalculation
        lines = readiness.lines
        tenders = readiness.tenders
        locked_originals = readiness.locked_originals

        now = Time.current
        warnings = recalculation.warnings.dup

        linked_request_ids = lines.filter_map { |line|
          if line.sale? && line.line_kind == "product" && line.product_request_id.present?
            line.product_request_id
          elsif line.direction == "return" && line.line_kind == "product"
            original = locked_originals[:lines][line.original_pos_line_item_id] || line.original_pos_line_item
            next if original.blank?

            fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: original.id, kind: "fulfill")
            fulfillment&.product_request_id || original.product_request_id
          end
        }.uniq.sort
        locked_requests = linked_request_ids.index_with { |id| ProductRequest.lock.find(id) }

        CompletionLockOrder.lock_inventory_for_lines!(lines)
        locked_sv_accounts = CompletionLockOrder.lock_stored_value_accounts!(lines, tenders)

        lines.each do |line|
          if line.direction == "return" && line.line_kind == "product"
            posted = Inventory::PostCustomerReturn.call(pos_line_item: line, posted_by_user: @actor)
            raise Error, posted.error unless posted.success?
            warnings.concat(posted.warnings)
            reverse_fulfilment_for_return!(line, posted_at: now, locked_requests: locked_requests)
          elsif line.sale? && line.line_kind == "product"
            conversion = nil
            if inventory_tracked_product_line?(line)
              conversion = Inventory::ConvertReservation.call(pos_line_item: line, posted_by_user: @actor)
              raise Error, conversion.error unless conversion.success?
              warnings.concat(conversion.warnings)
            end
            record_fulfilment_for_sale!(
              line, posted_at: now, converted_reservation: conversion&.reservation
            )
          elsif line.sale? && line.line_kind == "stored_value"
            post_stored_value_line!(line, transaction, locked_sv_accounts)
          end
        end

        tenders.each { |tender| post_stored_value_tender!(tender, transaction, locked_sv_accounts) }

        lines.each { |line| line.update!(status: "completed", completed_at: now) }
        tenders.each { |tender| tender.update!(status: "completed", completed_at: now) }

        store = Store.lock.find(transaction.store_id)
        sequence = store.next_receipt_sequence
        store.update!(next_receipt_sequence: sequence + 1)

        transaction.update!(
          status: "completed",
          completed_at: now,
          completed_by_user: @actor,
          cashier_user: @actor,
          completed_pos_session: session,
          receipt_number: format_receipt_number(store, sequence),
          receipt_sequence: sequence,
          completion_idempotency_key: @completion_idempotency_key,
          subtotal_cents: recalculation.subtotal_cents,
          discount_total_cents: recalculation.discount_total_cents,
          tax_total_cents: recalculation.tax_total_cents,
          net_total_cents: recalculation.net_total_cents
        )

        Administration::RecordAuditEvent.call(
          actor: @actor, organization: store.organization, store: store,
          action: "pos_transaction.completed", subject: transaction,
          metadata: { "receipt_number" => transaction.receipt_number, "net_total_cents" => recalculation.net_total_cents }
        )

        Result.new(pos_transaction: transaction, success?: true, error: nil, warnings: warnings.uniq, replayed: false)
      end
    rescue Error, ValidateCompletionReadiness::Error, ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotUnique,
           Inventory::ConvertReservation::Error, Inventory::PostCustomerReturn::Error,
           StoredValue::PostEntry::Error => e
      Result.new(pos_transaction: nil, success?: false, error: e.message, warnings: [], replayed: false)
    end

    private

    def post_stored_value_line!(line, transaction, locked_accounts)
      account = locked_accounts.fetch(line.stored_value_account_id)
      entry_type = line.stored_value_operation == "reload" ? "reloaded" : "issued"
      StoredValue::PostEntry.call(
        account: account,
        store: transaction.store,
        entry_type: entry_type,
        amount_cents: line.extended_price_cents,
        posting_key: "pos_line_item:#{line.id}:stored_value_#{entry_type}",
        actor: @actor,
        pos_transaction: transaction,
        pos_line_item: line
      )
    end

    def post_stored_value_tender!(tender, transaction, locked_accounts)
      return if tender.stored_value_account_id.blank?

      account = locked_accounts.fetch(tender.stored_value_account_id)
      if tender.direction == "received"
        StoredValue::PostEntry.call(
          account: account,
          store: transaction.store,
          entry_type: "redeemed",
          amount_cents: -tender.amount_cents,
          posting_key: "pos_tender:#{tender.id}:stored_value_redeemed",
          actor: @actor,
          pos_transaction: transaction,
          pos_tender: tender
        )
      elsif tender.direction == "refunded"
        StoredValue::PostEntry.call(
          account: account,
          store: transaction.store,
          entry_type: "refunded",
          amount_cents: tender.amount_cents,
          posting_key: "pos_tender:#{tender.id}:stored_value_refunded",
          actor: @actor,
          pos_transaction: transaction,
          pos_tender: tender,
          allow_suspended: true
        )
      end
    end

    # Phase 5f (OD-007): a sale line linked to a Customer Request at
    # `Pos::AddLine` time creates the Product Request Fulfilment fact
    # atomically with its sale inventory movement, closing the request when
    # fully fulfilled.
    def record_fulfilment_for_sale!(line, posted_at:, converted_reservation: nil)
      return if line.product_request_id.blank?

      result = Requests::RecordFulfillment.call(
        product_request: line.product_request, pos_line_item: line, actor: @actor,
        quantity: line.quantity, fulfilled_at: posted_at,
        converted_reservation: converted_reservation
      )
      raise Error, result.error unless result.success?
    end

    # A linked return of a completed sale line that fulfilled a Customer
    # Request appends a `reverse` fulfilment fact rather than mutating the
    # original (ADR-0008); a no-op when the original line was never linked.
    def reverse_fulfilment_for_return!(line, posted_at:, locked_requests: {})
      original = line.original_pos_line_item
      return if original.blank?

      fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: original.id, kind: "fulfill")
      request_id = fulfillment&.product_request_id || original.product_request_id
      product_request = locked_requests[request_id] if request_id

      result = Requests::ReverseFulfillment.call(
        original_pos_line_item: original,
        return_pos_line_item: line,
        actor: @actor,
        reversed_at: posted_at,
        product_request: product_request
      )
      raise Error, result.error unless result.success?
    end

    def inventory_tracked_product_line?(line)
      line.line_kind == "product" &&
        %w[quantity individual].include?(line.product_variant.inventory_tracking_mode)
    end

    def format_receipt_number(store, sequence)
      "#{store.code}-#{sequence.to_s.rjust(6, '0')}"
    end
  end
end
