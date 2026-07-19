# Current Phase

**Active delivery phase:** Phase 4b — Price, tax, discounts, approvals  
**Status:** 4a and 4b implemented on `phase/p4-point-of-sale`; not merged to `main` pending manual testing per the Phase 4 delivery plan's merge gate  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md)

## Immediate next work

1. Manually test Phase 4a and 4b on `phase/p4-point-of-sale` before any merge to `main` (automated tests alone are not sufficient per the delivery plan's merge gate).
2. ~~Land store tax rates/rules (`treatment` on rules, not Tax Category status) and ADR-0014 fixtures before Phase 4b~~ — done on `phase/p4-point-of-sale`: `store_tax_rates` / `store_tax_rules` schema, admin CRUD, the pure `Tax::CalculateTransaction` service, ADR-0014 fixtures/tests, and demo seed data. See [phase-04-tax-schema.md](phase-04-tax-schema.md), [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md), and [service-catalog.md](service-catalog.md).
3. ~~Begin the remainder of Phase 4b (discount allocation, `Pos::RecalculateTransaction` persisting `pos_line_item_taxes`, approvals)~~ — done on `phase/p4-point-of-sale`: `pos_discounts`/`pos_discount_allocations`/`pos_line_item_taxes`/`pos_tax_exemptions`/`pos_approvals` schema; the five 4b permission keys; `Pos::AuthorizeAction`, `Pos::OverridePrice`, `Pos::ApplyDiscount`, `Pos::OverrideTaxCategory`, `Pos::ApplyTaxExemption`, `Pos::RecalculateTransaction`; recalculation wired into every line-mutating 4a service; and register UI for price/discount/tax-category-override/exemption with approver deny paths. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4b exit criteria and [service-catalog.md](service-catalog.md).
4. Begin Phase 4c (tender and atomic completion) — the first demo milestone.
5. Keep [OD-014](open-decisions.md) open for deficit allocation until Phase 4c / Phase 5 producers need it.
6. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

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
