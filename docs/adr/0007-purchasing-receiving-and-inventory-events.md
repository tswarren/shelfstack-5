# ADR-0007: Separate Purchasing, Receiving, and Inventory Events

**Status:** Accepted with open details

## Context

Purchasing, receiving, and inventory answer different business questions:

* What does the store intend to acquire?  
* What physically arrived?  
* What did the store accept?  
* What does the store currently possess?

Earlier designs risked combining these concerns or creating overly complex status and exception workflows.

Suppliers may combine products from multiple purchase orders into one shipment.

A receipt therefore cannot be restricted to one purchase order.

The architecture must support the practical acquisition cycle without prematurely defining every discrepancy, backorder, claim, or correction workflow.

## Decision

ShelfStack will treat purchasing, receiving, and inventory as separate events and domains.

## Purchasing

A purchase order records intent to acquire merchandise.

A purchase order:

* belongs to one store;  
* normally belongs to one vendor;  
* contains variant-level lines;  
* records ordered quantity;  
* records cancelled quantity;  
* records expected cost;  
* may contain customer-request allocations;  
* contributes to on-order quantity;  
* does not change on hand.

## Receiving

A receipt records one vendor shipment or receiving event at one store.

A receipt header identifies:

* store;  
* vendor;  
* vendor shipment or document reference;  
* receiving timestamp;  
* receiving user;  
* posting status.

A receipt may contain lines fulfilling several purchase orders.

The purchase-order relationship occurs at the receipt-line level.

```
Receipt
├── Receipt line → PO line from PO 1
├── Receipt line → PO line from PO 2
├── Receipt line → PO line from PO 2
└── Unlinked receipt line, where permitted
```

Each receipt line may reference no more than one purchase-order line in the initial design.

When one delivered product quantity fulfils several PO lines, ShelfStack may create separate receipt lines for each PO allocation.

A more complex many-to-many receipt allocation will not be introduced unless a real workflow requires it.

## Accepted and rejected quantities

Receiving may record:

* delivered quantity;  
* accepted quantity;  
* rejected quantity;  
* damaged quantity;  
* inspection quantity;  
* actual unit cost;  
* discrepancy reason.

Only accepted merchandise enters inventory.

Accepted damaged or inspection quantity may enter on hand in an unavailable state.

Rejected quantity does not increase on hand.

## Inventory

Inventory records current physical ownership.

Posting a receipt creates:

* inventory ledger entries;  
* stock-balance updates;  
* exact inventory units where required;  
* cost updates;  
* purchase-order fulfilment updates.

## Minimal workflow principle

The initial workflow should support:

* draft purchasing;  
* order placement;  
* partial receipt;  
* combined shipments;  
* accepted and rejected quantities;  
* cost capture;  
* customer-request allocations;  
* order closure or cancellation.

It should avoid unnecessary:

* duplicated statuses;  
* nested sourcing stages;  
* vendor-claim subworkflows;  
* separate backorder records;  
* mandatory approval stages;  
* detailed discrepancy workflows not supported by actual operations.

## Open implementation details

The following remain unresolved:

* final purchase-order statuses;  
* whether submission and ordering are separate;  
* receipt posting and correction statuses;  
* how posted receipt corrections are represented;  
* whether unlinked receipt lines require approval;  
* backorder treatment;  
* freight allocation;  
* vendor claims;  
* complete return-to-vendor workflow;  
* purchase-order approval limits.

These open questions do not alter the domain separation established by this ADR.

## Consequences

### Benefits

* Preserves accurate distinctions among intent, delivery, acceptance, and ownership.  
* Supports shipments covering several purchase orders.  
* Avoids increasing inventory before physical acceptance.  
* Allows partial fulfilment and customer-request allocation.  
* Keeps the initial acquisition workflow manageable.

### Costs

* Purchase-order and receipt quantities must reconcile.  
* Combined shipments require line-level PO links.  
* Corrections require explicit reversing records.  
* Buyers and receivers must understand the separation between ordered and accepted quantities.

## Alternatives considered

### Require one receipt per purchase order

Rejected because vendor shipments may combine several purchase orders.

### Allow one receipt line to link directly to several PO lines

Deferred because separate receipt lines provide a simpler initial implementation.

### Increase inventory when a purchase order is placed

Rejected because ordered merchandise is not physically present.

### Use one acquisition record for purchasing and receiving

Rejected because intent and physical receipt are different events.

## Governing rules

* Purchase orders do not change on hand.  
* Only posted accepted receipt quantity creates inventory.  
* One receipt may fulfil several purchase orders.  
* Receipt-to-PO linkage occurs at the line level.  
* Rejected quantity does not become inventory.  
* Inventory movements, not receipt edits, explain posted quantity changes.

## Related domains

* Product Requests and Acquisition Demand  
* Vendors and Purchasing  
* Receiving and Inventory  
* Reporting and Reconciliation