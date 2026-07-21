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
  # are in scope; Stored-Value posting remains out of scope (Phase 6).
  #
  # Phase 5f: a sale line linked to a Customer Request (`Pos::AddLine`'s
  # `product_request:`) creates the Product Request Fulfilment fact in the
  # same transaction as its sale movement; a linked return of a fulfilled
  # sale line appends a reversing fulfilment fact instead of mutating the
  # original (OD-007). Post-void reversal is Phase 6 and is not wired here.
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

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        raise Error, recalculation.blockers.join(", ") if recalculation.blockers.any?

        lines = transaction.pos_line_items.lock.pending.order(:position, :id).to_a
        raise Error, "transaction has no lines to complete" if lines.empty?
        validate_departments!(lines)
        validate_sale_eligibility!(lines, transaction.store)

        tenders = transaction.pos_tenders.lock.where(status: PosTender::UNRESOLVED_STATUSES).to_a
        validate_tenders_settle!(tenders, recalculation.net_total_cents)

        now = Time.current
        warnings = recalculation.warnings.dup

        # Lock linked Product Requests before inventory conversion so completion
        # and POS edits share: Transaction → Lines → Product Request → Balance → Reservation.
        linked_request_ids = lines.filter_map { |line|
          if line.sale? && line.line_kind == "product" && line.product_request_id.present?
            line.product_request_id
          elsif line.direction == "return" && line.line_kind == "product"
            original = line.original_pos_line_item
            next if original.blank?

            fulfillment = ProductRequestFulfillment.find_by(pos_line_item_id: original.id, kind: "fulfill")
            fulfillment&.product_request_id || original.product_request_id
          end
        }.uniq.sort
        locked_requests = linked_request_ids.index_with { |id| ProductRequest.lock.find(id) }

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
          end
        end

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
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique,
           Inventory::ConvertReservation::Error, Inventory::PostCustomerReturn::Error => e
      Result.new(pos_transaction: nil, success?: false, error: e.message, warnings: [], replayed: false)
    end

    private

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

    # Domain: completion revalidates sale eligibility for pending sale product
    # lines. Linked returns keep historical values; open-ring has no variant.
    def validate_sale_eligibility!(lines, store)
      lines.each do |line|
        next unless line.sale? && line.line_kind == "product"

        variant = line.product_variant
        raise Error, "line #{line.id} is missing its product variant" if variant.blank?
        raise Error, "line #{line.id} has no selling price" if line.unit_price_cents.nil?

        eligibility = Catalog::SaleEligibility.call(variant: variant, store: store)
        next if eligibility.blockers.empty?

        raise Error, "line #{line.id} is not eligible for sale: #{eligibility.blockers.join(', ')}"
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
