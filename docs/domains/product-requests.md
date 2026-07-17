# Product Requests Domain

**Status:** Consolidated specification  
**Domain owner:** Demand, request lifecycle, buyer-review state, and fulfilment summary

## Governing ADRs

- [ADR-0005: Represent Demand, Supply Allocations, and Inventory Reservations Separately](../adr/0005-demand-allocations-and-reservations.md)
- [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](../adr/0006-inventory-quantities-and-reservation-records.md)

## Purpose

This domain records demand that the Store may attempt to fulfil.

It unifies Customer Requests, staff purchasing suggestions, future automated replenishment suggestions, and buyer-review demand.

It does not merge demand with supply. Product Requests, Purchase-Order Allocations, Inventory Reservations, Purchase Orders, and Receipts remain separate facts.

## Ownership boundary

### Owns

- Product Request;
- request type;
- requested quantity;
- priority;
- needed-by date;
- requesting User;
- Customer reference when applicable;
- request notes;
- request lifecycle;
- fulfilment summary and buyer-review state.

### References but does not own

- Product and Product Variant;
- Inventory Reservation, owned by Receiving and Inventory;
- Purchase-Order Allocation, owned by Vendors and Purchasing;
- Purchase Order and Receipt;
- POS Transaction used for final fulfilment;
- future Customer master data.

## Request types

Initial types:

```text
customer_request
staff_suggestion
```

Potential future type:

```text
system_replenishment_suggestion
```

### Customer Request

Represents customer demand and an intended fulfilment obligation.

### Staff Suggestion

Represents a recommendation for buyer consideration. It does not ordinarily reserve present inventory or commit future supply to a customer.

## Product Request

Suggested attributes:

- Store;
- request type;
- Customer when applicable;
- Product;
- Product Variant when known;
- requested quantity;
- priority;
- needed-by date;
- status;
- requesting User;
- assigned buyer;
- notes;
- timestamps.

Suggested high-level statuses:

```text
open
fulfilled
declined
cancelled
closed
```

Detailed sourcing progress should be derived from active Reservations and Allocations rather than encoded through many request statuses.

## Supply coverage

A Request may be covered by physically confirmed Inventory Reservations and active Purchase-Order Allocations.

```text
requested quantity
- confirmed active Inventory Reservations
- active Purchase-Order Allocations
= unfulfilled quantity
```

## Customer Request workflow

### Search in-house inventory

ShelfStack identifies potentially available inventory.

A staff member physically locates and confirms the merchandise before committing it.

After confirmation:

- quantity-tracked stock creates a quantity Reservation;
- individually tracked stock reserves the exact Inventory Unit.

### Search existing On-Order supply

If in-house supply is insufficient, ShelfStack identifies active Purchase-Order quantity not already allocated.

An authorized User may create a Purchase-Order Allocation.

### Buyer-review queue

Remaining quantity enters buyer review.

A buyer may select or create a Vendor Source, add quantity to a Purchase Order, defer, decline, request more information, or contact the Customer.

### Receipt and fulfilment

When allocated merchandise is accepted:

- the Allocation is marked received or fulfilled under the final workflow;
- merchandise may become Reserved for the Customer;
- notification or pickup may occur when Customer capability exists;
- final sale or delivery fulfils the Request.

## Staff Suggestion workflow

1. Create suggestion.
2. Resolve Product or provide enough information for buyer review.
3. Add to buyer queue.
4. Buyer orders, defers, declines, or closes.
5. Received merchandise remains generally available unless separately Reserved.

## Derived request states

The interface may present:

- physically reserved;
- allocated on order;
- awaiting buyer action;
- partially covered;
- fully covered;
- received;
- fulfilled.

These may be projections rather than persisted statuses.

## Permissions

```text
requests.view
requests.create_customer_request
requests.create_staff_suggestion
requests.edit_open_request
requests.assign_buyer
requests.reserve_in_house_inventory
requests.allocate_on_order_supply
requests.decline
requests.cancel
requests.close
requests.view_customer_details
```

## Audit requirements

Audit Request creation, quantity and Product changes, priority and needed-by changes, buyer assignment, referenced Reservation and Allocation changes, decline, Cancellation, fulfilment, close, User, and reason.

## Invariants

- A Request represents demand, not supply.
- Creating a Request does not change On Hand or On Order.
- A Request is not an Inventory Reservation.
- Future committed supply uses Purchase-Order Allocation.
- In-house Reservation requires physical confirmation.
- Staff Suggestions do not ordinarily create customer obligations.
- Active coverage must not exceed requested quantity without an explicit change.
- Supply cannot be allocated or reserved beyond available quantity.

## Open questions

- What minimum Customer data is required before a full Customer domain exists?
- When and how are Customers notified?
- What statuses are required beyond the high-level lifecycle?
- How are substitutions approved?
- May one Request accept several alternative Products or Variants?
- How are deposits or prepayment handled?
- How are unclaimed Reserved items released?
- Does final fulfilment require a POS Transaction in every case?
