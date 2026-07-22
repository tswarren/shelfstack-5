# frozen_string_literal: true

module Pos
  # Records the external terminal confirmation onto a prepared post-void card
  # preparation. After this succeeds, the external fact survives even if
  # PostVoidTransaction later rolls back.
  class RecordPostVoidCardConfirmation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    def initialize(
      preparation:,
      actor:,
      authorization_code: nil,
      terminal_reference: nil,
      external_void_reference: nil
    )
      @preparation = preparation
      @actor = actor
      @authorization_code = authorization_code.to_s.strip.presence
      @terminal_reference = terminal_reference.to_s.strip.presence
      @external_void_reference = external_void_reference.to_s.strip.presence
    end

    def call
      raise Error, "preparation is required" if @preparation.blank?
      raise Error, "at least one confirmation reference is required" if confirmation_blank?

      ActiveRecord::Base.transaction do
        preparation = PosPostVoidCardPreparation.lock.find(@preparation.id)
        if preparation.recorded?
          return replay!(preparation)
        end
        raise Error, "preparation is not recordable (status=#{preparation.status})" unless preparation.prepared?

        original = PosTransaction.lock.find(preparation.original_pos_transaction_id)
        raise Error, "original transaction already post-voided" if original.post_voided?

        unless Authorization::EvaluatePermission.call(
          user: @actor, store: preparation.store, permission_key: "pos.post_void.create"
        ) == :allow
          raise Error, "missing permission pos.post_void.create"
        end

        now = Time.current
        preparation.update!(
          status: "recorded",
          authorization_code: @authorization_code || preparation_id_fallback(preparation),
          terminal_reference: @terminal_reference,
          external_void_reference: @external_void_reference,
          authorized_at: now,
          recorded_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: preparation.store.organization,
          store: preparation.store,
          action: "pos_post_void_card.recorded",
          subject: preparation,
          metadata: {
            "original_pos_transaction_id" => preparation.original_pos_transaction_id,
            "original_pos_tender_id" => preparation.original_pos_tender_id,
            "authorization_code" => preparation.authorization_code,
            "terminal_reference" => preparation.terminal_reference,
            "external_void_reference" => preparation.external_void_reference
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end

    private

    def confirmation_blank?
      @authorization_code.blank? && @terminal_reference.blank? && @external_void_reference.blank?
    end

    # State shape requires authorization_code on recorded; use a durable stand-in
    # when the operator only captured a terminal/void reference.
    def preparation_id_fallback(preparation)
      "ext-ref:#{@external_void_reference || @terminal_reference || preparation.id}"
    end

    def replay!(preparation)
      same =
        preparation.authorization_code.to_s == (@authorization_code || preparation.authorization_code).to_s &&
        preparation.terminal_reference.to_s == @terminal_reference.to_s &&
        preparation.external_void_reference.to_s == @external_void_reference.to_s
      raise Error, "preparation already recorded with different confirmation data" unless same

      Result.new(preparation: preparation, success?: true, error: nil)
    end
  end
end
