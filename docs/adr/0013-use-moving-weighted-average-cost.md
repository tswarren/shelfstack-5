# ADR-0013: Use Moving Weighted-Average Cost with Explicit Cost Basis and Negative-Inventory Variances

**Status:** Proposed
**Date:** 2026-07-18

## Context

ShelfStack must assign inventory cost to quantity-tracked merchandise for:

* current inventory valuation;
* completed-sale cost snapshots;
* gross-margin reporting;
* inventory adjustments;
* customer returns;
* post-voids;
* future receiving workflows.

Quantity-tracked inventory is authoritative for each Store and Product Variant and uses moving weighted-average cost.

Several conditions make a simple average-cost field insufficient:

* opening inventory may be entered without receipt history;
* actual acquisition cost may be unknown;
* estimated cost may be derived from a Department policy;
* quantity-only adjustments must not arbitrarily change valuation;
* cost corrections must not change quantity;
* quantity-tracked merchandise may be sold into negative inventory after a warning;
* receiving may later partially or completely offset negative inventory;
* completed POS activity must remain historically reproducible;
* missing cost must remain distinguishable from confirmed zero cost;
* repeated cent rounding must not cause inventory value to drift.

A deterministic costing policy is required before completed POS sales and later receipt posting can rely on inventory cost.

## Decision

ShelfStack will use moving weighted-average cost for quantity-tracked inventory, supported by an explicit aggregate inventory value, cost-basis classification, and separate treatment of negative-inventory cost variances.

The inventory ledger remains the authoritative history. A Stock Balance may cache current quantity, value, average cost, and negative-inventory costing state for efficient operation.

## Cost representation

For each Store and quantity-tracked Product Variant, ShelfStack will maintain or derive:

```text
on_hand
inventory_value_cents
moving_average_cost_cents
cost_basis
```

Where necessary to reconcile negative inventory, ShelfStack will also retain or derive:

```text
negative_quantity
provisional_negative_cost_cents
negative_cost_basis
```

### Aggregate inventory value

`inventory_value_cents` represents the aggregate cost value assigned to positive physical On Hand.

It is authoritative for current inventory valuation when cost is known or estimated.

The rounded moving-average cost is derived from:

```text
inventory_value_cents / on_hand
```

when On Hand is positive.

ShelfStack will use aggregate value, rather than repeatedly multiplying a rounded average by quantity, to reduce cumulative rounding errors.

### Cost basis

Cost-bearing inventory events must identify their cost basis.

Initial cost-basis classifications are:

```text
actual
estimated
mixed
unknown
```

Meaning:

* `actual` — based on documented acquisition cost or another authoritative historical cost;
* `estimated` — based on an explicitly identified estimate;
* `mixed` — the current balance combines actual and estimated cost;
* `unknown` — some or all required cost cannot be determined.

A zero monetary value does not mean missing cost.

```text
unit cost = null
cost basis = unknown
```

means that cost is unavailable.

```text
unit cost = 0
cost basis = actual or estimated
```

means that zero cost was explicitly established.

Every ledger entry and completed POS cost snapshot must preserve enough information to distinguish these cases.

## Positive On-Hand weighted average

When On Hand is positive and all existing and incoming cost is known or estimated:

```text
resulting quantity
=
existing quantity
+ incoming quantity
```

```text
resulting inventory value
=
existing inventory value
+ incoming inventory value
```

```text
resulting moving average
=
resulting inventory value
/ resulting quantity
```

For an incoming quantity with one unit cost:

```text
incoming inventory value
=
incoming quantity
× incoming unit cost
```

Example:

```text
Existing:
5 units
$50.00 inventory value

Incoming:
3 units at $12.00
$36.00 incoming value

Result:
8 units
$86.00 inventory value
$10.75 moving-average cost
```

An incoming actual cost combined with an estimated balance produces a `mixed` cost basis unless an explicit cost correction replaces the estimate.

## Outbound quantity and cost allocation

An outbound inventory movement includes:

* completed sale;
* shrink or loss adjustment;
* return to vendor;
* transfer out;
* another posted quantity reduction.

