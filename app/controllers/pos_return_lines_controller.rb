# frozen_string_literal: true

class PosReturnLinesController < ApplicationController
  include UnlinkedReturnRequest
  include PosPendingApprovalStaging

  before_action -> { require_permission!("pos.return.create") }
  before_action :set_transaction

  def lookup
    receipt = params[:receipt_number].to_s.strip
    if receipt.blank?
      redirect_to pos_transaction_path(@pos_transaction), alert: "Enter a receipt number."
      return
    end

    original = Current.store.pos_transactions.completed.find_by(receipt_number: receipt)
    if original.blank?
      session.delete(:pos_return_lookup)
      redirect_to pos_transaction_path(@pos_transaction),
                  alert: "No completed transaction found for that receipt."
      return
    end

    session[:pos_return_lookup] = {
      "for_transaction_id" => @pos_transaction.id,
      "original_transaction_id" => original.id,
      "receipt_number" => original.receipt_number
    }
    redirect_to pos_transaction_path(@pos_transaction),
                notice: "Receipt #{original.receipt_number} loaded for return."
  end

  def create
    if params[:mode].to_s == "unlinked"
      create_unlinked
    else
      create_linked
    end
  end

  private

  def create_linked
    if params[:batch].present?
      create_linked_batch
    else
      create_linked_single
    end
  end

  def create_linked_single
    original = PosLineItem.joins(:pos_transaction)
                          .where(pos_transactions: { store_id: Current.store.id, status: "completed" })
                          .find(params[:original_pos_line_item_id])
    reason = Current.organization.return_reasons.find(params[:return_reason_id])

    result = Pos::AddLinkedReturnLine.call(
      pos_transaction: @pos_transaction,
      original_pos_line_item: original,
      quantity: params[:quantity].presence || 1,
      return_reason: reason,
      return_disposition: params[:return_disposition],
      actor: Current.user
    )

    if result.success?
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction, intent: "sale", focus_target: "scan"),
                                notice: "Return line added."
    else
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  end

  def create_linked_batch
    default_reason = Current.organization.return_reasons.find(params[:default_return_reason_id])
    default_disposition = params[:default_return_disposition].presence || "return_to_stock"
    line_params = params[:lines].presence || {}

    specs = []
    line_params.each do |line_id, attrs|
      next unless ActiveModel::Type::Boolean.new.cast(attrs[:selected])

      original = PosLineItem.joins(:pos_transaction)
                            .where(pos_transactions: { store_id: Current.store.id, status: "completed" })
                            .find(line_id)
      reason = if attrs[:return_reason_id].present?
        Current.organization.return_reasons.find(attrs[:return_reason_id])
      else
        default_reason
      end
      disposition = attrs[:return_disposition].presence || default_disposition
      specs << Pos::AddLinkedReturnLines::LineSpec.new(
        original_pos_line_item: original,
        quantity: attrs[:quantity].presence || 1,
        return_reason: reason,
        return_disposition: disposition
      )
    end

    result = Pos::AddLinkedReturnLines.call(
      pos_transaction: @pos_transaction,
      lines: specs,
      actor: Current.user
    )

    if result.success?
      count = result.pos_line_items.size
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction, intent: "sale", focus_target: "scan"),
                                notice: "#{count} return line#{count == 1 ? "" : "s"} added."
    else
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  rescue ActiveRecord::RecordNotFound => e
    redirect_out_of_overlay_to pos_transaction_path(@pos_transaction), alert: e.message
  end

  def create_unlinked
    return if handle_unlinked_wizard!

    parse_unlinked_return_inputs!

    if unlinked_cost_review_needed?
      error = prepare_unlinked_cost_review!
      if error
        return render_unlinked_return_overlay_error(alert: error)
      end

      @cost_review_form_url = pos_transaction_pos_return_lines_path(@pos_transaction)
      @cost_review_form_id = "txn_unlinked_return_cost_confirm_form"
      @cost_review_submit_label = "Confirm and add return"
      return render "pos_overlays/unlinked_return_cost_review", layout: false
    end

    result = Pos::AddUnlinkedReturnLine.call(
      pos_transaction: @pos_transaction,
      actor: Current.user,
      **unlinked_return_service_kwargs
    )

    if result.success?
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction, intent: "sale", focus_target: "scan"),
                                notice: "Unlinked return line added."
    elsif result.requires_approval?
      stage_unlinked_return_approval!(result)
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction, intent: "return")
    elsif first_step_unlinked_overlay_request?
      render_unlinked_return_overlay_error(alert: result.error)
    else
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction), alert: result.error
    end
  rescue ArgumentError => e
    if first_step_unlinked_overlay_request?
      render_unlinked_return_overlay_error(alert: e.message)
    else
      redirect_out_of_overlay_to pos_transaction_path(@pos_transaction), alert: e.message
    end
  end

  def stage_unlinked_return_approval!(_result)
    payload = {
      "pos_transaction_id" => @pos_transaction.id,
      "product_variant_id" => @unlinked_variant&.id,
      "department_id" => @unlinked_department&.id,
      "description" => params[:description],
      "quantity" => @unlinked_quantity,
      "unit_price_cents" => @unlinked_unit_price_cents,
      "return_reason_id" => @unlinked_reason&.id,
      "return_disposition" => params[:return_disposition],
      "return_source" => params[:return_source],
      "tax_category_id" => @unlinked_tax_category&.id,
      "tax_basis" => params[:tax_basis],
      "explicit_tax_amount_cents" => @unlinked_explicit_tax,
      "cost_method" => params[:reviewed_cost_source],
      "unit_cost_cents" => params[:reviewed_cost_unit_cents],
      "cost_quality" => nil
    }
    description = @unlinked_variant&.product&.name || params[:description].presence || "Open ring"
    stage_pending_approval!(
      action: "unlinked_return",
      fingerprint: Pos::ApprovalInterrupt.unlinked_return_fingerprint(payload),
      payload: payload,
      presentation: Pos::ApprovalInterrupt.unlinked_return_presentation(
        description: description,
        quantity: @unlinked_quantity,
        unit_price_cents: @unlinked_unit_price_cents
      )
    )
  end

  def set_transaction
    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end
end
