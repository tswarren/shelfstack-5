# OD-007 — Purchase-Order Allocation Receipt and Fulfilment Representation

**Status:** accepted
**Needed by:** Phase 5
**Governing area:** Product Requests / Purchasing / Receiving and Inventory / POS
**Related:** [ADR-0015](../../adr/0015-product-backed-demand-and-customer-supply-commitments.md); [Product Requests](../../domains/product-requests.md); [Vendors and Purchasing](../../domains/vendors-and-purchasing.md); [Receiving and Inventory](../../domains/receiving-and-inventory.md)

### Decision

Purchase-Order Allocations represent expected future supply committed to Customer Requests.

They do not represent physical inventory and do not represent final customer fulfilment.

The lifecycle is separated as follows:

```text
Purchase-Order Allocation
= expected supply committed to a Customer Request

Inventory Reservation
= physically present supply committed to a Customer Request

Product Request Fulfilment
= merchandise actually delivered or sold in satisfaction of the request
```

The allocation itself does not persist `received` or `fulfilled` statuses.

Instead:

* receipt posting converts applicable allocated quantity into an Inventory Reservation;
* cancelled, unavailable, redundant, or otherwise unusable allocated quantity is released;
* final customer fulfilment is recorded separately against the Product Request;
* allocation, reservation, and fulfilment quantities remain independently auditable.

### Allocation quantity model

A Purchase-Order Allocation records the original quantity committed from one Purchase-Order Line to one Customer Request.

Its unresolved future-supply quantity is derived:

```text
remaining allocation quantity
=
allocated quantity
− converted-to-reservation quantity
− released quantity
```

Where:

```text
converted-to-reservation quantity
= allocation quantity that became physically present
  and was committed through an Inventory Reservation

released quantity
= allocation quantity no longer committed to the request
```

The remaining allocation quantity must never be negative.

### Allocation events

Quantity resolved from an allocation is recorded through append-only allocation events or an equivalent auditable quantity record.

Initial event types:

```text
converted_to_reservation
released
```

A `converted_to_reservation` event should identify:

* Purchase-Order Allocation;
* quantity;
* Receipt Line;
* resulting Inventory Reservation;
* posting User;
* posting time;
* idempotency or posting key.

A `released` event should identify:

* Purchase-Order Allocation;
* quantity;
* release reason;
* releasing User;
* release time;
* optional replacement or superseding supply reference.

Suggested release reasons include:

```text
purchase_order_cancelled
line_quantity_cancelled
vendor_unavailable
received_unavailable
request_cancelled
request_quantity_reduced
fulfilled_from_earlier_supply
reallocated_to_other_supply
manual_release
```

Corrections to posted events use explicit reversing events rather than editing historical quantity events in place.

### Receipt posting

When merchandise linked to a Purchase-Order Line is accepted, receipt posting evaluates active Customer Request allocations against the accepted available quantity.

For quantity that can satisfy an allocation, the posting service atomically:

1. posts the accepted inventory movement;
2. creates or updates the physical inventory state;
3. creates an Inventory Reservation for the Customer Request;
4. records an allocation `converted_to_reservation` event;
5. reduces remaining allocation quantity by the same amount;
6. reduces Purchase-Order open quantity through accepted receipt quantity;
7. preserves request coverage without double counting;
8. records an idempotent audit trail.

The allocation conversion and Inventory Reservation must succeed or fail together.

Accepted merchandise that is damaged, under inspection, or otherwise unavailable does not automatically become reserved for the Customer Request.

When such merchandise no longer represents usable expected supply, the corresponding allocation quantity is released with an appropriate reason, and the Customer Request becomes uncovered again.

### Partial receipts

Partial receipt is supported without replacing or rewriting the original allocation.

Example:

```text
allocated quantity:                 10
converted to Inventory Reservation:  6
released quantity:                   0
remaining allocation quantity:       4
```

The remaining four units continue to represent expected future supply.

### Cancellation and re-sourcing

An operation that reduces Purchase-Order open quantity must not leave remaining allocation quantity greater than available open supply.

The operation must atomically:

* reject the reduction;
* release affected allocation quantity; or
* move the customer commitment to replacement supply.

When an allocation is released because supply was cancelled or unavailable, the Customer Request remains open and its uncovered quantity returns to buyer review.

### Earlier compatible supply

A Customer Request may be satisfied by compatible merchandise that becomes available before its allocated Purchase-Order quantity arrives.

When earlier supply is physically reserved:

* the corresponding future allocation quantity is released;
* the release reason identifies fulfilment from earlier supply;
* the later Purchase-Order quantity becomes available for another Customer Request or general stock.

### Allocation states presented by the interface

Allocation lifecycle labels are derived from quantities and events rather than persisted as the governing status.

The interface may present:

```text
active
partially_resolved
converted
released
resolved_mixed
```

Suggested derivation:

```text
active
= remaining quantity equals allocated quantity

partially_resolved
= remaining quantity is greater than zero
  and some quantity has been converted or released

converted
= remaining quantity is zero
  and all quantity was converted to reservations

released
= remaining quantity is zero
  and all quantity was released

resolved_mixed
= remaining quantity is zero
  and quantity was resolved through both conversion and release
```

These labels are projections and need not be stored on the allocation.

### Product Request fulfilment

Final customer fulfilment is not an allocation status.

ShelfStack persists Product Request fulfilment separately so it can represent:

* partial fulfilment;
* fulfilment through several POS transactions;
* fulfilment through several physical reservations;
* correction or reversal;
* future non-POS delivery workflows.

A baseline Product Request Fulfilment should identify:

```text
product_request_id
inventory_reservation_id
pos_line_item_id
quantity
fulfilled_at
fulfilled_by_user_id
```

