# Proposed changes to `docs/domains/classification-and-configuration.md`

Companion drafts:

* [ADR-0013 draft](0013-govern-quantity-tracked-inventory-cost.md)
* [Receiving and Inventory domain update](receiving_inventory_domain_update.md)
* [Catalog cost interaction](catalog_cost_interaction_update.md)

---

## Governing ADR addition

Add:

```markdown
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)
```

---

## Extend `## Departments` suggested attributes

Add optional costing and GL attributes (OD-008 style: codes on the Department row):

* optional `default_cost_estimation_margin_bps` — Organization-level gross-margin assumption used only as an estimated-cost fallback;
* `inventory_deficit_clearing_gl_account_code`;
* `inventory_cost_variance_gl_account_code`;

Retain existing inventory-asset, COGS, adjustment, write-down, and shrinkage mappings as already modeled.

### Department cost estimation

A Department may define an optional default gross-margin assumption for estimating inventory cost when no more authoritative cost is available.

The rate is expressed in basis points and represents gross margin, not markup.

```text
estimated unit cost
=
round_half_up(
  Catalog regular selling price
  × (10,000 - margin basis points)
  / 10,000
)
```

Rules:

* the estimate is Classification policy, not actual acquisition cost;
* the Department does not own Product-Variant cost;
* Inventory posts and snapshots the estimate when used;
* users may reject the estimate and leave cost unknown;
* later Department or price changes do not recalculate posted estimates.

Cost-source precedence (Inventory / ADR-0013):

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

### Future Store overrides

Do not add nullable Store columns or duplicate Departments per Store for Phase 3.

A later effective-dated policy table may provide Store overrides:

```text
store_department_cost_estimation_policies
```

Suggested fields:

* `store_id`;
* `department_id`;
* `gross_margin_bps`;
* `effective_from` / `effective_to`;
* `active`;
* audit identity and timestamps.

### Accounting mapping for negative inventory

Export patterns for deficit clearing and cost variance are specified in Receiving and Inventory. Classification owns the Department GL code fields those exports resolve.

The inventory cost-variance account normally rolls up to COGS or cost-of-sales reporting.

---

## Add to `## Invariants`

* Department gross-margin defaults are estimation policy only, not actual acquisition cost.
* Department GL mappings may include inventory deficit clearing and inventory cost variance accounts.
* A department used as an active merchandise-class default must remain postable (existing Phase 2 reciprocal rule).

---

## Open questions

Defer:

* timing for introducing `store_department_cost_estimation_policies`;
* whether any Department estimation margin is required versus optional for specific Department types.

Remove or narrow any lingering question that treated quantity moving-average behavior under negative On Hand as Classification-owned; that belongs to Inventory / ADR-0013.
