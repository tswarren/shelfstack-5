# ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance

**Status:** Proposed  
**Date:** 2026-07-18

## Context

ShelfStack must assign cost to inventory and completed merchandise activity for:

* current inventory valuation;
* completed-sale cost snapshots;
* gross-margin reporting;
* opening inventory;
* inventory adjustments;
* customer returns;
* post-voids;
* future receiving, transfer, RTV, count, and purchasing workflows.

Quantity-tracked merchandise is maintained at the Store-and-Product-Variant level. Catalog owns Product Variant identity, Inventory-Tracking Mode, and regular selling price. Receiving and Inventory owns Stock Balances, Inventory Movements, and posted cost. Classification owns Department estimation defaults and GL mapping codes.

Quantity-tracked merchandise may be sold into negative On Hand after a visible warning.

A simple rounded average-cost field is not sufficient because:

* opening inventory may have no Receipt history;
* actual acquisition cost may be unknown;
* estimated cost may be required during migration;
* missing cost must remain distinct from confirmed zero cost;
* quantity-only adjustments must not arbitrarily revalue inventory;
* negative On Hand does not represent a negative physical asset;
* later incoming inventory may reveal a difference from provisional deficit cost;
* completed POS activity must remain historically reproducible;
* repeated cent rounding must not cause inventory valuation to drift.

## Decision

### Scope

This ADR governs costing for **quantity-tracked Product Variants at the Store level**.

It does not govern individually tracked Inventory Units. Each Inventory Unit retains its own acquisition cost and does not participate in a Store-and-Variant moving weighted average.

Catalog remains upstream: Inventory-Tracking Mode determines whether Stock Balances and Inventory Movements exist; regular selling price supplies Department-margin estimates. Catalog does not own Stock Balances or ledger posting.

This ADR settles **costing behavior** for future workflows (Receipts, transfers, RTV, counts, Receipt corrections). It does not establish their document lifecycles, statuses, or permissions. Those workflows must post inventory effects consistently with this decision.

### Current valuation and history

ShelfStack will use moving weighted-average cost for positive quantity-tracked inventory.

```text
Inventory Ledger Entries
→ authoritative history

Stock Balance
→ authoritative current operational state
→ reconcilable from history
```

Aggregate inventory value (`inventory_value_cents`) is stored on the Stock Balance as a reconcilable current-state cache. Posted Inventory Ledger Entries remain the historical explanation.

The rounded moving-average unit cost may be cached for display and convenience. Proportional calculations use aggregate inventory value and positive On Hand, not the cached unit average.

Every cost-bearing posting locks the applicable Stock Balance, creates ledger (and variance) records, and updates the balance atomically.

### Zero and negative On Hand

Negative On Hand represents an operational inventory deficit. It does not represent a negative inventory asset.

When On Hand is zero or negative:

```text
positive inventory asset value = 0
```

An outbound movement that creates or increases a deficit may receive a provisional cost based on the most recent applicable known or estimated quantity cost. If no defensible cost is available, its cost remains unknown.

Provisional deficit cost is tracked separately from positive inventory asset value. The Stock Balance caches aggregate deficit-cost state; immutable detail remains on deficit-origin movements and related settlement records.

Incoming quantity settles an existing deficit before creating positive inventory:

1. the portion that offsets the deficit resolves provisional deficit cost in deterministic FIFO order of outstanding deficit-origin movements (`posted_at`, then ledger-entry ID);
2. any difference between provisional cost and the incoming cost becomes an explicit cost variance;
3. only quantity remaining after the deficit is settled creates positive inventory value.

FIFO settlement order is a reconciliation rule for outstanding negative movements. It is not physical FIFO inventory costing.

Later incoming cost does not rewrite completed sale or other posted outbound cost snapshots.

### Cost variances

Negative-inventory and related cost differences that do not change physical quantity are represented as related `inventory_cost_variances` records, not as overloaded Inventory Movement types.

Variances report in the period of the resolving event. They do not reinterpret completed historical snapshots.

### Cost provenance

ShelfStack must distinguish three independent dimensions:

* **cost method** — how the amount was calculated;
* **cost quality** — evidentiary basis (`actual`, `estimated`, `mixed`, `unknown`);
* **cost finality** — whether the amount is `final`, `provisional`, or `unresolved`.

Confirmed zero cost is not missing cost.

```text
cost amount = null  → unknown
cost amount = 0     → explicitly established zero cost
```

Exact column and enum names are documented in the Receiving and Inventory Domain Specification and schema documentation. Persistence uses string columns with application validation and database check constraints, not native PostgreSQL enums.

### Estimated cost

ShelfStack may use an explicit estimated cost when actual acquisition cost is unavailable.

