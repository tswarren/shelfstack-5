# frozen_string_literal: true

require "test_helper"

class PosTransactionTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
  end

  test "assigns a public_id automatically on create" do
    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    session = Pos::OpenSession.call(business_day: day, store: @store, pos_device: @device, cashier: @admin, actor: @admin).pos_session

    transaction = PosTransaction.create!(
      store: @store, origin_pos_session: session, active_pos_session: session,
      cashier_user: @admin, status: "open", opened_at: Time.current
    )

    assert transaction.public_id.present?
    assert transaction.editable?
  end
end
