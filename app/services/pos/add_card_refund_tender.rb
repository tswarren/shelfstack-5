# frozen_string_literal: true

module Pos
  # Records an externally authorized card refund against a durable preparation.
  #
  # Accepts only preparation identity + terminal authorization data. Plan fields
  # are taken from the preparation. After a valid preparation ID and nonblank
  # authorization are presented, ordinary business/config failures become
  # reconciliation reasons — the external fact is always retained.
  #
  # If the preparation was abandoned before auth arrives, the fact is retained as
  # a recorded_orphan (preserving abandonment + authorization history).
  class AddCardRefundTender < ApplicationService
    Error = Class.new(StandardError)
    IdempotencyConflict = Class.new(Error)
    Result = Data.define(
      :pos_tender, :preparation, :success?, :error, :warnings, :requires_reconciliation
    )

    def initialize(preparation:, authorization_code:, actor:, terminal_reference: nil)
      @preparation = preparation
      @authorization_code = authorization_code.to_s.strip
      @terminal_reference = terminal_reference.presence
      @actor = actor
    end

    def call
      raise Error, "authorization code is required" if @authorization_code.blank?
      raise Error, "preparation is required" if @preparation.blank?

      ActiveRecord::Base.transaction do
        transaction_id = @preparation.pos_transaction_id
        transaction = PosTransaction.lock.find(transaction_id)
        preparation = PosCardRefundPreparation.lock.find(@preparation.id)
        unless preparation.pos_transaction_id == transaction.id
          raise Error, "preparation does not belong to this transaction"
        end

        if preparation.recorded_tender? || preparation.recorded_orphan?
          return replay_result!(preparation)
        end
        unless preparation.prepared? || preparation.abandoned?
          raise Error, "preparation is not recordable (status=#{preparation.status})"
        end

        abandoned_before = preparation.abandoned?

        tender_type = TenderType.find(preparation.tender_type_id)
        amount_cents = preparation.amount_cents
        intended_original = preparation.intended_original_pos_tender
        approval = preparation.pos_approval

        reasons = []
        warnings = []
        original = nil

        reasons << "preparation was abandoned before authorization was recorded" if abandoned_before
        unless transaction.open?
          reasons << "transaction is not open (status=#{transaction.status})"
        end

        begin
          TenderGuards.assert_active!(tender_type)
          TenderGuards.assert_refund_enabled!(tender_type)
        rescue TenderGuards::Error => e
          reasons << e.message
        end

        if preparation.expires_at <= Time.current
          reasons << "preparation expired before recording"
        end

        replacing = preparation.replaces_pos_tender
        excluding_ids = []
        if replacing.present?
          replacing = PosTender.lock.find(replacing.id)
          begin
            CardRefundSupport.assert_replaceable_recon_tender!(transaction, replacing)
            excluding_ids = [ replacing.id ]
          rescue CardRefundSupport::Error
            # External auth may already exist; retain as reconciliation rather than discard.
            reasons << "replacement target no longer requires reconciliation"
            replacing = nil
          end
        end

        begin
          recalculation = FinalizeReturnFinancials.call(pos_transaction: transaction).recalculation
          warnings.concat(Array(recalculation.warnings))
          if recalculation.blockers.present?
            reasons << "calculation blockers: #{recalculation.blockers.join(', ')}"
          else
            refund_due = CardRefundSupport.refund_due_cents(
              transaction, recalculation.net_total_cents, excluding_tender_ids: excluding_ids
            )
            reasons << "no refund balance due" if refund_due.zero?
            if refund_due.positive? && amount_cents > refund_due
              reasons << "refund exceeds balance due (#{refund_due})"
            end
            current_snapshot = RefundPlanSnapshot.build(
              pos_transaction: transaction,
              tender_type: tender_type,
              amount_cents: amount_cents,
              actor: preparation.prepared_by_user,
              intended_original_pos_tender: intended_original,
              pos_approval: approval,
              net_total_cents: recalculation.net_total_cents,
              refund_due_cents: refund_due
            )
            current_fingerprint = RefundPlanSnapshot.fingerprint(current_snapshot)
            if current_fingerprint != preparation.plan_fingerprint
              reasons << "refund plan fingerprint changed since preparation"
            end
          end

          CardRefundSupport.assert_no_post_voided_linked_originals!(transaction)
          original = CardRefundSupport.validate_original!(
            transaction: transaction,
            original_pos_tender: intended_original,
            amount_cents: amount_cents,
            excluding_refund_tender: replacing
          )

          RefundAllocationPolicy.call(
            pos_transaction: transaction,
            actor: @actor,
            destination: :card,
            amount_cents: amount_cents,
            original_pos_tender: original,
            existing_exception_approval: approval,
            excluding_tender_ids: excluding_ids
          )
        rescue CardRefundSupport::Error, RefundAllocationPolicy::Error, TenderGuards::Error => e
          reasons << e.message
          original = nil if e.is_a?(CardRefundSupport::Error)
        end

        requires_reconciliation = reasons.any?
        now = Time.current
        unless preparation.prepared? || preparation.abandoned?
          raise Error, "preparation was concurrently consumed"
        end

        # Abandoned preparations always become orphans so the commercial unlock
        # after abandon cannot silently attach a tender to a drifted plan.
        if transaction.open? && !abandoned_before
          tender = PosTender.create!(
            pos_transaction: transaction,
            store: transaction.store,
            tender_type: tender_type,
            direction: "refunded",
            status: "authorized",
            amount_cents: amount_cents,
            authorization_code: @authorization_code,
            terminal_reference: @terminal_reference,
            authorized_at: now,
            original_pos_tender: original,
            requires_reconciliation: requires_reconciliation,
            created_by_user: @actor,
            pos_approval: approval
          )

          preparation.update!(
            status: "recorded_tender",
            pos_tender: tender,
            authorization_code: @authorization_code,
            terminal_reference: @terminal_reference,
            authorized_at: now,
            consumed_at: now,
            recorded_by_user: @actor,
            requires_reconciliation: requires_reconciliation,
            reconciliation_reasons: reasons
          )
          audit_reconciliation!(transaction, preparation, tender, reasons) if requires_reconciliation

          Result.new(
            pos_tender: tender,
            preparation: preparation,
            success?: true,
            error: nil,
            warnings: (warnings + reasons).uniq,
            requires_reconciliation: requires_reconciliation
          )
        else
          orphan_reasons = reasons.presence || [ "transaction not open at record time" ]
          preparation.update!(
            status: "recorded_orphan",
            authorization_code: @authorization_code,
            terminal_reference: @terminal_reference,
            authorized_at: now,
            consumed_at: now,
            recorded_by_user: @actor,
            requires_reconciliation: true,
            reconciliation_reasons: orphan_reasons
          )
          Administration::RecordAuditEvent.call(
            actor: @actor,
            organization: transaction.store.organization,
            store: transaction.store,
            action: "pos_card_refund.external_orphan_recorded",
            subject: preparation,
            metadata: {
              "preparation_id" => preparation.id,
              "authorization_code" => @authorization_code,
              "terminal_reference" => @terminal_reference,
              "intended_original_pos_tender_id" => preparation.intended_original_pos_tender_id,
              "amount_cents" => amount_cents,
              "reasons" => orphan_reasons,
              "transaction_status" => transaction.status,
              "abandoned_before_record" => abandoned_before,
              "abandoned_at" => preparation.abandoned_at,
              "abandoned_by_user_id" => preparation.abandoned_by_user_id
            }
          )

          Result.new(
            pos_tender: nil,
            preparation: preparation,
            success?: true,
            error: nil,
            warnings: (warnings + orphan_reasons).uniq,
            requires_reconciliation: true
          )
        end
      end
    rescue IdempotencyConflict => e
      Result.new(
        pos_tender: nil, preparation: @preparation, success?: false, error: e.message,
        warnings: [], requires_reconciliation: false
      )
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(
        pos_tender: nil, preparation: nil, success?: false, error: e.message,
        warnings: [], requires_reconciliation: false
      )
    end

    private

    def replay_result!(preparation)
      same_auth = preparation.authorization_code.to_s == @authorization_code
      same_terminal = preparation.terminal_reference.to_s == @terminal_reference.to_s
      unless same_auth && same_terminal
        raise IdempotencyConflict,
              "preparation already recorded with different authorization data"
      end

      Result.new(
        pos_tender: preparation.pos_tender,
        preparation: preparation,
        success?: true,
        error: nil,
        warnings: Array(preparation.reconciliation_reasons),
        requires_reconciliation: preparation.requires_reconciliation?
      )
    end

    def audit_reconciliation!(transaction, preparation, tender, reasons)
      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: transaction.store.organization,
        store: transaction.store,
        action: "pos_tender.card_refund_requires_reconciliation",
        subject: tender,
        metadata: {
          "preparation_id" => preparation.id,
          "authorization_code" => @authorization_code,
          "reasons" => reasons,
          "amount_cents" => preparation.amount_cents,
          "intended_original_pos_tender_id" => preparation.intended_original_pos_tender_id
        }
      )
    end
  end
end
