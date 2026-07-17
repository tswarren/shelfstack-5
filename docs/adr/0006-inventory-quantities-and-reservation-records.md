# ADR-0006: Use Explicit Inventory Quantities and Reservation Records

**Status:** Accepted

## Context

ShelfStack must distinguish:

* physical ownership;  
* temporary commitment;  
* temporary unavailability;  
* current sellable availability;  
* expected future supply.

Using one quantity such as `stock` or `available` would hide important operational differences.

Reservations must also be traceable to the workflow that created them.

A cached `reserved` quantity alone would not explain:

* which transaction holds the stock;  
* which customer request holds the stock;  
* which exact unit is held;  
* when the hold began;  
* whether it was released or converted.

## Decision

For each store and quantity-tracked variant, ShelfStack will support:

```
on_hand
reserved
unavailable
available
on_order
```

The governing relationship is:

```
available = on_hand - reserved - unavailable
```

## Quantity definitions

### On hand

Physical merchandise present and owned by the store.

On hand may include merchandise that is:

* sellable;  
* reserved;  
* under inspection;  
* damaged;  
* awaiting return to vendor.

### Reserved

Physically present merchandise committed to an incomplete workflow.

Initial reservation sources include:

* open POS line;  
* suspended POS line;  
* confirmed customer request.

### Unavailable

Physically present merchandise that is not currently sellable.

Examples include:

* inspection;  
* damaged;  
* RTV holding;  
* quarantine.

### Available

Merchandise currently sellable without consuming reserved or unavailable stock.

### On order

Unreceived quantity expected from active purchase-order lines.

On order is not:

* on hand;  
* reserved physical inventory;  
* available physical inventory;  
* inventory value.

## Explicit reservation records

Reservations will be stored as explicit records.

A reservation identifies:

* store;  
* variant;  
* exact inventory unit, where applicable;  
* source type;  
* source record;  
* quantity;  
* status;  
* reserved timestamp;  
* release or conversion timestamp;  
* releasing user and reason where applicable.

Suggested statuses are:

```
active
released
converted
```

## Quantity-tracked reservations

A quantity-tracked reservation identifies a store, variant, and quantity.

## Individually tracked reservations

An individually tracked reservation identifies the exact inventory unit.

One inventory unit may have no more than one active reservation.

## POS lifecycle

```
Line added
→ reservation active

Line removed
→ reservation released

Transaction cancelled
→ reservation released

Transaction suspended
→ reservation remains active

Transaction completed
→ reservation converted into sale movement
```

Suspended transactions do not automatically expire.

Authorized users must be able to review old reservations and cancel abandoned suspended transactions.

## Customer-request lifecycle

```
Staff locates physical item
→ reservation active

Customer receives item through sale
→ reservation converted

Customer declines or request cancelled
→ reservation released
```

## Negative inventory

Quantity-tracked merchandise may be sold into negative inventory after a warning, according to store policy.

Negative inventory is not inherently an approval event.

An individually tracked unit cannot be sold unless the exact unit is valid and available or reserved to the transaction.

## Consequences

### Benefits

* Makes availability calculations understandable.  
* Preserves physical on-hand quantity while stock is held.  
* Supports POS and customer requests through one reservation model.  
* Makes abandoned or stale holds visible.  
* Prevents double reservation of exact units.  
* Separates current supply from future on-order supply.

### Costs

* Balance caches and reservation records must remain synchronized.  
* Concurrent reservation creation requires locking or transactional protection.  
* Old reservations require operational review.  
* Unavailable quantity may eventually require status-specific balance records for efficient reporting.

## Alternatives considered

### Store only available quantity

Rejected because it does not explain physical ownership or commitments.

### Store only a reserved cache without reservation records

Rejected because it provides no source-level traceability.

### Use `pending` rather than `reserved`

Rejected because `pending` is ambiguous across purchasing, receiving, returns, and POS.

## Governing rules

* Reservations do not change on hand.  
* Reservations reduce available.  
* Unavailable stock remains on hand.  
* On-order quantity remains outside on hand.  
* Every active reservation identifies its source.  
* One exact inventory unit has at most one active reservation.  
* Only inventory movements change on-hand quantity.

## Related domains

* Receiving and Inventory  
* Product Requests and Acquisition Demand  
* Point of Sale