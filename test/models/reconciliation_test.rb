# frozen_string_literal: true

require "test_helper"

class ReconciliationTest < ActiveSupport::TestCase
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
    Pos::CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: 0)
    @session.reload
  end

  test "creates draft session reconciliation" do
    recon = Reconciliation.create!(
      store: @store,
      pos_session: @session,
      scope_type: "session",
      status: "draft",
      opened_at: Time.current,
      opened_by_user: @admin
    )

    assert recon.draft?
    assert_nil recon.reconciled_at
  end

  test "finalize requires reconciled_at and by" do
    recon = Reconciliation.create!(
      store: @store,
      pos_session: @session,
      scope_type: "session",
      status: "draft",
      opened_at: Time.current,
      opened_by_user: @admin
    )

    recon.assign_attributes(status: "finalized")
    assert_not recon.valid?
    assert_includes recon.errors[:reconciled_at], "can't be blank"

    recon.assign_attributes(reconciled_at: Time.current, reconciled_by_user: @admin)
    assert recon.valid?
  end

  test "enforces one reconciliation per session" do
    attrs = {
      store: @store,
      pos_session: @session,
      scope_type: "session",
      status: "draft",
      opened_at: Time.current,
      opened_by_user: @admin
    }
    Reconciliation.create!(attrs)
    duplicate = Reconciliation.new(attrs)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:pos_session_id], "has already been taken"
  end

  test "business day scope excludes pos_session" do
    recon = Reconciliation.new(
      store: @store,
      business_day: @day,
      pos_session: @session,
      scope_type: "business_day",
      status: "draft",
      opened_at: Time.current,
      opened_by_user: @admin
    )
    assert_not recon.valid?
  end
end
