# Ordering and Acquisition Planning

**Status:** Governing planning specification for Phase 5 supply and demand  
**Scope:** Product-backed acquisition demand, buyer review, vendor sourcing, expected cost, and connection to receiving and fulfilment  
**Governing ADR:** [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md)  
**Related phase plan:** [../implementation/phases/phase-05-supply-and-demand.md](../implementation/phases/phase-05-supply-and-demand.md)  
**Lifecycle boundaries:** [../implementation/phase-05-ordering-scope-and-future-lifecycle-boundaries.md](../implementation/phase-05-ordering-scope-and-future-lifecycle-boundaries.md)

## 1. Purpose

This document describes how ShelfStack identifies merchandise that may need to be ordered, presents that demand to buyers, supports vendor sourcing, calculates expected acquisition cost, and connects incoming supply to customer fulfilment and store inventory.

In this document, **buyers** are store staff authorized to make the final decisions about:

* whether merchandise should be ordered;  
* how much should be ordered;  
* which vendor should supply it;  
* whether unavailable merchandise should be backordered, sourced elsewhere, deferred, or cancelled.

The initial implementation does not need to support every possible vendor response or purchasing exception. It must establish a model that can later support a fuller order lifecycle without replacing the records created during Phase 5.

---

## 2. Core principles

### 2.1 ShelfStack tracks demand for products

Every acquisition-demand record must reference an existing ShelfStack product.

This applies to:

* customer requests;  
* staff suggestions;  
* replenishment demand;  
* frontlist buying;  
* buyer-created acquisition requests;  
* future automated replenishment suggestions.

ShelfStack does not use free-text demand records as temporary substitutes for products.

If the product does not yet exist, staff must first:

1. search the ShelfStack catalog;  
2. search an external catalog where available;  
3. import or create the product;  
4. confirm the new product;  
5. create demand against that product.

The intended workflow is:

```
Search ShelfStack
→ product found
   → create demand

→ product not found
   → search external catalog or quick-create product
   → create or confirm ShelfStack product
   → create demand
```

The product may initially be incomplete for sale or purchasing, but it must provide a stable commercial identity.

### 2.2 Product and variant remain distinct

Acquisition demand must identify a product.

The exact product variant may remain unresolved when:

* several variants could satisfy the demand;  
* the exact condition or configuration has not been selected;  
* the product has been created but its standard variant is not yet complete;  
* a buyer must decide which sellable configuration to order.

Before merchandise is added to a purchase order, ShelfStack must resolve the exact product variant being ordered.

```
Product request
= demand for the commercial item

Product variant
= exact configuration selected for purchasing and fulfilment
```

When the customer requires a specific edition, format, condition, size, package, or other configuration, the request should identify the variant as soon as that requirement is known.

### 2.3 Demand remains separate from purchasing and inventory

ShelfStack must preserve the following distinctions:

```
Acquisition demand
= why the store may want merchandise

Vendor source
= how a vendor supplies a product variant

Purchase order
= the store’s intent to acquire merchandise

Purchase-order allocation
= expected incoming supply committed to customer demand

Inventory reservation
= physically present merchandise committed to a request

Receipt
= merchandise delivered and accepted

Inventory movement
= the event that changes physical on-hand quantity
```

Creating demand does not:

* create a purchase order;  
* increase `on_order`;  
* increase `on_hand`;  
* create a physical inventory reservation.

### 2.4 “To Be Ordered” is a work queue

**To Be Ordered**, or the **buyer-review queue**, is a user-facing projection of acquisition demand requiring buyer action.

It is not:

* a boolean on a purchase-order line;  
* a permanent product status;  
* an inventory quantity;  
* a replacement for customer requests or staff suggestions;  
* a substitute for purchase orders.

The queue may combine compatible demand for presentation, but the underlying reasons and commitments must remain traceable.

---

## 3. Product creation from demand workflows

### 3.1 Quick product creation

The product requirement must not make demand entry cumbersome.

From customer-request, staff-suggestion, replenishment, and frontlist workflows, staff should be able to:

