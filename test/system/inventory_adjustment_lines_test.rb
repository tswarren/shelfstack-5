# frozen_string_literal: true

require "application_system_test_case"

# Phase 4f UX baseline (PR3): the inventory adjustment document workspace must
# let staff add, remove, and reorder lines while always retaining at least one
# line row (the last line can never be removed).
class InventoryAdjustmentLinesTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
  end

  test "adds and removes lines but always retains at least one" do
    visit new_inventory_adjustment_path

    assert_selector "fieldset.adjustment-line", count: 1
    # The only line cannot be removed.
    assert_selector "[data-inventory-adjustment-form-target='removeButton'][disabled]"

    click_button "Add line"
    assert_selector "fieldset.adjustment-line", count: 2
    click_button "Add line"
    assert_selector "fieldset.adjustment-line", count: 3
    # With multiple lines, removal is enabled.
    assert_no_selector "[data-inventory-adjustment-form-target='removeButton'][disabled]"

    within all("fieldset.adjustment-line").last do
      click_button "Remove"
    end
    assert_selector "fieldset.adjustment-line", count: 2

    within all("fieldset.adjustment-line").last do
      click_button "Remove"
    end
    assert_selector "fieldset.adjustment-line", count: 1

    # Back down to one line: removal is disabled again — cannot remove all.
    assert_selector "[data-inventory-adjustment-form-target='removeButton'][disabled]"
  end

  test "reorders lines and keeps positions aligned with display order" do
    visit new_inventory_adjustment_path
    click_button "Add line"

    lines = all("fieldset.adjustment-line")
    within(lines[0]) { fill_in "Quantity Δ", with: "11" }
    within(lines[1]) { fill_in "Quantity Δ", with: "22" }

    within(lines[0]) { find("button[aria-label='Move line down']").click }

    reordered = all("fieldset.adjustment-line")
    assert_equal "22", reordered[0].find("input[name*='quantity_delta']").value
    assert_equal "11", reordered[1].find("input[name*='quantity_delta']").value
    # Position hidden fields track the new display order.
    assert_equal "0", reordered[0].find("input[name*='[position]']", visible: :all).value
    assert_equal "1", reordered[1].find("input[name*='[position]']", visible: :all).value
  end
end
