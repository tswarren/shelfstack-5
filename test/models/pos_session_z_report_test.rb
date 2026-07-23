# frozen_string_literal: true

require "test_helper"

class PosSessionZReportTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
  end

  test "creates an immutable session Z snapshot" do
    report = PosSessionZReport.create!(
      pos_session: @session,
      store: @store,
      z_number: 1,
      business_date: @day.reporting_date,
      source_cutoff_at: Time.current,
      report_definition_version: "session_z.v1",
      generated_at: Time.current,
      generated_by_user: @admin,
      payload: { "gross_sales_cents" => 0 },
      expected_cash_cents: 0,
      counted_cash_cents: 0,
      cash_variance_cents: 0
    )

    assert_equal 1, report.z_number
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      report.update!(counted_cash_cents: 100)
    end
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      report.destroy!
    end
  end

  test "enforces one Z report per session" do
    attrs = {
      pos_session: @session,
      store: @store,
      z_number: 1,
      business_date: @day.reporting_date,
      source_cutoff_at: Time.current,
      report_definition_version: "session_z.v1",
      generated_at: Time.current,
      generated_by_user: @admin,
      payload: { "sections" => [] }
    }
    PosSessionZReport.create!(attrs)
    duplicate = PosSessionZReport.new(attrs.merge(z_number: 2))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:pos_session_id], "has already been taken"
  end
end
