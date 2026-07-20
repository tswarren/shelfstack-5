# Receiving and Inventory Domain

**Status:** Consolidated specification with open correction, count, transfer, and RTV details  
**Domain owner:** Vendor shipment acceptance, physical Store inventory, availability, exact Units, Reservations, movements, and cost

## Governing ADRs

- [ADR-0001: Separate Product, Product Variant, and Inventory Unit](../adr/0001-product-variant-inventory-unit.md)
- [ADR-0002: Use Canonical Identifiers and Separate Restricted-Circulation Namespaces](../adr/0002-canonical-identifiers-and-namespaces.md)
- [ADR-0004: Treat the Store as the Authoritative Inventory Boundary](../adr/0004-store-level-inventory-boundary.md)
- [ADR-0015: Require Product-Backed Demand and Reserve Supply Allocations for Customer Commitments](../adr/0015-product-backed-demand-and-customer-supply-commitments.md)
- [OD-007 allocation receipt and fulfilment](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md)
- [OD-014 negative-inventory settlement](../implementation/decisions/od-014-negative-inventory-settlement.md)
- [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](../adr/0006-inventory-quantities-and-reservation-records.md)
- [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](../adr/0007-purchasing-receiving-and-inventory-events.md)
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)

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

It holds current quantity, availability, and current quantity-tracked valuation state.

Suggested attributes:

- Store;
- Product Variant;
- On Hand;
- Reserved;
- Unavailable;
- optional cached Available;
- aggregate inventory value;
- cached moving weighted-average cost;
- cost quality;
- optional last-known unit cost and quality;
- concurrency / lock version;
- last received timestamp.

```text
available = on_hand - reserved - unavailable
```

Authority:

```text
Posted Inventory Movements / Inventory Ledger Entries
→ authoritative history

Stock Balance
→ authoritative current operational state
→ reconcilable from history
```

Aggregate positive inventory value governs current valuation calculations. A cached moving-average unit cost may exist for display and convenience; proportional allocations use aggregate value and positive On Hand.

### State at zero

When On Hand is zero:

```text
inventory value = 0
moving-average cost = null
current cost quality = unknown
```

Any retained historical rate and quality belong in separate last-known fields, not in current cost quality.

Zero or negative quantity does not create a negative inventory asset. When On Hand is negative, positive inventory asset value remains zero.

When On Hand is positive and cost is unknown, complete valuation is unknown. Later known-cost inventory must not silently assign cost to unresolved unknown-cost quantity. An explicit cost correction may establish complete valuation.

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

Only posted Inventory Movements change On Hand.

An Inventory Ledger Entry is the persisted record of a posted Inventory Movement. Posted entries form an append-only inventory ledger.

Suggested movement types:

```text
opening_inventory
quantity_adjustment
cost_correction
receipt
sale
customer_return
post_void
transfer_out
transfer_in
rtv_shipment
discard
correction
```

Listing a type does not establish that workflow’s lifecycle.

Each cost-bearing entry retains enough information to reproduce quantity change, inventory-value change, cost calculation approach, cost quality, source, reversal relationship, resulting balance state, User, time, and reason.

Movement extended cost may differ from the signed change to positive inventory asset value. Example: a sale into negative inventory may carry provisional COGS without creating a negative inventory asset.

When positive inventory valuation is unknown, the inventory-value delta is null (unknown), not zero. Reconciliation must replay ordered value-state transitions using resulting snapshots; it cannot always be implemented as a simple sum of value deltas.

Posting a movement and updating its Stock Balance occur atomically and must be idempotent. Inventory posting services exclusively own value-state changes; controllers and jobs must not edit Stock Balance valuation fields directly.

## Cost

