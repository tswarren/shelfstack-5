# ADR-0015: Require Product-Backed Demand and Reserve Supply Allocations for Customer Commitments

**Status:** Proposed
**Date:** 2026-07-20
**Supersedes:** [ADR-0005: Represent Demand, Supply Allocations, and Inventory Reservations Separately](0005-demand-allocations-and-reservations.md)

**Note:** Once adopted, update ADR-0005
> ADR-0005: Represent Demand, Supply Allocations, and Inventory Reservations Separately
>
> **Status:** Superseded by [ADR-0015: Require Product-Backed Demand and Reserve Supply Allocations for Customer Commitments](0015-product-backed-demand-and-customer-supply-commitments.md)

## Context

ShelfStack must represent several related but distinct reasons merchandise may be considered for acquisition:

* a customer asks the store to obtain a specific product;
* a staff member suggests that buyers consider a product;
* a buyer identifies a need to replenish stock;
* a buyer selects a forthcoming or frontlist product;
* merchandise is already present and may be held;
* merchandise is already on order and may be committed to a customer;
* merchandise has not yet been sourced;
* a POS transaction temporarily reserves physical stock.

ADR-0005 correctly established that demand, expected-supply commitments, physical inventory reservations, purchase orders, and receipts are separate facts.

Subsequent planning exposed two areas requiring a revised decision.

First, ADR-0005 did not require every demand record to identify an existing ShelfStack Product. Later drafts allowed unresolved demand to be stored as free-text descriptions. That would create a second, lower-quality product-identification system inside Product Requests and require later reconciliation with the Catalog.

ShelfStack should instead make Product creation and import easy from the demand workflow. Demand should then reference the resulting authoritative Product.

Second, ADR-0005 treated Purchase-Order Allocations as the general mechanism connecting Product Requests to incoming supply. That persistent supply commitment is necessary for Customer Requests, because ShelfStack must know which incoming quantity is promised to a customer.

The same commitment is not ordinarily necessary for:

* Staff Suggestions;
* Stock Replenishment;
* Frontlist Selections.

Those records exist primarily to obtain a buyer decision. Once a buyer chooses whether and how much to order, the request has served its operational purpose. Merchandise ordered from these sources becomes general expected supply rather than supply committed to the originating request.

Persisting allocation lifecycles for all demand types would create unnecessary coupling between buyer-decision records and later purchasing, receiving, cancellation, and re-sourcing activity.

ShelfStack therefore needs to preserve the distinction between:

```text
Customer demand
= an obligation that may remain open through ordering, receiving, reservation, and fulfilment

Non-customer acquisition demand
= a proposal or buying decision that is normally resolved when the buyer acts
```

## Decision

### 1. ShelfStack uses one Product Request model for acquisition demand

ShelfStack will continue using one general Product Request model to represent acquisition demand.

Initial request types are:

```text
customer_request
staff_suggestion
stock_replenishment
frontlist_selection
```

A potential future request type is:

```text
system_replenishment_suggestion
```

The request type determines whether the request represents:

* a continuing customer fulfilment obligation; or
* a buyer-decision record that is normally resolved when the buyer acts.

### 2. Every Product Request identifies an existing Product

Every Product Request must reference an existing ShelfStack Product.

```text
product_requests.product_id
= required
```

A Product Request must not use a free-text description as a substitute for Product identity.

Free-text notes may retain context, including:

* customer comments;
* acceptable substitutions;
* staff rationale;
* media or event references;
* buying notes;
* campaign or catalog references.

When the Product does not already exist, staff must first:

1. search the ShelfStack Catalog;
2. search a configured external catalog where available;
3. import or create the Product;
4. review likely duplicates;
5. return to the demand workflow with the Product selected.

An unidentified inquiry is not Product demand until a specific Product has been identified.

### 3. Product Variant may remain unresolved temporarily

A Product Request must identify a Product but may omit the exact Product Variant until the operational configuration is known.

```text
product_requests.product_variant_id
= nullable
```

The exact Variant becomes mandatory before:

* creating a Purchase-Order Line;
* reserving an exact Variant where the request requires one;
* fulfilling a Variant-specific Customer Request.

A request that requires a particular edition, condition, configuration, or other Variant-specific characteristic should identify that Variant as soon as it is known.

