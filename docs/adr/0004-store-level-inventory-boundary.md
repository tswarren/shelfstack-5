# ADR-0004: Treat the Store as the Authoritative Inventory Boundary

**Status:** Accepted

## Context

A bookstore may physically move merchandise among:

* receiving;  
* stockroom;  
* sales floor;  
* front tables;  
* cashwrap;  
* café storage;  
* temporary displays.

Previous iterations risked requiring staff to record routine movement among these internal areas.

That would impose operational work without necessarily improving financial or inventory accuracy.

ShelfStack’s primary inventory question is:

Which store owns and possesses this merchandise?

Movement among stores is materially different because the authoritative store assignment changes.

## Decision

Inventory will be authoritative at the store level.

ShelfStack will not initially require operational tracking of routine movement among physical areas within the same store.

Store-level inventory records will determine:

* on hand;  
* reserved;  
* unavailable;  
* available;  
* exact-unit store assignment;  
* inventory cost;  
* inventory ownership.

Internal physical locations may later be added as optional metadata for:

* merchandising;  
* picking;  
* receiving;  
* auditing;  
* finding exact units.

They will not replace or fragment the authoritative store-level balance.

## Inter-store movement

Movement from one store to another is an inventory transfer.

An inter-store transfer must:

* reduce inventory at the source store;  
* identify any in-transit state;  
* increase inventory at the destination store after receipt;  
* preserve exact inventory-unit identity;  
* retain an auditable movement history.

The detailed transfer document and workflow remain deferred.

## Consequences

### Benefits

* Reduces unnecessary staff data entry.  
* Keeps stock balances understandable.  
* Avoids false precision about internal placement.  
* Supports reliable store-level inventory and POS.  
* Preserves the ability to add optional physical-location metadata later.

### Costs

* ShelfStack may not know whether an item is in receiving, the stockroom, or on the sales floor.  
* Staff may still need physical search processes.  
* Advanced warehouse-style workflows require later extension.  
* Internal placement reports will not initially reconcile to authoritative quantity.

## Alternatives considered

### Track every physical sublocation as authoritative inventory

Rejected because it would create operational complexity disproportionate to current bookstore requirements.

### Track no store ownership and use organization-wide inventory

Rejected because stores require independent availability, selling, receiving, cost, and reporting.

## Governing rules

* Every inventory balance belongs to one store.  
* Every active inventory unit belongs to one store.  
* Movement inside a store does not alter on hand.  
* Movement between stores requires inventory movements.  
* Optional physical placement must not alter the authoritative store balance.

## Related domains

* Stores and Operational Control  
* Receiving and Inventory  
* Point of Sale  
* Reporting and Reconciliation