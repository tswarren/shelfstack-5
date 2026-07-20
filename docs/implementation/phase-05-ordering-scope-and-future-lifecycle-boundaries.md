# Phase 5 Ordering Scope and Future-Lifecycle Boundaries

**Status:** Governing Phase 5 implementation boundary  
**Phase plan:** [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)  
**Planning detail:** [../domains/ordering-and-acquisition-planning.md](../domains/ordering-and-acquisition-planning.md)  
**Accepted decisions:** [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md); [OD-007](decisions/od-007-allocation-receipt-and-fulfilment.md); [OD-014](decisions/od-014-negative-inventory-settlement.md)  
**Deferred catalog:** [deferred-capabilities.md](deferred-capabilities.md)

Purchase-Order Allocations are reserved for Customer Requests. Non-customer demand closes with buyer resolution (ADR-0015). Allocation `received`/`fulfilled` statuses are not used; see OD-007.

## 1. Purpose

Phase 5 establishes ShelfStack’s initial supply-and-demand workflow:

```
Product
→ acquisition demand
→ buyer review
→ vendor sourcing
→ purchase order
→ receiving
→ inventory
→ customer fulfilment or general stock
```

Phase 5 does not implement the complete vendor-order lifecycle.

It must deliver a usable acquisition workflow while preserving the structural distinctions needed for later:

* vendor acknowledgements;  
* backorders;  
* alternate sourcing;  
* frontlist imports;  
* automated replenishment;  
* vendor integrations;  
* customer notifications;  
* vendor returns and claims.

---

## 2. Governing Phase 5 decisions

## 2.1 Demand requires a product

Every Phase 5 acquisition-demand record must reference an existing ShelfStack product.

This includes:

* customer requests;  
* staff suggestions;  
* replenishment demand;  
* frontlist demand;  
* buyer-created demand.

`product_id` is required.

`product_variant_id` may remain nullable until the exact purchasable or fulfilment configuration is selected.

Free-text notes may provide context but do not replace product identity.

## 2.2 Product creation precedes demand creation

When a product does not exist, the user must be able to:

1. search external catalogs;  
2. import a product;  
3. quick-create a product manually;  
4. confirm duplicate warnings;  
5. return to demand entry with the new product selected.

Phase 5 must not create a second shadow catalog through unresolved demand descriptions.

## 2.3 Buyer review is derived work

“To Be Ordered” is a buyer-facing projection.

It is not:

* a PO-line boolean;  
* an inventory field;  
* a product lifecycle status;  
* a substitute for demand records.

## 2.4 Product requests, allocations, and reservations remain separate

```
Product request
= demand

Purchase-order allocation
= future supply committed to demand

Inventory reservation
= physical supply committed to demand

Purchase order
= acquisition intent

Receipt
= accepted physical supply
```

---

## 3. Phase 5 requirements

## 3.1 Product creation and demand-entry integration

Phase 5 must provide a product search and quick-create path from demand workflows.

Required behavior:

* search ShelfStack products;  
* normalize identifier input;  
* detect likely duplicates;  
* search external catalogs when configured;  
* import selected metadata;  
* manually create a minimal product;  
* create a standard variant where appropriate;  
* return to the original demand workflow.

The product may be demand-ready without being sale-ready.

## 3.2 Product requests

Phase 5 must support:

```
customer_request
staff_suggestion
```

A request should include:

* store;  
* request type;  
* required product;  
* optional product variant;  
* requested quantity;  
* customer reference where applicable;  
* priority;  
* needed-by date;  
* requesting user;  
* assigned buyer;  
* notes;  
* status;  
* timestamps.

Suggested high-level statuses:

```
open
fulfilled
declined
cancelled
closed
```

Detailed sourcing progress should be derived from supply coverage rather than encoded through numerous request statuses.

## 3.3 Customer-request fulfilment

The workflow must evaluate:

1. physically present inventory;  
2. existing unallocated on-order supply;  
3. remaining quantity requiring buyer review.

In-house inventory requires physical confirmation before reservation.

Unfulfilled quantity is derived:

```
requested quantity
− confirmed active reservations
− active purchase-order allocations
= unfulfilled quantity
```

## 3.4 FIFO coverage

Compatible customer requests should ordinarily be fulfilled according to:

1. authorized priority;  
2. needed-by date;  
3. request creation time.

When earlier compatible supply becomes available, it may fulfil a request previously allocated to later supply.

Redundant future allocations must then be reduced or cancelled.

## 3.5 Staff suggestions

Staff suggestions must:

