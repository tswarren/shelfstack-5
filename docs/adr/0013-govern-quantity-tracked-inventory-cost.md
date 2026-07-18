# ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance

**Status:** Accepted with open details  
**Date:** 2026-07-18

## Context

ShelfStack must assign cost for inventory valuation, completed-sale snapshots, margin reporting, opening stock, adjustments, returns, post-voids, and later receiving workflows.

Quantity-tracked merchandise is maintained at the Store-and-Product-Variant level and may be sold into negative On Hand after a warning. Individually tracked Inventory Units use exact acquisition cost and are outside this ADR’s moving-average rules.

A durable model must:

* value positive interchangeable stock without cumulative rounding drift;
* keep missing cost distinct from confirmed zero cost;
* prevent negative On Hand from becoming a negative inventory asset;
* allow estimated cost without misrepresenting it as actual acquisition cost;
* keep completed POS history immutable when later supply or corrections arrive.

Catalog owns Product Variant identity, Inventory-Tracking Mode, and regular selling price. Receiving and Inventory owns Stock Balances, Inventory Movements, and posted cost. Classification may supply optional Department estimation defaults. Vendors and Purchasing supply later actual and expected acquisition costs.

## Decision

### Scope

This ADR governs costing for **quantity-tracked Product Variants at the Store level**.

It does not govern individually tracked Inventory-Unit acquisition cost. A shared schema taxonomy may also represent exact Unit cost, although Unit costing is governed outside this ADR.

It does not establish document lifecycles for Receipts, transfers, RTV, counts, or Receipt corrections. Future workflows must:

* preserve carried cost;
* avoid rewriting completed history;
* represent discrepancies explicitly.

