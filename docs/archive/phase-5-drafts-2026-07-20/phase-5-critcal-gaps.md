# Critical gaps

## 1\. ADR-0005 now conflicts with the revised design

ADR-0005 still says the initial request types are only:

```
customer_request
staff_suggestion
```

It does not include `stock_replenishment` or `frontlist_selection`, and its wording says a request “may identify” a product rather than requiring one.

The revised Product Requests domain now requires a product and defines four initial types.

This matters because the documented authority order places accepted ADRs above Domain Specifications and implementation documents.

**Recommendation:** amend ADR-0005 or create a superseding ADR that records:

* every acquisition-demand record requires `product_id`;  
* `product_variant_id` may be unresolved;  
* the four initial request types;  
* the buyer-review queue remains a projection;  
* how PO supply covers non-customer demand.

This was a significant enough decision that it should not live only in phase planning documents.

## 2\. Non-customer demand has no quantity-level link to a PO

This is the largest model gap.

The documents say:

* stock replenishment, staff suggestions, and frontlist selections are Product Requests;  
* they enter buyer review;  
* buyers can create POs from selected demand;  
* several demand records can contribute to one consolidated PO line;  
* those contributing records must remain traceable.

But the only proposed relationship between demand and a PO line is `purchase_order_allocations`, which is consistently defined as committing supply to a **customer request**.

That leaves unanswered:

* How does a stock-replenishment request stop appearing in buyer review after it is ordered?  
* How is a partially ordered staff suggestion represented?  
* How can one frontlist quantity be split across vendors?  
* How do we trace why a PO line was ordered?  
* How is remaining non-customer demand calculated?

### Recommended resolution

Generalize `purchase_order_allocations` to mean:

Expected PO-line supply assigned to a Product Request.

Then request type controls the business effect:

| Request type | Meaning of allocation after receipt |
| :---- | :---- |
| `customer_request` | Supply is committed to the customer and normally becomes a physical reservation |
| `staff_suggestion` | Suggested quantity is covered; received stock remains general inventory |
| `stock_replenishment` | Replenishment need is covered; received stock remains general inventory |
| `frontlist_selection` | Frontlist buying quantity is covered; received stock remains general inventory |

This preserves one demand-coverage model and avoids adding a parallel PO-to-demand link table.

The alternative is a second table such as `purchase_order_line_demand_sources`, but that risks recreating the duplicated demand systems ADR-0005 was intended to prevent.

## 3\. OD-007 cannot remain undecided through receipt implementation

OD-007 still leaves allocation `received` and `fulfilled` behavior open.

The Product Requests domain says receipt posting will decide whether these become statuses, derived states, or separate events. It also requires redundant future allocations to be reduced when earlier supply fulfils the request.

A two-status model of only `active` and `cancelled` cannot cleanly handle:

* partial receipts;  
* partial conversion to physical reservations;  
* one allocation fulfilled by several receipt lines;  
* earlier general stock fulfilling a request;  
* reallocation to replacement supply;  
* distinguishing cancellation from successful conversion.

Using `cancelled` for successful receipt conversion would give cancellation the wrong meaning.

**Recommendation:** close OD-007 before implementing receipt-to-request posting. The cleanest future-compatible model is a quantity-bearing conversion or coverage fact, for example:

```
purchase_order_allocation_coverage_events
- purchase_order_allocation_id
- receipt_line_id
- inventory_reservation_id
- quantity
- event_type       # received, converted, released, fulfilled
- occurred_at
- user_id
- reason
```

A simpler implementation can split allocation records as quantities convert, but the system still needs to preserve partial history.

## 4\. Negative-inventory receipt settlement is missing from the Phase 5 plan

Phase 4 deliberately allowed negative quantity sales while deferring receipt settlement and monetary variance representation to Phase 5\. The open-decision document explicitly says incoming Receipt settlement is Phase 5 work.

The Receiving and Inventory domain also states that incoming quantity settles a deficit before creating positive inventory, while leaving the exact variance representation under OD-014.

However, the revised Phase 5 plan does not list OD-014 settlement as a build item or exit criterion. It currently promises receipt-based costing without specifying how a receipt behaves when current `on_hand` is negative.

**Recommendation:** add an explicit Phase 5 gate:

Close OD-014 before receipt posting is considered complete for quantity-tracked variants with negative on-hand balances.

Add an exit criterion such as:

```
Receipt into a negative quantity balance:
- settles deficit quantity before creating positive stock;
- records the settling acquisition cost;
- records any monetary variance explicitly;
- does not rewrite completed POS cost snapshots;
- remains idempotent and reconcilable.
```

