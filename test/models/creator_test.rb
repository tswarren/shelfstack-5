# frozen_string_literal: true

require "test_helper"

class CreatorTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "normalizes name for matching while retaining punctuation and diacritics" do
    creator = Creator.create!(organization: @organization, display_name: "  Ursula K.  Le Guin  ")

    assert_equal "ursula k. le guin", creator.normalized_name
  end

  test "defaults sort_name to display_name without inverting" do
    creator = Creator.create!(organization: @organization, display_name: "Ray Bradbury")

    assert_equal "Ray Bradbury", creator.sort_name
  end

  test "does not overwrite an explicitly provided sort_name" do
    creator = Creator.create!(organization: @organization, display_name: "Ray Bradbury", sort_name: "Bradbury, Ray")

    assert_equal "Bradbury, Ray", creator.sort_name
  end

  test "requires display_name" do
    creator = Creator.new(organization: @organization)

    assert_not creator.valid?
    assert_includes creator.errors[:display_name], "can't be blank"
  end

  test "duplicate display names and normalized names are permitted" do
    Creator.create!(organization: @organization, display_name: "Same Name")

    duplicate = Creator.create!(organization: @organization, display_name: "Same Name")

    assert duplicate.persisted?
  end

  test "deactivation preserves existing ProductCreator links" do
    creator = creators(:ray_bradbury)
    product = products(:sample_book)
    link = ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)

    creator.update!(active: false)

    assert link.reload.persisted?
    assert_equal creator.id, link.creator_id
  end

  test "restricts destroy while linked to a product" do
    creator = creators(:ray_bradbury)
    ProductCreator.create!(product: products(:sample_book), creator: creator, role: "author", position: 0)

    assert_raises(ActiveRecord::DeleteRestrictionError) { creator.destroy! }
  end
end