Governed by [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md). Phase 3 field notes: [phase-03-inventory-cost-schema.md](../implementation/phase-03-inventory-cost-schema.md). Deficit allocation: [OD-014](../implementation/open-decisions.md#od-014-negative-inventory-deficit-allocation).

### Costing scope

| Tracking mode | Cost model |
| --- | --- |
| `quantity` | Store-and-Variant moving weighted average |
| `individual` | Exact Inventory-Unit acquisition cost |
| `none` | No stock effects |

Catalog owns tracking mode and regular price. Inventory owns posted cost and balances.

### Provenance

Distinguish calculation approach from evidentiary quality (`actual`, `estimated`, `mixed`, `unknown`). Confirmed zero cost is not missing cost. Unknown must never be treated as zero.

Missing cost normally produces a warning rather than blocking sale. Completed lines distinguish missing cost from confirmed zero cost.

### Cost-quality aggregation

When combining valued positive inventory:

| Existing | Incoming | Result |
| --- | --- | --- |
| actual | actual | actual |
| estimated | estimated | estimated |
| actual | estimated | mixed |
| estimated | actual | mixed |
| mixed | actual or estimated | mixed |
| any known quality | unknown | unknown |
| unknown | any cost-bearing addition | unknown until explicit complete correction |

Once a positive balance becomes `mixed`, it remains `mixed` until the balance reaches zero or an explicit cost correction establishes another complete basis.

### First positive quantity from zero

When existing On Hand is zero, incoming quantity is positive, and incoming cost is known:

```text
resulting inventory value = incoming quantity × incoming unit cost
resulting moving average = incoming unit cost
```

Resulting cost quality follows the incoming quality. When incoming cost is unknown, resulting positive inventory remains unknown-valued.

### Positive inbound / outbound

When On Hand is positive and valued:

```text
resulting quantity = existing quantity + incoming quantity
resulting inventory value = existing inventory value + incoming value
resulting moving average = resulting inventory value / resulting quantity
```

Outbound quantity that does not exceed positive On Hand receives a proportional share of aggregate inventory value (deterministic round-half-up). A movement that consumes the final positive quantity consumes any remaining valuation residual and leaves the zero-state defined under Stock Balance.

### High-level deficit behavior

When an outbound movement crosses below zero:

1. the positive portion consumes remaining positive inventory value;
2. the excess creates or increases a deficit;
3. the deficit may carry provisional cost when a defensible retained rate exists, else unknown;
4. positive inventory asset value becomes zero.

Incoming quantity settles deficit before creating positive inventory. Differences between provisional and settling cost become explicit variance facts that do not change On Hand, do not create inventory asset value, do not rewrite earlier completed activity, and report in the settlement period.

Phase 5 settlement uses an aggregate Store-and-Variant deficit-cost pool (not origin-matched sales). A Receipt Line may post a `receipt_deficit_settlement` movement then a positive `receipt` movement. Full rules: [OD-014](../implementation/decisions/od-014-negative-inventory-settlement.md).

### Department estimate

When no more authoritative cost is available, Inventory may offer an optional Department gross-margin estimate. Classification owns the margin field; Inventory owns calculation and posting.

```text
estimated_unit_cost_cents
=
round_half_up(
  regular_price_cents
  × (10,000 - margin_bps)
  / 10,000
)
```

Rules:

* `margin_bps` must be between `0` and `10_000`;
* Catalog regular selling price must be available;
* temporary discounts and promotions are not used;
* the user must explicitly select or confirm the estimate;
* price, margin, Department, and result are snapshotted;
* a calculated result of zero is estimated confirmed-zero cost, not unknown;
* missing margin or missing applicable regular price means the estimate is unavailable, not zero;
* the user may leave cost unknown;
* later Department or price changes do not recalculate posted estimates.

### Returns and post-voids

Linked returns restore original completed-line cost. Post-voids reverse original completed cost. Restored positive quantity participates in the current moving average. Unlinked returns without historical cost use explicit actual, confirmed estimate, or unknown.

### Variance facts

Cost differences that do not change physical quantity are distinct non-quantity facts (not overloaded quantity movements). Exact table shape is deferred under OD-014 until an operational producer exists.

### Rounding

Integer cents. Deterministic round-half-up for proportional allocation and rate-based estimates unless a later ADR specifies otherwise. Fully depleted positive balances and fully settled provisional deficits leave no unexplained residual.

## Inventory Adjustments

A posted Inventory Adjustment creates Ledger Entries.

Posted or cancelled Adjustments and their lines are immutable. Draft updates lock the header and recheck status before replacing lines. Corrections use new adjusting records.

Suggested structure:

- adjustment header with Store, adjustment kind, status, Classification Inventory Adjustment Reason, optional note, creator, poster, posting key, and timestamps;
- lines with Variant, optional Unit, quantity or status change, and kind-specific cost inputs (`input_*` / `corrected_inventory_value_cents`);
- posted headers snapshot reason code and name; ledger entries store structured `reason_code` and `reason_note`.


Initial quantity-tracked adjustment kinds:

```text
opening_inventory
quantity_only
cost_correction
```

`opening_inventory` may establish quantity with actual, estimated, or unknown cost without creating a Receipt. From zero with known cost, use the first-positive-from-zero rule.

### Quantity-only adjustments (Phase 3)

`quantity_only` must not impose an arbitrary replacement rate.

* From a positive valued balance: added quantity uses current moving-average rate; removed quantity receives an allocated share of aggregate value.
* When an adjustment crosses from positive into deficit: the positive portion consumes remaining aggregate value; excess creates a deficit with no positive asset value; full provisional deficit-cost reconciliation is deferred (OD-014).
* Quantity added from negative toward zero does not create inventory asset value and is not an acquisition-cost variance.
* If quantity crosses from negative/zero into positive surplus: Phase 3 treats the positive surplus as unknown-cost inventory unless an implemented retained-cost policy supplies a rate. Do not invent a Department estimate automatically.

### Cost corrections (Phase 3)

```text
cost corrections require on_hand > 0
quantity_delta = 0
```

A positive-balance cost correction may establish previously unknown complete valuation, replace estimated with actual, or correct erroneous aggregate value. Corrections require `inventory.cost_correction.post`, an audit reason, and full audit. They do not rewrite earlier movements or completed POS lines.

Corrections to provisional deficit state remain deferred with OD-014.

Direct unexplained edits to On Hand or valuation are prohibited.

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

Canonical keys live in [authorization-permissions.md](authorization-permissions.md). Phase 3 inventory keys include:

```text
inventory.stock.view
inventory.cost.view
inventory.adjustment.create
inventory.adjustment.post
inventory.cost_correction.post
inventory.reservation.view
inventory.reservation.release
```

Later phases add receipt, unit, transfer, RTV, and count permissions when designed.

## Audit requirements

Audit Receipt posting and corrections, accepted and rejected quantities, cost approach and quality, estimate inputs, missing versus confirmed-zero cost, aggregate inventory-value changes, Inventory Movements, Reservation lifecycle, Unit creation and status changes, manual Adjustments, cost corrections, provisional deficit creation/settlement and variances when implemented, inspection and damage resolution, transfer, RTV, discard, and retained negative-inventory warnings.

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
- Quantity-tracked inventory uses Store-and-Variant moving weighted-average cost.
- Individually tracked Units retain exact Unit acquisition cost.
- Aggregate value governs positive quantity-tracked valuation calculations.
- Ledger history is authoritative; Stock Balance is reconcilable current state.
- At zero On Hand, current cost quality is unknown; asset value is zero.
- Zero or negative On Hand does not carry positive inventory asset value.
- Incoming quantity settles a deficit before creating positive inventory.
- Missing cost is distinct from confirmed zero cost.
- Mixed quality persists until zero balance or explicit complete correction.
- Department-based cost is an estimate, not actual acquisition cost.
- Quantity-only adjustments do not arbitrarily rewrite valuation.
- Phase 3 cost corrections require positive On Hand.
- Cost corrections are explicit, permissioned, and audited.
- Linked returns and post-voids use original completed cost.
- Posted cost history is not dynamically recalculated.
- Unknown cost is never treated as zero.
- Inventory posting services exclusively own value-state changes.
- Completed cost snapshots do not change later.

## Open questions

- What quantities beyond delivered, accepted, and rejected are required?
- How is accepted damaged or inspection quantity represented?
- What is the posted Receipt correction workflow?
- Is Available stored or calculated?
- Are unavailable quantities cached by status?
- Negative-inventory deficit allocation and settlement representation — accepted; [OD-014 decision](../implementation/decisions/od-014-negative-inventory-settlement.md).
- Allocation-to-reservation conversion on receipt — accepted; [OD-007 decision](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md).
- What is the Inventory Count model?
- What Adjustment thresholds require Approval?
- What is the inter-Store transfer lifecycle?
- When does RTV merchandise leave On Hand?
- What is the complete Return-to-Vendor document model?
