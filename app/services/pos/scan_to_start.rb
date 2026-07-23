# frozen_string_literal: true

module Pos
  # Ready-state scan: resolve first, then open + add atomically when resolved.
  # Never leaves an empty open transaction on failure or ambiguity.
  # Concurrent starts serialize on the POS session row and reuse any open txn.
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

      add_resolved_line(resolution)
    end

    private

    def add_resolved_line(resolution)
      add_error = nil

      result = ActiveRecord::Base.transaction(requires_new: true) do
        session = PosSession.lock.find(@pos_session.id)
        unless session.open?
          next failure("POS session is not open.", outcome: "failed")
        end

        transaction = PosTransaction.open_transactions.find_by(active_pos_session_id: session.id)
        unless transaction
          open = OpenTransaction.call(pos_session: session, actor: @actor)
          unless open.success?
            next failure(open.error, outcome: "failed")
          end
          transaction = open.pos_transaction
        end

        add = AddLine.call(
          pos_transaction: transaction,
          product_variant: resolution.variant,
          actor: @actor,
          quantity: @quantity,
          inventory_unit: resolution.inventory_unit
        )
        unless add.success?
          add_error = add.error
          raise ActiveRecord::Rollback
        end

        Result.new(
          success?: true,
          pos_transaction: transaction,
          pos_line_item: add.pos_line_item,
          error: nil,
          outcome: "added",
          resolution: resolution,
          warnings: Array(resolution.warnings) + Array(add.warnings)
        )
      end

      return result if result

      Result.new(
        success?: false,
        pos_transaction: nil,
        pos_line_item: nil,
        error: add_error.presence || "Unable to add line.",
        outcome: "failed",
        resolution: resolution,
        warnings: Array(resolution.warnings)
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
