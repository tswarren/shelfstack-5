# Phase 0 — Scaffold and Architectural Locks

**Status:** Complete (2026-07-17)  
**Depends on:** none  
**Unlocks:** Phase 1

## Goal

Make the Rails application a trustworthy empty shell and record delivery locks before domain migrations.

## Work

- Rename Compose and database defaults from `my_rails_app_*` to `shelfstack_*`.
- Confirm `bin/setup`, `bin/ci`, and Docker Postgres paths succeed.
- Establish conventions: `app/services/`, permission helper stubs, current store/org context pattern.
- Record locks in [../architectural-locks.md](../architectural-locks.md).
- Audit domain specs and schema exports for leftover `display_categor*` concepts before Phase 2.

## Exit criteria

- [x] `bin/ci` green on empty schema
- [x] Compose/DB naming uses ShelfStack identifiers
- [x] Architectural locks documented
- [x] Classification-field audit complete or checklist filed with owners
- [x] [../current-phase.md](../current-phase.md) advanced to Phase 1 after this phase exited

## Audit result

**Date:** 2026-07-17  
**Scope:** `docs/adr/`, `docs/architecture/`, `docs/domains/`, `docs/schema/`, `docs/workflows/`, `docs/implementation/`, `docs/exports/schema/`, `db/schema.rb`, `db/migrate/`  
**Verdict:** Reconciled proforma is safe as a Phase 1–2 implementation input. No Phase 2-blocking discrepancies remain.

| Check | Outcome |
| --- | --- |
| Active `display_categories` / `*_display_category_id` | None in Schema Dictionary or domains. Remaining `display_categor*` hits are prohibition, revision notes, or phase out-of-scope language — allowed. |
| `special_order_quantity` / `tbo_required` | Absent as active dictionary fields; mentioned only as removed in revision notes / table summary. |
| Merchandise-class hierarchy | `merchandise_classes.parent_id` + `default_department_id`; products/variants use `merchandise_class_id`. |
| Store inventory boundary | Architecture docs prohibit area-level ownership; `stock_balances` keyed by `store_id` + `product_variant_id`. |
| Quantity vocabulary | `stock_balances.reserved` present; inventory commitment does not use `pending`. POS `pending` statuses are line/tender lifecycle only. |
| Money | Proforma money fields use integer `*_cents`. |
| Receipt–PO linkage | `receipt_lines.purchase_order_line_id` only; no receipt-header PO FK. |
| Premature CRM / transfer / RTV / buyback tables | Not present. Deferred-capable enum notes on units/ledger are documentation only. |
| Planned Phase 1/2 migrations | No migrations exist yet (`db/schema.rb` version `0`); none expect superseded fields. |

## Out of scope

- Domain tables and POS UI
- Inventing deferred capabilities

## Related

- [../roadmap.md](../roadmap.md)
- [../../exports/schema/README.md](../../exports/schema/README.md)
- Issue [#11](https://github.com/tswarren/shelfstack-5/issues/11)
