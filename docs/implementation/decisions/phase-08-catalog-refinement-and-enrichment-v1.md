# Phase 8 — Catalog Refinement and Enrichment Decisions v1

**Status:** accepted  
**Date:** 2026-07-24  
**Applies to:** Phase 8 — Catalog Refinement and Enrichment  
**Related:** [ADR-0001](../../adr/0001-product-variant-inventory-unit.md); [ADR-0002](../../adr/0002-canonical-identifiers-and-namespaces.md); [ADR-0003](../../adr/0003-merchandise-classes-and-departments.md); [catalog-and-products](../../domains/catalog-and-products.md); [phase-8 draft](../../temp_draft/phase-8-catalog-refinement-ideas.md); [deferred-work-register](../deferred-work-register.md) DWR-020–DWR-027; [open-decisions](../open-decisions.md)

## Decision summary

| ID | Decision | Status | Implementation timing |
| --- | --- | --- | --- |
| OD-P8-01 | Enrichment overwrite and protected-field policy | accepted | Required for 8b–8f |
| OD-P8-02 | Creator model | accepted | Required for 8b–8c |
| OD-P8-03 | Product-image storage and provider rights | accepted (v1 policy) | Optional Gate 8g |
| OD-P8-04 | Provider order, credentials, fallback, and failure policy | accepted | Required for 8b–8c |
| OD-P8-05 | BISAC and external-subject mapping | accepted | Optional Gate 8g |
| OD-P8-06 | Publisher/manufacturer party model | deferred | Later catalog work |
| OD-P8-07 | Minimal multi-variant structure | accepted direction; delivery deferred | Phase 8.5 |
| OD-P8-08 | Product-summary store context | accepted | Required for 8d |
| OD-P8-09 | Import provenance representation | accepted | Required for 8b–8f |
| OD-P8-10 | Minimum persisted bibliographic fields | accepted | Required for 8b–8c |

Acceptance clarifications (2026-07-24): merchandise class may be **suggested** on create with operator acceptance; format changes on enrich-existing use fill-empty / selected-apply only; duplicate creator+role uses soft validation; creator match is exact normalized name → suggest; image rows only when adapter policy is `remote_display_permitted` (or stronger); list price may apply when currency matches organization currency **or is null** (null treated as assume org currency, shown in preview); Phase 8.5 still needs a short cross-domain packet before code; permissions remain an implementation detail of the phase plan.

---

# OD-P8-01 — Enrichment overwrite and protected-field policy

## Status

**Accepted**

## Decision

ShelfStack divides fields that may appear in an enrichment result into five policy categories:

1. ShelfStack identity;
2. canonical product identity;
3. operational configuration;
4. bibliographic metadata;
5. external relationships and media.

The enrichment service must apply policy by category. Provider adapters do not decide which ShelfStack fields may be written.

## 1. ShelfStack identity

Never provider-managed:

* Product Variant SKU;
* Inventory Unit identifier;
* ShelfStack-generated sequence values;
* internal database identifiers;
* posting keys;
* operational public identifiers other than the Product’s canonical trade identifier used for matching.

## 2. Canonical Product identifier

The Product’s canonical identifier is normalized before lookup, used to find an existing Product, assigned during create-from-ISBN, and not replaced through ordinary enrichment.

A canonical identifier may be changed only through a separate controlled identifier-correction workflow. Ordinary Phase 8 enrichment must reject any attempt to replace the identifier of an operationally used Product.

## 3. Operational configuration

Protected; never automatically imported:

* `variant_structure`;
* inventory-tracking mode;
* Product / Variant status;
* sellable / purchasable;
* regular selling price;
* Product / Variant department, tax-category, and merchandise-class overrides (and Product merchandise-class assignment as an automatic write);
* discountability / returnability / return policy;
* exact-unit configuration;
* inventory availability;
* vendor source;
* inventory cost.

**Merchandise class and format suggestions:** A provider or BISAC mapping may **suggest** a merchandise class or Product format on create-from-ISBN. Applying that suggestion requires operator acceptance in the create preview. Mapping changes never silently reclassify existing Products (see OD-P8-05). On enrich-existing, Product format is bibliographic and may change only via **Fill empty fields** or **Apply selected fields**, not automatically.

