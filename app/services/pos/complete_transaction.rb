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
  # Individual-unit and Stored-Value posting are out of scope (Phase 4d/6);
  # Product-line tracking modes `quantity` and `none` only (phase-04 4c scope).
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
        transaction = PosTransaction.lock.find(@pos_transaction.id)

        if transaction.completed?
          if transaction.completion_idempotency_key == @completion_idempotency_key
            return Result.new(pos_transaction: transaction, success?: true, error: nil, warnings: [], replayed: true)
          end

          raise Error, "transaction is already completed"
        end

        raise Error, "transaction is not open" unless transaction.open?

        session = PosSession.lock.find(@pos_session.id)
        raise Error, "completion session is not open" unless session.open?
        unless transaction.active_pos_session_id == session.id
          raise Error, "completion session does not control this transaction"
        end
        raise Error, "business day is not open" unless session.business_day.open?

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        raise Error, recalculation.blockers.join(", ") if recalculation.blockers.any?

        lines = transaction.pos_line_items.lock.pending.order(:position).to_a
        raise Error, "transaction has no lines to complete" if lines.empty?
        validate_departments!(lines)

        tenders = transaction.pos_tenders.lock.where(status: PosTender::UNRESOLVED_STATUSES).to_a
        validate_tenders_settle!(tenders, recalculation.net_total_cents)

        warnings = recalculation.warnings.dup
        lines.each do |line|
          next unless quantity_tracked_product_line?(line)

          conversion = Inventory::ConvertReservation.call(pos_line_item: line, posted_by_user: @actor)
          raise Error, conversion.error unless conversion.success?
          warnings.concat(conversion.warnings)
        end

        now = Time.current
        lines.each { |line| line.update!(status: "completed", completed_at: now) }
        tenders.each { |tender| tender.update!(status: "completed", completed_at: now) }

        store = Store.lock.find(transaction.store_id)
        sequence = store.next_receipt_sequence
        store.update!(next_receipt_sequence: sequence + 1)

        transaction.update!(
          status: "completed",
          completed_at: now,
          completed_by_user: @actor,
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
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique,
           Inventory::ConvertReservation::Error => e
      Result.new(pos_transaction: nil, success?: false, error: e.message, warnings: [], replayed: false)
    end

    private

    def quantity_tracked_product_line?(line)
      line.line_kind == "product" && line.product_variant.inventory_tracking_mode == "quantity"
    end

    # Domain: "Completion blocks when the resolved Department on a contributing
    # line is missing, inactive, or non-postable." Departments may be deactivated
    # after a line was added, so re-check the persisted line department here.
    def validate_departments!(lines)
      lines.each do |line|
        department = line.department
        if department.nil? || !department.active? || !department.postable?
          raise Error, "line #{line.id} has a missing, inactive, or non-postable department"
        end
      end
    end

    # Domain: "completed Tender net equals final Transaction net."
    def validate_tenders_settle!(tenders, net_total_cents)
      total = tenders.sum { |tender| tender.direction == "received" ? tender.amount_cents : -tender.amount_cents }
      return if total == net_total_cents

      raise Error, "tenders (#{total}) do not settle transaction net (#{net_total_cents})"
    end

    def format_receipt_number(store, sequence)
      "#{store.code}-#{sequence.to_s.rjust(6, '0')}"
    end
  end
end
