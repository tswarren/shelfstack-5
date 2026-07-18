# Proposed changes to `docs/domains/catalog-and-products.md`

**Intent:** Minimal cross-domain clarification. Catalog already owns tracking mode and pricing and excludes Stock Balances / Unit operational cost.

## Related documentation addition

Under Related / see also (not necessarily “Governing ADRs”):

```markdown
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md) — quantity-tracked cost owned by Receiving and Inventory; Catalog supplies tracking mode and regular price
```

## Short cross-domain paragraph

Add near Inventory-Tracking Mode or Price resolution:

> Inventory-Tracking Mode determines whether Stock Balances and inventory cost apply (`quantity` and later `individual`). Catalog regular selling price may be used as an input when Inventory posts a Department-based cost estimate. Catalog does not own Stock Balances, ledger posting, or posted inventory valuation. Current Catalog price or classification changes do not rewrite completed cost snapshots.

## Invariant addition

* Catalog regular price may feed estimated inventory cost; Catalog does not own posted inventory valuation.
