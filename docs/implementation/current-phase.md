# Current Phase

**Active delivery phase:** None numbered — Phase 9 Customer records closed  
**Status:** Carry-forward / later extensions  
**Phase 9 closed:** Gates 9a–9d merged to `main` at `db6778d87f9e10b7890884dcd96437b85e211ec1` (PR [#122](https://github.com/tswarren/shelfstack-5/pull/122)); [ADR-0017](../adr/0017-customer-domain-and-namespace-22.md)

**Phase 8 closed:** Must gates 8a–8d complete ([#95](https://github.com/tswarren/shelfstack-5/issues/95)–[#98](https://github.com/tswarren/shelfstack-5/issues/98); Gate 8d PR [#118](https://github.com/tswarren/shelfstack-5/pull/118)). Should/Nice 8e–8g deferred (DWR-022 / DWR-023 / DWR-027 / DWR-065).

**Phase 7 merge:** `d27d6668312b19d0012fd8d370011c966838f895` (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)); core gate 7a–7d accepted; **7e partial** ([#94](https://github.com/tswarren/shelfstack-5/issues/94))  
**Phase 6.5 merge:** `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54))  
**Phase 6 merge:** `853ae3b7a31b03960935bb14d8761b3fd19a0258` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39))

## Immediate next work

1. Prefer register-tracked carry-forward and ops hardening over inventing a new numbered Must phase.
2. Phase 8 deferred Should/Nice remain register-tracked until pulled back (DWR-022 / DWR-023 / DWR-027 / DWR-065).
3. Phase 7 follow-ups remain deferred (`phase-7` + `deferred`); canonical list in [deferred-work-register.md](deferred-work-register.md).
4. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
5. Retain OD-014 interim post-void block until a full correction algorithm PR is accepted.
6. Do not pull customer-receipt product design or hardware printing into near-term work (DWR-017).
7. Do not open Phase 8.5 / multi-variant (DWR-021) until explicitly scheduled.
8. Full CRM beyond flat Customer v1 remains deferred (DWR-036).

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision.
- Full CRM beyond flat Customer v1 (DWR-036 remainder).
- PWA / offline POS; integrated payments; customer receipt templates / gift receipts / ESC/POS.
- Fat POS shell revamp beyond Phase 9 customer attach.

## Pointers

- Carry-forward backlog: [deferred-work-register.md](deferred-work-register.md)
- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Phase 9 plan: [phases/phase-09-customer-records.md](phases/phase-09-customer-records.md)
- Customers domain: [../domains/customers.md](../domains/customers.md)
