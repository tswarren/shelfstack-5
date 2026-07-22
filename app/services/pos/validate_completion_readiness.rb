# frozen_string_literal: true

module Pos
  # Non-posting completion readiness checks shared by CompleteTransaction and
  # card-refund reconciliation acceptance. Does not assign receipt numbers,
  # post inventory, or mutate completion status.
  #
  # Caller must hold a row lock on the transaction. This service locks pending
  # lines, unresolved tenders, and related originals.
  class ValidateCompletionReadiness < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:recalculation, :lines, :tenders, :locked_originals)

    def initialize(pos_transaction:, actor:)
      @pos_transaction = pos_transaction
      @actor = actor
    end

    def call
      lines = @pos_transaction.pos_line_items.lock.pending.order(:position, :id).to_a
      raise Error, "transaction has no lines to complete" if lines.empty?

      tenders = @pos_transaction.pos_tenders.lock.where(status: PosTender::UNRESOLVED_STATUSES).to_a
      locked_originals = CompletionLockOrder.lock_related_originals!(lines, tenders)

      # Finalize historical residuals under original-line locks before tax/settlement.
      ReassignReturnResiduals.call(pos_transaction: @pos_transaction, return_lines: lines)
      lines.each(&:reload)

      recalculation = Pos::RecalculateTransaction.call(pos_transaction: @pos_transaction)
      raise Error, recalculation.blockers.join(", ") if recalculation.blockers.any?

      validate_departments!(lines)
      validate_sale_eligibility!(lines, @pos_transaction.store)
      validate_tenders_settle!(tenders, recalculation.net_total_cents)
      validate_linked_returns_and_refunds!(@pos_transaction, lines, tenders, locked_originals)

      Result.new(
        recalculation: recalculation,
        lines: lines,
        tenders: tenders,
        locked_originals: locked_originals
      )
    end

    private

    def validate_linked_returns_and_refunds!(transaction, lines, tenders, locked_originals)
      return_lines = lines.select { |line| line.direction == "return" && line.original_pos_line_item_id.present? }
      locked_lines = locked_originals.fetch(:lines)
      locked_tenders = locked_originals.fetch(:tenders)

      return_lines.each do |line|
        original = locked_lines.fetch(line.original_pos_line_item_id)
        raise Error, "original sale line #{original.id} has been post-voided" if original.post_voided?
        pending_here = return_lines
          .select { |other| other.original_pos_line_item_id == original.id }
          .sum(&:quantity)
        available = original.remaining_returnable_quantity + pending_here
        if pending_here > available
          raise Error, "return quantity exceeds remaining returnable for line #{original.id}"
        end
      end

      refund_tenders = tenders.select { |t| t.direction == "refunded" }
      refund_tenders.each do |tender|
        next if tender.original_pos_tender_id.blank?

        original = locked_tenders.fetch(tender.original_pos_tender_id)
        raise Error, "original tender #{original.id} has been post-voided" if original.post_voided?
        raise Error, "original tender's transaction has been post-voided" if original.pos_transaction.post_voided?
      end

      RefundAllocationPolicy.validate_plan!(
        pos_transaction: transaction,
        actor: @actor,
        refund_tenders: refund_tenders
      )
    rescue RefundAllocationPolicy::Error => e
      raise Error, e.message
    end

    def validate_departments!(lines)
      lines.each do |line|
        next if line.line_kind == "stored_value"

        department = line.department
        if department.nil? || !department.active? || !department.postable?
          raise Error, "line #{line.id} has a missing, inactive, or non-postable department"
        end
      end
    end

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

    def validate_tenders_settle!(tenders, net_total_cents)
      if tenders.any?(&:requires_reconciliation?)
        raise Error, "tender requires reconciliation before completion"
      end

      total = tenders.sum { |tender| tender.direction == "received" ? tender.amount_cents : -tender.amount_cents }
      return if total == net_total_cents

      raise Error, "tenders (#{total}) do not settle transaction net (#{net_total_cents})"
    end
  end
end
