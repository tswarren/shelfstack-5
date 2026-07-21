# Purchasing schema (Phase 5)

**Status:** Implemented (Phase 5a–5e)  
**Domain:** [vendors-and-purchasing.md](../domains/vendors-and-purchasing.md)  
**Related:** [inventory.md](inventory.md) (receipts), [product-requests.md](product-requests.md) (allocations / fulfilment)

## Tables

| Table | Purpose |
| --- | --- |
| `vendors` | Organization-owned vendor masters (`code` unique per organization) |
| `product_variant_vendors` | Vendor Source for a Product Variant (expected cost, list/discount, MOQ, preferred) |
| `purchase_orders` | Commercial acquisition headers (store-scoped `purchase_order_number`) |
| `purchase_order_lines` | Ordered lines with cost snapshots; `cancelled_quantity` / `received_quantity` |
| `purchase_order_allocations` | Expected-supply commitment of a PO line to a Customer Request |
| `purchase_order_allocation_events` | Append-only conversion/release events; remaining quantity is derived |

## Purchase orders

Commercial statuses: `draft` | `ordered` | `closed` | `cancelled`.  
Receiving progress is **derived** (`not_received` / `partially_received` / `fully_received`), not a commercial status.

```text
open_quantity = ordered_quantity − cancelled_quantity − received_quantity
on_order      = max(open_quantity, 0)   # derived; never via inventory ledger
```

After placement, vendor / store / currency and line identity are immutable; reduce quantity via `cancelled_quantity` only. No reopen in Phase 5.

Line cost entry: `discount_from_list` or `direct_net_cost`, with snapped `expected_unit_cost_cents` and provenance. PO expected cost takes precedence over mutable Vendor Source data when suggesting receipt costs.

## Allocations (OD-007 / ADR-0015)

- Allocations commit expected supply **only** to Customer Requests.
- One row per `(purchase_order_line_id, product_request_id)`.
- `quantity` is the originally allocated amount; remaining quantity and state are derived from events.
- Event types: `converted_to_reservation`, `released` (structured reason required for release).
- Unique `posting_key` on events supports idempotent release/conversion.

Allocation does not change On Hand, Reserved physical inventory, or derived `on_order`.
