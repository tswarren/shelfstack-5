# frozen_string_literal: true

module Pos
  class CloseBusinessDay < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:business_day, :success?, :error, :replayed)

    def initialize(business_day:, actor:)
      @business_day = business_day
      @actor = actor
    end

    def call
      ActiveRecord::Base.transaction do
        business_day = BusinessDay.lock.find(@business_day.id)

        if business_day.closed?
          return Result.new(business_day: business_day, success?: true, error: nil, replayed: true)
        end

        if PosSession.where(business_day_id: business_day.id, status: "open").exists?
          raise Error, "cannot close business day while a POS session is open"
        end

        business_day.update!(status: "closed", closed_at: Time.current, closed_by_user: @actor)

        Result.new(business_day: business_day, success?: true, error: nil, replayed: false)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(business_day: @business_day, success?: false, error: e.message, replayed: false)
    end
  end
end
