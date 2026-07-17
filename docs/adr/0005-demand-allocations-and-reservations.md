# ADR-0005: Represent Demand, Supply Allocations, and Inventory Reservations Separately

**Status:** Accepted

## Context

ShelfStack must represent several related but different situations:

* a customer asks the store to obtain an item;  
* a staff member suggests that buyers consider an item;  
* merchandise is already present and may be held;  
* merchandise is already on order and may be committed;  
* merchandise has not yet been sourced;  
* a POS transaction temporarily reserves stock.

Previous designs considered separate systems for:

* customer requests;  
* special orders;  
* staff TBO suggestions;  
* holds;  
* inventory reservations;  
* purchase-order commitments.

These systems risked duplicating buyer queues and demand logic.

At the same time, combining demand and supply commitment into one record would obscure whether merchandise is merely requested, expected, or physically present.

## Decision

ShelfStack will use one general product-request model to represent demand.

Initial request types will include:

```
customer_request
staff_suggestion
```

Future request types may include:

```
system_replenishment_suggestion
```

The following concepts will remain distinct:

```
Product request
Purchase-order allocation
Inventory reservation
Purchase order
Receipt
```

## Product request

A product request records demand that the store may attempt to fulfil.

It may identify:

* store;  
* request type;  
* customer, when applicable;  
* product;  
* product variant, when known;  
* requested quantity;  
* priority;  
* needed-by date;  
* requesting user;  
* notes;  
* status.

Suggested high-level statuses are:

```
open
fulfilled
declined
cancelled
closed
```

Supply progress should ordinarily be derived from allocations rather than represented by many request statuses.

## Customer requests

A customer request creates a customer obligation or intended fulfilment workflow.

ShelfStack will evaluate supply in the following order.

### 1\. In-house inventory

ShelfStack identifies potentially available inventory.

A user must physically locate and confirm the item before it is committed to the customer request.

After confirmation:

* quantity-tracked merchandise creates a quantity reservation;  
* individually tracked merchandise reserves the exact unit.

### 2\. Existing on-order supply

When sufficient in-house stock is not reserved, ShelfStack identifies open purchase-order quantity not already committed to earlier requests.

An authorized user may allocate that future quantity to the customer request.

### 3\. Buyer-review queue

Any remaining unfulfilled quantity appears in a buyer-review queue.

A buyer may:

* select an existing vendor source;  
* create a vendor source;  
* add the item to a purchase order;  
* defer the request;  
* decline the request;  
* request additional information;  
* contact the customer.

The unfulfilled quantity is:

```
requested quantity
- confirmed in-house reservations
- active purchase-order allocations
= quantity requiring buyer action
```

## Staff suggestions

A staff suggestion enters the same buyer-review queue.

It does not ordinarily:

* reserve current stock;  
* allocate future stock to a customer;  
* create a customer obligation.

After merchandise is received, it remains generally available unless separately reserved.

## Purchase-order allocation

A purchase-order allocation commits incoming quantity to a customer request.

It:

* references one request;  
* references one purchase-order line;  
* records quantity;  
* does not increase on hand;  
* does not increase reserved physical inventory;  
* reduces the future quantity available to satisfy later requests.

## Inventory reservation

An inventory reservation commits merchandise already physically present at the store.

It:

* reduces available inventory;  
* does not reduce on hand;  
* identifies the request or transaction holding the merchandise;  
* remains until fulfilled, released, converted, or cancelled.

## Consequences

### Benefits

* Replaces several overlapping demand systems with one model.  
* Provides one buyer-review queue.  
* Preserves the distinction between demand and supply.  
* Supports both customer requests and staff suggestions.  
* Allows customer demand to be satisfied from current or incoming inventory.  
* Prevents on-order merchandise from being overcommitted.

### Costs

* Requires allocation records in addition to requests.  
* Requires staff confirmation before creating an in-house hold.  
* Buyer interfaces must show requested, reserved, allocated, and unfulfilled quantities.  
* Customer-notification workflows remain to be designed.

## Alternatives considered

### Separate special-order, customer-request, and TBO systems

Rejected because they would duplicate demand and purchasing workflows.

### Treat every request as an inventory reservation

Rejected because requested merchandise may not physically exist.

### Treat on-order allocations as inventory reservations

Rejected because on-order merchandise is not yet on hand.

## Governing rules

* A request represents demand.  
* A purchase-order allocation represents expected supply assigned to demand.  
* An inventory reservation represents physically present supply assigned to demand or POS.  
* A staff suggestion does not ordinarily create a customer commitment.  
* In-house customer holds require physical confirmation.  
* Supply may not be committed beyond its unallocated quantity.

## Related domains

* Product Requests and Acquisition Demand  
* Vendors and Purchasing  
* Receiving and Inventory  
* Point of Sale  
* Future Customer domain