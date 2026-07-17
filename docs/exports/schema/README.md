# Proforma Schema Exports

Files in `docs/exports/schema/` are **proforma planning artifacts**. They are intended to support architecture review, schema reconciliation, and Rails implementation planning.

They are not authoritative when they conflict with:

1. an accepted Architectural Decision Record;
2. the applicable Domain Specification;
3. the architecture invariants;
4. the implemented Rails migrations and `db/schema.rb`.

For the current classification model, [ADR-0003](../../adr/0003-merchandise-classes-and-departments.md) governs:

- ShelfStack uses one Merchandise-Class hierarchy;
- no `display_categories` table or active `display_category_id` foreign key should be scaffolded;
- Departments remain a separate financial and policy classification.

For demand and supply commitments, [ADR-0005](../../adr/0005-demand-allocations-and-reservations.md) and [ADR-0006](../../adr/0006-inventory-quantities-and-reservation-records.md) govern:

- `product_requests` record demand;
- `purchase_order_allocations` commit expected future supply;
- `inventory_reservations` commit physically present supply;
- Purchase Orders record acquisition intent;
- Receipts record delivered and accepted supply.

The Phase 3 proforma must include Product Requests and Purchase-Order Allocations even when an older export grouped customer demand under Purchasing.

The actual implemented database structure is defined by Rails migrations and `db/schema.rb`. An implementation conflict with a governing ADR or Domain Specification must be resolved explicitly rather than silently treating the current database as the intended architecture.
