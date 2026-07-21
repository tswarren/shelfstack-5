# frozen_string_literal: true

module Purchasing
  # Buyer → Purchase Order seam (ordering-and-acquisition-planning.md,
  # phase-05-supply-and-demand.md build order step 6–7): resolves the exact
  # Product Variant and a vendor source, then adds ordered quantity to a new
  # or existing draft Purchase Order.
  #
  # This service never creates a Purchase-Order Allocation — Allocations
  # commit expected supply only to Customer Requests and are deferred to a
  # later phase (ADR-0015; phase-05 build order step 8). For non-customer
  # requests it optionally resolves the originating Product Request via
  # Requests::ResolveProductRequest ("ordered"); for Customer Requests it adds
  # general demand to a draft PO without closing or allocating the request.
  class AddDemandToDraftPurchaseOrder < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order, :purchase_order_line, :product_request, :success?, :error)

    def initialize(store:, vendor:, quantity:, actor:, product_request: nil, product_variant: nil,
                   product_variant_vendor: nil, purchase_order: nil, cost_entry_method: nil,
                   list_cost_cents: nil, discount_bps: nil, expected_unit_cost_cents: nil,
                   resolve_request: true, resolution_note: nil)
      @store = store
      @vendor = vendor
      @quantity = quantity.to_i
      @actor = actor
      @product_request = product_request
      @product_variant = product_variant || product_request&.product_variant
      @product_variant_vendor = product_variant_vendor
      @purchase_order = purchase_order
      @cost_entry_method = cost_entry_method
      @list_cost_cents = list_cost_cents
      @discount_bps = discount_bps
      @expected_unit_cost_cents = expected_unit_cost_cents
      @resolve_request = ActiveModel::Type::Boolean.new.cast(resolve_request)
      @resolution_note = resolution_note
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "a product variant must be resolved before adding to a purchase order" if @product_variant.blank?
      raise Error, "vendor store mismatch" unless @vendor.organization_id == @store.organization_id
      raise Error, "not permitted to add demand to a purchase order" unless authorized_for_purchase_order?
      if resolving_product_request? && !authorized_for_resolve?
        raise Error, "not permitted to resolve product requests"
      end

      ActiveRecord::Base.transaction do
        store = Store.lock.find(@store.id)
        purchase_order = resolve_purchase_order!(store)
        line = add_line!(purchase_order)

        resolved_request = resolve_product_request!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "purchasing.purchase_order.demand_added",
          subject: purchase_order,
          metadata: {
            "purchase_order_line_id" => line.id,
            "product_variant_id" => @product_variant.id,
            "quantity" => @quantity,
            "product_request_id" => @product_request&.id
          }
        )

        Result.new(purchase_order: purchase_order.reload, purchase_order_line: line,
                   product_request: resolved_request, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order: @purchase_order, purchase_order_line: nil, product_request: @product_request,
                 success?: false, error: e.record.errors.full_messages.to_sentence)
    rescue Error => e
      Result.new(purchase_order: @purchase_order, purchase_order_line: nil, product_request: @product_request,
                 success?: false, error: e.message)
    end

    private

    def resolving_product_request?
      @resolve_request && @product_request.present? && @product_request.non_customer_request?
    end

    def authorized_for_purchase_order?
      permission = @purchase_order.present? ? "purchasing.purchase_order.edit" : "purchasing.purchase_order.create"
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: permission) == :allow
    end

    def authorized_for_resolve?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.product_request.resolve") == :allow
    end

    def resolve_purchase_order!(store)
      if @purchase_order.present?
        po = PurchaseOrder.lock.find(@purchase_order.id)
        raise Error, "purchase order store mismatch" unless po.store_id == store.id
        raise Error, "purchase order vendor mismatch" unless po.vendor_id == @vendor.id
        raise Error, "only draft purchase orders can receive added demand" unless po.draft?
        return po
      end

      existing = PurchaseOrder.lock.where(store_id: store.id, vendor_id: @vendor.id, status: "draft").order(:id).first
      return existing if existing

      # Built independently of `store.purchase_orders` (not the association
      # proxy) so the later `store.update!` for numbering does not cascade
      # autosave-validate this not-yet-numbered record.
      po = PurchaseOrder.new(store: store, vendor: @vendor, status: "draft", currency_code: store.currency_code)
      po.purchase_order_number = next_number!(store)
      po.save!
      po
    end

    def next_number!(store)
      number = store.next_purchase_order_number
      store.update!(next_purchase_order_number: number + 1)
      "#{store.code}-PO-#{number.to_s.rjust(5, '0')}"
    end

    def resolved_vendor_source
      return @product_variant_vendor if @product_variant_vendor.present?

      ProductVariantVendor
        .where(product_variant_id: @product_variant.id, vendor_id: @vendor.id, active: true)
        .order(preferred: :desc, id: :asc)
        .first
    end

    def add_line!(purchase_order)
      source = resolved_vendor_source
      base_position = (purchase_order.purchase_order_lines.maximum(:position) || -1) + 1

      line = purchase_order.purchase_order_lines.build(
        product_variant: @product_variant,
        product_variant_vendor: source,
        ordered_quantity: @quantity,
        position: base_position,
        cost_entry_method: cost_entry_method_for(source),
        list_cost_cents: @list_cost_cents || source&.list_cost_cents,
        discount_bps: @discount_bps || source&.discount_bps,
        expected_unit_cost_cents: @expected_unit_cost_cents || source&.expected_unit_cost_cents
      )
      line.cost_provenance = source.present? ? "vendor_source" : "manual_entry"
      Purchasing::LineSnapshot.apply!(line)
      line.save!
      line
    end

    def cost_entry_method_for(source)
      return @cost_entry_method if @cost_entry_method.present?
      return "discount_from_list" if @list_cost_cents.present? || source&.list_cost_cents.present?

      "direct_net_cost"
    end

    def resolve_product_request!
      return nil unless @product_request.present?
      return @product_request unless resolving_product_request?

      result = Requests::ResolveProductRequest.call(
        product_request: @product_request,
        resolution: "ordered",
        resolved_quantity: @quantity,
        resolution_note: @resolution_note,
        actor: @actor,
        store: @store
      )
      raise Error, "could not resolve product request: #{result.error}" unless result.success?

      result.product_request
    end
  end
end
