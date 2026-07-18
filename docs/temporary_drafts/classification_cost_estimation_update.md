# Proposed changes to `docs/domains/classification-and-configuration.md`

## Related / governing ADR

```markdown
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)
```

## Department estimation (keep)

A Department may define an optional Organization-level default gross-margin assumption for estimating inventory cost when no more authoritative cost is available.

* Express as basis points of gross margin, not markup.
* The estimate is Classification policy, not actual acquisition cost.
* The Department does not own Product-Variant cost.
* Inventory snapshots price and rate when the estimate is posted.
* Users may reject the estimate and leave cost unknown.
* Later Department or Catalog price changes do not recalculate posted estimates.

Suggested field (schema when implemented):

```text
default_cost_estimation_margin_bps   optional integer
```

## Store overrides (one sentence only)

Store-specific estimation policy may later override the Organization Department default through an effective-dated configuration model. Do not design that table in Phase 3.

## Defer

* `inventory_deficit_clearing_gl_account_code`
* `inventory_cost_variance_gl_account_code`
* exact Store override table shape

See [inventory_cost_reporting_accounting_note.md](inventory_cost_reporting_accounting_note.md).

## Invariant

* Department gross-margin defaults are estimation policy only, not actual acquisition cost.