Their detailed costing and allocation rules remain governed by their domain and workflow designs. Negative-inventory deficit allocation remains [OD-014](../implementation/open-decisions.md#od-014-negative-inventory-deficit-allocation).

### Positive inventory valuation

Quantity-tracked positive On Hand uses moving weighted-average cost.

Aggregate positive inventory value is authoritative for current valuation calculations. The moving-average unit cost may be derived or cached for convenience, but proportional allocations use aggregate value and positive quantity, not a repeatedly rounded unit average.

```text
Inventory Ledger Entries / posted Inventory Movements
→ authoritative history

Stock Balance
→ authoritative current operational state
→ reconcilable from history
```

### Zero and negative On Hand

Negative On Hand is an operational deficit, not a negative inventory asset.

When On Hand is zero or negative, positive inventory asset value is zero.

An outbound movement that creates or increases a deficit may carry provisional cost when a defensible rate exists; otherwise its cost remains unknown. Provisional deficit cost is separate from positive inventory asset value.

Incoming quantity settles an existing deficit before creating positive inventory value. Differences between provisional deficit cost and later settling cost are represented as explicit variance facts that do not change On Hand and do not rewrite completed outbound snapshots.

Exact deficit-allocation algorithms and variance/settlement table shapes are deferred to OD-014.

### Cost provenance

Posted and snapshotted cost must distinguish at least:

* calculation approach (for example moving average, original snapshot, explicit entry, configured estimate, retained rate, unknown);
* evidentiary quality: `actual`, `estimated`, `mixed`, or `unknown`.

Confirmed zero cost is not missing cost. Unknown cost must never be treated as zero.

Exact field names, enums, and allowed combinations are schema decisions.

### Estimated cost

Estimated cost may be used when actual acquisition cost is unavailable. A Department may provide an optional Organization-level gross-margin fallback. That fallback:

* is estimation policy, not actual acquisition cost;
* does not make the Department the owner of Variant cost;
* must use an identified regular selling price, not a temporary transaction price;
* must be snapshotted when posted;
* must not be recalculated historically when Department, price, or policy changes.

Calculation and validation rules belong in the Receiving and Inventory Domain Specification.

Users may leave cost unknown rather than accept an unsupported estimate.

More authoritative actual or specific estimated cost takes precedence over a Department fallback. Store-specific estimation overrides, if introduced later, remain a Classification configuration concern.

### Adjustments

Retain distinct adjustment kinds:

* opening inventory;
* quantity-only adjustment;
* cost correction.

Opening inventory may establish quantity with actual, estimated, or unknown cost.

Quantity-only adjustments use the applicable current costing basis for positive balances and must not arbitrarily rewrite valuation. Phase-specific behavior for crossing zero is defined in the Inventory Domain and Phase 3 scope.

Cost corrections change cost or valuation explicitly, require elevated permission, audit reason, and must not rewrite earlier Inventory Movements or completed POS cost snapshots. Independent Approval infrastructure may be required later; it is not mandated by this ADR for every correction.

### Returns and post-voids

Linked customer returns restore original completed-line cost snapshots.

Post-voids reverse original completed cost snapshots.

Neither recalculates historical cost from current moving average, price, Department, or purchasing terms.

### Posting integrity

Cost-bearing posting is atomic and idempotent. Money is stored in integer cents. Rounding is deterministic so that fully depleted positive balances and fully settled provisional deficits leave no unexplained residual value.

Detailed formulas belong in the Receiving and Inventory Domain Specification.

## Consequences

### Benefits

* One quantity-tracked costing model across Inventory, POS, and Reporting.
* Clear separation of current balance state and historical explanation.
* Distinguishes actual, estimated, mixed, unknown, and confirmed-zero cost.
* Supports opening inventory before Receipt history.
* Prevents negative On Hand from corrupting inventory asset value.
* Preserves completed POS history.

### Costs

* Stock Balance and ledger require cost metadata beyond a single average field.
* Negative inventory requires provisional-cost and later variance handling (OD-014).
* Some valuation may remain unknown.
* Reports must distinguish provenance and later variances.
* Centralized costing services and concurrency tests are required.

## Alternatives considered

### Store only a rounded moving-average unit cost

Rejected because repeated rounding can drift aggregate valuation.

### Use most recent acquisition cost

Rejected because it revalues older interchangeable stock.

### Treat Department margin as actual cost

Rejected because a Department is too broad to establish acquisition cost.

### Treat missing cost as zero

Rejected because it understates inventory value and overstates margin.

### Maintain negative inventory asset value

Rejected because negative On Hand is not physical merchandise owned by the Store.

### Recalculate completed sale cost after later receiving

Rejected because completed POS snapshots are immutable.

## Governing rules

* Quantity-tracked inventory uses Store-and-Variant moving weighted-average cost.
* Individually tracked Units retain exact Unit acquisition cost (outside this ADR’s moving-average rules).
* Aggregate positive inventory value governs current valuation calculations.
* Posted Inventory Movements remain authoritative history; Stock Balance is reconcilable current state.
* Zero or negative On Hand carries no positive inventory asset value.
* Incoming quantity settles deficits before creating positive inventory.
* Later cost differences create explicit variance facts; they do not rewrite completed history.
* Missing cost differs from confirmed zero cost.
* Actual, estimated, mixed, and unknown remain distinguishable.
* Department margin is an optional estimated-cost fallback, not actual cost.
* Estimate inputs are snapshotted when posted.
* Opening, quantity-only, and cost-correction adjustments remain distinct.
* Quantity-only adjustments do not arbitrarily rewrite valuation.
* Cost corrections are explicit, permissioned, and audited.
* Linked returns and post-voids use original completed cost.
* Posting is atomic, idempotent, and deterministically rounded.

## Open details

* Deficit settlement algorithm and settlement/variance record shapes — [OD-014](../implementation/open-decisions.md#od-014-negative-inventory-deficit-allocation).
* Exact persisted field and enum names and allowed combinations (Phase 3 subset in [phase-03-inventory-cost-schema.md](../implementation/phase-03-inventory-cost-schema.md)).
* Full cost-correction numeric authority and Approval policy beyond elevated permission + audit reason.
* Accounting-export journal patterns and GL-account placement.
* UI presentation details.
* Store-level estimation override configuration model.
* Detailed transfer, RTV, count, and Receipt-correction costing algorithms, including any Receipt-correction allocation method.

A posted Receipt correction, when designed, must divide its effect between current inventory valuation and a separately reported historical cost variance without rewriting completed POS snapshots. The exact allocation algorithm remains open.

## Related domains

* Catalog and Products
* Classification and Configuration
* Vendors and Purchasing
* Receiving and Inventory
* Point of Sale
* Reporting and Reconciliation
* Organization and Authorization

## Related ADRs

* [ADR-0001: Separate Product, Product Variant, and Inventory Unit](0001-product-variant-inventory-unit.md)
* [ADR-0003: Use One Merchandise-Class Hierarchy with Department Defaults](0003-merchandise-classes-and-departments.md)
* [ADR-0004: Treat the Store as the Authoritative Inventory Boundary](0004-store-level-inventory-boundary.md)
* [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](0006-inventory-quantities-and-reservation-records.md)
* [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](0007-purchasing-receiving-and-inventory-events.md)
* [ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections](0008-immutable-pos-transactions.md)
* [ADR-0009: Complete POS Transactions Atomically and Idempotently](0009-atomic-idempotent-pos-completion.md)
* [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](0011-permissions-authority-and-approvals.md)