1. search the local catalog;  
2. search configured external catalogs;  
3. select an external result;  
4. review which data will be imported;  
5. create a minimal product manually when no external result exists;  
6. return directly to the original workflow with the product selected.

The quick-create process should collect enough information to establish reliable product identity.

Depending on the product type, this may include:

* canonical identifier;  
* title or product name;  
* product type;  
* format;  
* publisher, manufacturer, or brand;  
* publication or release date;  
* list price;  
* merchandise class;  
* standard variant information.

### 3.2 Readiness levels

A product may be valid enough to support demand while not yet being ready for purchasing, receiving, inventory, or sale.

Conceptually, ShelfStack should distinguish:

```
Identified
→ Demand-ready
→ Purchasing-ready
→ Receiving-ready
→ Sale-ready
```

These may be implemented as derived readiness checks rather than stored statuses.

A demand-ready product requires stable identity.

A purchasing-ready product additionally requires an exact purchasable variant and sufficient purchasing configuration.

A sale-ready variant requires the classifications, price, tax treatment, and operational settings required by POS.

### 3.3 Duplicate prevention

Quick product creation must use the standard identifier normalization and duplicate-detection services.

Before creating a new product, ShelfStack should check:

* canonical identifier;  
* normalized ISBN;  
* UPC and EAN equivalence;  
* alternate identifier;  
* probable title, format, and publisher matches.

Probable matches should be shown before a duplicate product is created.

### 3.4 Products without external identifiers

A legitimate commercial product without a usable external identifier may receive a ShelfStack-generated local product identifier.

This is appropriate for actual products such as:

* locally produced merchandise;  
* services;  
* handmade or local goods;  
* products with no reliable manufacturer identifier.

It must not be used to create a placeholder product for an unidentified inquiry.

A request such as “a book about regional birdwatching” does not yet identify a product. Staff must identify the specific title before recording product demand.

---

## 4. Sources of acquisition demand

## 4.1 Stock replenishment

Buyers need to review recent sales together with current and expected supply.

The replenishment view should show, where available:

* recent unit sales over selectable periods;  
* current `on_hand`;  
* `reserved`;  
* `unavailable`;  
* `available`;  
* total `on_order`;  
* allocated on-order quantity;  
* unallocated on-order quantity;  
* open customer demand;  
* last sold date;  
* last ordered date;  
* last received date;  
* current selling price;  
* expected or last known cost.

The buyer should be able to:

* enter a proposed replenishment quantity;  
* add the quantity to buyer review;  
* add it directly to a purchase order when the vendor is known;  
* combine compatible replenishment demand;  
* review existing supply before ordering more.

Replenishment demand:

* references a product;  
* may identify a preferred variant;  
* does not create a customer obligation;  
* does not reserve received merchandise.

Automated forecasting is not required initially.

## 4.2 Customer requests

A customer request represents demand that the store is attempting to fulfil for a customer or customer reference.

A request should identify:

* store;  
* product;  
* optional product variant;  
* requested quantity;  
* customer reference;  
* priority;  
* needed-by date;  
* requesting user;  
* assigned buyer;  
* notes;  
* status;  
* timestamps.

### In-house inventory

ShelfStack identifies potentially available merchandise.

A staff member must physically locate and confirm the merchandise before committing it to the customer request.

After confirmation:

* quantity-tracked merchandise creates a quantity reservation;  
* individually tracked merchandise reserves the exact inventory unit.

Database availability alone does not confirm that an item has been found.

### Existing on-order supply

If confirmed in-house inventory is insufficient, ShelfStack should identify compatible incoming quantity that is not already allocated.

An authorized user may allocate that future quantity to the request.

### Buyer review

The remaining quantity enters buyer review.

```
requested quantity
− confirmed active inventory reservations
− active purchase-order allocations
= quantity requiring buyer action
```

## 4.3 FIFO customer fulfilment

Compatible customer requests should ordinarily be fulfilled first-in, first-out.

Normal priority should consider:

1. an explicitly authorized priority;  
2. needed-by date;  
3. request creation time.

