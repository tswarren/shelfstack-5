# frozen_string_literal: true

module Pos
  class OpenBusinessDay < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:business_day, :success?, :error)

    def initialize(store:, actor:, reporting_date: nil)
      @store = store
      @actor = actor
      @reporting_date = reporting_date || default_reporting_date
    end

    def call
      raise Error, "store must be active" unless @store.active?

      ActiveRecord::Base.transaction do
        existing = BusinessDay.lock.find_by(store_id: @store.id, status: "open")
        raise Error, "a business day is already open for this store" if existing

        business_day = BusinessDay.create!(
          store: @store,
          reporting_date: @reporting_date,
          status: "open",
          opened_at: Time.current,
          opened_by_user: @actor
        )

        Result.new(business_day: business_day, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(business_day: nil, success?: false, error: e.message)
    end

    private

    # OD-001 v1: reporting date defaults to the store-local calendar date at open.
    def default_reporting_date
      StoreTime.today(@store)
    end
  end
end