* reference a product;  
* optionally reference a variant;  
* enter buyer review;  
* remain separate from customer obligations;  
* create no reservation by default;  
* create no customer-specific allocation by default.

## 3.6 Replenishment view

Phase 5 should provide a manual replenishment workspace showing:

* recent sales;  
* on hand;  
* reserved;  
* unavailable;  
* available;  
* on order;  
* allocated and unallocated future supply;  
* customer demand;  
* last ordered;  
* last received;  
* current selling price;  
* current or expected cost.

Buyers should be able to add proposed quantities to buyer review or directly to a PO.

## 3.7 Frontlist workflow

Frontlist products must be imported or created before demand is recorded.

Phase 5 should support:

* external product search;  
* batch product import where practical;  
* creation of standard variants;  
* addition of imported products to buyer review or POs.

Full publisher-catalog management is not required.

## 3.8 Vendors

Phase 5 must support vendor records containing:

* organization;  
* code;  
* name;  
* legal name;  
* active status;  
* vendor type;  
* currency;  
* account reference;  
* ordering contact;  
* default discount;  
* purchasing terms;  
* return-policy notes;  
* internal notes.

Inactive vendors remain available for history.

## 3.9 Variant-vendor sources

Phase 5 must support multiple vendor sources for one variant.

A source may include:

* product variant;  
* vendor;  
* vendor item code;  
* vendor identifier;  
* list-price or cost basis;  
* expected discount;  
* expected net cost;  
* minimum quantity;  
* order multiple;  
* pack quantity;  
* lead time;  
* returnability;  
* preferred status;  
* last ordered;  
* last received;  
* notes.

Variant-level sourcing is authoritative.

## 3.10 Purchase orders

Phase 5 must support:

* one receiving store;  
* normally one vendor;  
* PO number;  
* draft editing;  
* order placement;  
* administrative closure;  
* cancellation;  
* expected cost;  
* buyer;  
* expected date;  
* vendor reference;  
* notes.

A minimal commercial lifecycle may use:

```
draft
ordered
closed
cancelled
```

Receiving progress should ordinarily be derived:

```
not_received
partially_received
fully_received
```

## 3.11 Purchase-order lines

Each ordinary PO line must identify one product variant.

Required quantity concepts:

* ordered quantity;  
* accepted received quantity;  
* cancelled quantity;  
* open quantity.

```
open quantity
=
ordered quantity
− accepted received quantity
− cancelled quantity
```

Only active ordered open quantity contributes to `on_order`.

PO lines must snapshot:

* product description;  
* product identifier;  
* variant SKU;  
* vendor item code;  
* expected list price or cost basis;  
* discount;  
* net unit cost;  
* returnability where applicable.

## 3.12 Purchase-order allocations

Phase 5 must support allocations connecting customer requests to expected supply.

An allocation contains:

* purchase-order line;  
* product request;  
* quantity;  
* status;  
* creator;  
* cancellation details;  
* timestamps.

Initial statuses:

```
active
cancelled
```

Service constraints must ensure:

* active allocations do not exceed PO open quantity;  
* request coverage does not exceed requested quantity;  
* concurrent allocation is transactionally protected.

## 3.13 Expected cost

Phase 5 must support:

```
discount_from_list
direct_net_cost
```

For discount-from-list lines:

```
net unit cost
=
vendor list price
× (1 − discount rate)
```

When list price is meaningful:

* editing discount recalculates net cost;  
* editing net cost recalculates effective discount;  
* editing list price preserves discount and recalculates net cost.

Direct-net merchandise must not require an artificial discount.

PO lines should preserve cost-entry method and provenance.

## 3.14 Bulk discount changes

Buyers must be able to apply discount changes to selected PO lines.

The operation should:

* identify affected lines;  
* preserve excluded lines;  
* recalculate expected cost;  
* snapshot the final discount;  
* retain an audit trail.

## 3.15 Vendor minimums

Phase 5 should display:

* minimum order amount;  
* minimum quantity;  
* pack and order multiples;  
* free-freight threshold where known.

Initial behavior may use warnings instead of hard enforcement.

## 3.16 Catalog-price review

When PO list price differs from catalog list price, ShelfStack should show:

* current catalog list price;  
* PO list price;  
* current selling price;  
* expected margin effect.

Updating catalog or selling prices requires an explicit user action.

## 3.17 Receiving

Phase 5 must support:

