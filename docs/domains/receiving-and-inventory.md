# Receiving and Inventory Domain

**Status:** Consolidated specification with open correction, count, transfer, and RTV details  
**Domain owner:** Vendor shipment acceptance, physical Store inventory, availability, exact Units, Reservations, movements, and cost

## Governing ADRs

- [ADR-0001: Separate Product, Product Variant, and Inventory Unit](../adr/0001-product-variant-inventory-unit.md)
- [ADR-0002: Use Canonical Identifiers and Separate Restricted-Circulation Namespaces](../adr/0002-canonical-identifiers-and-namespaces.md)
- [ADR-0004: Treat the Store as the Authoritative Inventory Boundary](../adr/0004-store-level-inventory-boundary.md)
- [ADR-0005: Represent Demand, Supply Allocations, and Inventory Reservations Separately](../adr/0005-demand-allocations-and-reservations.md)
- [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](../adr/0006-inventory-quantities-and-reservation-records.md)
- [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](../adr/0007-purchasing-receiving-and-inventory-events.md)

## Purpose

This domain is the authoritative source for physical merchandise owned by each Store.

It records what shipment arrived, what quantity was accepted or rejected, what the Store currently possesses, what is Reserved or Unavailable, which exact physical Units exist, which movements explain quantity and status, and what inventory cost applies.

## Ownership boundary

### Owns

- Receipt;
- Receipt Line;
- delivered, accepted, and rejected quantities;
- Stock Balance;
- Inventory Unit;
- Unit Identifier;
- Inventory Reservation;
- Inventory Ledger Entry;
- Inventory Adjustment;
- inventory availability status;
- moving weighted-average cost;
- exact Unit acquisition cost;
- inventory acquisition source;
- last-received information;
- future Inventory Counts, transfers, and RTV-holding records.

### References but does not own

- Product and Product Variant;
- Vendor;
- Purchase Order and Purchase-Order Line;
- Purchase-Order Allocation;
- Product Request;
- POS Transaction and POS Line Item;
- report definitions.

## Store inventory boundary

Inventory is authoritative at Store level.

Routine movement among receiving, stockroom, sales floor, cashwrap, or temporary displays does not change Store On Hand.

Optional Physical Placement may later assist locating merchandise but must not fragment the authoritative balance.

## Inventory quantities

For each Store and quantity-tracked Variant:

```text
on_hand
reserved
unavailable
available
on_order
```

```text
available = on_hand - reserved - unavailable
```

`on_order` is supplied by Purchasing and remains outside physical inventory.

### On Hand

Physical merchandise present and owned by the Store.

### Reserved

Physically present inventory committed to an incomplete workflow.

### Unavailable

Physically present inventory not currently sellable, such as inspection, damaged, RTV, or quarantine.

### Available

Inventory currently sellable.

## Receipt

A Receipt represents one Vendor shipment or receiving event at one Store.

Suggested attributes:

- Store;
- Vendor;
- shipment or document reference;
- status;
- received timestamp and User;
- posted timestamp and User;
- notes.

A Receipt does not have one required header-level Purchase Order. One shipment may fulfil several Purchase Orders.

### Receipt Line

Suggested attributes:

- Receipt;
- Product Variant;
- optional Purchase-Order Line;
- delivered quantity;
- accepted quantity;
- rejected quantity;
- accepted unavailable quantity or disposition;
- actual unit cost;
- discrepancy reason;
- notes.

One Receipt Line links to at most one Purchase-Order Line in the baseline. Separate lines may split one delivered Product across several PO Lines.

Only accepted quantity creates inventory.

### Receipt status

Proposed minimum:

```text
draft
posted
cancelled
```

A posted Receipt is not edited to change historical inventory. Corrections use explicit corrective records. The final correction model remains Open.

## Stock Balance

One Stock Balance exists per Store and quantity-tracked Product Variant.

Suggested attributes:

- Store;
- Product Variant;
- On Hand;
- Reserved;
- Unavailable;
- optional cached Available;
- moving weighted-average cost;
- last received timestamp.

