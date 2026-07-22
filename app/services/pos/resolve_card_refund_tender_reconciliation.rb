# frozen_string_literal: true

module Pos
  # Resolves an authorized card-refund tender that requires reconciliation.
  # Outcomes are explicit — there is no generic "clear" flag.
  class ResolveCardRefundTenderReconciliation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :preparation, :success?, :error)

    OUTCOMES = %i[externally_voided validated_and_accepted replaced].freeze

    def initialize(
      preparation: nil,
      pos_tender: nil,
      actor:,
      outcome:,
      reason:,
      external_void_reference: nil
    )
      @preparation = preparation
      @pos_tender = pos_tender
      @actor = actor
      @outcome = outcome.to_sym
      @reason = reason.to_s.strip
      @external_void_reference = external_void_reference.presence
    end

    def call
      raise Error, "unsupported outcome" unless OUTCOMES.include?(@outcome)
      raise Error, "resolution reason is required" if @reason.blank?

      ActiveRecord::Base.transaction do
        preparation = resolve_preparation!
        transaction = PosTransaction.lock.find(preparation.pos_transaction_id)
        preparation = PosCardRefundPreparation.lock.find(preparation.id)
        tender = PosTender.lock.find(preparation.pos_tender_id)

        raise Error, "preparation is not a recorded tender" unless preparation.recorded_tender?
        raise Error, "tender does not require reconciliation" unless tender.requires_reconciliation?
        raise Error, "tender is not authorized" unless tender.authorized?
        unless %w[open suspended].include?(transaction.status)
          raise Error, "transaction must be open or suspended to resolve tender reconciliation"
        end

        case @outcome
        when :externally_voided, :replaced
          void_tender!(tender)
          preparation.update!(
            resolution_kind: @outcome.to_s,
            resolved_at: Time.current,
            resolved_by_user: @actor,
            resolution_reason: @reason,
            external_void_reference: @external_void_reference,
            requires_reconciliation: false
          )
        when :validated_and_accepted
          assert_permission!(tender.store, "pos.tender.card_standalone")
          bind_original = preparation.intended_original_pos_tender
          # Do not re-check remaining capacity — this tender already consumes it.
          if bind_original.present?
            assert_bindable_original!(transaction, bind_original)
          end
          tender.update!(
            requires_reconciliation: false,
            original_pos_tender: bind_original || tender.original_pos_tender
          )
          preparation.update!(
            resolution_kind: "validated_and_accepted",
            resolved_at: Time.current,
            resolved_by_user: @actor,
            resolution_reason: @reason,
            requires_reconciliation: false,
            reconciliation_reasons: []
          )
        end

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: transaction.store.organization,
          store: transaction.store,
          action: "pos_card_refund.tender_reconciliation_resolved",
          subject: preparation,
          metadata: {
            "preparation_id" => preparation.id,
            "pos_tender_id" => tender.id,
            "outcome" => @outcome.to_s,
            "reason" => @reason,
            "external_void_reference" => @external_void_reference
          }
        )

        Result.new(pos_tender: tender.reload, preparation: preparation, success?: true, error: nil)
      end
    rescue Error, CardRefundSupport::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, preparation: nil, success?: false, error: e.message)
    end

    private

    def resolve_preparation!
      if @preparation
        @preparation
      elsif @pos_tender
        prep = PosCardRefundPreparation.find_by!(pos_tender_id: @pos_tender.id)
        prep
      else
        raise Error, "preparation or pos_tender is required"
      end
    end

    def void_tender!(tender)
      removed = RemoveTender.call(
        pos_tender: tender,
        actor: @actor,
        reason: @reason,
        external_void_confirmed: true,
        external_void_reference: @external_void_reference
      )
      raise Error, removed.error unless removed.success?
    end

    def assert_permission!(store, key)
      unless Authorization::EvaluatePermission.call(
        user: @actor, store: store, permission_key: key
      ) == :allow
        raise Error, "missing permission #{key}"
      end
    end

    def assert_bindable_original!(transaction, original)
      original_txn = PosTransaction.find(original.pos_transaction_id)
      raise Error, "original tender's transaction has been post-voided" if original_txn.post_voided?
      unless CardRefundSupport.linked_original_transaction?(transaction, original_txn)
        raise Error, "original tender is not linked to this return transaction"
      end
      raise Error, "original tender is not completed" unless original.completed?
      raise Error, "original tender must be card" unless original.tender_type.tender_category == "card"
    end
  end
end
