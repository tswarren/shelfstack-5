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

For demand and supply commitments, [ADR-0015](../../adr/0015-product-backed-demand-and-customer-supply-commitments.md) (supersedes ADR-0005), [OD-007](../../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md), and [ADR-0006](../../adr/0006-inventory-quantities-and-reservation-records.md) govern:

- every `product_requests` row references an existing Product (`product_id` required);
- four request types: customer request, staff suggestion, stock replenishment, frontlist selection;
- `purchase_order_allocations` commit expected future supply **only** to Customer Requests;
- remaining allocation quantity is derived from append-only `purchase_order_allocation_events` (conversion/release); do not use allocation statuses `received` / `fulfilled`;
- final Customer Request fulfilment is a separate `product_request_fulfillments` fact;
- `inventory_reservations` commit physically present supply;
- Purchase Orders record acquisition intent (`draft` / `ordered` / `closed` / `cancelled`);
- Receipts record delivered and accepted supply.

The reconciled dictionary and table summary should reflect ADR-0015 / OD-007 even when older workbook rows still say ADR-0005.

The actual implemented database structure is defined by Rails migrations and `db/schema.rb`. An implementation conflict with a governing ADR or Domain Specification must be resolved explicitly rather than silently treating the current database as the intended architecture.

### Implementation additions beyond the 260717.1402 reconciled proforma

| Table | Reason |
| --- | --- |
| `administrative_audit_events` | Organization and Authorization owns administrative audit events ([organization-and-authorization.md](../../domains/organization-and-authorization.md)); append-only events for Phase 1 admin mutations. |

Phase 4 tax / commercial schema deltas (Store Tax Rule `treatment`, `store_id`, nullable rate for exempt, line tax snapshots, discount `tax_treatment`, Tax Category override audit fields, whole-transaction exemption coverage) are governed by [ADR-0014](../../adr/0014-hybrid-transaction-component-tax-calculation.md) and [phase-04-tax-schema.md](../../implementation/phase-04-tax-schema.md). Reconcile those fields into this proforma before or with the Phase 4 tax migrations.
