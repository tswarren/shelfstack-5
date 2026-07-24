# frozen_string_literal: true

require "test_helper"

class ProductCreatorTest < ActiveSupport::TestCase
  setup do
    @product = products(:sample_book)
    @creator = creators(:ray_bradbury)
  end

  test "requires an allowlisted role" do
    link = ProductCreator.new(product: @product, creator: @creator, role: "ghostwriter", position: 0)

    assert_not link.valid?
    assert_includes link.errors[:role], "is not included in the list"
  end

  test "requires a non-negative position" do
    link = ProductCreator.new(product: @product, creator: @creator, role: "author", position: -1)

    assert_not link.valid?
    assert_includes link.errors[:position], "must be greater than or equal to 0"
  end

  test "rejects a creator from a different organization" do
    foreign = create_foreign_organization_catalog!
    link = ProductCreator.new(product: @product, creator: foreign[:creator], role: "author", position: 0)

    assert_not link.valid?
    assert_includes link.errors[:creator].join, "must belong to the same organization"
  end

  test "soft-rejects the same creator and role twice on one product" do
    ProductCreator.create!(product: @product, creator: @creator, role: "author", position: 0)
    duplicate = ProductCreator.new(product: @product, creator: @creator, role: "author", position: 1)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:creator_id].join, "already linked"
  end

  test "allows the same creator with a different role on one product" do
    ProductCreator.create!(product: @product, creator: @creator, role: "author", position: 0)
    other_role = ProductCreator.new(product: @product, creator: @creator, role: "illustrator", position: 1)

    assert other_role.valid?
  end

  test "database check constraint rejects an out-of-allowlist role" do
    link = ProductCreator.new(product: @product, creator: @creator, role: "author", position: 0)
    link.save!(validate: false) # baseline row exists
    invalid = ProductCreator.new(product: @product, creator: @creator, role: "author", position: 1)

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid) do
      invalid.role = "ghostwriter"
      invalid.save!(validate: false)
    end
  end
end