FIFO applies only among requests that can legitimately be fulfilled by the same merchandise.

ShelfStack must not automatically substitute:

* another product;  
* another edition;  
* another format;  
* another condition;  
* another variant;  
* a different exact unit where exact identity matters.

Substitution requires explicit approval.

### Earliest compatible supply

A customer request should not remain tied to a later shipment when earlier compatible merchandise becomes available.

When compatible supply arrives or becomes available:

1. ShelfStack considers eligible customer requests;  
2. the oldest applicable request receives priority;  
3. physically present merchandise is reserved;  
4. any redundant future allocation is reduced or cancelled;  
5. remaining supply becomes available to later requests or general stock.

Coverage must never exceed the request quantity.

## 4.4 Staff suggestions

Staff may suggest products for buyer review when they expect customer demand.

Examples include:

* repeated informal inquiries;  
* a customer asked about a product but declined to place a request;  
* media coverage;  
* a local event;  
* staff knowledge of likely demand;  
* a gap in the store’s assortment.

A staff suggestion:

* references a ShelfStack product;  
* may identify a variant;  
* enters buyer review;  
* does not create a customer obligation;  
* does not reserve current stock;  
* does not ordinarily commit future stock to a customer.

Received merchandise ordered from a staff suggestion remains general stock unless separately reserved.

## 4.5 Frontlist and forthcoming merchandise

Frontlist merchandise must be created or imported as ShelfStack products before buyer demand is recorded.

The workflow should support:

* external catalog search;  
* batch product import;  
* product review before creation;  
* automatic standard-variant creation where appropriate;  
* immediate addition to buyer review or a purchase order.

Frontlist demand may record:

* product;  
* optional product variant;  
* proposed quantity;  
* expected release date;  
* proposed vendor;  
* buyer;  
* campaign or catalog source;  
* notes.

The catalog or campaign reference provides context. It does not replace the product relationship.

A full frontlist-management system may remain deferred.

---

## 5. Buyer-review queue

The buyer-review queue should support both individual demand records and useful grouping.

Potential grouping dimensions include:

* store;  
* product;  
* product variant;  
* demand source;  
* publisher or manufacturer;  
* proposed or preferred vendor;  
* assigned buyer;  
* needed-by date;  
* priority;  
* sourcing state.

A grouped row should distinguish:

* customer-request quantity;  
* staff-suggestion quantity;  
* replenishment quantity;  
* frontlist quantity;  
* quantity physically reserved;  
* quantity allocated on order;  
* remaining quantity requiring action.

ShelfStack must not combine quantities in a way that obscures:

* customer references;  
* FIFO priority;  
* needed-by dates;  
* exact-variant requirements;  
* substitution restrictions;  
* store ownership;  
* incompatible vendor packs or cost bases.

A buyer may:

* choose a vendor source;  
* create a vendor source;  
* check vendor availability;  
* add quantity to a purchase order;  
* defer action;  
* decline demand;  
* cancel demand;  
* return unresolved quantity for further sourcing.

---

## 6. Sourcing

## 6.1 Vendor selection may occur later

The vendor does not need to be known when demand is created.

A buyer may:

* select a known source;  
* compare available sources;  
* create a new source;  
* perform an availability check;  
* defer sourcing;  
* return the demand to buyer review.

The sourcing decision does not change the original reason the product is wanted.

## 6.2 Multiple vendor sources

One product variant may be available from several vendors.

A vendor source may contain:

* product variant;  
* vendor;  
* vendor item code;  
* vendor identifier;  
* vendor list price or cost basis;  
* default discount;  
* expected net cost;  
* currency;  
* minimum quantity;  
* order multiple;  
* pack quantity;  
* lead time;  
* returnability;  
* preferred status;  
* last ordered date;  
* last received date;  
* notes.

The preferred source is a recommendation, not a restriction.

## 6.3 Wholesalers and direct vendors

Vendors may be described as:

* wholesalers;  
* publishers;  
* manufacturers;  
* distributors;  
* local suppliers;  
* consignors;  
* other vendor types.

Vendor type is descriptive.