When the movement leaves On Hand positive, the movement receives a proportional share of current aggregate inventory value:

```text
outbound value
=
round_half_up(
  existing inventory value
  × outbound quantity
  / existing positive quantity
)
```

The resulting balance is:

```text
resulting inventory value
=
existing inventory value
- outbound value
```

When the movement consumes all remaining positive quantity, it consumes all remaining inventory value. This prevents residual cents from remaining on a zero quantity.

The extended cost assigned to the movement is authoritative. A displayed or snapshotted unit cost may be rounded from the extended cost.

## Missing cost while On Hand is positive

When positive On Hand includes unresolved unknown cost:

* current aggregate inventory value is reported as unknown;
* moving-average cost is unknown;
* outbound movements snapshot unknown cost;
* later known-cost receipts do not silently make the entire existing balance known;
* the balance remains unknown until it reaches zero or an explicit cost correction establishes a complete valuation.

ShelfStack must not present a partially known value as a complete inventory valuation.

An estimated cost may instead be established explicitly when an approved estimation source is available.

## Estimated cost from Department margin

A Department may define an optional default gross-margin assumption for estimating cost when no more authoritative cost is available.

A suitable schema name would be:

```text
default_cost_estimation_margin_bps
```

The rate is expressed in basis points and represents gross margin, not markup.

Estimated unit cost is:

```text
estimated unit cost
=
round_half_up(
  regular selling price
  × (10,000 - margin basis points)
  / 10,000
)
```

Example:

```text
Regular selling price: $20.00
Department estimation margin: 40.00%
Estimated unit cost: $12.00
```

The estimate must use the effective regular selling price, excluding:

* temporary promotions;
* coupons;
* transaction discounts;
* temporary markdowns;
* employee or membership discounts.

The posting record must snapshot:

* the regular selling price used;
* the margin rate used;
* the resolved Department;
* the resulting estimated unit cost;
* the cost basis `estimated`;
* the user or policy that authorized use of the estimate.

A Department rate is a fallback costing assumption. It is not an actual acquisition cost and does not make the Department the owner of variant cost.

The estimate must be established when inventory is posted or through an explicit cost correction. Reports and completed sales must not dynamically recalculate historical cost from the current Department rate or current selling price.

## Cost-source precedence

Cost for a new inventory event is resolved in this order:

1. the exact historical cost being restored or reversed;
2. an explicit documented actual unit cost;
3. an explicit documented estimated unit cost;
4. an approved Department gross-margin estimate;
5. unknown cost.

Future Vendor or receipt estimates may be inserted before the Department fallback, but they must remain classified as estimated unless they represent actual invoiced acquisition cost.

ShelfStack must not silently convert an expected, list, or suggested cost into actual cost.

## Opening inventory

An `opening_inventory` adjustment establishes inventory without requiring receipt history.

It records:

* quantity;
* explicit actual or estimated unit cost, where available;
* cost basis;
* estimation details, where applicable;
* reason;
* posting user;
* resulting quantity and value.

When a Department estimate is available, ShelfStack may suggest it, but its use must be visible and recorded.

When no cost is available or approved:

* opening quantity may still be posted;
* inventory cost remains unknown;
* the condition appears in missing-cost reporting.

Opening inventory does not create a receipt or imply a Vendor acquisition.

## Quantity-only adjustments

A `quantity_only` adjustment changes quantity without accepting an arbitrary replacement cost.

When current cost is known or estimated, added or removed quantity uses the current moving-average cost.

When current cost is unknown:

* added quantity remains unknown-cost inventory;
* removed quantity receives unknown cost;
* the adjustment does not manufacture an estimated value implicitly.

A quantity-only adjustment reaching zero quantity sets current inventory value to zero.

A quantity-only adjustment must not be used to correct cost.

## Cost corrections

A `cost_correction` adjustment changes inventory valuation without changing quantity.

It requires:

* positive On Hand;
* elevated permission;
* an audit reason;
* the previous inventory value;
* the corrected inventory value or documented correction delta;
* the resulting cost basis;
* the posting user and timestamp.