This does not necessarily mean building a large settlement subsystem before all other Phase 5 work. It does mean receipt posting cannot be considered finished while its behavior for an already-supported inventory state remains undefined.

## 5\. The proforma schema is still materially stale

The schema-reconciliation note correctly states that Phase 5 requires `product_id` and removes unresolved `requested_description`.

But the actual exported Schema Dictionary still says:

* request types are only `customer_request` and `staff_suggestion`;  
* `product_id` is nullable;  
* `requested_description` is required when product is unresolved;  
* the PO status set includes `submitted` and `received`;  
* allocation receipt behavior is deferred to “Phase 4”;  
* PO lines lack a cost-entry method and cost provenance.

The exports are non-authoritative when they conflict with domain documents, but they are explicitly used for architecture review and Rails implementation planning.

**Recommendation:** update the Schema Dictionary, Table Summary, Revision Notes, and Open Decisions exports before scaffolding Phase 5\.

At minimum:

```
product_requests.product_id           null: false
product_requests.request_type         four initial values
requested_description                 removed

purchase_order_lines.cost_entry_method
purchase_order_lines.cost_provenance
purchase_order_lines.expected_list_price_cents
purchase_order_lines.discount_bps
purchase_order_lines.expected_unit_cost_cents
```

The final field names can differ, but the export should no longer advertise the superseded model.

## 6\. `vendors-and-purchasing.md` has not absorbed the new contract

Only one line was changed: the expected-cost open question now points to the new planning document. The domain itself still:

* lists no `cost_entry_method`;  
* lists no cost provenance;  
* does not define direct-net versus discount-from-list behavior;  
* does not describe bulk discount editing;  
* does not define vendor minimum warnings;  
* does not lock vendor identity after placement;  
* does not describe manual re-sourcing;  
* still says “Receipt posting in Phase 4” will decide allocation behavior;  
* leaves the PO status model open.

Because this is a Domain Specification, it outranks the Phase 5 implementation documents.

**Recommendation:** revise the domain document itself rather than leaving the new decisions only in `ordering-and-acquisition-planning.md`.

It should add:

* expected-cost methods and authoritative input behavior;  
* cost snapshot fields;  
* bulk discount workflow;  
* vendor minimum and order-multiple behavior;  
* placed-line immutability;  
* manual cascade/re-source behavior;  
* generalized Product Request allocation, if accepted;  
* Phase 5 rather than Phase 4 receipt wording;  
* explicit baseline PO statuses.

## 7\. Request fulfilment through POS is not actually modeled

The Phase 5 header says the phase unlocks customer-request fulfilment through POS.

The Product Requests domain says final sale or delivery fulfils the request, but still asks whether a POS transaction is required.

No proposed principal table or relationship connects:

* a Product Request;  
* the inventory reservation;  
* the fulfilling POS line;  
* the fulfilled quantity.

This becomes important for:

* partial fulfilment;  
* multiple units sold in separate transactions;  
* one request covered by several receipts;  
* cancellation after partial sale;  
* proving that a reservation was converted into customer fulfilment.

**Recommendation:** decide whether Phase 5 includes actual request completion through POS or only supply coverage.

Given the stated goal, I would include a fulfillment fact such as:

```
product_request_fulfillments
- product_request_id
- pos_line_item_id
- inventory_reservation_id
- quantity
- fulfilled_at
- fulfilled_by_user_id
```

This also leaves room for a future non-POS delivery fulfillment without overloading the request status.

## 8\. Canonical Phase 5 permissions are missing

The lifecycle-boundary document proposes permission keys, but:

* it omits creation permissions for stock replenishment and frontlist selection;  
* its names do not consistently use the project’s canonical `<domain>.<resource>.<action>` grammar.

The canonical permission catalog says code and seeds must match that catalog and explicitly states that Phase 5 keys must be added there before seeding.

At minimum, Phase 5 needs canonical rows covering:

* vendor and vendor-source viewing/management;  
* PO viewing, creation, editing, placement, cancellation, and closure;  
* cost viewing and editing;  
* allocation creation and release;  
* each initial request type;  
* buyer assignment;  
* request-priority override;  
* in-house reservation;  
* receipt creation and posting;  
* product import/creation through the demand workflow.

# Important scope clarifications

## Single-variant baseline

Phase 2 explicitly implemented only `variant_structure = single`; option and matrix products remain out of scope.

The new planning document discusses several possible variants satisfying one request and later variant resolution.

This is not necessarily wrong, but Phase 5 should state explicitly:

