# frozen_string_literal: true

module Inventory
  # Atomically posts a draft Receipt: only accepted quantity ever enters
  # inventory (rejected never does). Quantity-tracked lines settle open
  # negative On Hand before creating positive inventory (OD-014); individual
  # lines create one Inventory Unit per accepted unit. Linked lines advance
  # the Purchase Order Line's received_quantity and (quantity-tracked only)
  # convert applicable Purchase-Order Allocations into Inventory Reservations
  # (Phase 5f, OD-007 — see below).
  #
  # Posting is receipt-level and PO-Line-grouped:
  # lock Receipt → POs → PO Lines → Product Requests → snapshot costs →
  # inventory → aggregate received_quantity → reserve → lock Allocations →
  # append conversion events → release. Allocations are locked last.
  #
  # Idempotent — the whole posting runs in one transaction, so a failure
  # leaves no partial ledger, unit, or Purchase-Order-line effect; replaying
  # an already-posted Receipt is a no-op success (posting_key/posted_at are
  # only ever assigned once, at successful completion).
  class PostReceipt < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:receipt, :success?, :error, :replayed)
    ConversionPlanEntry = Data.define(
      :allocation_id, :product_request_id, :receipt_line_id, :quantity, :inventory_unit_id
    )

    PRIORITY_RANK = { "urgent" => 0, "high" => 1, "normal" => 2 }.freeze

    # Test hook: invoked immediately before Purchase Order Line locks are taken.
    # Used by concurrency tests to force overlapping lock contention.
    class << self
      attr_accessor :before_po_line_lock
    end

    def initialize(receipt:, actor:, store:)
      @receipt = receipt
      @actor = actor
      @store = store
      @resolved_costs = {}
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
        lines.each { |line| validate_line_shape!(line) }

        grouped = lines.group_by(&:purchase_order_line_id)
        authorize_unlinked_lines!(grouped[nil])
        locked_po_lines = lock_and_validate_purchase_order_lines!(grouped)
        lock_allocation_product_requests!(locked_po_lines.keys)

        snapshot_resolved_costs!(lines)

        posted_at = Time.current
        posting_key = "receipt:#{@receipt.id}"

        lines.each { |line| post_inventory_line!(line, posting_key: posting_key, posted_at: posted_at) }
        update_received_quantities!(grouped, locked_po_lines)
        convert_allocations!(grouped, locked_po_lines, posted_at: posted_at)
        release_unbacked_allocations!(locked_po_lines, posted_at: posted_at)

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

    def validate_line_shape!(line)
      raise Error, "receipt line #{line.position} is invalid: #{line.errors.full_messages.to_sentence}" unless line.valid?

      variant = line.product_variant
      raise Error, "line #{line.position}: variant/store organization mismatch" unless variant.organization.id == @store.organization_id
      unless %w[quantity individual].include?(variant.inventory_tracking_mode)
        raise Error, "line #{line.position}: variant is not inventory-tracked and cannot be received"
      end
    end

    def authorize_unlinked_lines!(unlinked_lines)
      Array(unlinked_lines).each do |line|
        next if Authorization::EvaluatePermission.call(
          user: @actor, store: @store, permission_key: "inventory.receipt.receive_unlinked"
        ) == :allow

        raise Error, "not permitted to receive line #{line.position} without a purchase order line"
      end
    end

    def lock_and_validate_purchase_order_lines!(grouped)
      po_line_ids = grouped.keys.compact.sort
      return {} if po_line_ids.empty?

      po_ids = PurchaseOrderLine.where(id: po_line_ids).distinct.pluck(:purchase_order_id).sort
      po_ids.each { |id| PurchaseOrder.lock.find(id) }
      self.class.before_po_line_lock&.call
      locked = po_line_ids.index_with { |id| PurchaseOrderLine.lock.find(id) }

      locked.each do |po_line_id, po_line|
        raise Error, "purchase order line #{po_line_id} store mismatch" unless po_line.purchase_order.store_id == @store.id
        unless po_line.purchase_order.ordered?
          raise Error, "purchase order #{po_line.purchase_order.purchase_order_number} is not ordered"
        end

        group_lines = grouped.fetch(po_line_id)
        aggregate_accepted = group_lines.sum(&:accepted_quantity)
        next if aggregate_accepted <= po_line.open_quantity

        unless Authorization::EvaluatePermission.call(
          user: @actor, store: @store, permission_key: "inventory.receipt.over_receive"
        ) == :allow
          raise Error, "not permitted to over-receive purchase order line #{po_line_id}"
        end
      end

      locked
    end

    def lock_allocation_product_requests!(po_line_ids)
      return if po_line_ids.blank?

      request_ids = PurchaseOrderAllocation.where(purchase_order_line_id: po_line_ids)
        .distinct.pluck(:product_request_id).sort
      request_ids.each { |id| ProductRequest.lock.find(id) }
    end

    def snapshot_resolved_costs!(lines)
      lines.each do |line|
        resolved = ResolveReceiptLineCost.call(receipt_line: line)
        line.update!(
          actual_unit_cost_cents: resolved.unit_cost_cents,
          cost_quality: resolved.cost_quality,
          cost_provenance: resolved.cost_provenance
        )
        @resolved_costs[line.id] = resolved
      end
    end

    def post_inventory_line!(line, posting_key:, posted_at:)
      variant = line.product_variant
      case variant.inventory_tracking_mode
      when "quantity"
        post_quantity_line!(line, variant, posting_key: posting_key, posted_at: posted_at)
      when "individual"
        post_individual_line!(line, variant, posted_at: posted_at)
      end
    end

    def post_quantity_line!(line, variant, posting_key:, posted_at:)
      return if line.accepted_quantity.zero?

      unit_cost_cents, cost_method, cost_quality = receipt_cost_inputs(line)
      balance = FindOrCreateStockBalance.call(store: @store, product_variant: variant)
      open_deficit_quantity = balance.open_deficit_quantity
      settlement_quantity = [ line.accepted_quantity, open_deficit_quantity ].min
      positive_quantity = line.accepted_quantity - settlement_quantity
      sellable_positive_quantity = [ line.sellable_accepted_quantity, positive_quantity ].min
      unavailable_positive_quantity = positive_quantity - sellable_positive_quantity

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
          incoming_cost_quality: cost_quality,
          unavailable_delta: unavailable_positive_quantity,
          availability_reason: unavailable_positive_quantity.positive? ? "accepted_unavailable" : nil
        )
        final_balance = result.stock_balance
      end

      line.define_singleton_method(:positive_sellable_quantity_for_conversion) { sellable_positive_quantity }
    end

    def post_individual_line!(line, variant, posted_at:)
      return if line.accepted_quantity.zero?

      unit_cost_cents, = receipt_cost_inputs(line)
      sellable = line.sellable_accepted_quantity
      unavailable = line.accepted_unavailable_quantity.to_i
      created_sellable = []

      sellable.times do
        created_sellable << create_unit!(line, variant, unit_cost_cents, "available", posted_at)
      end
      unavailable.times { create_unit!(line, variant, unit_cost_cents, "inspection", posted_at) }

      line.define_singleton_method(:created_sellable_units_for_conversion) { created_sellable }
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
      result.inventory_unit
    end

    def receipt_cost_inputs(line)
      resolved = @resolved_costs.fetch(line.id)
      [
        resolved.unit_cost_cents,
        resolved.ledger_cost_method,
        resolved.ledger_cost_quality
      ]
    end

    def update_received_quantities!(grouped, locked_po_lines)
      locked_po_lines.each do |po_line_id, po_line|
        aggregate = grouped.fetch(po_line_id).sum(&:accepted_quantity)
        next if aggregate.zero?

        po_line.update!(received_quantity: po_line.received_quantity + aggregate)
      end
    end

    def convert_allocations!(grouped, locked_po_lines, posted_at:)
      locked_po_lines.each do |po_line_id, po_line|
        group_lines = grouped.fetch(po_line_id)
        variant = po_line.product_variant
        case variant.inventory_tracking_mode
        when "quantity"
          convert_quantity_allocations!(po_line, group_lines, variant, posted_at: posted_at)
        when "individual"
          convert_individual_allocations!(po_line, group_lines, variant, posted_at: posted_at)
        end
      end
    end

    def convert_quantity_allocations!(po_line, group_lines, variant, posted_at:)
      slices = group_lines.filter_map do |line|
        qty = if line.respond_to?(:positive_sellable_quantity_for_conversion)
          line.positive_sellable_quantity_for_conversion
        else
          line.sellable_accepted_quantity
        end
        next if qty.to_i <= 0

        { receipt_line: line, remaining: qty.to_i }
      end
      return if slices.blank?

      plan = build_quantity_conversion_plan(po_line, slices)
      return if plan.blank?

      execute_conversion_plan!(plan, variant: variant, posted_at: posted_at, individual: false)
    end

    def convert_individual_allocations!(po_line, group_lines, variant, posted_at:)
      unit_pairs = group_lines.flat_map do |line|
        units = line.respond_to?(:created_sellable_units_for_conversion) ? line.created_sellable_units_for_conversion : []
        units.map { |unit| { inventory_unit: unit, receipt_line: line } }
      end
      return if unit_pairs.blank?

      plan = build_individual_conversion_plan(po_line, unit_pairs)
      return if plan.blank?

      execute_conversion_plan!(plan, variant: variant, posted_at: posted_at, individual: true)
    end

    def build_quantity_conversion_plan(po_line, slices)
      plan = []
      working_slices = slices.map { |s| s.dup }

      convertible_allocations(po_line).each do |allocation|
        break if working_slices.all? { |s| s[:remaining] <= 0 }

        product_request = ProductRequest.find(allocation.product_request_id)
        next unless product_request.open?
        next unless product_request.compatible_with_variant?(po_line.product_variant)

        remaining_on_allocation = allocation.remaining_quantity
        next unless remaining_on_allocation.positive?

        working_slices.each do |slice|
          break unless remaining_on_allocation.positive?
          next unless slice[:remaining].positive?

          qty = [ remaining_on_allocation, slice[:remaining] ].min
          plan << ConversionPlanEntry.new(
            allocation_id: allocation.id,
            product_request_id: product_request.id,
            receipt_line_id: slice[:receipt_line].id,
            quantity: qty,
            inventory_unit_id: nil
          )
          slice[:remaining] -= qty
          remaining_on_allocation -= qty
        end
      end

      plan
    end

    def build_individual_conversion_plan(po_line, unit_pairs)
      plan = []
      pair_index = 0

      convertible_allocations(po_line).each do |allocation|
        break if pair_index >= unit_pairs.size

        product_request = ProductRequest.find(allocation.product_request_id)
        next unless product_request.open?
        next unless product_request.compatible_with_variant?(po_line.product_variant)

        remaining_on_allocation = allocation.remaining_quantity
        while remaining_on_allocation.positive? && pair_index < unit_pairs.size
          pair = unit_pairs[pair_index]
          pair_index += 1
          plan << ConversionPlanEntry.new(
            allocation_id: allocation.id,
            product_request_id: product_request.id,
            receipt_line_id: pair[:receipt_line].id,
            quantity: 1,
            inventory_unit_id: pair[:inventory_unit].id
          )
          remaining_on_allocation -= 1
        end
      end

      plan
    end

    def execute_conversion_plan!(plan, variant:, posted_at:, individual:)
      # Reserve first (Balance/Unit → Reservation), then lock Allocations last.
      reservations_by_key = {}
      plan.group_by { |entry| [ entry.product_request_id, entry.inventory_unit_id ] }.each do |(request_id, unit_id), entries|
        quantity = entries.sum(&:quantity)
        product_request = ProductRequest.find(request_id)

        if individual
          unit = InventoryUnit.find(unit_id)
          reservation_result = Reserve.call(
            store: @store, product_variant: variant, quantity: 1,
            source_type: "product_request", source_id: product_request.id,
            actor: @actor, inventory_unit: unit
          )
          raise Error, reservation_result.error unless reservation_result.success?

          reservations_by_key[[ request_id, unit_id ]] = reservation_result.reservation
        else
          reservation = reserve_for_request!(
            variant: variant, product_request: product_request, additional_quantity: quantity
          )
          reservations_by_key[[ request_id, nil ]] = reservation
        end
      end

      allocation_ids = plan.map(&:allocation_id).uniq.sort
      locked_allocations = allocation_ids.index_with { |id| PurchaseOrderAllocation.lock.find(id) }

      remaining_by_allocation = locked_allocations.transform_values(&:remaining_quantity)
      plan.each do |entry|
        available = remaining_by_allocation.fetch(entry.allocation_id)
        if available < entry.quantity
          raise Error, "allocation #{entry.allocation_id} remaining quantity changed during posting"
        end

        reservation = if individual
          reservations_by_key.fetch([ entry.product_request_id, entry.inventory_unit_id ])
        else
          reservations_by_key.fetch([ entry.product_request_id, nil ])
        end

        receipt_line = ReceiptLine.find(entry.receipt_line_id)
        locked = locked_allocations.fetch(entry.allocation_id)
        posting_key = if individual
          "receipt:#{@receipt.id}:po_line:#{locked.purchase_order_line_id}:allocation:#{locked.id}:line:#{receipt_line.id}:unit:#{entry.inventory_unit_id}:convert"
        else
          "receipt:#{@receipt.id}:po_line:#{locked.purchase_order_line_id}:allocation:#{locked.id}:line:#{receipt_line.id}:convert"
        end

        record_conversion_event!(
          locked, receipt_line, reservation, entry.quantity, posted_at, posting_key: posting_key
        )
        remaining_by_allocation[entry.allocation_id] = available - entry.quantity
      end
    end

    def convertible_allocations(po_line)
      PurchaseOrderAllocation.where(purchase_order_line_id: po_line.id)
        .includes(:product_request, :purchase_order_allocation_events)
        .select { |allocation| allocation.remaining_quantity.positive? }
        .sort_by { |allocation| allocation_sort_key(allocation) }
    end

    def release_unbacked_allocations!(locked_po_lines, posted_at:)
      locked_po_lines.each_value do |po_line|
        open_qty = po_line.reload.open_quantity

        loop do
          total_remaining = PurchaseOrderAllocation.where(purchase_order_line_id: po_line.id)
            .includes(:purchase_order_allocation_events)
            .sum(&:remaining_quantity)
          overhang = total_remaining - open_qty
          break unless overhang.positive?

          candidate = PurchaseOrderAllocation.where(purchase_order_line_id: po_line.id)
            .includes(:product_request, :purchase_order_allocation_events)
            .select { |allocation| allocation.remaining_quantity.positive? }
            .max_by { |allocation| allocation_sort_key(allocation) }
          break if candidate.blank?

          locked = PurchaseOrderAllocation.lock.find(candidate.id)
          release_qty = [ locked.remaining_quantity, overhang ].min
          break unless release_qty.positive?

          locked.release!(
            quantity: release_qty,
            reason: "received_unavailable",
            actor: @actor,
            note: "released after receipt #{@receipt.receipt_number}; open supply no longer backs allocation",
            occurred_at: posted_at,
            posting_key: "receipt:#{@receipt.id}:po_line:#{po_line.id}:allocation:#{locked.id}:received_unavailable:#{release_qty}"
          )
        end
      end
    end

    def record_conversion_event!(allocation, line, reservation, quantity, posted_at, posting_key:)
      allocation.purchase_order_allocation_events.create!(
        event_type: "converted_to_reservation",
        quantity: quantity,
        receipt_line: line,
        inventory_reservation: reservation,
        occurred_at: posted_at,
        user: @actor,
        posting_key: posting_key
      )
    end

    def reserve_for_request!(variant:, product_request:, additional_quantity:)
      existing = InventoryReservation.active.find_by(
        store_id: @store.id, product_variant_id: variant.id,
        source_type: "product_request", source_id: product_request.id
      )
      target_quantity = (existing&.quantity || 0) + additional_quantity

      result = Reserve.call(
        store: @store, product_variant: variant, quantity: target_quantity,
        source_type: "product_request", source_id: product_request.id, actor: @actor
      )
      raise Error, result.error unless result.success?

      result.reservation
    end

    def allocation_sort_key(allocation)
      request = allocation.product_request
      [
        PRIORITY_RANK.fetch(request.priority, PRIORITY_RANK.size),
        request.needed_by_on.nil? ? 1 : 0,
        request.needed_by_on || request.created_at.to_date,
        request.created_at,
        allocation.id
      ]
    end
  end
end
