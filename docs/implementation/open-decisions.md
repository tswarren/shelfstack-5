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
| OD-003 | Inventory costing (moving average, opening, zero/negative on-hand, cost corrections) | open | Phase 3 | Inventory / Reporting | Needs ADR + Inventory Domain update. Edge cases listed below. Interim adjustment **kinds** locked in [architectural-locks.md](architectural-locks.md#opening-cost-contract) |
| OD-004 | Tax residual-cent allocation, compounding, and rounding policy | open | Phase 4b | Classification / POS | Domain updates required; ADR if competing rounding/compounding approaches are selected |
| OD-005 | Tax calculated per line vs transaction after discount allocation | open | Phase 4b | Classification / POS | Domain specs say tax after discount; finalize aggregation and residual rules |
| OD-006 | Minimal customer shell shape for Phase 5 | proposed | Phase 5 | Product Requests / future Customer | [architectural-locks.md](architectural-locks.md#customer-identity-before-customer-requests) requires a minimal contact record before `customer_request`; fields and table name TBD. Reconcile with product-requests.md v1 opaque-reference text |
| OD-007 | PO allocation `received` / `fulfilled` — persist vs derive | open | Phase 5 | Purchasing / Inventory | Phase 3 schema persists only `active` / `cancelled` |
| OD-008 | Department GL account codes vs later mapping table | accepted | Phase 2 | Classification | GL account code columns remain on `departments` for Phase 2; no separate mapping table |
| OD-009 | Store configuration home (columns vs `store_configurations` vs policy tables) | open | Phase 4a | Classification / Org | Thresholds and behavioral settings placement |
| OD-010 | Unavailable quantity by status (aggregate only vs status balances) | open | Phase 3–5 | Inventory | `stock_balances.unavailable` total vs optional status buckets |
| OD-011 | Identifier generation sequence ownership | accepted | Phase 2 | Catalog | Installation-singleton `identifier_sequences` (namespaces `21`/`27`/`28`/`29`); INV-ORG-001. Issue [#14](https://github.com/tswarren/shelfstack-5/issues/14) |
| OD-012 | Parent/reporting-only departments (`postable = false`) in first release | accepted | Phase 2 | Classification | Hierarchical departments with `postable`; reporting-only parents in scope |
| OD-013 | Storage and precedence of role and store authority defaults | deferred | Phase 4b | Organization / Authorization | See [OD-013 notes](#od-013-role-and-store-authority-defaults) |

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

## OD-003 costing edge cases (must settle in ADR)

Before Phase 4c, an accepted ADR (or Inventory Domain section with ADR authority) must define deterministic behavior for:

- on hand zero before receipt or opening stock;
- on hand negative before receipt;
- receipt brings negative stock to exactly zero;
- receipt only partially offsets negative stock;
- opening adjustment with explicit unit cost;
- quantity-only adjustment (uses current moving average);
- cost-only correction;
- customer return restores original cost snapshot;
- post-void reverses original cost;
- missing cost versus confirmed zero cost;
- formula shape for positive on-hand, e.g.  
  `(existing_inventory_value + incoming_value) / resulting_on_hand`.

Quantity may sell negative after warning ([architectural-locks](architectural-locks.md#negative-inventory)); costing under that condition remains **open** until OD-003 closes.

## OD-004 / OD-005 tax topics (must settle before Phase 4b)

- Taxable base after discount allocation  
- Multiple components and calculation order  
- Compounding yes/no  
- Taxable fraction  
- Rate and intermediate precision  
- Cent rounding and residual-cent allocation  
- Returns and post-voids  
- Transaction-scoped exemptions (reusable exemptions deferred)  
- Receipt labels / codes  

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
