# Temporary drafts — quantity inventory costing (ADR-0013)

These drafts are **not authoritative** until promoted.

There must be **exactly one** ADR-0013 candidate. The live tree must not contain a second `docs/adr/0013-*.md` while this package is under review.

## Document hierarchy

| Draft | Role | Auto-promote with ADR? |
| --- | --- | --- |
| [0013-govern-quantity-tracked-inventory-cost.md](0013-govern-quantity-tracked-inventory-cost.md) | Proposed ADR (~durable decision only) | Yes → `docs/adr/` |
| [receiving_inventory_domain_update.md](receiving_inventory_domain_update.md) | Inventory Domain patch | Yes → domain, after ADR accept |
| [catalog_cost_interaction_update.md](catalog_cost_interaction_update.md) | Minimal Catalog cross-link | Yes → short domain patch |
| [classification_cost_estimation_update.md](classification_cost_estimation_update.md) | Department estimation fallback | Yes → domain (margin only) |
| [permission_catalog_cost_correction_update.md](permission_catalog_cost_correction_update.md) | Phase 3 permission interim | Yes → permission catalog |
| [phase_03_costing_scope_note.md](phase_03_costing_scope_note.md) | Phase 3 required vs deferred | Yes → Phase 3 / OD-003 notes |

### Design notes (do **not** auto-promote)

| Draft | Role |
| --- | --- |
| [inventory_cost_schema_design_note.md](inventory_cost_schema_design_note.md) | Proposed fields, enums, deficit-allocation alternatives |
| [inventory_workflow_costing_design_note.md](inventory_workflow_costing_design_note.md) | Transfer / RTV / count / Receipt-correction candidates |
| [inventory_cost_reporting_accounting_note.md](inventory_cost_reporting_accounting_note.md) | Export / GL open questions |
| [inventory_cost_ui_guidance_note.md](inventory_cost_ui_guidance_note.md) | Presentation guidance |

## Promotion checklist

1. Accept ADR-0013 (Open details remain open).
2. Apply **authoritative** domain / permission / Phase 3 patches only.
3. Do **not** automatically promote every implementation suggestion from design notes.
4. Index ADR in `docs/adr/README.md`.
5. Close OD-003.
6. Remove or archive this temporary package.