### 4. Demand, purchasing, allocations, reservations, and receipts remain separate

ShelfStack preserves these distinct concepts:

```text
Product Request
= why the store may want merchandise

Purchase Order
= the store’s intent to acquire merchandise

Purchase-Order Allocation
= expected incoming supply committed to a Customer Request

Inventory Reservation
= physically present merchandise committed to an incomplete workflow

Receipt
= delivered and accepted merchandise

Inventory Movement
= the event that changes physical inventory
```

Creating a Product Request does not:

* increase On Hand;
* increase On Order;
* create a Purchase Order;
* create a Purchase-Order Allocation automatically;
* create an Inventory Reservation automatically.

### 5. Customer Requests remain open through fulfilment

A Customer Request represents a customer obligation or intended fulfilment workflow.

ShelfStack evaluates possible coverage in this order:

1. physically present inventory;
2. compatible unallocated On-Order supply;
3. remaining quantity requiring buyer action.

#### Physically present supply

ShelfStack may identify potentially available inventory, but a staff member must physically locate and confirm it before committing it to the request.

After confirmation:

* quantity-tracked merchandise creates an Inventory Reservation;
* individually tracked merchandise reserves the exact Inventory Unit.

#### Incoming supply

An authorized user may create a Purchase-Order Allocation connecting a Customer Request to a Purchase-Order Line.

The allocation persists because ShelfStack must know:

* which incoming quantity is committed to the customer;
* whether the request is fully or partially covered;
* whether committed supply has been cancelled;
* whether replacement supply must be found;
* whether earlier compatible supply makes the allocation redundant;
* which accepted merchandise should become physically reserved.

Customer-request unfulfilled quantity is derived:

```text
requested quantity
− confirmed active Inventory Reservations
− active Purchase-Order Allocations
= unfulfilled quantity
```

Coverage must not exceed requested quantity without an explicit request-quantity change.

### 6. Purchase-Order Allocations are reserved for Customer Requests

A Purchase-Order Allocation represents expected supply committed to a Customer Request.

It does not represent the general reason a buyer decided to order merchandise.

An allocation:

* references one Customer Request;
* references one Purchase-Order Line;
* records committed quantity;
* does not increase On Hand;
* does not increase Reserved physical inventory;
* reduces incoming quantity available for later Customer Requests.

Staff Suggestions, Stock Replenishment, and Frontlist Selections do not ordinarily create Purchase-Order Allocations.

### 7. Non-customer requests are buyer-decision records

The purpose of a Staff Suggestion, Stock Replenishment request, or Frontlist Selection is to present a Product and proposed quantity for buyer consideration.

A buyer may:

* order the proposed quantity;
* order a different quantity;
* defer the decision;
* decline the request;
* close it as a duplicate or superseded request;
* keep a remaining quantity under review.

When a buyer places merchandise on a Purchase Order in response to a non-customer request, the request is normally closed with an ordered resolution.

The resulting Purchase-Order quantity:

* becomes general expected supply;
* is not committed to the originating request;
* becomes general inventory after receipt unless separately reserved;
* does not require an allocation lifecycle tied to the request.

The request should preserve the buyer’s decision, including:

* resolution;
* quantity selected by the buyer;
* resolving User;
* resolution time;
* explanatory note where appropriate.

Suggested resolution codes include:

```text
ordered
declined
deferred
duplicate
superseded
no_longer_needed
```

`deferred` may leave the request open rather than close it, depending on the final request-status workflow.

### 8. Buyer quantity supersedes advisory quantity

For non-customer requests, the requested or proposed quantity is advisory.

A buyer may order a different quantity and close the request as ordered.

Example:

```text
proposed quantity: 10
buyer orders: 6
resolution: ordered
request status: closed
```

The remaining four units do not automatically remain as demand.

When the buyer intentionally wants the remainder reconsidered later, ShelfStack should preserve that intention explicitly.

The preferred workflow is:

1. close the original request with the quantity ordered;
2. create a new request for the remaining quantity;
3. retain an audit or supersession reference between the requests.

This preserves a clear history of each buyer decision.

### 9. Non-customer demand does not require a durable PO relationship

ShelfStack does not require a persistent business relationship between a non-customer Product Request and the resulting Purchase-Order Line.