Capabilities such as availability checking, electronic ordering, acknowledgements, and backordering should be represented separately rather than inferred solely from vendor type.

## 6.4 Availability checking

Some vendors allow a buyer to check availability before placing an order.

A future-compatible workflow is:

```
buyer-review demand
→ select vendor
→ perform availability check
→ record result
→ decide how to proceed
```

Possible outcomes include:

* available;  
* partially available;  
* backorderable;  
* unavailable;  
* discontinued;  
* unknown;  
* further research required.

The buyer may then:

* order available quantity;  
* backorder some quantity;  
* source remaining quantity elsewhere;  
* cancel the demand;  
* return it to buyer review.

An availability response does not increase `on_order`. Only quantity on an active purchase order contributes to `on_order`.

## 6.5 Backorders

A backorder means the vendor has not supplied merchandise immediately but may fulfil it later.

Backorder handling must remain separate from:

* customer-request status;  
* physical inventory reservations;  
* purchase-order allocations;  
* received quantity;  
* cancelled quantity.

A purchase-order line may eventually have mixed outcomes:

```
ordered: 10
confirmed available: 4
backordered: 3
unavailable: 3
```

The initial implementation may use a simpler open-quantity model, but the design must not assume that one line status can represent every vendor response.

## 6.6 Cascading to another vendor

Changing vendors after an order has been placed must not alter the original purchase-order line in place.

The workflow should:

1. preserve the original PO line;  
2. record the quantity the original vendor will not supply;  
3. cancel or release that quantity where appropriate;  
4. return uncovered demand to buyer review;  
5. select another vendor;  
6. create a new PO line;  
7. recreate or transfer applicable allocations;  
8. retain the relationship between sourcing attempts.

This preserves accurate vendor and purchasing history.

---

## 7. Vendor terms and discounts

## 7.1 Default discounts

A vendor or vendor source may provide a default discount.

Suggested precedence:

```
variant-vendor source discount
→ store-specific vendor terms
→ organization-wide vendor terms
→ vendor default discount
→ manual entry
```

The discount used on a purchase-order line is snapshotted.

Later vendor-term changes must not rewrite historical orders.

## 7.2 Tiered and order-specific discounts

Some vendors offer discounts based on:

* order list-value subtotal;  
* net subtotal;  
* unit quantity;  
* eligible merchandise groups;  
* promotional programs;  
* returnability terms.

The initial implementation may permit manual discount changes instead of a complete tier engine.

Buyers must be able to bulk-edit selected purchase-order lines.

Bulk editing should:

* show affected lines;  
* preserve excluded or locked lines;  
* recalculate expected cost;  
* record the resulting discount on each line;  
* preserve line history after placement.

## 7.3 Minimum orders

Vendor terms may include:

* minimum merchandise amount;  
* minimum unit quantity;  
* order multiple;  
* pack quantity;  
* free-freight threshold.

Before placement, ShelfStack should show whether the order satisfies those terms.

Initial enforcement may use warnings rather than universal blockers.

---

## 8. Expected cost

## 8.1 Discount-from-list cost

Common for books and some other merchandise:

```
net unit cost
=
vendor list price
× (1 − discount rate)
```

## 8.2 Direct net cost

Common for gifts, sidelines, stationery, café products, and other merchandise sold to the store at a quoted wholesale cost.

For direct-net merchandise:

* the buyer enters net unit cost;  
* list price may be absent;  
* discount may be absent;  
* ShelfStack does not invent a misleading discount.

## 8.3 Purchase-order line cost information

A purchase-order line should retain:

* vendor list price or cost basis;  
* discount rate;  
* net unit cost;  
* extended expected cost;  
* cost-entry method;  
* currency;  
* vendor-source reference;  
* calculation provenance.

## 8.4 Synchronized manual entry

When a meaningful list-price basis exists:

### Editing discount

* preserve list price;  
* recalculate net unit cost;  
* recalculate extended cost.

### Editing net cost

* preserve list price;  
* recalculate effective discount;  
* identify the line as manually costed where appropriate.

### Editing list price

