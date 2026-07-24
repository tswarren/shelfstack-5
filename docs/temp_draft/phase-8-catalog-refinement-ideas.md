# Phase 8 — Catalog refinement & enrichment (draft)

**Status:** Non-governing scratch  
**Date:** 2026-07-23  
**Depends on:** Phase 7 complete (or far enough that catalog work can start without blocking close/reporting)  
**Roadmap note:** After Phase 7 merge (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)), [roadmap.md](../implementation/roadmap.md) marks Phase 8 as **Catalog refinement & enrichment** (planning). [deferred-capabilities.md](../implementation/deferred-capabilities.md) remains later extensions. Canonical carry-forward rows: [deferred-work-register.md](../implementation/deferred-work-register.md). Promote this draft to `docs/implementation/phases/phase-08-…` before implementation.

## Operator priorities (accepted for this draft)

1. **Enrichment over multi-variant.** Create/enrich from external bibliographic APIs matters more than unlocking multiple variants per product in v1 of this phase.
2. **Enrich-existing is important, not a dealbreaker.** Create-from-ISBN is the core path; suggest/apply enrichment for existing products is a strong follow-on, not a phase blocker.

Implication: Phase 8 can ship on today’s **one variant per product** (`variant_structure = single`) model. Multi-variant remains in-phase if capacity allows, but is not a gate for enrichment.

---

## Characterization

```text
existing Product + single Variant
→ staff linking UX (search / nested selects)
→ create-from-ISBN (ISBNdb first; Google Books optional)
→ product summary hub (staff-shaped, drilldowns)
→ effective-value presentation (override vs derived)
→ enrich-existing suggest/apply (when ready)
→ multi-variant unlock (later in phase or Phase 8.x)
```

**Should deliver:** easier catalog data entry; bibliographic create (and preferably enrich); clearer product overview; shared linking controls.

**Should not deliver:** inventory counts, transfers, RTV, buyback workflow, full ONIX/frontlist campaigns, EDI, full customer CRM, accounting exports, or a second display-category hierarchy (ADR-0003).

---

## Terminology (UX only)

| Staff-facing | Domain / schema |
| --- | --- |
| Products (library / catalog) | Product |
| Items | Product Variant |
| Units | Inventory Unit |

Do not rename domain entities. Put staff terms in design/copy guidance.

---

## Proposed gates

| Gate | Focus | Priority |
| --- | --- | --- |
| **8a** | Shared linking controls — filterable/nested combos (departments, formats, classes); search-to-link (products, items/variants, vendors) | Must |
| **8b** | Create-from-ISBN enrichment — adapter(s), mapping into Product (+ default Variant), format/class assist | Must |
| **8c** | Product summary hub — identity, item, stock/order/vendor drilldowns; effective values with override/derived cue | Must |
| **8d** | Vendor-source linking UX (streamlined; no publisher-as-vendor auto-create) | Should |
| **8e** | Creators model + optional image/thumbnail | Should (creators likely needed for good enrichment) |
| **8f** | Enrich-existing suggest/apply UI + field protection policy | Should (important; not dealbreaker) |
| **8g** | BISAC → merchandise-class mapping (into existing class tree only) | Nice |
| **8h** | Multi-variant unlock (new/used under one product; drop 1:1 unique) | Later / optional in phase |

---

## Enrichment policy (draft — needs OD)

### Create-from-ISBN (core)

1. Operator enters ISBN (normalize ISBN-10 → ISBN-13 per existing rules).
2. Lookup via provider adapter (ISBNdb primary).
3. Preview mapped fields before create.
4. On accept: create Product (+ single Variant) with mapped bibliographic fields; leave operational fields (price, tracking, department overrides, sellable) to store defaults / operator confirmation.
5. Never silently invent sellability or inventory effects.

### Enrich-existing (follow-on)

1. Lookup by canonical identifier (or confirmed match).
2. Show **diff**: proposed vs current.
3. Apply only selected fields, or “fill empty only.”
4. **Protected by default** (draft list): SKU, tracking mode, regular price, department/tax overrides, sellable/purchasable, status, identifier once operationally used.
5. **Safe to suggest/fill:** title/subtitle, description, publisher/imprint strings, creators, images, list price (as external list, not selling price), language/edition-like metadata, external subjects.

