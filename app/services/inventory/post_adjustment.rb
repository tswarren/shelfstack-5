# frozen_string_literal: true

module Inventory
  class PostAdjustment < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:adjustment, :success?, :error, :replayed)

    def initialize(adjustment:, actor:, store:)
      @adjustment = adjustment
      @actor = actor
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @adjustment.reload.lock!

        if @adjustment.posted?

          return Result.new(adjustment: @adjustment, success?: true, error: nil, replayed: true)
        end

        raise Error, "only draft adjustments can be posted" unless @adjustment.draft?
        raise Error, "adjustment store mismatch" unless @adjustment.store_id == @store.id

        authorize!
        validate_reason!
        validate_note!
        validate_lines!

        @adjustment.posting_key ||= "inventory-adjustment:#{SecureRandom.uuid}"
        @adjustment.reason_code_snapshot = @adjustment.inventory_adjustment_reason.code
        @adjustment.reason_name_snapshot = @adjustment.inventory_adjustment_reason.name
        @adjustment.save!

        lines = @adjustment.inventory_adjustment_lines
          .sort_by { |line| [ line.product_variant_id, line.position, line.id ] }

        lines.each do |line|
          post_line!(line)
        end

        @adjustment.update!(
          status: "posted",
          posted_by_user: @actor,
          posted_at: Time.current
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "inventory.adjustment.posted",
          subject: @adjustment,
          metadata: {
            "kind" => @adjustment.kind,
            "reason_code" => @adjustment.reason_code_snapshot,
            "reason_name" => @adjustment.reason_name_snapshot,
            "posting_key" => @adjustment.posting_key,
            "line_count" => lines.size
          }
        )

        Result.new(adjustment: @adjustment, success?: true, error: nil, replayed: false)
      end
    rescue Error, PostLedgerEntry::Error, ArgumentError => e
      Result.new(adjustment: @adjustment, success?: false, error: e.message, replayed: false)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(adjustment: @adjustment, success?: false, error: e.record.errors.full_messages.to_sentence, replayed: false)
    rescue ActiveRecord::StatementInvalid => e
      Result.new(adjustment: @adjustment, success?: false, error: e.cause&.message || e.message, replayed: false)
    end


    private

    def authorize!
      case @adjustment.kind
      when "cost_correction"
        unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.cost_correction.post") == :allow
          raise Error, "not permitted to post cost corrections"
        end
        unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.cost.view") == :allow
          raise Error, "cost view permission required to post cost corrections"
        end
      else
        unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.adjustment.post") == :allow
          raise Error, "not permitted to post adjustments"
        end
      end
    end

    def validate_reason!
      reason = @adjustment.inventory_adjustment_reason
      raise Error, "reason is required" if reason.blank?
      raise Error, "reason is inactive; reselect an active reason" unless reason.active?
      raise Error, "reason kind mismatch" unless reason.adjustment_kind == @adjustment.kind
      raise Error, "reason organization mismatch" unless reason.organization_id == @store.organization_id
    end

    def validate_note!
      return unless @adjustment.inventory_adjustment_reason.requires_note?
      raise Error, "note is required for this reason" if @adjustment.note.blank?
    end

    def validate_lines!
      raise Error, "adjustment must have at least one line" if @adjustment.inventory_adjustment_lines.empty?

      @adjustment.inventory_adjustment_lines.each do |line|
        raise Error, line.errors.full_messages.to_sentence unless line.valid?

        case @adjustment.kind
        when "opening_inventory"
          raise Error, "opening inventory quantity must be positive" unless line.quantity_delta.positive?
        when "quantity_only"
          raise Error, "quantity_delta must be non-zero" if line.quantity_delta.zero?
        when "cost_correction"
          raise Error, "quantity_delta must be zero for cost corrections" unless line.quantity_delta.zero?
          raise Error, "corrected_inventory_value_cents is required" if line.corrected_inventory_value_cents.nil?
          raise Error, "corrected_inventory_value_cents must be >= 0" if line.corrected_inventory_value_cents.negative?

          balance = StockBalance.find_by(store_id: @store.id, product_variant_id: line.product_variant_id)
          unless balance&.on_hand.to_i.positive?
            raise Error, "cost correction requires positive on-hand for #{line.product_variant.sku}"
          end
        end
      end
    end

    def post_line!(line)
      variant = line.product_variant
      raise Error, "variant must be quantity-tracked" unless variant.inventory_tracking_mode == "quantity"
      raise Error, "variant organization mismatch" unless variant.organization.id == @store.organization_id

      case @adjustment.kind
      when "opening_inventory"
        post_opening!(line)
      when "quantity_only"
        post_quantity_only!(line)
      when "cost_correction"
        post_cost_correction!(line)
      else
        raise Error, "unsupported kind"
      end
    end

    def post_opening!(line)
      unit_cost = line.input_unit_cost_cents
      method = line.input_cost_method
      quality = line.input_cost_quality
      estimate_dept = line.estimate_department
      estimate_price = line.estimate_regular_price_cents
      estimate_margin = line.estimate_margin_bps
      estimate_unit = line.estimate_unit_cost_cents

      if method == "configured_estimate"
        estimate = DepartmentEstimate.call(product_variant: line.product_variant)
        raise Error, estimate.error || "estimate unavailable" unless estimate.available

        unit_cost = estimate.unit_cost_cents
        quality = "estimated"
        estimate_dept = estimate.department
        estimate_price = estimate.regular_price_cents
        estimate_margin = estimate.margin_bps
        estimate_unit = estimate.unit_cost_cents
      elsif quality.blank? && unit_cost.nil?
        method = "unknown"
        quality = "unknown"
      else
        method ||= "explicit"
        quality ||= "actual"
      end

      PostLedgerEntry.call(
        store: @store,
        product_variant: line.product_variant,
        movement_type: "opening_inventory",
        movement_kind: :opening_inventory,
        quantity_delta: line.quantity_delta,
        incoming_unit_cost_cents: unit_cost,
        incoming_cost_method: method,
        incoming_cost_quality: quality,
        source: line,
        posting_key: "#{@adjustment.posting_key}:line:#{line.id}",
        posted_by_user: @actor,
        reason_code: @adjustment.qualified_reason_code,
        reason_note: @adjustment.note,
        estimate_department: estimate_dept,
        estimate_regular_price_cents: estimate_price,
        estimate_margin_bps: estimate_margin,
        estimate_unit_cost_cents: estimate_unit
      )
    end

    def post_quantity_only!(line)
      PostLedgerEntry.call(
        store: @store,
        product_variant: line.product_variant,
        movement_type: "quantity_adjustment",
        movement_kind: :quantity_only,
        quantity_delta: line.quantity_delta,
        source: line,
        posting_key: "#{@adjustment.posting_key}:line:#{line.id}",
        posted_by_user: @actor,
        reason_code: @adjustment.qualified_reason_code,
        reason_note: @adjustment.note
      )
    end

    def post_cost_correction!(line)
      PostLedgerEntry.call(
        store: @store,
        product_variant: line.product_variant,
        movement_type: "cost_correction",
        movement_kind: :cost_correction,
        quantity_delta: 0,
        corrected_inventory_value_cents: line.corrected_inventory_value_cents,
        incoming_cost_method: line.input_cost_method.presence || "explicit",
        incoming_cost_quality: line.input_cost_quality.presence || "actual",
        source: line,
        posting_key: "#{@adjustment.posting_key}:line:#{line.id}",
        posted_by_user: @actor,
        reason_code: @adjustment.qualified_reason_code,
        reason_note: @adjustment.note
      )
    end
  end
end
