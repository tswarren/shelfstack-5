# Current Phase

**Active delivery phase:** Phase 4e — Simple linked returns (Phase 4 complete on branch)  
**Status:** 4a–4e implemented on `phase/p4-point-of-sale`; not merged to `main` pending manual testing per the Phase 4 delivery plan's merge gate  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md)

## Immediate next work

1. Manually test Phase 4a–4e on `phase/p4-point-of-sale` before any merge to `main` (automated tests alone are not sufficient per the delivery plan's merge gate).
2. ~~Land store tax rates/rules (`treatment` on rules, not Tax Category status) and ADR-0014 fixtures before Phase 4b~~ — done on `phase/p4-point-of-sale`. See [phase-04-tax-schema.md](phase-04-tax-schema.md), [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md), and [service-catalog.md](service-catalog.md).
3. ~~Phase 4b (discount allocation, `Pos::RecalculateTransaction`, approvals)~~ — done. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4b exit criteria.
4. ~~Phase 4c (tender and atomic completion)~~ — done. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4c exit criteria.
5. ~~Phase 4d (individually tracked inventory)~~ — done. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4d exit criteria.
6. ~~Phase 4e (simple linked returns)~~ — done on `phase/p4-point-of-sale`: return `direction` / link / disposition on `pos_line_items`; `pos.return.create`; `Pos::AddLinkedReturnLine`, `Pos::AddCashRefundTender`, `Inventory::PostCustomerReturn` (`customer_return` ledger movement for `return_to_stock`); `Pos::RecalculateTransaction` / `Pos::CompleteTransaction` return branches; register UI for linked return + cash refund. See [phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) 4e exit criteria and [service-catalog.md](service-catalog.md).
7. Keep [OD-014](open-decisions.md)'s full settlement/variance representation open for Phase 5; the Phase 4c interim is closed as accepted and implemented.
8. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).
9. Wire up a `test/system` (Capybara/Selenium) harness before claiming the 4c "critical browser paths" UX-acceptance item — carried gap from 4a/4b, not newly introduced.
10. Phase 5 *foundational* purchasing may begin after 4c (already satisfied). Complete **4d before individual-item Phase 5 work** (also satisfied on this branch). See [roadmap.md](roadmap.md).

### UX readiness gate (complete)

- [x] Original UX drafts archived under [../archive/ux-drafts-2026-07/](../archive/ux-drafts-2026-07/)
- [x] Living mockups under [../design/prototypes/ui_mockup/](../design/prototypes/ui_mockup/) with demo-only warning
- [x] Governing [../design/](../design/) docs for visual style, shell, POS register UI/states, scanner/hotkeys, accessibility
- [x] Architecture mismatches corrected (merchandise class; no float-money / title-based tax / bypass-validation contract language)
- [x] Shared tokens and shell primitives in Rails CSS; light header/context application
- [x] Roadmap and Phase 4 docs require the gate and list UX acceptance criteria

Phase 3 (quantity inventory bootstrap) exit criteria and hardening follow-up are complete. See [phases/phase-03-quantity-inventory-bootstrap.md](phase-03-quantity-inventory-bootstrap.md).

Phase 2 (configuration and catalog) exit criteria are complete. See [phases/phase-02-configuration-and-catalog.md](phases/phase-02-configuration-and-catalog.md).

## Do not start yet

- Full redesign of Phase 1–3 admin CRUD to match mockups.
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
