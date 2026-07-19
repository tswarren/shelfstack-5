# frozen_string_literal: true

require "test_helper"

# Phase 4f UX baseline (PR3): catalog and inventory back-office page patterns —
# Pagy pagination with filter preservation, decimal money parsing, adjustment
# line scaffolding, and reservation release with a captured reason.
class CatalogInventoryUxBaselineTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    @org = organizations(:acme)
    @store = stores(:main_street)
    @admin = users(:admin)
    @variant = product_variants(:sample_book_standard)
    post session_path, params: { username: "admin", password: "password123" }
  end

  # --- Products: search + validation ---------------------------------------

  test "product index renders the data-table and search toolbar" do
    get products_path
    assert_response :success
    assert_select "form[role='search']"
    assert_select "table.data-table"
    assert_match "The Illustrated Man", response.body
  end

  test "product search filters by name and shows a result count" do
    get products_path, params: { q: "Illustrated" }
    assert_response :success
    assert_match "The Illustrated Man", response.body
    assert_no_match(/UPC Sample/, response.body)
    assert_select ".pagination-info"
  end

  test "creating a product parses decimal money into cents" do
    assert_difference "Product.count", 1 do
      post products_path, params: {
        identifier: "",
        product: {
          name: "Decimal Priced", product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          status: "active", sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity", regular_price: "12.95",
          sellable: true, status: "active"
        }
      }
    end

    variant = Product.order(:id).last.product_variants.first
    assert_equal 1295, variant.regular_price_cents
  end

  test "invalid money on product form is rejected and redisplayed" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)
    original_cents = variant.regular_price_cents

    patch product_path(product), params: {
      product: {
        name: product.name, product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status, sellable: product.sellable,
        list_price: "abc"
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price: "12.95",
        sellable: variant.sellable, status: variant.status
      }
    }

    assert_response :unprocessable_entity
    assert_select "#form-errors-product"
    assert_select "input#product_list_price[value='abc'][aria-invalid='true']"
    assert_equal original_cents, variant.reload.regular_price_cents
  end

  test "product form re-renders with shared errors when validation fails" do
    assert_no_difference "Product.count" do
      post products_path, params: {
        identifier: "",
        product: {
          name: "", product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          status: "active", sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity", regular_price: "",
          sellable: true, status: "active"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
    assert_select "section.form-section"
  end

  # --- Products: pagination + filter preservation --------------------------

  test "products paginate at 25 with an out-of-range redirect preserving filters" do
    format = product_formats(:hardcover)
    30.times do |i|
      @org.products.create!(
        identifier: "BULK#{format("%09d", i)}",
        name: "Bulk Product #{format("%02d", i)}",
        product_type: "book", product_format: format,
        status: "active", sellable: false
      )
    end

    get products_path, params: { q: "Bulk Product" }
    assert_response :success
    assert_select "tbody tr", 25
    assert_select "nav.pagination-bar"

    get products_path, params: { q: "Bulk Product", page: 2 }
    assert_response :success
    assert_select "tbody tr", 5
    assert_no_match(/The Illustrated Man/, response.body)

    get products_path, params: { q: "Bulk Product", page: 999 }
    assert_response :redirect
    assert_match(/page=2/, @response.location)
    assert_match(/q=Bulk/, @response.location)
  end

  test "the page size is clamped to a maximum of 100" do
    get products_path, params: { limit: 999 }
    assert_response :success
    # No error; clamped limit keeps the request valid.
  end

  # --- Stock balances: filters + negative warning --------------------------

  test "stock balances flag negative rows and filter by availability" do
    StockBalance.create!(
      store: @store, product_variant: @variant,
      on_hand: -2, reserved: 0, unavailable: 0, cost_quality: "unknown"
    )

    get stock_balances_path
    assert_response :success
    assert_select "tr.is-warning"

    get stock_balances_path, params: { availability: "negative" }
    assert_response :success
    assert_match @variant.sku, response.body

    get stock_balances_path, params: { availability: "in_stock" }
    assert_response :success
    assert_no_match(/#{@variant.sku}/, response.body)
  end

  # --- Inventory adjustments: line scaffolding + decimal money -------------

  test "adjustment form exposes add-line and removable-line scaffolding" do
    get new_inventory_adjustment_path
    assert_response :success
    assert_select "[data-action~='inventory-adjustment-form#addLine']"
    assert_select "template[data-inventory-adjustment-form-target='lineTemplate']"
    assert_select "button[data-inventory-adjustment-form-target='removeButton']"
  end

  test "adjustment create parses decimal cost into cents" do
    reason = inventory_adjustment_reasons(:opening_other)

    assert_difference "InventoryAdjustmentLine.count", 1 do
      post inventory_adjustments_path, params: {
        inventory_adjustment: {
          kind: "opening_inventory",
          inventory_adjustment_reason_id: reason.id,
          note: "",
          inventory_adjustment_lines_attributes: {
            "0" => {
              product_variant_id: @variant.id, quantity_delta: 2,
              input_unit_cost: "3.50", input_cost_method: "explicit",
              input_cost_quality: "actual", position: 0
            }
          }
        }
      }
    end

    line = InventoryAdjustmentLine.order(:id).last
    assert_equal 350, line.input_unit_cost_cents
  end

  # --- Reservations: filters + release with reason -------------------------

  test "reservation release captures the supplied reason instead of a hard-coded value" do
    StockBalance.create!(
      store: @store, product_variant: @variant,
      on_hand: 5, reserved: 2, unavailable: 0,
      cost_quality: "unknown", inventory_value_cents: nil
    )
    reservation = InventoryReservation.create!(
      store: @store, product_variant: @variant,
      source_type: "pos_line_item", source_id: 1,
      quantity: 2, status: "active", reserved_at: Time.current
    )

    get inventory_reservations_path(status: "active")
    assert_response :success
    assert_select "input[name='release_reason']"

    post release_inventory_reservation_path(reservation),
         params: { release_reason: "Customer changed mind" }

    assert_redirected_to inventory_reservations_path
    reservation.reload
    assert_equal "released", reservation.status
    assert_equal "Customer changed mind", reservation.release_reason
  end

  # --- Render smoke tests for standardized detail / form screens -----------

  test "product show renders the record-detail pattern" do
    get product_path(products(:sample_book))
    assert_response :success
    assert_select "section.record-section", minimum: 3
    assert_select "table.data-table"
  end

  test "stock balance show renders the summary strip and ledger section" do
    balance = StockBalance.create!(
      store: @store, product_variant: @variant,
      on_hand: -1, reserved: 0, unavailable: 0, cost_quality: "unknown"
    )
    get stock_balance_path(balance)
    assert_response :success
    assert_select ".summary-strip .metric", 4
  end

  test "inventory adjustment show renders status badge and finalize actions" do
    adjustment = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_other),
      created_by_user: @admin
    )
    adjustment.inventory_adjustment_lines.create!(product_variant: @variant, quantity_delta: 1, position: 0)

    get inventory_adjustment_path(adjustment)
    assert_response :success
    assert_select ".badge"
    assert_select "form[action=?]", post_inventory_adjustment_path(adjustment)
    assert_select "form[action=?]", cancel_inventory_adjustment_path(adjustment)
  end

  test "inventory unit new and show render standardized patterns" do
    get new_inventory_unit_path
    assert_response :success
    assert_select "section.form-section"
    assert_select ".form-errors", false

    unit = Inventory::CreateInventoryUnit.call(
      store: @store, product_variant: product_variants(:signed_book_standard),
      actor: @admin, acquisition_cost_cents: 1000
    ).inventory_unit

    get inventory_unit_path(unit)
    assert_response :success
    assert_select "section.record-section"
  end
end
