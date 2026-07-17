# Schema Reconciliation: Merchandise Classes and Demand Allocation

**Status:** Decisions confirmed for the pre-scaffolding schema pass  
**Authority:** ADR-0003, ADR-0005, ADR-0006  
**Scope:** Display-category removal, Product Requests, Purchase-Order Allocations, and directly related proforma cleanup

## Confirmed decisions

### Merchandise classification

1. ShelfStack uses one Merchandise-Class hierarchy.
2. No `display_categories` table will be scaffolded.
3. Products use `merchandise_class_id` as their primary merchandising assignment.
4. Product Variants may provide an optional `merchandise_class_id` override.
5. Completed POS Product Lines snapshot `merchandise_class_id`.
6. Product-level `merchandise_class_id` remains nullable at the database level so incomplete Catalog records and non-merchandise services can exist; sale eligibility requires a resolved Merchandise Class for ordinary merchandise.
7. Temporary placements such as Front Table and Staff Picks remain deferred non-hierarchy metadata.

### Product demand and supply commitments

1. Phase 3 includes first-class `product_requests`.
2. Phase 3 includes first-class `purchase_order_allocations`.
3. V1 Customer Requests use nullable opaque `customer_reference`; no `customers` table or `customer_id` foreign key is introduced.
4. A Request may retain `requested_description` while Product identity remains unresolved.
5. `special_order_quantity` and `tbo_required` are removed from Purchase-Order Lines.
6. Buyer-review quantity is derived from Product Request coverage.
7. Inventory Reservations may use `source_type = product_request`.
8. Purchase-Order Allocation statuses in Phase 3 are `active` and `cancelled`.
9. `received` and `fulfilled` remain deferred until Phase 4 posting rules are defined.

## Schema changes

### Removed

- `display_categories`;
- `products.default_display_category_id`;
- `product_variants.display_category_id`;
- `pos_line_items.display_category_id`;
- `purchase_order_lines.special_order_quantity`;
- `purchase_order_lines.tbo_required`;
- `receipts.purchase_order_id`;
- `pos_transactions.customer_id`.

### Added or replaced

- `pos_line_items.merchandise_class_id`;
- `product_requests`;
- `purchase_order_allocations`;
- `pos_transactions.customer_reference`;
- Product Request support in `inventory_reservations.source_type`.

### Clarified

- `stock_balances.on_order` is maintained only by Purchasing and Receiving posting services, never by POS.
- `merchandise_classes.default_inventory_tracking_mode` is a setup default; `product_variants.inventory_tracking_mode` is runtime authority.
- `inventory_units.status` may reserve `rtv` and `in_transfer` as deferred-capable values without implementing those workflows in Phase 4.
- `pos_discounts.promotion_id` remains nullable and deferred.
- Schema Domain labels use the nine architecture-domain names.

## Product Requests v1 fields

```text
id
store_id
request_type
status
product_id
product_variant_id
requested_description
requested_quantity
priority
needed_by_on
customer_reference
requested_by_user_id
assigned_buyer_user_id
notes
created_at
updated_at
```

Unfulfilled quantity is derived:

```text
requested quantity
- active confirmed Inventory Reservations
- active Purchase-Order Allocations
= unfulfilled quantity
```

## Purchase-Order Allocations v1 fields

```text
id
purchase_order_line_id
product_request_id
quantity
status
created_by_user_id
cancelled_at
cancelled_by_user_id
cancellation_reason
created_at
updated_at
```

Required service constraints:

- active allocations for a Purchase-Order Line do not exceed its open quantity;
- active Reservation and Allocation coverage for a Product Request does not exceed requested quantity without an explicit quantity change;
- concurrent allocation uses locking or an equivalent transactional safeguard.

## Acceptance checks

```bash
grep -RniE 'display_categor' docs   --exclude='ShelfStack Proforma Schema*'   --exclude='*.xlsx'
```

Expected results are limited to historical or prohibitive language in ADR-0003, the glossary, architecture invariants, domain guidance, revision notes, and this reconciliation note.

```bash
grep -RniE 'special_order_quantity|tbo_required'   docs/architecture docs/domains docs/exports/schema
```

Expected results are limited to removal, deprecation, or historical notes.

Before Rails scaffolding, verify the Schema Dictionary:

- contains `product_requests`;
- contains `purchase_order_allocations`;
- contains no `display_categories` table;
- contains no FK to `display_categories`;
- permits `inventory_reservations.source_type = product_request`;
- contains no active `customer_id` FK without a Customer domain.
