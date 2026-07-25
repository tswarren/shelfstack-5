# frozen_string_literal: true

require "test_helper"

class CatalogHelperTest < ActionView::TestCase
  Identity = Data.define(:publication_date)

  test "publication_date_label formats an exact long date" do
    identity = Identity.new(publication_date: Date.new(2014, 2, 15))
    assert_equal Date.new(2014, 2, 15).to_fs(:long), publication_date_label(identity)
  end

  test "publication_date_label returns nil when blank" do
    assert_nil publication_date_label(Identity.new(publication_date: nil))
  end

  test "language_code_label uses curated labels" do
    assert_equal "English (eng)", language_code_label("eng")
  end

  test "sale_eligibility_blocker_label maps known codes and humanizes unknown" do
    assert_equal "Selling price is missing", sale_eligibility_blocker_label("missing_price")
    assert_equal "Some new blocker", sale_eligibility_blocker_label("some_new_blocker")
  end
end
