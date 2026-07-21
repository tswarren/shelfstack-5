# frozen_string_literal: true

class StoredValueAccountsController < ApplicationController
  before_action -> { require_permission!("stored_value.account.view") }, only: %i[index show]
  before_action -> { require_permission!("stored_value.account.create") }, only: %i[new create]
  before_action -> { require_permission!("stored_value.adjustment.create") }, only: %i[adjust]
  before_action :set_account, only: %i[show adjust]

  def index
    @accounts = Current.organization.stored_value_accounts.order(created_at: :desc).limit(200)
  end

  def show
    @entries = @account.stored_value_entries.order(created_at: :desc, id: :desc).limit(100)
    @adjustment_reasons = Current.organization.stored_value_adjustment_reasons.where(active: true).order(:position, :name)
  end

  def new
    @account = Current.organization.stored_value_accounts.new(account_type: "gift_card", status: "active")
  end

  def create
    result = StoredValue::CreateAccount.call(
      organization: Current.organization,
      account_type: params.require(:stored_value_account)[:account_type],
      actor: Current.user,
      store: Current.store,
      alternate_identifier: params.dig(:stored_value_account, :alternate_identifier)
    )
    if result.success?
      redirect_to result.account, notice: "Stored-value account created."
    else
      @account = Current.organization.stored_value_accounts.new(
        account_type: params.dig(:stored_value_account, :account_type),
        alternate_identifier: params.dig(:stored_value_account, :alternate_identifier)
      )
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def adjust
    reason = Current.organization.stored_value_adjustment_reasons.find(params[:adjustment_reason_id])
    approver = User.find_by(username: params[:approver_username].to_s.strip.downcase)
    result = StoredValue::AdjustBalance.call(
      account: @account,
      store: Current.store,
      amount_cents: money_param_to_cents(params[:amount_cents], label: "Amount"),
      adjustment_reason: reason,
      actor: Current.user,
      description: params[:description],
      approver: approver,
      approver_pin: params[:approver_pin]
    )
    if result.success?
      redirect_to @account, notice: "Adjustment posted."
    else
      redirect_to @account, alert: result.error
    end
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    redirect_to @account, alert: e.message
  end

  private

  def set_account
    @account = Current.organization.stored_value_accounts.find(params[:id])
  end
end