The correction creates a ledger entry with:

```text
quantity delta = 0
inventory value delta = corrected value - previous value
```

A cost correction does not rewrite earlier ledger entries or completed POS cost snapshots.

A normal cost correction is not permitted when On Hand is zero or negative because there is no positive inventory asset to revalue. Negative-inventory cost differences are handled as variances when the deficit is settled.

## Zero and negative On Hand

Quantity-tracked inventory may become negative after a visible warning.

Negative inventory represents an operational timing or quantity discrepancy. It does not represent a negative inventory asset.

Therefore:

```text
when on_hand <= 0:
inventory_value_cents = 0
```

ShelfStack must not report negative inventory value as a negative asset.

### Sale or outbound movement crossing below zero

When an outbound movement consumes all positive On Hand and continues into negative quantity:

1. the positive portion consumes all remaining positive inventory value;
2. the excess negative portion receives a provisional issue cost from the current moving-average cost, when available;
3. that provisional cost is retained separately as negative-inventory costing state;
4. current inventory value remains zero.

If no issue cost is available, the negative portion has unknown provisional cost.

Completed POS lines snapshot:

* the cost assigned to the positive portion;
* the provisional cost assigned to the negative portion, where available;
* total extended cost;
* whether any cost was provisional or unknown.

### Provisional negative-cost pool

Negative quantities and their provisional costs form a reconciliation pool separate from positive inventory value.

When additional negative quantity is created:

* its provisional extended cost is added to the pool;
* unknown-cost negative quantity remains identifiable.

When part of the deficit is settled, the corresponding provisional cost is allocated proportionally from the pool. Final settlement consumes any remaining rounding residual.

This pool may be stored as cached balance data or derived from ledger entries, provided results are deterministic and reconcilable.

## Incoming inventory against negative On Hand

Incoming inventory first settles existing negative quantity.

Define:

```text
deficit quantity
=
maximum of (-existing on_hand) and 0
```

```text
settlement quantity
=
minimum of incoming quantity and deficit quantity
```

```text
surplus quantity
=
incoming quantity - settlement quantity
```

### Incoming quantity only partially offsets negative stock

When resulting On Hand remains negative:

* no positive inventory asset is created;
* inventory value remains zero;
* the settlement quantity reduces the negative-cost pool;
* the incoming cost for the settlement quantity is compared with its allocated provisional cost;
* the difference is recorded as a negative-inventory cost variance;
* any remaining deficit remains in the negative-cost pool.

### Incoming quantity brings On Hand exactly to zero

When resulting On Hand is zero:

* inventory value remains zero;
* the remaining negative-cost pool is fully settled;
* the difference between incoming cost and provisional cost is recorded as a variance;
* the negative-inventory episode is closed.

### Incoming quantity crosses from negative to positive

When incoming quantity exceeds the deficit:

* the settlement portion does not create positive inventory value;
* the settlement portion resolves provisional cost and records any variance;
* only the surplus quantity creates positive inventory value;
* the surplus is valued at the incoming unit cost;
* the resulting moving-average cost is based on the positive surplus.

Example:

```text
Before incoming movement:
on hand = -2
provisional negative cost = $20.00

Incoming:
3 units at $12.00
incoming value = $36.00

Settlement:
2 units
actual settlement cost = $24.00
provisional settlement cost = $20.00
cost variance = $4.00

Positive surplus:
1 unit
inventory value = $12.00
moving-average cost = $12.00
```

The prior completed sales remain unchanged. The $4.00 difference is reported as a later cost variance.

### Unknown provisional cost

When the deficit had unknown provisional cost, the known incoming cost assigned to its settlement is recorded as a cost catch-up or unresolved negative-inventory variance according to reporting policy.

It must not be added to positive inventory value unless it relates to surplus positive quantity.

## Negative-inventory variance

A negative-inventory variance represents the difference between:

* provisional cost assigned when merchandise was issued below zero; and
* actual or estimated incoming cost later associated with settling that deficit.

