# Current Phase

**Active delivery phase:** Phase 4a — Editable POS  
**Status:** UX readiness gate complete; 4a not started  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md)

## Immediate next work

1. Begin Phase 4a (editable POS: business days, sessions, open transactions) per [phases/phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md), using [../design/pos-register-ui.md](../design/pos-register-ui.md).
2. Land store tax rates/rules before Phase 4b (hard prerequisite; may proceed in parallel with 4a).
3. Keep [OD-014](open-decisions.md) open for deficit allocation until Phase 4c / Phase 5 producers need it.
4. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

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
- Closing [OD-014](open-decisions.md) / [OD-004](open-decisions.md) by inventing ad hoc formulas in code.
- Closing [OD-013](open-decisions.md) role/store authority defaults before Phase 4b needs them.
- Deferred capabilities listed in [deferred-capabilities.md](deferred-capabilities.md).
- PWA / offline POS as adopted architecture.

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Phase 3 cost schema: [phase-03-inventory-cost-schema.md](phase-03-inventory-cost-schema.md)
- Identifiers: [../reference/identifiers.md](../reference/identifiers.md)
- Testing mechanics: [testing.md](testing.md)
- Services: [service-catalog.md](service-catalog.md)