An implementation may retain a non-authoritative audit or navigation reference recording that a buyer acted on a request while creating a PO line.

Such a reference must not:

* behave as a Purchase-Order Allocation;
* reserve expected supply;
* control On Order;
* keep the request open until receipt;
* imply that received merchandise remains committed to the request.

The authoritative records are:

```text
Product Request resolution
= what the buyer decided

Purchase-Order Line
= what the store ordered
```

### 10. Later PO exceptions do not automatically reopen non-customer requests

When a PO line created after a non-customer request is later:

* cancelled;
* unavailable;
* discontinued;
* transferred to another vendor;
* partially supplied;

the original request does not automatically become an active supply commitment again.

A buyer may explicitly:

* reopen the original request where the workflow permits;
* create a replacement request;
* add the Product directly back to buyer review;
* decide no further action is required.

For a Customer Request, the behavior is different:

* the Customer Request remains open until resolved;
* cancelled expected supply releases its allocation;
* newly uncovered quantity returns to buyer review.

### 11. Buyer review is a derived work queue

“To Be Ordered,” or the buyer-review queue, is a user-facing projection of open Product Requests requiring buyer action.

It is not:

* a boolean field on a Purchase-Order Line;
* a permanent Product status;
* an inventory quantity;
* a replacement for Product Requests;
* a replacement for Purchase Orders.

The queue may group compatible demand for presentation, but underlying request identity and customer obligations must remain visible.

For Customer Requests, buyer-action quantity is derived from supply coverage.

For non-customer requests, buyer-review state is based primarily on request status and buyer disposition.

```text
open non-customer request
= awaiting buyer decision

closed with ordered resolution
= buyer acted; no continuing supply commitment
```

### 12. Customer-request priority applies to compatible supply

Compatible Customer Requests should ordinarily be ranked by:

1. explicitly authorized priority;
2. needed-by date;
3. request creation time.

Priority applies only when the same Product or an explicitly approved Variant can legitimately fulfil the requests.

A Customer Request must not remain unnecessarily committed to later supply when earlier compatible merchandise becomes available.

When earlier supply fulfils the request:

* physical merchandise is reserved;
* redundant future allocations are reduced or cancelled;
* later expected supply becomes available to another request or general stock.

## Consequences

### Benefits

* Preserves one Product Request model without creating a shadow product catalog.
* Makes Catalog identity authoritative before demand is recorded.
* Separates continuing customer obligations from ordinary buyer decisions.
* Limits Purchase-Order Allocations to situations where persistent supply commitment is operationally meaningful.
* Avoids unnecessary allocation and receipt lifecycles for replenishment, staff suggestions, and frontlist buying.
* Keeps received non-customer merchandise available as general stock.
* Preserves the distinction between requested, ordered, expected, physically present, reserved, and fulfilled merchandise.
* Allows the buyer to override advisory quantities without manufacturing residual demand.
* Supports a derived buyer-review queue without `tbo_required` or similar PO-line flags.
* Keeps customer demand covered through vendor cancellation and re-sourcing changes.

### Costs

* Product search and quick creation must be available from demand workflows.
* Staff cannot record unidentified merchandise as Product demand.
* Non-customer request closure must capture enough resolution information to explain the buyer’s decision.
* Partial non-customer decisions may require creating a follow-up request.
* Customer Requests require allocation, reservation, and fulfilment logic that other request types do not.
* The interface must explain why Customer Requests remain open while other request types may close upon ordering.
* Earlier documents and schema exports that permit unresolved Product identity must be updated.
* ADR-0005, Domain Specifications, phase plans, permission catalogs, and schema documentation must be reconciled.

## Alternatives considered

### Update ADR-0005 directly

Rejected because the new decision materially changes:

* Product identity requirements;
* the initial request-type set;
* the scope of Purchase-Order Allocations;
* the lifecycle of non-customer requests;
* implementation consequences across Catalog, Product Requests, Purchasing, Receiving, and POS.

A superseding ADR preserves the history of the original separation decision while making the revised rules explicit.

### Allow unresolved free-text Product Requests

Rejected because this would create a parallel product-identification system outside the Catalog.

It would require:

* later Product resolution;
* duplicate detection after demand exists;
* migration of request identity;
* special buyer-review behavior for unidentified records.

ShelfStack instead makes Product creation part of demand entry.

