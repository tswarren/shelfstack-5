# Current Phase

**Active delivery phase:** Phase 3 — Quantity inventory bootstrap  
**Status:** Not started  
**Plan document:** [phases/phase-03-quantity-inventory-bootstrap.md](phases/phase-03-quantity-inventory-bootstrap.md) *(create when Phase 3 planning begins)*

## Immediate next work

1. Implement Phase 3 from the roadmap: quantity bootstrap, opening cost, negative-stock tests.
2. Resolve or respect [OD-003](open-decisions.md) (inventory costing) before Phase 4c receipt/sale cost behavior expands.
3. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

Phase 2 (configuration and catalog) exit criteria are complete. See [phases/phase-02-configuration-and-catalog.md](phases/phase-02-configuration-and-catalog.md).

Phase 1 hardening follow-up (transactional audited mutations, installation-global users, safe bootstrap, immutable memberships, fail-closed authority, return path, store-local dates) is complete. See [phases/phase-01-organization-and-authorization.md](phases/phase-01-organization-and-authorization.md) § Hardening follow-up.

## Do not start yet

- POS, purchasing, or receiving tables before their phase prerequisites.
- Closing [OD-003](open-decisions.md) / [OD-004](open-decisions.md) by inventing ad hoc formulas in code.
- Closing [OD-013](open-decisions.md) role/store authority defaults before Phase 4b needs them.
- Deferred capabilities listed in [deferred-capabilities.md](deferred-capabilities.md).

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Identifiers: [../reference/identifiers.md](../reference/identifiers.md)
- Testing mechanics: [testing.md](testing.md)
- Services: [service-catalog.md](service-catalog.md)
