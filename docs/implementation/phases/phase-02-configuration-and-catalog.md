# Phase 2 — Configuration and Catalog

**Status:** Complete  
 
**Depends on:** Phase 1; classification-field audit from Phase 0  
**Unlocks:** Phase 3  
**Governing docs:** ADR-0001, ADR-0002, ADR-0003; [catalog](../../domains/catalog-and-products.md); [classification](../../domains/classification-and-configuration.md)

## Goal

Define a complete minimum sellable product variant with correct merchandising and financial classification defaults.

## Seed lifecycle (three layers)

Organization-scoped masters cannot load in `db:seed` before bootstrap creates the organization.

```text
db:seed
  → installation-global definitions (permissions only via shared loader)

shelfstack:bootstrap
  → organization, store, administrator role/user/membership
  → loads permissions via shared loader (same as db:seed)
  → does NOT load org-owned reference data
  → does NOT reset sequence counters
  → does NOT re-grant admin permissions except on role create

shelfstack:seed_reference_data
  → organization-owned canonical masters for the sole Organization
  → identifier_sequences rows (create if missing; never reset next_value)
  → import from docs/exports/*.csv
```

**`bin/setup` order:** `db:seed` → `shelfstack:bootstrap` → `shelfstack:seed_reference_data`.

**Existing install after permission/reference changes:** `db:seed` → `shelfstack:seed_reference_data` → `shelfstack:sync_admin_permissions`.

**Reference-data rerun rules:** create missing canonical rows; update source-owned descriptive fields; never reset `identifier_sequences.next_value`; never silently reactivate administrator-deactivated rows.

## Principal tables

Configuration:

- `departments` (hierarchical, `postable`; GL codes on the row — OD-008/OD-012)
- `merchandise_classes` (hierarchical; path-qualified codes)
- `product_formats`
- `product_conditions`
- `tax_categories`
- `return_policies`, `return_reasons`
- `discount_reasons`

Catalog:

- `products`
- `product_variants`
- `identifier_sequences` (installation-singleton — OD-011)

Option/matrix tables are **deferred**; Phase 2 accepts only `variant_structure = single`.

Store tax rates/rules and the tax engine are **not** required for Phase 2 exit (hard prerequisite for Phase 4b).

## Services and behavior

- Seed/import organization-owned masters via `shelfstack:seed_reference_data` from cleaned [exports](../../exports/README.md).
- Identifier normalization (ISBN-10 → ISBN-13) and generation (`29` product, `28` variant SKU).
- Every sellable product has at least one variant; POS will sell variants only.
- `inventory_tracking_mode` is authoritative on the variant.
- `Catalog::SaleEligibility` = catalog readiness (not full POS authorization).
- Admin catalog search by identifier and SKU.

## Must not

- Create `display_categories` or `*_display_category_id`.
- Infer runtime tracking mode solely from merchandise class or department (class defaults are setup aids only).
- Reset identifier sequence counters on seed re-run.

## Exit criteria

- [x] Import-ready export CSVs committed and validated (`docs/exports`, `script/validate_exports.rb`).
- [x] OD-008, OD-011, and OD-012 accepted and linked; issue #14 closed.
- [x] Clean `bin/setup` creates organization-owned reference data successfully.
- [x] Reference-data reruns do not reset sequence counters or reactivate deactivated records.
- [x] Merchandise-class codes unambiguous (path-qualified uniqueness) — enforced in DB on import.
- [x] Every merchandise-class default department is postable.
- [x] Unsupported option/matrix structures cannot be created (`variant_structure` = `single` only).
- [x] Every variant SKU is generated in namespace `28`.
- [x] UPC-A/EAN-equivalent products cannot be created as duplicates.
- [x] Product creation rolls back completely if default-variant creation fails.
- [x] Concurrent generation produces distinct, valid EAN-13 identifiers.
- [x] No ordinary update path changes canonical product identifier or variant SKU.
- [x] Create product with canonical identifier and one variant SKU.
- [x] Department, merchandise class, and tax category resolve for the variant.
- [x] `Catalog::SaleEligibility` tests pass; documented as catalog-level readiness.
- [x] No display-category tables or FKs in migrations.

## Out of scope

- Working tax **engine** (rates/rules calculation) — hard prerequisite for Phase 4b
- Display-category hierarchy; product options / matrix
- Inventory quantities / units / stock balances
- Purchasing, receiving, POS completion
- Identifier correction workflow UI
- Closing OD-003 / OD-004 / OD-013
- Tender / cash-movement type masters
- Re-deriving merchandise hierarchy at seed time

## Related

- [../architectural-locks.md](../architectural-locks.md)
- [../open-decisions.md](../open-decisions.md)
- [../schema-reconciliation-display-categories-and-demand-allocation.md](../schema-reconciliation-display-categories-and-demand-allocation.md)