Phase 5 does not remove the current single-standard-variant implementation constraint. Nullable request variant identity is retained for semantic correctness and future compatibility. Quick product creation creates the standard variant under the current catalog baseline.

Otherwise an implementer could reasonably interpret Phase 5 as requiring option/matrix product support.

## Receiving quantity rules

The Receiving domain still leaves several material decisions open, while permitting an optional PO-line link.

Before implementing receipt posting, define:

```
delivered_quantity = accepted_quantity + rejected_quantity

accepted_quantity
= accepted_available_quantity
+ accepted_unavailable_quantity
```

Also decide:

* whether receipt lines without PO lines are allowed;  
* whether over-receipt is allowed, warned, or blocked;  
* whether `on_order` is floored at zero after over-receipt;  
* whether accepted damaged/inspection quantities are subsets of accepted quantity;  
* how cost applies to accepted unavailable stock;  
* whether a PO cancellation may reduce open quantity below active allocations;  
* whether ordered quantity becomes immutable after placement;  
* what receipt-level idempotency key prevents duplicate posting.

## PO baseline decisions

The purchasing domain still lists these as open:

* final PO statuses;  
* internal submission versus vendor placement;  
* store-specific versus organization-wide order numbers;  
* vendor-term scope;  
* reopening behavior.

They need not become elaborate workflows. A suitable Phase 5 baseline could simply lock:

```
commercial statuses:
draft
ordered
closed
cancelled

PO numbers:
store-scoped sequence

submission/approval:
deferred

reopening:
not supported in Phase 5

vendor terms:
organization-wide vendor defaults
+ variant-vendor overrides
+ PO-line snapshots
```

# Internal document inconsistencies

The new lifecycle-boundary document itself still lists only `customer_request` and `staff_suggestion` under Phase 5 requirements, even though the phase plan and Product Requests domain define four initial types. Its permission list also omits the other two creation capabilities.

There is also substantial duplication among:

* `ordering-and-acquisition-planning.md`;  
* `phase-05-ordering-scope-and-future-lifecycle-boundaries.md`;  
* `phase-05-supply-and-demand.md`;  
* `product-requests.md`;  
* `vendors-and-purchasing.md`.

That duplication has already produced drift.

I would sharpen their roles:

| Document | Should own |
| :---- | :---- |
| Ordering and Acquisition Planning | Business workflows and user-facing operational behavior |
| Product Requests | Demand fields, lifecycle, coverage invariants |
| Vendors and Purchasing | Vendor, PO, allocation, cost fields and invariants |
| Receiving and Inventory | Receipt posting, reservation conversion, cost and inventory effects |
| Phase 5 Lifecycle Boundaries | Compact in-scope/deferred matrix only |
| Phase 5 Plan | Build order, gates, services, screens, tests, exit criteria |

The Markdown heading levels in both large new documents also use headings such as `## 4.1` beneath `## 4`; these should be `### 4.1`. This is editorial rather than architectural, but it will improve generated navigation.

# Recommended revised build order

The current build order places receipt posting before Product Requests and allocations.  That risks designing receipt posting before OD-007, FIFO conversion, and demand coverage are settled.

A safer order is:

1. **Phase 5 decision/schema reconciliation**  
     
   - [x] ~~amend ADR-0005;~~  
   - [x] ~~close baseline PO decisions;~~  
   - [x] ~~decide generalized demand allocation;~~  
   - [x] ~~close OD-007;~~  
   - [x] ~~close the required portion of OD-014;~~  
   - [ ] update proforma and permission catalog.

   

2. **Vendors and vendor sources**  
3. **Purchase orders and expected cost**  
4. **Product-backed requests and buyer-review projection**  
5. **PO allocations and in-house reservations**  
6. **Receipt posting**  
   - [ ] multi-PO;  
   - [ ] partial receipts;  
   - [ ] allocation conversion;  
   - [ ] negative-deficit settlement;  
   - [ ] inventory cost;  
   - [ ] exact units.  
7. **Request fulfilment through POS**  
8. **Replenishment/frontlist UX and Phase 5 hardening**

## Conclusion

The revised documents capture the correct operating model. The remaining work is primarily reconciliation rather than a conceptual rewrite.

The items that should block migrations are:

1. ADR-0005 reconciliation.  
2. A quantity-level PO relationship for all four demand types.  
3. OD-007 allocation conversion.  
4. OD-014 receipt settlement.  
5. Request-to-POS fulfilment representation.  
6. Updated purchasing domain, schema export, and permission catalog.  
7. Baseline receipt and PO invariants.

