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

**Moving average when on-hand is zero or negative:** still open as [OD-003](open-decisions.md); must be settled by ADR / Inventory Domain update before Phase 4c. Adjustment **kinds** above are locked; formulas for edge cases are not.

## Tax before Phase 4b

A tax category alone is not enough for transaction tax.

Before Phase 4b begins, implement at least:

- store tax rates;
- store tax rules linking tax category to rate;
- effective dates;
- taxable fraction;
- calculation order;
- component label / receipt code;
- deterministic rounding.

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

Phase 5 introduces a **minimal customer/contact shell** (identity and contact fields) before `customer_request` workflows.

Deferred until a later customer domain: loyalty, householding, full purchase history, CRM, notifications platform.

Opaque `customer_reference` strings alone are not sufficient once customer requests and fulfilment are implemented.

## Purchase-order and receipt linkage

- One receipt **header** may contain lines from several purchase orders.
- Each receipt **line** references **at most one** purchase-order line.
- One delivered quantity that fulfils several PO lines is recorded as **several receipt lines**.

## On-order quantity

`on_order` is expected supply, not physical inventory.

**v1 preference:** derive from purchase-order lines:

```text
ordered quantity
− accepted received quantity
− cancelled quantity
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
