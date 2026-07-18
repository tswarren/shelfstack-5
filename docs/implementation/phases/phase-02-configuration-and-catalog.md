# Phase 2 — Configuration and Catalog

**Status:** Not started  
**Depends on:** Phase 1; classification-field audit from Phase 0  
**Unlocks:** Phase 3  
**Governing docs:** ADR-0001, ADR-0002, ADR-0003; [catalog](../../domains/catalog-and-products.md); [classification](../../domains/classification-and-configuration.md)

## Goal

Define a complete minimum sellable product variant with correct merchandising and financial classification defaults.

## Principal tables

Configuration:

- `departments`
- `merchandise_classes` (hierarchical)
- `product_formats`
- `product_conditions`
- `tax_categories`
- `return_policies`, `return_reasons`
- `discount_reasons`
- tender / cash-movement types as needed for later seeds

Catalog:

- `products`
- `product_variants`

Option/matrix tables (`product_options`, `product_option_values`, `product_variant_option_values`) are **deferred**; Phase 2 accepts only `variant_structure = single`.

Store tax rates/rules and the tax engine are **not** required for Phase 2 exit (hard prerequisite for Phase 4b).

## Services and behavior

- Seed/import organization-owned masters via `shelfstack:seed_reference_data` from cleaned [exports](../../exports/README.md): [departments](../../exports/departments.csv), [tax_categories](../../exports/tax_categories.csv), [merchandise_classes](../../exports/merchandise_classes.csv) (path-qualified nodes), [product_formats](../../exports/product_formats.csv), [product_conditions](../../exports/product_conditions.csv), [return_policies](../../exports/return_policies.csv), [return_reasons](../../exports/return_reasons.csv), [discount_reasons](../../exports/discount_reasons.csv).
- Identifier normalization (ISBN-10 → ISBN-13) and generation (`29` product, `28` variant SKU).
- Every sellable product has at least one variant; POS will sell variants only.
- `inventory_tracking_mode` is authoritative on the variant.
- Sale-eligibility / sale-readiness resolution (active, sellable, price, class/dept/tax category).
- Admin catalog search by identifier and SKU.

## Must not

- Create `display_categories` or `*_display_category_id`.
- Infer runtime tracking mode solely from merchandise class or department (class defaults are setup aids only).

## Exit criteria

- [ ] Create a product with canonical identifier and one variant SKU
- [ ] Department, merchandise class, and tax **category** resolve for the variant
- [ ] Sale-eligibility tests pass for a ready variant
- [ ] No display-category tables or FKs in migrations

## Out of scope

- Working tax **engine** (rates/rules calculation) — hard prerequisite for Phase 4b, may land at end of Phase 2 or start of 4b
- Inventory quantities
- Purchasing and POS completion

## Related

- [../architectural-locks.md](../architectural-locks.md)
- [../schema-reconciliation-display-categories-and-demand-allocation.md](../schema-reconciliation-display-categories-and-demand-allocation.md)