A Department may provide an optional Organization-level default gross-margin assumption as a fallback. Such a default:

* is an estimation policy, not actual acquisition cost;
* does not make the Department the owner of Product-Variant cost;
* must use Catalog regular selling price, not a temporary transaction price;
* must retain the price and rate used when the estimate is posted;
* must be classified as estimated;
* must not be recalculated historically when Department, price, or policy changes.

Cost-source precedence:

```text
original historical cost
→ explicit actual cost
→ receipt or vendor-specific actual cost
→ explicit line-level estimate
→ vendor expected net cost
→ Store-and-Department estimation policy (future)
→ Organization Department default
→ unknown
```

Vendor expected cost remains estimated until it becomes documented actual acquisition cost.

Users may leave cost unknown rather than accept an unsupported estimate.

Effective-dated Store-level estimation overrides are supported later through a separate policy table. They are out of Phase 3 scope.

### Opening inventory and adjustments

Separate adjustment kinds:

* `opening_inventory`;
* `quantity_only`;
* `cost_correction`.

Opening inventory may establish quantity with actual, estimated, or unknown cost.

A quantity-only adjustment uses the applicable current or retained costing basis and must not accept an arbitrary replacement valuation.

A cost correction changes cost or valuation explicitly without disguising the change as a quantity movement. It requires:

* `inventory.cost_correction.post` (distinct from ordinary adjustment posting);
* sufficient numeric authority on amount and, when evaluable, relative rate;
* an independent Approval when mandatory conditions apply (see Inventory Domain / permission catalog).

System-calculated variances created by ordinary receiving settlement do not require a separate cost-correction Approval. Manual overrides of those variances do.

Corrections do not rewrite earlier Inventory Movements or completed POS cost snapshots.

### Returns and post-voids

A linked customer return restores the cost snapshotted on the original completed sale line.

A post-void reverses the cost effects snapshotted on the original transaction.

Neither recalculates historical cost from the current moving average, price, Department, or purchasing terms.

When restored quantity enters a current positive balance, its restored value participates in the current moving weighted average.

### Workflow costing (lifecycles deferred)

Full document lifecycles remain open. Costing rules are settled now:

* **Transfers** — transfer out removes available stock at source moving-average (or Unit) cost; transfer in adds that exact carried value at destination; average differences alone create no profit/loss; transfers must not create negative On Hand.
* **RTV** — holding increases Unavailable only; shipment removes On Hand and value at carrying cost; Vendor-credit differences are RTV/purchasing settlement variances, not negative-inventory cost variances.
* **Counts** — posting creates a quantity-only adjustment; overages do not automatically invoke Department estimates; correcting a deficit toward zero is not an acquisition-cost variance.
* **Receipt corrections** — never edit posted Receipts or original movements; linked corrections split effects into current inventory-value adjustment plus historical `inventory_cost_variance` via counterfactual replay from the original Receipt movement forward. Implementation may wait until Receipt corrections are introduced.

### Inventory movement history

Posted Inventory Movements form an append-only inventory ledger.

Each cost-bearing movement retains enough information to reproduce quantity change, inventory-value change, cost method, quality, finality, source, reversal relationship, resulting balance state, and posting identity/time.

Inventory movement posting, Stock Balance updates, and related variance creation must be atomic and idempotent.

### Rounding

ShelfStack stores money in integer cents.

Cost allocation and rate-based estimation use deterministic rounding. Residual cents follow documented rules so that:

* a fully depleted positive balance retains no inventory value;
* a fully settled provisional deficit retains no cost residual;
* retries and concurrent execution produce the same posted result.

Detailed formulas belong in the Receiving and Inventory Domain Specification.

### Accounting mapping

Departments carry GL mapping codes including:

* inventory deficit clearing;
* inventory cost variance.

Export journal patterns for negative sales, deficit settlement, and unknown-cost catch-up are specified in the Inventory Domain. External export batch protocol remains outside this ADR.

### Presentation

UI and reports must never present unknown cost as zero. Amount, quality, source, and finality must remain distinguishable for users with `inventory.cost.view`. Detailed presentation guidance belongs in the Inventory Domain.

## Consequences

### Benefits

* Establishes one quantity-tracked costing model across Catalog inputs, Inventory, POS, and Reporting.
* Prevents repeated unit-cost rounding from causing valuation drift.
* Preserves actual, estimated, mixed, unknown, confirmed-zero, provisional, and variance distinctions.
* Allows opening inventory before Receipt history exists.
* Permits Department-based estimates without representing them as actual acquisition cost.
* Prevents negative On Hand from becoming a negative inventory asset.
* Makes later negative-inventory cost differences explicit and reportable.
* Preserves completed POS history.
* Settles workflow costing rules before those workflows are designed.
* Keeps individually tracked Unit cost separate from quantity moving average.

