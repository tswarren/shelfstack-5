# Architectural Locks for Delivery

**Status:** Binding for implementation until a superseding ADR or explicit roadmap revision  
**Purpose:** Record settled delivery decisions so phases do not re-open them casually

These locks complement accepted ADRs. They choose among allowed implementation options or stage accepted capabilities.

## Document and schema authority

Before Phase 2 migrations:

1. Prefer accepted ADRs over domain text or schema exports that still describe removed concepts.
2. Audit domain specs and schema artifacts for leftover `display_categor*` fields or separate display-category entities.
3. Do not scaffold `display_categories` or `*_display_category_id` (ADR-0003).

See [schema-reconciliation-display-categories-and-demand-allocation.md](schema-reconciliation-display-categories-and-demand-allocation.md).

## First completed-sale scope

Phases 3 through 4c support inventory-tracking modes:

```text
quantity
none
```

Individually tracked merchandise (`inventory_units`, `27` identifiers, exact-unit sale) is **Phase 4d**, not part of the first completion milestone.

## Negative inventory

**Settled baseline** (not an open gate):

- Quantity-tracked variants may reserve and sell beyond available quantity after a **visible warning**.
- Negative inventory is not inherently an approval event.
- A store setting may later enable a stricter blocking policy.
- Individually tracked units must **never** be oversold (enforced when Phase 4d lands).

## Inventory bootstrap mechanism

Phase 3 establishes on-hand stock with **posted inventory adjustments** only.

Do **not** introduce provisional or unlinked receipts in Phase 3. Receipts arrive with purchasing in Phase 5.

## Opening-cost contract

Adjustment kinds are distinct:

| Kind | Behavior |
| --- | --- |
| Opening inventory | Accepts quantity and opening unit cost; initializes or updates inventory value per a documented formula; controlled use |
| Quantity-only | Changes quantity using the **current** moving-average cost; must not arbitrarily rewrite valuation |
| Cost correction | Separate type; elevated permission and audit reason; explicit valuation change |

Ledger entries retain at minimum:

- quantity delta;
- unit cost used;
- total value delta;
- adjustment type;
- reason;
- user;
- source record.

**Quantity-tracked costing (ADR-0013):** Positive On Hand uses moving weighted average over aggregate inventory value. Zero or negative On Hand carries no positive inventory asset value. Opening, quantity-only, and cost-correction kinds remain as locked above. Missing cost differs from confirmed zero. Completed cost snapshots are immutable.

**Deficit allocation (OD-014):** Phase 4c interim accepted — provisional outbound cost on negative-sale posting; **no settlement/variance tables** until Phase 5 Receipt settlement. Asset value remains zero when On Hand ≤ 0. See [open-decisions.md](open-decisions.md#od-014-negative-inventory-deficit-allocation).

## Tax before Phase 4b

A tax category alone is not enough for transaction tax.

**Accepted calculation contract:** [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md) (closes OD-004 / OD-005).

Before Phase 4b code begins, implement at least:

- store tax rates;
- store tax rules linking tax category to store (and rate when applicable);
- Store Tax Rule `treatment` (`taxable` / `zero_rated` / `exempt` / `not_applicable`) — not a global Tax Category status;
- denormalized `store_id` on store tax rules;
- effective dates with non-overlapping periods per `(store_id, tax_category_id, component code)`;
- taxable fraction;
- calculation order;
- compounding flag;
- component label / receipt code;
- hybrid transaction-component rounding with largest-remainder residual allocation per ADR-0014;
- fixtures that prove aggregation, residual allocation, compounding, taxable fraction, and treatments.

Do not invent an alternate residual policy (including “last line gets the residual”) in Phase 4b.

## Receipt sequence ownership (v1 choice)

**Lock for v1:** maintain the next receipt sequence on the **store** record (locked increment during successful completion only).

Rationale: simplest store-scoped sequence matching “unique receipt number within a store.” A dedicated sequence table may replace this later if multi-device contention warrants it.

Receipt numbers are assigned only during successful completion (ADR-0009).

## Business / reporting date (v1 choice)

**Lock for v1:**

- Store `reporting_date` explicitly on the business day (do not derive later from timestamps alone).
- Temporary assignment rule: **reporting date = the operating date selected when the business day is opened** (defaults to the store-local calendar date at open).
- Policy remains configurable later without rewriting history, because the date is stored.

## Customer identity before customer requests

Phase 5 Customer Requests use a nullable opaque `customer_reference` on the Product Request. Phase 5 does **not** introduce a `customers` table or Customer master shell.

Deferred until a later Customer domain: stable Customer identity, loyalty, householding, full purchase history, CRM, notifications platform, and migration of `customer_reference` values.

See [product-requests.md](../domains/product-requests.md) and [ordering-and-acquisition-planning.md](../domains/ordering-and-acquisition-planning.md).

## Purchase-order and receipt linkage

- One receipt **header** may contain lines from several purchase orders.
- Each receipt **line** references **at most one** purchase-order line.
- One delivered quantity that fulfils several PO lines is recorded as **several receipt lines**.
- Unlinked receipt lines (no PO line) require receiving authority and a reason.

## Purchase-order commercial lifecycle (Phase 5)

- Commercial statuses: `draft`, `ordered`, `closed`, `cancelled`.
- Receiving progress is derived separately (`not_received` / `partially_received` / `fully_received`).
- PO numbers are store-scoped, assigned at draft creation, never reused.
- After placement: vendor, store, currency, and line identity are immutable; reduce quantity via `cancelled_quantity`; no reopen in Phase 5.
- Purchase-Order Allocations commit expected supply only to Customer Requests (ADR-0015).

## On-order quantity

`on_order` is expected supply, not physical inventory.

**v1 preference:** derive from purchase-order lines:

```text
max(ordered − accepted received − cancelled, 0)
```

If later cached on `stock_balances`, a single purchasing/receiving posting service must own all updates and remain reconcilable to source PO lines.

Never post `on_order` through the inventory ledger.

## Reporting sources

Reports must not reinterpret completed history or modify source records.

| Report class | Primary sources |
| --- | --- |
| Historical sales, returns, tax, margin | Completed POS snapshots |
| Inventory | Inventory ledger + current balances |
| Stored-value history | Stored-value ledger |
| Open order / receiving ops | Current purchase orders and receipts |
| Holds | Current reservation records |

## Related

- [roadmap.md](roadmap.md)
- [open-decisions.md](open-decisions.md)
- [AGENTS.md](../../AGENTS.md)
- [System Overview](../architecture/system-overview.md)
