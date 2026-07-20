# Phase 5: Supply and Demand

## Consolidated Scope and Working Implementation Baseline

**Project:** ShelfStack 0.5

**Status:** Working consolidated specification

**Date:** July 20, 2026

**Purpose:** Combine the original Phase 5 scope with the supply, demand, purchase-order, fulfilment, and negative-inventory decisions established during design review.

| Document status This document is an implementation-facing consolidation. It explains the intended Phase 5 baseline without reproducing draft open-decision records. The accepted ADR set, domain specifications, schema documentation, permission catalog, and phase plan should be reconciled to this baseline before migrations are treated as authoritative. |
| :---- |

   
**1\. Executive summary**  
Phase 5 reconnects ShelfStack’s completed Point-of-Sale and inventory foundation to the processes by which a bookstore identifies demand, chooses vendors, places orders, receives merchandise, and either reserves that merchandise for a customer or makes it available as general stock.

| Product → acquisition demand → buyer review → vendor sourcing → purchase order → receipt → physical inventory → customer fulfilment or general stock |
| :---- |

   
The phase deliberately establishes a practical baseline rather than a complete enterprise purchasing platform. It must support ordinary bookstore acquisition and receiving work without prematurely implementing vendor acknowledgements, electronic ordering, automatic replenishment, invoice matching, or a full customer relationship domain.

The consolidated design rests on five central decisions:

1\.  All acquisition demand is product-backed. Staff create or import a ShelfStack Product before recording demand; free text may explain the request but does not substitute for product identity.

2\.  Customer Requests and non-customer demand have different lifecycles. Customer Requests remain open as fulfilment obligations. Staff Suggestions, Stock Replenishment, and Frontlist Selections are buyer-decision records and normally close when the buyer orders, declines, or otherwise resolves them.

3\.  Only Customer Requests maintain a persistent commitment to future supply through Purchase-Order Allocations. Non-customer requests do not remain linked to incoming stock after the buyer has acted.

4\.  Expected supply, physical reservations, and final fulfilment are separate facts. Receipt posting converts usable allocated supply into an Inventory Reservation; completed sale or delivery creates a separate Product Request Fulfilment fact.

5\.  Negative inventory is settled at the aggregate Store-and-Variant level. A receipt first moves negative On Hand toward zero, then creates positive inventory only for the remaining quantity. ShelfStack does not match each receipt to individual historical sales.

## **1.1 Phase 5 at a glance**

| Area | Phase 5 baseline |
| :---- | :---- |
| Demand | Product-backed Customer Requests, Staff Suggestions, Stock Replenishment, and Frontlist Selections. |
| Buyer review | Derived queue over unresolved requests and supply coverage; not a permanent product or PO-line flag. |
| Vendors | Vendor identity and Variant-specific sourcing, expected cost, packs, multiples, and manual buying context. |
| Purchase orders | Draft-to-ordered commercial workflow, line snapshots, explicit cancellations, derived receiving progress, and derived On Order. |
| Receiving | Multi-PO shipments, accepted/rejected/unavailable quantities, line-level PO links, atomic and idempotent posting. |
| Customer coverage | Future-supply allocations, physically confirmed reservations, receipt conversion, and final fulfilment through POS. |
| Inventory cost | Receipt-based cost, moving weighted average for positive quantity, and aggregate settlement when receipts encounter negative On Hand. |

 

# **2\. Goals and boundaries**

## **2.1 Goals**

·       Give staff a fast path from local or external product search into a valid acquisition-demand record.  
·       Give buyers a coherent queue that distinguishes customer obligations from ordinary assortment and replenishment decisions.  
·       Represent how each purchasable Product Variant can be sourced from one or more vendors.  
·       Create and place purchase orders with reliable quantity and expected-cost snapshots.  
·       Receive shipments that may combine merchandise from several purchase orders.  
·       Post only accepted merchandise into inventory and maintain exact cost provenance.  
·       Commit present or expected supply to Customer Requests without confusing allocations with physical reservations.  
·       Support partial receipt, partial customer fulfilment, cancellation, re-sourcing, and correction without rewriting posted history.  
·       Preserve Phase 4 POS behavior while allowing received stock to participate in ordinary sales and request fulfilment.

## **2.2 Out of scope**

