# frozen_string_literal: true

module Pos
  # Ready-state scan: resolve first, then open + add atomically when resolved.
  # Never leaves an empty open transaction on failure or ambiguity.
  class ScanToStart < ApplicationService
    Result = Data.define(
      :success?, :pos_transaction, :pos_line_item, :error, :outcome, :resolution, :warnings
    )

    def initialize(pos_session:, actor:, query:, quantity: 1)
      @pos_session = pos_session
      @actor = actor
      @query = query.to_s.strip
      @quantity = [ quantity.to_i, 1 ].max
    end

    def call
      return failure("Scan or search query is required.", outcome: "failed") if @query.blank?
      return failure("POS session is not open.", outcome: "failed") unless @pos_session.open?

      existing = PosTransaction.open_transactions.find_by(active_pos_session: @pos_session)
      if existing
        return add_to_existing(existing)
      end

      resolution = ResolveScan.call(
        organization: @pos_session.store.organization,
        query: @query,
        store: @pos_session.store
      )

      if resolution.error == "ambiguous_match" || resolution.ambiguous
        return Result.new(
          success?: false,
          pos_transaction: nil,
          pos_line_item: nil,
          error: "Multiple matches — open a transaction to resolve.",
          outcome: "ambiguous",
          resolution: resolution,
          warnings: []
        )
      end

      unless resolution.resolved?
        return Result.new(
          success?: false,
          pos_transaction: nil,
          pos_line_item: nil,
          error: resolution.error.presence || "No match for that scan.",
          outcome: "failed",
          resolution: resolution,
          warnings: resolution.warnings
        )
      end

      if resolution.blockers.any?
        return Result.new(
          success?: false,
          pos_transaction: nil,
          pos_line_item: nil,
          error: resolution.blockers.join(", "),
          outcome: "blocked",
          resolution: resolution,
          warnings: resolution.warnings
        )
      end

      ActiveRecord::Base.transaction(requires_new: true) do
        open = OpenTransaction.call(pos_session: @pos_session, actor: @actor)
        unless open.success?
          raise StandardError, open.error
        end

        add = AddLine.call(
          pos_transaction: open.pos_transaction,
          product_variant: resolution.variant,
          actor: @actor,
          quantity: @quantity,
          inventory_unit: resolution.inventory_unit
        )
        unless add.success?
          # Roll back the open transaction created in this requires_new block.
          raise StandardError, add.error
        end

        Result.new(
          success?: true,
          pos_transaction: open.pos_transaction,
          pos_line_item: add.pos_line_item,
          error: nil,
          outcome: "added",
          resolution: resolution,
          warnings: Array(resolution.warnings) + Array(add.warnings)
        )
      end
    rescue StandardError => e
      # Ensure no empty open txn remains for this session after a failed start.
      leftover = PosTransaction.open_transactions.find_by(active_pos_session: @pos_session)
      if leftover&.pos_line_items&.pending&.none?
        Pos::CancelTransaction.call(pos_transaction: leftover, actor: @actor, reason: "scan_to_start_failed")
      end

      Result.new(
        success?: false,
        pos_transaction: nil,
        pos_line_item: nil,
        error: e.message,
        outcome: "failed",
        resolution: nil,
        warnings: []
      )
    end

    private

    def add_to_existing(transaction)
      resolution = ResolveScan.call(
        organization: @pos_session.store.organization,
        query: @query,
        store: @pos_session.store
      )

      unless resolution.resolved?
        return Result.new(
          success?: false,
          pos_transaction: transaction,
          pos_line_item: nil,
          error: resolution.error.presence || "No match for that scan.",
          outcome: resolution.ambiguous ? "ambiguous" : "failed",
          resolution: resolution,
          warnings: resolution.warnings
        )
      end

      if resolution.blockers.any?
        return Result.new(
          success?: false,
          pos_transaction: transaction,
          pos_line_item: nil,
          error: resolution.blockers.join(", "),
          outcome: "blocked",
          resolution: resolution,
          warnings: resolution.warnings
        )
      end

      add = AddLine.call(
        pos_transaction: transaction,
        product_variant: resolution.variant,
        actor: @actor,
        quantity: @quantity,
        inventory_unit: resolution.inventory_unit
      )

      Result.new(
        success?: add.success?,
        pos_transaction: transaction,
        pos_line_item: add.pos_line_item,
        error: add.error,
        outcome: add.success? ? "added" : "failed",
        resolution: resolution,
        warnings: Array(resolution.warnings) + Array(add.warnings)
      )
    end

    def failure(message, outcome:)
      Result.new(
        success?: false,
        pos_transaction: nil,
        pos_line_item: nil,
        error: message,
        outcome: outcome,
        resolution: nil,
        warnings: []
      )
    end
  end
end
