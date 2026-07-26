# frozen_string_literal: true

require "test_helper"

class IconsHelperTest < ActionView::TestCase
  test "renders allowlisted icon with aria-hidden by default" do
    html = icon_tag("info")
    assert_includes html, 'aria-hidden="true"'
    assert_includes html, 'fill="currentColor"'
    assert_includes html, "icon-info"
  end

  test "labelled icon exposes accessible name" do
    html = icon_tag("info", title: "Source detail")
    assert_includes html, 'aria-label="Source detail"'
    assert_includes html, 'role="img"'
    assert_not_includes html, 'aria-hidden="true"'
  end

  test "rejects unknown icon names" do
    assert_raises(ArgumentError) { icon_tag("not-a-real-icon") }
  end
end
