# frozen_string_literal: true

require "test_helper"

# Phase 4g-4: high-integrity model / DB invariants (uniques, checks, cross-store
# shape). Not presence-only coverage for every lookup table.
class HighIntegrityInvariantsTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @other_store = stores(:warehouse)
    @admin = users(:admin)
    @clerk = users(:clerk)
    @variant = product_variants(:sample_book_standard)
    @individual = product_variants(:signed_book_standard)
    @none_variant = product_variants(:gift_wrap_service_standard)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
  end

  # --- BusinessDay -----------------------------------------------------------

  test "database enforces one open business day per store" do
    BusinessDay.create!(
      store: @store, reporting_date: Date.current, status: "open",
      opened_at: Time.current, opened_by_user: @admin
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      BusinessDay.connection.execute(<<~SQL.squish)
        INSERT INTO business_days (store_id, reporting_date, status, opened_at, opened_by_user_id, created_at, updated_at)
        VALUES (#{@store.id}, CURRENT_DATE, 'open', CURRENT_TIMESTAMP, #{@admin.id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
    end
  end

  # --- PosSession ------------------------------------------------------------

  test "pos session rejects a device from another store" do
    foreign_device = PosDevice.create!(
      store: @other_store, code: "WH1", name: "Warehouse 1", device_type: "register", active: true
    )
    day = BusinessDay.create!(
      store: @store, reporting_date: Date.current, status: "open",
      opened_at: Time.current, opened_by_user: @admin
    )
    session = PosSession.new(
      business_day: day, store: @store, pos_device: foreign_device, cash_drawer: @drawer,
      cashier_user: @admin, opened_by_user: @admin, opened_at: Time.current,
      opening_cash_cents: 0, status: "open"
    )

    refute session.valid?
    assert_includes session.errors[:pos_device], "must belong to the same store"
  end

  test "pos session rejects a cash drawer from another store" do
    foreign_drawer = CashDrawer.create!(
      store: @other_store, code: "WHD1", name: "Warehouse Drawer", active: true
    )
    day = BusinessDay.create!(
      store: @store, reporting_date: Date.current, status: "open",
      opened_at: Time.current, opened_by_user: @admin
    )
    session = PosSession.new(
      business_day: day, store: @store, pos_device: @device, cash_drawer: foreign_drawer,
      cashier_user: @admin, opened_by_user: @admin, opened_at: Time.current,
      opening_cash_cents: 0, status: "open"
    )

    refute session.valid?
    assert_includes session.errors[:cash_drawer], "must belong to the same store"
  end

  test "database enforces one open session per device" do
    day, session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    assert session.open?

    other_device = PosDevice.create!(
      store: @store, code: "REG2", name: "Register 2", device_type: "register", active: true
    )
    # Use a different device first so we can insert a conflicting second open on @device via SQL.
    PosSession.create!(
      business_day: day, store: @store, pos_device: other_device, cash_drawer: nil,
      cashier_user: @admin, opened_by_user: @admin, opened_at: Time.current,
      opening_cash_cents: 0, status: "closed", closed_at: Time.current, closed_by_user: @admin
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      PosSession.connection.execute(<<~SQL.squish)
        INSERT INTO pos_sessions (
          business_day_id, store_id, pos_device_id, cash_drawer_id, cashier_user_id,
          opened_by_user_id, opened_at, opening_cash_cents, status, created_at, updated_at
        ) VALUES (
          #{day.id}, #{@store.id}, #{@device.id}, NULL, #{@admin.id},
          #{@admin.id}, CURRENT_TIMESTAMP, 0, 'open', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  # --- PosDiscount / allocation ----------------------------------------------

  test "line-scoped discount requires a target line; DB check matches" do
    _day, session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction

    discount = PosDiscount.new(
      pos_transaction: txn, scope: "line", method: "fixed_amount",
      tax_treatment: "reduces_taxable_base", applied_amount_cents: 100,
      created_by_user: @admin
    )
    refute discount.valid?
    assert_includes discount.errors[:target_pos_line_item], "is required for line-scoped discounts"

    assert_raises(ActiveRecord::StatementInvalid) do
      PosDiscount.connection.execute(<<~SQL.squish)
        INSERT INTO pos_discounts (
          pos_transaction_id, scope, method, tax_treatment, applied_amount_cents,
          created_by_user_id, position, created_at
        ) VALUES (
          #{txn.id}, 'line', 'fixed_amount', 'reduces_taxable_base', 100,
          #{@admin.id}, 0, CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  test "discount allocation uniqueness is enforced by the database" do
    _day, session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
    line = Pos::AddOpenRingLine.call(
      pos_transaction: txn, department: departments(:books_new),
      unit_price_cents: 500, actor: @admin
    ).pos_line_item
    discount = PosDiscount.create!(
      pos_transaction: txn, scope: "transaction", method: "fixed_amount",
      tax_treatment: "reduces_taxable_base", applied_amount_cents: 100,
      created_by_user: @admin
    )
    PosDiscountAllocation.create!(
      pos_discount: discount, pos_line_item: line, allocated_amount_cents: 100
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      PosDiscountAllocation.connection.execute(<<~SQL.squish)
        INSERT INTO pos_discount_allocations (
          pos_discount_id, pos_line_item_id, allocated_amount_cents, created_at
        ) VALUES (#{discount.id}, #{line.id}, 50, CURRENT_TIMESTAMP)
      SQL
    end
  end

  # --- PosCashMovement -------------------------------------------------------

  test "cash movement requires positive amount and matching store" do
    _day, session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    type = cash_movement_types(:additional_float)

    zero = PosCashMovement.new(
      store: @store, pos_session: session, cash_movement_type: type,
      amount_cents: 0, created_by_user: @admin, reason: "float"
    )
    refute zero.valid?

    mismatched = PosCashMovement.new(
      store: @other_store, pos_session: session, cash_movement_type: type,
      amount_cents: 100, created_by_user: @admin, reason: "float"
    )
    refute mismatched.valid?
    assert_includes mismatched.errors[:store], "must match the session's store"

    assert_raises(ActiveRecord::StatementInvalid) do
      PosCashMovement.connection.execute(<<~SQL.squish)
        INSERT INTO pos_cash_movements (
          store_id, pos_session_id, cash_movement_type_id, amount_cents,
          created_by_user_id, reason, created_at
        ) VALUES (
          #{@store.id}, #{session.id}, #{type.id}, 0,
          #{@admin.id}, 'float', CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  # --- PosTender / PosTaxExemption / PosApproval -----------------------------

  test "tender store must match the transaction store" do
    _day, session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
    tender = PosTender.new(
      pos_transaction: txn, store: @other_store, tender_type: tender_types(:cash),
      direction: "received", status: "pending", amount_cents: 100, created_by_user: @admin
    )
    refute tender.valid?
    assert_includes tender.errors[:store], "must match the transaction's store"
  end

  test "database enforces one tax exemption per transaction" do
    _day, session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
    txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
    PosTaxExemption.create!(
      pos_transaction: txn, coverage: "whole_transaction",
      exemption_type: "resale", created_by_user: @admin
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      PosTaxExemption.connection.execute(<<~SQL.squish)
        INSERT INTO pos_tax_exemptions (
          pos_transaction_id, coverage, exemption_type, created_by_user_id, created_at, updated_at
        ) VALUES (
          #{txn.id}, 'whole_transaction', 'nonprofit', #{@admin.id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  test "approval rejects the same user as requester and approver" do
    approval = PosApproval.new(
      store: @store, action_type: "discount_apply", reason: "manager override",
      approved_at: Time.current, requested_by_user: @clerk, approved_by_user: @clerk
    )
    refute approval.valid?
    assert_includes approval.errors[:approved_by_user], "must be a different user than the requester"
  end

  # --- InventoryReservation --------------------------------------------------

  test "reservation shape rejects individual without unit and quantity with unit" do
    without_unit = InventoryReservation.new(
      store: @store, product_variant: @individual, source_type: "pos_line_item",
      source_id: 1, quantity: 1, status: "active", reserved_at: Time.current
    )
    refute without_unit.valid?
    assert_includes without_unit.errors[:inventory_unit], "is required for individually tracked reservations"

    unit = InventoryUnit.create!(
      store: @store, product_variant: @individual, unit_identifier: "2700000000014",
      status: "available", acquired_at: Time.current, created_by_user: @admin
    )
    quantity_with_unit = InventoryReservation.new(
      store: @store, product_variant: @variant, inventory_unit: unit,
      source_type: "pos_line_item", source_id: 2, quantity: 1,
      status: "active", reserved_at: Time.current
    )
    refute quantity_with_unit.valid?
    assert_includes quantity_with_unit.errors[:inventory_unit], "must be blank for quantity-tracked reservations"
  end

  test "database enforces one active reservation per inventory unit" do
    unit = InventoryUnit.create!(
      store: @store, product_variant: @individual, unit_identifier: "2700000000021",
      status: "available", acquired_at: Time.current, created_by_user: @admin
    )
    InventoryReservation.create!(
      store: @store, product_variant: @individual, inventory_unit: unit,
      source_type: "pos_line_item", source_id: 10, quantity: 1,
      status: "active", reserved_at: Time.current
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      InventoryReservation.connection.execute(<<~SQL.squish)
        INSERT INTO inventory_reservations (
          store_id, product_variant_id, inventory_unit_id, source_type, source_id,
          quantity, status, reserved_at, created_at, updated_at
        ) VALUES (
          #{@store.id}, #{@individual.id}, #{unit.id}, 'pos_line_item', 11,
          1, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  # --- StockBalance ----------------------------------------------------------

  test "stock balance available formula and quantity-tracking requirement" do
    balance = StockBalance.new(
      store: @store, product_variant: @variant,
      on_hand: 10, reserved: 3, unavailable: 2, cost_quality: "unknown"
    )
    assert_equal 5, balance.available

    individual_balance = StockBalance.new(
      store: @store, product_variant: @individual,
      on_hand: 1, reserved: 0, unavailable: 0, cost_quality: "unknown"
    )
    refute individual_balance.valid?
    assert_includes individual_balance.errors[:product_variant], "must use quantity inventory tracking"
  end

  test "database enforces one stock balance per store and variant" do
    StockBalance.create!(
      store: @store, product_variant: @variant,
      on_hand: 0, reserved: 0, unavailable: 0, cost_quality: "unknown"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      StockBalance.connection.execute(<<~SQL.squish)
        INSERT INTO stock_balances (
          store_id, product_variant_id, on_hand, reserved, unavailable, cost_quality,
          lock_version, created_at, updated_at
        ) VALUES (
          #{@store.id}, #{@variant.id}, 0, 0, 0, 'unknown',
          0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  test "database rejects zero on_hand with non-unknown cost quality" do
    balance = StockBalance.create!(
      store: @store, product_variant: @variant,
      on_hand: 0, reserved: 0, unavailable: 0, cost_quality: "unknown"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      balance.update_columns(cost_quality: "actual", inventory_value_cents: 0)
    end
  end
end
