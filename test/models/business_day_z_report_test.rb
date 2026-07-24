# frozen_string_literal: true

require "test_helper"

class BusinessDayZReportTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
  end

  test "creates an immutable business-day Z snapshot" do
    report = BusinessDayZReport.create!(
      business_day: @day,
      store: @store,
      z_number: 1,
      business_date: @day.reporting_date,
      source_cutoff_at: Time.current,
      report_definition_version: "business_day_z.v1",
      generated_at: Time.current,
      generated_by_user: @admin,
      payload: { "gross_sales_cents" => 0 }
    )

    assert_equal 1, report.z_number
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      report.update!(payload: { "gross_sales_cents" => 1 })
    end
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      report.destroy!
    end
  end

  test "enforces one Z report per business day" do
    attrs = {
      business_day: @day,
      store: @store,
      z_number: 1,
      business_date: @day.reporting_date,
      source_cutoff_at: Time.current,
      report_definition_version: "business_day_z.v1",
      generated_at: Time.current,
      generated_by_user: @admin,
      payload: { "sections" => [] }
    }
    BusinessDayZReport.create!(attrs)
    duplicate = BusinessDayZReport.new(attrs.merge(z_number: 2))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:business_day_id], "has already been taken"
  end
end
