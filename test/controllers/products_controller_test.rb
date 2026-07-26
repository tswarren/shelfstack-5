# frozen_string_literal: true

require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    IdentifierSequence.ensure_defaults!
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists products" do
    get products_path
    assert_response :success
    assert_match "The Illustrated Man", response.body
  end

  test "product summary hub frames selected-store ops and organization-wide vendors" do
    product = products(:sample_book)

    get product_path(product)
    assert_response :success
    assert_match "Store status — Main Street", response.body
    assert_match 'id="overview"', response.body
    assert_match 'id="selling"', response.body
    assert_match 'id="inventory"', response.body
    assert_match 'id="supply"', response.body
    assert_match "data-controller=\"tabs\"", response.body
    assert_match "Vendor sources — Organization-wide", response.body
    assert_no_match(/Stock — Organization/i, response.body)
    assert_match "Selling configuration", response.body
    assert_match product.product_variants.first.sku, response.body
  end

  test "product show renders all tab panel content without JavaScript enhancement" do
    product = products(:sample_book)

    get product_path(product)
    assert_response :success
    assert_match 'href="#overview"', response.body
    assert_match 'href="#inventory"', response.body
    assert_match 'data-tabs-target="panel"', response.body
    assert_no_match(/role="tablist"/, response.body)
    assert_match product.name, response.body
  end

  test "product summary hub omits unauthorized stock section content" do
    product = products(:sample_book)
    RolePermission.where(
      role: roles(:administrator),
      permission: permissions(:inventory_stock_view)
    ).delete_all

    get product_path(product)
    assert_response :success
    assert_match "Stock details are not available with your permissions", response.body
    assert_no_match(/View stock balance/, response.body)
  end

  test "product summary hub omits cost fields without inventory.cost.view" do
    product = products(:sample_book)
    RolePermission.where(
      role: roles(:administrator),
      permission: permissions(:inventory_cost_view)
    ).delete_all

    get product_path(product)
    assert_response :success
    assert_no_match(/Moving average cost/, response.body)
  end

  test "product summary hub GET show does not mutate records" do
    product = products(:sample_book)
    variant = product.product_variants.first

    assert_no_difference -> { Product.count } do
      assert_no_difference -> { ProductVariant.count } do
        assert_no_difference -> { StockBalance.count } do
          assert_no_difference -> { ProductVariantVendor.count } do
            get product_path(product)
          end
        end
      end
    end

    assert_response :success
    assert_equal product.updated_at.to_i, product.reload.updated_at.to_i
    assert_equal variant.updated_at.to_i, variant.reload.updated_at.to_i
  end

  test "edit form uses shared record pickers for classification links" do
    product = products(:sample_book)
    get edit_product_path(product)
    assert_response :success
    assert_match "data-controller=\"record-picker\"", response.body
    assert_match "data-controller=\"merchandise-class-cascade\"", response.body
    assert_match 'name="product[merchandise_class_id]"', response.body
    assert_match "data-record-picker-record-type-value=\"department\"", response.body
    assert_match "data-record-picker-record-type-value=\"product_format\"", response.body
    assert_match "data-record-picker-record-type-value=\"tax_category\"", response.body
  end

  test "new product form defaults product and variant sellable to true" do
    get new_product_path
    assert_response :success
    assert_select "input[name='product[sellable]'][type='checkbox'][checked]"
    assert_select "input[name='product_variant[sellable]'][type='checkbox'][checked]"
    assert_match "form-actions--sticky", response.body
  end

  test "searches by normalized ISBN-10 input" do
    get products_path, params: { q: "0-306-40615-2" }
    assert_response :success
    assert_match "The Illustrated Man", response.body
  end

  test "creates product through service" do
    assert_difference "Product.count", 1 do
      post products_path, params: {
        identifier: "",
        product: {
          name: "Created Via UI",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          merchandise_class_id: merchandise_classes(:fiction_primary).id,
          default_department_id: departments(:books_new).id,
          default_tax_category_id: tax_categories(:physical_book).id,
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 1599,
          sellable: true,
          status: "active"
        }
      }
    end

    product = Product.order(:id).last
    assert_redirected_to product_path(product)
    assert_match(/\A29\d{11}\z/, product.identifier)
  end

  test "shows explicit identifier warning when checksum fails" do
    assert_no_difference "Product.count" do
      post products_path, params: {
        identifier: "9781786798986",
        product: {
          name: "Mavericks",
          subtitle: "Kept on redisplay",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          publisher_or_manufacturer_name: "Test Press",
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 2495,
          sellable: true,
          status: "active"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/invalid EAN-13 check digit/, response.body)
    assert_match(/Save anyway/, response.body)
    assert_match(/accept_identifier_warning/, response.body)
    assert_match(/accepted_identifier_normalized/, response.body)
    assert_match(/value="Mavericks"/, response.body)
    assert_match(/value="Kept on redisplay"/, response.body)
    assert_match(/value="Test Press"/, response.body)
    assert_match(/value="9781786798986"/, response.body)
  end

  test "accepts warned identifier via checkbox and preserves create" do
    assert_difference "Product.count", 1 do
      post products_path, params: {
        identifier: "9781786798986",
        accept_identifier_warning: "1",
        accepted_identifier_normalized: "9781786798986",
        product: {
          name: "Warned Accept",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          merchandise_class_id: merchandise_classes(:fiction_primary).id,
          default_department_id: departments(:books_new).id,
          default_tax_category_id: tax_categories(:physical_book).id,
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 2495,
          sellable: true,
          status: "active"
        }
      }
    end

    product = Product.order(:id).last
    assert_redirected_to product_path(product)
    assert_equal "9781786798986", product.identifier
    assert_equal "warning", product.identifier_validation_status
  end

  test "invalid ISBN-10 check digit blocks without save-anyway override" do
    assert_no_difference "Product.count" do
      post products_path, params: {
        identifier: "0-306-40615-3",
        product: {
          name: "ISBN10 Blocked",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 1999,
          sellable: true,
          status: "active"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/invalid ISBN-10 check digit/, response.body)
    assert_no_match(/Save anyway/, response.body)
    assert_match(/value="ISBN10 Blocked"/, response.body)
    assert_match(/value="0-306-40615-3"/, response.body)
  end

  test "price sync mode survives validation redisplay when regular price is cleared" do
    assert_no_difference "Product.count" do
      post products_path, params: {
        price_sync_mode: "independent",
        product: {
          name: "",
          list_price: "24.95",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          status: "active",
          sellable: true
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price: "",
          sellable: true,
          status: "active"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/name="price_sync_mode"[^>]*value="independent"/, response.body)
    assert_match(/data-price-sync-mode-value="independent"/, response.body)
  end

  test "denies clerk without catalog permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get products_path
    assert_redirected_to root_path
  end

  test "validation rerender does not disclose foreign-organization classification labels" do
    foreign = create_foreign_organization_catalog!
    product = products(:sample_book)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        merchandise_class_id: foreign[:merchandise_class].id,
        default_department_id: foreign[:department].id,
        default_tax_category_id: foreign[:tax_category].id,
        status: product.status,
        sellable: product.sellable
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_response :unprocessable_entity
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_CLASS_NAME)}/, response.body)
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_TAX_NAME)}/, response.body)
    assert_no_match(/Foreign Department SECRET/, response.body)
    assert_match(/must belong to the same organization/, response.body)
  end

  test "editor without deactivate can edit an already nonsellable product" do
    product = products(:sample_book)
    product.update!(sellable: false)
    variant = product.product_variants.first

    delete session_path
    post session_path, params: { username: "cateditor", password: "password123" }

    patch product_path(product), params: {
      product: {
        name: "Edited Without Deactivate",
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: false
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    assert_equal "Edited Without Deactivate", product.reload.name
  end

  test "editor without deactivate cannot transition sellable product to nonsellable" do
    product = products(:sample_book)
    variant = product.product_variants.first
    assert product.sellable?

    delete session_path
    post session_path, params: { username: "cateditor", password: "password123" }

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: "active",
        sellable: false
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: true,
        status: "active"
      }
    }

    assert_redirected_to root_path
    assert product.reload.sellable?
  end

  test "creates a product with ordered creator assignments" do
    bradbury = creators(:ray_bradbury)
    le_guin = creators(:ursula_le_guin)

    assert_difference "Product.count", 1 do
      post products_path, params: {
        identifier: "",
        product: {
          name: "Created With Creators",
          product_type: "book",
          product_format_id: product_formats(:hardcover).id,
          merchandise_class_id: merchandise_classes(:fiction_primary).id,
          default_department_id: departments(:books_new).id,
          default_tax_category_id: tax_categories(:physical_book).id,
          status: "active",
          sellable: true,
          creator_assignments_provided: "1",
          creator_assignments: [
            { creator_id: le_guin.id, role: "author" },
            { creator_id: bradbury.id, role: "illustrator" }
          ]
        },
        product_variant: {
          inventory_tracking_mode: "quantity",
          regular_price_cents: 1599,
          sellable: true,
          status: "active"
        }
      }
    end

    product = Product.order(:id).last
    assert_redirected_to product_path(product)
    assert_equal [ le_guin.id, bradbury.id ], product.product_creators.order(:position).pluck(:creator_id)
  end

  test "update without creator_assignments_provided leaves existing creator links untouched" do
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: "Renamed Without Touching Creators",
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    assert_equal [ creator.id ], product.product_creators.reload.pluck(:creator_id)
  end

  test "update with an explicit empty creator_assignments array clears existing links" do
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        creator_assignments_provided: "1",
        creator_assignments: []
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    assert_empty product.product_creators.reload
  end

  test "edit form uses unique row keys when the same creator has multiple roles" do
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    author_link = ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    illustrator_link = ProductCreator.create!(
      product: product, creator: creator, role: "illustrator", position: 1, credited_as: "Cover art"
    )

    get edit_product_path(product)
    assert_response :success

    author_key = "product_creator_#{author_link.id}"
    illustrator_key = "product_creator_#{illustrator_link.id}"
    assert_match(/id="creator-assignment-row-#{Regexp.escape(author_key)}"/, response.body)
    assert_match(/id="creator-assignment-row-#{Regexp.escape(illustrator_key)}"/, response.body)
    assert_match(/id="product_creator_assignment_#{Regexp.escape(author_key)}_creator_picker"/, response.body)
    assert_match(/id="product_creator_assignment_#{Regexp.escape(illustrator_key)}_creator_picker"/, response.body)
    assert_match(/id="inline-creator-opener-#{Regexp.escape(illustrator_key)}"/, response.body)
    assert_match(/value="Cover art"/, response.body)
    assert_select "option[value=illustrator][selected]", 1
  end

  test "validation rerender does not disclose a foreign-organization creator label" do
    foreign = create_foreign_organization_catalog!
    product = products(:sample_book)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        creator_assignments_provided: "1",
        creator_assignments: [ { creator_id: foreign[:creator].id, role: "author" } ]
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_response :unprocessable_entity
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_CREATOR_NAME)}/, response.body)
  end

  test "update with credited_as over 255 characters returns unprocessable and leaves links unchanged" do
    product = products(:sample_book)
    creator = creators(:ray_bradbury)
    ProductCreator.create!(product: product, creator: creator, role: "author", position: 0)
    variant = product.product_variants.first
    le_guin = creators(:ursula_le_guin)

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        creator_assignments_provided: "1",
        creator_assignments: [ { creator_id: le_guin.id, role: "author", credited_as: "x" * 256 } ]
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_response :unprocessable_entity
    assert_equal [ creator.id ], product.product_creators.reload.pluck(:creator_id)
  end

  test "persists plain publication date and language select on update" do
    product = products(:sample_book)
    variant = product.product_variants.first

    patch product_path(product), params: {
      product: {
        name: product.name,
        product_type: product.product_type,
        product_format_id: product.product_format_id,
        status: product.status,
        sellable: product.sellable,
        publication_date: "2020-05-15",
        language_code: "fra"
      },
      product_variant: {
        inventory_tracking_mode: variant.inventory_tracking_mode,
        regular_price_cents: variant.regular_price_cents,
        sellable: variant.sellable,
        status: variant.status
      }
    }

    assert_redirected_to product_path(product)
    product.reload
    assert_equal Date.new(2020, 5, 15), product.publication_date
    assert_equal "fra", product.language_code
  end

  test "new product form defaults language to eng and renders language select" do
    get new_product_path
    assert_response :success
    assert_select "select#product_language_code option[value=eng][selected]"
    assert_select "input#product_publication_date[type=date]"
  end
end