### Costs

* Stock Balance and ledger require richer cost metadata.
* Negative inventory requires provisional-cost cache, FIFO settlement detail, and variance records.
* Some current inventory valuation may remain unknown.
* Reports must distinguish provenance and variance amounts.
* Cost corrections require separate permission, authority, and Approval paths.
* Receipt-cost corrections require counterfactual replay when introduced.
* Concurrency and rounding behavior require dedicated tests.

## Alternatives considered

### Store only a rounded moving-average unit cost

Rejected because repeated multiplication and rounding can cause aggregate inventory value to drift.

### Use most recent acquisition cost

Rejected because the latest cost would revalue older interchangeable stock.

### Treat Department margin as actual cost

Rejected because a Department is too broad to establish acquisition cost.

### Treat missing cost as zero

Rejected because it would understate inventory value and overstate margin.

### Maintain negative inventory asset value

Rejected because negative On Hand is an operational deficit, not physical merchandise owned by the Store.

### Represent variances only as Inventory Movements

Rejected because variances do not change quantity, may link one incoming event to several origins, and need distinct accounting and reporting treatment.

### Derive deficit state from the full ledger on every posting

Rejected because concurrent posting needs a locked current aggregate; history remains available for reconstruction and reconciliation.

### Recalculate completed sale cost after later receiving

Rejected because completed POS records and their financial snapshots are immutable.

### Dynamically recalculate estimates during reporting

Rejected because later policy or price changes would reinterpret posted history.

## Governing rules

* This ADR governs quantity-tracked inventory only.
* Individually tracked Inventory Units retain exact Unit acquisition cost.
* Catalog owns tracking mode and regular price; Inventory owns posted cost and balances.
* Positive quantity-tracked inventory uses moving weighted-average cost.
* Aggregate positive inventory value on Stock Balance governs current valuation calculations.
* Inventory Ledger Entries remain authoritative history.
* Zero or negative On Hand carries no positive inventory asset value.
* Negative quantity may retain separate provisional cost state.
* Deficit settlement uses deterministic FIFO of outstanding deficit-origin movements.
* Incoming quantity settles deficits before creating positive inventory.
* Cost variances use related `inventory_cost_variances` records.
* Missing cost and confirmed zero cost remain distinct.
* Cost method, quality, and finality remain distinguishable.
* Department margin is an estimated-cost fallback, not actual cost.
* Estimate inputs are snapshotted when posted.
* Quantity-only adjustments do not arbitrarily rewrite valuation.
* Cost corrections are explicit, permissioned, authority-checked, and approved when required.
* Linked returns restore original completed-line cost.
* Post-voids reverse original completed cost.
* Completed cost snapshots are not recalculated.
* Posted Inventory Movements are append-only.
* Movement, balance, and variance posting are atomic and idempotent.
* Cost calculations use deterministic rounding.
* Unknown cost must never be displayed or exported as zero.
* Transfer, RTV, count, and Receipt-correction costing follow this ADR; their document lifecycles remain separately designed.

## Open details

The following operating and integration details remain outside this ADR:

* configured numeric authority values by Role and Store;
* external accounting-system export format and batch protocol;
* full Transfer lifecycle and in-transit discrepancy workflow;
* full Return-to-Vendor document and settlement lifecycle;
* Inventory Count scheduling, freezing, recount, and approval workflow;
* Receipt-correction UI and counterfactual replay implementation;
* timing for introducing effective-dated Store-level cost-estimation policies.

These details must preserve the costing, provenance, variance, and historical-immutability rules established by this ADR.

## Related domains

* Catalog and Products
* Classification and Configuration
* Organization and Authorization
* Vendors and Purchasing
* Receiving and Inventory
* Point of Sale
* Reporting and Reconciliation

## Related ADRs

* [ADR-0001: Separate Product, Product Variant, and Inventory Unit](../adr/0001-product-variant-inventory-unit.md)
* [ADR-0003: Use One Merchandise-Class Hierarchy with Department Defaults](../adr/0003-merchandise-classes-and-departments.md)
* [ADR-0004: Treat the Store as the Authoritative Inventory Boundary](../adr/0004-store-level-inventory-boundary.md)
* [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](../adr/0006-inventory-quantities-and-reservation-records.md)
* [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](../adr/0007-purchasing-receiving-and-inventory-events.md)
* [ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections](../adr/0008-immutable-pos-transactions.md)
* [ADR-0009: Complete POS Transactions Atomically and Idempotently](../adr/0009-atomic-idempotent-pos-completion.md)
* [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](../adr/0011-permissions-authority-and-approvals.md)
