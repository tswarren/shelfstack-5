# frozen_string_literal: true

require "application_system_test_case"

class RecordPickerSystemTest < ApplicationSystemTestCase
  setup do
    IdentifierSequence.ensure_defaults!
    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"
  end

  test "search and select tax category with mouse persists on save" do
    product = products(:sample_book)
    stationery = tax_categories(:stationery)

    visit edit_product_path(product)
    select_picker_result(
      query_id: "product_default_tax_category_id_query",
      query: "Stationery",
      result_text: stationery.name
    )

    click_button "Update product"
    assert_text "Product updated."
    assert_equal stationery.id, product.reload.default_tax_category_id
  end

  test "search and select with keyboard arrows and enter" do
    product = products(:sample_book)
    stationery = tax_categories(:stationery)

    visit edit_product_path(product)
    input = find("#product_default_tax_category_id_query")
    input.click
    input.set("Station")
    assert_selector ".record-picker-option", text: /Stationery/, wait: 5
    input.send_keys(:arrow_down, :enter)

    expected_label = ApplicationController.helpers.record_picker_label(stationery, "tax_category")
    assert_equal expected_label, find("#product_default_tax_category_id_query").value
    assert_equal stationery.id.to_s, find("#product_default_tax_category_id", visible: :all).value
  end

  test "unmatched text restores committed optional association and blocks submit" do
    product = products(:sample_book)
    original_tax_id = product.default_tax_category_id
    assert_predicate original_tax_id, :present?

    visit edit_product_path(product)
    input = find("#product_default_tax_category_id_query")
    committed = input.value
    input.set("not-a-real-tax-category-xyz")

    # Browser constraint validation should block submit while unmatched.
    click_button "Update product"
    assert_current_path edit_product_path(product)
    assert_equal original_tax_id, product.reload.default_tax_category_id

    # Escape restores committed label/id synchronously.
    find("#product_default_tax_category_id_query").send_keys(:escape)
    assert_equal committed, find("#product_default_tax_category_id_query").value
    assert_equal original_tax_id.to_s, find("#product_default_tax_category_id", visible: :all).value
  end

  test "explicit clear blanks optional tax category on save" do
    product = products(:sample_book)
    assert_predicate product.default_tax_category_id, :present?

    visit edit_product_path(product)
    within find("#product_default_tax_category_id_query").ancestor(".record-picker") do
      click_button "Clear"
    end
    assert_equal "", find("#product_default_tax_category_id", visible: :all).value

    click_button "Update product"
    assert_text "Product updated."
    assert_nil product.reload.default_tax_category_id
  end

  test "changing product on request clears and rescopes variant picker" do
    visit new_product_request_path
    select_picker_result(
      query_id: "product_request_product_id_query",
      query: "Illustrated",
      result_text: /Illustrated/
    )
    sample_variant = product_variants(:sample_book_standard)
    select_picker_result(
      query_id: "product_request_product_variant_id_query",
      query: "Standard",
      result_text: /SKU #{sample_variant.sku}/
    )
    assert_equal sample_variant.id.to_s, find("#product_request_product_variant_id", visible: :all).value

    select_picker_result(
      query_id: "product_request_product_id_query",
      query: "UPC Sample",
      result_text: /UPC Sample/
    )
    assert_equal "", find("#product_request_product_variant_id", visible: :all).value
    assert_equal "", find("#product_request_product_variant_id_query").value
  end

  test "inactive vendors are hidden from default search results" do
    visit new_product_variant_vendor_path
    input = find("#product_variant_vendor_vendor_id_query")
    input.click
    input.set("Old")
    sleep 0.4
    assert_no_selector ".record-picker-option", text: /Old Vendor/
  end

  test "selected labels survive validation rerender" do
    visit new_product_path
    select_picker_result(
      query_id: "product_merchandise_class_id_query",
      query: "fiction",
      result_text: /Fiction/i
    )
    label = find("#product_merchandise_class_id_query").value
    # Bypass HTML5 required so the server re-renders the form with errors.
    page.execute_script("document.querySelector('#product_name')?.removeAttribute('required')")
    click_button "Create product"
    assert_selector "#form-errors-product, .field-error", wait: 5
    assert_equal label, find("#product_merchandise_class_id_query").value
  end

  test "stale delayed search response does not repopulate after clear" do
    visit edit_product_path(products(:sample_book))
    picker = find("#product_default_tax_category_id_query").ancestor(".record-picker")
    page.execute_script(
      "const el = arguments[0]; const c = window.Stimulus.getControllerForElementAndIdentifier(el, 'record-picker'); c.searchUrlValue = arguments[1];",
      picker.native,
      catalog_slow_record_searches_path
    )

    input = find("#product_default_tax_category_id_query")
    input.click
    input.set("delay")
    sleep 0.25
    within(picker) { click_button "Clear" }
    sleep 0.8
    assert_no_selector ".record-picker-option", text: /STALE RESULT/
  end

  private

  def select_picker_result(query_id:, query:, result_text:)
    input = find("##{query_id}")
    input.click
    input.set(query)
    option = find(".record-picker-option", text: result_text, wait: 5)
    option.click
  end
end
