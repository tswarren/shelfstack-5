# frozen_string_literal: true

module Pos
  class OpenSession < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_session, :success?, :error)

    def initialize(business_day:, store:, pos_device:, cashier:, actor:, cash_drawer: nil)
      @business_day = business_day
      @store = store
      @pos_device = pos_device
      @cash_drawer = cash_drawer
      @cashier = cashier
      @actor = actor
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

        session = PosSession.create!(
          business_day: day,
          store: @store,
          pos_device: @pos_device,
          cash_drawer: @cash_drawer,
          cashier_user: @cashier,
          status: "open",
          opened_at: Time.current,
          opened_by_user: @actor
        )

        Result.new(pos_session: session, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(pos_session: nil, success?: false, error: e.message)
    end
  end
end