Once those are resolved, the Phase 5 plan will be coherent from business workflow through schema, permissions, posting services, and acceptance tests.

---

Yes. I think that is the cleaner model.

My earlier recommendation to generalize `purchase_order_allocations` across all demand types would overstate the meaning of non-customer demand. **Only a customer request creates an obligation that must remain attached to expected supply.**

## Recommended distinction

### Customer request

A customer request remains open until the customer obligation is fulfilled, declined, cancelled, or otherwise closed.

When future supply is committed to it, persist:

```
customer_request
↔ purchase_order_allocation
↔ purchase_order_line
```

That relationship is necessary because ShelfStack must know:

* which incoming quantity is committed;  
* whether the request is fully or partially covered;  
* whether the supply was cancelled or replaced;  
* whether earlier stock makes the allocation redundant;  
* which received merchandise should be reserved for the customer.

### Staff suggestion, replenishment, and frontlist selection

These records exist to prompt a **buyer decision**.

Once the buyer decides to order merchandise, their purpose has been satisfied. The purchased quantity does not remain committed to the original request; it becomes general expected supply and, after receipt, general stock.

The lifecycle can therefore be:

```
staff suggestion / replenishment / frontlist selection
→ buyer review
→ buyer orders chosen quantity
→ request closes as ordered
```

No `purchase_order_allocation` is required.

## Why this is preferable

It preserves a useful semantic distinction:

```
Customer request
= ongoing fulfilment obligation

Non-customer request
= proposal requiring a buyer decision
```

Persisting quantity allocations for non-customer demand would create unnecessary questions:

* Does stock received for a staff suggestion remain committed to that suggestion?  
* Does a replenishment request need fulfilment status after receipt?  
* Must allocations be moved if the PO is replaced?  
* Does a frontlist selection remain open until every copy arrives?

The answer to each is generally no. Once the buyer has made the purchasing decision, the suggestion has done its job.

## Closing information

I would still preserve the outcome on the non-customer request itself.

Suggested attributes include:

```
status
closed_at
closed_by_user_id
resolution_code
resolved_quantity
resolution_note
```

Suggested resolution codes:

```
ordered
declined
deferred
duplicate
superseded
no_longer_needed
```

For example:

```
request_type: stock_replenishment
requested_quantity: 8
status: closed
resolution_code: ordered
resolved_quantity: 6
resolution_note: Buyer ordered 6 based on current on-order stock.
```

This records what the buyer decided without turning the request into a supply-tracking record.

## Partial ordering

The buyer should have two explicit choices:

### Resolve with the chosen quantity

The suggested quantity is advisory. The buyer orders a different quantity and closes the request:

```
suggested: 10
ordered: 6
resolution: ordered
request closed
```

There is no residual demand because the buyer’s decision supersedes the suggestion.

### Keep a remainder under review

When the buyer intentionally wants the remaining quantity reconsidered:

```
suggested: 10
ordered now: 6
remaining in buyer review: 4
```

This could be implemented by:

* reducing the open request to four; or  
* closing the original request and creating a new four-unit request.

I prefer the second approach when an order has actually been placed. It preserves a clear decision history:

```
Original request: 10
→ closed, ordered 6

Follow-up request: 4
→ still open for later review
```

## If the PO is later cancelled or unavailable

For non-customer demand, the request should not automatically remain attached to the PO.

Instead, the buyer can choose:

```
Return to buyer review
```

That action may reopen the original request or create a new request referencing the previous decision in its audit history.

For customer demand, the behavior is different:

* the customer request remains open;  
* the cancelled allocation is released;  
* the uncovered quantity returns to buyer review automatically.

That difference is precisely why customer requests require persistent allocations and the other request types do not.

## Revised governing rule

I would use this wording:

Purchase-order allocations are created only for customer requests. Staff suggestions, stock-replenishment requests, and frontlist selections are buyer-decision records. When a buyer orders merchandise in response to one of these records, the request is normally closed with an `ordered` resolution and the quantity chosen by the buyer. The resulting purchase-order quantity is general expected supply and is not committed to the originating request.

And revise the coverage formula so it applies specifically to customer requests:

```
customer-request unfulfilled quantity
=
requested quantity
− active confirmed inventory reservations
− active purchase-order allocations
```

For non-customer demand, the buyer-review state is simpler:

```
open request
= awaiting buyer decision

closed with ordered resolution
= buyer acted; no continuing supply commitment
```

This removes the supposed need for a generalized demand-to-PO relationship. An optional audit correlation may be useful for navigation, but it should not behave as an allocation or control supply quantities.  