The variance:

* is recorded in the period in which the settling event posts;
* references the settling inventory event;
* retains the relevant Store and Product Variant;
* identifies actual, estimated, or unknown basis;
* does not change On Hand;
* does not rewrite completed POS lines;
* is separately reportable from ordinary inventory asset value.

The exact schema may store the variance on the inventory ledger entry or through a related cost-variance record. In either case, it must be reproducible and auditable.

## Customer returns

A linked customer return restores the cost snapshotted on the original completed sale line.

It does not use the current moving-average cost.

For a partial return, original extended cost is allocated proportionally. The final return of the remaining quantity consumes any residual cents from the original snapshot.

When returned merchandise becomes positive On Hand, its restored value participates in the current moving weighted average.

When the return offsets negative On Hand, the negative-inventory settlement rules apply, while the customer-return cost effect continues to use the original snapshot.

An unlinked return without authoritative historical cost must use an explicit actual cost, an approved estimate, or unknown cost.

## Post-voids

A post-void reverses the original completed transaction’s cost effects using the original cost snapshots.

It does not calculate a new cost from the current Product Variant or Department.

Restored quantity enters current inventory at the original snapshotted cost and participates in the current moving weighted average.

The original completed transaction remains unchanged.

## Rounding

ShelfStack uses integer cents for monetary storage.

Unless a more specific accepted ADR applies:

* rate-based cost estimates use round-half-up to the nearest cent;
* proportional outbound cost uses round-half-up;
* aggregate inventory value remains authoritative;
* the last movement consuming a positive balance receives any remaining valuation-cent residual;
* the final settlement of a negative-cost pool receives any remaining provisional-cost residual.

The same inputs must produce the same result regardless of interface, job, or retry.

## Historical immutability

Changes to:

* current moving-average cost;
* Department estimation margins;
* Product Variant price;
* Vendor cost;
* receipt cost;
* current inventory value;

must not reinterpret completed POS lines or posted ledger entries.

Completed activity retains its original quantity, unit-cost, extended-cost, cost-basis, and estimation snapshots.

Later information creates:

* a cost correction for remaining positive inventory;
* a negative-inventory variance;
* another explicit corrective event.

It does not mutate historical facts.

## Ledger requirements

Every cost-bearing inventory ledger entry retains at minimum:

* Store;
* Product Variant;
* quantity delta;
* inventory-value delta;
* unit cost used, when applicable;
* extended cost used;
* cost basis;
* movement or adjustment type;
* reason;
* source record;
* posting user;
* posting timestamp;
* resulting On Hand;
* resulting inventory value;
* resulting moving-average cost;
* negative-inventory variance, where applicable;
* estimation inputs, where applicable.

Ledger posting and Stock Balance updates must occur atomically.

Retries must not create duplicate movements, duplicate cost corrections, or duplicate variances.

## Consequences

### Benefits

* Establishes deterministic moving-average calculations.
* Prevents cumulative valuation drift from repeatedly rounded unit averages.
* Supports opening inventory before purchasing and receiving are implemented.
* Distinguishes actual, estimated, mixed, zero, and unknown cost.
* Allows Department defaults without misrepresenting estimates as actual acquisition cost.
* Prevents temporary discounts from corrupting cost estimates.
* Prevents negative On Hand from creating a negative inventory asset.
* Reconciles provisional negative-sale cost when actual incoming cost becomes known.
* Preserves immutable completed POS history.
* Supports reproducible inventory and margin reporting.
* Keeps quantity changes, cost changes, and historical corrections separate.

### Costs

* Stock Balance and ledger structures require more cost metadata than a single average-cost field.
* Negative inventory requires provisional-cost and variance handling.
* Current valuation may remain unknown when unresolved opening cost exists.
* Reports must distinguish ordinary COGS, estimated COGS, missing cost, and later cost variances.
* Cost corrections require controlled permissions and audit.
* Mixed actual and estimated balances require clear user presentation.
* Receipt and POS posting services must use the same centralized costing service.
* Testing must cover cent rounding, retries, concurrency, negative quantity, and unknown-cost paths.

