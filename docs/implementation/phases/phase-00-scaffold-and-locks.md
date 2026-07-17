# Phase 0 — Scaffold and Architectural Locks

**Status:** Not started  
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

- [ ] `bin/ci` green on empty schema
- [ ] Compose/DB naming uses ShelfStack identifiers
- [ ] Architectural locks documented
- [ ] Classification-field audit complete or checklist filed with owners
- [ ] [../current-phase.md](../current-phase.md) points here until Phase 0 exits

## Out of scope

- Domain tables and POS UI
- Inventing deferred capabilities

## Related

- [../roadmap.md](../roadmap.md)
- [../../exports/schema/README.md](../../exports/schema/README.md)
