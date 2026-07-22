# frozen_string_literal: true

module Pos
  # Resolves a recorded_orphan external card refund with an explicit outcome.
  class ResolveCardRefundOrphan < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    KINDS = %i[
      external_void_confirmed
      linked_to_correcting_transaction
      accepted_financial_exception
    ].freeze

    def initialize(
      preparation:,
      actor:,
      resolution_kind:,
      reason:,
      external_void_reference: nil,
      correcting_pos_transaction: nil
    )
      @preparation = preparation
      @actor = actor
      @resolution_kind = resolution_kind.to_sym
      @reason = reason.to_s.strip
      @external_void_reference = external_void_reference.presence
      @correcting_pos_transaction = correcting_pos_transaction
    end

    def call
      raise Error, "unsupported resolution kind" unless KINDS.include?(@resolution_kind)
      raise Error, "resolution reason is required" if @reason.blank?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@preparation.pos_transaction_id)
        preparation = PosCardRefundPreparation.lock.find(@preparation.id)
        raise Error, "preparation is not an unresolved orphan" unless preparation.unresolved_orphan?

        case @resolution_kind
        when :external_void_confirmed
          assert_permission!(transaction.store, "pos.tender.card_void")
          raise Error, "external void reference is required" if @external_void_reference.blank?
        when :linked_to_correcting_transaction
          assert_permission!(transaction.store, "pos.tender.card_standalone")
          correcting = @correcting_pos_transaction
          raise Error, "correcting transaction is required" if correcting.blank?
          unless correcting.store_id == transaction.store_id
            raise Error, "correcting transaction must belong to the same store"
          end
          raise Error, "correcting transaction must be completed" unless correcting.completed?
        when :accepted_financial_exception
          assert_permission!(transaction.store, "pos.tender.card_standalone")
        end

        preparation.update!(
          resolution_kind: @resolution_kind.to_s,
          resolved_at: Time.current,
          resolved_by_user: @actor,
          resolution_reason: @reason,
          external_void_reference: @external_void_reference,
          correcting_pos_transaction: @correcting_pos_transaction,
          requires_reconciliation: false
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: transaction.store.organization,
          store: transaction.store,
          action: "pos_card_refund.orphan_resolved",
          subject: preparation,
          metadata: {
            "preparation_id" => preparation.id,
            "resolution_kind" => @resolution_kind.to_s,
            "reason" => @reason,
            "external_void_reference" => @external_void_reference,
            "correcting_pos_transaction_id" => @correcting_pos_transaction&.id,
            "intended_original_pos_tender_id" => preparation.intended_original_pos_tender_id,
            "authorization_code" => preparation.authorization_code
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end

    private

    def assert_permission!(store, key)
      unless Authorization::EvaluatePermission.call(
        user: @actor, store: store, permission_key: key
      ) == :allow
        raise Error, "missing permission #{key}"
      end
    end
  end
end
