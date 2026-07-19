# frozen_string_literal: true

module Pos
  # Cancellation releases provisional reservations and creates no completed sale,
  # inventory, tax, or tender effect.
  class CancelTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error)

    def initialize(pos_transaction:, actor:, reason: nil)
      @pos_transaction = pos_transaction
      @actor = actor
      @reason = reason
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        unless %w[open suspended].include?(transaction.status)
          raise Error, "only open or suspended transactions may be cancelled"
        end

        transaction.pos_line_items.pending.where(line_kind: "product").find_each do |line|
          reservation = InventoryReservation.active.find_by(source_type: "pos_line_item", source_id: line.id)
          next if reservation.blank?

          released = Inventory::ReleaseReservation.call(
            reservation: reservation,
            actor: @actor,
            release_reason: @reason || "transaction cancelled"
          )
          raise Error, released.error unless released.success?
        end

        # ADR-0008: cancellation resolves provisional Tender activity (no completed
        # Tender may survive a cancelled Transaction).
        transaction.pos_tenders.unresolved.find_each do |tender|
          removed = Pos::RemoveTender.call(
            pos_tender: tender, actor: @actor, reason: @reason || "transaction cancelled"
          )
          raise Error, removed.error unless removed.success?
        end

        transaction.update!(
          status: "cancelled",
          cancelled_at: Time.current,
          cancelled_by_user: @actor,
          cancel_reason: @reason
        )

        Result.new(pos_transaction: transaction, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: nil, success?: false, error: e.message)
    end
  end
end
