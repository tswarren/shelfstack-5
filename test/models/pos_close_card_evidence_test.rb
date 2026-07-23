# frozen_string_literal: true

require "test_helper"

class PosCloseCardEvidenceTest < ActiveSupport::TestCase
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

  test "creates business-day machine_batch evidence with net_only precision" do
    row = PosCloseCardEvidence.create!(
      store: @store,
      business_day: @day,
      kind: "machine_batch",
      status: "recorded",
      precision: "net_only",
      net_cents: 12_345,
      batch_reference: "BATCH-1",
      entered_by_user: @admin,
      entered_at: Time.current
    )

    assert_equal "net_only", row.precision
    assert_nil row.received_cents
  end

  test "rejects received_and_refunded without both legs" do
    row = PosCloseCardEvidence.new(
      store: @store,
      business_day: @day,
      kind: "machine_batch",
      status: "recorded",
      precision: "received_and_refunded",
      net_cents: 100,
      received_cents: 100,
      entered_by_user: @admin,
      entered_at: Time.current
    )

    assert_not row.valid?
    assert_includes row.errors[:refunded_cents], "can't be blank"
  end

  test "rejects received_and_refunded when net does not match" do
    row = PosCloseCardEvidence.new(
      store: @store,
      business_day: @day,
      kind: "machine_batch",
      status: "recorded",
      precision: "received_and_refunded",
      received_cents: 200,
      refunded_cents: 50,
      net_cents: 100,
      entered_by_user: @admin,
      entered_at: Time.current
    )

    assert_not row.valid?
    assert_includes row.errors[:net_cents], "must equal received minus refunded"
  end

  test "allows evidence_unavailable without inventing amounts" do
    row = PosCloseCardEvidence.create!(
      store: @store,
      business_day: @day,
      kind: "machine_batch",
      status: "unavailable",
      unavailable_reason: "Batch printer offline",
      entered_by_user: @admin,
      entered_at: Time.current
    )

    assert_equal "unavailable", row.status
    assert_nil row.net_cents
  end

  test "session scope requires pos_session and excludes business_day" do
    row = PosCloseCardEvidence.new(
      store: @store,
      business_day: @day,
      pos_session: @session,
      kind: "merchant_slip",
      status: "recorded",
      precision: "net_only",
      net_cents: 500,
      entered_by_user: @admin,
      entered_at: Time.current
    )

    assert_not row.valid?
    assert_includes row.errors[:base], "exactly one of pos_session or business_day is required"
  end

  test "session merchant slip evidence is immutable after create" do
    row = PosCloseCardEvidence.create!(
      store: @store,
      pos_session: @session,
      kind: "merchant_slip",
      status: "recorded",
      precision: "net_only",
      net_cents: 500,
      entered_by_user: @admin,
      entered_at: Time.current
    )

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      row.update!(net_cents: 600)
    end
  end
end
