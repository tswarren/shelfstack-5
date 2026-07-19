# frozen_string_literal: true

module Pos
  class OpenSession < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_session, :success?, :error)

    def initialize(business_day:, store:, pos_device:, cashier:, actor:, cash_drawer: nil, opening_cash_cents: nil)
      @business_day = business_day
      @store = store
      @pos_device = pos_device
      @cash_drawer = cash_drawer
      @cashier = cashier
      @actor = actor
      @opening_cash_cents = opening_cash_cents
    end

    def call
      raise Error, "business day must belong to the store" unless @business_day.store_id == @store.id
      raise Error, "device must belong to the store" unless @pos_device.store_id == @store.id
      if @cash_drawer.present? && @cash_drawer.store_id != @store.id
        raise Error, "drawer must belong to the store"
      end

      ActiveRecord::Base.transaction do
        # Lock parent Business Day and recheck status under the lock before creating
        # a child Session (prevents open-on-closed race with CloseBusinessDay).
        day = BusinessDay.lock.find(@business_day.id)
        raise Error, "business day must be open" unless day.open?
        raise Error, "business day must belong to the store" unless day.store_id == @store.id

        if PosSession.where(pos_device_id: @pos_device.id, status: "open").lock.exists?
          raise Error, "device already has an open session"
        end
        if @cash_drawer.present? && PosSession.where(cash_drawer_id: @cash_drawer.id, status: "open").lock.exists?
          raise Error, "drawer already has an active cash-enabled session"
        end

        opening_cash = nil
        if @cash_drawer.present?
          raise Error, "opening cash is required for cash-enabled sessions" if @opening_cash_cents.nil?
          opening_cash = @opening_cash_cents.to_i
          raise Error, "opening cash must not be negative" if opening_cash.negative?
        elsif !@opening_cash_cents.nil?
          raise Error, "opening cash is only valid for cash-enabled sessions"
        end

        session = PosSession.create!(
          business_day: day,
          store: @store,
          pos_device: @pos_device,
          cash_drawer: @cash_drawer,
          cashier_user: @cashier,
          status: "open",
          opened_at: Time.current,
          opened_by_user: @actor,
          opening_cash_cents: opening_cash
        )

        if opening_cash
          PosSessionCashCount.create!(
            pos_session: session,
            count_type: "opening",
            total_cents: opening_cash,
            counted_by_user: @actor,
            counted_at: Time.current,
            created_at: Time.current
          )
        end

        Result.new(pos_session: session, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(pos_session: nil, success?: false, error: e.message)
    end
  end
end
