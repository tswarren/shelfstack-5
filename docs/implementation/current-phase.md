# Current Phase

**Active delivery phase:** Phase 4d — Individually tracked inventory  
**Status:** 4a, 4b, 4c, and 4d implemented on `phase/p4-point-of-sale`; not merged to `main` pending manual testing per the Phase 4 delivery plan's merge gate  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md)

## Immediate next work

1. Manually test Phase 4a–4c on `phase/p4-point-of-sale` before any merge to `main` (automated tests alone are not sufficient per the delivery plan's merge gate).
2. ~~Land store tax rates/rules (`treatment` on rules, not Tax Category status) and ADR-0014 fixtures before Phase 4b~~ — done on `phase/p4-point-of-sale`: `store_tax_rates` / `store_tax_rules` schema, admin CRUD, the pure `Tax::CalculateTransaction` service, ADR-0014 fixtures/tests, and demo seed data. See [phase-04-tax-schema.md](phase-04-tax-schema.md), [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md), and [service-catalog.md](service-catalog.md).
3. ~~Begin the remainder of Phase 4b (discount allocation, `Pos::RecalculateTransaction` persisting `pos_line_item_taxes`, approvals)~~ — done on `phase/p4-point-of-sale`: `pos_discounts`/`pos_discount_allocations`/`pos_line_item_taxes`/`pos_tax_exemptions`/`pos_approvals` schema; the five 4b permission keys; `Pos::AuthorizeAction`, `Pos::OverridePrice`, `Pos::ApplyDiscount`, `Pos::OverrideTaxCategory`, `Pos::ApplyTaxExemption`, `Pos::RecalculateTransaction`; recalculation wired into every line-mutating 4a service; and register UI for price/discount/tax-category-override/exemption with approver deny paths. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4b exit criteria and [service-catalog.md](service-catalog.md).
4. ~~Begin Phase 4c (tender and atomic completion) — the first demo milestone~~ — done on `phase/p4-point-of-sale`: the D1 inventory sale bridge (`Inventory::ConvertReservation`, OD-014 provisional sale cost), D2 completion schema (`pos_tenders`, `pos_cash_movements`, `stores.next_receipt_sequence`, completion fields on `pos_transactions`), the five 4c permission keys, the Tender-state lock, `Pos::CompleteTransaction` (atomic + idempotent per ADR-0009), and register UI for tenders/completion/receipt. OD-014's Phase 4c interim (no settlement/variance tables) is exercised, not re-opened. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4c exit criteria and [service-catalog.md](service-catalog.md).
5. ~~Begin Phase 4d (individually tracked inventory) or Phase 4e (simple linked returns)~~ — 4d done on `phase/p4-point-of-sale`: `inventory_units` schema (generated `27` identifiers, `available`/`reserved`/`sold` statuses, exact acquisition cost), `Inventory::CreateInventoryUnit` bootstrap service (enforces `inventory.unit.manage`), `Inventory::Reserve`/`ReleaseReservation`/`ConvertReservation` extended to lock and transition the exact unit, `Pos::AddLine`/`UpdateLineQty`/`ResolveScan` extended for unit-backed lines, the `inventory.unit.manage` permission with a minimal admin UI, and concurrency/completion tests. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4d exit criteria and [service-catalog.md](service-catalog.md). Phase 4e (simple linked returns) remains open.
6. Keep [OD-014](open-decisions.md)'s full settlement/variance representation open for Phase 5; the Phase 4c interim is closed as accepted and implemented.
7. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).
8. Wire up a `test/system` (Capybara/Selenium) harness before claiming the 4c "critical browser paths" UX-acceptance item — carried gap from 4a/4b, not newly introduced.

### UX readiness gate (complete)

- [x] Original UX drafts archived under [../archive/ux-drafts-2026-07/](../archive/ux-drafts-2026-07/)
- [x] Living mockups under [../design/prototypes/ui_mockup/](../design/prototypes/ui_mockup/) with demo-only warning
- [x] Governing [../design/](../design/) docs for visual style, shell, POS register UI/states, scanner/hotkeys, accessibility
- [x] Architecture mismatches corrected (merchandise class; no float-money / title-based tax / bypass-validation contract language)
- [x] Shared tokens and shell primitives in Rails CSS; light header/context application
- [x] Roadmap and Phase 4 docs require the gate and list UX acceptance criteria

Phase 3 (quantity inventory bootstrap) exit criteria and hardening follow-up are complete. See [phases/phase-03-quantity-inventory-bootstrap.md](phases/phase-03-quantity-inventory-bootstrap.md).

Phase 2 (configuration and catalog) exit criteria are complete. See [phases/phase-02-configuration-and-catalog.md](phases/phase-02-configuration-and-catalog.md).

## Do not start yet

- Full redesign of Phase 1–3 admin CRUD to match mockups.
- Purchasing or receiving tables before their phase prerequisites.
- Closing [OD-014](open-decisions.md) by inventing ad hoc formulas in code.
- Implementing Phase 4b tax with a residual policy other than [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md).
- Closing [OD-013](open-decisions.md) role/store authority defaults before Phase 4b needs them.
- Deferred capabilities listed in [deferred-capabilities.md](deferred-capabilities.md).
- PWA / offline POS as adopted architecture.

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Phase 3 cost schema: [phase-03-inventory-cost-schema.md](phase-03-inventory-cost-schema.md)
- Phase 4 tax schema: [phase-04-tax-schema.md](phase-04-tax-schema.md)
- Identifiers: [../reference/identifiers.md](../reference/identifiers.md)
- Testing mechanics: [testing.md](testing.md)
- Services: [service-catalog.md](service-catalog.md)