### Persist Purchase-Order Allocations for every request type

Rejected because non-customer requests do not ordinarily create continuing fulfilment obligations.

Persisting allocations for all requests would unnecessarily couple:

* replenishment suggestions;
* staff buying ideas;
* frontlist decisions;

to later PO receipt, cancellation, re-sourcing, and fulfilment activity.

### Persist a required PO-line source link for non-customer requests

Rejected as a governing requirement because the Product Request resolution and Purchase-Order Line already preserve the important business facts.

A non-authoritative audit or navigation correlation may be retained, but it must not become a supply commitment.

### Delete non-customer requests after ordering

Rejected because the request and its buyer resolution provide useful operational and audit history.

Requests should be closed, not deleted.

### Keep the original request open until ordered merchandise is received

Rejected because receipt does not complete a staff suggestion, replenishment proposal, or frontlist buying decision.

The buyer’s order decision resolves those request types. Receiving governs physical supply separately.

### Automatically retain unselected quantity as open demand

Rejected because proposed non-customer quantity is advisory.

The buyer’s selected quantity supersedes the proposal unless the buyer explicitly creates or preserves a follow-up request.

## Governing rules

* Every Product Request references an existing ShelfStack Product.
* Product Variant may remain nullable until an exact configuration is required.
* Product Requests represent demand, not supply.
* Customer Requests represent continuing fulfilment obligations.
* Staff Suggestions, Stock Replenishment, and Frontlist Selections represent buyer-decision work.
* Purchase-Order Allocations commit expected supply only to Customer Requests.
* Inventory Reservations commit physically present supply.
* In-house Customer Request reservations require physical confirmation.
* Creating a Product Request does not change On Hand or On Order.
* Creating a Purchase-Order Allocation does not change On Hand or Reserved.
* Non-customer requests normally close when the buyer orders, declines, or otherwise resolves them.
* Merchandise ordered from a non-customer request becomes general expected supply.
* Merchandise received from non-customer demand becomes general stock unless separately reserved.
* A buyer-selected quantity may differ from a proposed non-customer quantity.
* Residual non-customer demand exists only when the buyer explicitly preserves or creates it.
* PO cancellation automatically uncovers Customer Request demand when an allocation is released.
* PO cancellation does not automatically reopen a closed non-customer request.
* The buyer-review queue is derived and is not an inventory or PO-line field.
* Requests and historical purchasing facts are not deleted merely because the workflow is complete.

## Open details

The following details remain to be resolved in the applicable Domain Specifications or implementation decisions:

* whether non-customer resolution fields are stored directly on `product_requests` or through a request-resolution event;
* whether a lightweight audit correlation between a resolved non-customer request and a PO line is useful;
* whether partially ordered non-customer requests always create a follow-up request or may be split in place;
* how request supersession relationships are represented;
* whether allocation conversion after receipt is persisted as statuses, quantity events, or separate fulfilment records;
* how final Customer Request fulfilment is linked to POS or another delivery workflow;
* how substitutions are authorized;
* how unclaimed customer reservations are released.

These details must not change the governing distinction between Customer Request supply commitments and non-customer buyer decisions.

## Related domains

* Catalog and Products
* Product Requests
* Vendors and Purchasing
* Receiving and Inventory
* Point of Sale
* Future Customer domain
* Reporting and Reconciliation

## Related ADRs

* [ADR-0001: Separate Product, Product Variant, and Inventory Unit](0001-product-variant-inventory-unit.md)
* [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](0006-inventory-quantities-and-reservation-records.md)
* [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](0007-purchasing-receiving-and-inventory-events.md)
* [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](0013-govern-quantity-tracked-inventory-cost.md)

## Related specifications

* [Product Requests Domain](../domains/product-requests.md)
* [Ordering and Acquisition Planning](../domains/ordering-and-acquisition-planning.md)
* [Vendors and Purchasing Domain](../domains/vendors-and-purchasing.md)
* [Receiving and Inventory Domain](../domains/receiving-and-inventory.md)
* [Phase 5 — Supply and Demand](../implementation/phases/phase-05-supply-and-demand.md)
* [Phase 5 Ordering Scope and Future-Lifecycle Boundaries](../implementation/phase-05-ordering-scope-and-future-lifecycle-boundaries.md)
