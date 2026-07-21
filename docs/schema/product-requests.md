# Product Requests schema (Phase 5)

**Status:** Implemented (Phase 5d–5f)  
**Domain:** [product-requests.md](../domains/product-requests.md)  
**Related:** [purchasing.md](purchasing.md) (allocations), [inventory.md](inventory.md) (reservations / receipts)

## Tables

| Table | Purpose |
| --- | --- |
| `product_requests` | Product-backed demand (four request types); non-customer resolution columns |
| `product_request_fulfillments` | Append-only fulfilment / reverse facts linked to POS lines |

## Product Request

Required `product_id`; optional `product_variant_id` (resolved before PO line / reserve / fulfilment).  
Request types: `customer_request`, `staff_suggestion`, `stock_replenishment`, `frontlist_selection`.  
Statuses: `open`, `fulfilled`, `declined`, `cancelled`, `closed`.  
Priorities: `normal`, `high`, `urgent`.

Customer identity in Phase 5 is a nullable opaque `customer_reference` only (no `customers` table).

Non-customer resolution uses columns on the request (`resolution`, `resolved_quantity`, `resolved_at`, `resolved_by_user_id`, `resolution_note`), not a separate event table. Optional `supersedes_product_request_id` links follow-up demand.

### Coverage (Customer Requests)

```text
uncovered = requested
          − fulfilled
          − active_reserved
          − remaining_allocated
```

Purchase-Order Allocations apply only to Customer Requests. Non-customer ordered merchandise becomes general expected supply.

## Fulfilment

`product_request_fulfillments` records the demand-closing fact:

- `kind`: `fulfill` or `reverse` (reverse requires `linked_fulfillment_id`);
- unique `posting_key` for idempotent POS completion;
- links to `pos_line_item_id` and optionally the consumed `inventory_reservation_id`.

Sale completion posts fulfilment atomically; linked returns post reversing fulfilment. Post-void of a fulfilled sale is Phase 6.