* preserve the effective discount;  
* recalculate net unit cost;  
* recalculate extended cost.

For direct-net merchandise, changing a descriptive list price must not silently alter manually entered net cost.

All calculations use deterministic integer-cent rounding.

## 8.5 Catalog list price and selling-price review

The vendor list price on a PO line is a historical purchasing fact.

It is distinct from:

* current product list price;  
* current variant selling price;  
* final POS price.

When the order-line list price differs from the product’s current list price, ShelfStack should show:

* existing catalog list price;  
* entered vendor list price;  
* current selling price;  
* expected margin effect.

The buyer may explicitly choose to:

* retain existing prices;  
* update the product list price;  
* update the variant selling price;  
* apply a pricing recommendation;  
* defer review.

ShelfStack must not silently update catalog or selling prices.

---

## 9. Purchase-order creation from demand

A buyer should be able to create or update a purchase order from selected demand.

The workflow should:

1. select the receiving store;  
2. select the vendor;  
3. resolve or create variant-vendor sources;  
4. resolve exact product variants;  
5. determine quantities attributable to each demand source;  
6. respect packs, multiples, and minimums;  
7. populate expected list price, discount, and net cost;  
8. permit bulk discount and cost editing;  
9. show vendor thresholds;  
10. create Purchase-Order Allocations only for Customer Request quantities (ADR-0015);  
11. close non-customer requests with buyer resolution when ordering from them;  
12. leave unplaced Customer Request quantity in buyer review.

Several compatible demand records may contribute quantity to one PO line for ordering convenience. Only Customer Requests retain persistent allocations. Non-customer requests close with resolution; a non-authoritative audit hint to the ordering session is optional and must not behave as an allocation.

---

## 10. Receiving and fulfilment

A receipt represents one vendor shipment or receiving event at one store.

One receipt may contain lines from several purchase orders.

Each receipt line may reference at most one purchase-order line.

Only accepted quantity enters inventory.

Receipt posting should:

* create inventory movements;  
* update stock balances;  
* create exact inventory units where required;  
* update accepted received quantity;  
* reduce derived `on_order`;  
* establish receipt-based cost;  
* update last-received information;  
* surface related customer allocations.

When received merchandise covers customer demand:

1. determine eligible requests;  
2. apply FIFO and authorized priority;  
3. reserve physically accepted merchandise;  
4. reduce or cancel redundant allocations;  
5. leave uncommitted quantity as general stock.

Posted receipts must not be edited to rewrite inventory history.

---

## 11. Future order-lifecycle compatibility

The initial model must support later expansion toward:

```
product demand
→ buyer review
→ source research
→ availability check
→ vendor selection
→ purchase order
→ vendor acknowledgement
→ available / partial / backordered / unavailable
→ cascade, defer, cancel, or continue
→ shipment
→ receipt
→ customer fulfilment or general stock
```

The initial implementation must therefore preserve these rules:

* every demand record references a product;  
* vendor is not required when demand is created;  
* purchase-order lines always identify exact variants;  
* ordered lines do not change vendors in place;  
* sourcing attempts remain traceable;  
* vendor outcomes may be quantity-based;  
* allocations may be reduced, cancelled, or replaced;  
* customer demand may be fulfilled by earlier compatible supply;  
* cost provenance is retained;  
* accepted receipt quantity, not vendor confirmation, creates inventory.

## Related

- [Product Requests](product-requests.md)
- [Vendors and Purchasing](vendors-and-purchasing.md)
- [Receiving and Inventory](receiving-and-inventory.md)
- [Catalog and Products](catalog-and-products.md)
- [Phase 5 plan](../implementation/phases/phase-05-supply-and-demand.md)
- [Phase 5 ordering scope and future-lifecycle boundaries](../implementation/phase-05-ordering-scope-and-future-lifecycle-boundaries.md)
- [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md)
- [OD-007](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md)
- [OD-014](../implementation/decisions/od-014-negative-inventory-settlement.md)
- [ADR-0007](../adr/0007-purchasing-receiving-and-inventory-events.md)
- [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md)

