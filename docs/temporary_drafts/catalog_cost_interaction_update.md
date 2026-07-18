# Proposed changes to `docs/domains/catalog-and-products.md`

Companion drafts:

* [ADR-0013 draft](0013-govern-quantity-tracked-inventory-cost.md)
* [Receiving and Inventory domain update](receiving_inventory_domain_update.md)
* [Classification estimation and GL](classification_cost_estimation_update.md)

---

## Governing ADR addition

Add:

```markdown
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)
```

---

## Clarify ownership under `## Purpose` / ownership bullets

Ensure Catalog ownership remains:

* Product and Variant identity;
* canonical and alternate identifiers;
* Inventory-Tracking Mode;
* regular selling price and related sellability inputs;
* classification links used for Department and merchandise defaults.

Ensure Catalog does **not** own:

* Stock Balances;
* Inventory Movements / ledger posting;
* inventory cost variances;
* Inventory Units' operational status and posted acquisition cost (Receiving and Inventory).

Receiving and Inventory owns operational inventory and posted cost. Catalog is the upstream identity and pricing source those services consume.

---

## After `## Inventory-Tracking Mode`, add

## Cost interaction

Catalog does not calculate or store Store-and-Variant moving-average cost.

Inventory-Tracking Mode determines whether inventory cost applies:

| Mode | Cost effect |
| --- | --- |
| `quantity` | Store-and-Variant Stock Balance and moving weighted-average cost apply (ADR-0013) |
| `individual` | Exact Inventory-Unit acquisition cost applies; no quantity moving average |
| `none` | No Stock Balance, Reservation, or Inventory Movement; no inventory cost |

Regular selling price on the Variant (and later Store-specific price when introduced) is the Catalog input used when Classification supplies a Department gross-margin estimate. Temporary promotions, coupons, and transaction discounts are not estimation inputs.

Completed POS lines snapshot Catalog identity and descriptions independently of later Catalog edits. Completed cost amounts and provenance are snapshotted from Inventory / POS completion and are not recalculated from current Catalog price.

Sale-eligibility continues to evaluate tracking-mode requirements and availability. Cost unknown is not by itself a sale blocker unless a later accepted policy says otherwise; missing cost remains distinct from confirmed zero cost in inventory and reporting.

---

## Add to `## Invariants`

* Inventory-Tracking Mode determines whether Stock Balances and inventory cost apply.
* Catalog regular price may feed estimated inventory cost; Catalog does not own posted inventory valuation.
* Current Catalog price or classification changes do not rewrite completed cost snapshots.

---

## Open questions

No new Catalog open question is required for ADR-0013. Store-specific Variant price remains the existing future price-resolution note.