External metadata must never independently cause a Product or Variant to become sellable.

## 4. Bibliographic metadata

May be offered for enrichment:

* Product name or title;
* subtitle;
* description;
* publisher or manufacturer name;
* imprint or brand name;
* publication or release date;
* language code;
* edition statement;
* Product format;
* creators;
* external subjects;
* external list price;
* image references.

For an existing Product:

* an empty eligible field may be filled through **Fill empty fields**;
* a non-empty eligible field changes only when specifically selected;
* merely previewing performs no writes;
* Phase 8 does not provide a general “replace all” action.

## 5. External list price

Provider list price is descriptive external metadata. It must not populate Variant regular price, make a Variant sale eligible, or be interpreted as the store’s selling price.

Persist `list_price_cents` only when:

* the amount is explicitly supplied; **and**
* the currency is **null** (treated as the organization’s operating currency) **or** matches `organization.default_currency_code`.

Do **not** persist when currency is present and differs from the organization currency. When currency is null, the preview must show that ShelfStack assumes the organization currency.

## Operational-use test

One centralized service determines whether the canonical Product identifier is operationally used (PO lines, receipts, stock, ledger, units, requests, reservations, completed POS lines, posted snapshots). It returns whether protected use exists and which record categories establish that use. Controllers and views must not implement separate incomplete queries.

## Consequences

* Existing non-empty metadata is protected by default.
* No per-field manual-lock columns in Phase 8.
* Identifier correction remains separate from enrichment.
* External metadata cannot silently alter sale, inventory, tax, cost, or purchasing behavior.

---

# OD-P8-02 — Creator model

## Status

**Accepted**

## Decision

Organization-owned Creator master and ordered Product-to-Creator join.

## Schema direction

```text
creators
- id, organization_id, display_name, normalized_name, sort_name, active, timestamps

product_creators
- id, product_id, creator_id, role, credited_as, position, timestamps
```

`normalized_name` is indexed but not unique. Different Creators may share a normalized name.

## Roles

Controlled string allowlist (no admin control-master table in Phase 8):

```text
author editor illustrator translator narrator photographer contributor
```

## Matching policy

1. Normalize the provider name.
2. Find organization-scoped candidates.
3. **Exact normalized-name match → suggest** that Creator.
4. Several exact matches (or other ambiguity) → require operator selection.
5. No suitable match → authorized create.

Name matching is advisory. Do not merge Creators solely because normalized names match.

## Duplicate creator+role

The same Creator and role on one Product should not be duplicated without an explicit reason. Enforce with **soft validation** in v1 (not a hard unique database constraint).

## Create-on-import

Authorized create-from-ISBN may create missing Creator rows in the same transaction as Product and Variant. Any failure rolls back the complete creation.

## Deferred

Creator merging, authority files, external Creator IDs, biographies, creator images, customer-facing pages, perfect identity reconciliation.

---

# OD-P8-03 — Product images and provider rights

## Status

**Accepted v1 policy**

## Decision

Images are optional Gate 8g enrichment. Phase 8 does not copy external image binaries into Active Storage by default. Store source references and attribution only.

```text
product_images
- id, product_id, provider, provider_record_id, source_url, attribution,
  position, retrieved_at, active, timestamps
```

Each provider adapter declares an image-use policy:

```text
unsupported | preview_only | remote_display_permitted | local_storage_permitted
```

Persist `product_images` source rows (create or enrich) only when the adapter policy is **`remote_display_permitted`** or **`local_storage_permitted`**. `preview_only` and `unsupported` / uncertain rights → no image row applied. Image failure never blocks Product creation.

Google Books images must not be copied permanently in Phase 8. Active Storage for externally sourced images is deferred until license/contract permits. Staff-uploaded images are a separate source type.

---

# OD-P8-04 — Provider order, credentials, fallback, and failure policy

## Status

**Accepted**

## Decision

Provider order:

1. **ISBNdb — primary production provider**
2. **Google Books — optional secondary** (operator-selected after no result / incomplete / error / rejected primary; not automatic fallback in v1)
3. No provider — manual Product creation remains available