* receipt headers;  
* receipt lines;  
* one shipment covering several POs;  
* at most one PO-line reference per receipt line;  
* delivered quantity;  
* accepted quantity;  
* rejected quantity;  
* actual unit cost;  
* unavailable accepted quantity or disposition;  
* discrepancy reason;  
* posting.

Only accepted quantity creates inventory.

Receipt posting must:

* create inventory ledger entries;  
* update stock balances;  
* create inventory units where required;  
* update accepted PO quantity;  
* reduce `on_order`;  
* update inventory cost;  
* update last-received information.

## 3.18 Request coverage after receipt

When allocated merchandise is accepted, Phase 5 should:

* identify related customer demand;  
* apply FIFO and authorized priority;  
* create or prepare a physical reservation;  
* release redundant allocations;  
* leave excess quantity available as general stock.

Allocation `received` / `fulfilled` statuses are not used; see OD-007.

## 3.19 Permissions

Canonical keys: [authorization-permissions.md](../domains/authorization-permissions.md). Phase 5 covers:

```
requests.request.view
requests.customer_request.create
requests.staff_suggestion.create
requests.stock_replenishment.create
requests.frontlist_selection.create
requests.request.edit
requests.request.assign_buyer
requests.reservation.create
requests.request.resolve
requests.request.decline
requests.request.cancel
requests.request.close
requests.request.fulfill

purchasing.vendor.view
purchasing.vendor.manage
purchasing.vendor_source.view
purchasing.vendor_source.manage
purchasing.purchase_order.view
purchasing.purchase_order.create
purchasing.purchase_order.edit_draft
purchasing.purchase_order.place
purchasing.purchase_order.cancel
purchasing.purchase_order.close
purchasing.allocation.create
purchasing.allocation.release
purchasing.cost.view

inventory.receipt.create
inventory.receipt.post
inventory.receipt.receive_unlinked
inventory.cost.view
```

## 3.20 Audit and concurrency

Phase 5 must audit:

* product creation from demand workflows;  
* request creation and changes;  
* buyer assignment;  
* vendor and source changes;  
* PO creation and placement;  
* PO quantity and cost changes;  
* allocation creation and cancellation;  
* receipt posting;  
* order closure and cancellation.

Concurrency protection is required for:

* purchase-order allocations;  
* inventory reservations;  
* receipt posting;  
* stock-balance updates;  
* PO accepted-quantity updates.

---

## 4. Future-compatible structural rules

These rules must shape the Phase 5 design even when the corresponding workflows are deferred.

## 4.1 Product identity is durable

Demand must remain attached to the same product through:

* sourcing;  
* ordering;  
* receipt;  
* reservation;  
* POS fulfilment;  
* later reporting.

Product merging or correction must preserve that history.

## 4.2 Variant may be resolved later

A request may begin at product level.

An exact variant becomes mandatory before:

* creating a PO line;  
* reserving an exact variant where required;  
* fulfilling a variant-specific customer request.

## 4.3 Vendor is not part of demand identity

The same demand may be sourced from several vendors over time.

Demand records must not require or permanently own one vendor.

## 4.4 Ordered lines retain vendor history

A placed PO line must not change vendor in place.

Alternate sourcing creates another PO line or future sourcing-attempt record.

## 4.5 Vendor outcomes may be quantity-based

The design must later accommodate mixed outcomes such as:

```
ordered
confirmed
backordered
unavailable
cancelled
received
```

without requiring one status to describe the entire line.

## 4.6 Sourcing attempts must remain traceable

Future history may need to show:

```
demand
→ vendor A unavailable
→ vendor B backordered
→ vendor C supplied
```

Phase 5 must not overwrite the records needed for this history.

## 4.7 Allocations may move between supplies

Customer demand may be:

* allocated to one PO;  
* fulfilled by earlier stock;  
* released from the original PO;  
* allocated to replacement supply;  
* fulfilled by another compatible receipt.

## 4.8 Vendor capabilities are separate configuration

Future vendor capabilities may include:

* availability checking;  
* electronic ordering;  
* acknowledgement import;  
* backorder support;  
* expected-date support;  
* shipment notices;  
* invoice feeds.

These must not be inferred only from vendor type.

## 4.9 Cost provenance remains explicit

Expected cost may originate from:

* vendor default;  
* store-specific terms;  
* variant-vendor source;  
* order-specific discount;  
* manually entered net cost;  
* vendor acknowledgement;  
* promotional terms.

The origin should remain explainable.

## 4.10 Discount schedules remain separate from PO snapshots

Future discount schedules may change.

Placed PO lines retain the actual discount and cost used at placement.

## 4.11 Posted receipts remain immutable