`pos_line_item_id` may be replaced later by a more general fulfilment-source model if non-POS delivery is introduced.

When a reserved item is sold through POS, completion should atomically:

1. convert or close the Inventory Reservation;
2. create the inventory sale movement;
3. create the Product Request Fulfilment;
4. update the Product Request lifecycle when fully fulfilled.

### Request quantity derivations

Product Request quantity is separated into:

```text
fulfilled quantity
= sum of valid Product Request Fulfilments

outstanding quantity
=
requested quantity
− fulfilled quantity
```

Outstanding quantity may be covered by physical reservations and remaining future allocations:

```text
uncovered quantity
=
requested quantity
− fulfilled quantity
− active Inventory Reservation quantity
− remaining Purchase-Order Allocation quantity
```

The result must never be negative.

This replaces the earlier incomplete formula that considered only reservations and allocations without accounting for partial completed fulfilment.

### Product Request status

A Customer Request may remain `open` while partially fulfilled.

It becomes `fulfilled` when:

```text
fulfilled quantity >= requested quantity
```

unless the request has already been cancelled, declined, or administratively closed under an authorized workflow.

Supply coverage states such as:

```text
physically_reserved
allocated_on_order
partially_covered
fully_covered
partially_fulfilled
```

remain derived projections rather than additional Product Request lifecycle statuses.

### Concurrency and idempotency

Allocation conversion, release, reservation creation, receipt posting, and request fulfilment require transactional protection.

Services must prevent:

* conversion beyond remaining allocation quantity;
* release beyond remaining allocation quantity;
* active allocations beyond Purchase-Order open quantity;
* request coverage beyond outstanding quantity;
* duplicate allocation conversion during receipt retry;
* duplicate fulfilment during POS completion retry;
* duplicate reservation of an exact Inventory Unit.

Allocation-event posting and Product Request Fulfilment creation require unique idempotency or posting keys.

### Consequences

#### Benefits

* Keeps expected supply, physical supply, and final fulfilment separate.
* Supports partial receipts and partial fulfilment.
* Avoids forcing one status to represent quantity-level mixed outcomes.
* Prevents double counting when an allocation becomes a reservation.
* Preserves allocation history after receipt or release.
* Supports earlier supply replacing later allocated supply.
* Makes customer fulfilment auditable through POS.
* Keeps non-customer Product Requests outside the allocation lifecycle.

#### Costs

* Requires an allocation-event or equivalent quantity-resolution structure.
* Requires a separate Product Request Fulfilment record.
* Receipt and POS completion services must coordinate several records atomically.
* Coverage projections require aggregate quantity calculations.
* Receipt corrections require explicit reversal behavior.

### Governing rules

* Purchase-Order Allocations apply only to Customer Requests.
* An allocation represents future supply, not physical stock.
* An allocation never becomes final customer fulfilment.
* `received` and `fulfilled` are not persisted allocation statuses.
* Receipt posting converts usable allocated quantity into an Inventory Reservation.
* Allocation conversion and reservation creation are atomic.
* Unusable, cancelled, or redundant allocation quantity is explicitly released.
* Partial allocation conversion and release are permitted.
* Remaining allocation quantity is derived from the original allocation and append-only resolution events.
* Product Request Fulfilment is persisted separately.
* Partial fulfilment does not require closing the Customer Request.
* Coverage and fulfilment must never exceed requested quantity.
* Corrections use reversing records rather than rewriting posted history.

--
# Discussion

> **Purchase-order allocations track only expected future supply. They do not become “fulfilled.” Receipt posting resolves allocated quantity by converting it into a physical Inventory Reservation or releasing it. Final customer fulfilment is recorded separately against the Product Request.**

This fits the established domain boundaries: allocations commit future supply, reservations commit physical supply, and receipt posting bridges the two.  It also handles partial receipts, partial cancellation, and fulfilment through multiple POS transactions without overloading a single allocation status.

## Recommended lifecycle

```text
Purchase-Order Allocation
    expected supply committed to request
                │
                ├─ receipt accepted and available
                │      → Inventory Reservation
                │      → allocation quantity converted
                │
                ├─ PO quantity cancelled/unavailable
                │      → allocation quantity released
                │      → request becomes uncovered again
                │
                └─ earlier stock satisfies request
                       → allocation quantity released
```

Then:

```text
Inventory Reservation
    physical supply committed to request
                │
                └─ POS completion / delivery
                       → Product Request Fulfilment
                       → reservation converted
```

`received` and `fulfilled` therefore do not belong in `purchase_order_allocations.status`.

## Open-decisions table row

Replace the current OD-007 row with:

```markdown
| OD-007 | PO allocation receipt / fulfilment representation | accepted | Phase 5 | Purchasing / Product Requests / Inventory / POS | Allocations represent future supply only. Receipt posting records quantity conversion to Inventory Reservations or release through append-only allocation events; `received` and `fulfilled` are not allocation statuses. Final fulfilment is a separate Product Request Fulfilment fact. |
```

## Companion changes required

1. **ADR-0015:** remove allocation receipt/fulfilment from `Open details` and add the separation among allocation, reservation, and fulfilment to the governing decision.
2. **`product-requests.md`:** add fulfilled quantity and the revised uncovered-quantity formula.
3. **`vendors-and-purchasing.md`:** replace the `active`/`cancelled` allocation-status model with original quantity plus derived remaining quantity and resolution events.
4. **`receiving-and-inventory.md`:** require atomic allocation conversion and reservation creation during applicable receipt posting.
5. **Phase 5 plan:** add allocation events and Product Request Fulfilments to principal tables or explicitly identify them as Phase 5 supporting records.
