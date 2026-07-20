# frozen_string_literal: true

require "test_helper"

class MerchandiseClassTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
    @postable_department = departments(:books_new)
    @non_postable_department = departments(:non_postable)
  end

  test "enforces level and parent progression" do
    primary = @organization.merchandise_classes.create!(
      code: "test_fiction",
      name: "Test Fiction",
      level: "primary",
      default_department: @postable_department,
      active: true
    )

    secondary = @organization.merchandise_classes.new(
      code: "test_fiction.literary",
      name: "Literary Fiction",
      level: "secondary",
      parent: primary,
      default_department: @postable_department,
      active: true
    )
    assert secondary.valid?

    invalid_secondary = @organization.merchandise_classes.new(
      code: "test_orphan.secondary",
      name: "Orphan Secondary",
      level: "secondary",
      default_department: @postable_department,
      active: true
    )
    assert_not invalid_secondary.valid?
    assert_includes invalid_secondary.errors[:parent], "is required for secondary level"

    invalid_parent_level = @organization.merchandise_classes.new(
      code: "test_fiction.bad_minor",
      name: "Bad Minor",
      level: "minor",
      parent: primary,
      default_department: @postable_department,
      active: true
    )
    assert_not invalid_parent_level.valid?
    assert_includes invalid_parent_level.errors[:parent], "must be secondary level"
  end

  test "requires postable default departments" do
    merchandise_class = @organization.merchandise_classes.new(
      code: "nonpostable.default",
      name: "Bad Default",
      level: "primary",
      default_department: @non_postable_department,
      active: true
    )

    assert_not merchandise_class.valid?
    assert_includes merchandise_class.errors[:default_department], "must be postable"
  end

  test "code is readonly after create" do
    merchandise_class = @organization.merchandise_classes.create!(
      code: "test_history",
      name: "History",
      level: "primary",
      default_department: @postable_department,
      active: true
    )

    assert_raises(ActiveRecord::ReadonlyAttributeError) { merchandise_class.code = "changed" }
  end

  test "sorted_hierarchically is depth-first by position then name" do
    zebra = @organization.merchandise_classes.create!(
      code: "z_primary", name: "Zebra", level: "primary",
      position: 2, default_department: @postable_department, active: true
    )
    alpha = @organization.merchandise_classes.create!(
      code: "a_primary", name: "Alpha", level: "primary",
      position: 1, default_department: @postable_department, active: true
    )
    child_b = @organization.merchandise_classes.create!(
      code: "a_primary.b", name: "Beta child", level: "secondary",
      parent: alpha, position: 2, default_department: @postable_department, active: true
    )
    child_a = @organization.merchandise_classes.create!(
      code: "a_primary.a", name: "Alpha child", level: "secondary",
      parent: alpha, position: 1, default_department: @postable_department, active: true
    )

    ordered = MerchandiseClass.sorted_hierarchically(
      @organization.merchandise_classes.where(id: [ zebra.id, alpha.id, child_a.id, child_b.id ])
    )

    assert_equal [ alpha, child_a, child_b, zebra ].map(&:id), ordered.map(&:id)
  end
end