Inventory Ledger Entries and Reservation records explain the balance.

## Inventory Unit

An Inventory Unit represents one exact physical copy of an individually tracked Variant.

Suggested attributes:

- Product Variant;
- Store;
- generated `27` EAN-13 Unit Identifier;
- status;
- exact Condition;
- acquisition cost;
- optional Unit-specific price;
- acquisition source;
- acquired timestamp;
- notes.

One Unit belongs to one Store at a time and has at most one active Reservation.

## Inventory Reservation

A Reservation commits physically present stock.

Suggested attributes:

- Store;
- Product Variant;
- Inventory Unit when individual;
- source type and record;
- quantity;
- status;
- reserve, release, and conversion timestamps;
- releasing User and reason.

Suggested statuses:

```text
active
released
converted
```

### POS lifecycle

```text
line added → active
line removed → released
transaction cancelled → released
transaction suspended → remains active
transaction completed → converted
```

### Product Request lifecycle

```text
staff physically confirms item → active
sale or fulfilment → converted
request cancelled or item released → released
```

## Inventory Ledger

Only Inventory Movements change On Hand.

Suggested movement types:

```text
receipt
sale
customer_return
adjustment
transfer_out
transfer_in
rtv_shipment
discard
post_void
correction
```

Each entry retains Store, Variant, optional Unit, quantity delta, status transition, cost, source, reversal reference, User, time, and reason.

## Cost

### Quantity-tracked cost

Use Store-and-Variant moving weighted-average cost. The exact algorithm under negative inventory remains Open.

### Individually tracked cost

Each Inventory Unit retains its own acquisition cost.

### Missing cost

Missing cost normally produces a warning rather than blocking sale. Completed lines distinguish missing cost from confirmed zero cost.

## Inventory Adjustments

A posted Inventory Adjustment creates Ledger Entries.

Suggested structure:

- adjustment header with Store, status, reason, creator, poster, and timestamps;
- lines with Variant, optional Unit, quantity or status change, cost, and reason.

Direct unexplained edits to On Hand are prohibited.

## Return dispositions

Initial physical outcomes:

```text
return_to_stock
inspection_required
damaged
return_to_vendor
discard
non_inventory
```

Only `return_to_stock` becomes immediately Available.

RTV status does not complete the Vendor-return workflow.

## Permissions

```text
inventory.view_store_stock
inventory.view_cost
inventory.receive
inventory.post_receipt
inventory.correct_receipt
inventory.adjust_stock
inventory.review_reservations
inventory.release_reservation
inventory.resolve_inspection
inventory.resolve_damaged_stock
inventory.transfer_between_stores
inventory.discard
```

## Audit requirements

Audit Receipt posting and corrections, accepted and rejected quantities, cost, Inventory Movements, Reservation lifecycle, Unit creation and status changes, manual Adjustments, inspection and damage resolution, transfer, RTV, discard, and retained negative-inventory warnings.

## Invariants

- Inventory is authoritative at Store level.
- Internal placement does not change On Hand.
- Only Inventory Movements change On Hand.
- Reservations reduce Available but not On Hand.
- Unavailable inventory remains On Hand.
- On Order is not inventory.
- One Stock Balance exists per Store and quantity-tracked Variant.
- One Unit belongs to one individually tracked Variant and one Store.
- One Unit has at most one active Reservation.
- Only accepted Receipt quantity enters inventory.
- Rejected quantity does not enter inventory.
- Completed cost snapshots do not change later.

## Open questions

- What quantities beyond delivered, accepted, and rejected are required?
- How is accepted damaged or inspection quantity represented?
- What is the posted Receipt correction workflow?
- Is Available stored or calculated?
- Are unavailable quantities cached by status?
- How does moving average behave with negative On Hand?
- What is the Inventory Count model?
- What Adjustment thresholds require Approval?
- What is the inter-Store transfer lifecycle?
- When does RTV merchandise leave On Hand?
- What is the complete Return-to-Vendor document model?
