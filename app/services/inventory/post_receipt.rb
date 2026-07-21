# frozen_string_literal: true

module Inventory
  # Atomically posts a draft Receipt: only accepted quantity ever enters
  # inventory (rejected never does). Quantity-tracked lines settle open
  # negative On Hand before creating positive inventory (OD-014); individual
  # lines create one Inventory Unit per accepted unit. Linked lines advance
  # the Purchase Order Line's received_quantity; PO-line allocation
  # conversion is a later phase (5f) concern and is not performed here.
  #
  # Idempotent — the whole posting runs in one transaction, so a failure
  # leaves no partial ledger, unit, or Purchase-Order-line effect; replaying
  # an already-posted Receipt is a no-op success (posting_key/posted_at are
  # only ever assigned once, at successful completion).
  class PostReceipt < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:receipt, :success?, :error, :replayed)

    def initialize(receipt:, actor:, store:)
      @receipt = receipt
      @actor = actor
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @receipt.reload.lock!

        if @receipt.posted?
          return Result.new(receipt: @receipt, success?: true, error: nil, replayed: true)
        end

        raise Error, "only draft receipts can be posted" unless @receipt.draft?
        raise Error, "receipt store mismatch" unless @receipt.store_id == @store.id
        authorize_post!

        lines = @receipt.receipt_lines.to_a.sort_by { |line| [ line.product_variant_id, line.position, line.id ] }
        raise Error, "receipt must have at least one line" if lines.empty?

        lines.each { |line| authorize_line!(line) }

        posted_at = Time.current
        posting_key = "receipt:#{@receipt.id}"

        lines.each { |line| post_line!(line, posting_key: posting_key, posted_at: posted_at) }

        @receipt.update!(
          status: "posted",
          posting_key: posting_key,
          posted_by_user: @actor,
          posted_at: posted_at
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "inventory.receipt.posted",
          subject: @receipt,
          metadata: {
            "receipt_number" => @receipt.receipt_number,
            "vendor_id" => @receipt.vendor_id,
            "line_count" => lines.size,
            "posting_key" => posting_key
          }
        )

        Result.new(receipt: @receipt, success?: true, error: nil, replayed: false)
      end
    rescue Error, PostLedgerEntry::Error, CreateInventoryUnit::Error, ArgumentError => e
      Result.new(receipt: @receipt, success?: false, error: e.message, replayed: false)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(receipt: @receipt, success?: false, error: e.record.errors.full_messages.to_sentence, replayed: false)
    end

    private

    def authorize_post!
      return if Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.receipt.post") == :allow

      raise Error, "not permitted to post receipts"
    end

    def authorize_line!(line)
      raise Error, "receipt line #{line.position} is invalid: #{line.errors.full_messages.to_sentence}" unless line.valid?

      po_line = line.purchase_order_line
      if po_line.blank?
        unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.receipt.receive_unlinked") == :allow
          raise Error, "not permitted to receive line #{line.position} without a purchase order line"
        end
      elsif line.accepted_quantity > po_line.open_quantity
        unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.receipt.over_receive") == :allow
          raise Error, "not permitted to over-receive line #{line.position}"
        end
      end
    end

    def post_line!(line, posting_key:, posted_at:)
      variant = line.product_variant
      raise Error, "line #{line.position}: variant/store organization mismatch" unless variant.organization.id == @store.organization_id

      case variant.inventory_tracking_mode
      when "quantity"
        post_quantity_line!(line, variant, posting_key: posting_key, posted_at: posted_at)
      when "individual"
        post_individual_line!(line, variant, posted_at: posted_at)
      else
        raise Error, "line #{line.position}: variant is not inventory-tracked and cannot be received"
      end

      update_purchase_order_line!(line)
    end

    def post_quantity_line!(line, variant, posting_key:, posted_at:)
      return if line.accepted_quantity.zero?

      unit_cost_cents, cost_method, cost_quality = receipt_cost_inputs(line)
      balance = FindOrCreateStockBalance.call(store: @store, product_variant: variant)
      open_deficit_quantity = balance.open_deficit_quantity
      settlement_quantity = [ line.accepted_quantity, open_deficit_quantity ].min
      positive_quantity = line.accepted_quantity - settlement_quantity

      line_key = "#{posting_key}:line:#{line.id}"
      final_balance = balance

      if settlement_quantity.positive?
        result = PostLedgerEntry.call(
          store: @store,
          product_variant: variant,
          movement_type: "receipt_deficit_settlement",
          quantity_delta: settlement_quantity,
          source: line,
          posting_key: "#{line_key}:settlement",
          posted_by_user: @actor,
          posted_at: posted_at,
          incoming_unit_cost_cents: unit_cost_cents,
          incoming_cost_method: cost_method,
          incoming_cost_quality: cost_quality
        )
        final_balance = result.stock_balance
      end

      if positive_quantity.positive?
        result = PostLedgerEntry.call(
          store: @store,
          product_variant: variant,
          movement_type: "receipt",
          quantity_delta: positive_quantity,
          source: line,
          posting_key: "#{line_key}:receipt",
          posted_by_user: @actor,
          posted_at: posted_at,
          incoming_unit_cost_cents: unit_cost_cents,
          incoming_cost_method: cost_method,
          incoming_cost_quality: cost_quality
        )
        final_balance = result.stock_balance
      end

      if line.accepted_unavailable_quantity.to_i.positive?
        final_balance.update!(unavailable: final_balance.unavailable + line.accepted_unavailable_quantity)
      end
    end

    def post_individual_line!(line, variant, posted_at:)
      return if line.accepted_quantity.zero?

      unit_cost_cents, = receipt_cost_inputs(line)
      sellable = line.sellable_accepted_quantity
      unavailable = line.accepted_unavailable_quantity.to_i

      sellable.times { create_unit!(line, variant, unit_cost_cents, "available", posted_at) }
      unavailable.times { create_unit!(line, variant, unit_cost_cents, "inspection", posted_at) }
    end

    def create_unit!(line, variant, unit_cost_cents, status, posted_at)
      result = CreateInventoryUnit.call(
        store: @store,
        product_variant: variant,
        actor: @actor,
        acquisition_cost_cents: unit_cost_cents,
        acquisition_source_type: "receipt_line",
        acquisition_source_id: line.id,
        acquired_at: @receipt.received_at || posted_at,
        require_unit_manage_permission: false
      )
      raise Error, "line #{line.position}: #{result.error}" unless result.success?

      result.inventory_unit.update!(status: status) unless status == "available"
    end

    # OD-014 "Unknown receipt cost": actual cost → confirmed vendor cost →
    # PO expected cost as an estimate → unknown. `confirmed_zero` is a known
    # actual cost of zero, distinct from a missing (unknown) cost.
    def receipt_cost_inputs(line)
      case line.cost_quality
      when "confirmed_zero"
        [ 0, "explicit", "actual" ]
      when "actual", "estimated"
        if line.actual_unit_cost_cents.present?
          [ line.actual_unit_cost_cents, "explicit", line.cost_quality ]
        else
          [ nil, "unknown", "unknown" ]
        end
      else
        [ nil, "unknown", "unknown" ]
      end
    end

    def update_purchase_order_line!(line)
      po_line = line.purchase_order_line
      return if po_line.blank?

      locked = PurchaseOrderLine.lock.find(po_line.id)
      locked.update!(received_quantity: locked.received_quantity + line.accepted_quantity)
    end
  end
end
