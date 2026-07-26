# frozen_string_literal: true

require "test_helper"

class MerchandiseClassFormHelperTest < ActionView::TestCase
  include ApplicationHelper
  include MerchandiseClassFormHelper

  setup do
    @organization = organizations(:acme)
  end

  test "select options ignore foreign merchandise class objects" do
    foreign = create_foreign_organization_catalog!
    options = merchandise_class_select_options(@organization, selected: foreign[:merchandise_class])
    labels = options.map(&:first)

    assert labels.none? { |label| label.include?(ForeignOrganizationHelper::SECRET_CLASS_NAME) }
    assert_nil options.find { |_, id, _| id == foreign[:merchandise_class].id }
  end

  test "cascade payload ignores foreign merchandise class objects" do
    foreign = create_foreign_organization_catalog!
    payload = merchandise_class_cascade_payload(@organization, selected: foreign[:merchandise_class])

    assert_nil payload[:selected_id]
    assert payload[:nodes].none? { |node| node[:name] == ForeignOrganizationHelper::SECRET_CLASS_NAME }
  end

  test "select options include org-scoped selected inactive ancestors" do
    selected = merchandise_classes(:fiction_primary)
    options = merchandise_class_select_options(@organization, selected: selected)

    assert options.any? { |_, id, _| id == selected.id }
  end
end