Future receiving corrections must use:

* corrective receipt records;  
* reversing inventory movements;  
* explicit cost corrections;

rather than editing posted receipt history.

---

## 5. Explicitly deferred capabilities

The following do not block Phase 5 completion.

## 5.1 Automated replenishment

Deferred:

* reorder points;  
* stock minimums and maximums;  
* seasonal forecasting;  
* automatic suggested quantities;  
* automatic PO generation.

## 5.2 Full frontlist management

Deferred:

* publisher catalog campaigns;  
* ONIX ingestion;  
* sales-representative worksheets;  
* catalog comparison;  
* automated buying lists.

## 5.3 Vendor integrations

Deferred:

* EDI;  
* vendor APIs;  
* electronic PO transmission;  
* real-time wholesaler availability;  
* acknowledgement import;  
* advance shipment notices;  
* invoice matching.

## 5.4 Complete vendor-response lifecycle

Deferred:

* confirmed quantity;  
* vendor-rejected quantity;  
* expected fulfilment date;  
* acknowledgement revisions;  
* discontinue notices;  
* repeated response events.

## 5.5 Automated cascading

Deferred:

* automatic fallback vendor selection;  
* automatic replacement POs;  
* automatic transfer of allocations;  
* automatic cancellation of original supply.

## 5.6 Full backorder management

Deferred:

* backorder queues;  
* aging;  
* vendor-specific expiration;  
* customer notifications;  
* automated cancellation;  
* partial backorder release.

## 5.7 Tiered-discount engine

Deferred:

* automatic threshold qualification;  
* product-group tiers;  
* promotional programs;  
* automatic recalculation while draft totals change.

Phase 5 supports defaults and manual bulk editing.

## 5.8 Advanced minimum enforcement

Deferred:

* hard blocking;  
* buyer approval for exceptions;  
* automatic consolidation until thresholds are reached;  
* cross-store purchasing consolidation.

## 5.9 Freight and landed cost

Deferred:

* freight allocation;  
* duty;  
* brokerage;  
* landed-cost calculation;  
* invoice cost reconciliation.

## 5.10 Advanced purchasing approvals

Deferred:

* dollar-value approval limits;  
* buyer budgets;  
* dual authorization;  
* departmental spending controls;  
* approval routing.

## 5.11 Rich customer capabilities

Deferred:

* full customer master domain;  
* email and SMS notifications;  
* deposits;  
* prepayment;  
* pickup scheduling;  
* unclaimed-order aging;  
* customer communication history.

Phase 5 may continue using a limited customer reference.

## 5.12 Vendor returns and claims

Deferred:

* RTV documents;  
* return authorizations;  
* vendor credits;  
* shortages and damage claims;  
* replacement shipments;  
* claim aging.

---

## 6. Phase 5 completion boundary

## 6.1 Supply flow

```
Find or create product
→ record acquisition demand
→ select vendor and variant
→ create and place purchase order
→ quantity appears on order
→ receive shipment
→ accepted quantity enters inventory
→ receipt cost updates inventory valuation
→ merchandise becomes available to POS
```

## 6.2 Customer-request flow

```
Find or create product
→ create customer request
→ search physical inventory
→ confirm and reserve stock

or

→ allocate incoming PO quantity
→ receive compatible merchandise
→ apply FIFO
→ reserve accepted stock
→ fulfil through POS
```

## 6.3 Staff-suggestion flow

```
Find or create product
→ create staff suggestion
→ buyer review
→ select vendor and quantity
→ purchase and receive
→ merchandise becomes general stock
```

## 6.4 Phase 5 exit criteria

Phase 5 is complete when:

* every acquisition-demand record references a product;  
* product quick-create is available from demand workflows;  
* POs create correct derived `on_order`;  
* receipt posting increases inventory only for accepted quantity;  
* one receipt may cover several POs;  
* customer requests may be covered by physical reservations and PO allocations;  
* FIFO is preserved for compatible customer demand;  
* redundant allocations can be released;  
* staff suggestions do not create customer obligations;  
* expected cost supports discount-from-list and direct-net entry;  
* existing POS can sell received stock;  
* deferred lifecycle capabilities remain addable without replacing Phase 5 records.

## Related

- [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)
- [../domains/ordering-and-acquisition-planning.md](../domains/ordering-and-acquisition-planning.md)
- [../domains/product-requests.md](../domains/product-requests.md)
- [../domains/vendors-and-purchasing.md](../domains/vendors-and-purchasing.md)
- [deferred-capabilities.md](deferred-capabilities.md)

