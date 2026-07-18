# Proposed changes to `docs/domains/receiving-and-inventory.md`

**Role:** Authoritative domain behavior under ADR-0013.  
**Not in this file:** exact schema columns, journal patterns, UI layouts, or future-workflow algorithms. See companion drafts listed below.

Companions:

* [ADR-0013 draft](0013-govern-quantity-tracked-inventory-cost.md)
* [Schema design note](inventory_cost_schema_design_note.md) — proposed, not for automatic promotion
* [Workflow costing note](inventory_workflow_costing_design_note.md) — proposed / open
* [Reporting and accounting note](inventory_cost_reporting_accounting_note.md) — proposed / open
* [UI guidance note](inventory_cost_ui_guidance_note.md) — proposed / open
* [Phase 3 scope](phase_03_costing_scope_note.md)

---

## Governing ADR addition

```markdown
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)
```

---

## Replace / extend Stock Balance cost language

One Stock Balance exists per Store and quantity-tracked Product Variant.

It holds current quantity, availability, and current quantity-tracked valuation state.

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

Aggregate inventory value applies only to positive On Hand. Zero or negative quantity does not create a negative inventory asset.

When On Hand is positive and cost is unknown, complete valuation is unknown. Later known-cost inventory must not silently assign cost to unresolved unknown-cost quantity. An explicit cost correction may establish complete valuation.

---

## Replace / extend Inventory Movements and ledger language

Only posted Inventory Movements change On Hand.

An Inventory Ledger Entry is the persisted record of a posted Inventory Movement. Posted entries form an append-only inventory ledger.

Each cost-bearing movement retains enough information to reproduce quantity change, inventory-value change, cost calculation approach, cost quality, source, reversal relationship, resulting balance state, and posting identity/time.

`movement_cost` (extended cost associated with the quantity moved) may differ from the signed change to positive inventory asset value. Example: a sale into negative inventory may carry provisional COGS without creating a negative inventory asset.

Posting a movement and updating its Stock Balance occur atomically and must be idempotent.

Illustrative movement types may include opening, quantity adjustment, cost correction, receipt, sale, return, post-void, transfer, RTV, discard, and correction. Listing a type does not establish that workflow’s lifecycle.

---

## Replace `## Cost`

### Costing scope

| Tracking mode | Cost model |
| --- | --- |
| `quantity` | Store-and-Variant moving weighted average (ADR-0013) |
| `individual` | Exact Inventory-Unit acquisition cost |
| `none` | No stock effects |

Catalog owns tracking mode and regular price. Inventory owns posted cost and balances.

### Provenance

Distinguish calculation approach from evidentiary quality (`actual`, `estimated`, `mixed`, `unknown`). Confirmed zero cost is not missing cost. Unknown must never be treated as zero.

Exact enum names and allowed combinations are schema decisions.

### Positive inbound / outbound

When On Hand is positive and valued:

```text
resulting quantity = existing quantity + incoming quantity
resulting inventory value = existing inventory value + incoming value
resulting moving average = resulting inventory value / resulting quantity
```

Outbound quantity that does not exceed positive On Hand receives a proportional share of aggregate inventory value (deterministic round-half-up). A movement that consumes the final positive quantity consumes any remaining valuation residual.

Combining actual and estimated inventory normally yields mixed quality.

### High-level deficit behavior

When an outbound movement crosses below zero:

1. the positive portion consumes remaining positive inventory value;
2. the excess creates or increases a deficit;
3. the deficit may carry provisional cost when a defensible retained rate exists, else unknown;
4. positive inventory asset value becomes zero.

Incoming quantity settles deficit before creating positive inventory. Differences between provisional and settling cost become explicit variance facts that:

* do not change On Hand;
* do not create inventory asset value;
* do not rewrite earlier completed activity;
* report in the settlement period.

Deficit-allocation algorithm (aggregate proportional pool versus origin-FIFO settlement records) remains open. See the schema design note.

### Opening inventory and adjustments

`opening_inventory` may establish quantity with actual, estimated, or unknown cost without creating a Receipt.

`quantity_only` changes quantity using the applicable current or retained costing basis and must not impose an arbitrary replacement rate. Quantity correcting a deficit toward zero is not an acquisition-cost variance.

`cost_correction` changes valuation or cost state without disguising the change as a quantity movement. For positive On Hand it may establish unknown valuation, replace estimate with actual, or correct erroneous aggregate value. Corrections are explicit and audited. They do not rewrite earlier movements or completed POS lines.

### Department estimate

When no more authoritative cost is available, Inventory may use an optional Department gross-margin estimate supplied by Classification and a Catalog regular selling price. The estimate is snapshotted when posted. The user may leave cost unknown. Later Department or price changes do not recalculate posted estimates.

### Returns and post-voids

Linked returns restore original completed-line cost. Post-voids reverse original completed cost. Restored positive quantity participates in the current moving average. Unlinked returns without historical cost use explicit actual, approved estimate, or unknown.

### Variance facts

Cost differences that do not change physical quantity are distinct non-quantity facts (not overloaded quantity movements). Exact table shape is a schema decision and may be deferred until an operational producer exists.

### Rounding

Integer cents. Deterministic round-half-up for proportional allocation and rate-based estimates unless a later ADR specifies otherwise. Fully depleted positive balances and fully settled provisional deficits leave no unexplained residual.

---

## Add to Audit requirements

Audit cost approach, quality, estimate inputs, missing versus confirmed-zero cost, aggregate value changes, provisional deficit creation/settlement, variances, and cost corrections.

---

## Add to Invariants

* Quantity-tracked inventory uses Store-and-Variant moving weighted-average cost.
* Individually tracked Units retain exact Unit acquisition cost.
* Aggregate value governs positive quantity-tracked valuation calculations.
* Ledger history is authoritative; Stock Balance is reconcilable current state.
* Zero or negative On Hand does not carry positive inventory asset value.
* Incoming quantity settles a deficit before creating positive inventory.
* Missing cost is distinct from confirmed zero cost.
* Department-based cost is an estimate, not actual acquisition cost.
* Quantity-only adjustments do not arbitrarily rewrite valuation.
* Cost corrections are explicit and audited.
* Linked returns and post-voids use original completed cost.
* Posted cost history is not dynamically recalculated.
* Unknown cost is never treated as zero.

---

## Remove from Open questions (after ADR acceptance)

```markdown
- How does moving average behave with negative On Hand?
```

Add open questions instead:

* Which deficit-allocation algorithm is used (proportional pool versus origin settlement records)?
* When are variance / settlement tables introduced relative to Phase 3, 4c, and 5?