Google Books: secondary adapter behind the same service boundary; same preview/apply rules.

### Mapping concerns

- Formats: map provider format → `product_formats` with fallback + operator pick.
- Classifications: optional BISAC → merchandise class mapping; unmapped stays manual (ADR-0003: no parallel display tree).
- Publisher: keep string (and/or soft link) in Phase 8; do **not** auto-create Vendor rows for every publisher.

---

## Creators (draft — needs OD)

**Lean recommendation for enrichment quality:**

- `creators` master (normalized name; optional external IDs later).
- `product_creators` join: role (author, illustrator, …), position / primary flag.
- Import matching: soft match on normalized name; allow create-on-import when no confident match; no perfect-merge requirement in v1.

Cons to accept: duplicate creator rows until a later merge/review tool (`catalog.review_data_quality` already foreshadowed).

---

## Derived values

Always show **effective** department, tax category, class, price inputs, etc.

Subtly mark **record override vs derived** (icon/badge). Prefer one shared resolution path with POS sale-eligibility so UI and completion do not diverge.

---

## Stock ledger clarification

- Catalog/metadata edits on products, variants, or units → **no** stock ledger write.
- Unit status / availability / acquisition effects → existing inventory services only; never mutate `on_hand` from catalog screens.
- Individually tracked units still do not require vendor rows; acquisition source remains the audit trail.

---

## Vendors / publishers

- Streamline linking products/items to vendor sources for ordering.
- Publishers remain bibliographic identity (string / optional party later).
- Do not maintain a Vendor for every publisher “just in case.”
- Party model (publisher vs vendor) stays an open decision; Phase 8 does not require solving it.

---

## Multi-variant (deferred within phase)

Still desirable (standard + used under one commercial product per ADR-0001), but **not** required for 8a–8f.

When taken:

- Remove / relax `product_variants.product_id` uniqueness and `variant_structure = single` check for an agreed minimal structure (N named variants without full options/matrix).
- Used variants likely default to `individual` tracking; new to `quantity` — confirm at decision time.
- Existing products migrate as single-variant products unchanged.

---

## Product summary (staff hub)

One navigable surface, not a domain dump:

- Identity + creators/images  
- Item (variant): price, tracking, effective class/dept/tax  
- Stock snapshot + drilldown  
- Vendor sources / orderability  
- Open POs, recent receipts, requests (links)  
- Units only when individually tracked  

Read aggregation across Catalog / Inventory / Purchasing; no new ownership of those facts.

---

## Candidate open decisions

| Draft ID | Decision | Needed for |
| --- | --- | --- |
| OD-P8-01 | Enrichment overwrite / protect-field policy | 8b, 8f |
| OD-P8-02 | Creator model (join + master vs join-only) | 8e, good 8b |
| OD-P8-03 | Image storage (URL-only vs Active Storage) | 8e |
| OD-P8-04 | Provider order and credentials (ISBNdb, Google Books) | 8b |
| OD-P8-05 | BISAC → merchandise-class mapping shape | 8g |
| OD-P8-06 | Publisher party model vs string (+ optional vendor link) | 8d; can stay open |
| OD-P8-07 | Multi-variant v1 shape (if/when 8h) | 8h |

---

## Out of scope (remain deferred)

See [deferred-capabilities.md](../implementation/deferred-capabilities.md): counts, transfers, RTV, buyback, full CRM, ONIX campaign tooling, EDI, offline POS, accounting exports, etc.

---

## Suggested promotion path

1. Keep this file as scratch while Phase 7 finishes.  
2. Accept OD-P8-01 and OD-P8-04 (and preferably OD-P8-02) before implementation.  
3. Promote to `docs/implementation/phases/phase-08-catalog-refinement.md` and retarget roadmap Phase 8 away from the deferred-capabilities bucket.  
4. Add ODs to [open-decisions.md](../implementation/open-decisions.md) with Needed-by Phase 8.