## Alternatives considered

### Store only a rounded moving-average unit cost

Rejected because repeated quantity reductions can accumulate rounding errors and leave residual or overstated inventory value.

### Use the most recent acquisition cost

Rejected because it would cause all existing quantity to be revalued whenever new merchandise arrives and would not represent the blended cost of interchangeable stock.

### Use a Department margin as authoritative cost

Rejected because a Department is too broad to establish actual acquisition cost and may contain merchandise with substantially different purchasing economics.

The Department margin is retained only as an explicitly identified estimation fallback.

### Derive estimated cost dynamically during reporting

Rejected because changes to selling price or Department policy would reinterpret historical results.

Estimated cost must be snapshotted when the inventory or correction event posts.

### Treat missing cost as zero

Rejected because it would overstate margin, understate inventory value, and make unavailable information indistinguishable from confirmed free merchandise.

### Maintain negative inventory value

Rejected because a negative quantity is an operational discrepancy, not a negative physical inventory asset. Negative valuation can also produce unstable or nonsensical averages when receipts partially offset a deficit.

### Ignore the cost of receipts that settle negative inventory

Rejected because the acquisition cost would disappear from inventory and margin reporting.

The settling cost must reconcile against provisional issue cost through an explicit variance.

### Retroactively update completed POS cost when a receipt arrives

Rejected because completed transactions and their cost snapshots must remain immutable and reproducible.

### Block negative inventory

Rejected for the established baseline because quantity-tracked merchandise may be sold beyond available quantity after a visible warning.

## Governing rules

* Quantity-tracked inventory uses moving weighted-average cost.
* Aggregate inventory value is authoritative when cost is known or estimated.
* Moving-average unit cost is derived from aggregate value and positive On Hand.
* Missing cost is not zero cost.
* Every cost-bearing event identifies actual, estimated, mixed, or unknown basis.
* Department margin is an estimation fallback, not actual cost.
* Department-based estimates use snapshotted regular price and margin inputs.
* Quantity-only adjustments use current cost and cannot arbitrarily revalue inventory.
* Cost corrections change value without changing quantity.
* Ordinary cost corrections require positive On Hand.
* Inventory value is zero whenever On Hand is zero or negative.
* Negative quantity may retain a separate provisional cost pool.
* Incoming quantity settles negative inventory before creating a positive inventory asset.
* Differences between provisional and settling cost create explicit variances.
* Linked returns restore original cost snapshots.
* Post-voids reverse original cost snapshots.
* Completed cost snapshots are immutable.
* Ledger and balance posting are atomic and idempotent.
* Cost, valuation, and variance calculations use deterministic rounding.

## Open details

The following implementation choices do not alter this decision:

* whether aggregate cost-basis state is stored directly on Stock Balance or derived from ledger history;
* whether negative-inventory variances are columns on inventory-ledger entries or separate related records;
* exact permission keys and approval thresholds for cost corrections;
* presentation of estimated, mixed, and unknown valuation in administrative screens;
* accounting-export mappings for negative-inventory variances;
* whether later Store-specific estimation overrides supplement the Department default.

These details must preserve the formulas, historical immutability, and cost-provenance rules established by this ADR.

## Related domains

* Classification and Configuration
* Vendors and Purchasing
* Receiving and Inventory
* Point of Sale
* Reporting and Reconciliation

## Related ADRs

* [ADR-0003: Use One Merchandise-Class Hierarchy with Department Defaults](0003-merchandise-classes-and-departments.md)
* [ADR-0004: Treat the Store as the Authoritative Inventory Boundary](0004-store-level-inventory-boundary.md)
* [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](0006-inventory-quantities-and-reservation-records.md)
* [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](0007-purchasing-receiving-and-inventory-events.md)
* [ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections](0008-immutable-pos-transactions.md)
* [ADR-0009: Complete POS Transactions Atomically and Idempotently](0009-atomic-idempotent-pos-completion.md)
* [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](0011-permissions-authority-and-approvals.md)
