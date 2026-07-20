# Product Requests Domain

**Status:** Consolidated specification  
**Domain owner:** Demand, request lifecycle, buyer-review state, and fulfilment summary

## Governing ADRs

- [ADR-0005: Represent Demand, Supply Allocations, and Inventory Reservations Separately](../adr/0005-demand-allocations-and-reservations.md)
- [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](../adr/0006-inventory-quantities-and-reservation-records.md)

## Purpose

This domain records demand that the Store may attempt to fulfil.

It unifies Customer Requests, staff purchasing suggestions, stock replenishment, frontlist selections, future automated replenishment suggestions, and buyer-review demand.

It does not merge demand with supply. Product Requests, Purchase-Order Allocations, Inventory Reservations, Purchase Orders, and Receipts remain separate facts.

Every acquisition-demand record references an existing ShelfStack Product. Free-text notes may preserve context but do not substitute for product identity. When the Product does not exist, staff search, import, or create it before recording demand. See [ordering-and-acquisition-planning.md](ordering-and-acquisition-planning.md).

## Ownership boundary

### Owns

- Product Request;
- request type;
- requested quantity;
- priority;
- needed-by date;
- requesting User;
- nullable opaque Customer reference for v1;
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
stock_replenishment
frontlist_selection
```

Potential future type:

```text
system_replenishment_suggestion
```

### Customer Request

Represents customer demand and an intended fulfilment obligation.

### Staff Suggestion

Represents a recommendation for buyer consideration. It does not ordinarily reserve present inventory or commit future supply to a customer.

### Stock Replenishment

Represents a buyer or authorized user’s decision that additional stock should be considered for ordering. It may originate from a replenishment-review screen. It does not create a customer obligation.

### Frontlist Selection

Represents buyer interest in a forthcoming or newly released Product. The Product must be imported or created before the selection is recorded. Full publisher-catalog or ONIX campaign management is deferred.

## Product Request

Suggested attributes:

- Store;
- request type;
- nullable `customer_reference` string for v1 Customer Requests;
- required Product;
- optional Product Variant when known;
- requested quantity;
- priority;
- needed-by date;
- status;
- requesting User;
- assigned buyer;
- notes;
- timestamps.

Required relationship:

```text
product_requests.product_id → required
```

Optional relationship:

```text
product_requests.product_variant_id → nullable until an exact configuration is known or selected
```

Before merchandise is added to a Purchase Order, the exact Product Variant must be resolved.

Suggested high-level statuses:

```text
open
fulfilled
declined
cancelled
closed
```

Detailed sourcing progress should be derived from active Reservations and Allocations rather than encoded through many request statuses.

## V1 Customer reference

The first Product Requests schema does not introduce a `customers` table or a `customer_id` foreign key.

Customer Requests may store a nullable opaque `customer_reference` string. This may contain a name, order reference, or another staff-entered locator sufficient for the immediate workflow.

`customer_reference`:

- is not stable Customer identity;
- must not be used as a durable cross-record Customer key;
- may be replaced or migrated when the Customer domain is designed;
- does not provide notifications, reusable tax exemptions, deposits, or Customer history.

Phase 5 does not require a Customer master shell. Rich CRM remains deferred.

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

A buyer may select or create a Vendor Source, add quantity to a Purchase Order, defer, decline, or return unresolved quantity for later sourcing.

### Receipt and fulfilment

When allocated merchandise is accepted:

- Phase 5 posting rules determine whether the Allocation becomes `received`/`fulfilled`, a derived state, or a separate fulfilment event (schema persists only `active` and `cancelled` until OD-007 is closed);
- merchandise may become Reserved for the Customer;
- notification or pickup may occur when Customer capability exists;
- final sale or delivery fulfils the Request.

Compatible Customer Requests should ordinarily be ranked by explicitly authorized priority, needed-by date, then request creation time. Earlier compatible supply may fulfil a request previously allocated to later supply; redundant future Allocations are then reduced or cancelled.

## Staff Suggestion workflow

1. Resolve or create the Product (and optional Variant).
2. Create suggestion.
3. Add to buyer queue.
4. Buyer orders, defers, declines, or closes.
5. Received merchandise remains generally available unless separately Reserved.

## Stock replenishment and frontlist

Replenishment and frontlist selections enter the same buyer-review projection as other demand. They do not create customer obligations or reserve received merchandise by default. See [ordering-and-acquisition-planning.md](ordering-and-acquisition-planning.md).

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

The buyer-review (“To Be Ordered”) queue is a projection over Product Requests and coverage. It is not a boolean on a Purchase-Order Line, a permanent Product status, or an inventory quantity.

## Permissions

```text
requests.view
requests.create_customer_request
requests.create_staff_suggestion
requests.create_stock_replenishment
requests.create_frontlist_selection
requests.edit_open_request
requests.assign_buyer
requests.reserve_in_house_inventory
requests.allocate_on_order_supply
requests.decline
requests.cancel
requests.close
```

`requests.view_customer_details` is reserved for a future Customer domain and is not part of the v1 `customer_reference` model.

## Audit requirements

Audit Request creation, quantity and Product changes, priority and needed-by changes, buyer assignment, referenced Reservation and Allocation changes, decline, Cancellation, fulfilment, close, User, and reason. Product creation initiated from demand entry is audited in Catalog.

## Invariants

- A Request represents demand, not supply.
- Creating a Request does not change On Hand or On Order.
- Every Request references an existing ShelfStack Product.
- A Request is not an Inventory Reservation.
- Future committed supply uses Purchase-Order Allocation.
- In-house Reservation requires physical confirmation.
- Staff Suggestions, stock replenishment, and frontlist selections do not ordinarily create customer obligations.
- Active coverage must not exceed requested quantity without an explicit change.
- Supply cannot be allocated or reserved beyond available quantity.
- V1 Customer Requests use `customer_reference`; they do not require or imply a Customer master record.

## Open questions

- When and how are Customers notified after the Customer domain is introduced?
- What statuses are required beyond the high-level lifecycle?
- How are substitutions approved?
- May one Request accept several alternative Products or Variants?
- How are deposits or prepayment handled?
- How are unclaimed Reserved items released?
- Does final fulfilment require a POS Transaction in every case?
