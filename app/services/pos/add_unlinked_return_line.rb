# frozen_string_literal: true

module Pos
  # Creates an unlinked customer-return line with explicit refund, tax basis, and
  # (for inventory-affecting quantity-tracked product returns) a confirmed cost basis.
  # Individually tracked variants remain unsupported without a linked original.
  class AddUnlinkedReturnLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings, :pos_approval)

    UNLINKED_SOURCES = PosLineItem::UNLINKED_RETURN_SOURCES
    TAX_BASES = %w[current_configured_rules external_receipt_tax no_tax_refund].freeze
    INVENTORY_AFFECTING_DISPOSITIONS = %w[
      return_to_stock inspection_required damaged return_to_vendor discard
    ].freeze

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
      tax_basis: nil,
      explicit_tax_amount_cents: nil,
      confirm_cost_basis: false,
      confirmed_unit_cost_cents: nil,
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
      @tax_basis = tax_basis.to_s.presence
      @explicit_tax_amount_cents = explicit_tax_amount_cents
      @confirm_cost_basis = ActiveModel::Type::Boolean.new.cast(confirm_cost_basis)
      @confirmed_unit_cost_cents = confirmed_unit_cost_cents
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
      tax_basis = resolve_tax_basis!
      cost_basis = resolve_cost_basis!(line_shape)
      refund_extended_cents = @quantity * @unit_price_cents

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        raise Error, "commercial fields are locked by unresolved tenders" unless transaction.editable?

        approval = authorize_no_receipt!(refund_extended_cents)

        position = (transaction.pos_line_items.maximum(:position) || -1) + 1
        now = Time.current
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
          tax_basis_snapshot: tax_basis.fetch(:basis),
          explicit_tax_amount_cents: tax_basis[:explicit_tax_amount_cents],
          tax_basis_confirmed_by_user_id: @actor.id,
          tax_basis_confirmed_at: now,
          cost_unit_cost_cents: cost_basis&.fetch(:unit_cost_cents),
          cost_extended_cents: cost_basis && (cost_basis.fetch(:unit_cost_cents) * @quantity),
          cost_method_snapshot: cost_basis&.fetch(:method),
          cost_quality_snapshot: cost_basis&.fetch(:quality),
          cost_basis_type_snapshot: cost_basis&.fetch(:basis_type),
          cost_basis_source_snapshot: cost_basis&.fetch(:source),
          cost_proposed_unit_cents: cost_basis&.fetch(:proposed_unit_cents),
          cost_confirmed_unit_cents: cost_basis&.fetch(:unit_cost_cents),
          cost_confirmed_by_user_id: cost_basis && @actor.id,
          cost_confirmed_at: cost_basis && now
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

    def resolve_tax_basis!
      basis = @tax_basis.presence || default_tax_basis_for_source
      raise Error, "tax basis is invalid" unless TAX_BASES.include?(basis)

      explicit = nil
      if basis == "external_receipt_tax"
        explicit = @explicit_tax_amount_cents
        raise Error, "explicit tax amount is required for external receipt tax basis" if explicit.nil?
        raise Error, "explicit tax amount must not be negative" if explicit.to_i.negative?

        explicit = explicit.to_i
      end
      # Ignore leftover currency-field values (often 0.00) unless external_receipt_tax.

      { basis: basis, explicit_tax_amount_cents: explicit }
    end

    def default_tax_basis_for_source
      "current_configured_rules"
    end

    def resolve_cost_basis!(line_shape)
      return nil unless line_shape.fetch(:line_kind) == "product"
      return nil unless INVENTORY_AFFECTING_DISPOSITIONS.include?(@return_disposition)

      variant = line_shape.fetch(:product_variant)
      return nil if variant.inventory_tracking_mode == "none"

      raise Error, "confirm the proposed inventory cost basis before adding this return" unless @confirm_cost_basis

      store = @pos_transaction.store
      balance = StockBalance.find_by(store_id: store.id, product_variant_id: variant.id)
      mac = balance&.moving_average_cost_cents
      if mac.present? && balance.cost_quality.to_s != "unknown"
        proposed = mac
        basis_type = "moving_average"
        method = "moving_average"
        source = "store_stock_balance_mac"
      else
        estimate = Inventory::DepartmentEstimate.call(product_variant: variant)
        unless estimate.available
          raise Error,
                "no inventory cost basis available (MAC and department estimate missing); " \
                "supply an authorized cost basis before inventory-affecting unlinked returns"
        end
        proposed = estimate.unit_cost_cents
        basis_type = "configured_estimate"
        method = "configured_estimate"
        source = "department_estimate"
      end

      confirmed = @confirmed_unit_cost_cents.nil? ? proposed : @confirmed_unit_cost_cents.to_i
      raise Error, "confirmed unit cost must not be negative" if confirmed.negative?

      {
        proposed_unit_cents: proposed,
        unit_cost_cents: confirmed,
        basis_type: basis_type,
        method: method,
        quality: "estimated",
        source: source
      }
    end

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
