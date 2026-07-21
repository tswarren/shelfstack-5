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
  # Idempotent — the whole posting runs in one transaction, so a failure
  # leaves no partial ledger, unit, or Purchase-Order-line effect; replaying
  # an already-posted Receipt is a no-op success (posting_key/posted_at are
  # only ever assigned once, at successful completion).
  #
  # Phase 5f: for a quantity-tracked line linked to a Purchase-Order Line,
  # once the accepted sellable quantity is posted, converts as much remaining
  # Purchase-Order Allocation quantity on that line into Inventory
  # Reservations for the allocations' Customer Requests as the accepted
  # sellable quantity allows (OD-007 "receipt posting"). Deterministic order
  # when accepted quantity cannot satisfy every remaining allocation: request
  # priority (urgent > high > normal), `needed_by_on` (earlier first, nulls
  # last), then `created_at`. Unavailable/inspection-held accepted quantity is
  # never converted (it is not usable expected supply for a customer).
  # Allocation quantity this posting cannot satisfy is left as remaining
  # future supply — releasing it (cancellation, unavailability, earlier
  # supply) is `Purchasing::ReleaseAllocation`'s job, not this service's.
  class PostReceipt < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:receipt, :success?, :error, :replayed)

    PRIORITY_RANK = { "urgent" => 0, "high" => 1, "normal" => 2 }.freeze

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

      case variant.inventory_tracking_mode
      when "quantity"
        convert_allocations_for_line!(line, variant, posted_at: posted_at)
      when "individual"
        convert_individual_allocations_for_line!(line, variant, posted_at: posted_at)
      end
    end

    def post_quantity_line!(line, variant, posting_key:, posted_at:)
      return if line.accepted_quantity.zero?

      unit_cost_cents, cost_method, cost_quality = receipt_cost_inputs(line)
      balance = FindOrCreateStockBalance.call(store: @store, product_variant: variant)
      open_deficit_quantity = balance.open_deficit_quantity
      settlement_quantity = [ line.accepted_quantity, open_deficit_quantity ].min
      positive_quantity = line.accepted_quantity - settlement_quantity
      # Only quantity remaining after the deficit reaches zero is physically
      # present positive stock. Prefer sellable units for that remainder so
      # customer allocation conversion can use them; any leftover positive
      # quantity (and never deficit-settlement quantity) may enter unavailable.
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
          incoming_cost_quality: cost_quality
        )
        final_balance = result.stock_balance
      end

      if unavailable_positive_quantity.positive?
        final_balance.update!(unavailable: final_balance.unavailable + unavailable_positive_quantity)
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

    # OD-014 "Unknown receipt cost": actual receipt cost → confirmed vendor
    # source cost → linked PO expected cost as an estimate → unknown.
    # `confirmed_zero` is a known actual cost of zero, distinct from unknown.
    def receipt_cost_inputs(line)
      case line.cost_quality
      when "confirmed_zero"
        return [ 0, "explicit", "actual" ]
      when "actual", "estimated"
        if line.actual_unit_cost_cents.present?
          return [ line.actual_unit_cost_cents, "explicit", line.cost_quality ]
        end
      end

      if line.actual_unit_cost_cents.present?
        quality = line.cost_quality.presence || "actual"
        return [ line.actual_unit_cost_cents, "explicit", quality ] if %w[actual estimated].include?(quality)
      end

      source = line.purchase_order_line&.product_variant_vendor
      if source&.expected_unit_cost_cents.present?
        return [ source.expected_unit_cost_cents, "vendor_source", "actual" ]
      end
      if source&.list_cost_cents.present?
        discount = source.discount_bps.to_i
        estimated = Inventory::Rounding.round_half_up(source.list_cost_cents.to_i * (10_000 - discount), 10_000)
        return [ estimated, "vendor_source", "estimated" ]
      end

      po_line = line.purchase_order_line
      if po_line&.expected_unit_cost_cents.present?
        return [ po_line.expected_unit_cost_cents, "purchase_order_expected", "estimated" ]
      end

      [ nil, "unknown", "unknown" ]
    end

    def update_purchase_order_line!(line)
      po_line = line.purchase_order_line
      return if po_line.blank?

      locked = PurchaseOrderLine.lock.find(po_line.id)
      locked.update!(received_quantity: locked.received_quantity + line.accepted_quantity)
    end

    # OD-007 "receipt posting": only sellable quantity that remains after
    # deficit settlement is physically present and usable for conversion.
    # Accepted-but-unavailable positive quantity is never converted.
    def convert_allocations_for_line!(line, variant, posted_at:)
      po_line = line.purchase_order_line
      return if po_line.blank?

      remaining_to_convert = if line.respond_to?(:positive_sellable_quantity_for_conversion)
        line.positive_sellable_quantity_for_conversion
      else
        line.sellable_accepted_quantity
      end
      return unless remaining_to_convert.positive?

      each_convertible_allocation(po_line) do |product_request, locked_allocation|
        break unless remaining_to_convert.positive?

        convert_quantity = [ remaining_to_convert, locked_allocation.remaining_quantity ].min
        next unless convert_quantity.positive?

        reservation = reserve_for_request!(variant: variant, product_request: product_request, additional_quantity: convert_quantity)
        record_conversion_event!(
          locked_allocation, line, reservation, convert_quantity, posted_at,
          posting_key: "receipt:#{@receipt.id}:line:#{line.id}:allocation:#{locked_allocation.id}:convert"
        )
        remaining_to_convert -= convert_quantity
      end
    end

    # Exact-copy Customer Requests: each newly accepted available Inventory Unit
    # may convert one remaining allocation unit onto that request. The active
    # reservation unique index allows one unit reservation per request/variant,
    # so a request already holding a unit is skipped until that hold is sold or
    # released. Inspection/unavailable units are never converted.
    def convert_individual_allocations_for_line!(line, variant, posted_at:)
      po_line = line.purchase_order_line
      return if po_line.blank?

      units = line.respond_to?(:created_sellable_units_for_conversion) ? line.created_sellable_units_for_conversion : []
      return if units.blank?

      unit_index = 0
      each_convertible_allocation(po_line) do |product_request, locked_allocation|
        break if unit_index >= units.size

        existing = InventoryReservation.active.find_by(
          store_id: @store.id, product_variant_id: variant.id,
          source_type: "product_request", source_id: product_request.id
        )
        next if existing.present?

        unit = units[unit_index]
        unit_index += 1

        reservation_result = Reserve.call(
          store: @store, product_variant: variant, quantity: 1,
          source_type: "product_request", source_id: product_request.id,
          actor: @actor, inventory_unit: unit
        )
        raise Error, reservation_result.error unless reservation_result.success?

        record_conversion_event!(
          locked_allocation, line, reservation_result.reservation, 1, posted_at,
          posting_key: "receipt:#{@receipt.id}:line:#{line.id}:allocation:#{locked_allocation.id}:unit:#{unit.id}:convert"
        )
      end
    end

    def each_convertible_allocation(po_line)
      candidates = PurchaseOrderAllocation.where(purchase_order_line_id: po_line.id)
        .includes(:product_request, :purchase_order_allocation_events)
        .select { |allocation| allocation.remaining_quantity.positive? }
        .sort_by { |allocation| allocation_sort_key(allocation) }

      candidates.each do |allocation|
        product_request = ProductRequest.lock.find(allocation.product_request_id)
        next unless product_request.open?
        next unless product_request.compatible_with_variant?(po_line.product_variant)

        locked_allocation = PurchaseOrderAllocation.lock.find(allocation.id)
        next unless locked_allocation.remaining_quantity.positive?

        yield product_request, locked_allocation
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

    # Adds `additional_quantity` on top of any existing active Inventory
    # Reservation for this Customer Request/variant (`Inventory::Reserve`
    # sets an absolute quantity, so the current locked quantity is read
    # first; the Product Request lock taken by the caller serializes this
    # read-then-set against concurrent writers of the same reservation).
    def reserve_for_request!(variant:, product_request:, additional_quantity:)
      existing = InventoryReservation.active.lock.find_by(
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
