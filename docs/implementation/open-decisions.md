# Open Decisions

**Status:** Living decision queue  
**Purpose:** Track unresolved design choices that block or shape upcoming delivery phases  
**Related:** [architectural-locks.md](architectural-locks.md) (accepted delivery choices), [deferred-capabilities.md](deferred-capabilities.md)

## How to use

1. Add a row when work reaches an unresolved choice.
2. Set **Needed by** to the delivery phase that cannot complete without a disposition.
3. When accepted, link the ADR, domain section, or architectural lock — do not restate the full decision here.
4. Do not list items already settled in [architectural-locks.md](architectural-locks.md) as Open.

### Status values

```text
open
proposed
accepted
deferred
superseded
```

## Decision queue

| ID | Decision | Status | Needed by | Governing area | Resolution |
| --- | --- | --- | --- | --- | --- |
| OD-001 | Business / reporting-date assignment rule | accepted | Phase 4a | POS | [architectural-locks.md](architectural-locks.md#business--reporting-date-v1-choice) — store `reporting_date` explicitly; v1 rule = date selected at business-day open |
| OD-002 | Receipt-sequence owner | accepted | Phase 4c | POS | [architectural-locks.md](architectural-locks.md#receipt-sequence-ownership-v1-choice) — next sequence on `stores`, locked at successful completion |
| OD-003 | Inventory costing (positive MWA, zero/negative asset, opening, adjustments, unknown vs zero, immutability) | accepted | Phase 3 | Inventory / Reporting | [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md); Inventory Domain cost sections |
| OD-004 | Tax residual-cent allocation, compounding, and rounding policy | accepted | Phase 4b | Classification / POS | [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md) |
| OD-005 | Tax calculated per line vs transaction after discount allocation | accepted | Phase 4b | Classification / POS | [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md) — hybrid line resolution + transaction-component rounding |
| OD-006 | Customer identity for Phase 5 requests | accepted (v1) | Phase 5 | Product Requests / future Customer | Phase 5 uses nullable opaque `customer_reference` only; no `customers` table. Rich CRM remains deferred. See [product-requests.md](../domains/product-requests.md) |
| OD-007 | PO allocation receipt and fulfilment representation | accepted | Phase 5 | Purchasing / Inventory / Requests | [decisions/od-007-allocation-receipt-and-fulfilment.md](decisions/od-007-allocation-receipt-and-fulfilment.md); ADR-0015 |
| OD-008 | Department GL account codes vs later mapping table | accepted | Phase 2 | Classification | GL account code columns remain on `departments` for Phase 2; no separate mapping table |
| OD-009 | Store configuration home (columns vs `store_configurations` vs policy tables) | open | Phase 4a | Classification / Org | Thresholds and behavioral settings placement |
| OD-010 | Unavailable quantity by status (aggregate only vs status balances) | open | Phase 3–5 | Inventory | `stock_balances.unavailable` total vs optional status buckets |
| OD-011 | Identifier generation sequence ownership | accepted | Phase 2 | Catalog | Installation-singleton `identifier_sequences` (namespaces `21`/`27`/`28`/`29`); INV-ORG-001. Issue [#14](https://github.com/tswarren/shelfstack-5/issues/14) |
| OD-012 | Parent/reporting-only departments (`postable = false`) in first release | accepted | Phase 2 | Classification | Hierarchical departments with `postable`; reporting-only parents in scope |
| OD-013 | Storage and precedence of role and store authority defaults | deferred | Phase 4b | Organization / Authorization | See [OD-013 notes](#od-013-role-and-store-authority-defaults) |
| OD-014 | Negative-inventory deficit allocation and settlement representation | accepted | Phase 4c / Phase 5 | Inventory / Reporting | [Phase 4c interim](#od-014-negative-inventory-deficit-allocation); Phase 5 settlement accepted in [decisions/od-014-negative-inventory-settlement.md](decisions/od-014-negative-inventory-settlement.md) |

## OD-013 role and store authority defaults

ADR-0011 and the domain specification describe precedence:

```text
membership override → role default → store default
```

The reconciled schema currently has authority columns only on `store_memberships`. Role default-limit columns and the store-configuration home for store defaults (related to OD-009) are not yet decided.

**Phase 1 interim rule** (fail closed):

- membership override present → evaluate against that value;
- membership override null → deny as **unconfigured** (complete precedence chain not implemented).

Do not interpret null as “zero authority.” Do not invent role or store authority columns until this OD is accepted.

## OD-003 — closed by ADR-0013

Accepted behavior:

- positive Store-and-Variant moving weighted average using aggregate inventory value;
- zero or negative On Hand carries no positive inventory asset value;
- opening inventory with actual, estimated, or unknown cost;
- quantity-only adjustments that do not arbitrarily rewrite valuation;
- explicit positive-balance cost corrections;
- missing cost versus confirmed zero cost;
- linked returns restore original cost; post-voids reverse original cost;
- completed cost snapshots are immutable.

Phase 3 deterministic transition rules live in the Inventory Domain (first positive from zero, cost-quality aggregation, zero-state quality, quantity-only crossing zero).

Quantity may sell negative after warning ([architectural-locks](architectural-locks.md#negative-inventory)). Asset value remains zero when On Hand ≤ 0. Phase 5 receipt settlement is accepted under OD-014.

## OD-007 — allocation receipt and fulfilment

**Status:** accepted  
**Needed by:** Phase 5  
**Governing area:** Product Requests / Purchasing / Receiving / POS  
**Related:** [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md), [decisions/od-007-allocation-receipt-and-fulfilment.md](decisions/od-007-allocation-receipt-and-fulfilment.md)

Purchase-Order Allocations commit expected supply only to Customer Requests. They do not persist `received` or `fulfilled` statuses. Remaining allocation quantity is derived from append-only conversion and release events. Receipt posting converts usable allocated quantity into an Inventory Reservation atomically. Final customer fulfilment is a separate Product Request Fulfilment fact linked to POS (or later delivery sources).

## OD-014 — negative-inventory deficit allocation

**Status:** accepted (Phase 4c interim + Phase 5 settlement)  
**Needed by:** Phase 4c / Phase 5  
**Governing area:** Inventory / Reporting  
**Related:** [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md), [decisions/od-014-negative-inventory-settlement.md](decisions/od-014-negative-inventory-settlement.md)

ADR-0013 and the closed portion of OD-003 settle positive moving average, zero/negative **asset** treatment, opening inventory, quantity-only and cost-correction kinds, unknown versus zero, and immutable historical costs.

### Phase 4c accepted interim (sale posting)

For quantity-tracked sales that create or increase negative On Hand:

1. **No settlement/variance tables in Phase 4c.** Explicit outcome: introduce **zero** new deficit-settlement tables for the first completed-sale milestone.
2. Outbound sale movements carry **provisional unit cost** from the best available rate (`moving_average` / `last_known` when positive history exists); otherwise cost quality is `unknown`. Confirmed zero remains distinct from unknown.
3. When On Hand ≤ 0 after the sale, **positive inventory asset value remains zero** (ADR-0013). Provisional deficit cost may be recorded on the outbound ledger/sale snapshot for later settlement; it is not a negative inventory asset.
4. Completed POS cost snapshots remain immutable when later supply arrives.
5. Incoming Receipt settlement is Phase 5 work and must not rewrite completed sale snapshots.

### Phase 5 accepted settlement

Aggregate Store-and-Variant deficit-cost pool (not origin-matched to individual sales). Accepted receipt quantity settles negative On Hand before creating positive inventory; a receipt line may post up to two ledger entries (`receipt_deficit_settlement` then `receipt`). Monetary variance / late cost recognition are separate non-quantity facts. Full rules: [decisions/od-014-negative-inventory-settlement.md](decisions/od-014-negative-inventory-settlement.md).

### Non-goals

- Transfer / RTV / count document lifecycles
- Receipt-correction allocation algorithm (may become a separate OD if substantial)
- Accounting journal patterns

## OD-004 / OD-005 — closed by ADR-0014

Accepted behavior:

- hybrid model: taxability and taxable base per line; round once per transaction tax component and line direction; allocate cents to lines with largest remainder;
- exact decimal intermediate arithmetic; integer cents for finalized money; no binary floats; rates and fractions at eight decimal places;
- round half up only at defined taxable-base and tax-component aggregation points;
- ordered components; compounding uses finalized (allocated) prior line tax amounts; taxable fraction applies to merchandise first;
- sale and return directions are separate rounding pools;
- tax effective date = store-local calendar date at completion (not Business Day `reporting_date`);
- Store Tax Rule `treatment` distinguishes `taxable`, `zero_rated`, `exempt`, and `not_applicable` (not a global Tax Category status); missing effective rules for a line’s Tax Category block completion;
- linked returns and post-voids reverse stored tax components exactly;
- tax-exclusive prices in initial release; tax-inclusive pricing and jurisdiction-configurable line-level rounding remain deferred;
- reusable tax-exemption masters remain deferred; transaction-scoped exemptions may exist earlier.

## Already settled (do not reopen here)

See [architectural-locks.md](architectural-locks.md):

- quantity-only first sale (through Phase 4c);
- negative-inventory sell-after-warning for quantity;
- Phase 3 adjustments only (no bootstrap receipts);
- opening / quantity-only / cost-correction adjustment kinds;
- receipt header may span POs; one PO line per receipt line;
- prefer derived `on_order`;
- reporting source rules;
- no display categories (ADR-0003).

## Sources

- [Proforma Open Decisions export](../exports/schema/ShelfStack%20Proforma%20Schema%20260717.1402%20reconciled%20-%20Open%20Decisions.csv)
- Domain Specification open-question sections
- Delivery roadmap phases
