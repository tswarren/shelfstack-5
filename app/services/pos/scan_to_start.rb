# frozen_string_literal: true

module Pos
  # Ready-state first valid work: resolve (scan or explicit variant), then open +
  # add atomically. Never leaves an empty open transaction on failure or ambiguity.
  # Concurrent starts serialize on the POS session row and reuse any open txn.
  class ScanToStart < ApplicationService
    Result = Data.define(
      :success?, :pos_transaction, :pos_line_item, :error, :outcome, :resolution, :warnings
    )

    def initialize(pos_session:, actor:, query: nil, quantity: 1, product_variant_id: nil)
      @pos_session = pos_session
      @actor = actor
      @query = query.to_s.strip
      @quantity = [ quantity.to_i, 1 ].max
      @product_variant_id = product_variant_id.presence
    end

    def call
      return failure("POS session is not open.", outcome: "failed") unless @pos_session.open?

      if @product_variant_id.present?
        start_with_variant_id
      else
        start_with_query
      end
    end

    private

    def start_with_query
      return failure("Scan or search query is required.", outcome: "failed") if @query.blank?

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
          error: "Multiple matches — refine the scan or use Product lookup.",
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

      add_line(
        variant: resolution.variant,
        inventory_unit: resolution.inventory_unit,
        resolution: resolution,
        warnings: Array(resolution.warnings)
      )
    end

    def start_with_variant_id
      variant = ProductVariant.joins(:product)
                              .where(products: { organization_id: @pos_session.store.organization_id })
                              .find_by(id: @product_variant_id)
      return failure("Select a valid product variant.", outcome: "failed") if variant.blank?

      eligibility = Catalog::SaleEligibility.call(variant: variant, store: @pos_session.store)
      if eligibility.blockers.any?
        return Result.new(
          success?: false,
          pos_transaction: nil,
          pos_line_item: nil,
          error: eligibility.blockers.join(", "),
          outcome: "blocked",
          resolution: nil,
          warnings: Array(eligibility.warnings)
        )
      end

      add_line(
        variant: variant,
        inventory_unit: nil,
        resolution: nil,
        warnings: Array(eligibility.warnings)
      )
    end

    def add_line(variant:, inventory_unit:, resolution:, warnings:)
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
        else
          consume = ConsumeStagedCustomer.call(
            pos_session: session,
            pos_transaction: transaction,
            actor: @actor
          )
          if consume.conflict?
            next Result.new(
              success?: false,
              pos_transaction: transaction,
              pos_line_item: nil,
              error: "Staged customer was not attached because this transaction already has a " \
                     "different customer. Resolve the customer on the open transaction before scanning.",
              outcome: "customer_conflict",
              resolution: resolution,
              warnings: []
            )
          end
          transaction.reload
        end

        add = AddLine.call(
          pos_transaction: transaction,
          product_variant: variant,
          actor: @actor,
          quantity: @quantity,
          inventory_unit: inventory_unit
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
          warnings: warnings + Array(add.warnings)
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
        warnings: warnings
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
