# Current Phase

**Active delivery phase:** Phase 3 — Quantity inventory bootstrap (hardening)  
**Status:** In review  
**Plan document:** [phases/phase-03-quantity-inventory-bootstrap.md](phases/phase-03-quantity-inventory-bootstrap.md)

## Immediate next work

1. Finish Phase 3 hardening from the reopened review gate (concurrency coverage remaining: first-balance creation, reserve vs release, reserve vs post).
2. Do not begin Phase 4a until Phase 3 exit criteria are re-closed.
3. Keep [OD-014](open-decisions.md) open for deficit allocation until Phase 4c / Phase 5 producers need it.
4. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

Phase 3 structure is landed; review-gate hardening is in progress. See [phases/phase-03-quantity-inventory-bootstrap.md](phases/phase-03-quantity-inventory-bootstrap.md).

Phase 2 (configuration and catalog) exit criteria are complete. See [phases/phase-02-configuration-and-catalog.md](phases/phase-02-configuration-and-catalog.md).

Phase 1 hardening follow-up (transactional audited mutations, installation-global users, safe bootstrap, immutable memberships, fail-closed authority, return path, store-local dates) is complete. See [phases/phase-01-organization-and-authorization.md](phases/phase-01-organization-and-authorization.md) § Hardening follow-up.

## Do not start yet

- Purchasing or receiving tables before their phase prerequisites.
- Closing [OD-014](open-decisions.md) / [OD-004](open-decisions.md) by inventing ad hoc formulas in code.
- Closing [OD-013](open-decisions.md) role/store authority defaults before Phase 4b needs them.
- Deferred capabilities listed in [deferred-capabilities.md](deferred-capabilities.md).

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Phase 3 cost schema: [phase-03-inventory-cost-schema.md](phase-03-inventory-cost-schema.md)
- Identifiers: [../reference/identifiers.md](../reference/identifiers.md)
- Testing mechanics: [testing.md](testing.md)
- Services: [service-catalog.md](service-catalog.md)
