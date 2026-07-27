# frozen_string_literal: true

module Pos
  # Creates an unlinked customer-return line with an explicit refund and tax basis.
  # Supports product (quantity/none tracking) and open-ring merchandise. Individually
  # tracked variants are rejected in this Must slice (unit restoration needs a sold link).
  class AddUnlinkedReturnLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings, :pos_approval)

    UNLINKED_SOURCES = PosLineItem::UNLINKED_RETURN_SOURCES

    def initialize(
      pos_transaction:,
      return_source:,
      return_reason:,
      return_disposition:,
      actor:,
      unit_price_cents:,
      quantity: 1,
      product_variant: nil,
      department: nil,
      description: nil,
      tax_category: nil,
      approver: nil,
      approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @return_source = return_source.to_s
      @return_reason = return_reason
      @return_disposition = return_disposition.to_s
      @actor = actor
      @quantity = quantity.to_i
      @unit_price_cents = unit_price_cents.to_i
      @product_variant = product_variant
      @department = department
      @description = description
      @tax_category = tax_category
      @approver = approver
      @approver_pin = approver_pin
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "refund unit price must not be negative" if @unit_price_cents.negative?
      raise Error, "return disposition is invalid" unless PosLineItem::RETURN_DISPOSITIONS.include?(@return_disposition)
      raise Error, "return source is invalid" unless UNLINKED_SOURCES.include?(@return_source)
      raise Error, "return reason is required" if @return_reason.blank?

      unless Authorization::EvaluatePermission.call(
        user: @actor, store: @pos_transaction.store, permission_key: "pos.return.create"
      ) == :allow
        raise Error, "missing permission pos.return.create"
      end

      line_shape = resolve_line_shape!
      refund_extended_cents = @quantity * @unit_price_cents
      approval = authorize_no_receipt!(refund_extended_cents)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        raise Error, "commercial fields are locked by unresolved tenders" unless transaction.editable?

        position = (transaction.pos_line_items.maximum(:position) || -1) + 1
        line = transaction.pos_line_items.create!(
          status: "pending",
          direction: "return",
          line_kind: line_shape.fetch(:line_kind),
          position: position,
          product_variant: line_shape[:product_variant],
          department: line_shape.fetch(:department),
          tax_category: line_shape.fetch(:tax_category),
          description_snapshot: line_shape.fetch(:description_snapshot),
          identifier_snapshot: line_shape[:identifier_snapshot],
          quantity: @quantity,
          unit_price_cents: @unit_price_cents,
          return_reason: @return_reason,
          return_disposition: @return_disposition,
          return_source: @return_source,
          created_by_user: @actor,
          cost_unit_cost_cents: 0,
          cost_extended_cents: 0,
          cost_method_snapshot: "unknown",
          cost_quality_snapshot: "unknown"
        )

        recalc = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        Result.new(
          pos_line_item: line,
          success?: true,
          error: nil,
          warnings: recalc.blockers + recalc.warnings,
          pos_approval: approval
        )
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [], pos_approval: nil)
    end

    private

    def resolve_line_shape!
      if @product_variant.present?
        raise Error, "open-ring department cannot be combined with a product variant" if @department.present?

        variant = @product_variant
        if variant.inventory_tracking_mode == "individual"
          raise Error, "individually tracked variants require a linked return"
        end

        classification = Catalog::ResolveClassification.call(product: variant.product, variant: variant)
        department = classification.department
        raise Error, "no postable department resolved for variant" if department.blank?
        raise Error, "department must be postable" unless department.postable?

        tax_category = @tax_category || classification.tax_category
        raise Error, "tax category is required" if tax_category.blank?

        {
          line_kind: "product",
          product_variant: variant,
          department: department,
          tax_category: tax_category,
          description_snapshot: variant.product.name,
          identifier_snapshot: variant.product.identifier.presence || variant.sku
        }
      else
        department = @department
        raise Error, "department is required for open-ring returns" if department.blank?
        raise Error, "department must be postable" unless department.postable?
        raise Error, "department must be active" unless department.active?
        unless department.organization_id == @pos_transaction.store.organization_id
          raise Error, "department must belong to the transaction's organization"
        end

        tax_category = @tax_category || department.default_tax_category
        raise Error, "tax category is required" if tax_category.blank?

        {
          line_kind: "open_ring",
          product_variant: nil,
          department: department,
          tax_category: tax_category,
          description_snapshot: @description.presence || department.name,
          identifier_snapshot: nil
        }
      end
    end

    def authorize_no_receipt!(refund_extended_cents)
      return nil unless @return_source == "no_receipt"

      auth = Pos::AuthorizeAction.call(
        store: @pos_transaction.store,
        requester: @actor,
        permission_key: "pos.return.no_receipt",
        action_type: "no_receipt_return",
        reason: "No-receipt return",
        limit_key: :maximum_no_receipt_return_cents,
        requested_value: refund_extended_cents,
        approver: @approver,
        approver_pin: @approver_pin,
        pos_transaction: @pos_transaction
      )
      return auth.pos_approval if auth.allowed?

      raise Error, auth.error.presence || "no-receipt return requires approval"
    end
  end
end