Credentials are installation secrets (Rails credentials / env / secret manager)—never in Product/org/store tables, HTML, logs, or provenance records. V1 needs no credential admin UI.

One lookup action calls one provider. Adapters normalize failures (`not_found`, `ambiguous_result`, `authentication_failed`, `rate_limited`, `timeout`, `provider_unavailable`, `invalid_response`, `unsupported_identifier`). Bounded retry only for transient network failures. Short-lived normalized-result cache may support preview-and-accept only.

---

# OD-P8-05 — BISAC and external-subject mapping

## Status

**Accepted**

## Decision

External subjects remain separate source metadata. Mapping may suggest existing merchandise classes; external taxonomies do not become a ShelfStack hierarchy (ADR-0003).

```text
product_external_subjects
- id, product_id, taxonomy, external_code, external_label, provider, position, timestamps

external_subject_mappings
- id, organization_id, taxonomy, external_code, merchandise_class_id, active, timestamps
```

Unique active mapping per `(organization_id, taxonomy, external_code)`.

On create-from-ISBN: no mapped subjects → class unresolved or other default; one mapped class → **preselect as suggestion**; several → require selection. Applying a mapped class requires operator acceptance. Adding/changing mappings does not reclassify existing Products automatically.

Must not: auto-create merchandise classes; create display-category hierarchy; change dept/tax directly; rewrite completed classifications; silently reclassify existing Products.

---

# OD-P8-06 — Publisher/manufacturer party model

## Status

**Deferred**

## Decision

Retain `publisher_or_manufacturer_name` and `imprint_or_brand_name`. No Party / Publisher master in Phase 8. Publisher import does not create Vendors. DWR-024 remains deferred.

---

# OD-P8-07 — Minimal multi-variant structure

## Status

**Accepted architectural direction; implementation deferred to Phase 8.5**

## Decision

First multi-variant shape is **named variants**, not options/matrices:

```text
variant_structure: single | named
```

`options` / `matrix` remain later extensions. Product identifier with several eligible Variants requires Variant selection—no silent default. New/used may share a Product; tracking-mode defaults are suggestions only.

Phase 8.5 must still produce a short cross-domain decision packet covering Product forms, summary, lookup, POS scan, vendor sources, Product Requests, POs, receiving, stock summaries, labels, sale eligibility, authorization, and reports before schema unlock (`product_variants.product_id` uniqueness / `variant_structure` check).

---

# OD-P8-08 — Product-summary store context

## Status

**Accepted**

## Decision

Primary view is the **selected store**, with optional **all-accessible-stores** overview table. Store name visible with store-scoped facts. No unlabeled cross-store aggregate. Organization totals, if shown, labeled **All accessible stores**.

---

# OD-P8-09 — Import provenance representation

## Status

**Accepted**

## Decision

Dedicated append-only `catalog_enrichment_events` (not general logs alone). Actions: `create`, `fill_empty`, `selected_apply`. Event created only when changes successfully apply; same transaction as Product/Variant/creators/subjects/images. No permanent raw provider payload. Events are immutable; later edits create new events or ordinary catalog audit.

---

# OD-P8-10 — Minimum persisted bibliographic fields

## Status

**Accepted**

## Decision

Retain existing Product fields. Add:

```text
publication_date
publication_date_precision   # year | month | day when present
language_code
edition_statement
```

Do not add first-class columns for page count, dimensions, series, Dewey/LCC, reviews, provider IDs, etc., without a concrete requirement. Creators, images, subjects, and enrichment history use related tables. UI may label `name` as **Title**; do not rename the column. List-price rules follow OD-P8-01 §5.

---

# Consolidated implementation order

```text
1. Bibliographic fields
2. Creators and Product-Creator joins
3. Catalog enrichment events
4. Provider-neutral normalized result
5. ISBNdb adapter
6. Existing-Product detection
7. Create-from-ISBN preview and persistence
8. Product summary with selected-store context
9. Enrich-existing diff/apply
10. Optional external subjects, BISAC mapping, image references
11. Named multi-variant support separately in Phase 8.5
```

Permissions for enrichment workflows remain an implementation detail of the Phase 8 plan / permission catalog (no separate OD).