·       Customer master records, communications, deposits, prepayment, and pickup scheduling.  
·       Automated replenishment, demand forecasting, and system-generated reorder recommendations.  
·       Full ONIX or frontlist campaign management.  
·       Vendor APIs, EDI, electronic order transmission, and automatic availability polling.  
·       Full vendor acknowledgement, backorder, substitution, and automatic vendor-cascading lifecycles.  
·       Automatic tiered-discount qualification and hard enforcement of vendor minimums.  
·       Freight, landed-cost allocation, foreign-exchange accounting, invoice matching, and accounts payable.  
·       Advanced PO approval thresholds, buyer budgets, and multi-level procurement workflows.  
·       Full return-to-vendor and inter-store transfer documents.  
·       Automated cross-store order consolidation.

## **2.3 Current Product Variant boundary**

Phase 5 continues the current one-standard-variant implementation baseline. Product Requests may leave \`product\_variant\_id\` unresolved because the request expresses demand for a commercial Product and because the model must remain compatible with later variant structures. Before a Purchase-Order Line is created, however, the exact Product Variant must be resolved. Phase 5 does not introduce option matrices, configurable variants, or variant-generation workflows beyond ensuring that an ordinary standard variant exists and is purchasing-ready.

# **3\. Governing domain distinctions**

| Product Request       	\= why the store may want merchandise Vendor Source         	\= how a vendor supplies a Product Variant Purchase Order        	\= the store’s intent to acquire merchandise Purchase-Order Allocation \= expected supply committed to a Customer Request Inventory Reservation 	\= physically present merchandise committed to an incomplete workflow Receipt               	\= merchandise delivered and accepted Inventory Movement    	\= the event that changes physical quantity Product Request Fulfilment \= merchandise actually delivered or sold in satisfaction of a request |
| :---- |

   
These records may participate in one workflow, but they are not interchangeable. Creating demand does not increase On Hand or On Order. Creating an allocation does not create physical stock or increase Reserved. A Receipt does not change inventory until posting succeeds. A reservation does not prove that the customer has received the merchandise. Final fulfilment does not rewrite the original request, allocation, receipt, or POS transaction.

## **3.1 Inventory quantities**

| available \= on\_hand − reserved − unavailable |
| :---- |

   
\`on\_order\` is a purchasing projection, not an Inventory Ledger balance. It is derived from placed Purchase-Order Lines and their accepted and cancelled quantities:

| open PO-line quantity \= max(ordered quantity − accepted received quantity − cancelled quantity, 0\) on\_order \= sum of open PO-line quantity for the Store and Product Variant |
| :---- |

 

# **4\. Product-backed acquisition demand**

## **4.1 Product identity is required**

Every Product Request references an existing ShelfStack Product. Free-text notes may retain customer comments, substitution constraints, staff rationale, catalog references, event context, or other buying information, but they do not serve as a temporary Product record.

When a Product does not exist, the demand workflow must allow staff to:

1\.  search the local ShelfStack catalog;

2\.  search configured external catalogs;

3\.  review and import an external result;

4\.  create a minimal Product manually when no external result exists;

5\.  run identifier normalization and duplicate detection;

6\.  create or confirm the standard Product Variant as appropriate;

7\.  return directly to the originating demand workflow with the Product selected.

A Product can be demand-ready before it is sale-ready. Stable commercial identity is sufficient for demand entry; an exact purchasable Variant and source configuration are required before ordering; price, tax, classification, and other operational settings are required before sale.

## **4.2 Initial Product Request types**

| Request type | Meaning | Normal end of lifecycle |
| :---- | :---- | :---- |
| Customer Request | A continuing obligation to obtain or hold merchandise for a customer reference. | Remains open through coverage and partial fulfilment; closes when fulfilled, cancelled, declined, or administratively resolved. |
| Staff Suggestion | A staff proposal based on likely demand, inquiries, events, media, assortment gaps, or local knowledge. | Normally closes when the buyer orders, declines, defers, or supersedes it. |
| Stock Replenishment | A buyer-facing proposal to replenish general stock after reviewing sales and current or expected supply. | Normally closes when the buyer makes the purchasing decision. |
| Frontlist Selection | A buyer-facing selection of forthcoming or newly released merchandise. | Normally closes when the buyer orders or otherwise resolves the selection. |

 

## **4.3 Non-customer requests close on buyer action**

Staff Suggestions, Stock Replenishment, and Frontlist Selections exist to obtain a buyer decision. When the buyer orders merchandise in response, the request is normally closed with an \`ordered\` resolution. The Purchase-Order quantity becomes general expected supply and later general stock; it is not committed to the originating request.

The non-customer request should preserve the decision through fields or an equivalent resolution event, including:

·       \`status\`;  
·       \`resolution\_code\` such as ordered, declined, deferred, duplicate, superseded, or no\_longer\_needed;  
·       \`resolved\_quantity\` reflecting the quantity the buyer actually chose;  
·       \`resolved\_at\` and \`resolved\_by\_user\_id\`;  
·       an optional resolution note.

The buyer-selected quantity supersedes the proposed quantity. If ten units were proposed and the buyer orders six, the original request can close as ordered for six; the remaining four do not automatically remain as demand. When the buyer wants the remainder reconsidered later, the preferred audit-friendly workflow is to create a follow-up request for the remaining quantity.

There is no required persistent relationship from these requests to a Purchase-Order Line. The request resolution records what the buyer decided; the Purchase-Order Line records what the store ordered. General audit logging may record that the buyer acted from a queue, but it must not behave as a supply allocation or keep the request open through receiving.

## **4.4 Customer Requests remain fulfilment obligations**

Customer Requests remain open because they represent an obligation rather than a suggestion. They use a nullable opaque \`customer\_reference\`; Phase 5 does not introduce a Customer table. The request may be covered by physically present stock, compatible expected supply, or a later buying action.

Coverage is evaluated in this order:

1\.  Identify potentially available in-house merchandise.

2\.  Require staff to physically locate and confirm the merchandise before reserving it.

3\.  Identify compatible, unallocated open Purchase-Order quantity.

4\.  Allocate expected supply when authorized.

5\.  Return any uncovered quantity to buyer review.

# **5\. Buyer-review queue**

The buyer-review queue is a projection over open Product Requests, physical reservations, expected-supply allocations, and relevant Product and Vendor Source data. It is not a separate demand table, a Product status, an inventory quantity, or a \`to\_be\_ordered\` flag on a PO line.

The queue should distinguish at least:

·       customer-request quantity and customer priority;  
·       staff-suggestion quantity;  
·       stock-replenishment quantity;  
·       frontlist-selection quantity;  
·       physically reserved quantity;  
·       allocated On-Order quantity;  
·       remaining quantity requiring buyer action;  
·       store, Product, Variant requirements, preferred vendor, needed-by date, buyer, and sourcing state.

Grouping is useful, but it must not obscure customer references, FIFO priority, needed-by dates, exact-Variant requirements, substitution restrictions, incompatible vendor packs, or different cost bases.

# **6\. Vendors and Product Variant sources**

A Vendor records the supplier identity and organization-level purchasing context. A Product Variant Vendor record describes how one Vendor supplies one exact Product Variant. It is the normal source for vendor SKU or item code, list cost, discount, expected net cost, pack size, order multiple, returnability, and other source-specific details.

## **6.1 Cost-entry methods and provenance**

Expected cost must distinguish how the amount was entered rather than storing a number with no explanation. Phase 5 supports at least:

| Method | Baseline behavior |
| :---- | :---- |
| Discount from list | Store list cost and discount basis; derive expected net cost with deterministic cent rounding. |
| Direct net cost | Store the expected net unit cost directly; list cost and discount may be absent. |

   
Purchase-Order Lines snapshot the chosen method and values so later Vendor Source changes do not rewrite placed orders. Cost quality and provenance should distinguish actual, confirmed, estimated, confirmed zero, and unknown values where relevant.

Bulk discount editing and warnings for vendor thresholds, pack sizes, and order multiples are in scope. Automatic discount-tier qualification and hard minimum enforcement remain deferred.

## **6.2 Vendor-term precedence**

The working baseline resolves expected purchasing defaults in this order:

| Variant-specific Vendor Source → Store-specific Vendor terms, when implemented → Organization-level Vendor defaults → authorized manual PO-line entry |
| :---- |

   
The final selected commercial values are snapshotted on the Purchase-Order Line. A later default change affects future work, not historical placed orders.

# **7\. Purchase-order baseline**

## **7.1 Identity and numbering**

A Purchase Order belongs to one receiving Store and normally one Vendor. It receives a Store-scoped, continuous, human-facing PO number when the draft is created. Numbers are never reused. Cancelled drafts retain their assigned number so references and audit history remain stable.

## **7.2 Commercial lifecycle**

| draft   ↓ place order ordered   ├─ receive partially or fully   ├─ cancel remaining line quantities   ↓ all ordered quantity received or cancelled closed draft or ordered may become cancelled when policy permits and no further activity is expected |
| :---- |

   
The minimal commercial status set is:

·       **\`draft\` —** editable purchasing intent not yet committed to the Vendor.  
·       **\`ordered\` —** the store has committed or transmitted the order; open quantity contributes to derived On Order.  
·       **\`closed\` —** no further ordinary ordering or receiving activity is expected; all quantity is received or cancelled.  
·       **\`cancelled\` —** the PO will not proceed or continue under the original commitment.

Receiving progress is derived separately as not received, partially received, or fully received. \`submitted\` and \`received\` are not commercial PO statuses in the Phase 5 baseline. There is no separate internal submission or approval state; permission to place the PO is the baseline control. Advanced approval routing remains deferred.

## **7.3 Placement contract**

The transition from draft to ordered is an atomic and idempotent commercial boundary. Placement must:

1\.  verify that the PO is still a draft;

2\.  verify active Store and Vendor context;

3\.  require at least one valid line and an exact purchasable Product Variant on every line;

4\.  validate positive quantities and surface pack, multiple, and minimum warnings;

5\.  calculate and snapshot expected cost, method, and provenance;

6\.  snapshot Product, Variant, vendor item code, returnability, and other historical line descriptions;

7\.  verify that customer allocations do not exceed supply;

8\.  record the placing User and timestamp;

9\.  change status to ordered;

10\. make open quantities visible in derived On Order;

11\. write an auditable placement event without permitting a retry to duplicate expected supply.

## **7.4 Mutability after placement**

After placement, Store, Vendor, currency, Product Variant identity, and historical commercial snapshots are immutable. Placed quantity is not silently reduced or overwritten. A reduction is recorded through explicit \`cancelled\_quantity\`, together with User, time, and reason. An increase should create a new line or an explicit amendment operation rather than rewriting the original commitment without history.

Any operation that reduces open quantity must protect active Customer Request allocations. It must preserve sufficient supply, release selected allocations, reassign them to replacement supply, or fail atomically.

## **7.5 Closing and reopening**

A PO can close only when every line has no remaining open quantity. Remaining quantity must be accepted through receiving or explicitly cancelled. Reopening is not part of the Phase 5 baseline. A mistake is corrected through an explicit correction or replacement PO rather than reactivating a closed commercial record.

## **7.6 Currency and duplicate lines**

One currency applies to the entire PO. For the baseline, it must match the Store’s operating currency; foreign-currency purchasing and exchange-rate accounting are deferred. Draft additions should merge when Product Variant, Vendor Source, cost basis, returnability, and operational purpose are compatible. Separate lines remain valid when those commercial facts differ.

# **8\. Purchase-Order Lines and On Order**

Purchase-Order Lines are Variant-level commercial commitments. At minimum they retain ordered quantity, cancelled quantity, Product and Variant snapshots, Vendor Source reference where available, expected-cost fields and method, vendor item code, returnability, notes, and placement context.

| open quantity \= max(ordered quantity − accepted received quantity − cancelled quantity, 0\) |
| :---- |

   
Open quantity contributes to On Order only while the PO is ordered and the line remains commercially active. On Order is never posted through the Inventory Ledger. A cached \`stock\_balances.on\_order\` is acceptable only if one transactionally protected posting service owns every update and it remains reconcilable to PO lines.

# **9\. Receiving**

## **9.1 Shipment and line structure**

A Receipt represents one physical receiving event. One Receipt header may contain lines from several Purchase Orders because vendors may consolidate shipments. Each Receipt Line references at most one Purchase-Order Line. An authorized unlinked Receipt Line may be permitted for unexpected or informal deliveries, but it requires an explicit reason and does not invent a retrospective PO commitment.

## **9.2 Quantity dimensions**

The baseline distinguishes what arrived, what the store accepted, what it rejected, and whether accepted merchandise is immediately available:

| delivered quantity \= accepted quantity \+ rejected quantity accepted quantity \= available quantity \+ unavailable quantity |
| :---- |

   
Only accepted quantity creates inventory. Rejected quantity is documented but does not enter On Hand. Accepted unavailable quantity enters On Hand and the unavailable bucket but is not immediately available for sale or customer reservation.

## **9.3 Over-receipt and discrepancies**

Over-receipt is permitted only through an explicit warning and authorized confirmation. Accepted over-receipt increases inventory, but PO open quantity and On Order are floored at zero and never become negative. The discrepancy and approving User are retained. Short receipt leaves the remaining PO quantity open unless it is explicitly cancelled.

## **9.4 Posting rules**

·       Receipt posting is atomic and idempotent.  
·       Posting creates Inventory Ledger Entries and updates Store-and-Variant balances through one owning service.  
·       Quantity-tracked accepted stock updates aggregate On Hand and cost.  
·       Individually tracked accepted stock creates or updates exact Inventory Units as required.  
·       Receipt-based acquisition cost becomes the normal inventory-cost source.  
·       Posted Receipts are immutable; corrections use explicit reversing or corrective records and Inventory Movements.  
·       Existing Phase 3 adjustment workflows remain available for opening balances and exceptional corrections, not ordinary receiving.

# **10\. Customer supply coverage**

## **10.1 Purchase-Order Allocations**

A Purchase-Order Allocation exists only for a Customer Request. It commits part of one open Purchase-Order Line to that request. It does not increase On Hand, Reserved, or inventory value. It reduces the open incoming quantity available to other Customer Requests.

The governing quantity is the allocation’s unresolved future-supply quantity:

| remaining allocation quantity \= allocated quantity − quantity converted to Inventory Reservations − released quantity |
| :---- |

   
Quantity resolution should be auditable through append-only allocation events or an equivalent immutable structure. The baseline event types are \`converted\_to\_reservation\` and \`released\`. Release reasons include PO cancellation, line cancellation, vendor unavailability, accepted-but-unavailable merchandise, request cancellation or reduction, earlier supply, reallocation, and authorized manual release.

Allocation lifecycle labels such as active, partially resolved, converted, released, or resolved mixed are derived from quantities and events. \`received\` and \`fulfilled\` are not persisted allocation statuses.

## **10.2 Physical Inventory Reservations**

An Inventory Reservation represents physically present merchandise committed to an incomplete workflow. For in-house stock, a staff member must physically locate and confirm the merchandise before the reservation is created. Quantity-tracked merchandise reserves quantity; individually tracked merchandise reserves the exact Inventory Unit.

When an accepted available Receipt quantity is associated with an active Customer Request allocation, receipt posting atomically:

1\.  posts the accepted Inventory Movement;

2\.  creates the physical inventory state;

3\.  creates the Inventory Reservation;

4\.  records allocation conversion for the same quantity;

5\.  reduces remaining allocation quantity;

6\.  preserves request coverage without double counting.

If accepted merchandise is unavailable because of damage, inspection, or another status, it does not automatically become reserved. When it no longer represents usable expected supply, the associated allocation quantity is released and the Customer Request becomes uncovered again.

## **10.3 Earlier compatible supply**

A Customer Request must not remain tied to later supply when earlier compatible merchandise becomes available. Compatible requests are ranked by authorized priority, needed-by date, and creation time. When earlier merchandise is physically reserved, redundant future allocations are released so the later PO quantity can serve another request or general stock. Substitution of another Product, edition, format, condition, Variant, or exact unit requires explicit approval.

# **11\. Product Request fulfilment**

Final customer fulfilment is separate from both allocation and reservation. A Product Request Fulfilment fact records merchandise actually sold or delivered in satisfaction of the request. This supports partial fulfilment, several POS transactions, several reservations, corrections, and future non-POS delivery workflows.

A baseline fulfilment record should identify:

·       \`product\_request\_id\`;  
·       \`inventory\_reservation\_id\` where fulfilment consumed a reservation;  
·       \`pos\_line\_item\_id\` for the Phase 5 POS path;  
·       \`quantity\`;  
·       \`fulfilled\_at\`;  
·       \`fulfilled\_by\_user\_id\`;  
·       idempotency and reversal context.

POS completion for a reserved Customer Request item atomically converts or closes the Inventory Reservation, posts the sale movement, creates the Product Request Fulfilment, and evaluates whether the request is fully fulfilled. Completed POS lines remain immutable.

| fulfilled quantity \= sum of valid Product Request Fulfilments outstanding quantity \= requested quantity − fulfilled quantity uncovered quantity \= requested quantity − fulfilled quantity − active Inventory Reservation quantity − remaining Purchase-Order Allocation quantity |
| :---- |

   
Coverage states such as physically reserved, allocated on order, partially covered, fully covered, and partially fulfilled are derived projections. A Customer Request may remain open while partially fulfilled and becomes fulfilled when valid fulfilment quantity reaches the requested quantity.

# **12\. Negative inventory and receipt settlement**

## **12.1 Design objective**

ShelfStack permits quantity-tracked merchandise to be sold into negative On Hand with a warning. Completed POS lines retain their provisional unit and extended cost snapshots. When merchandise later arrives, the system must settle the physical deficit without rewriting completed sales and without creating a positive inventory asset for units that merely bring On Hand back to zero.

The baseline uses an aggregate Store-and-Variant deficit model rather than matching each receipt to individual historical sales. This keeps the process maintainable while preserving the required quantity, valuation, and variance distinctions.

## **12.2 Aggregate deficit state**

| open deficit quantity \= max(−on\_hand, 0\) |
| :---- |

   
When On Hand is negative, the Stock Balance additionally retains an aggregate memorandum balance such as \`open\_deficit\_provisional\_cost\_cents\` and a cost-quality indicator. This amount represents provisional cost already associated with the outstanding negative quantity. It is not inventory asset value.

When an outbound movement takes On Hand below zero or farther below zero, only the quantity that increases the deficit contributes to the pool:

| deficit quantity created \= max(−resulting on\_hand, 0\) − max(−prior on\_hand, 0\) |
| :---- |

   
The provisional cost attributable to that quantity is added to the aggregate deficit-cost pool. Unknown cost remains unknown and is never treated as zero.

## **12.3 Receipt posting across a deficit**

Accepted Receipt quantity settles the deficit before creating positive inventory:

| deficit settlement quantity \= min(accepted receipt quantity, max(−prior on\_hand, 0)) positive inventory quantity \= accepted receipt quantity − deficit settlement quantity |
| :---- |

   
One Receipt Line may therefore create up to two Inventory Ledger Entries that share the same posting group and Receipt Line reference:

| Ledger role | Quantity effect | Value effect |
| :---- | :---- | :---- |
| Receipt deficit settlement | Moves On Hand toward zero by the settlement quantity. | Creates no positive inventory asset; releases provisional deficit cost and records settlement variance or late cost recognition. |
| Receipt positive inventory | Posts only the accepted quantity remaining after On Hand reaches zero. | Creates positive inventory asset value and participates in moving weighted average. |

   
The entry quantities must sum to accepted Receipt quantity. The second entry is not an additional receipt and does not “reverse” a historical sale. It is the positive-inventory portion of the same receipt posting after the deficit has been settled.

## **12.4 Example**

| Before receipt   on\_hand:                     	−3   inventory asset value:       	$0   open provisional deficit cost:  $18 Accepted receipt   quantity:                     	5   actual unit cost:            	$7   total cost:                 	$35 Ledger effect 1 — deficit settlement   quantity delta:              	\+3   inventory value delta:       	$0   actual settlement cost:     	$21   provisional cost released:  	$18   unfavorable variance:        	$3 Ledger effect 2 — positive inventory   quantity delta:              	\+2   inventory value delta:      	$14 Result   on\_hand:                      	2   inventory asset value:      	$14   moving average unit cost:    	$7 |
| :---- |

 

## **12.5 Partial settlement and rounding**

When incoming quantity settles only part of the deficit, provisional deficit cost is released proportionally:

| provisional cost released \= round(open provisional deficit cost     	× settlement quantity     	÷ deficit quantity before settlement) |
| :---- |

   
When the deficit is fully settled, the entire remaining provisional pool is released so no residual cents remain.

## **12.6 Cost variance and unknown cost**

| settlement variance \= actual settlement cost − provisional cost released |
| :---- |

   
A positive variance is unfavorable; a negative variance is favorable. The variance is a separate non-quantity cost fact associated with the deficit-settlement entry. It does not change the original completed POS cost snapshot.

·       **Unknown provisional cost:** known incoming settlement cost is classified as late cost recognition rather than a variance from zero.  
·       **Unknown incoming cost:** quantity may settle the physical deficit, but monetary effect remains unresolved until a later append-only cost correction or settlement adjustment.  
·       **Confirmed zero cost:** remains distinct from unknown and can produce a valid calculated variance.

## **12.7 Returns, adjustments, and corrections**

A linked return or post-void that moves On Hand toward zero uses its original completed cost, reduces the aggregate deficit pool accordingly, and does not create ordinary acquisition-cost variance. A quantity-only correction may reduce deficit quantity without inventing acquisition cost; the treatment of the memorandum pool must remain explicit and auditable.

Posted Receipt and deficit-settlement entries are immutable. Corrections create reversing Inventory Ledger Entries that restore quantity, positive inventory value, open provisional deficit cost, and associated variance or late cost recognition. Posting is atomic and idempotent and must lock or otherwise protect the Store-and-Variant Stock Balance.

# **13\. Principal records and responsibilities**

| Record | Responsibility |
| :---- | :---- |
| vendors | Supplier identity and organization-level purchasing context. |
| product\_variant\_vendors | Variant-specific vendor source, codes, expected-cost basis, packs, multiples, and source defaults. |
| purchase\_orders | Store/Vendor commercial intent, PO number, status, placement context, currency, and lifecycle. |
| purchase\_order\_lines | Exact Variant, ordered and cancelled quantities, snapshots, expected-cost method and provenance. |
| receipts | One physical receiving event, potentially spanning several POs. |
| receipt\_lines | Delivered, accepted, rejected, available, and unavailable quantities; optional one PO-line reference. |
| product\_requests | Product-backed Customer Requests and non-customer buyer-decision records, including resolution details. |
| purchase\_order\_allocations | Original expected quantity committed from a PO line to a Customer Request. |
| purchase\_order\_allocation\_events | Append-only conversion and release of allocated future supply. |
| inventory\_reservations | Existing physical quantity or exact units committed to open workflows. |
| product\_request\_fulfillments | Final quantity sold or delivered in satisfaction of a Customer Request. |
| inventory\_ledger\_entries | Append-only physical quantity events, including receipt deficit-settlement and positive-inventory roles. |
| stock\_balances | Authoritative Store-and-Variant quantities, inventory value, moving average, and aggregate deficit memorandum state. |

 

# **14\. End-to-end workflows**

## **14.1 Non-customer demand to general stock**

| Product identified → Staff Suggestion / Stock Replenishment / Frontlist Selection → buyer review → buyer chooses Vendor, Variant, and quantity → request closes with buyer resolution → PO line is created or updated → PO is placed → merchandise is received → accepted merchandise becomes general stock |
| :---- |

   
No continuing allocation ties the received merchandise to the originating non-customer request.

## **14.2 Customer Request using in-house stock**

| Customer Request → ShelfStack identifies potentially available stock → staff physically locates merchandise → Inventory Reservation → POS sale or delivery → Product Request Fulfilment → request closes when fulfilled |
| :---- |

 

## **14.3 Customer Request using expected supply**

| Customer Request → compatible open PO quantity identified → Purchase-Order Allocation → Receipt posts accepted available quantity → allocation converts to Inventory Reservation → POS sale or delivery → Product Request Fulfilment → request closes when fulfilled |
| :---- |

 

## **14.4 PO cancellation affecting a Customer Request**

| PO quantity cancelled or Vendor unavailable → affected allocation quantity released or reassigned atomically → Customer Request remains open → uncovered quantity returns to buyer review |
| :---- |

   
A closed non-customer request does not automatically reopen when its resulting PO line is cancelled. A buyer may create a replacement request or return the Product to buyer review explicitly.

## **14.5 Receipt crossing negative On Hand**

| Receipt accepted → determine prior negative On Hand → post receipt-deficit-settlement quantity toward zero → release proportional deficit memorandum cost → record cost variance or late recognition → post remaining quantity as positive inventory → update inventory value and moving average |
| :---- |

 

# **15\. Authorization, concurrency, and audit**

Phase 5 actions must follow ShelfStack’s canonical permission grammar and Store context. The exact catalog entries should be finalized before seeding, but the baseline must distinguish authority to:

·       create and manage Product Requests;  
·       resolve non-customer requests;  
·       allocate expected supply to Customer Requests;  
·       physically confirm and reserve inventory;  
·       create and edit draft POs;  
·       place, cancel, and close POs or line quantities;  
·       receive and post shipments;  
·       authorize over-receipt and unlinked receipt lines;  
·       correct posted receiving and inventory events.

The following operations require atomic, idempotent services with appropriate locking or equivalent concurrency control:

·       PO placement and derived On Order activation;  
·       PO quantity cancellation when allocations exist;  
·       Receipt posting and balance updates;  
·       allocation conversion and Inventory Reservation creation;  
·       allocation release and re-sourcing;  
·       POS completion and Product Request Fulfilment;  
·       negative-inventory deficit settlement and inventory-value updates;  
·       reversal or correction of posted events.

# **16\. Recommended implementation sequence**

1\.  Reconcile the governing ADRs, Domain Specifications, schema exports, open-decision register, and permission catalog to the consolidated baseline.

2\.  Implement Vendors and Product Variant Vendor sources, including expected-cost method and provenance.

3\.  Implement Purchase Orders and Lines, numbering, draft editing, placement, snapshots, cancelled quantities, commercial statuses, and derived On Order.

4\.  Implement Receipts and Receipt Lines, multi-PO shipments, quantity dimensions, discrepancy handling, and atomic posting.

5\.  Implement receipt-based positive inventory cost and aggregate negative-inventory deficit settlement.

6\.  Implement product-backed Product Requests and the fast local/external Product creation return path.

7\.  Implement non-customer resolution and the buyer-review queue.

8\.  Implement Customer Request Purchase-Order Allocations and quantity-resolution events.

9\.  Implement physical confirmation, Inventory Reservations, receipt-to-reservation conversion, and allocation release.

10\. Implement Product Request Fulfilment through Phase 4 POS completion.

11\. Add reconciliation reports, concurrency tests, authorization tests, idempotency tests, and browser coverage for the complete workflow.

# **17\. Phase 5 exit criteria**

☐  Staff can search, import, or create a Product and return directly to demand entry.

☐  Every Product Request references an existing Product; the exact Variant is resolved before PO entry.

☐  All four initial request types enter buyer review with correct customer-obligation semantics.

☐  Non-customer requests close with an auditable buyer resolution and do not retain supply allocations.

☐  Customer Requests derive fulfilled, reserved, allocated, and uncovered quantities without double counting.

☐  Buyers can select Vendor Sources and create or update draft POs from buyer-review work.

☐  PO Lines support discount-from-list and direct-net expected cost with provenance and snapshots.

☐  PO numbering, placement, cancellation, closing, and no-reopen rules operate consistently.

☐  Derived On Order reconciles to ordered, accepted, and cancelled line quantities.

☐  One Receipt can contain lines from several POs; each line references at most one PO line.

☐  Delivered, accepted, rejected, available, and unavailable quantities reconcile correctly.

☐  Only accepted quantity increases On Hand; over-receipt and unlinked receipt lines require explicit authorization.

☐  Receipt posting is atomic, idempotent, immutable after posting, and correctable through reversing facts.

☐  Receipt quantity crossing negative On Hand is split correctly between deficit settlement and positive inventory.

☐  Negative On Hand carries no positive inventory asset and the aggregate deficit memorandum pool reconciles.

☐  A Customer Request can allocate PO quantity and reserve physically confirmed stock.

☐  Receipt posting converts applicable allocations into Inventory Reservations without double counting.

☐  Earlier compatible supply can release redundant future allocations.

☐  POS completion can create Product Request Fulfilment and close a fully fulfilled request.

☐  Existing Phase 4 POS sale paths continue to work with received general stock.

# **18\. Remaining implementation details**

The architectural baseline is sufficiently defined to reconcile documentation and begin schema design. The following are implementation choices rather than reasons to reopen the domain boundaries:

·       Whether non-customer resolution is stored directly on Product Requests or in a separate request-resolution event table.  
·       The exact schema for allocation events, including whether aggregate converted and released counters are cached on the allocation.  
·       The generalization path for fulfilment sources beyond POS Line Items.  
·       The exact representation of later monetary correction when a Receipt posts with unknown cost.  
·       Specific permission keys and numeric authority thresholds for placement, cancellation, over-receipt, and corrections.  
·       Service names, event names, UI layouts, and reporting presentation.  
·       Whether a lightweight non-authoritative navigation hint from a resolved non-customer request to the ordering session provides enough value to justify storage.

| Boundary reminder These details may refine schema and workflow mechanics, but they must not collapse Product Requests into POs, expected allocations into physical reservations, reservations into final fulfilment, or negative-inventory settlement into edits of completed POS history. |
| :---- |

 

# **19\. Documentation reconciliation**

Before Phase 5 implementation is considered governed, the following repository documents should be updated consistently:

·       Supersede ADR-0005 with the revised product-backed demand and customer-only supply-allocation decision.  
·       Update the Product Requests Domain with four request types, non-customer resolution, fulfilled quantity, and revised uncovered quantity.  
·       Update Vendors and Purchasing with the PO commercial lifecycle, placement boundary, line cancellation, expected-cost provenance, and customer-only allocations.  
·       Update Receiving and Inventory with quantity reconciliation, allocation-to-reservation conversion, and aggregate negative-inventory settlement.  
·       Update the Phase 5 plan and lifecycle-boundary document to remove the deferred allocation-status question and add deficit settlement and Product Request Fulfilment to the build and exit gates.  
·       Update schema exports so Product Requests require Product identity, support all four request types, and include the new supporting records and fields.  
·       Add canonical Phase 5 permissions before seeds or authorization checks are implemented.

# **20\. Source documents consolidated**

·       \`docs/implementation/phases/phase-05-supply-and-demand.md\`  
·       \`docs/domains/ordering-and-acquisition-planning.md\`  
·       \`docs/domains/product-requests.md\`  
·       \`docs/domains/vendors-and-purchasing.md\`  
·       \`docs/domains/receiving-and-inventory.md\`  
·       \`docs/implementation/phase-05-ordering-scope-and-future-lifecycle-boundaries.md\`  
·       \`docs/implementation/architectural-locks.md\`  
·       \`docs/implementation/deferred-capabilities.md\`  
·       \`docs/implementation/open-decisions.md\`  
·       \`docs/adr/0005-demand-allocations-and-reservations.md\`  
·       \`docs/adr/0007-purchasing-receiving-and-inventory-events.md\`  
·       \`docs/adr/0013-govern-quantity-tracked-inventory-cost.md\`
